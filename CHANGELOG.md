# Changelog

All notable changes to `flutter_whisper_ggml` are documented here. This project
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 0.1.0

- Web model downloads now use persistent browser Cache Storage with size and
  SHA-256 verification, forced refresh, cache clearing, and storage quota fallback.
- Fixed native automatic language detection returning an empty transcription.
  English-only native models now report English consistently.
- Reset native VAD regions and timestamp mappings for each transcription.
  Switching a VAD model path reloads that model without reloading Whisper.
- Native segment callbacks now deliver decoded segments during inference.
- Native cancellation also works immediately after starting a request, including
  while the WAV file is being prepared. A cancelled session can be reused.
- Added real-audio regression tests for the packaged Linux CPU and Windows runtimes.
- Web cancellation interrupts active inference through a shared flag and keeps
  the loaded model available for another transcription.
- Web decoding honors the requested thread count, prompt, temperature, context,
  single-segment mode, and token timestamps. Automatic language detection now
  continues into transcription.
- Added a real WAV and model smoke test in Chrome to Web CI.

## 0.0.3

- Updated whisper.cpp to v1.9.5.
- CI builds the bundled native and WebAssembly runtimes from the upstream
  GitHub tag and assembles the pub.dev package with the compiled binaries.

## 0.0.2

- Pinned the local whisper.cpp v1.9.2 source tree as the default Windows build
  input, removing the requirement for an external checkout.
- Changed the Windows build default to CPU for reproducible consumer builds;
  CUDA and Vulkan remain explicit opt-in backends.
- Migrated stale `AUTO` CMake caches to CPU and added clearer backend
  validation.
- Applied modern CMake policy handling for ASM detection and scoped noisy MSVC
  conversion warnings to vendored whisper.cpp/GGML targets.
- Fixed model initialization and disposal paths used by release-mode Windows
  applications after a previous transcription was interrupted.

## 0.0.1

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
