## 0.2.0

* **Subtitle Exporters**: Added `result.toSrt()` (SubRip) and `result.toVtt()` (WebVTT) formatters with millisecond timestamp precision.
* **In-Memory Audio Transcription**: Added `Whisper.transcribeBytes()` for transcribing `Uint8List` byte buffers and raw PCM data directly.
* **Audio Utilities**: Added `AudioUtils` for 44-byte RIFF WAV header generation, PCM-to-WAV conversion, WAV duration calculation, and header validation.
* **Drop-in UI Widgets**:
  * `WhisperRecordingButton`: Animated pulsing microphone button with timer and start/stop/cancel actions.
  * `TranscriptionView`: Material 3 transcription viewer with timestamp chips, word pills, copy-to-clipboard, and segment navigation.
* **Model Specifications**: Added `WhisperModel` metadata for RAM usage estimates, speed/accuracy ratings, file sizes, and recommended use-cases.
* **Expanded Test Suite**: Added comprehensive unit and widget tests covering subtitle formatters, audio utilities, model specs, and UI widgets.

## 0.1.0

* Initial release: on-device speech-to-text using whisper.cpp (Android).
* Automatic model download from HuggingFace (tiny/base/small/medium/large).
* Native whisper.cpp engine via JNI bridge, CPU inference (ARM64 / ARMv7).
* Streaming segment results for real-time UI updates.
* Segment + word-level timestamps, language auto-detection and forcing.
