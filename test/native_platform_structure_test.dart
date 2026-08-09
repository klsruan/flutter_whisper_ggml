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

  test('ships complete iOS and macOS CocoaPods source forwarders', () {
    const requiredSources = [
      'flutter_whisper_bridge.cpp',
      'whisper.cpp',
      'ggml.c',
      'ggml_backend_reg.cpp',
      'cpu_ggml_cpu.cpp',
      'cpu_ops.cpp',
      'cpu_arch_quants.c',
      'cpu_arch_repack.cpp',
    ];

    for (final platform in ['ios', 'macos']) {
      final podspec = File('$platform/flutter_whisper_ggml.podspec');
      expect(podspec.existsSync(), isTrue);
      final contents = podspec.readAsStringSync();
      expect(contents, contains("s.frameworks       = 'Accelerate'"));
      expect(contents, contains("'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17'"));
      expect(contents, contains('WHISPER_VERSION=\\"1.9.2\\"'));
      expect(contents, isNot(contains('_XOPEN_SOURCE')));
      expect(
        File('$platform/Resources/PrivacyInfo.xcprivacy').existsSync(),
        isTrue,
      );

      final forwarders = Directory(
        '$platform/Classes',
      ).listSync().whereType<File>().toList();
      expect(forwarders, isNotEmpty);
      for (final forwarder in forwarders) {
        final includes = RegExp(
          r'^#include\s+"([^"]+)"',
          multiLine: true,
        ).allMatches(forwarder.readAsStringSync());
        expect(includes, isNotEmpty, reason: '${forwarder.path} is empty');
        for (final include in includes) {
          final target = File.fromUri(
            forwarder.parent.uri.resolve(include.group(1)!),
          );
          expect(
            target.existsSync(),
            isTrue,
            reason: '${forwarder.path} points to missing ${target.path}',
          );
        }
      }

      for (final source in requiredSources) {
        expect(
          File('$platform/Classes/$source').existsSync(),
          isTrue,
          reason: '$platform is missing $source',
        );
      }
    }

    final iosSources =
        Directory('ios/Classes')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    final macosSources =
        Directory('macos/Classes')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    expect(macosSources, iosSources);
  });

  test('Apple CI covers simulator, device ARM64 and macOS builds', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    expect(workflow, contains('flutter build ios --simulator'));
    expect(workflow, contains('flutter build ios --release --no-codesign'));
    expect(workflow, contains('flutter build macos'));
  });
}
