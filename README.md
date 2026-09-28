# flutter_whisper

[![Pub Version](https://img.shields.io/pub/v/flutter_whisper.svg?style=flat-square&color=blue)](https://pub.dev/packages/flutter_whisper)
[![Pub Points](https://img.shields.io/pub/points/flutter_whisper?style=flat-square&color=2E8B57&label=pub%20points)](https://pub.dev/packages/flutter_whisper/score)
[![Pub Likes](https://img.shields.io/pub/likes/flutter_whisper?style=flat-square)](https://pub.dev/packages/flutter_whisper)
[![CI](https://github.com/govindtank/flutter_whisper/actions/workflows/ci.yml/badge.svg)](https://github.com/govindtank/flutter_whisper/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-brightgreen?style=flat-square)](https://pub.dev/packages/flutter_whisper)

Fast, on-device speech-to-text transcription for Flutter using [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and native C++ JNI bindings. 100% offline, privacy-first, with zero cloud API keys, automatic model downloads, and streaming segment callbacks.

Now available on **[pub.dev/packages/flutter_whisper](https://pub.dev/packages/flutter_whisper)**.

---

> 📱 **Platform Status:**
> - **Android:** Fully supported (JNI + CMake + whisper.cpp native engine with ARM NEON acceleration).
> - **iOS:** Planned on roadmap (static framework build).

---

## ✨ Features

- 🔒 **100% On-Device & Offline** — Audio never leaves the user's device. No cloud subscriptions, no API keys, no latency overhead.
- ⬇️ **Automatic Resumable Model Downloads** — Downloads standard quantized GGUF models directly from HuggingFace on first use with integrity checks and exponential backoff.
- 🧠 **5 Model Sizes** — From ultra-fast `tiny` (39 MB) to studio-accuracy `large` (1.5 GB).
- 🌐 **Multilingual & Translation** — Supports multilingual speech recognition with automatic language detection and real-time translation to English.
- ⏱️ **Segment & Word-Level Timestamps** — Get start/end timestamps for every recognized phrase or individual word.
- 📡 **Real-Time Streaming Callbacks** — Stream interim transcription segments to update UI as speech is decoded.
- 🎤 **Built-in Audio Recorder** — Capture microphone audio directly to 16kHz WAV format ready for transcription.

---

## 📦 Installation

Add `flutter_whisper` to your Flutter app:

```bash
flutter pub add flutter_whisper
```

Or in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_whisper: ^0.1.0
```

Import:

```dart
import 'package:flutter_whisper/flutter_whisper.dart';
```

---

## 🚀 Quick Start

### 1. Initialize and Transcribe Audio File

```dart
import 'package:flutter_whisper/flutter_whisper.dart';

void main() async {
  final whisper = Whisper();

  // 1. Initialize model (automatically downloads on first run)
  await whisper.initialize(
    model: WhisperModel.tiny,
    onProgress: (progress) {
      print('Model download progress: ${(progress.fraction * 100).toStringAsFixed(1)}%');
    },
  );

  // 2. Transcribe a 16kHz WAV audio file
  final result = await whisper.transcribeFile(
    '/path/to/sample.wav',
    onSegment: (segment) {
      print('[${segment.start}s - ${segment.end}s] ${segment.text}');
    },
  );

  print('Detected Language: ${result.language}');
  print('Full Transcript:\n${result.text}');

  // 3. Dispose when finished
  await whisper.dispose();
}
```

---

### 2. Live Microphone Recording & Transcription

Record directly from the device's microphone and transcribe the result:

```dart
final whisper = Whisper();
await whisper.initialize(model: WhisperModel.base);

// Start recording microphone input
await whisper.startRecording();

// ... user speaks ...

// Stop recording and get temporary WAV file path
final String recordedWavPath = await whisper.stopRecording();

// Transcribe recorded audio
final result = await whisper.transcribeFile(recordedWavPath);
print('You said: ${result.text}');
```

---

## ⚙️ Configuration & Options

Customize transcription behavior using `WhisperOptions`:

```dart
await whisper.initialize(
  model: WhisperModel.small,
  options: const WhisperOptions(
    language: 'auto',       // 'auto' for language detection or 'en', 'es', 'hi', 'fr' etc.
    translate: false,       // Set true to translate source audio into English
    vad: true,              // Voice Activity Detection to skip silent regions
    wordTimestamps: true,   // Compute word-level precise timestamps
    threads: 4,             // CPU worker threads (0 = auto-detect hardware concurrency)
    temperature: 0.0,       // Sampling temperature (0.0 for greedy deterministic output)
  ),
);
```

---

## 🧠 Available Models

| Model | File Size | English-Only | Multilingual | Best For |
|---|---|---|---|---|
| `WhisperModel.tiny` | **39 MB** | ✅ `tiny.en` | ✅ `tiny` | Real-time chat, low memory devices, quick commands |
| `WhisperModel.base` | **75 MB** | ✅ `base.en` | ✅ `base` | Balanced everyday speech recognition |
| `WhisperModel.small` | **150 MB** | — | ✅ `small` | High accuracy transcription with good performance |
| `WhisperModel.medium` | **300 MB** | — | ✅ `medium` | Heavy conversational audio, accents, and podcasts |
| `WhisperModel.large` | **1.5 GB** | — | ✅ `large-v3` | Highest precision, complex jargon, difficult acoustics |

*Models are downloaded once and cached locally in app documents directory.*

---

## 📱 Platform Setup

### Android Setup

Add `RECORD_AUDIO` permission to `android/app/src/main/AndroidManifest.xml` (required only if using `startRecording()`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Microphone permission for speech recording -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- Internet permission for initial model download -->
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

---

## 📚 API Reference

### `Whisper`
The primary controller class:

| Method | Returns | Description |
|---|---|---|
| `initialize({WhisperModel model, WhisperOptions? options, void Function(WhisperDownloadProgress)? onProgress})` | `Future<void>` | Downloads model if needed and initializes native whisper context. |
| `transcribeFile(String path, {void Function(TranscriptionSegment)? onSegment})` | `Future<TranscriptionResult>` | Runs offline transcription on a WAV audio file. |
| `startRecording()` | `Future<void>` | Starts microphone capture in 16kHz mono WAV format. |
| `stopRecording()` | `Future<String>` | Stops recording and returns the path to the recorded WAV file. |
| `isModelDownloaded(WhisperModel model)` | `Future<bool>` | Checks if model file exists in local cache. |
| `deleteModel(WhisperModel model)` | `Future<void>` | Deletes cached model file to free device storage. |
| `dispose()` | `Future<void>` | Frees native C++ memory and resources. |

---

### `TranscriptionResult`

| Property | Type | Description |
|---|---|---|
| `text` | `String` | Concatenated full transcript text. |
| `language` | `String` | Detected or configured language ISO code (e.g. `en`, `hi`, `de`). |
| `segments` | `List<TranscriptionSegment>` | List of segmented transcription timestamps and sentences. |
| `durationSeconds` | `double` | Total audio duration processed. |

---

## 🧪 Testing

```bash
flutter test
flutter analyze
```

---

## 📄 License

MIT License. whisper.cpp is licensed under MIT (Georgi Gerganov).
