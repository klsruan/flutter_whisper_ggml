import 'package:flutter/foundation.dart';

import 'model_catalog.dart';
import 'model_manager_stub.dart'
    if (dart.library.io) 'model_manager_native.dart'
    if (dart.library.js_interop) 'model_manager_web.dart'
    as implementation;

typedef WhisperModelDownloadCallback =
    void Function(WhisperModelDownloadProgress progress);

@immutable
final class WhisperModelDownloadProgress {
  const WhisperModelDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();
}

/// Downloads and caches official GGML models on native platforms.
///
/// On Web, [prepare] returns the remote URL. The WebAssembly worker downloads
/// the model while `FlutterWhisper.loadModel` reports [onModelProgress].
abstract final class WhisperModelManager {
  static Future<String> prepare(
    WhisperModel model, {
    String? directoryPath,
    bool forceDownload = false,
    WhisperModelDownloadCallback? onProgress,
  }) => implementation.prepareModel(
    model,
    directoryPath: directoryPath,
    forceDownload: forceDownload,
    onProgress: onProgress,
  );
}
