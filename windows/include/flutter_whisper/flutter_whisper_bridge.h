#ifndef FLUTTER_WHISPER_BRIDGE_H_
#define FLUTTER_WHISPER_BRIDGE_H_

#include <stdint.h>

#ifdef _WIN32
#define FW_EXPORT __declspec(dllexport)
#elif defined(__APPLE__)
#define FW_EXPORT __attribute__((visibility("default"), used))
#else
#define FW_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct fw_context fw_context;
typedef void (*fw_progress_callback)(int32_t progress);
typedef void (*fw_segment_callback)(int32_t segment);

typedef struct fw_options_v2 {
  uint32_t abi_version;
  uint32_t struct_size;
  int32_t strategy;
  int32_t threads;
  int32_t offset_ms;
  int32_t duration_ms;
  int32_t translate;
  int32_t no_context;
  int32_t token_timestamps;
  int32_t single_segment;
  int32_t max_segment_length;
  int32_t split_on_word;
  int32_t max_tokens;
  int32_t audio_context;
  int32_t tiny_diarize;
  int32_t best_of;
  int32_t beam_size;
  float beam_patience;
  float temperature;
  float temperature_increment;
  float entropy_threshold;
  float log_probability_threshold;
  float no_speech_threshold;
  int32_t vad_enabled;
  float vad_threshold;
  int32_t vad_min_speech_ms;
  int32_t vad_min_silence_ms;
  float vad_max_speech_seconds;
  int32_t vad_speech_padding_ms;
  float vad_samples_overlap;
  const char* language;
  const char* initial_prompt;
  const char* suppress_regex;
  const char* vad_model_path;
  fw_progress_callback progress_callback;
} fw_options_v2;

FW_EXPORT fw_context* fw_create(const char* model_path, uint8_t use_gpu,
                                uint8_t flash_attention, int32_t gpu_device);
FW_EXPORT void fw_destroy(fw_context* context);

FW_EXPORT int32_t fw_device_count(void);
FW_EXPORT const char* fw_device_name(int32_t index);
FW_EXPORT const char* fw_device_description(int32_t index);
FW_EXPORT int32_t fw_device_type(int32_t index);
FW_EXPORT uint64_t fw_device_memory_free(int32_t index);
FW_EXPORT uint64_t fw_device_memory_total(int32_t index);

FW_EXPORT int32_t fw_transcribe(fw_context* context, const float* samples,
                                int32_t sample_count, const char* language,
                                uint8_t translate, int32_t threads,
                                uint8_t token_timestamps, uint8_t no_context);
FW_EXPORT int32_t fw_transcribe_v2(fw_context* context, const float* samples,
                                   int32_t sample_count,
                                   const fw_options_v2* options);
// Call prepare before starting a v3 request so cancellation can arrive early.
FW_EXPORT void fw_prepare_transcription(fw_context* context);
FW_EXPORT int32_t fw_transcribe_v3(fw_context* context, const float* samples,
                                   int32_t sample_count,
                                   const fw_options_v2* options,
                                   fw_segment_callback on_segment);
FW_EXPORT void fw_cancel(fw_context* context);

FW_EXPORT int32_t fw_segment_count(const fw_context* context);
FW_EXPORT const char* fw_segment_text(const fw_context* context, int32_t index);
FW_EXPORT int64_t fw_segment_start(const fw_context* context, int32_t index);
FW_EXPORT int64_t fw_segment_end(const fw_context* context, int32_t index);
FW_EXPORT const char* fw_result_language(const fw_context* context);
FW_EXPORT const char* fw_last_error(const fw_context* context);
FW_EXPORT int32_t fw_segment_speaker_turn_next(const fw_context* context,
                                                int32_t segment);
FW_EXPORT float fw_segment_no_speech_probability(const fw_context* context,
                                                  int32_t segment);
FW_EXPORT int32_t fw_token_count(const fw_context* context, int32_t segment);
FW_EXPORT int32_t fw_token_id(const fw_context* context, int32_t segment,
                              int32_t token);
FW_EXPORT const char* fw_token_text(const fw_context* context, int32_t segment,
                                    int32_t token);
FW_EXPORT float fw_token_probability(const fw_context* context, int32_t segment,
                                      int32_t token);
FW_EXPORT int64_t fw_token_start(const fw_context* context, int32_t segment,
                                 int32_t token);
FW_EXPORT int64_t fw_token_end(const fw_context* context, int32_t segment,
                               int32_t token);
FW_EXPORT int32_t fw_vad_segment_count(const fw_context* context);
FW_EXPORT int64_t fw_vad_segment_start(const fw_context* context, int32_t index);
FW_EXPORT int64_t fw_vad_segment_end(const fw_context* context, int32_t index);
FW_EXPORT float fw_timing_ms(const fw_context* context, int32_t timing);
FW_EXPORT const char* fw_version(void);
FW_EXPORT const char* fw_system_info(void);

#ifdef __cplusplus
}
#endif

#endif  // FLUTTER_WHISPER_BRIDGE_H_
