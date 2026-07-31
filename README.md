# flutter_whisper

On-device speech-to-text transcription using [whisper.cpp](https://github.com/ggerganov/whisper.cpp). No cloud, no API keys — models run locally on iOS and Android.

## Features

- 🎙️ On-device transcription (works offline, privacy-first)
- ⬇️ Automatic model download on first use
- 🧠 5 model sizes: `tiny` (39 MB) → `large` (1.5 GB)
- 🌍 Multilingual (tiny/base are English-only, small+ are multilingual)
- ⏱️ Segment + word-level timestamps
- 📡 Streaming segment results (real-time UI updates)

## Getting started

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_whisper: ^0.1.0
```

## Usage

```dart
import 'package:flutter_whisper/flutter_whisper.dart';

final whisper = Whisper();

// 1. Initialize — downloads model on first use
await whisper.initialize(model: WhisperModel.tiny);

// 2. Transcribe a file
final result = await whisper.transcribeFile('/path/to/audio.wav');
print(result.text);          // "hello world"
print(result.language);      // "en"
for (final seg in result.segments) {
  print('[${seg.start}s - ${seg.end}s] ${seg.text}');
}

// 3. Transcribe raw PCM (16 kHz, mono)
final result2 = await whisper.transcribePcm(pcmData);

// 4. Stream segments as they're generated
final sub = whisper.streamFile('/path/to/audio.wav').listen((seg) {
  print(seg.text);  // partial results for live UI
});

// 5. Clean up
await whisper.dispose();
```

### Options

```dart
await whisper.initialize(
  model: WhisperModel.small,
  options: const WhisperOptions(
    language: 'en',        // '' = auto-detect
    translate: false,      // translate to English
    vad: true,             // filter silence
    wordTimestamps: true,  // word-level timestamps
    threads: 4,            // 0 = auto
  ),
);
```

### Models

| Model | Size | Languages | Use case |
|-------|------|-----------|----------|
| `tiny` | 39 MB | English | Fastest, quick tests |
| `base` | 75 MB | English | Fast + decent accuracy |
| `small` | 150 MB | Multilingual | Good balance |
| `medium` | 300 MB | Multilingual | High accuracy |
| `large` | 1.5 GB | Multilingual | Best accuracy |

Models download automatically from HuggingFace on first `initialize()`.

## Platform setup

**Android** — add RECORD_AUDIO permission (only if recording):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** — add to `Info.plist` (only if recording):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access for speech recognition</string>
```

No network permissions needed — transcription runs on-device.

## Example

Full demo app in [`example/`](example/lib/main.dart):

```bash
cd example
flutter run
```

## Additional information

- [Report issues](https://github.com/govindtank/flutter_whisper/issues)
- Native integration uses whisper.cpp via platform channels
- PCM transcription and streaming are stubs — coming next
