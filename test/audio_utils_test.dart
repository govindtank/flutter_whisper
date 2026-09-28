import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper/flutter_whisper.dart';

void main() {
  group('AudioUtils WAV header and PCM tests', () {
    test('createWavHeader produces valid 44-byte RIFF header', () {
      final header = AudioUtils.createWavHeader(
        dataLength: 32000,
        sampleRate: 16000,
        channels: 1,
        bitsPerSample: 16,
      );

      expect(header.length, equals(44));
      expect(AudioUtils.isValidWavHeader(header), isTrue);
    });

    test('pcmToWav wraps raw PCM data into readable WAV', () {
      final dummyPcm = Uint8List(32000); // 1 second of 16kHz 16-bit mono audio
      final wav = AudioUtils.pcmToWav(dummyPcm);

      expect(wav.length, equals(44 + 32000));
      expect(AudioUtils.isValidWavHeader(wav), isTrue);
      expect(AudioUtils.getWavDurationSeconds(wav), closeTo(1.0, 0.01));
    });

    test('isValidWavHeader handles invalid or short bytes', () {
      expect(AudioUtils.isValidWavHeader(Uint8List(5)), isFalse);
      expect(AudioUtils.isValidWavHeader(Uint8List.fromList(List.filled(44, 0))), isFalse);
    });
  });
}
