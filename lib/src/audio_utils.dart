part of 'package:flutter_whisper/flutter_whisper.dart';

/// Audio utilities for preparing, validating, and formatting audio for Whisper.
class AudioUtils {
  AudioUtils._();

  /// Standard sample rate expected by whisper.cpp models (16,000 Hz).
  static const int kWhisperSampleRate = 16000;

  /// Creates a standard 44-byte RIFF WAV header for raw 16-bit PCM audio.
  ///
  /// [dataLength] - Length of raw PCM data bytes.
  /// [sampleRate] - Sample rate in Hz (default: 16,000 Hz).
  /// [channels] - Number of audio channels (default: 1 for Mono).
  /// [bitsPerSample] - Bit depth (default: 16-bit PCM).
  static Uint8List createWavHeader({
    required int dataLength,
    int sampleRate = kWhisperSampleRate,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final totalDataLen = dataLength + 36;

    final header = Uint8List(44);
    final buffer = ByteData.view(header.buffer);

    // RIFF header
    header[0] = 0x52; // 'R'
    header[1] = 0x49; // 'I'
    header[2] = 0x46; // 'F'
    header[3] = 0x46; // 'F'
    buffer.setUint32(4, totalDataLen, Endian.little);
    header[8] = 0x57; // 'W'
    header[9] = 0x41; // 'A'
    header[10] = 0x56; // 'V'
    header[11] = 0x45; // 'E'

    // fmt subchunk
    header[12] = 0x66; // 'f'
    header[13] = 0x6D; // 'm'
    header[14] = 0x74; // 't'
    header[15] = 0x20; // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    header[36] = 0x64; // 'd'
    header[37] = 0x61; // 'a'
    header[38] = 0x74; // 't'
    header[39] = 0x61; // 'a'
    buffer.setUint32(40, dataLength, Endian.little);

    return header;
  }

  /// Wraps raw PCM audio bytes with a standard WAV container header.
  static Uint8List pcmToWav(
    Uint8List pcmBytes, {
    int sampleRate = kWhisperSampleRate,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final header = createWavHeader(
      dataLength: pcmBytes.length,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );

    final out = Uint8List(header.length + pcmBytes.length);
    out.setRange(0, header.length, header);
    out.setRange(header.length, out.length, pcmBytes);
    return out;
  }

  /// Checks if a byte buffer starts with a valid 'RIFF' + 'WAVE' header.
  static bool isValidWavHeader(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x41 && // A
        bytes[10] == 0x56 && // V
        bytes[11] == 0x45; // E
  }

  /// Calculates audio duration in seconds from standard WAV bytes.
  static double getWavDurationSeconds(Uint8List wavBytes) {
    if (!isValidWavHeader(wavBytes) || wavBytes.length < 44) return 0.0;
    final view = ByteData.view(wavBytes.buffer, wavBytes.offsetInBytes);
    final sampleRate = view.getUint32(24, Endian.little);
    final channels = view.getUint16(22, Endian.little);
    final bitsPerSample = view.getUint16(34, Endian.little);
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);

    if (byteRate == 0) return 0.0;
    final dataSize = wavBytes.length - 44;
    return dataSize / byteRate;
  }

  /// Calculates root-mean-square (RMS) volume level of 16-bit PCM audio samples.
  static double calculateRms(Uint8List pcmBytes) {
    if (pcmBytes.length < 2) return 0.0;
    final buffer = ByteData.view(
        pcmBytes.buffer, pcmBytes.offsetInBytes, pcmBytes.lengthInBytes);
    final sampleCount = pcmBytes.length ~/ 2;
    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = buffer.getInt16(i * 2, Endian.little);
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    return math.sqrt(sumSquares / sampleCount);
  }
}
