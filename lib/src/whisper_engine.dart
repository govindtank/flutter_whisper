part of 'package:flutter_whisper/flutter_whisper.dart';

/// Abstract engine interface for platform implementations.
abstract class WhisperEngine {
  Future<void> initialize({
    required String modelPath,
    WhisperOptions? options,
  });

  /// Transcribes [audioPath]. [onProgress] receives 0..100.
  Future<TranscriptionResult> transcribeFile(
    String audioPath, {
    WhisperOptions? options,
    void Function(int)? onProgress,
  });

  /// Starts mic recording to a WAV file.
  Future<void> startRecording();

  /// Stops mic recording; returns the recorded WAV path.
  Future<String> stopRecording();

  void cancel();

  Future<void> dispose();
}

/// Platform implementation using MethodChannel.
class MethodChannelWhisperEngine implements WhisperEngine {
  static const MethodChannel _channel = MethodChannel('flutter_whisper');

  void Function(int)? _onTranscribeProgress;

  MethodChannelWhisperEngine() {
    // Native progress events arrive as invocations on the same channel.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'transcribeProgress') {
        _onTranscribeProgress?.call(call.arguments as int);
      }
    });
  }

  @override
  Future<void> initialize({
    required String modelPath,
    WhisperOptions? options,
  }) async {
    await _channel.invokeMethod('initialize', {
      'modelPath': modelPath,
      'options': options?.toMap(),
    });
  }

  @override
  Future<TranscriptionResult> transcribeFile(
    String audioPath, {
    WhisperOptions? options,
    void Function(int)? onProgress,
  }) async {
    _onTranscribeProgress = onProgress;
    final result = await _channel.invokeMethod('transcribeFile', {
      'audioPath': audioPath,
      'options': options?.toMap(),
    });
    _onTranscribeProgress = null;
    return TranscriptionResult.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<void> startRecording() async {
    await _channel.invokeMethod('startRecording');
  }

  @override
  Future<String> stopRecording() async {
    return _channel.invokeMethod('stopRecording') as String;
  }

  @override
  void cancel() {
    _channel.invokeMethod('cancel');
  }

  @override
  Future<void> dispose() async {
    _onTranscribeProgress = null;
    await _channel.invokeMethod('dispose');
  }
}
