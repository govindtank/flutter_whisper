part of 'package:flutter_whisper/flutter_whisper.dart';

/// Configuration options for Whisper transcription.
class WhisperOptions {
  /// Model to use. Default: [WhisperModel.tiny].
  final WhisperModel model;

  /// Language code (e.g., 'en', 'es', 'fr'). Empty = auto-detect.
  final String language;

  /// Translate to English instead of transcribing.
  final bool translate;

  /// Number of threads to use. 0 = auto (use all cores).
  final int threads;

  /// Enable VAD (Voice Activity Detection) to filter silence.
  final bool vad;

  /// VAD threshold (0.0-1.0). Higher = more aggressive silence removal.
  final double vadThreshold;

  /// Maximum segment length in seconds (for streaming).
  final double maxSegmentLength;

  /// Temperature for sampling (0.0 = greedy).
  final double temperature;

  /// Suppress blank outputs.
  final bool suppressBlank;

  /// Word-level timestamps.
  final bool wordTimestamps;

  const WhisperOptions({
    this.model = WhisperModel.tiny,
    this.language = '',
    this.translate = false,
    this.threads = 0,
    this.vad = true,
    this.vadThreshold = 0.5,
    this.maxSegmentLength = 30.0,
    this.temperature = 0.0,
    this.suppressBlank = true,
    this.wordTimestamps = false,
  });

  WhisperOptions copyWith({
    WhisperModel? model,
    String? language,
    bool? translate,
    int? threads,
    bool? vad,
    double? vadThreshold,
    double? maxSegmentLength,
    double? temperature,
    bool? suppressBlank,
    bool? wordTimestamps,
  }) {
    return WhisperOptions(
      model: model ?? this.model,
      language: language ?? this.language,
      translate: translate ?? this.translate,
      threads: threads ?? this.threads,
      vad: vad ?? this.vad,
      vadThreshold: vadThreshold ?? this.vadThreshold,
      maxSegmentLength: maxSegmentLength ?? this.maxSegmentLength,
      temperature: temperature ?? this.temperature,
      suppressBlank: suppressBlank ?? this.suppressBlank,
      wordTimestamps: wordTimestamps ?? this.wordTimestamps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model.name,
      'language': language,
      'translate': translate,
      'threads': threads,
      'vad': vad,
      'vadThreshold': vadThreshold,
      'maxSegmentLength': maxSegmentLength,
      'temperature': temperature,
      'suppressBlank': suppressBlank,
      'wordTimestamps': wordTimestamps,
    };
  }
}
