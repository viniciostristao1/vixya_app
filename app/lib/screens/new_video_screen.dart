import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class NewVideoScreen extends StatefulWidget {
  const NewVideoScreen({super.key});
  @override
  State<NewVideoScreen> createState() => _NewVideoScreenState();
}

class _NewVideoScreenState extends State<NewVideoScreen> {
  File? _video;
  final List<File> _shots = [];
  final _objective = TextEditingController();
  String _style = 'dinamico';
  String _model = ''; // '' = padrão do backend
  List<String> _models = [];
  bool _sending = false;

  static const _styles = ['dinamico', 'minimalista', 'tutorial', 'marketing'];

  @override
  void initState() {
    super.initState();
    _loadModels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Config.isSet) _openSettings();
    });
  }

  Future<void> _loadModels() async {
    final m = await Api.models();
    if (mounted) setState(() => _models = m);
  }

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _loadModels();
    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    final p = r?.files.single.path;
    if (p != null) setState(() => _video = File(p));
  }

  Future<void> _pickShots() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (r != null) {
      setState(() => _shots.addAll(r.files.where((f) => f.path != null).map((f) => File(f.path!))));
    }
  }

  Future<void> _generate() async {
    if (_video == null || _objective.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = await Api.createJob(
        files: [_video!, ..._shots],
        objective: _objective.text.trim(),
        style: _style,
        model: _model,
      );
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressScreen(jobId: id)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _video != null && _objective.text.trim().isNotEmpty && Config.isSet;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vixya'),
        actions: [
          IconButton(
            tooltip: 'Recarregar IAs',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadModels();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_models.isEmpty ? 'Ainda sem conexão' : '${_models.length} IAs disponíveis')));
            },
          ),
          IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!Config.isSet)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Toque em ⚙️ e informe o endereço do backend para começar.'),
              ),
            ),
          _tile(Icons.videocam,
              _video == null ? 'Adicionar vídeo (gravação de tela)' : _video!.path.split('/').last, _pickVideo),
          _tile(Icons.image,
              _shots.isEmpty ? 'Adicionar prints (opcional)' : '${_shots.length} print(s)', _pickShots),
          const SizedBox(height: 16),
          TextField(
            controller: _objective,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'O que você quer divulgar?', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _style,
                decoration: const InputDecoration(labelText: 'Estilo', border: OutlineInputBorder()),
                items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _style = v ?? 'dinamico'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _model,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'IA', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('padrão')),
                  ..._models.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _model = v ?? ''),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (ready && !_sending) ? _generate : null,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_sending ? 'Enviando...' : 'GERAR VÍDEO'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) => Card(
        child: ListTile(leading: Icon(icon), title: Text(label), trailing: const Icon(Icons.add), onTap: onTap),
      );
}
