import 'dart:convert';

import 'models.dart';

/// Supported text representations for a completed transcription.
enum WhisperOutputFormat { json, srt }

extension WhisperResultFormatting on WhisperResult {
  /// Returns a stable, versioned JSON-compatible representation.
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'language': language,
    'text': text.trim(),
    'segments': [
      for (final (index, segment) in segments.indexed)
        {
          'id': index + 1,
          'text': segment.text.trim(),
          'startMs': segment.start.inMilliseconds,
          'endMs': segment.end.inMilliseconds,
          'speakerTurnNext': segment.speakerTurnNext,
          'noSpeechProbability': _finite(segment.noSpeechProbability),
          'tokens': [
            for (final token in segment.tokens)
              {
                'id': token.id,
                'text': token.text,
                'probability': _finite(token.probability),
                'startMs': token.start.inMilliseconds,
                'endMs': token.end.inMilliseconds,
              },
          ],
        },
    ],
    'vadSegments': [
      for (final segment in vadSegments)
        {
          'startMs': segment.start.inMilliseconds,
          'endMs': segment.end.inMilliseconds,
        },
    ],
    if (timings case final value?)
      'timingsMs': {
        'sample': value.sample.inMicroseconds / 1000,
        'encode': value.encode.inMicroseconds / 1000,
        'decode': value.decode.inMicroseconds / 1000,
        'batchDecode': value.batchDecode.inMicroseconds / 1000,
        'prompt': value.prompt.inMicroseconds / 1000,
      },
  };

  /// Encodes [toJson] with deterministic indentation by default.
  String toJsonString({bool pretty = true}) =>
      (pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder())
          .convert(toJson());

  /// Encodes timestamped segments as SubRip subtitles.
  String toSrt() {
    final output = StringBuffer();
    var cue = 0;
    for (final segment in segments) {
      final text = segment.text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .trim();
      if (text.isEmpty) continue;
      final rawStartMs = segment.start.inMilliseconds;
      final startMs = rawStartMs.isNegative ? 0 : rawStartMs;
      final rawEndMs = segment.end.inMilliseconds;
      final endMs = rawEndMs < startMs ? startMs : rawEndMs;
      if (cue > 0) output.write('\n\n');
      output
        ..writeln(++cue)
        ..writeln('${_srtTime(startMs)} --> ${_srtTime(endMs)}')
        ..write(text);
    }
    return output.toString();
  }

  String format(WhisperOutputFormat format, {bool prettyJson = true}) =>
      switch (format) {
        WhisperOutputFormat.json => toJsonString(pretty: prettyJson),
        WhisperOutputFormat.srt => toSrt(),
      };
}

double _finite(double value) => value.isFinite ? value : 0;

String _srtTime(int milliseconds) {
  final hours = milliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (milliseconds ~/ Duration.millisecondsPerMinute) % 60;
  final seconds = (milliseconds ~/ Duration.millisecondsPerSecond) % 60;
  final millis = milliseconds % 1000;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')},'
      '${millis.toString().padLeft(3, '0')}';
}
