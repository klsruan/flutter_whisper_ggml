#include "whisper.h"

#include <atomic>
#include <cstdio>
#include <sstream>
#include <string>

#include <emscripten/emscripten.h>

struct fw_web_context {
  whisper_context* whisper = nullptr;
  std::atomic_bool cancelled{false};
  std::string result;
};

namespace {

bool abort_callback(void* user_data) {
  return static_cast<fw_web_context*>(user_data)->cancelled.load();
}

EM_JS(void, emit_progress, (int progress), {
  if (Module["fwOnProgress"]) Module["fwOnProgress"](progress);
});

EM_JS(void, emit_segment,
      (const char* text, int start, int end), {
  if (Module["fwOnSegment"]) {
    Module["fwOnSegment"]({
      text: UTF8ToString(text),
      start: start,
      end: end,
    });
  }
});

void progress_callback(whisper_context*, whisper_state*, int progress,
                       void*) {
  emit_progress(progress);
}

void new_segment_callback(whisper_context* whisper, whisper_state*, int n_new,
                          void*) {
  const int count = whisper_full_n_segments(whisper);
  const int first = count > n_new ? count - n_new : 0;
  for (int index = first; index < count; ++index) {
    emit_segment(whisper_full_get_segment_text(whisper, index),
                 static_cast<int>(whisper_full_get_segment_t0(whisper, index)),
                 static_cast<int>(whisper_full_get_segment_t1(whisper, index)));
  }
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
    const char* language, int translate, int threads) {
  if (context == nullptr || samples == nullptr || sample_count <= 0) return nullptr;
  context->cancelled.store(false);
  auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.language = language == nullptr ? "auto" : language;
  params.detect_language = std::string(params.language) == "auto";
  params.translate = translate != 0;
  // The first Web milestone stays single-threaded inside its dedicated Worker.
  // Pthread pool bootstrap and COOP/COEP deployment are the next milestone.
  (void) threads;
  params.n_threads = 1;
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.progress_callback = progress_callback;
  params.new_segment_callback = new_segment_callback;
  params.abort_callback = abort_callback;
  params.abort_callback_user_data = context;
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
    json << "{\"text\":\""
         << json_escape(whisper_full_get_segment_text(context->whisper, i))
         << "\",\"start\":" << whisper_full_get_segment_t0(context->whisper, i)
         << ",\"end\":" << whisper_full_get_segment_t1(context->whisper, i) << '}';
  }
  json << "]}";
  context->result = json.str();
  return context->result.c_str();
}

EMSCRIPTEN_KEEPALIVE void fw_web_cancel(fw_web_context* context) {
  if (context != nullptr) context->cancelled.store(true);
}

}  // extern "C"
