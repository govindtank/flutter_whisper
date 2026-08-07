# flutter_whisper

On-device speech-to-text transcription using [whisper.cpp](https://github.com/ggerganov/whisper.cpp). No cloud, no API keys — models run locally on Android.

> ⚠️ **Platform status:** Android is fully supported (JNI + whisper.cpp via CMake).
> iOS is planned but not yet implemented.

## Features

- 🎙️ On-device transcription (works offline, privacy-first)
- ⬇️ Automatic model download on first use (resumable, with integrity check)
- 🧠 5 model sizes: `tiny` (39 MB) → `large` (1.5 GB)
- 🌍 Multilingual (tiny/base are English-only, small+ are multilingual)
- ⏱️ Segment + word-level timestamps
- 📡 Streaming segment results (real-time UI updates)
- 🎤 Microphone recording → WAV → transcribe (Android)

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

// 3. Record from the microphone, then transcribe
await whisper.startRecording();
// ... speak ...
final wavPath = await whisper.stopRecording();
final result2 = await whisper.transcribeFile(wavPath);

// 4. Clean up
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

No network permissions needed — transcription runs on-device. Model downloads
use the app's own network permission.

## Example

Full demo app in [`example/`](example/lib/main.dart):

```bash
cd example
flutter run
```

## Additional information

- [Report issues](https://github.com/govindtank/flutter_whisper/issues)
- Native integration uses whisper.cpp via platform channels
- iOS support is on the roadmap (whisper.cpp static framework build)
