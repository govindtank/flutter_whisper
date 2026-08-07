## 0.1.0

* Initial release: on-device speech-to-text using whisper.cpp (Android).
* Automatic model download from HuggingFace (tiny/base/small/medium/large).
* Native whisper.cpp engine via JNI bridge, CPU inference (ARM64 / ARMv7).
* Streaming segment results for real-time UI updates.
* Segment + word-level timestamps, language auto-detection and forcing.
