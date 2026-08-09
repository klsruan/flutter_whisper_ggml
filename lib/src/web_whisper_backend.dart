import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'exceptions.dart';
import 'models.dart';
import 'whisper_backend.dart';

final class WebWhisperBackend implements WhisperBackend {
  WebWhisperBackend._(this._worker) {
    _worker.addEventListener('message', _onMessage.toJS);
    _worker.addEventListener('error', _onError.toJS);
  }

  static const _assetBase =
      'assets/packages/flutter_whisper_ggml/assets/web';
  static const workerUrl = '$_assetBase/flutter_whisper_worker.js';
  static const moduleUrl = '$_assetBase/flutter_whisper.js';

  static Future<WebWhisperBackend> load(
    String modelUrl,
    WhisperModelConfig config, {
    void Function(int progress)? onProgress,
  }) async {
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(modelUrl.trim())) {
      throw const WhisperException(
        'Web browsers cannot read C:\\ model paths. Select the model with '
        'the browser file button or provide an HTTP(S)/asset URL.',
      );
    }
    final backend = WebWhisperBackend._(web.Worker(workerUrl.toJS));
    try {
      await backend._request('init', {
        'modelUrl': Uri.base.resolve(modelUrl).toString(),
        'moduleUrl': Uri.base.resolve(moduleUrl).toString(),
        'useGpu': config.useGpu,
        'gpuDevice': config.gpuDevice,
        'flashAttention': config.flashAttention,
      }, onProgress: onProgress);
      return backend;
    } catch (_) {
      backend.dispose();
      rethrow;
    }
  }

  final web.Worker _worker;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};
  final Map<int, void Function(int)> _progress = {};
  final Map<int, void Function(WhisperSegment)> _segments = {};
  var _nextRequest = 0;
  var _disposed = false;

  @override
  Future<WhisperResult> transcribe(
    Float32List samples,
    WhisperTranscribeConfig config, {
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  }) async {
    if (_disposed) throw StateError('Web Whisper backend is disposed.');
    if (samples.isEmpty) {
      throw const WhisperException('Audio samples cannot be empty.');
    }
    final response = await _request(
      'transcribe',
      {
        'samples': samples,
        'config': {
          'language': config.language,
          'translate': config.translate,
          'threads': config.threads,
          'tokenTimestamps': config.tokenTimestamps,
          'noContext': config.noContext,
          'singleSegment': config.singleSegment,
          'initialPrompt': config.initialPrompt,
          'temperature': config.temperature,
        },
      },
      onProgress: onProgress,
      onSegment: onSegment,
    );
    final encoded = response['result'];
    final map = encoded is String
        ? jsonDecode(encoded) as Map<String, Object?>
        : (encoded as Map).cast<String, Object?>();
    return _resultFromJson(map);
  }

  Future<Map<String, Object?>> _request(
    String command,
    Map<String, Object?> payload, {
    void Function(int)? onProgress,
    void Function(WhisperSegment)? onSegment,
  }) {
    final id = _nextRequest++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    if (onProgress != null) _progress[id] = onProgress;
    if (onSegment != null) _segments[id] = onSegment;
    _worker.postMessage({'id': id, 'command': command, ...payload}.jsify());
    return completer.future;
  }

  void _onMessage(web.Event event) {
    final value = (event as web.MessageEvent).data.dartify();
    if (value is! Map) return;
    final message = value.cast<String, Object?>();
    final id = (message['id'] as num?)?.toInt();
    if (id == null) return;
    if (message['event'] == 'progress') {
      _progress[id]?.call((message['progress'] as num).toInt());
      return;
    }
    if (message['event'] == 'segment') {
      final raw = message['segment'];
      if (raw is Map) {
        _segments[id]?.call(_segmentFromJson(raw.cast<String, Object?>()));
      }
      return;
    }
    _progress.remove(id);
    _segments.remove(id);
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['ok'] == true) {
      completer.complete(message);
    } else {
      completer.completeError(
        WhisperException(
          message['error']?.toString() ?? 'Unknown WebAssembly worker error.',
        ),
      );
    }
  }

  void _onError(web.Event event) {
    final error = WhisperException(
      'The whisper.cpp Web Worker failed to load. Build and copy the '
      'Emscripten artifacts into assets/web.',
    );
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
    _progress.clear();
    _segments.clear();
  }

  @override
  void cancel() {
    if (!_disposed) {
      _worker.postMessage({'id': -1, 'command': 'cancel'}.jsify());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _worker.terminate();
    final error = StateError('Web Whisper backend was disposed.');
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
    _progress.clear();
    _segments.clear();
  }
}

WhisperResult _resultFromJson(Map<String, Object?> value) {
  final segments = (value['segments'] as List? ?? const [])
      .cast<Map>()
      .map((segment) {
        final data = segment.cast<String, Object?>();
        return _segmentFromJson(data);
      })
      .toList(growable: false);
  return WhisperResult(
    language: value['language']?.toString() ?? '',
    segments: segments,
  );
}

WhisperSegment _segmentFromJson(Map<String, Object?> data) => WhisperSegment(
  text: data['text']?.toString() ?? '',
  start: _centiseconds(data['start']),
  end: _centiseconds(data['end']),
);

Duration _centiseconds(Object? value) =>
    Duration(milliseconds: ((value as num?)?.toInt() ?? 0) * 10);
