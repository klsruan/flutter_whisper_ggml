import 'dart:typed_data';

/// Converts a WAV input into the PCM format required by whisper.cpp.
abstract interface class WhisperAudioDecoder {
  Future<Float32List> decode(String inputPath);
  Future<void> cancel();
}
