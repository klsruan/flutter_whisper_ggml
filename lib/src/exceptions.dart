/// Error returned by the native whisper.cpp bridge.
class WhisperException implements Exception {
  const WhisperException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => code == null
      ? 'WhisperException: $message'
      : 'WhisperException($code): $message';
}
