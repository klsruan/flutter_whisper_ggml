#include "include/flutter_whisper/flutter_whisper_bridge.h"

#include "whisper.h"
#include "ggml-backend.h"

#include <algorithm>
#include <atomic>
#include <exception>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// Defined next to whisper.cpp so the adapter can reset its private VAD state.
void fw_reset_vad(whisper_context* context, bool discard_model);

struct fw_segment {
  std::string text;
  int64_t start;
  int64_t end;
  bool speaker_turn_next;
  float no_speech_probability;
  struct token {
    int32_t id;
    std::string text;
    float probability;
    int64_t start;
    int64_t end;
  };
  std::vector<token> tokens;
};

struct fw_vad_segment {
  int64_t start;
  int64_t end;
};

struct fw_context {
  whisper_context* whisper = nullptr;
  std::atomic_bool abort_requested{false};
  std::mutex mutex;
  std::vector<fw_segment> segments;
  std::vector<fw_vad_segment> vad_segments;
  std::string vad_model_path;
  std::string language;
  std::string error;
};

namespace {

bool AbortCallback(void* user_data) {
  return static_cast<fw_context*>(user_data)->abort_requested.load();
}

void ProgressCallback(whisper_context*, whisper_state*, int progress,
                      void* user_data) {
  const auto callback = reinterpret_cast<fw_progress_callback>(user_data);
  if (callback != nullptr) callback(progress);
}

int32_t DefaultThreadCount() {
  const auto available = std::thread::hardware_concurrency();
  return static_cast<int32_t>(std::max(1u, std::min(4u, available)));
}

const fw_segment* SegmentAt(const fw_context* context, int32_t index) {
  if (context == nullptr || index < 0 ||
      static_cast<size_t>(index) >= context->segments.size()) {
    return nullptr;
  }
  return &context->segments[static_cast<size_t>(index)];
}

fw_segment CaptureSegment(whisper_context* whisper, int index) {
  fw_segment segment{
      whisper_full_get_segment_text(whisper, index),
      whisper_full_get_segment_t0(whisper, index),
      whisper_full_get_segment_t1(whisper, index),
      whisper_full_get_segment_speaker_turn_next(whisper, index),
      whisper_full_get_segment_no_speech_prob(whisper, index),
      {}};
  const int count = whisper_full_n_tokens(whisper, index);
  segment.tokens.reserve(static_cast<size_t>(count));
  for (int token = 0; token < count; ++token) {
    segment.tokens.push_back({
        whisper_full_get_token_id(whisper, index, token),
        whisper_full_get_token_text(whisper, index, token),
        whisper_full_get_token_p(whisper, index, token),
        whisper_full_get_token_t0(whisper, index, token),
        whisper_full_get_token_t1(whisper, index, token),
    });
  }
  return segment;
}

struct SegmentListener {
  fw_context* context;
  fw_segment_callback callback;
};

void NewSegmentCallback(whisper_context* whisper, whisper_state*, int n_new,
                        void* user_data) {
  auto* listener = static_cast<SegmentListener*>(user_data);
  auto& segments = listener->context->segments;
  const int count = whisper_full_n_segments(whisper);
  for (int i = std::max(0, count - n_new); i < count; ++i) {
    segments.push_back(CaptureSegment(whisper, i));
    listener->callback(static_cast<int32_t>(segments.size() - 1));
  }
}

int32_t Transcribe(fw_context* context, const float* samples, int32_t sample_count,
                   const fw_options_v2* options, bool prepared,
                   fw_segment_callback on_segment);

}  // namespace

int32_t fw_device_count(void) {
  ggml_backend_load_all();
  return static_cast<int32_t>(ggml_backend_dev_count());
}

const char* fw_device_name(int32_t index) {
  if (index < 0 || static_cast<size_t>(index) >= ggml_backend_dev_count()) return "";
  return ggml_backend_dev_name(ggml_backend_dev_get(static_cast<size_t>(index)));
}

const char* fw_device_description(int32_t index) {
  if (index < 0 || static_cast<size_t>(index) >= ggml_backend_dev_count()) return "";
  return ggml_backend_dev_description(ggml_backend_dev_get(static_cast<size_t>(index)));
}

