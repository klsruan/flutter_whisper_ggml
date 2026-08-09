import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final class SelectedFile {
  const SelectedFile({required this.name, required this.path});

  final String name;
  final String path;
}

Future<SelectedFile?> pickModelFile() => _pick('.bin');

Future<SelectedFile?> pickWavFile() => _pick('.wav,audio/wav');

Future<SelectedFile?> _pick(String accept) {
  final completer = Completer<SelectedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;

  void onChange(web.Event _) {
    final file = input.files?.item(0);
    completer.complete(
      file == null
          ? null
          : SelectedFile(name: file.name, path: web.URL.createObjectURL(file)),
    );
  }

  input.addEventListener('change', onChange.toJS);
  input.click();
  return completer.future;
}

void releaseSelectedFile(SelectedFile? file) {
  if (file != null && file.path.startsWith('blob:')) {
    web.URL.revokeObjectURL(file.path);
  }
}
