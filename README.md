# flutter_whisper

[![Pub Version](https://img.shields.io/pub/v/flutter_whisper.svg?style=flat-square&color=blue)](https://pub.dev/packages/flutter_whisper)
[![Pub Points](https://img.shields.io/pub/points/flutter_whisper?style=flat-square&color=2E8B57&label=pub%20points)](https://pub.dev/packages/flutter_whisper/score)
[![Pub Likes](https://img.shields.io/pub/likes/flutter_whisper?style=flat-square)](https://pub.dev/packages/flutter_whisper)
[![CI](https://github.com/govindtank/flutter_whisper/actions/workflows/ci.yml/badge.svg)](https://github.com/govindtank/flutter_whisper/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-brightgreen?style=flat-square)](https://pub.dev/packages/flutter_whisper)

Fast, on-device speech-to-text transcription for Flutter powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and native C++ JNI bindings with ARM NEON acceleration. 100% offline, privacy-first, with automatic model downloading, SubRip (SRT) & WebVTT subtitle export, in-memory buffer transcription, and drop-in Material 3 UI widgets.

Now available on **[pub.dev/packages/flutter_whisper](https://pub.dev/packages/flutter_whisper)**.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/govindtank/flutter_whisper/main/screenshot.svg" width="850" alt="flutter_whisper preview screenshot" />
</p>

---

> 📱 **Platform Status:**
> - **Android:** Fully supported (JNI + CMake + whisper.cpp native engine with ARM NEON SIMD acceleration).
> - **iOS:** Planned on roadmap (static framework build).

---

## ✨ Features

- 🔒 **100% On-Device & Offline** — Audio never leaves the user's phone. No cloud API subscriptions, no latency to external servers, and complete user privacy.
- 📝 **Subtitle Exporters (SRT & WebVTT)** — Built-in `.toSrt()` and `.toVtt()` formatters with millisecond-accurate timestamp blocks.
- 🎛️ **In-Memory Buffer Transcription** — Transcribe `Uint8List` byte buffers and raw PCM audio streams directly via `transcribeBytes()`.
- 🧩 **Drop-in UI Components** — Includes `WhisperRecordingButton` (animated pulsing ripples and duration counter) and `TranscriptionView` (Material 3 transcript cards with timestamp chips and copy actions).
- ⬇️ **Automatic Resumable Downloads** — Quantized GGUF models download directly from HuggingFace on first use with integrity checks and exponential backoff.
- 🧠 **5 Quantized Model Sizes** — From ultra-light `tiny` (39 MB) to studio-grade `large-v3` (1.5 GB).
- ⏱️ **Word & Segment-Level Timestamps** — Access exact start/end offsets and confidence probabilities per word.
- 🌐 **Multilingual & Real-Time Translation** — Auto-detects 99+ languages and translates spoken audio directly into English.
- 🎤 **Built-in Microphone WAV Recorder** — Record 16kHz mono audio on-device with zero extra audio dependencies.

---

## 📦 Installation

Add `flutter_whisper` to your Flutter project:

```bash
flutter pub add flutter_whisper
```

Or in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_whisper: ^0.2.0
```

Import:

```dart
import 'package:flutter_whisper/flutter_whisper.dart';
```

---

## 🚀 Usage Guide

### 1. Transcribe an Audio File

```dart
import 'package:flutter_whisper/flutter_whisper.dart';

void main() async {
  final whisper = Whisper();

  // 1. Initialize (downloads model automatically on first run)
  await whisper.initialize(
    model: WhisperModel.tiny,
    onProgress: (p) => print('Download: ${(p.fraction * 100).toStringAsFixed(1)}%'),
  );

  // 2. Transcribe a 16kHz WAV file
  final result = await whisper.transcribeFile(
    '/path/to/recording.wav',
    onProgress: (progress) => print('Transcribing: $progress%'),
  );

  print('Full Transcript: ${result.text}');
  print('Language: ${result.language}');
  print('Total Words: ${result.wordCount}');

  // 3. Clean up
  await whisper.dispose();
}
```

---

### 2. Exporting to SubRip (.srt) and WebVTT (.vtt)

Generate subtitle tracks for video players or caption workflows:

```dart
final result = await whisper.transcribeFile('podcast.wav');

// SubRip format (00:01:23,450 --> 00:01:26,890)
final String srtContent = result.toSrt();
await File('subtitles.srt').writeAsString(srtContent);

// WebVTT format (WEBVTT\n\n00:01:23.450 --> 00:01:26.890)
final String vttContent = result.toVtt();
await File('subtitles.vtt').writeAsString(vttContent);

// Plain text with timestamp brackets: [01:23 - 01:26]
final String textWithTimestamps = result.toPlainText(includeTimestamps: true);
```

---

### 3. In-Memory Byte Transcription (`transcribeBytes`)

Transcribe audio buffers received from network sockets, Bluetooth, or memory caches:

```dart
final Uint8List audioBytes = await fetchAudioBytes();

final result = await whisper.transcribeBytes(
  audioBytes,
  isRawPcm: false, // Set true if passing raw 16kHz PCM bytes without WAV header
);

print(result.text);
```

---

### 4. Live Microphone Recording

```dart
final whisper = Whisper();
await whisper.initialize(model: WhisperModel.base);

// Start recording microphone input (16kHz WAV on disk)
await whisper.startRecording();

// ... user speaks ...

// Stop recording and get temporary WAV file path
final String recordedWavPath = await whisper.stopRecording();

// Transcribe recorded audio
final result = await whisper.transcribeFile(recordedWavPath);
print('You said: ${result.text}');
```

---

### 5. Drop-in Material 3 UI Widgets

Add high-polish voice dictation UI in seconds using built-in widgets:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_whisper/flutter_whisper.dart';

class VoiceNotesScreen extends StatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  State<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  final Whisper _whisper = Whisper();
  bool _isRecording = false;
  int _recordSeconds = 0;
  TranscriptionResult? _result;

  @override
  void initState() {
    super.initState();
    _whisper.initialize(model: WhisperModel.base);
  }

  void _onStart() async {
    await _whisper.startRecording();
    setState(() => _isRecording = true);
  }

  void _onStop() async {
    final wavPath = await _whisper.stopRecording();
    setState(() => _isRecording = false);

    final res = await _whisper.transcribeFile(wavPath);
    setState(() => _result = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Notes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Pulsing Animated Recording Button
            WhisperRecordingButton(
              isRecording: _isRecording,
              recordSeconds: _recordSeconds,
              onStart: _onStart,
              onStop: _onStop,
            ),
            const SizedBox(height: 24),

            // 2. Transcription Viewer with Timestamp Chips and Copy Action
            if (_result != null)
              TranscriptionView(
                result: _result!,
                onSegmentTap: (segment) {
                  print('Tapped: ${segment.start}s to ${segment.end}s');
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🧠 Model Specifications & Hardware Requirements

| Model | Download Size | Runtime RAM | Relative Speed | Accuracy | Best For |
|---|---|---|---|---|---|
| `WhisperModel.tiny` | **74 MB** | ~150 MB | ⚡⚡⚡⚡⚡ | ⭐⭐ | Quick voice commands, real-time chat, low memory devices |
| `WhisperModel.base` | **143 MB** | ~250 MB | ⚡⚡⚡⚡ | ⭐⭐⭐ | Everyday voice notes and speech dictation |
| `WhisperModel.small` | **461 MB** | ~500 MB | ⚡⚡⚡ | ⭐⭐⭐⭐ | Multilingual conversations, meetings, and interviews |
| `WhisperModel.medium` | **1.4 GB** | ~1.2 GB | ⚡⚡ | ⭐⭐⭐⭐⭐ | Podcasts, lectures, accented audio, and long-form recording |
| `WhisperModel.large` | **2.9 GB** | ~2.5 GB | ⚡ | ⭐⭐⭐⭐⭐ | Studio audio, specialized terminology, professional subtitles |

---

## 📱 Platform Setup

### Android Setup
Add the permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required only if using startRecording() -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- Required for initial model download from HuggingFace -->
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

---

## 🧪 Testing

```bash
flutter test
flutter analyze
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
