import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper/flutter_whisper.dart';

void main() {
  group('WhisperModel specifications and metadata', () {
    test('models have valid RAM requirements, file sizes, and download URLs', () {
      for (final model in WhisperModel.values) {
        expect(model.fileSizeBytes, greaterThan(1000000));
        expect(model.fileSizeHuman, isNotEmpty);
        expect(model.requiredRamMb, greaterThan(100));
        expect(model.relativeSpeedRating, inInclusiveRange(1, 5));
        expect(model.relativeAccuracyRating, inInclusiveRange(1, 5));
        expect(model.recommendedUseCase, isNotEmpty);
        expect(model.downloadUrl, startsWith('https://huggingface.co/'));
      }
    });

    test('multilingual capability flags', () {
      expect(WhisperModel.tiny.isMultilingual, isFalse);
      expect(WhisperModel.base.isMultilingual, isFalse);
      expect(WhisperModel.small.isMultilingual, isTrue);
      expect(WhisperModel.medium.isMultilingual, isTrue);
      expect(WhisperModel.large.isMultilingual, isTrue);
    });
  });
}
