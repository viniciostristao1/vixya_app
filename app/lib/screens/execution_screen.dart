import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../config.dart';
import '../i18n.dart';
import '../store.dart';
import '../theme.dart';
import 'progress_screen.dart';

/// Aba EXECUÇÃO: escolhe o app (perfil), mídia, prompt (ou deixa vazio p/ a IA), estilo,
/// idioma, velocidade e proporção -> GERAR. Sem AppBar próprio (a casca já fornece).
class ExecutionScreen extends StatefulWidget {
  const ExecutionScreen({super.key});
  @override
  State<ExecutionScreen> createState() => _ExecutionScreenState();
}

class _ExecutionScreenState extends State<ExecutionScreen> {
  File? _video;
  final List<File> _shots = [];
  final _objective = TextEditingController();
  String _style = 'auto';
  String _lang = 'pt';
  String _model = 'deepseek-v4-flash';
  String _aspect = '9:16';
  double _speed = 1.0;
  bool _sending = false;

  static const _styles = ['auto', 'dinamico', 'minimalista', 'tutorial', 'marketing', 'hook_viral', 'oferta'];
  static const _styleLabels = {
    'auto': 'Auto Profissional', 'dinamico': 'Dinâmico', 'minimalista': 'Minimalista',
    'tutorial': 'Tutorial', 'marketing': 'Marketing', 'hook_viral': 'Hook Viral', 'oferta': 'Oferta',
  };
  static const _langs = {'pt': 'Português', 'es': 'Espanhol', 'en': 'Inglês'};
  static const _speeds = {0.75: '0.75x', 1.0: '1x', 1.5: '1.5x'};

  @override
  void initState() {
    super.initState();
    _lang = langCtrl.current.value.code;
    langCtrl.current.addListener(_onLang);
    Store.models.addListener(_onStore);
    Store.selectedProjectId.addListener(_onStore);
    Store.pendingObjective.addListener(_onPending);
  }

  void _onLang() { if (mounted) setState(() => _lang = langCtrl.current.value.code); }
  void _onStore() { if (mounted) setState(() {}); }
  void _onPending() {
    final t = Store.pendingObjective.value;
    if (t != null && mounted) {
      setState(() => _objective.text = t);
      Store.pendingObjective.value = null;
    }
  }

  @override
  void dispose() {
    langCtrl.current.removeListener(_onLang);
    Store.models.removeListener(_onStore);
    Store.selectedProjectId.removeListener(_onStore);
    Store.pendingObjective.removeListener(_onPending);
    _objective.dispose();
    super.dispose();
  }

  Future<void> _ensureNoMedia() async {
    try {
      final tmp = await getTemporaryDirectory();
      for (final sub in ['vixya_pick', 'file_picker']) {
        final d = Directory('${tmp.path}/$sub');
        if (!await d.exists()) await d.create(recursive: true);
        final n = File('${d.path}/.nomedia');
        if (!await n.exists()) await n.create();
      }
    } catch (_) {}
  }

  Future<File> _toInternal(File src) async {
    try {
      await _ensureNoMedia();
      final dir = await getTemporaryDirectory();
      final vixyaDir = Directory('${dir.path}/vixya_pick');
      if (!await vixyaDir.exists()) await vixyaDir.create(recursive: true);
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
    if (_video == null) return;
    setState(() => _sending = true);
    try {
      final id = await Api.createJob(
        files: [_video!, ..._shots],
        objective: _objective.text.trim(),
        style: _style,
        model: _model,
        language: _lang,
        aspect: _aspect,
        speed: _speed,
        projectId: Store.selectedProjectId.value,
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
    final models = Store.models.value;
    final profiles = Store.profiles.value;
    final selId = Store.selectedProjectId.value;
    final ready = _video != null && Config.isSet;
    final modelValue = (models.contains(_model) || _model == 'deepseek-v4-flash') ? _model : (models.isNotEmpty ? models.first : 'deepseek-v4-flash');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!Config.isSet)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(tr('backendNeeded'))),
          ),
        // App (perfil) — o que torna a geração boa SEM prompt
        DropdownButtonFormField<String>(
          initialValue: profiles.any((p) => p.projectId == selId) ? selId : '',
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('appLabel'), border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: '', child: Text(tr('noApp'), overflow: TextOverflow.ellipsis)),
            ...profiles.map((p) => DropdownMenuItem(value: p.projectId, child: Text(p.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => Store.setSelected(v ?? ''),
        ),
        const SizedBox(height: 12),
        _tile(Icons.videocam, _video == null ? tr('addVideo') : _video!.path.split('/').last, _pickVideo),
        _tile(Icons.image, _shots.isEmpty ? tr('addPrints') : tr('printsCount', {'n': '${_shots.length}'}), _pickShots),
        const SizedBox(height: 16),
        Stack(children: [
          TextField(
            controller: _objective,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: tr('objective'),
              helperText: tr('promptHint'),
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 44, 12),
            ),
          ),
          Positioned(
            top: 2, right: 2,
            child: IconButton(
              tooltip: 'Limpar', icon: const Icon(Icons.cleaning_services, size: 20),
              onPressed: () => setState(() => _objective.clear()),
            ),
          ),
        ]),
        if (Store.savedPrompts.value.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in Store.savedPrompts.value.take(6))
              ActionChip(
                label: Text(p.length > 34 ? '${p.substring(0, 34)}…' : p, style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _objective.text = p),
              ),
          ]),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _dd(tr('style'), _style, _styles.map((s) => MapEntry(s, _styleLabels[s] ?? s)), (v) => setState(() => _style = v))),
          const SizedBox(width: 12),
          Expanded(child: _dd(tr('langLabel'), _lang, _langs.entries.map((e) => MapEntry(e.key, e.value)), (v) => setState(() => _lang = v))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dd(tr('aspect'), _aspect, {
            '9:16': tr('aspect916'), '1:1': tr('aspect11'), '16:9': tr('aspect169'),
          }.entries.map((e) => MapEntry(e.key, e.value)), (v) => setState(() => _aspect = v))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<double>(
            initialValue: _speed,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('speed'), border: const OutlineInputBorder()),
            items: _speeds.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _speed = v ?? 1.0),
          )),
        ]),
        if (_style == 'auto')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Auto Profissional: IA escolhe estilo e ativa karaoke, CTA pulsa e zoom sozinha.',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: modelValue,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('ia'), border: const OutlineInputBorder()),
          items: [
            if (!models.contains('deepseek-v4-flash'))
              const DropdownMenuItem(value: 'deepseek-v4-flash', child: Text('deepseek-v4-flash ★ padrão')),
            ...models.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))),
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
        Text('v0.1.14 • ${Config.backendUrl}', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _dd(String label, String value, Iterable<MapEntry<String, String>> items, ValueChanged<String> onCh) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => onCh(v ?? value),
      );

  Widget _tile(IconData icon, String label, VoidCallback onTap) => Card(
        child: ListTile(leading: Icon(icon), title: Text(label), trailing: const Icon(Icons.add), onTap: onTap),
      );
}
