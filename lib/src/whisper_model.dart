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

  /// Approximate file size in bytes (actual ggml-*.bin from HF).
  int get fileSizeBytes => switch (this) {
        WhisperModel.tiny => 77691713,
        WhisperModel.base => 149544538,
        WhisperModel.small => 483789920,
        WhisperModel.medium => 1537379430,
        WhisperModel.large => 3093265266,
      };

  /// Human-readable size string.
  String get fileSizeHuman => switch (this) {
        WhisperModel.tiny => '74 MB',
        WhisperModel.base => '143 MB',
        WhisperModel.small => '461 MB',
        WhisperModel.medium => '1.4 GB',
        WhisperModel.large => '2.9 GB',
      };

  /// Whether model supports non-English languages.
  bool get isMultilingual =>
      this != WhisperModel.tiny && this != WhisperModel.base;

  /// Download URL for the model.
  String get downloadUrl =>
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$name.bin';
}
