import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

import 'exceptions.dart';
import 'model_catalog.dart';
import 'model_manager.dart'
    show WhisperModelDownloadCallback, WhisperModelDownloadProgress;
import 'model_manager_validation.dart';

const _cacheName = 'flutter_whisper_ggml.models.v1';
final _inFlight = <(String, bool), _Preparation>{};
Future<void>? _clearing;
int _generation = 0;

final class _Preparation {
  final progress = StreamController<int>.broadcast(sync: true);
  late final Future<web.Blob> result;
}

Future<String> prepareModel(
  WhisperModel model, {
  String? directoryPath,
  bool forceDownload = false,
  WhisperModelDownloadCallback? onProgress,
}) async {
  validateModelMetadata(model);
  // A clearing operation invalidates old requests before removing their cache.
  while (true) {
    final clearing = _clearing;
    if (clearing == null) break;
    await clearing.catchError((Object _) {});
  }
  final key =
      '${web.window.location.origin}/.flutter-whisper-models/'
      '${model.sizeBytes}/${model.sha256.toLowerCase()}';
  final requestKey = (key, forceDownload);
  final preparation = _inFlight.putIfAbsent(requestKey, () {
    final pending = _Preparation();
    pending.result =
        _prepareBlob(
          key,
          model,
          forceDownload: forceDownload,
          generation: _generation,
          onBytes: pending.progress.add,
        ).whenComplete(() {
          if (identical(_inFlight[requestKey], pending)) {
            _inFlight.remove(requestKey);
          }
          unawaited(pending.progress.close());
        });
    return pending;
  });

  final subscription = onProgress == null
      ? null
      : preparation.progress.stream.listen((received) {
          onProgress(
            WhisperModelDownloadProgress(
              receivedBytes: received,
              totalBytes: model.sizeBytes,
            ),
          );
        });
  try {
    final blob = await preparation.result;
    onProgress?.call(
      WhisperModelDownloadProgress(
        receivedBytes: model.sizeBytes,
        totalBytes: model.sizeBytes,
      ),
    );
    return web.URL.createObjectURL(blob);
  } finally {
    await subscription?.cancel();
  }
}

Future<void> clearWebModelCache() {
  if (_clearing case final clearing?) return clearing;
  _generation++;
  _inFlight.clear();
  final clearing = Future<void>.sync(() async {
    try {
      await web.window.caches.delete(_cacheName).toDart;
    } catch (error) {
      throw WhisperException('Could not clear the browser model cache: $error');
    }
  }).whenComplete(() => _clearing = null);
  _clearing = clearing;
  return clearing;
}

void releasePreparedModel(String path) {
  if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
}

Future<web.Blob> _prepareBlob(
  String key,
  WhisperModel model, {
  required bool forceDownload,
  required int generation,
  required void Function(int) onBytes,
}) async {
  web.Cache? cache;
  try {
    cache = await web.window.caches.open(_cacheName).toDart;
  } catch (_) {
    // Browser storage can be unavailable while a network load still works.
  }
  if (cache != null && !forceDownload && generation == _generation) {
    try {
      final cached = await cache.match(key.toJS).toDart;
      if (cached != null) {
        final blob = await cached.blob().toDart;
        if (blob.size == model.sizeBytes) {
          await _verify(blob.stream(), model);
          return blob;
        }
      }
    } catch (_) {
      // A failed read or integrity check falls back to a verified download.
    }
  }

  final blob = await _download(model, onBytes);
  if (cache != null && generation == _generation) {
    try {
      await cache.put(key.toJS, web.Response(blob)).toDart;
    } catch (_) {
      // Quota and storage failures must not prevent use of a verified model.
    }
  }
  return blob;
}

Future<web.Blob> _download(
  WhisperModel model,
  void Function(int) onBytes,
) async {
  final controller = web.AbortController();
  try {
    final response = await web.window
        .fetch(
          model.downloadUri.toString().toJS,
          web.RequestInit(cache: 'no-store', signal: controller.signal),
        )
        .toDart;
    if (!response.ok) {
      throw WhisperException(
        'Model download failed with HTTP ${response.status}: ${model.downloadUri}',
      );
    }
    // Cloning tees the stream and replaces the original response's body.
    final copy = response.clone();
    final body = response.body;
    if (body == null) {
      throw const WhisperException('The model response has no body.');
    }
    onBytes(0);
    // Consume both branches concurrently. The hash branch reads one chunk at a
    // time while the browser constructs the Blob for caching and model loading.
    final results = await Future.wait<web.Blob?>([
      copy.blob().toDart,
      _verify(body, model, onBytes: onBytes).then((_) => null),
    ], eagerError: true);
    return results.first!;
  } on WhisperException {
    controller.abort();
    rethrow;
  } catch (error) {
    controller.abort();
    throw WhisperException('Could not download ${model.id}: $error');
  }
}

Future<void> _verify(
  web.ReadableStream stream,
  WhisperModel model, {
  void Function(int)? onBytes,
}) async {
  final reader = stream.getReader() as web.ReadableStreamDefaultReader;
  Digest? digest;
  final input = sha256.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback(
      (values) => digest = values.single,
    ),
  );
  var received = 0;
  try {
    while (true) {
      final next = await reader.read().toDart;
      if (next.done) break;
      final bytes = (next.value as JSUint8Array).toDart;
      received += bytes.length;
      if (received > model.sizeBytes) {
        throw const WhisperException('The model is larger than expected.');
      }
      input.add(bytes);
      if (received < model.sizeBytes) onBytes?.call(received);
    }
    input.close();
  } finally {
    reader.releaseLock();
  }
  if (received != model.sizeBytes ||
      digest.toString() != model.sha256.toLowerCase()) {
    throw const WhisperException(
      'The model failed size or SHA-256 verification.',
    );
  }
}
