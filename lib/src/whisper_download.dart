part of 'package:flutter_whisper/flutter_whisper.dart';

/// Live progress of a model download.
class WhisperDownloadProgress {
  final double fraction;
  final int receivedBytes;
  final int totalBytes;
  final double? speedBytesPerSec;
  final Duration? eta;

  const WhisperDownloadProgress({
    required this.fraction,
    required this.receivedBytes,
    required this.totalBytes,
    this.speedBytesPerSec,
    this.eta,
  });
}

/// Configuration for model download behavior.
class WhisperDownloadConfig {
  /// Fallback CDN used when the primary URL fails (retry rotates URLs).
  final String? mirrorUrl;

  /// Per-chunk stall timeout. Default 30 s.
  final Duration stallTimeout;

  /// Max attempts per download (primary + mirror + retries). Default 3.
  final int maxRetries;

  /// Validate final size against the model's known size. Default true.
  final bool verifyIntegrity;

  const WhisperDownloadConfig({
    this.mirrorUrl,
    this.stallTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.verifyIntegrity = true,
  });
}

/// Resumable model downloader.
///
/// Partial data is kept in `<model>.bin.part`. A new [download] call detects
/// the `.part` file and continues via HTTP `Range` instead of restarting.
/// Interrupted downloads therefore survive app kills and network drops.
class WhisperDownloader {
  WhisperDownloader({required String directory, http.Client? client})
      : _directory = directory,
        _client = client ?? http.Client();

  final String _directory;
  final http.Client _client;
  bool _paused = false;
  bool _cancelled = false;

  /// Downloads [model] into `models/` under [_directory].
  ///
  /// Throws [WhisperError] with [WhisperErrorCode.cancelled] on cancel,
  /// [WhisperErrorCode.downloadPaused] on pause, or
  /// [WhisperErrorCode.modelDownloadFailed] after retries are exhausted.
  /// Returns the path to the completed model file.
  Future<String> download(
    WhisperModel model, {
    WhisperDownloadConfig config = const WhisperDownloadConfig(),
    void Function(WhisperDownloadProgress)? onProgress,
  }) async {
    _paused = false;
    _cancelled = false;
    final dir = Directory('$_directory/models')..createSync(recursive: true);
    final file = File('${dir.path}/${model.name}.bin');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;
    final part = File('${file.path}.part');

    final urls = [
      model.downloadUrl,
      if (config.mirrorUrl != null) config.mirrorUrl!,
    ];
    final stopwatch = Stopwatch()..start();
    var attempts = 0;

    while (true) {
      final start = part.existsSync() ? part.lengthSync() : 0;
      var sink =
          part.openWrite(mode: start > 0 ? FileMode.append : FileMode.write);
      try {
        final total = await _attempt(
          urls[attempts % urls.length],
          sink,
          part,
          start,
          config,
          onProgress,
          stopwatch,
        );
        await sink.close();
        if (config.verifyIntegrity) {
          final expected = model.fileSizeBytes;
          final actual = part.lengthSync();
          final tolerance = expected > 1024 ? expected * 0.02 : 1024.0;
          if ((actual - expected).abs() > tolerance) {
            part.deleteSync();
            throw WhisperError(
              'Download corrupt ($actual bytes, expected ~$expected)',
              WhisperErrorCode.modelDownloadFailed,
            );
          }
        }
        part.renameSync(file.path);
        onProgress?.call(WhisperDownloadProgress(
          fraction: 1.0,
          receivedBytes: total,
          totalBytes: total,
        ));
        return file.path;
      } on _PauseSignal {
        await sink.close();
        throw WhisperError('Download paused', WhisperErrorCode.downloadPaused);
      } on _CancelSignal {
        await sink.close();
        part.deleteSync();
        throw WhisperError('Download cancelled', WhisperErrorCode.cancelled);
      } catch (e) {
        await sink.close();
        attempts++;
        if (attempts >= config.maxRetries) {
          throw WhisperError(
            'Download failed: $e',
            WhisperErrorCode.modelDownloadFailed,
          );
        }
        // Backoff: 2s, 4s, 8s… then retry, resuming from saved partial.
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
  }

  Future<int> _attempt(
    String url,
    IOSink sink,
    File part,
    int start,
    WhisperDownloadConfig config,
    void Function(WhisperDownloadProgress)? onProgress,
    Stopwatch sw,
  ) async {
    final req = http.Request('GET', Uri.parse(url));
    if (start > 0) req.headers['Range'] = 'bytes=$start-';
    final resp = await _client.send(req).timeout(config.stallTimeout);

    var offset = start;
    if (resp.statusCode == 200 && start > 0) {
      // Server ignored Range → restart from scratch.
      await sink.close();
      part.deleteSync();
      sink = part.openWrite(mode: FileMode.write);
      offset = 0;
    } else if (resp.statusCode != 200 && resp.statusCode != 206) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final total = (resp.contentLength ?? 0) + offset;
    final stream = resp.stream.timeout(config.stallTimeout);

    await for (final chunk in stream) {
      if (_paused) throw _PauseSignal();
      if (_cancelled) throw _CancelSignal();
      sink.add(chunk);
      offset += chunk.length;
      if (total > 0 && onProgress != null) {
        final secs = sw.elapsedMilliseconds / 1000.0;
        final speed = secs > 0 ? offset / secs : null;
        onProgress(WhisperDownloadProgress(
          fraction: (offset / total).clamp(0.0, 1.0),
          receivedBytes: offset,
          totalBytes: total,
          speedBytesPerSec: speed,
          eta: (speed != null && speed > 0)
              ? Duration(seconds: ((total - offset) / speed).round())
              : null,
        ));
      }
    }
    return offset;
  }

  void pause() => _paused = true;
  void cancel() => _cancelled = true;
}

class _PauseSignal implements Exception {}

class _CancelSignal implements Exception {}
