import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper/flutter_whisper.dart';

void main() {
  group('Widget tests', () {
    testWidgets('WhisperRecordingButton renders idle and active states', (tester) async {
      var started = false;
      var stopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecordingButton(
              isRecording: false,
              onStart: () => started = true,
              onStop: () => stopped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
      await tester.tap(find.byType(WhisperRecordingButton));
      expect(started, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhisperRecordingButton(
              isRecording: true,
              recordSeconds: 15,
              onStart: () => started = true,
              onStop: () => stopped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.text('00:15'), findsOneWidget);
      await tester.tap(find.byType(WhisperRecordingButton));
      expect(stopped, isTrue);
    });

    testWidgets('TranscriptionView displays chips and segments', (tester) async {
      final sample = TranscriptionResult(
        text: 'Voice note demo.',
        language: 'en',
        duration: 2.5,
        segments: [
          TranscriptionSegment(text: 'Voice note demo.', start: 0.0, end: 2.5),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TranscriptionView(result: sample),
            ),
          ),
        ),
      );

      expect(find.text('Lang: EN'), findsOneWidget);
      expect(find.text('2.5s'), findsOneWidget);
      expect(find.text('3 words'), findsOneWidget);
      expect(find.text('Voice note demo.'), findsOneWidget);
    });
  });
}
