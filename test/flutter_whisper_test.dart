import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_whisper/flutter_whisper.dart';

void main() {
  test('WhisperModel sizes', () {
    expect(WhisperModel.tiny.fileSizeBytes, 77691713);
    expect(WhisperModel.large.isMultilingual, isTrue);
    expect(WhisperModel.tiny.isMultilingual, isFalse);
  });

  test('TranscriptionResult parses fromMap', () {
    final result = TranscriptionResult.fromMap({
      'text': 'hello world',
      'language': 'en',
      'segments': [
        {'text': 'hello', 'start': 0.0, 'end': 1.0},
        {'text': 'world', 'start': 1.0, 'end': 2.0},
      ],
    });
    expect(result.text, 'hello world');
    expect(result.language, 'en');
    expect(result.segments, hasLength(2));
    expect(result.segments.first.text, 'hello');
  });
}
