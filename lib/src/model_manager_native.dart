import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'exceptions.dart';
import 'model_catalog.dart';
import 'model_manager.dart'
    show WhisperModelDownloadCallback, WhisperModelDownloadProgress;

final _inFlight = <String, Future<String>>{};

Future<String> prepareModel(
  WhisperModel model, {
  String? directoryPath,
  bool forceDownload = false,
  WhisperModelDownloadCallback? onProgress,
}) async {
  _validateModel(model);
  final directory = directoryPath == null
      ? Directory(
          '${(await getApplicationSupportDirectory()).path}'
          '${Platform.pathSeparator}flutter_whisper_ggml'
          '${Platform.pathSeparator}models',
        )
      : Directory(directoryPath);
  await directory.create(recursive: true);
  final target = File(
    '${directory.path}${Platform.pathSeparator}${model.fileName}',
  );

  if (!forceDownload && await _isValidCachedModel(target, model)) {
    onProgress?.call(
      WhisperModelDownloadProgress(
        receivedBytes: model.sizeBytes,
        totalBytes: model.sizeBytes,
      ),
    );
    return target.path;
  }

  final key = target.absolute.path;
  final active = _inFlight[key];
  if (active != null) return active;

  final download = _download(model, target, onProgress);
  _inFlight[key] = download;
  try {
    return await download;
  } finally {
    _inFlight.remove(key);
  }
}

Future<String> _download(
  WhisperModel model,
  File target,
  WhisperModelDownloadCallback? onProgress,
) async {
  final part = File(
    '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
  );
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  RandomAccessFile? output;
  try {
    final request = await client.getUrl(model.downloadUri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'flutter_whisper_ggml/0.0.1',
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw WhisperException(
        'Model download failed with HTTP ${response.statusCode}: '
        '${model.downloadUri}',
      );
    }
    if (response.contentLength >= 0 &&
        response.contentLength != model.sizeBytes) {
      throw WhisperException(
        'Unexpected model size from the server: ${response.contentLength} '
        'bytes (expected ${model.sizeBytes}).',
      );
    }

    var received = 0;
    Digest? digest;
    final digestOutput = ChunkedConversionSink<Digest>.withCallback((values) {
      digest = values.single;
    });
    final digestInput = sha256.startChunkedConversion(digestOutput);
    final progressClock = Stopwatch()..start();
    output = await part.open(mode: FileMode.write);
    onProgress?.call(
      WhisperModelDownloadProgress(
        receivedBytes: 0,
        totalBytes: model.sizeBytes,
      ),
    );

    await for (final chunk in response) {
      received += chunk.length;
      if (received > model.sizeBytes) {
        throw const WhisperException(
          'Model download is larger than the expected file.',
        );
      }
      digestInput.add(chunk);
      await output.writeFrom(chunk);
      if (progressClock.elapsedMilliseconds >= 100 ||
          received == model.sizeBytes) {
        progressClock.reset();
        onProgress?.call(
          WhisperModelDownloadProgress(
            receivedBytes: received,
            totalBytes: model.sizeBytes,
          ),
        );
      }
    }
    digestInput.close();
    await output.flush();
    await output.close();
    output = null;

    if (received != model.sizeBytes) {
      throw WhisperException(
        'Incomplete model download: $received of ${model.sizeBytes} bytes.',
      );
    }
    if (digest.toString().toLowerCase() != model.sha256.toLowerCase()) {
      throw const WhisperException(
        'The downloaded model failed SHA-256 verification.',
      );
    }

    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    await File(
      '${target.path}.sha256',
    ).writeAsString(model.sha256, flush: true);
    onProgress?.call(
      WhisperModelDownloadProgress(
        receivedBytes: model.sizeBytes,
        totalBytes: model.sizeBytes,
      ),
    );
    return target.path;
  } on WhisperException {
    rethrow;
  } catch (error) {
    throw WhisperException('Could not download ${model.id}: $error');
  } finally {
    client.close(force: true);
    if (output != null) await output.close();
    if (await part.exists()) await part.delete();
  }
}

Future<bool> _isValidCachedModel(File file, WhisperModel model) async {
  if (!await file.exists() || await file.length() != model.sizeBytes) {
    return false;
  }
  final marker = File('${file.path}.sha256');
  if (await marker.exists() &&
      (await marker.readAsString()).trim().toLowerCase() ==
          model.sha256.toLowerCase()) {
    return true;
  }

  Digest? digest;
  final digestOutput = ChunkedConversionSink<Digest>.withCallback((values) {
    digest = values.single;
  });
  final digestInput = sha256.startChunkedConversion(digestOutput);
  await for (final chunk in file.openRead()) {
    digestInput.add(chunk);
  }
  digestInput.close();
  if (digest.toString().toLowerCase() != model.sha256.toLowerCase()) {
    return false;
  }
  await marker.writeAsString(model.sha256, flush: true);
  return true;
}

void _validateModel(WhisperModel model) {
  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model.id) ||
      model.sizeBytes <= 0 ||
      !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(model.sha256) ||
      !const {'http', 'https'}.contains(model.downloadUri.scheme)) {
    throw ArgumentError.value(model, 'model', 'Invalid model metadata.');
  }
}
