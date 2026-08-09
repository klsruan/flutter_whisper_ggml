import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';

final class FakeBackend implements WhisperBackend {
  int transcribeCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  final completers = <Completer<WhisperResult>>[];

  @override
  Future<WhisperResult> transcribe(
    Float32List samples,
    WhisperTranscribeConfig config, {
    void Function(int progress)? onProgress,
    void Function(WhisperSegment segment)? onSegment,
  }) {
    transcribeCalls++;
    final completer = Completer<WhisperResult>();
    completers.add(completer);
    return completer.future;
  }

  @override
  void cancel() => cancelCalls++;

  @override
  void dispose() => disposeCalls++;
}

final class FakeAudioDecoder implements WhisperAudioDecoder {
  String? decodedPath;
  bool cancelled = false;

  @override
  Future<Float32List> decode(String inputPath) async {
    decodedPath = inputPath;
    return Float32List(160);
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

const result = WhisperResult(
  language: 'en',
  segments: [
    WhisperSegment(
      text: ' hello',
      start: Duration.zero,
      end: Duration(seconds: 1),
    ),
  ],
);

void main() {
  test('creates model configuration for CPU and GPU devices', () {
    const cpu = WhisperDevice(
      index: 0,
      gpuIndex: null,
      name: 'CPU',
      description: 'Test CPU',
      type: WhisperDeviceType.cpu,
      freeMemory: 0,
      totalMemory: 0,
    );
    const gpu = WhisperDevice(
      index: 1,
      gpuIndex: 2,
      name: 'Vulkan2',
      description: 'Test GPU',
      type: WhisperDeviceType.gpu,
      freeMemory: 1024,
      totalMemory: 2048,
    );

    expect(WhisperModelConfig.forDevice(cpu).useGpu, isFalse);
    final gpuConfig = WhisperModelConfig.forDevice(gpu);
    expect(gpuConfig.useGpu, isTrue);
    expect(gpuConfig.gpuDevice, 2);
  });

  test('serializes transcription calls for one context', () async {
    final backend = FakeBackend();
    final whisper = FlutterWhisper.withBackend(backend);

    final first = whisper.transcribe(Float32List(160));
    final second = whisper.transcribe(Float32List(160));
    await Future<void>.delayed(Duration.zero);
    expect(backend.transcribeCalls, 1);

    backend.completers.first.complete(result);
    expect(await first, same(result));
    await Future<void>.delayed(Duration.zero);
    expect(backend.transcribeCalls, 2);

    backend.completers.last.complete(result);
    expect(await second, same(result));
  });

  test('forwards cancellation to the backend', () {
    final backend = FakeBackend();
    final decoder = FakeAudioDecoder();
    FlutterWhisper.withBackend(backend, audioDecoder: decoder).cancel();
    expect(backend.cancelCalls, 1);
    expect(decoder.cancelled, isTrue);
  });

  test('transcribeFile decodes media before inference', () async {
    final backend = FakeBackend();
    final decoder = FakeAudioDecoder();
    final whisper = FlutterWhisper.withBackend(backend, audioDecoder: decoder);

    final future = whisper.transcribeFile('sample.wav');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(decoder.decodedPath, 'sample.wav');
    expect(backend.transcribeCalls, 1);
    backend.completers.single.complete(result);
    expect(await future, same(result));
  });

  test('dispose is idempotent and rejects later operations', () async {
    final backend = FakeBackend();
    final whisper = FlutterWhisper.withBackend(backend);

    await whisper.dispose();
    await whisper.dispose();

    expect(backend.disposeCalls, 1);
    expect(
      () => whisper.transcribe(Float32List(1)),
      throwsA(isA<StateError>()),
    );
    expect(whisper.cancel, throwsA(isA<StateError>()));
  });

  test('result joins segment text without changing whitespace', () {
    const value = WhisperResult(
      language: 'pt',
      segments: [
        WhisperSegment(
          text: ' Olá',
          start: Duration.zero,
          end: Duration(seconds: 1),
        ),
        WhisperSegment(
          text: ' mundo',
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
        ),
      ],
    );
    expect(value.text, ' Olá mundo');
  });

  test('rejects header-only upstream test models', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flutter_whisper_test_',
    );
    final model = File(
      '${directory.path}${Platform.pathSeparator}for-tests-model.bin',
    );
    await model.writeAsBytes(List<int>.filled(1024, 0));
    try {
      await expectLater(
        FlutterWhisper.load(modelPath: model.path),
        throwsA(
          isA<WhisperException>().having(
            (error) => error.message,
            'message',
            contains('headers only'),
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('rejects large files with invalid GGML magic', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flutter_whisper_model_',
    );
    final model = File('${directory.path}${Platform.pathSeparator}model.bin');
    await model.writeAsBytes(List<int>.filled(1024 * 1024, 0));
    try {
      await expectLater(
        FlutterWhisper.load(modelPath: model.path),
        throwsA(
          isA<WhisperException>().having(
            (error) => error.message,
            'message',
            contains('bad magic'),
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