int32_t fw_device_type(int32_t index) {
  if (index < 0 || static_cast<size_t>(index) >= ggml_backend_dev_count()) return -1;
  return static_cast<int32_t>(
      ggml_backend_dev_type(ggml_backend_dev_get(static_cast<size_t>(index))));
}

uint64_t fw_device_memory_free(int32_t index) {
  if (index < 0 || static_cast<size_t>(index) >= ggml_backend_dev_count()) return 0;
  size_t free = 0;
  size_t total = 0;
  ggml_backend_dev_memory(ggml_backend_dev_get(static_cast<size_t>(index)), &free, &total);
  return static_cast<uint64_t>(free);
}

uint64_t fw_device_memory_total(int32_t index) {
  if (index < 0 || static_cast<size_t>(index) >= ggml_backend_dev_count()) return 0;
  size_t free = 0;
  size_t total = 0;
  ggml_backend_dev_memory(ggml_backend_dev_get(static_cast<size_t>(index)), &free, &total);
  return static_cast<uint64_t>(total);
}

fw_context* fw_create(const char* model_path, uint8_t use_gpu,
                      uint8_t flash_attention, int32_t gpu_device) {
  if (model_path == nullptr || model_path[0] == '\0') return nullptr;
  try {
    auto* context = new fw_context();
    auto params = whisper_context_default_params();
    params.use_gpu = use_gpu != 0;
    params.flash_attn = flash_attention != 0;
    params.gpu_device = gpu_device;
    context->whisper = whisper_init_from_file_with_params(model_path, params);
    if (context->whisper == nullptr) {
      delete context;
      return nullptr;
    }
    return context;
  } catch (...) {
    return nullptr;
  }
}

void fw_destroy(fw_context* context) {
  if (context == nullptr) return;
  {
    std::lock_guard<std::mutex> lock(context->mutex);
    whisper_free(context->whisper);
    context->whisper = nullptr;
  }
  delete context;
}

int32_t fw_transcribe(fw_context* context, const float* samples,
                      int32_t sample_count, const char* language,
                      uint8_t translate, int32_t threads,
                      uint8_t token_timestamps, uint8_t no_context) {
  fw_options_v2 options{};
  options.abi_version = 2;
  options.struct_size = sizeof(options);
  options.strategy = 0;
  options.threads = threads;
  options.translate = translate;
  options.no_context = no_context;
  options.token_timestamps = token_timestamps;
  options.best_of = 5;
  options.beam_size = 5;
  options.beam_patience = -1.0f;
  options.temperature_increment = 0.2f;
  options.entropy_threshold = 2.4f;
  options.log_probability_threshold = -1.0f;
  options.no_speech_threshold = 0.6f;
  options.language = language;
  return fw_transcribe_v2(context, samples, sample_count, &options);
}

int32_t fw_transcribe_v2(fw_context* context, const float* samples,
                         int32_t sample_count, const fw_options_v2* options) {
  return Transcribe(context, samples, sample_count, options, false, nullptr);
}

void fw_prepare_transcription(fw_context* context) {
  if (context != nullptr) context->abort_requested.store(false);
}

int32_t fw_transcribe_v3(fw_context* context, const float* samples,
                         int32_t sample_count, const fw_options_v2* options,
                         fw_segment_callback on_segment) {
  return Transcribe(context, samples, sample_count, options, true, on_segment);
}

