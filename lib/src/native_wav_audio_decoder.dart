import 'dart:io';
import 'dart:typed_data';

import 'audio_decoder.dart';
import 'exceptions.dart';
import 'wav_pcm_decoder.dart';

/// Native WAV-only decoder used by the lightweight plugin core.
final class NativeWavAudioDecoder implements WhisperAudioDecoder {
  @override
  Future<Float32List> decode(String inputPath) async {
    final path = inputPath.trim();
    if (!path.toLowerCase().endsWith('.wav')) {
      throw const WhisperException(
        'flutter_whisper accepts only WAV files. Convert the input to mono '
        '16 kHz PCM16 WAV in the application before transcription.',
      );
    }
    final input = File(path);
    if (!await input.exists()) {
      throw WhisperException('WAV file does not exist: $path');
    }
    final bytes = await input.readAsBytes();
    return decodeWavPcm(bytes);
  }

  @override
  Future<void> cancel() async {}
}
