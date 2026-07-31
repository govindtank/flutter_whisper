part of 'package:flutter_whisper/flutter_whisper.dart';

/// Whisper model variants with sizes and characteristics.
enum WhisperModel {
  /// ~39 MB, English-only, fastest, lowest accuracy
  tiny,

  /// ~75 MB, English-only, better accuracy
  base,

  /// ~150 MB, multilingual, good accuracy
  small,

  /// ~300 MB, multilingual, best accuracy
  medium,

  /// ~1.5 GB, multilingual, highest accuracy
  large;

  /// Approximate file size in bytes.
  int get fileSizeBytes => switch (this) {
    WhisperModel.tiny => 39 * 1024 * 1024,
    WhisperModel.base => 75 * 1024 * 1024,
    WhisperModel.small => 150 * 1024 * 1024,
    WhisperModel.medium => 300 * 1024 * 1024,
    WhisperModel.large => 1500 * 1024 * 1024,
  };

  /// Human-readable size string.
  String get fileSizeHuman => switch (this) {
    WhisperModel.tiny => '39 MB',
    WhisperModel.base => '75 MB',
    WhisperModel.small => '150 MB',
    WhisperModel.medium => '300 MB',
    WhisperModel.large => '1.5 GB',
  };

  /// Whether model supports non-English languages.
  bool get isMultilingual => this != WhisperModel.tiny && this != WhisperModel.base;

  /// Download URL for the model.
  String get downloadUrl => 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$name.bin';
}