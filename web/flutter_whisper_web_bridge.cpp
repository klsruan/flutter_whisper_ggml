#include "whisper.h"

#include <cstdio>
#include <sstream>
#include <string>

#include <emscripten/emscripten.h>

struct fw_web_context {
  whisper_context* whisper = nullptr;
  std::string result;
};

namespace {

EM_JS(int, cancellation_requested, (), {
  const view = Module["fwCancelView"];
  return view ? Atomics.load(view, 0) : 0;
});

bool abort_callback(void*) {
  return cancellation_requested() != 0;
}

EM_JS(void, emit_progress, (int progress), {
  if (Module["fwOnProgress"]) Module["fwOnProgress"](progress);
});

EM_JS(void, emit_segment, (const char* json), {
  if (Module["fwOnSegment"]) {
    Module["fwOnSegment"](JSON.parse(UTF8ToString(json)));
  }
});

void progress_callback(whisper_context*, whisper_state*, int progress,
                       void*) {
  emit_progress(progress);
}

std::string json_escape(const char* value) {
  std::ostringstream output;
  for (const unsigned char ch : std::string(value == nullptr ? "" : value)) {
    switch (ch) {
      case '\\': output << "\\\\"; break;
      case '"': output << "\\\""; break;
      case '\n': output << "\\n"; break;
      case '\r': output << "\\r"; break;
      case '\t': output << "\\t"; break;
      default:
        if (ch < 0x20) {
          char encoded[7];
          std::snprintf(encoded, sizeof(encoded), "\\u%04x", ch);
          output << encoded;
        } else {
          output << ch;
        }
    }
  }
  return output.str();
}

std::string segment_json(whisper_context* whisper, int index,
                         bool token_timestamps) {
  std::ostringstream json;
  json << "{\"text\":\"" << json_escape(whisper_full_get_segment_text(whisper, index))
       << "\",\"start\":" << whisper_full_get_segment_t0(whisper, index)
       << ",\"end\":" << whisper_full_get_segment_t1(whisper, index);
  if (token_timestamps) {
    json << ",\"tokens\":[";
    const int count = whisper_full_n_tokens(whisper, index);
    for (int token = 0; token < count; ++token) {
      if (token > 0) json << ',';
      json << "{\"id\":" << whisper_full_get_token_id(whisper, index, token)
           << ",\"text\":\""
           << json_escape(whisper_full_get_token_text(whisper, index, token))
           << "\",\"probability\":" << whisper_full_get_token_p(whisper, index, token)
           << ",\"start\":" << whisper_full_get_token_t0(whisper, index, token)
           << ",\"end\":" << whisper_full_get_token_t1(whisper, index, token)
           << '}';
    }
    json << ']';
  }
  json << '}';
  return json.str();
}

void new_segment_callback(whisper_context* whisper, whisper_state*, int n_new,
                          void* user_data) {
  const bool token_timestamps = *static_cast<const bool*>(user_data);
  const int count = whisper_full_n_segments(whisper);
  const int first = count > n_new ? count - n_new : 0;
  for (int index = first; index < count; ++index) {
    const auto json = segment_json(whisper, index, token_timestamps);
    emit_segment(json.c_str());
  }
}

}  // namespace

extern "C" {

EMSCRIPTEN_KEEPALIVE fw_web_context* fw_web_create(
    const char* model_path, int use_gpu, int flash_attention, int gpu_device) {
  fw_web_context* context = new fw_web_context();
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
}

EMSCRIPTEN_KEEPALIVE void fw_web_destroy(fw_web_context* context) {
  if (context == nullptr) return;
  whisper_free(context->whisper);
  delete context;
}

EMSCRIPTEN_KEEPALIVE const char* fw_web_transcribe(
    fw_web_context* context, const float* samples, int sample_count,
    const char* language, int translate, int threads, const char* initial_prompt,
    float temperature, int token_timestamps, int no_context, int single_segment) {
  if (context == nullptr || samples == nullptr || sample_count <= 0) return nullptr;
  if (cancellation_requested()) return nullptr;
  auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.language = whisper_is_multilingual(context->whisper)
      ? (language == nullptr ? "auto" : language)
      : "en";
  // "auto" detects the language and continues decoding. detect_language
  // would return immediately after language detection.
  params.translate = translate != 0;
  params.n_threads = threads;
  params.initial_prompt = initial_prompt;
  params.temperature = temperature;
  bool include_tokens = token_timestamps != 0;
  params.token_timestamps = include_tokens;
  params.no_context = no_context != 0;
  params.single_segment = single_segment != 0;
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.progress_callback = progress_callback;
  params.new_segment_callback = new_segment_callback;
  params.abort_callback = abort_callback;
  params.new_segment_callback_user_data = &include_tokens;
  if (whisper_full(context->whisper, params, samples, sample_count) != 0) {
    context->result = "{\"error\":\"whisper_full failed\"}";
    return context->result.c_str();
  }
  std::ostringstream json;
  const int language_id = whisper_full_lang_id(context->whisper);
  json << "{\"language\":\"" << json_escape(whisper_lang_str(language_id))
       << "\",\"segments\":[";
  const int count = whisper_full_n_segments(context->whisper);
  for (int i = 0; i < count; ++i) {
    if (i > 0) json << ',';
    json << segment_json(context->whisper, i, include_tokens);
  }
  json << "]}";
  context->result = json.str();
  return context->result.c_str();
}

}  // extern "C"
