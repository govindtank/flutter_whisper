part of 'package:flutter_whisper/flutter_whisper.dart';

/// Whisper model variants with sizes, RAM requirements, and characteristics.
enum WhisperModel {
  /// ~39 MB, English-only, fastest, lowest accuracy (~150 MB RAM required).
  tiny,

  /// ~75 MB, English-only, fast with balanced accuracy (~250 MB RAM required).
  base,

  /// ~150 MB, multilingual, good general accuracy (~500 MB RAM required).
  small,

  /// ~300 MB, multilingual, high accuracy (~1.2 GB RAM required).
  medium,

  /// ~1.5 GB, multilingual, state-of-the-art precision (~2.5 GB RAM required).
  large;

  /// Approximate file size in bytes (actual ggml-*.bin from HuggingFace).
  int get fileSizeBytes => switch (this) {
        WhisperModel.tiny => 77691713,
        WhisperModel.base => 149544538,
        WhisperModel.small => 483789920,
        WhisperModel.medium => 1537379430,
        WhisperModel.large => 3093265266,
      };

  /// Human-readable file size string.
  String get fileSizeHuman => switch (this) {
        WhisperModel.tiny => '74 MB',
        WhisperModel.base => '143 MB',
        WhisperModel.small => '461 MB',
        WhisperModel.medium => '1.4 GB',
        WhisperModel.large => '2.9 GB',
      };

  /// Estimated runtime RAM consumption in megabytes during inference.
  int get requiredRamMb => switch (this) {
        WhisperModel.tiny => 150,
        WhisperModel.base => 250,
        WhisperModel.small => 500,
        WhisperModel.medium => 1200,
        WhisperModel.large => 2500,
      };

  /// Relative speed rating on mobile CPUs (1 = slowest, 5 = fastest).
  int get relativeSpeedRating => switch (this) {
        WhisperModel.tiny => 5,
        WhisperModel.base => 4,
        WhisperModel.small => 3,
        WhisperModel.medium => 2,
        WhisperModel.large => 1,
      };

  /// Relative accuracy rating (1 = basic, 5 = best).
  int get relativeAccuracyRating => switch (this) {
        WhisperModel.tiny => 2,
        WhisperModel.base => 3,
        WhisperModel.small => 4,
        WhisperModel.medium => 5,
        WhisperModel.large => 5,
      };

  /// Whether model supports multilingual transcription & translation.
  bool get isMultilingual =>
      this != WhisperModel.tiny && this != WhisperModel.base;

  /// Recommended use-case description for this model size.
  String get recommendedUseCase => switch (this) {
        WhisperModel.tiny =>
          'Real-time chat, quick voice commands, and memory-constrained devices.',
        WhisperModel.base =>
          'Standard mobile voice dictation with balanced speed and accuracy.',
        WhisperModel.small =>
          'Multilingual transcription, meetings, interviews, and notes.',
        WhisperModel.medium =>
          'Podcasts, lectures, accented audio, and long-form recording.',
        WhisperModel.large =>
          'Studio audio, complex domain terminology, and professional subtitling.',
      };

  /// Official HuggingFace download URL for the quantized model binary.
  String get downloadUrl =>
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$name.bin';
}
