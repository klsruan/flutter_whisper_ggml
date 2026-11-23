import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';
import 'package:flutter_whisper_ggml/src/native_wav_audio_decoder.dart';

const _fixtures = 'build/native-smoke-fixtures';
const _wav = '$_fixtures/jfk.wav';
const _vad = WhisperVadConfig(modelPath: '$_fixtures/ggml-silero-v6.2.0.bin');

Future<FlutterWhisper> _load(String filename) async {
  final whisper = await FlutterWhisper.load(
    modelPath: '$_fixtures/$filename',
    config: const WhisperModelConfig(useGpu: false),
  );
  addTearDown(whisper.dispose);
  return whisper;
}

List<Object> _timestamps(WhisperResult result) => [
  for (final segment in result.segments) ...[
    segment.start,
    segment.end,
    for (final token in segment.tokens) ...[token.start, token.end],
  ],
];

void main() {
  test(
    'can cancel before native inference starts or from a live segment',
    () async {
      final whisper = await _load('ggml-tiny.en-q5_1.bin');
      final samples = await NativeWavAudioDecoder().decode(_wav);
      const config = WhisperTranscribeConfig(
        threads: 2,
        noContext: true,
        tokenTimestamps: true,
      );
      final cancelled = throwsA(
        isA<WhisperException>().having((error) => error.code, 'code', -4),
      );

      final pending = whisper.transcribe(samples, config: config);
      whisper.cancel();
      await expectLater(pending, cancelled);

      final filePending = whisper.transcribeFile(_wav, config: config);
      whisper.cancel();
      await expectLater(filePending, cancelled);

      final longer = Float32List(samples.length * 8);
      for (var offset = 0; offset < longer.length; offset += samples.length) {
        longer.setAll(offset, samples);
      }
      final live = <WhisperSegment>[];
      final progress = <int>[];
      await expectLater(
        whisper.transcribe(
          longer,
          config: config,
          onProgress: progress.add,
          onSegment: (segment) {
            live.add(segment);
            if (live.length == 1) whisper.cancel();
          },
        ),
        cancelled,
      );
      expect(live.first.text.trim(), isNotEmpty);
      expect(live.first.tokens.any((token) => token.end > token.start), isTrue);
      expect(progress, isNot(contains(100)));

      live.clear();
      final retried = await whisper.transcribeFile(
        _wav,
        config: config,
        onSegment: live.add,
      );
      expect(retried.text.toLowerCase(), contains('ask not'));
      expect(
        live.map((segment) => segment.text),
        retried.segments.map((segment) => segment.text),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'auto detects speech and transcribes with a multilingual model',
    () async {
      final whisper = await _load('ggml-tiny-q5_1.bin');
      final result = await whisper.transcribeFile(_wav);
      expect(result.language, 'en');
      expect(result.text.toLowerCase(), contains('ask not'));
    },
  );

  test(
    'English-only inference clears VAD state between requests',
    () async {
      final whisper = await _load('ggml-tiny.en-q5_1.bin');
      const config = WhisperTranscribeConfig(
        threads: 2,
        noContext: true,
        tokenTimestamps: true,
      );
      const withVad = WhisperTranscribeConfig(
        threads: 2,
        noContext: true,
        tokenTimestamps: true,
        vad: _vad,
      );

      final baseline = await whisper.transcribeFile(_wav, config: config);
      expect(baseline.language, 'en');
      expect(baseline.text.toLowerCase(), contains('ask not'));
      expect(baseline.segments.first.tokens, isNotEmpty);
      final speech = await whisper.transcribeFile(_wav, config: withVad);
      expect(speech.vadSegments, isNotEmpty);

      final silence = await whisper.transcribe(
        Float32List(32000),
        config: withVad,
      );
      expect(silence.segments, isEmpty);
      expect(silence.vadSegments, isEmpty);

      final speechAgain = await whisper.transcribeFile(_wav, config: withVad);
      expect(speechAgain.vadSegments, isNotEmpty);
      final withoutVad = await whisper.transcribeFile(_wav, config: config);
      expect(withoutVad.vadSegments, isEmpty);
      expect(_timestamps(withoutVad), _timestamps(baseline));

      await expectLater(
        whisper.transcribeFile(
          _wav,
          config: const WhisperTranscribeConfig(
            vad: WhisperVadConfig(modelPath: '$_fixtures/missing-vad.bin'),
          ),
        ),
        throwsA(isA<WhisperException>()),
      );
      final retried = await whisper.transcribeFile(_wav, config: withVad);
      expect(retried.vadSegments, isNotEmpty);
      expect(retried.text, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
