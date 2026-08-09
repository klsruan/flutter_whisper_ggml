library;

import 'dart:async';
import 'dart:typed_data';

import 'src/models.dart';
import 'src/audio_decoder.dart';
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
  Future<void> _queue = Future<void>.value();

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
  /// [modelDirectory] to control that location. Web loads the official URL in
  /// the WebAssembly worker and reports network/loading progress through
  /// [onModelProgress].
  static Future<FlutterWhisper> loadModel({
    required WhisperModel model,
    String? modelDirectory,
    bool forceDownload = false,
    WhisperModelConfig config = const WhisperModelConfig(),
    WhisperModelDownloadCallback? onDownloadProgress,
    void Function(int progress)? onModelProgress,
  }) async {
    final modelPath = await WhisperModelManager.prepare(
      model,
      directoryPath: modelDirectory,
      forceDownload: forceDownload,
      onProgress: onDownloadProgress,
    );
    return load(
      modelPath: modelPath,
      config: config,
      onModelProgress: onModelProgress,
    );
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
  }) async {
    _ensureActive();
    final samples = await _audioDecoder.decode(inputPath);
    return transcribe(
      samples,
      config: config,
      onProgress: onProgress,
      onSegment: onSegment,
    );
  }

  /// Transcribes mono 16 kHz PCM samples normalized to `[-1.0, 1.0]`.
  Future<WhisperResult> transcribe(
    Float32List samples, {
    WhisperTranscribeConfig config = const WhisperTranscribeConfig(),
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  }) {
    _ensureActive();
    final result = _queue.then((_) async {
      _ensureActive();
      return _native.transcribe(
        samples,
        config,
        onProgress: onProgress,
        onSegment: onSegment,
      );
    });
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Requests cancellation of the active transcription.
  void cancel() {
    _ensureActive();
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
