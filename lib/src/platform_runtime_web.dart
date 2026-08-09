import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'audio_decoder.dart';
import 'exceptions.dart';
import 'models.dart';
import 'web_whisper_backend.dart';
import 'whisper_backend.dart';
import 'wav_pcm_decoder.dart';

Future<WhisperBackend> loadBackend(
  String modelPath,
  WhisperModelConfig config, {
  void Function(int progress)? onProgress,
}) => WebWhisperBackend.load(modelPath, config, onProgress: onProgress);

WhisperAudioDecoder createAudioDecoder() => WebWavAudioDecoder();

List<WhisperDevice> get availableDevices => const [
  WhisperDevice(
    index: 0,
    gpuIndex: null,
    name: 'WASM',
    description: 'WebAssembly SIMD/threads',
    type: WhisperDeviceType.cpu,
    freeMemory: 0,
    totalMemory: 0,
  ),
];

/// Browser WAV decoder for HTTP, asset and local `blob:` URLs.
final class WebWavAudioDecoder implements WhisperAudioDecoder {
  @override
  Future<void> cancel() async {}

  @override
  Future<Float32List> decode(String inputPath) async {
    if (_isWindowsPath(inputPath)) {
      throw const WhisperException(
        'Web browsers cannot read C:\\ paths. Select the audio with the '
        'browser file button or provide an HTTP(S)/asset URL.',
      );
    }
    final uri = Uri.base.resolve(inputPath).toString();
    web.Response response;
    try {
      response = await web.window.fetch(uri.toJS).toDart;
    } catch (error) {
      throw WhisperException(
        'Could not fetch the Web audio file: $uri ($error)',
      );
    }
    if (!response.ok) {
      throw WhisperException(
        'Could not fetch the Web audio file (${response.status}): $uri',
      );
    }
    final contentType = response.headers.get('content-type') ?? '';
    final path = Uri.tryParse(uri)?.path.toLowerCase() ?? '';
    if (!path.endsWith('.wav') &&
        !contentType.contains('wav') &&
        !uri.startsWith('blob:')) {
      throw const WhisperException(
        'flutter_whisper accepts only WAV files. Convert the input to mono '
        '16 kHz PCM16 WAV before transcription.',
      );
    }
    final buffer = await response.arrayBuffer().toDart;
    return decodeWavPcm(buffer.toDart.asUint8List());
  }
}

bool _isWindowsPath(String value) =>
    RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value.trim());
