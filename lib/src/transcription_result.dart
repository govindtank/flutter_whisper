part of 'package:flutter_whisper/flutter_whisper.dart';

/// A single word with timestamp and confidence score from transcription.
class WordTimestamp {
  /// The transcribed word.
  final String word;

  /// Start time in seconds from the beginning of the audio.
  final double start;

  /// End time in seconds from the beginning of the audio.
  final double end;

  /// Probability / confidence score (0.0 to 1.0).
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

  Map<String, dynamic> toMap() => {
        'word': word,
        'start': start,
        'end': end,
        'probability': probability,
      };

  @override
  String toString() => '$word (${start.toStringAsFixed(2)}s - ${end.toStringAsFixed(2)}s)';
}

/// A single transcription segment with start and end timestamps.
class TranscriptionSegment {
  /// Transcribed text for this segment.
  final String text;

  /// Start offset in seconds.
  final double start;

  /// End offset in seconds.
  final double end;

  /// Optional list of word-level timestamps within this segment.
  final List<WordTimestamp>? words;

  TranscriptionSegment({
    required this.text,
    required this.start,
    required this.end,
    this.words,
  });

  /// Duration of this segment in seconds.
  double get duration => (end - start).clamp(0.0, double.infinity);

  factory TranscriptionSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptionSegment(
      text: (map['text'] as String? ?? '').trim(),
      start: (map['start'] as num?)?.toDouble() ?? 0.0,
      end: (map['end'] as num?)?.toDouble() ?? 0.0,
      words: (map['words'] as List?)
          ?.map((w) => WordTimestamp.fromMap(Map<String, dynamic>.from(w)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'start': start,
        'end': end,
        if (words != null) 'words': words!.map((w) => w.toMap()).toList(),
      };

  @override
  String toString() => '[${start.toStringAsFixed(2)}s - ${end.toStringAsFixed(2)}s] $text';
}

/// Full transcription result with text, language, duration, and segments.
class TranscriptionResult {
  /// Full concatenated transcript text.
  final String text;

  /// Detected or specified language ISO code (e.g. 'en', 'es', 'hi').
  final String language;

  /// Total duration of processed audio in seconds.
  final double duration;

  /// Detailed timestamped segments.
  final List<TranscriptionSegment> segments;

  TranscriptionResult({
    required this.text,
    required this.language,
    this.duration = 0.0,
    required this.segments,
  });

  /// Whether the transcription returned empty text.
  bool get isEmpty => text.trim().isEmpty;

  /// Whether the transcription contains text.
  bool get isNotEmpty => !isEmpty;

  /// Total word count of the transcript.
  int get wordCount {
    final clean = text.trim();
    if (clean.isEmpty) return 0;
    return clean.split(RegExp(r'\s+')).length;
  }

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

  Map<String, dynamic> toMap() => {
        'text': text,
        'language': language,
        'duration': duration,
        'segments': segments.map((s) => s.toMap()).toList(),
      };

  /// Exports the transcription to standard SubRip (.srt) subtitle format.
  String toSrt() {
    if (segments.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSrtTimestamp(seg.start)} --> ${_formatSrtTimestamp(seg.end)}');
      buffer.writeln(seg.text);
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Exports the transcription to standard WebVTT (.vtt) format.
  String toVtt() {
    final buffer = StringBuffer('WEBVTT\n\n');
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatVttTimestamp(seg.start)} --> ${_formatVttTimestamp(seg.end)}');
      buffer.writeln(seg.text);
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Returns plain text transcript with optional timestamp prefixes.
  String toPlainText({bool includeTimestamps = false}) {
    if (!includeTimestamps) return text;
    final buffer = StringBuffer();
    for (final seg in segments) {
      buffer.writeln('[${_formatShortTimestamp(seg.start)} - ${_formatShortTimestamp(seg.end)}] ${seg.text}');
    }
    return buffer.toString().trimRight();
  }

  static String _formatSrtTimestamp(double seconds) {
    final totalMs = (seconds * 1000).round();
    final h = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final m = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  static String _formatVttTimestamp(double seconds) {
    final totalMs = (seconds * 1000).round();
    final h = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final m = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static String _formatShortTimestamp(double seconds) {
    final totalSec = seconds.floor();
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
