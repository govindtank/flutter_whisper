part of 'package:flutter_whisper/flutter_whisper.dart';

/// Abstract engine interface for platform implementations.
abstract class WhisperEngine {
  bool get isInitialized;
  bool get isTranscribing;
  WhisperModel? get loadedModel;
  double get progress;

  Future<void> initialize({
    required String modelPath,
    WhisperOptions? options,
  });

  Future<TranscriptionResult> transcribeFile(
    String audioPath, {
    WhisperOptions? options,
  });

  Future<TranscriptionResult> transcribePcm(
    Float32List pcmData, {
    WhisperOptions? options,
  });

  Stream<TranscriptionSegment> streamFile(
    String audioPath, {
    WhisperOptions? options,
  });

  void cancel();

  Future<void> dispose();
}

/// Platform implementation using MethodChannel.
class MethodChannelWhisperEngine implements WhisperEngine {
  static const MethodChannel _channel = MethodChannel('flutter_whisper');

  @override
  bool get isInitialized => false;

  @override
  bool get isTranscribing => false;

  @override
  WhisperModel? get loadedModel => null;

  @override
  double get progress => 0.0;

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
  }) async {
    final result = await _channel.invokeMethod('transcribeFile', {
      'audioPath': audioPath,
      'options': options?.toMap(),
    });
    return TranscriptionResult.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<TranscriptionResult> transcribePcm(
    Float32List pcmData, {
    WhisperOptions? options,
  }) async {
    throw UnimplementedError('PCM transcription not yet implemented');
  }

  @override
  Stream<TranscriptionSegment> streamFile(
    String audioPath, {
    WhisperOptions? options,
  }) {
    throw UnimplementedError('Streaming not yet implemented');
  }

  @override
  void cancel() {
    // TODO: Implement cancel via event channel
  }

  @override
  Future<void> dispose() async {
    // TODO: Implement dispose
  }
}