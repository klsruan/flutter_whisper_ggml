# Changelog

All notable changes to `flutter_whisper_ggml` are documented here. This project
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-08-08

Initial beta release.

### Added

- Bundled and pinned whisper.cpp v1.9.2 source tree; consumers do not need an
  external whisper.cpp checkout.
- Stable Dart FFI/C bridge for Android, iOS, Linux, macOS and Windows.
- Web Worker and Emscripten WebAssembly runtime with SIMD, pthreads, progress
  events and live transcription segments.
- Windows x64 CPU, CUDA and Vulkan build selection with runtime GGML device
  enumeration.
- Linux x64 CPU and Vulkan build targets.
- Android 24+ ARM64/x86_64 CPU/NEON builds with Android 15 16 KiB page support.
- iOS 13+ and macOS 10.15+ C++17 CocoaPods builds using Apple Accelerate.
- Typed catalog for all 34 GGML model variants supported by the bundled upstream
  download scripts.
- `FlutterWhisper.loadModel` and `WhisperModelManager.prepare` for automatic
  native downloads, application-support caching and Web URL loading.
- Streamed model downloads with progress, atomic `.part` writes, exact-size
  checks, SHA-256 verification and cache reuse.
- Manual GGML model loading from native paths, HTTP/asset URLs and browser blob
  URLs.
- WAV PCM/Float decoding, multichannel-to-mono mixing, 16 kHz resampling and
  strict input validation.
- Direct transcription of normalized mono 16 kHz `Float32List` samples.
- Automatic or explicit language selection, English translation, greedy/beam
  decoding, prompts, context control, offsets, duration, token timestamps,
  segment limits and probability/temperature thresholds.
- Silero VAD configuration, TinyDiarize controls and VAD result regions.
- Serialized model inference, cooperative cancellation, deterministic disposal,
  progress callbacks and incremental segment callbacks.
- Timestamped segments, token metadata, detected language and native timing
  information.
- Stable versioned JSON output and normalized SRT subtitle formatting.
- GGML magic validation and explicit rejection of incomplete upstream
  `for-tests-*` fixtures.
- Minimal all-platform smoke example plus a separate full showcase repository.
- Unified CI covering analysis, tests, pub.dev validation and release builds for
  Android, Linux CPU/Vulkan, Windows CPU, Web/WASM, iOS and macOS.
- MIT License, Apple privacy manifests, package documentation, model download
  catalog and troubleshooting guidance.

### Design decisions

- FFmpeg is intentionally not a package dependency. Applications convert MP3,
  AAC, M4A, MP4 and other compressed media to WAV when needed.
- Model binaries are intentionally downloaded or supplied by the application so
  they do not inflate the plugin archive.
- Native file transcription is intentionally WAV-only for predictable audio
  preprocessing.

### Known limitations

- The API is beta and may change before `1.0.0`.
- Metal, Android Vulkan, WebGPU, microphone streaming and plugin-managed browser
  model persistence are not available in this release.
- Apple targets are compiled in CI but still require physical-device validation.
