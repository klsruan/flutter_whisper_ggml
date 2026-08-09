final class SelectedFile {
  const SelectedFile({required this.name, required this.path});

  final String name;
  final String path;
}

Future<SelectedFile?> pickModelFile() =>
    throw UnsupportedError('File selection is unavailable on this platform.');

Future<SelectedFile?> pickWavFile() =>
    throw UnsupportedError('File selection is unavailable on this platform.');

void releaseSelectedFile(SelectedFile? file) {}
