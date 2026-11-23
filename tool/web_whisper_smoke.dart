import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_whisper_ggml/flutter_whisper.dart';
import 'package:flutter_whisper_ggml/src/platform_runtime_web.dart';
import 'package:web/web.dart' as web;

@JS('Promise.reject')
external JSPromise<JSAny?> _rejectStorageWrite(JSAny error);

Future<void> main() async {
  Map<String, Object?> result;
  try {
    final storage = web.window.sessionStorage;
    if (storage.getItem('whisper-cache-reload') == null) {
      await WhisperModelManager.clearWebCache();
      await _testTranscription();
      await _setModelNetwork(false);
      storage.setItem('whisper-cache-reload', 'yes');
      web.window.location.reload();
      return;
    }
    await _testPersistentCache();
    result = {'ok': true};
  } catch (error, stackTrace) {
    result = {'ok': false, 'error': '$error\n$stackTrace'};
  }
  await web.window
      .fetch(
        '/__whisper_test_result'.toJS,
        web.RequestInit(method: 'POST', body: jsonEncode(result).toJS),
      )
      .toDart;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

WhisperModel get _model => WhisperModel(
  id: WhisperModels.tinyEnQ5_1.id,
  sizeBytes: WhisperModels.tinyEnQ5_1.sizeBytes,
  sha256: WhisperModels.tinyEnQ5_1.sha256,
  baseUrl: Uri.base.resolve('/web_fixtures').toString(),
);

Future<void> _setModelNetwork(bool enabled) async {
  final response = await web.window
      .fetch(
        '/__whisper_model_network/${enabled ? 'on' : 'off'}'.toJS,
        web.RequestInit(method: 'POST'),
      )
      .toDart;
  _check(response.ok, 'Could not change fixture network mode.');
}

Future<void> _prepare({bool forceDownload = false}) async {
  final url = await WhisperModelManager.prepare(
    _model,
    forceDownload: forceDownload,
  );
  WhisperModelManager.releasePreparedModel(url);
}

Future<void> _expectBlockedDownload({bool forceDownload = false}) async {
  try {
    await _prepare(forceDownload: forceDownload);
  } on WhisperException catch (error) {
    _check(error.message.contains('HTTP 503'), 'Unexpected error: $error');
    return;
  }
  throw StateError('Expected a model download while the route was blocked.');
}

Future<void> _testPersistentCache() async {
  final whisper = await FlutterWhisper.loadModel(
    model: _model,
    config: const WhisperModelConfig(useGpu: false),
  );
  try {
    final result = await whisper.transcribeFile('/web_fixtures/jfk.wav');
    _check(
      result.text.toLowerCase().contains('ask not'),
      'Could not transcribe using the cached model after a reload.',
    );
  } finally {
    await whisper.dispose();
  }

  await _expectBlockedDownload(forceDownload: true);
  await _prepare(); // The failed forced refresh preserves the verified copy.
  final cache = await web.window.caches
      .open('flutter_whisper_ggml.models.v1')
      .toDart;
  final entry = (await cache.keys().toDart).toDart.single;
  // Keep the size intact so only SHA-256 can distinguish this entry.
  await cache.put(entry, web.Response(Uint8List(_model.sizeBytes).toJS)).toDart;
  await _expectBlockedDownload();

  await _setModelNetwork(true);
  await _prepare();
  await _setModelNetwork(false);
  await _prepare();
  await WhisperModelManager.clearWebCache();
  await _expectBlockedDownload();

  await _setModelNetwork(true);
  final prototype =
      (globalContext['Cache'] as JSObject)['prototype'] as JSObject;
  final put = prototype['put'];
  prototype['put'] = ((JSAny? request, JSAny? response) => _rejectStorageWrite(
    web.DOMException('Storage full', 'QuotaExceededError'),
  )).toJS;
  try {
    await _prepare();
  } finally {
    prototype['put'] = put;
  }
  await _setModelNetwork(false);
  await _expectBlockedDownload();
}

Future<void> _testTranscription() async {
  final modelProgress = <int>[];
  final downloadProgress = <int>[];
  final whisper = await FlutterWhisper.loadModel(
    model: _model,
    config: const WhisperModelConfig(useGpu: false),
    onDownloadProgress: (progress) => downloadProgress.add(progress.percent),
    onModelProgress: modelProgress.add,
  );
  try {
    _check(modelProgress.contains(100), 'Model progress did not reach 100%.');
    _check(
      downloadProgress.first == 0 && downloadProgress.last == 100,
      'Unexpected download progress: $downloadProgress',
    );
    const wavUrl = '/web_fixtures/jfk.wav';
    const config = WhisperTranscribeConfig(
      threads: 2,
      initialPrompt: 'John F. Kennedy inaugural address.',
      noContext: true,
      tokenTimestamps: true,
    );
    final progress = <int>[];
    final live = <WhisperSegment>[];
    final result = await whisper.transcribeFile(
      wavUrl,
      config: config,
      onProgress: progress.add,
      onSegment: live.add,
    );
    _check(result.language == 'en', 'Unexpected language: ${result.language}');
    _check(
      result.text.toLowerCase().contains('ask not'),
      'Unexpected text: ${result.text}',
    );
    final first = result.segments.first;
    _check(first.end > first.start, 'Invalid segment timestamps.');
    _check(
      first.tokens.any((token) => token.end > token.start),
      'Missing token timestamps.',
    );
    _check(
      live.isNotEmpty && live.first.tokens.isNotEmpty,
      'Missing live segment tokens.',
    );
    _check(
      progress.isNotEmpty && progress.first == 0 && progress.last == 100,
      'Unexpected transcription progress: $progress',
    );

    final samples = await createAudioDecoder().decode(wavUrl);
    final longer = Float32List(samples.length * 12);
    for (var offset = 0; offset < longer.length; offset += samples.length) {
      longer.setAll(offset, samples);
    }
    var cancelled = false;
    final cancelledProgress = <int>[];
    try {
      await whisper.transcribe(
        longer,
        config: config,
        onProgress: cancelledProgress.add,
        onSegment: (_) {
          if (cancelled) return;
          cancelled = true;
          whisper.cancel();
        },
      );
      throw StateError(
        'The active transcription completed after cancellation.',
      );
    } on WhisperException catch (error) {
      _check(
        error.message == 'Transcription cancelled.',
        'Unexpected error: $error',
      );
    }
    _check(
      cancelled && !cancelledProgress.contains(100),
      'Cancellation did not interrupt active inference.',
    );
    final retried = await whisper.transcribe(
      samples,
      config: const WhisperTranscribeConfig(threads: 1, singleSegment: true),
    );
    _check(
      retried.text.toLowerCase().contains('ask not'),
      'Model reuse failed after cancellation.',
    );
    _check(
      retried.segments.length == 1,
      'Single-segment decoding was ignored.',
    );
  } finally {
    await whisper.dispose();
  }
}
