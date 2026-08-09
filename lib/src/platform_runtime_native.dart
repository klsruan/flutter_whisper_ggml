import 'audio_decoder.dart';
import 'flutter_whisper_native.dart';
import 'models.dart';
import 'native_wav_audio_decoder.dart';
import 'whisper_backend.dart';

Future<WhisperBackend> loadBackend(
  String modelPath,
  WhisperModelConfig config, {
  void Function(int progress)? onProgress,
}) async {
  onProgress?.call(0);
  final backend = await FlutterWhisperNative.load(modelPath, config);
  onProgress?.call(100);
  return backend;
}

WhisperAudioDecoder createAudioDecoder() => NativeWavAudioDecoder();

List<WhisperDevice> get availableDevices =>
    FlutterWhisperNative.availableDevices;
