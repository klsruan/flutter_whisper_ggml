import 'dart:typed_data';

import 'audio_decoder.dart';
import 'models.dart';
import 'whisper_backend.dart';

Future<WhisperBackend> loadBackend(
  String modelPath,
  WhisperModelConfig config, {
  void Function(int progress)? onProgress,
}) =>
    throw UnsupportedError('flutter_whisper is unsupported on this platform.');

WhisperAudioDecoder createAudioDecoder() => _UnsupportedAudioDecoder();

List<WhisperDevice> get availableDevices => const [];

final class _UnsupportedAudioDecoder implements WhisperAudioDecoder {
  @override
  Future<void> cancel() async {}

  @override
  Future<Float32List> decode(String inputPath) =>
      throw UnsupportedError('Media decoding is unsupported on this platform.');
}
