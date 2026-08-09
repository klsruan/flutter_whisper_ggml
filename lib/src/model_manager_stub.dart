import 'model_catalog.dart';
import 'model_manager.dart' show WhisperModelDownloadCallback;

Future<String> prepareModel(
  WhisperModel model, {
  String? directoryPath,
  bool forceDownload = false,
  WhisperModelDownloadCallback? onProgress,
}) => throw UnsupportedError(
  'Automatic Whisper model downloads are unsupported on this platform.',
);
