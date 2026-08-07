import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper/flutter_whisper.dart';
import 'package:http/http.dart' as http;

/// Minimal fake http.Client — only `send` + `close` needed (rest is
/// concrete on the base class).
class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest req) handler;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    return handler(request);
  }
}

http.StreamedResponse _resp(
  int status,
  List<List<int>> chunks, {
  int? contentLength,
}) {
  return http.StreamedResponse(
    Stream<List<int>>.fromIterable(chunks),
    status,
    contentLength: contentLength ?? chunks.fold<int>(0, (a, b) => a + b.length),
    request: http.Request('GET', Uri.parse('http://fake')),
  );
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('whisper_dl_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  WhisperDownloader downloader(http.Client client) =>
      WhisperDownloader(directory: tmp.path, client: client);

  WhisperDownloadConfig cfg({int retries = 3, bool verify = false}) =>
      WhisperDownloadConfig(maxRetries: retries, verifyIntegrity: verify);

  test('progress emits 0→1 and file lands', () async {
    final client = _FakeClient((req) async {
      return _resp(200, [List.filled(50, 1), List.filled(50, 2)],
          contentLength: 100);
    });
    final fractions = <double>[];
    final path = await downloader(client).download(
      WhisperModel.tiny,
      config: cfg(),
      onProgress: (p) => fractions.add(p.fraction),
    );
    expect(fractions.last, 1.0);
    expect(fractions.first, lessThan(1.0));
    expect(File(path).lengthSync(), 100);
  });

  test('resumes from existing .part with Range header', () async {
    final part = File('${tmp.path}/models/tiny.bin.part');
    part.createSync(recursive: true);
    part.writeAsBytesSync(List.filled(50, 7));
    final client = _FakeClient((req) async {
      expect(req.headers['Range'], 'bytes=50-');
      return _resp(206, [List.filled(50, 8)], contentLength: 50);
    });
    final path =
        await downloader(client).download(WhisperModel.tiny, config: cfg());
    expect(File(path).lengthSync(), 100);
    expect(client.requests, 1);
  });

  test('cancel mid-stream deletes .part and throws cancelled', () async {
    final controller = StreamController<List<int>>();
    final client = _FakeClient((req) async {
      return http.StreamedResponse(controller.stream, 200, contentLength: 1000);
    });
    final dl = downloader(client);
    final future = dl.download(WhisperModel.tiny, config: cfg());
    // Let first chunk land, then cancel, then another chunk arrives —
    // the loop must notice the cancel flag.
    controller.add(List.filled(10, 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    dl.cancel();
    controller.add(List.filled(10, 2));
    await controller.close();
    await expectLater(
      future,
      throwsA(isA<WhisperError>().having(
        (e) => e.code,
        'code',
        WhisperErrorCode.cancelled,
      )),
    );
    expect(File('${tmp.path}/models/tiny.bin.part').existsSync(), isFalse);
  });

  test('corrupt download (size mismatch) throws and deletes file', () async {
    // Stream delivers 50 bytes but claims 100; verifyIntegrity compares
    // against the real model size → mismatch.
    final client = _FakeClient((req) async {
      return _resp(200, [List.filled(50, 1)], contentLength: 100);
    });
    await expectLater(
      downloader(client).download(WhisperModel.tiny, config: cfg(verify: true)),
      throwsA(isA<WhisperError>().having(
        (e) => e.code,
        'code',
        WhisperErrorCode.modelDownloadFailed,
      )),
    );
    expect(File('${tmp.path}/models/tiny.bin.part').existsSync(), isFalse);
  });

  test('retries with backoff after transient failures', () async {
    var fails = 0;
    final client = _FakeClient((req) async {
      if (fails < 2) {
        fails++;
        throw const SocketException('network down');
      }
      return _resp(200, [List.filled(100, 1)], contentLength: 100);
    });
    final path = await downloader(client).download(
      WhisperModel.tiny,
      config: cfg(retries: 3),
    );
    expect(client.requests, 3);
    expect(File(path).lengthSync(), 100);
  });
}
