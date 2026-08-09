import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';

void main() {
  const result = WhisperResult(
    language: 'pt',
    segments: [
      WhisperSegment(
        text: ' Primeira fala. ',
        start: Duration(milliseconds: 1234),
        end: Duration(milliseconds: 4567),
        noSpeechProbability: 0.1,
        tokens: [
          WhisperToken(
            id: 42,
            text: ' Primeira',
            probability: 0.95,
            start: Duration(milliseconds: 1234),
            end: Duration(milliseconds: 2500),
          ),
        ],
      ),
      WhisperSegment(
        text: 'Segunda\nlinha.',
        start: Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 4),
        end: Duration(hours: 1, minutes: 2, seconds: 5, milliseconds: 6),
      ),
    ],
    vadSegments: [
      WhisperVadSegment(
        start: Duration(milliseconds: 1000),
        end: Duration(milliseconds: 5000),
      ),
    ],
  );

  test('serializes a stable versioned JSON result', () {
    final value = jsonDecode(result.toJsonString()) as Map<String, dynamic>;

    expect(value['schemaVersion'], 1);
    expect(value['language'], 'pt');
    expect(value['segments'], hasLength(2));
    expect(value['segments'][0]['startMs'], 1234);
    expect(value['segments'][0]['tokens'][0]['id'], 42);
    expect(value['vadSegments'][0]['endMs'], 5000);
  });

  test('serializes valid SRT cues and preserves multiline text', () {
    expect(
      result.toSrt(),
      '1\n00:00:01,234 --> 00:00:04,567\nPrimeira fala.\n\n'
      '2\n01:02:03,004 --> 01:02:05,006\nSegunda\nlinha.',
    );
  });

  test('format selects JSON or SRT', () {
    expect(result.format(WhisperOutputFormat.srt), startsWith('1\n'));
    expect(
      jsonDecode(result.format(WhisperOutputFormat.json)),
      isA<Map<String, dynamic>>(),
    );
  });

  test('normalizes invalid SRT timestamp ranges', () {
    const invalidRange = WhisperResult(
      language: 'pt',
      segments: [
        WhisperSegment(
          text: 'Intervalo normalizado',
          start: Duration(milliseconds: -500),
          end: Duration(milliseconds: -1000),
        ),
      ],
    );

    expect(
      invalidRange.toSrt(),
      '1\n00:00:00,000 --> 00:00:00,000\nIntervalo normalizado',
    );
  });
}
