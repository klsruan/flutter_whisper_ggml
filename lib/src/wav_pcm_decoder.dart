import 'dart:math' as math;
import 'dart:typed_data';

import 'exceptions.dart';

/// Decodes a RIFF/WAVE PCM stream and normalizes it for whisper.cpp.
///
/// Supports little-endian PCM16, PCM32 and IEEE Float32, mixes all channels to
/// mono and resamples to 16 kHz when necessary.
Float32List decodeWavPcm(Uint8List bytes, {int targetSampleRate = 16000}) {
  if (bytes.length < 44 ||
      _ascii(bytes, 0, 4) != 'RIFF' ||
      _ascii(bytes, 8, 4) != 'WAVE') {
    throw const WhisperException('The selected file is not a RIFF/WAVE file.');
  }

  final data = ByteData.sublistView(bytes);
  int? audioFormat;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  int? blockAlign;
  int? dataOffset;
  int? dataLength;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = _ascii(bytes, offset, 4);
    final chunkLength = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;
    if (chunkStart + chunkLength > bytes.length) {
      throw const WhisperException('The WAV file contains a truncated chunk.');
    }
    if (chunkId == 'fmt ') {
      if (chunkLength < 16) {
        throw const WhisperException('The WAV fmt chunk is invalid.');
      }
      audioFormat = data.getUint16(chunkStart, Endian.little);
      channels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
      blockAlign = data.getUint16(chunkStart + 12, Endian.little);
      bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkStart;
      dataLength = chunkLength;
    }
    offset = chunkStart + chunkLength + (chunkLength.isOdd ? 1 : 0);
  }

  if (audioFormat == null ||
      channels == null ||
      sampleRate == null ||
      bitsPerSample == null ||
      blockAlign == null ||
      dataOffset == null ||
      dataLength == null) {
    throw const WhisperException('The WAV file is missing fmt or data chunks.');
  }
  if (channels < 1 ||
      channels > 32 ||
      sampleRate < 1000 ||
      sampleRate > 384000 ||
      dataLength == 0) {
    throw const WhisperException('The WAV file has no decodable audio.');
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  final supported =
      (audioFormat == 1 && (bitsPerSample == 16 || bitsPerSample == 32)) ||
      (audioFormat == 3 && bitsPerSample == 32);
  if (!supported || bytesPerSample == 0) {
    throw WhisperException(
      'Unsupported WAV encoding (format $audioFormat, $bitsPerSample-bit). '
      'Convert the input to mono 16 kHz PCM16 WAV.',
    );
  }

  final frameSize = bytesPerSample * channels;
  if (blockAlign != frameSize || dataLength % frameSize != 0) {
    throw const WhisperException(
      'The WAV block alignment or data length is invalid.',
    );
  }
  final frameCount = dataLength ~/ frameSize;
  final mono = Float32List(frameCount);
  for (var frame = 0; frame < frameCount; frame++) {
    var mixed = 0.0;
    final frameOffset = dataOffset + frame * frameSize;
    for (var channel = 0; channel < channels; channel++) {
      final sampleOffset = frameOffset + channel * bytesPerSample;
      if (audioFormat == 3) {
        mixed += data.getFloat32(sampleOffset, Endian.little);
      } else if (bitsPerSample == 16) {
        mixed += data.getInt16(sampleOffset, Endian.little) / 32768.0;
      } else {
        mixed += data.getInt32(sampleOffset, Endian.little) / 2147483648.0;
      }
    }
    final sample = mixed / channels;
    if (!sample.isFinite) {
      throw const WhisperException('The WAV file contains non-finite samples.');
    }
    mono[frame] = sample.clamp(-1.0, 1.0);
  }

  if (sampleRate == targetSampleRate || mono.isEmpty) return mono;
  final outputLength = math.max(
    1,
    (mono.length * targetSampleRate / sampleRate).round(),
  );
  final output = Float32List(outputLength);
  final scale = sampleRate / targetSampleRate;
  for (var index = 0; index < outputLength; index++) {
    final source = index * scale;
    final left = source.floor().clamp(0, mono.length - 1);
    final right = math.min(left + 1, mono.length - 1);
    final fraction = source - left;
    output[index] = mono[left] + (mono[right] - mono[left]) * fraction;
  }
  return output;
}

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));
