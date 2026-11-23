# flutter_whisper_ggml

[![CI](https://github.com/klsruan/flutter_whisper_ggml/actions/workflows/ci.yml/badge.svg)](https://github.com/klsruan/flutter_whisper_ggml/actions/workflows/ci.yml)

Cross-platform, offline speech recognition for Flutter powered by a bundled and
pinned [`whisper.cpp`](https://github.com/ggml-org/whisper.cpp) v1.9.5 runtime.

The plugin runs inference locally, accepts WAV audio, reports progress and live
segments, and exports timestamped results as text, JSON or SRT. Native platforms
use Dart FFI; Web runs whisper.cpp in a Web Worker through WebAssembly.

Highlights:

- Android, iOS, Linux, macOS, Web and Windows support;
- automatic download and verified cache for 34 official GGML models;
- manual model paths, application assets, HTTP URLs and browser file selection;
- CPU plus optional CUDA/Vulkan acceleration on supported desktop builds;
- language detection, translation, greedy/beam decoding, prompts, timestamps,
  VAD controls, cancellation and live segments;
- no FFmpeg or model binaries bundled into the package.

> The package is in beta. The public API may change before `1.0.0`.

## Contents

- [Platform support](#platform-support)
- [Quick start](#quick-start)
- [Audio input](#audio-input)
- [Models](#models)
- [Transcription controls](#transcription-controls)
- [Device and GPU selection](#device-and-gpu-selection)
- [Output](#output)
- [WebAssembly](#webassembly)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Build and validation](#build-and-validation)
- [Known limitations](#known-limitations)

## Platform support

| Platform | Runtime | Acceleration | Current validation |
| --- | --- | --- | --- |
| Windows x64 | Dart FFI | CPU in pub.dev builds | CI build and manual use |
| Linux x64 | Dart FFI | CPU or Vulkan | CPU/Vulkan CI builds |
| Android 24+ | Dart FFI/NDK | CPU/NEON, ARM64 and x86_64 | Release CI build |
| iOS 13+ | Dart FFI/CocoaPods | CPU + Accelerate | Simulator and unsigned ARM64 CI builds |
| macOS 10.15+ | Dart FFI/CocoaPods | CPU + Accelerate | Release CI build |
| Web | Web Worker + WebAssembly | CPU SIMD/pthreads | CI build and manual use |

iOS and macOS compile in CI but have not yet been validated on physical Apple
hardware. Metal, Android Vulkan and WebGPU are not enabled. CUDA and Vulkan only
appear in device enumeration when they were compiled into the native library.

## Quick start

### 1. Install

```yaml
dependencies:
  flutter_whisper_ggml: ^0.0.3
```

```dart
import 'package:flutter_whisper_ggml/flutter_whisper.dart';
```

The package already contains whisper.cpp. Consumers do not need a separate
source checkout or system installation.

### 2. Allow automatic downloads on Android

Only applications that call `FlutterWhisper.loadModel` or
`WhisperModelManager.prepare` need network access. Add this outside the
`<application>` element in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Applications that provide a local model can omit this permission.

### 3. Download, load and transcribe

```dart
final whisper = await FlutterWhisper.loadModel(
  model: WhisperModels.smallQ5_1,
  config: const WhisperModelConfig(useGpu: false),
  onDownloadProgress: (progress) {
    print('download: ${progress.percent}%');
  },
  onModelProgress: (progress) {
    print('model: $progress%');
  },
);

try {
  final result = await whisper.transcribeFile(
    '/path/to/speech.wav',
    config: const WhisperTranscribeConfig(
      language: 'pt',
      threads: 4,
    ),
    onProgress: (progress) => print('inference: $progress%'),
    onSegment: (segment) => print(segment.text),
  );

  print(result.text);
  print(result.toSrt());
  print(result.toJsonString());
} finally {
  await whisper.dispose();
}
```

The first native call downloads and verifies the model. Later calls reuse the
cache and inference is fully offline. On Web, reuse depends on normal browser
HTTP caching.

### Load an existing model

```dart
final whisper = await FlutterWhisper.load(
  modelPath: '/path/to/ggml-small-q5_1.bin',
  config: const WhisperModelConfig(
    useGpu: true,
    flashAttention: true,
  ),
  onModelProgress: (progress) => print('model: $progress%'),
);
```

One `FlutterWhisper` instance owns one model context. Calls on the same instance
are serialized. Always call `dispose()` when the session is no longer needed.

## Audio input

The plugin intentionally accepts WAV only. The most predictable input is:

- mono;
- 16 kHz;
- signed 16-bit PCM;
- speech normalized without clipping.

The Dart decoder also reads supported PCM/Float WAV variants, mixes multiple
channels to mono and resamples to 16 kHz. Canonical PCM16 remains recommended
because it removes ambiguity before inference.

MP3, AAC, M4A, MP4 and other compressed containers are outside this package.
Convert them in the application before calling `transcribeFile`. The full
example demonstrates optional FFmpeg conversion without making FFmpeg a plugin
dependency.

Already decoded mono 16 kHz samples can be passed directly:

```dart
final result = await whisper.transcribe(
  samples,
  config: const WhisperTranscribeConfig(language: 'auto'),
);
```

## Models

Models are not included in the package archive. `WhisperModels.values` contains
all 34 variants supported by the bundled upstream download scripts.

### Recommended models

Choose a multilingual model — one without `.en` — for Brazilian Portuguese.

| Goal | Suggested model | Approximate download |
| --- | --- | ---: |
| Smoke test or very constrained device | `tiny-q5_1` | 31 MiB |
| Lightweight mobile use | `base-q5_1` | 57 MiB |
| Balanced Portuguese/mobile/desktop | `small-q5_1` | 181 MiB |
| Strong desktop quality and speed | `large-v3-turbo-q5_0` | 547 MiB |
| Maximum available quality | `large-v3` | 2.88 GiB |

`.en` models recognize English only. `q5` and `q8` variants are quantized: they
use less storage and memory, with a possible accuracy tradeoff. Large models can
exceed browser, mobile or GPU memory limits even when the download succeeds.

### Automatic cache

```dart
final modelPath = await WhisperModelManager.prepare(
  WhisperModels.largeV3TurboQ5_0,
  directoryPath: optionalModelsDirectory,
  forceDownload: false,
  onProgress: (progress) {
    print('${progress.receivedBytes}/${progress.totalBytes}');
  },
);
```

On native platforms, the default location is a `flutter_whisper_ggml/models`
folder inside the application-support directory. Downloads:

- stream directly to disk instead of buffering the model in memory;
- use a temporary `.part` file;
- verify exact size and SHA-256;
- retain a `.sha256` cache marker after successful verification;
- preserve an existing model if a replacement download fails.

Set `modelDirectory`/`directoryPath` when the application needs to own the cache
location. Set `forceDownload: true` to replace a cached copy. Cache deletion is
currently application-managed.

On Web, `prepare` returns the official HTTPS URL. The Web Worker downloads the
model during `loadModel`, and `onModelProgress` reports that operation.

Files named `for-tests-*` in upstream whisper.cpp contain headers but no model
weights. They cannot transcribe audio and are rejected by the native loader.

### All model downloads

Links and exact catalog metadata come from the model repositories used by the
whisper.cpp v1.9.5 download scripts.

| Model | Size | Variant |
| --- | ---: | --- |
| [`tiny`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin) | 74 MiB | Multilingual |
| [`tiny-q5_1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin) | 31 MiB | Multilingual, quantized |
| [`tiny-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q8_0.bin) | 42 MiB | Multilingual, quantized |
| [`tiny.en`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin) | 74 MiB | English only |
| [`tiny.en-q5_1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin) | 31 MiB | English only, quantized |
| [`tiny.en-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q8_0.bin) | 42 MiB | English only, quantized |
| [`base`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin) | 141 MiB | Multilingual |
| [`base-q5_1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin) | 57 MiB | Multilingual, quantized |
| [`base-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q8_0.bin) | 78 MiB | Multilingual, quantized |
| [`base.en`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin) | 141 MiB | English only |
| [`base.en-q5_1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin) | 57 MiB | English only, quantized |
| [`base.en-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q8_0.bin) | 78 MiB | English only, quantized |
| [`small`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin) | 465 MiB | Multilingual |
| [`small-q5_1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin) | 181 MiB | Multilingual, quantized |
| [`small-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin) | 252 MiB | Multilingual, quantized |
| [`small.en`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin) | 465 MiB | English only |
| [`small.en-q5_1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin) | 181 MiB | English only, quantized |
| [`small.en-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q8_0.bin) | 252 MiB | English only, quantized |
| [`small.en-tdrz`](https://huggingface.co/akashmjn/tinydiarize-whisper.cpp/resolve/main/ggml-small.en-tdrz.bin) | 465 MiB | English, experimental speaker turns |
| [`medium`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin) | 1.43 GiB | Multilingual |
| [`medium-q5_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin) | 514 MiB | Multilingual, quantized |
| [`medium-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin) | 785 MiB | Multilingual, quantized |
| [`medium.en`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin) | 1.43 GiB | English only |
| [`medium.en-q5_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q5_0.bin) | 514 MiB | English only, quantized |
| [`medium.en-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q8_0.bin) | 785 MiB | English only, quantized |
| [`large-v1`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v1.bin) | 2.88 GiB | Multilingual |
| [`large-v2`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin) | 2.88 GiB | Multilingual |
| [`large-v2-q5_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q5_0.bin) | 1.01 GiB | Multilingual, quantized |
| [`large-v2-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q8_0.bin) | 1.54 GiB | Multilingual, quantized |
| [`large-v3`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin) | 2.88 GiB | Multilingual, highest quality |
| [`large-v3-q5_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin) | 1.01 GiB | Multilingual, quantized |
| [`large-v3-turbo`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin) | 1.51 GiB | Multilingual, faster large model |
| [`large-v3-turbo-q5_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin) | 547 MiB | Multilingual, recommended desktop balance |
| [`large-v3-turbo-q8_0`](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin) | 834 MiB | Multilingual, higher-precision quantization |

## Transcription controls

`WhisperTranscribeConfig` exposes:

- automatic or explicit language;
- translation to English;
- greedy or beam-search sampling;
- thread count, offset and duration;
- initial prompt and context control;
- token timestamps and segment/token length controls;
- temperature fallback and probability thresholds;
- TinyDiarize and Silero VAD parameters.

Example with beam search and live segments:

```dart
final result = await whisper.transcribeFile(
  wavPath,
  config: const WhisperTranscribeConfig(
    language: 'auto',
    strategy: WhisperSamplingStrategy.beamSearch,
    beamSize: 5,
    tokenTimestamps: true,
    splitOnWord: true,
  ),
  onProgress: (progress) => updateProgress(progress / 100),
  onSegment: appendLiveSegment,
);
```

Cancellation is cooperative:

```dart
whisper.cancel();
```

The active operation finishes after native inference reaches a cancellation
checkpoint. Disposing a session waits for its queued work.

Silero VAD requires a separate compatible VAD model path in `WhisperVadConfig`;
the speech-model catalog does not download VAD models automatically.

## Device and GPU selection

```dart
final devices = FlutterWhisper.availableDevices;

for (final device in devices) {
  print('${device.name}: ${device.type}');
  print('memory: ${device.freeMemory}/${device.totalMemory}');
}

final selected = devices.first;
final whisper = await FlutterWhisper.load(
  modelPath: modelPath,
  config: WhisperModelConfig.forDevice(selected),
);
```

CPU is the safest fallback when a model does not fit in GPU memory. Web device
enumeration currently exposes only the WebAssembly CPU runtime.

### Windows backend

The pub.dev package includes the x64 CPU runtime. Maintainers building from
the repository can select CPU, CUDA, or Vulkan with
`FLUTTER_WHISPER_GPU_BACKEND`. CUDA requires the CUDA Toolkit. Vulkan requires
its SDK and shader compiler for source builds.

### Linux backend

The pub.dev package includes x64 CPU and Vulkan runtimes. CPU is selected by
default. To bundle the Vulkan runtime in your application:

```bash
FLUTTER_WHISPER_GPU_BACKEND=VULKAN flutter build linux --release
```

The Vulkan runtime requires the Vulkan loader and a compatible driver. Building
it from source also requires the Vulkan development headers, SPIR-V tools and
headers, and `glslc`.

## Output

`WhisperResult` contains detected language, combined text, timestamped segments,
optional token metadata, optional VAD regions and native timing data.

```dart
final plainText = result.text;
final json = result.toJsonString(pretty: true);
final subtitles = result.toSrt();

final selected = result.format(WhisperOutputFormat.json);
```

JSON uses a stable `schemaVersion: 1` structure. SRT output skips empty cues and
normalizes negative or reversed timestamp ranges.

## WebAssembly

Web inference runs outside the Flutter UI thread in a JavaScript Worker. The
Worker, Emscripten module and WASM binary are package assets loaded automatically
from:

```text
assets/packages/flutter_whisper_ggml/assets/web/
```

Applications do not copy these files into `web/`. A model may be an HTTP(S),
Flutter asset or browser `blob:` URL. Browsers cannot read local paths such as
`C:\models\ggml-small.bin`.

The pthread runtime requires these production response headers:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The minimal example includes a Netlify/Cloudflare-compatible `web/_headers`
file. Verify that the chosen host actually applies the headers and that remote
model responses are allowed by its CORS/cross-origin policy.

To rebuild the package Web artifacts, activate Emscripten and run one of:

```powershell
.\tool\build_web_wasm.ps1 -Configuration Release
```

```bash
bash tool/build_web_wasm.sh Release
```

CI pins Emscripten `4.0.7` for reproducibility.

## Examples

### Minimal package example

The local `example/` is an all-platform smoke application. It lets the user
select one GGML `.bin` model and one WAV file without bundling either file.

```bash
cd example
flutter pub get
flutter run -d windows   # linux, macos, android, ios or chrome also work
```

On Web, selected files become temporary `blob:` URLs.

### Full showcase

The separate
[`flutter_whisper_ggml_example`](https://github.com/klsruan/flutter_whisper_ggml_example)
repository contains the full UI, model dropdown, debugging asset, optional
FFmpeg conversion, progress display, live transcript and integration tests.
Keeping it separate prevents models and FFmpeg binaries from inflating this
package.

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| `Failed to fetch` on Web | Local filesystem path, CORS or missing isolation headers | Select files in the browser, use an allowed URL and verify COOP/COEP |
| Web Worker failed to load | Missing/stale generated Web assets | Run the Emscripten build script and rebuild the Flutter app |
| Only CPU appears | GPU backend was not compiled or its SDK/runtime is unavailable | Rebuild with CUDA/Vulkan and verify the driver/toolkit |
| `bad magic` | File is not a GGML Whisper model | Select an official `ggml-*.bin` file |
| Model reports headers only | An upstream `for-tests-*` fixture was selected | Download a real model from the catalog |
| SHA-256 verification failed | Incomplete, changed or intercepted download | Retry with `forceDownload: true`; do not use the partial file |
| Android download has no network | `INTERNET` permission is absent | Add the manifest permission shown in Quick start |
| WAV rejected | Unsupported/corrupt container or samples | Convert to mono 16 kHz PCM16 WAV |
| Repeated/hallucinated segments | Weak model, music/noise, clipping or unsuitable decoding settings | Improve the WAV, use a stronger multilingual model and tune thresholds/VAD |
| Out of memory or browser tab crash | Model exceeds available RAM/GPU/WASM limits | Use a smaller or quantized model and select CPU if GPU memory is limited |

## Build and validation

The pub.dev package includes precompiled whisper.cpp runtimes for Android
(ARM64 and x64, with 16 KiB page support), Linux x64, Windows x64, iOS
(ARM64 devices and ARM64/x64 simulators), macOS (ARM64 and x64), and Web.
Flutter bundles these binaries as part of the application build.

Local builds from the repository use Git to fetch the official whisper.cpp
v1.9.5 tag on first configure and cache the checkout in the build directory.
Set `FLUTTER_WHISPER_CPP_DIR` to use an existing checkout.

Run `bash tool/build_apple.sh` before building the iOS or macOS example.
To regenerate browser assets, activate Emscripten and run
`bash tool/build_web_wasm.sh Release` or `tool/build_web_wasm.ps1`.

`.github/workflows/ci.yml` clones the pinned Whisper tag on GitHub, compiles
each platform, builds the example, and validates the assembled package via
`dart pub publish --dry-run`. The package job uploads the archive as
`flutter_whisper_ggml-pub-package`. Download and extract that artifact outside
the repository, then run `dart pub get` and `dart pub publish` in the
extracted directory when releasing a new version.

## Known limitations

- Native file decoding is WAV-only by design.
- Web currently maps the common language, translation and thread controls; some
  advanced native decoding controls are not yet forwarded by the Worker.
- Metal, Android Vulkan and WebGPU are not implemented.
- The plugin does not provide microphone/live-stream capture.
- Downloads do not currently expose pause, resume, cancellation or a cache
  deletion API.
- Web has no plugin-managed persistent model cache; browser HTTP caching may
  still reuse a response.
- Apple platforms are CI-compiled but await physical-device validation.
- Accuracy, speed and memory depend primarily on model, quantization, audio and
  hardware.

## License

`flutter_whisper_ggml` is distributed under the [MIT License](LICENSE),
copyright (c) 2026 Ruan Dias. The bundled runtime retains the
[whisper.cpp license](LICENSE-whisper.cpp).
Applications must also review the license and usage terms of each model they
distribute or download.
