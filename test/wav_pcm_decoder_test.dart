import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_ggml/src/exceptions.dart';
import 'package:flutter_whisper_ggml/src/native_wav_audio_decoder.dart';
import 'package:flutter_whisper_ggml/src/wav_pcm_decoder.dart';

void main() {
  test('decodes PCM16 WAV and mixes stereo to mono', () {
    final wav = _pcm16Wav(
      sampleRate: 16000,
      channels: 2,
      samples: [32767, 32767, -32768, 0],
    );

    final decoded = decodeWavPcm(wav);

    expect(decoded, hasLength(2));
    expect(decoded[0], closeTo(32767 / 32768, 0.0001));
    expect(decoded[1], closeTo(-0.5, 0.0001));
  });

  test('resamples PCM16 WAV to 16 kHz', () {
    final wav = _pcm16Wav(
      sampleRate: 8000,
      channels: 1,
      samples: [0, 16384, 32767, 0],
    );

    final decoded = decodeWavPcm(wav);

    expect(decoded, hasLength(8));
    expect(decoded.first, 0);
    expect(decoded[2], closeTo(0.5, 0.0001));
  });

  test('decodes finite IEEE Float32 WAV samples', () {
    final wav = _float32Wav([0.25, -0.5, 1.5]);

    final decoded = decodeWavPcm(wav);

    expect(decoded, hasLength(3));
    expect(decoded[0], closeTo(0.25, 0.0001));
    expect(decoded[1], closeTo(-0.5, 0.0001));
    expect(decoded[2], 1);
  });

  test('rejects non-finite IEEE Float32 WAV samples', () {
    final wav = _float32Wav([double.nan]);

    expect(
      () => decodeWavPcm(wav),
      throwsA(
        isA<WhisperException>().having(
          (error) => error.message,
          'message',
          contains('non-finite'),
        ),
      ),
    );
  });

  test('rejects non-WAV data with a useful error', () {
    expect(() => decodeWavPcm(Uint8List(44)), throwsA(isA<WhisperException>()));
  });

  test('native decoder accepts WAV and rejects other extensions', () async {
    final directory = await Directory.systemTemp.createTemp('whisper_wav_');
    final wav = _pcm16Wav(
      sampleRate: 16000,
      channels: 1,
      samples: [0, 1000, -1000],
    );
    final wavFile = File('${directory.path}${Platform.pathSeparator}audio.wav');
    final mp3File = File('${directory.path}${Platform.pathSeparator}audio.mp3');
    await wavFile.writeAsBytes(wav);
    await mp3File.writeAsBytes(wav);
    final decoder = NativeWavAudioDecoder();
    try {
      expect(await decoder.decode(wavFile.path), hasLength(3));
      await expectLater(
        decoder.decode(mp3File.path),
        throwsA(
          isA<WhisperException>().having(
            (error) => error.message,
            'message',
            contains('only WAV'),
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Uint8List _pcm16Wav({
  required int sampleRate,
  required int channels,
  required List<int> samples,
}) {
  final dataLength = samples.length * 2;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(44 + index * 2, samples[index], Endian.little);
  }
  return bytes;
}

Uint8List _float32Wav(List<double> samples) {
  final dataLength = samples.length * 4;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 3, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 16000 * 4, Endian.little);
  data.setUint16(32, 4, Endian.little);
  data.setUint16(34, 32, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setFloat32(44 + index * 4, samples[index], Endian.little);
  }
  return bytes;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  bytes.setRange(offset, offset + value.length, value.codeUnits);
}