namespace {

int32_t Transcribe(fw_context* context, const float* samples,
                   int32_t sample_count, const fw_options_v2* options,
                   bool prepared, fw_segment_callback on_segment) {
  if (context == nullptr || context->whisper == nullptr) return -1;
  if (options == nullptr || options->abi_version != 2 ||
      options->struct_size < sizeof(fw_options_v2)) {
    context->error = "Unsupported transcription options ABI.";
    return -6;
  }
  if (samples == nullptr || sample_count <= 0) {
    context->error = "Audio samples cannot be empty.";
    return -2;
  }

  std::lock_guard<std::mutex> lock(context->mutex);
  try {
    if (!prepared) context->abort_requested.store(false);
    context->segments.clear();
    context->vad_segments.clear();
    context->language.clear();
    context->error.clear();
    if (context->abort_requested.load()) {
      context->error = "Transcription cancelled.";
      return -4;
    }

    const auto strategy = options->strategy == 1 ? WHISPER_SAMPLING_BEAM_SEARCH
                                                  : WHISPER_SAMPLING_GREEDY;
    auto params = whisper_full_default_params(strategy);
    params.n_threads = options->threads > 0 ? options->threads : DefaultThreadCount();
    params.offset_ms = options->offset_ms;
    params.duration_ms = options->duration_ms;
    params.translate = options->translate != 0;
    params.no_context = options->no_context != 0;
    params.token_timestamps = options->token_timestamps != 0;
    params.single_segment = options->single_segment != 0;
    params.max_len = options->max_segment_length;
    params.split_on_word = options->split_on_word != 0;
    params.max_tokens = options->max_tokens;
    params.audio_ctx = options->audio_context;
    params.tdrz_enable = options->tiny_diarize != 0;
    params.initial_prompt = options->initial_prompt;
    params.suppress_regex = options->suppress_regex;
    params.temperature = options->temperature;
    params.temperature_inc = options->temperature_increment;
    params.entropy_thold = options->entropy_threshold;
    params.logprob_thold = options->log_probability_threshold;
    params.no_speech_thold = options->no_speech_threshold;
    params.greedy.best_of = options->best_of;
    params.beam_search.beam_size = options->beam_size;
    params.beam_search.patience = options->beam_patience;
    params.vad = options->vad_enabled != 0;
    params.vad_model_path = options->vad_model_path;
    if (params.vad && (params.vad_model_path == nullptr || params.vad_model_path[0] == '\0')) {
      context->error = "VAD requires a model path.";
      return -2;
    }
    const bool new_vad_model = params.vad && context->vad_model_path != params.vad_model_path;
    fw_reset_vad(context->whisper, new_vad_model);
    if (new_vad_model) context->vad_model_path = params.vad_model_path;
    params.vad_params.threshold = options->vad_threshold;
    params.vad_params.min_speech_duration_ms = options->vad_min_speech_ms;
    params.vad_params.min_silence_duration_ms = options->vad_min_silence_ms;
    params.vad_params.max_speech_duration_s = options->vad_max_speech_seconds;
    params.vad_params.speech_pad_ms = options->vad_speech_padding_ms;
    params.vad_params.samples_overlap = options->vad_samples_overlap;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.abort_callback = AbortCallback;
    params.abort_callback_user_data = context;
    if (options->progress_callback != nullptr) {
      params.progress_callback = ProgressCallback;
      params.progress_callback_user_data =
          reinterpret_cast<void*>(options->progress_callback);
    }
    SegmentListener listener{context, on_segment};
    if (on_segment != nullptr) {
      params.new_segment_callback = NewSegmentCallback;
      params.new_segment_callback_user_data = &listener;
    }

    const std::string requested_language = options->language == nullptr ? "auto" : options->language;
    const bool multilingual = whisper_is_multilingual(context->whisper) != 0;
    params.language = multilingual ? requested_language.c_str() : "en";
    // An empty or "auto" language detects the language and continues decoding.
    // detect_language would stop immediately after detection.
    params.detect_language = false;

    const int result = whisper_full(context->whisper, params, samples, sample_count);
    if (context->abort_requested.load()) {
      context->error = "Transcription cancelled.";
      return -4;
    }
    if (result != 0) {
      context->error = "whisper_full failed.";
      return -3;
    }

    const int count = whisper_full_n_segments(context->whisper);
    context->segments.clear();
    context->segments.reserve(static_cast<size_t>(count));
    for (int i = 0; i < count; ++i) {
      context->segments.push_back(CaptureSegment(context->whisper, i));
    }
    const int vad_count = params.vad ? whisper_full_n_vad_segments(context->whisper) : 0;
    context->vad_segments.reserve(static_cast<size_t>(vad_count));
    for (int i = 0; i < vad_count; ++i) {
      context->vad_segments.push_back({
          whisper_full_get_vad_segment_t0(context->whisper, i),
          whisper_full_get_vad_segment_t1(context->whisper, i),
      });
    }
    const int language_id = whisper_full_lang_id(context->whisper);
    const char* detected = multilingual ? whisper_lang_str(language_id) : "en";
    context->language = detected == nullptr ? "" : detected;
    return 0;
  } catch (const std::exception& exception) {
    context->error = exception.what();
    return -5;
  } catch (...) {
    context->error = "Unexpected native exception.";
    return -5;
  }
}

}  // namespace

