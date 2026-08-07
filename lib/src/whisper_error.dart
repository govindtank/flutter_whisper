part of 'package:flutter_whisper/flutter_whisper.dart';

/// Errors that can occur during Whisper transcription.
class WhisperError implements Exception {
  final String message;
  final WhisperErrorCode code;

  WhisperError(this.message, this.code);

  @override
  String toString() => 'WhisperError($code): $message';
}

enum WhisperErrorCode {
  modelNotFound,
  modelDownloadFailed,
  initializationFailed,
  permissionDenied,
  audioRecordingFailed,
  transcriptionFailed,
  invalidOptions,
  modelLoadFailed,
  engineNotInitialized,
  sessionFailed,
  cancelled,
  downloadPaused,
  unknown,
}
