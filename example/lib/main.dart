import 'package:flutter/material.dart';
import 'package:flutter_whisper/flutter_whisper.dart';
import 'dart:io';

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
      ),
      home: const WhisperDemoScreen(),
    );
  }
}

class WhisperDemoScreen extends StatefulWidget {
  const WhisperDemoScreen({super.key});

  @override
  State<WhisperDemoScreen> createState() => _WhisperDemoScreenState();
}

class _WhisperDemoScreenState extends State<WhisperDemoScreen> {
  final Whisper _whisper = Whisper();
  WhisperModel _selectedModel = WhisperModel.tiny;
  bool _isInitialized = false;
  bool _isTranscribing = false;
  String _result = '';
  String _status = 'Not initialized';
  double _progress = 0.0;
  File? _audioFile;

  @override
  void dispose() {
    _whisper.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _status = 'Downloading ${_selectedModel.name}...';
      _progress = 0.0;
    });

    try {
      await Whisper().initialize(
        model: _selectedModel,
        onProgress: (p) {
          setState(() {
            _progress = p;
            if (p < 1.0) {
              _status = 'Downloading ${_selectedModel.name} '
                  '${(p * 100).toStringAsFixed(0)}%';
            } else {
              _status = 'Initializing...';
            }
          });
        },
      );
      setState(() {
        _isInitialized = true;
        _status = 'Ready with ${_selectedModel.name} (${_selectedModel.fileSizeHuman})';
      });
    } catch (e) {
      setState(() {
        _progress = 0.0;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _pickAudioFile() async {
    // In real app, use file_picker
    setState(() => _status = 'File picker not implemented in demo');
  }

  Future<void> _transcribe() async {
    if (!_isInitialized || _audioFile == null) return;

    setState(() {
      _isTranscribing = true;
      _result = '';
      _progress = 0.0;
    });

    try {
      final result = await Whisper().transcribeFile(_audioFile!.path);
      setState(() {
        _result = result.text;
        _isTranscribing = false;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _result = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Whisper Demo'),
        actions: [
          if (_isInitialized)
            PopupMenuButton<WhisperModel>(
              initialValue: _selectedModel,
              onSelected: (model) {
                setState(() => _selectedModel = model);
                _initialize();
              },
              itemBuilder: (context) => WhisperModel.values.map((m) => PopupMenuItem(
                value: m,
                child: Text('${m.name} (${m.fileSizeHuman})'),
              )).toList(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_progress > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _progress),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isInitialized) ...[
              FilledButton.icon(
                onPressed: _initialize,
                icon: const Icon(Icons.download),
                label: Text('Download & Initialize ${_selectedModel.name}'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Pick Audio File'),
              ),
              const SizedBox(height: 12),
              if (_audioFile != null) ...[
                FilledButton.icon(
                  onPressed: _isTranscribing ? null : _transcribe,
                  icon: _isTranscribing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.mic),
                  label: Text(_isTranscribing ? 'Transcribing...' : 'Transcribe'),
                ),
              ],
            ],
            const SizedBox(height: 24),
            if (_result.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transcription', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SelectableText(_result),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            Text('Models', style: Theme.of(context).textTheme.titleMedium),
            ...WhisperModel.values.map((m) => ListTile(
              title: Text(m.name.toUpperCase()),
              subtitle: Text('${m.fileSizeHuman} • ${m.isMultilingual ? 'Multilingual' : 'English only'}'),
              leading: Icon(m == WhisperModel.tiny ? Icons.flash_on :
                           m == WhisperModel.large ? Icons.verified : Icons.mic),
            )),
          ],
        ),
      ),
    );
  }
}
