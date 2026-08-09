import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';

import 'selected_file.dart';

void main() => runApp(const WhisperSmokeApp());

class WhisperSmokeApp extends StatelessWidget {
  const WhisperSmokeApp({super.key, this.testDevices});

  final List<WhisperDevice>? testDevices;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_whisper_ggml smoke test',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: WhisperSmokePage(testDevices: testDevices),
  );
}

class WhisperSmokePage extends StatefulWidget {
  const WhisperSmokePage({super.key, this.testDevices});

  final List<WhisperDevice>? testDevices;

  @override
  State<WhisperSmokePage> createState() => _WhisperSmokePageState();
}

class _WhisperSmokePageState extends State<WhisperSmokePage> {
  List<WhisperDevice> _devices = const [];
  WhisperDevice? _device;
  SelectedFile? _model;
  SelectedFile? _audio;
  FlutterWhisper? _session;
  String _output = 'Selecione um modelo GGML e um WAV para começar.';
  double _progress = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    try {
      _devices = widget.testDevices ?? FlutterWhisper.availableDevices;
      _device = _devices.firstOrNull;
    } catch (error) {
      _output = 'Não foi possível carregar o runtime: $error';
    }
  }

  Future<void> _selectModel() async {
    final selection = await pickModelFile();
    if (selection == null || !mounted) return;
    releaseSelectedFile(_model);
    setState(() => _model = selection);
  }

  Future<void> _selectAudio() async {
    final selection = await pickWavFile();
    if (selection == null || !mounted) return;
    releaseSelectedFile(_audio);
    setState(() => _audio = selection);
  }

  Future<void> _transcribe() async {
    final model = _model;
    final audio = _audio;
    final device = _device;
    if (model == null || audio == null || device == null || _running) return;

    setState(() {
      _running = true;
      _progress = 0;
      _output = 'Carregando ${model.name}...';
    });

    try {
      final session = await FlutterWhisper.load(
        modelPath: model.path,
        config: WhisperModelConfig.forDevice(device),
        onModelProgress: (value) {
          if (mounted) setState(() => _progress = value / 200);
        },
      );
      _session = session;
      final liveText = StringBuffer();
      final result = await session.transcribeFile(
        audio.path,
        config: const WhisperTranscribeConfig(language: 'auto'),
        onProgress: (value) {
          if (mounted) setState(() => _progress = 0.5 + value / 200);
        },
        onSegment: (segment) {
          liveText.write(segment.text);
          if (mounted) setState(() => _output = liveText.toString().trim());
        },
      );
      if (mounted) {
        setState(() {
          _progress = 1;
          _output = result.text.trim().isEmpty
              ? 'Transcrição concluída sem texto detectado.'
              : result.text.trim();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _output = 'Erro: $error');
    } finally {
      final session = _session;
      _session = null;
      await session?.dispose();
      if (mounted) setState(() => _running = false);
    }
  }

  void _cancel() {
    _session?.cancel();
    setState(() => _output = 'Cancelamento solicitado...');
  }

  @override
  void dispose() {
    releaseSelectedFile(_model);
    releaseSelectedFile(_audio);
    _session?.cancel();
    unawaited(_session?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('flutter_whisper_ggml')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Teste mínimo multiplataforma: escolha um modelo GGML e um arquivo '
          'WAV. O plugin não converte outros formatos.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<WhisperDevice>(
          initialValue: _device,
          decoration: const InputDecoration(
            labelText: 'Dispositivo',
            border: OutlineInputBorder(),
          ),
          items: _devices
              .map(
                (device) => DropdownMenuItem(
                  value: device,
                  child: Text('${device.name} — ${device.description}'),
                ),
              )
              .toList(growable: false),
          onChanged: _running
              ? null
              : (value) => setState(() => _device = value),
        ),
        const SizedBox(height: 12),
        _FileButton(
          label: 'Selecionar modelo GGML',
          fileName: _model?.name,
          onPressed: _running ? null : _selectModel,
        ),
        const SizedBox(height: 12),
        _FileButton(
          label: 'Selecionar áudio WAV',
          fileName: _audio?.name,
          onPressed: _running ? null : _selectAudio,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.icon(
              onPressed:
                  !_running &&
                      _model != null &&
                      _audio != null &&
                      _device != null
                  ? _transcribe
                  : null,
              icon: const Icon(Icons.transcribe),
              label: const Text('Transcrever'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _running ? _cancel : null,
              child: const Text('Cancelar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _running || _progress > 0 ? _progress : 0,
        ),
        const SizedBox(height: 20),
        SelectableText(_output),
      ],
    ),
  );
}

class _FileButton extends StatelessWidget {
  const _FileButton({
    required this.label,
    required this.fileName,
    required this.onPressed,
  });

  final String label;
  final String? fileName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.folder_open),
    label: Text(fileName == null ? label : '$label: $fileName'),
  );
}
