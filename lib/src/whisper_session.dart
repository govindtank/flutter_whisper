part of 'package:flutter_whisper/flutter_whisper.dart';

/// Whisper session wrapper - platform channel implementation
/// Actual whisper.cpp integration requires native build

/// Whisper session placeholder - platform channel implementation
/// Actual whisper.cpp integration requires native build
class WhisperSession {
  final WhisperModel model;
  final WhisperOptions options;

  WhisperSession({required this.model, required this.options});

  Future<void> dispose() async {}
}
