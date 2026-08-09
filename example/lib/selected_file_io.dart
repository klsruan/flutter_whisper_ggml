import 'package:file_picker/file_picker.dart';

final class SelectedFile {
  const SelectedFile({required this.name, required this.path});

  final String name;
  final String path;
}

Future<SelectedFile?> pickModelFile() => _pick(['bin']);

Future<SelectedFile?> pickWavFile() => _pick(['wav']);

Future<SelectedFile?> _pick(List<String> extensions) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final path = file.path;
  if (path == null || path.isEmpty) return null;
  return SelectedFile(name: file.name, path: path);
}

void releaseSelectedFile(SelectedFile? file) {}
