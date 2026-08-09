import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';

void main() {
  test('official catalog is complete and internally consistent', () {
    final readme = File('README.md').readAsStringSync();

    expect(WhisperModels.values, hasLength(34));
    expect(
      WhisperModels.values.map((model) => model.id).toSet(),
      hasLength(WhisperModels.values.length),
    );
    for (final model in WhisperModels.values) {
      expect(model.downloadUri.path, endsWith(model.fileName));
      expect(model.sizeBytes, greaterThan(30 * 1024 * 1024));
      expect(model.sha256, hasLength(64));
      expect(WhisperModels.byId(model.id), same(model));
      expect(readme, contains(model.downloadUri.toString()));
    }
    expect(WhisperModels.byId('does-not-exist'), isNull);
  });

  test('downloads, verifies and reuses a model cache atomically', () async {
    final bytes = List<int>.generate(4096, (index) => index % 251);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'flutter_whisper_model_download_',
    );
    var requests = 0;
    final subscription = server.listen((request) async {
      requests++;
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    final model = WhisperModel(
      id: 'fixture',
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    final progress = <WhisperModelDownloadProgress>[];

    try {
      final firstPath = await WhisperModelManager.prepare(
        model,
        directoryPath: directory.path,
        onProgress: progress.add,
      );
      final secondPath = await WhisperModelManager.prepare(
        model,
        directoryPath: directory.path,
      );

      expect(secondPath, firstPath);
      expect(await File(firstPath).readAsBytes(), bytes);
      expect(await File('$firstPath.sha256').readAsString(), model.sha256);
      expect(requests, 1);
      expect(progress.first.receivedBytes, 0);
      expect(progress.last.percent, 100);
      expect(
        directory.listSync().where((entry) => entry.path.endsWith('.part')),
        isEmpty,
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  test('rejects a corrupt download without leaving a partial model', () async {
    final bytes = List<int>.filled(2048, 7);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'flutter_whisper_bad_download_',
    );
    final subscription = server.listen((request) async {
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    final model = WhisperModel(
      id: 'corrupt-fixture',
      sizeBytes: bytes.length,
      sha256: List.filled(64, '0').join(),
      baseUrl: 'http://${server.address.address}:${server.port}',
    );

    try {
      await expectLater(
        WhisperModelManager.prepare(model, directoryPath: directory.path),
        throwsA(
          isA<WhisperException>().having(
            (error) => error.message,
            'message',
            contains('SHA-256'),
          ),
        ),
      );
      expect(directory.listSync(), isEmpty);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
