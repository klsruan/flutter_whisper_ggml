library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'src/models.dart';
import 'src/audio_decoder.dart';
import 'src/exceptions.dart';
import 'src/model_catalog.dart';
import 'src/model_manager.dart';
import 'src/platform_runtime.dart' as runtime;
import 'src/whisper_backend.dart';

export 'src/exceptions.dart';
export 'src/models.dart';
export 'src/model_catalog.dart';
export 'src/model_manager.dart';
export 'src/result_formatters.dart';
export 'src/audio_decoder.dart' show WhisperAudioDecoder;
export 'src/whisper_backend.dart' show WhisperBackend;

/// A reusable, offline whisper.cpp transcription session.
class FlutterWhisper {
  FlutterWhisper._(this._native, this._audioDecoder);

  /// Creates a session backed by a test double.
  ///
  /// Applications should use [load].
  FlutterWhisper.withBackend(
    WhisperBackend backend, {
    WhisperAudioDecoder? audioDecoder,
  }) : _native = backend,
       _audioDecoder = audioDecoder ?? runtime.createAudioDecoder();

  final WhisperBackend _native;
  final WhisperAudioDecoder _audioDecoder;
  bool _disposed = false;
  bool _cancelRequested = false;
  Future<void>? _queue;

  /// Loads a GGML Whisper model from [modelPath].
  static Future<FlutterWhisper> load({
    required String modelPath,
    WhisperModelConfig config = const WhisperModelConfig(),
    void Function(int progress)? onModelProgress,
  }) async {
    return FlutterWhisper._(
      await runtime.loadBackend(modelPath, config, onProgress: onModelProgress),
      runtime.createAudioDecoder(),
    );
  }

  /// Downloads (or reuses) [model] and loads it into whisper.cpp.
  ///
  /// Native platforms cache models in the application support directory. Set
  /// [modelDirectory] to control that location. Web stores models in the
  /// browser cache after verification. [onDownloadProgress] reports download
  /// or cache reuse, and [onModelProgress] reports loading the prepared model.
  static Future<FlutterWhisper> loadModel({
    required WhisperModel model,
    String? modelDirectory,
    bool forceDownload = false,
    WhisperModelConfig config = const WhisperModelConfig(),
    WhisperModelDownloadCallback? onDownloadProgress,
    void Function(int progress)? onModelProgress,
  }) async {
    final combinedWebProgress = kIsWeb && onDownloadProgress == null
        ? onModelProgress
        : null;
    final modelPath = await WhisperModelManager.prepare(
      model,
      directoryPath: modelDirectory,
      forceDownload: forceDownload,
      onProgress: combinedWebProgress == null
          ? onDownloadProgress
          : (progress) => combinedWebProgress(progress.percent ~/ 2),
    );
    try {
      return await load(
        modelPath: modelPath,
        config: config,
        onModelProgress: combinedWebProgress == null
            ? onModelProgress
            : (progress) => combinedWebProgress(50 + progress ~/ 2),
      );
    } finally {
      WhisperModelManager.releasePreparedModel(modelPath);
    }
  }

  /// Lists the devices compiled into and detected by the native GGML runtime.
  static List<WhisperDevice> get availableDevices => runtime.availableDevices;

  /// Decodes a WAV file and transcribes it.
  ///
  /// For the most predictable input, use mono 16 kHz PCM16 WAV. Media
  /// conversion intentionally belongs to the application, not this package.
  Future<WhisperResult> transcribeFile(
    String inputPath, {
    WhisperTranscribeConfig config = const WhisperTranscribeConfig(),
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  }) => _enqueue(() async {
    final samples = await _audioDecoder.decode(inputPath);
    if (_cancelRequested) {
      throw const WhisperException('Transcription cancelled.', code: -4);
    }
    _ensureActive();
    return _native.transcribe(
      samples,
      config,
      onProgress: onProgress,
      onSegment: onSegment,
    );
  });

  /// Transcribes mono 16 kHz PCM samples normalized to `[-1.0, 1.0]`.
  Future<WhisperResult> transcribe(
    Float32List samples, {
    WhisperTranscribeConfig config = const WhisperTranscribeConfig(),
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  }) => _enqueue(
    () => _native.transcribe(
      samples,
      config,
      onProgress: onProgress,
      onSegment: onSegment,
    ),
  );

  Future<WhisperResult> _enqueue(Future<WhisperResult> Function() operation) {
    _ensureActive();
    final previous = _queue;
    final result = Completer<WhisperResult>();
    final done = result.future.then<void>((_) {}, onError: (_) {});
    _queue = done;

    void run() {
      result.complete(
        Future<WhisperResult>.sync(() {
          _ensureActive();
          _cancelRequested = false;
          return operation();
        }).whenComplete(() {
          if (identical(_queue, done)) _queue = null;
        }),
      );
    }

    // An idle session starts immediately so cancel() can reach that request.
    if (previous == null) {
      run();
    } else {
      unawaited(previous.then((_) => run()));
    }
    return result.future;
  }

  /// Requests cancellation of the active transcription.
  void cancel() {
    _ensureActive();
    _cancelRequested = true;
    unawaited(_audioDecoder.cancel());
    _native.cancel();
  }

  /// Releases the native context after queued work completes.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _queue;
    _native.dispose();
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('FlutterWhisper has already been disposed.');
    }
  }
}
