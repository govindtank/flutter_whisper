import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper/flutter_whisper.dart';

void main() {
  group('TranscriptionResult formatting & exports', () {
    final result = TranscriptionResult(
      text: 'Hello world. This is on-device speech recognition.',
      language: 'en',
      duration: 4.5,
      segments: [
        TranscriptionSegment(
          text: 'Hello world.',
          start: 0.5,
          end: 1.8,
          words: [
            WordTimestamp(
                word: 'Hello', start: 0.5, end: 1.1, probability: 0.95),
            WordTimestamp(
                word: 'world.', start: 1.2, end: 1.8, probability: 0.92),
          ],
        ),
        TranscriptionSegment(
          text: 'This is on-device speech recognition.',
          start: 2.0,
          end: 4.5,
        ),
      ],
    );

    test('wordCount and isEmpty/isNotEmpty', () {
      expect(result.isNotEmpty, isTrue);
      expect(result.isEmpty, isFalse);
      expect(result.wordCount, equals(7));

      final empty = TranscriptionResult(text: '', language: 'en', segments: []);
      expect(empty.isEmpty, isTrue);
      expect(empty.wordCount, equals(0));
    });

    test('toSrt formats correctly with commas for milliseconds', () {
      final srt = result.toSrt();
      expect(srt, contains('1\n00:00:00,500 --> 00:00:01,800\nHello world.'));
      expect(
        srt,
        contains(
            '2\n00:00:02,000 --> 00:00:04,500\nThis is on-device speech recognition.'),
      );
    });

    test('toVtt formats correctly with WEBVTT header and period for ms', () {
      final vtt = result.toVtt();
      expect(vtt, startsWith('WEBVTT\n\n'));
      expect(vtt, contains('1\n00:00:00.500 --> 00:00:01.800\nHello world.'));
      expect(
        vtt,
        contains(
            '2\n00:00:02.000 --> 00:00:04.500\nThis is on-device speech recognition.'),
      );
    });

    test('toPlainText with and without timestamps', () {
      expect(result.toPlainText(), equals(result.text));
      final withTimestamps = result.toPlainText(includeTimestamps: true);
      expect(withTimestamps, contains('[00:00 - 00:01] Hello world.'));
      expect(withTimestamps,
          contains('[00:02 - 00:04] This is on-device speech recognition.'));
    });

    test('toMap and serialization round-trip', () {
      final map = result.toMap();
      expect(map['text'], equals(result.text));
      expect(map['language'], equals('en'));
      expect(map['duration'], equals(4.5));
      expect(map['segments'], isList);

      final reconstructed = TranscriptionResult.fromMap(map);
      expect(reconstructed.text, equals(result.text));
      expect(reconstructed.segments.length, equals(2));
      expect(reconstructed.segments.first.words?.length, equals(2));
    });
  });
}
