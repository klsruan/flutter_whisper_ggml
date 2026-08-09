import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one CI workflow covers every platform and rebuilds WebAssembly', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();

    expect(ci, contains('flutter build apk --release'));
    expect(ci, contains('flutter build linux --release'));
    expect(ci, contains('flutter build windows --release'));
    expect(ci, contains('bash tool/build_web_wasm.sh Release'));
    expect(ci, contains('flutter build web --release'));
    expect(ci, contains('backend: [CPU, VULKAN]'));
    expect(ci, contains('spirv-headers'));
    expect(ci, contains('libomp-dev'));
    expect(ci, contains('flutter build ios --simulator'));
    expect(ci, contains('flutter build ios --release --no-codesign'));
    expect(ci, contains('flutter build macos --release'));
    expect(ci, contains('runs-on: macos-15'));
    expect(File('.github/workflows/apple.yml').existsSync(), isFalse);
    expect(File('.github/workflows/release.yml').existsSync(), isFalse);
  });

  test('Web CI support ships a portable builder and isolation headers', () {
    final builder = File('tool/build_web_wasm.sh').readAsStringSync();
    final headers = File('example/web/_headers').readAsStringSync();

    expect(builder, contains('set -euo pipefail'));
    expect(builder, contains('emcmake cmake'));
    expect(builder, contains('flutter_whisper.wasm'));
    expect(
      File('lib/src/web_whisper_backend.dart').readAsStringSync(),
      contains('assets/packages/flutter_whisper_ggml/assets/web'),
    );
    expect(headers, contains('Cross-Origin-Opener-Policy: same-origin'));
    expect(headers, contains('Cross-Origin-Embedder-Policy: require-corp'));
  });

  test('publication excludes upstream media without Git ignore conflicts', () {
    final pubignore = File('.pubignore').readAsStringSync();
    final gitignore = File('.gitignore').readAsStringSync();

    expect(pubignore, contains('whisper/v1.9.2/samples/'));
    expect(gitignore, contains('!whisper/v1.9.2/samples/jfk.mp3'));
    expect(File('LICENSE').readAsStringSync(), contains('2026 Ruan Dias'));
  });
}