void fw_cancel(fw_context* context) {
  if (context != nullptr) context->abort_requested.store(true);
}

int32_t fw_segment_count(const fw_context* context) {
  return context == nullptr ? 0 : static_cast<int32_t>(context->segments.size());
}

const char* fw_segment_text(const fw_context* context, int32_t index) {
  const auto* segment = SegmentAt(context, index);
  return segment == nullptr ? "" : segment->text.c_str();
}

int64_t fw_segment_start(const fw_context* context, int32_t index) {
  const auto* segment = SegmentAt(context, index);
  return segment == nullptr ? 0 : segment->start;
}

int64_t fw_segment_end(const fw_context* context, int32_t index) {
  const auto* segment = SegmentAt(context, index);
  return segment == nullptr ? 0 : segment->end;
}

const char* fw_result_language(const fw_context* context) {
  return context == nullptr ? "" : context->language.c_str();
}

const char* fw_last_error(const fw_context* context) {
  return context == nullptr ? "Invalid native context." : context->error.c_str();
}

int32_t fw_segment_speaker_turn_next(const fw_context* context, int32_t segment) {
  const auto* value = SegmentAt(context, segment);
  return value != nullptr && value->speaker_turn_next ? 1 : 0;
}

float fw_segment_no_speech_probability(const fw_context* context,
                                       int32_t segment) {
  const auto* value = SegmentAt(context, segment);
  return value == nullptr ? 0.0f : value->no_speech_probability;
}

namespace {
const fw_segment::token* TokenAt(const fw_context* context, int32_t segment,
                                 int32_t token) {
  const auto* value = SegmentAt(context, segment);
  if (value == nullptr || token < 0 ||
      static_cast<size_t>(token) >= value->tokens.size()) return nullptr;
  return &value->tokens[static_cast<size_t>(token)];
}
}  // namespace

int32_t fw_token_count(const fw_context* context, int32_t segment) {
  const auto* value = SegmentAt(context, segment);
  return value == nullptr ? 0 : static_cast<int32_t>(value->tokens.size());
}

int32_t fw_token_id(const fw_context* context, int32_t segment, int32_t token) {
  const auto* value = TokenAt(context, segment, token);
  return value == nullptr ? -1 : value->id;
}

const char* fw_token_text(const fw_context* context, int32_t segment,
                          int32_t token) {
  const auto* value = TokenAt(context, segment, token);
  return value == nullptr ? "" : value->text.c_str();
}

float fw_token_probability(const fw_context* context, int32_t segment,
                           int32_t token) {
  const auto* value = TokenAt(context, segment, token);
  return value == nullptr ? 0.0f : value->probability;
}

int64_t fw_token_start(const fw_context* context, int32_t segment,
                       int32_t token) {
  const auto* value = TokenAt(context, segment, token);
  return value == nullptr ? 0 : value->start;
}

int64_t fw_token_end(const fw_context* context, int32_t segment,
                     int32_t token) {
  const auto* value = TokenAt(context, segment, token);
  return value == nullptr ? 0 : value->end;
}

int32_t fw_vad_segment_count(const fw_context* context) {
  return context == nullptr ? 0 : static_cast<int32_t>(context->vad_segments.size());
}

int64_t fw_vad_segment_start(const fw_context* context, int32_t index) {
  if (context == nullptr || index < 0 ||
      static_cast<size_t>(index) >= context->vad_segments.size()) return 0;
  return context->vad_segments[static_cast<size_t>(index)].start;
}

int64_t fw_vad_segment_end(const fw_context* context, int32_t index) {
  if (context == nullptr || index < 0 ||
      static_cast<size_t>(index) >= context->vad_segments.size()) return 0;
  return context->vad_segments[static_cast<size_t>(index)].end;
}

float fw_timing_ms(const fw_context* context, int32_t timing) {
  if (context == nullptr || context->whisper == nullptr) return 0.0f;
  const auto* value = whisper_get_timings(context->whisper);
  if (value == nullptr) return 0.0f;
  switch (timing) {
    case 0: return value->sample_ms;
    case 1: return value->encode_ms;
    case 2: return value->decode_ms;
    case 3: return value->batchd_ms;
    case 4: return value->prompt_ms;
    default: return 0.0f;
  }
}

const char* fw_version(void) { return whisper_version(); }

const char* fw_system_info(void) { return whisper_print_system_info(); }
