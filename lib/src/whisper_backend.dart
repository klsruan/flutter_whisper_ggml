import 'dart:typed_data';

import 'models.dart';

/// Internal backend contract, public only to support deterministic package tests.
abstract interface class WhisperBackend {
  Future<WhisperResult> transcribe(
    Float32List samples,
    WhisperTranscribeConfig config, {
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  });

  void cancel();
  void dispose();
}
