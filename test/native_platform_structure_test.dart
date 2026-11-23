import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares all implemented FFI platforms', () {
    final pubspec = File(
      'pubspec.yaml',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    for (final platform in ['android', 'ios', 'linux', 'macos']) {
      expect(pubspec, contains('      $platform:\n        ffiPlugin: true'));
    }
  });

  test('ships Android and Linux native build entry points', () {
    expect(File('android/build.gradle').existsSync(), isTrue);
    expect(File('android/src/main/AndroidManifest.xml').existsSync(), isTrue);
    expect(File('linux/CMakeLists.txt').existsSync(), isTrue);
    expect(File('src/CMakeLists.txt').existsSync(), isTrue);
  });

  test('Apple packages vendored XCFrameworks and privacy manifests', () {
    for (final platform in ['ios', 'macos']) {
      final contents = File(
        '$platform/flutter_whisper_ggml.podspec',
      ).readAsStringSync();
      expect(
        contents,
        contains(
          "s.vendored_frameworks = 'flutter_whisper_ggml_native.xcframework'",
        ),
      );
      expect(
        File('$platform/Resources/PrivacyInfo.xcprivacy').existsSync(),
        isTrue,
      );
    }
  });

  test('Apple CI covers simulator, device ARM64 and macOS builds', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    expect(workflow, contains('flutter build ios --simulator'));
    expect(workflow, contains('flutter build ios --release --no-codesign'));
    expect(workflow, contains('flutter build macos'));
  });
}
