/// Main entry point for flutter_whisper.
///
/// Usage:
/// ```dart
/// final whisper = Whisper();
/// await whisper.initialize(model: WhisperModel.tiny);
/// final result = await whisper.transcribeFile('recording.wav');
/// print(result.text);
/// ```
part of 'package:flutter_whisper/flutter_whisper.dart';

/// Main entry point for Flutter Whisper.
///
/// Usage:
/// ```dart
/// final whisper = Whisper();
/// await whisper.initialize(model: WhisperModel.tiny);
/// final result = await whisper.transcribeFile('recording.wav');
/// print(result.text);
/// ```
class Whisper {
  Whisper._internal();
  static final Whisper _instance = Whisper._internal();
  factory Whisper() => _instance;

  WhisperEngine? _engine;
  WhisperModel? _loadedModel;
  bool _isInitialized = false;

  /// Whether the engine is initialized and ready.
  bool get isInitialized => _isInitialized;

  /// Currently loaded model (if any).
  WhisperModel? get loadedModel => _loadedModel;

  /// Initialize the Whisper engine with a model.
  ///
  /// [model] - Model to load (default: tiny)
  /// [options] - Transcription options (optional)
  /// [onProgress] - Download progress callback (0.0-1.0), fires while
  ///                the model downloads on first use.
  ///
  /// Throws [WhisperError] on failure.
  Future<void> initialize({
    WhisperModel model = WhisperModel.tiny,
    WhisperOptions options = const WhisperOptions(),
    void Function(double)? onProgress,
  }) async {
    if (_isInitialized && _loadedModel == model) return;

    // Get model file path (downloads if not cached)
    final modelPath = await _ensureModel(model, onProgress);

    // Create platform engine
    _engine = _createEngine();

    try {
      await _engine!.initialize(modelPath: modelPath, options: options);
      _loadedModel = model;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      _loadedModel = null;
      rethrow;
    }
  }

  /// Transcribe an audio file.
  ///
  /// [audioPath] - Path to audio file (wav, mp3, m4a, etc.)
  /// [options] - Override options for this transcription
  ///
  /// Returns [TranscriptionResult] with text, segments, language.
  /// Throws [WhisperError] on failure.
  Future<TranscriptionResult> transcribeFile(
    String audioPath, {
    WhisperOptions? options,
  }) async {
    _assertInitialized();
    return _engine!.transcribeFile(audioPath, options: options);
  }

  /// Transcribe raw PCM audio data.
  ///
  /// [pcmData] - Float32List of PCM audio (16kHz, mono)
  /// [options] - Override options for this transcription
  Future<TranscriptionResult> transcribePcm(
    Float32List pcmData, {
    WhisperOptions? options,
  }) async {
    _assertInitialized();
    return _engine!.transcribePcm(pcmData, options: options);
  }

  /// Stream transcription segments as they're generated.
  ///
  /// Useful for real-time UI updates.
  Stream<TranscriptionSegment> streamFile(
    String audioPath, {
    WhisperOptions? options,
  }) {
    _assertInitialized();
    return _engine!.streamFile(audioPath, options: options);
  }

  /// Cancel any ongoing transcription.
  void cancel() {
    _engine?.cancel();
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _isInitialized = false;
    _loadedModel = null;
  }

  // Platform-specific engine creation
  WhisperEngine _createEngine() {
    return MethodChannelWhisperEngine();
  }

  void _assertInitialized() {
    if (!_isInitialized || _engine == null) {
      throw WhisperError(
        'Whisper not initialized. Call initialize() first.',
        WhisperErrorCode.engineNotInitialized,
      );
    }
  }

  /// Ensure model is available locally, downloading if needed.
  Future<String> _ensureModel(
    WhisperModel model,
    void Function(double)? onProgress,
  ) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/models/${model.name}.bin');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;

    final url = model.downloadUrl;
    final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
    if (request.statusCode != 200) {
      throw WhisperError(
        'Model download failed: HTTP ${request.statusCode}',
        WhisperErrorCode.modelDownloadFailed,
      );
    }

    file.parent.createSync(recursive: true);
    final total = request.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in request.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    onProgress?.call(1.0);
    return file.path;
  }
}