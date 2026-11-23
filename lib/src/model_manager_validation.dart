import 'model_catalog.dart';

void validateModelMetadata(WhisperModel model) {
  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model.id) ||
      model.sizeBytes <= 0 ||
      !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(model.sha256) ||
      !const {'http', 'https'}.contains(model.downloadUri.scheme)) {
    throw ArgumentError.value(model, 'model', 'Invalid model metadata.');
  }
}
