import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_whisper/flutter_whisper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WhisperDemoApp());

class WhisperDemoApp extends StatelessWidget {
  const WhisperDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Whisper Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const WhisperDemoScreen(),
    );
  }
}

enum AppState { idle, downloading, paused, initializing, ready, recording, transcribing, error }

class WhisperDemoScreen extends StatefulWidget {
  const WhisperDemoScreen({super.key});

  @override
  State<WhisperDemoScreen> createState() => _WhisperDemoScreenState();
}

class _WhisperDemoScreenState extends State<WhisperDemoScreen> {
  static const _onboardingKey = 'onboarding_done';

  final Whisper _whisper = Whisper();

  WhisperModel _selected = WhisperModel.tiny;
  AppState _state = AppState.idle;
  String _status = '';
  String _hint = '';
  WhisperDownloadProgress? _dl;
  String _errorDetail = '';
  File? _audioFile;
  TranscriptionResult? _result;
  bool _onboardingDone = false;
  late Map<WhisperModel, bool> _cached = {for (final m in WhisperModel.values) m: false};

  // Recording + transcription progress.
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  int _transcribeProgress = 0;
  String _language = 'auto';

  // History (JSONL in app support dir).
  File? _historyFile;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
    _refreshCached();
    _initHistory();
    _setIdle();
  }

  Future<void> _initHistory() async {
    final dir = await _appSupportPath();
    _historyFile = File('$dir/history.jsonl');
    if (_historyFile!.existsSync()) {
      try {
        _history = _historyFile!
            .readAsLinesSync()
            .map((l) => jsonDecode(l) as Map<String, dynamic>)
            .toList();
      } catch (_) {}
    }
  }

  Future<void> _loadOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _onboardingDone = prefs.getBool(_onboardingKey) ?? false);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    setState(() => _onboardingDone = true);
  }

  Future<void> _refreshCached() async {
    try {
      final dir = await _whisperSupportDir();
      final models = Directory('$dir/models');
      setState(() {
        _cached = {
          for (final m in WhisperModel.values)
            m: File('${models.path}/${m.name}.bin').existsSync(),
        };
      });
    } catch (_) {}
  }

  Future<String> _whisperSupportDir() async {
    // Same path the plugin uses (application support directory).
    final path = await _appSupportPath();
    return path;
  }

  Future<String> _appSupportPath() async {
    return (await getApplicationSupportDirectory()).path;
  }

  // ---- State transitions ----

  void _setIdle() {
    setState(() {
      _state = AppState.idle;
      _status = 'Not initialized';
      _hint = 'Pick a model, then download. Transcription runs on your phone.';
      _dl = null;
    });
  }

  void _setError(String title, String detail) {
    setState(() {
      _state = AppState.error;
      _status = title;
      _hint = 'Fix the issue, then retry.';
      _errorDetail = detail;
      _dl = null;
    });
  }

  String _friendlyError(Object e) {
    if (e is PlatformException) {
      switch (e.code) {
        case 'NATIVE_NOT_BUILT':
          return 'Native whisper engine not installed in this dev build.';
        case 'MODEL_NOT_FOUND':
          return 'Model file missing. Try downloading again.';
        case 'NOT_INITIALIZED':
          return 'Engine not initialized yet.';
      }
      return e.message ?? e.code;
    }
    if (e is WhisperError) {
      switch (e.code) {
        case WhisperErrorCode.modelDownloadFailed:
          return 'Download failed. Check your network, then retry — it resumes where it stopped.';
        case WhisperErrorCode.cancelled:
          return 'Download cancelled.';
        case WhisperErrorCode.downloadPaused:
          return 'Download paused.';
        default:
          return e.message;
      }
    }
    return '$e';
  }

  // ---- Actions ----

  Future<void> _initialize() async {
    setState(() {
      _state = AppState.downloading;
      _status = 'Downloading ${_selected.name}…';
      _hint = 'You can leave the app — download resumes where it stopped.';
      _dl = null;
    });
    try {
      await _whisper.initialize(
        model: _selected,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _dl = p;
            if (p.fraction < 1.0) {
              _status = 'Downloading ${_selected.name} '
                  '${(p.fraction * 100).toStringAsFixed(0)}%';
            } else {
              _status = 'Initializing ${_selected.name}…';
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _state = AppState.ready;
        _status = 'Ready — ${_selected.name} loaded';
        _hint = 'Transcribe a file, or try the sample below.';
        _dl = null;
      });
      _refreshCached();
    } catch (e) {
      if (!mounted) return;
      if (e is WhisperError && e.code == WhisperErrorCode.downloadPaused) {
        setState(() {
          _state = AppState.paused;
          _status = 'Paused — ${_selected.name} '
              '${_dl != null ? '${(_dl!.fraction * 100).toStringAsFixed(0)}%' : ''}';
          _hint = 'Resume anytime — nothing is lost.';
        });
      } else if (e is WhisperError && e.code == WhisperErrorCode.cancelled) {
        _setIdle();
      } else {
        _setError(_friendlyError(e), '$e');
      }
    }
  }

  Future<void> _resumeDownload() async {
    setState(() {
      _state = AppState.downloading;
      _status = 'Resuming download…';
      _hint = 'Picking up where it stopped.';
    });
    try {
      await _whisper.resumeDownload();
      if (!mounted) return;
      setState(() {
        _state = AppState.ready;
        _status = 'Ready — ${_selected.name} loaded';
        _hint = 'Transcribe a file, or try the sample below.';
        _dl = null;
      });
      _refreshCached();
    } catch (e) {
      if (!mounted) return;
      _setError(_friendlyError(e), '$e');
    }
  }

  Future<void> _pickAudioFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (picked == null || picked.files.isEmpty) return;
    setState(() {
      _audioFile = File(picked.files.first.path!);
      _result = null;
    });
  }

  Future<void> _trySample() async {
    setState(() => _status = 'Loading sample…');
    try {
      final bytes = await rootBundle.load('assets/sample.wav');
      final dir = await _appSupportPath();
      final sample = File('$dir/sample.wav');
      await sample.writeAsBytes(bytes.buffer.asUint8List());
      setState(() {
        _audioFile = sample;
        _result = null;
        _status = 'Sample ready — transcribe it.';
      });
    } catch (e) {
      _setError('Could not load sample', '$e');
    }
  }

  Future<void> _transcribe() async {
    final file = _audioFile;
    if (file == null || _state != AppState.ready) return;
    setState(() {
      _state = AppState.transcribing;
      _status = 'Transcribing…';
      _hint = 'On-device — no data leaves your phone.';
      _transcribeProgress = 0;
      _result = null;
    });
    final options = _language == 'auto' ? null : WhisperOptions(language: _language);
    try {
      final result = await _whisper.transcribeFile(
        file.path,
        options: options,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _transcribeProgress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _state = AppState.ready;
        _status = 'Done';
        _hint = 'Transcribe another file, or record your voice.';
        _result = result;
      });
      _appendHistory(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = AppState.ready;
        if (e is PlatformException && e.code == 'TRANSCRIPTION_CANCELLED') {
          _status = 'Cancelled';
          _hint = 'Tap Transcribe to start over.';
        } else {
          _status = 'Transcription failed';
          _hint = _friendlyError(e);
        }
      });
    }
  }

  // ---- Recording ----

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Microphone permission'),
          content: const Text('Recording needs mic access. '
              'Open Settings and allow it, then come back.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (open == true) await openAppSettings();
      return false;
    }
    return false;
  }

  Future<void> _startRecording() async {
    if (_state != AppState.ready) return;
    if (!await _ensureMicPermission()) return;
    try {
      await _whisper.startRecording();
      if (!mounted) return;
      setState(() {
        _state = AppState.recording;
        _recording = true;
        _recordSeconds = 0;
        _status = 'Recording…';
        _hint = 'Speak now. Tap Stop when done.';
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (!mounted) return;
      _setError('Could not start recording', '$e');
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    setState(() {
      _recording = false;
      _state = AppState.transcribing;
      _status = 'Transcribing recording…';
      _hint = 'On-device — no data leaves your phone.';
      _transcribeProgress = 0;
    });
    try {
      final path = await _whisper.stopRecording();
      if (!mounted) return;
      _audioFile = File(path);
      await _transcribe();
    } catch (e) {
      if (!mounted) return;
      _setError('Could not finish recording', '$e');
    }
  }

  void _appendHistory(TranscriptionResult r) {
    final f = _historyFile;
    if (f == null) return;
    final entry = {
      'text': r.text,
      'language': r.language,
      'duration': r.duration,
      'ts': DateTime.now().toIso8601String(),
    };
    _history.insert(0, entry);
    if (_history.length > 200) _history.removeRange(200, _history.length);
    try {
      f.writeAsStringSync(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  void _selectModel(WhisperModel m) {
    if (m == _selected) return;
    setState(() => _selected = m);

    final cached = _cached[m] == true;
    if (_state == AppState.ready) {
      _showSwitchConfirm(m);
    } else if (cached) {
      // Model already downloaded — initialize immediately.
      _initialize();
    } else {
      // Not cached — go to idle, user must tap the download button in the card.
      _setIdle();
    }
  }

  void _showSwitchConfirm(WhisperModel m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch model?'),
        content: Text('Load ${m.name.toUpperCase()} (${m.fileSizeHuman})? '
            'Current session will reload.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initialize();
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    if (!_onboardingDone) {
      return OnboardingScreen(onDone: _finishOnboarding);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Whisper'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(
                  history: List.of(_history),
                  onClear: () {
                    _history = [];
                    _historyFile?.deleteSync();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ),
          ),
          if (_state == AppState.ready || _state == AppState.transcribing)
            IconButton(
              tooltip: 'Reset',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _whisper.dispose();
                _setIdle();
                _refreshCached();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCapabilityChips(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            if (_state == AppState.ready ||
                _state == AppState.recording ||
                _state == AppState.transcribing) ...[
              const SizedBox(height: 16),
              _buildActions(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(),
            ],
            const SizedBox(height: 24),
            _buildModelSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityChips() {
    return const Wrap(
      spacing: 8,
      children: [
        Chip(avatar: Icon(Icons.cloud_off, size: 16), label: Text('Offline')),
        Chip(avatar: Icon(Icons.smartphone, size: 16), label: Text('On-device')),
        Chip(avatar: Icon(Icons.lock_outline, size: 16), label: Text('No uploads')),
        Chip(avatar: Icon(Icons.language, size: 16), label: Text('Multilingual')),
      ],
    );
  }

  Widget _buildStatusCard() {
    final (icon, color) = switch (_state) {
      AppState.idle => (Icons.mic_none, Colors.blueGrey),
      AppState.downloading || AppState.paused => (Icons.download, Colors.blue),
      AppState.initializing => (Icons.settings, Colors.blue),
      AppState.ready => (Icons.check_circle, Colors.green),
      AppState.recording => (Icons.mic, Colors.red),
      AppState.transcribing => (Icons.graphic_eq, Colors.teal),
      AppState.error => (Icons.error, Colors.red),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(_status, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            if (_state == AppState.downloading && _dl != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _dl!.fraction.clamp(0.0, 1.0)),
              const SizedBox(height: 8),
              Text(_formatProgress(_dl!), style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_state == AppState.downloading && _dl == null) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_state == AppState.transcribing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _transcribeProgress / 100),
              const SizedBox(height: 8),
              Text('$_transcribeProgress%',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_state == AppState.recording) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _fmtDuration(Duration(seconds: _recordSeconds)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(_hint, style: Theme.of(context).textTheme.bodySmall),
            if (_state == AppState.downloading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _whisper.pauseDownload,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cancel download',
                    onPressed: _whisper.cancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
            if (_state == AppState.paused) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _resumeDownload,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume download'),
              ),
            ],
            if (_state == AppState.error) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Details', style: TextStyle(fontSize: 13)),
                children: [
                  SelectableText(_errorDetail, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _initialize,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatProgress(WhisperDownloadProgress p) {
    final received = _fmtBytes(p.receivedBytes);
    final total = _fmtBytes(p.totalBytes);
    final speed = p.speedBytesPerSec != null ? '${_fmtBytes(p.speedBytesPerSec!.round())}/s' : '';
    final eta = p.eta != null ? ' • ETA ${_fmtDuration(p.eta!)}' : '';
    return '$received / $total$speed$eta';
  }

  static String _fmtBytes(int b) {
    if (b >= 1024 * 1024 * 1024) return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  static String _fmtDuration(Duration d) {
    final s = d.inSeconds;
    if (s >= 3600) return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
    if (s >= 60) return '${s ~/ 60}m ${s % 60}s';
    return '${s}s';
  }

  Widget _buildActions() {
    final busy = _state == AppState.transcribing;
    final recording = _state == AppState.recording;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Transcribe', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                DropdownButton<String>(
                  value: _language,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto language')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                    DropdownMenuItem(value: 'es', child: Text('Spanish')),
                    DropdownMenuItem(value: 'fr', child: Text('French')),
                    DropdownMenuItem(value: 'de', child: Text('German')),
                    DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                    DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  ],
                  onChanged: recording || busy
                      ? null
                      : (v) => setState(() => _language = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: recording ? Colors.red : null,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: recording
                  ? _stopAndTranscribe
                  : busy
                      ? null
                      : _startRecording,
              icon: Icon(recording ? Icons.stop : Icons.mic),
              label: Text(
                recording
                    ? 'Stop & Transcribe'
                    : busy
                        ? 'Transcribing…'
                        : 'Record & Transcribe',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (busy || recording) ? null : _pickAudioFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Pick audio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (busy || recording) ? null : _trySample,
                    icon: const Icon(Icons.audio_file),
                    label: const Text('Try sample'),
                  ),
                ),
              ],
            ),
            if (_audioFile != null && !recording) ...[
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                leading: const Icon(Icons.music_note),
                title: Text(_audioFile!.path.split('/').last,
                    overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _audioFile = null),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: busy ? null : _transcribe,
                icon: const Icon(Icons.transcribe),
                label: const Text('Transcribe file'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Result', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (r.language.isNotEmpty)
                  Chip(label: Text(r.language), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(r.text, style: const TextStyle(fontSize: 15, height: 1.4)),
            if (r.segments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Segments', style: TextStyle(fontSize: 13)),
                children: [
                  for (final s in r.segments)
                    ListTile(
                      dense: true,
                      leading: Text(
                        '[${s.start.toStringAsFixed(1)}-${s.end.toStringAsFixed(1)}s]',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                      title: Text(s.text, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy text',
                    icon: const Icon(Icons.copy),
                    onPressed: () => Clipboard.setData(ClipboardData(text: r.text)),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.share(
                      r.text,
                      subject: 'Transcription (${r.language})',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Models', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final m in WhisperModel.values)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: m == _selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: ListTile(
              onTap: () => _selectModel(m),
              leading: Icon(
                m == WhisperModel.tiny
                    ? Icons.flash_on
                    : m == WhisperModel.large
                        ? Icons.verified
                        : Icons.mic,
                color: m == _selected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(m.name.toUpperCase()),
              subtitle: Text('${m.fileSizeHuman} • ${m.isMultilingual ? 'Multilingual' : 'English only'}'),
              trailing: _buildModelAction(m),
            ),
          ),
      ],
    );
  }

  Widget _buildModelAction(WhisperModel m) {
    final cached = _cached[m] == true;
    final isSelected = m == _selected;

    // If already initialized with this model
    if (_state == AppState.ready && isSelected) {
      return const Chip(
        avatar: Icon(Icons.check_circle, size: 14, color: Colors.green),
        label: Text('Loaded'),
        visualDensity: VisualDensity.compact,
      );
    }

    // Cached but not loaded — offer to initialize
    if (cached) {
      return FilledButton.tonal(
        onPressed: () => _selectModel(m),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Initialize'),
      );
    }

    // Not cached — radio to select and download
    return Radio<WhisperModel>(
      value: m,
      groupValue: _selected,
      onChanged: (_) => _selectModel(m),
    );
  }
}

/// First-run onboarding — teaches what the app does.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          children: [
            _Slide(
              icon: Icons.cloud_off,
              title: 'Transcribe offline',
              body: 'Speech-to-text on your phone. No cloud, no uploads — '
                  'works without internet.',
              onDone: onDone,
            ),
            _Slide(
              icon: Icons.linear_scale,
              title: 'Pick a model',
              body: '5 sizes from 74 MB (fast) to 2.9 GB (most accurate). '
                  'Smaller = faster, bigger = better.',
              onDone: onDone,
            ),
            _Slide(
              icon: Icons.download_done,
              title: 'Download once',
              body: 'The model downloads to your phone, then everything runs '
                  'locally. Downloads resume — kill the app and pick up '
                  'where you left off.',
              isLast: true,
              onDone: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.onDone,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isLast;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(body, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onDone,
            child: Text(isLast ? 'Get started' : 'Skip'),
          ),
        ],
      ),
    );
  }
}

/// Saved transcriptions (JSONL history).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.history, required this.onClear});

  final List<Map<String, dynamic>> history;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                onClear();
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No transcriptions yet'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, i) {
                final e = history[i];
                final text = e['text'] as String;
                final ts = (e['ts'] as String).replaceFirst('T', ' ').split('.').first;
                return ListTile(
                  leading: const Icon(Icons.transcribe),
                  title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${e['language']} • $ts'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('$ts • ${e['language']}'),
                      content: SingleChildScrollView(
                        child: SelectableText(text),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy),
                          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
