import 'package:flutter/foundation.dart';

import 'model_catalog.dart';
import 'model_manager_stub.dart'
    if (dart.library.io) 'model_manager_native.dart'
    if (dart.library.js_interop) 'model_manager_web.dart'
    as implementation;
import 'model_manager_stub.dart'
    if (dart.library.js_interop) 'model_manager_web.dart'
    as web_cache;

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

/// Downloads and verifies GGML models for reuse.
abstract final class WhisperModelManager {
  /// Returns a native file path or a temporary Web object URL.
  ///
  /// Web callers that use this method directly must call
  /// [releasePreparedModel] after loading the URL. Use
  /// `FlutterWhisper.loadModel` to manage the URL automatically.
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

  /// Clears this plugin's model cache for the current browser origin.
  /// Throws [UnsupportedError] on native platforms.
  static Future<void> clearWebCache() => web_cache.clearWebModelCache();

  /// Releases a temporary Web URL created by [prepare].
  static void releasePreparedModel(String path) =>
      web_cache.releasePreparedModel(path);
}
