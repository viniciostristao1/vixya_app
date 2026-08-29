import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../config.dart';
import '../i18n.dart';
import '../theme.dart';
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
  String _lang = 'pt';
  String _model = 'deepseek-v4-flash';
  List<String> _models = [];
  bool _sending = false;

  static const _styles = ['dinamico', 'minimalista', 'tutorial', 'marketing'];
  static const _langs = {'pt': 'Português', 'es': 'Espanhol', 'en': 'Inglês'};

  @override
  void initState() {
    super.initState();
    _lang = langCtrl.current.value.code;
    langCtrl.current.addListener(_onLangChanged);
    _loadModels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Config.isSet) _openSettings();
    });
  }

  void _onLangChanged() {
    if (mounted) setState(() => _lang = langCtrl.current.value.code);
  }

  @override
  void dispose() {
    langCtrl.current.removeListener(_onLangChanged);
    _objective.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final m = await Api.models();
    if (mounted) {
      setState(() {
        _models = m;
        if (!_models.contains(_model) && _model != 'deepseek-v4-flash') {
          _model = _models.isNotEmpty ? _models.first : 'deepseek-v4-flash';
        }
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _loadModels();
    if (mounted) setState(() {});
  }

  Future<File> _toInternal(File src) async {
    try {
      final dir = await getTemporaryDirectory();
      final vixyaDir = Directory('${dir.path}/vixya_pick');
      if (!await vixyaDir.exists()) await vixyaDir.create(recursive: true);
      final nomedia = File('${vixyaDir.path}/.nomedia');
      if (!await nomedia.exists()) await nomedia.create();
      final name = src.path.split('/').last;
      final dst = File('${vixyaDir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
      if (await dst.exists()) await dst.delete();
      return await src.copy(dst.path);
    } catch (_) {
      return src;
    }
  }

  Future<void> _pickVideo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    final p = r?.files.single.path;
    if (p != null) {
      final f = await _toInternal(File(p));
      if (mounted) setState(() => _video = f);
    } else if (r?.files.single.bytes != null) {
      final dir = await getTemporaryDirectory();
      final vixyaDir = Directory('${dir.path}/vixya_pick');
      if (!await vixyaDir.exists()) await vixyaDir.create(recursive: true);
      final f = File('${vixyaDir.path}/${DateTime.now().millisecondsSinceEpoch}_${r!.files.single.name}');
      await f.writeAsBytes(r.files.single.bytes!);
      if (mounted) setState(() => _video = f);
    }
  }

  Future<void> _pickShots() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (r != null) {
      final List<File> copied = [];
      for (final pf in r.files) {
        if (pf.path != null) {
          copied.add(await _toInternal(File(pf.path!)));
        } else if (pf.bytes != null) {
          final dir = await getTemporaryDirectory();
          final vixyaDir = Directory('${dir.path}/vixya_pick');
          if (!await vixyaDir.exists()) await vixyaDir.create(recursive: true);
          final f = File('${vixyaDir.path}/${DateTime.now().millisecondsSinceEpoch}_${pf.name}');
          await f.writeAsBytes(pf.bytes!);
          copied.add(f);
        }
      }
      if (mounted && copied.isNotEmpty) setState(() => _shots.addAll(copied));
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
        language: _lang,
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
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset('assets/icon/icon.png', width: 30, height: 30, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          const Text('Vixya'),
        ]),
        actions: [
          IconButton(
            tooltip: tr('reloadIA'),
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadModels();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_models.isEmpty ? tr('noConnection') : tr('iasAvailable', {'n': '${_models.length}'}))));
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tr('backendNeeded')),
              ),
            ),
          _tile(Icons.videocam, _video == null ? tr('addVideo') : _video!.path.split('/').last, _pickVideo),
          _tile(Icons.image, _shots.isEmpty ? tr('addPrints') : tr('printsCount', {'n': '${_shots.length}'}), _pickShots),
          const SizedBox(height: 16),
          TextField(
            controller: _objective,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('objective'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _style,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('style'), border: const OutlineInputBorder()),
                items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _style = v ?? 'dinamico'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _lang,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('langLabel'), border: const OutlineInputBorder()),
                items: _langs.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _lang = v ?? 'pt'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _models.contains(_model) || _model == 'deepseek-v4-flash' ? _model : (_models.isNotEmpty ? _models.first : 'deepseek-v4-flash'),
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('ia'), border: const OutlineInputBorder()),
            items: [
              if (!_models.contains('deepseek-v4-flash'))
                const DropdownMenuItem(value: 'deepseek-v4-flash', child: Text('deepseek-v4-flash')),
              ..._models.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _model = v ?? 'deepseek-v4-flash'),
          ),
          const SizedBox(height: 24),
          GerarButton(
            onPressed: (ready && !_sending) ? _generate : null,
            sending: _sending,
            label: _sending ? tr('sending') : tr('generate'),
          ),
          const SizedBox(height: 12),
          Text('v0.1.9 • ${Config.backendUrl}', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) => Card(
        child: ListTile(leading: Icon(icon), title: Text(label), trailing: const Icon(Icons.add), onTap: onTap),
      );
}
