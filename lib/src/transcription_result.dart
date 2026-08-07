part of 'package:flutter_whisper/flutter_whisper.dart';

/// A single word with timestamp from transcription.
class WordTimestamp {
  final String word;
  final double start;
  final double end;
  final double probability;

  WordTimestamp({
    required this.word,
    required this.start,
    required this.end,
    required this.probability,
  });

  factory WordTimestamp.fromMap(Map<String, dynamic> map) {
    return WordTimestamp(
      word: map['word'] as String? ?? '',
      start: (map['start'] as num?)?.toDouble() ?? 0.0,
      end: (map['end'] as num?)?.toDouble() ?? 0.0,
      probability: (map['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A single transcription segment with timestamps.
class TranscriptionSegment {
  final String text;
  final double start;
  final double end;
  final List<WordTimestamp>? words;

  TranscriptionSegment({
    required this.text,
    required this.start,
    required this.end,
    this.words,
  });

  factory TranscriptionSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptionSegment(
      text: map['text'] as String? ?? '',
      start: (map['start'] as num?)?.toDouble() ?? 0.0,
      end: (map['end'] as num?)?.toDouble() ?? 0.0,
      words: (map['words'] as List?)
          ?.map((w) => WordTimestamp.fromMap(Map<String, dynamic>.from(w)))
          .toList(),
    );
  }
}

/// Full transcription result with text, language, and segments.
class TranscriptionResult {
  final String text;
  final String language;
  final double duration;
  final List<TranscriptionSegment> segments;

  TranscriptionResult({
    required this.text,
    required this.language,
    this.duration = 0.0,
    required this.segments,
  });

  factory TranscriptionResult.fromMap(Map<String, dynamic> map) {
    return TranscriptionResult(
      text: map['text'] as String? ?? '',
      language: map['language'] as String? ?? '',
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      segments: (map['segments'] as List?)
              ?.map((s) =>
                  TranscriptionSegment.fromMap(Map<String, dynamic>.from(s)))
              .toList() ??
          const [],
    );
  }
}
