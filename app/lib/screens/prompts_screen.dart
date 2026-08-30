import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../store.dart';

/// Aba PROMPTS: (1) perfil do app (o que faz a geração ser boa sem prompt),
/// (2) prompts sugeridos pela IA a partir do perfil, (3) prompts salvos pelo usuário.
class PromptsScreen extends StatefulWidget {
  const PromptsScreen({super.key});
  @override
  State<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends State<PromptsScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _feat = TextEditingController();
  final _pub = TextEditingController();
  final _cta = TextEditingController();
  final _colors = TextEditingController();
  String _editingId = ''; // '' = novo app
  bool _savingProfile = false;
  bool _suggesting = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    Store.profiles.addListener(_onStore);
    Store.savedPrompts.addListener(_onStore);
    _loadInto(Store.selected);
  }

  void _onStore() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    Store.profiles.removeListener(_onStore);
    Store.savedPrompts.removeListener(_onStore);
    for (final c in [_name, _desc, _feat, _pub, _cta, _colors]) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadInto(AppProfile? p) {
    _editingId = p?.projectId ?? '';
    _name.text = p?.name ?? '';
    _desc.text = p?.descricao ?? '';
    _feat.text = p?.funcionalidades ?? '';
    _pub.text = p?.publico ?? '';
    _cta.text = p?.cta ?? '';
    _colors.text = p?.cores ?? '';
    _suggestions = [];
    if (mounted) setState(() {});
  }

  AppProfile _formProfile() => AppProfile(
        projectId: _editingId,
        name: _name.text.trim(),
        descricao: _desc.text.trim(),
        funcionalidades: _feat.text.trim(),
        publico: _pub.text.trim(),
        cta: _cta.text.trim(),
        cores: _colors.text.trim(),
      );

  Future<void> _saveProfile() async {
    if (_name.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      _snack(tr('fillProfile'));
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final p = _formProfile();
      await Store.saveProfile(p);
      _editingId = p.projectId;
      if (mounted) setState(() => _savingProfile = false);
      _snack(tr('profileSaved'));
      await _suggest(); // já preenche os "Sugeridos pela IA" logo após salvar
    } catch (e) {
      if (mounted) setState(() => _savingProfile = false);
      _snack('Erro: $e');
    }
  }

  Future<void> _deleteApp() async {
    if (_editingId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(tr('deleteApp')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok == true) {
      await Store.removeProfile(_editingId);
      _loadInto(null);
    }
  }

  Future<void> _suggest() async {
    if (_name.text.trim().isEmpty && _editingId.isEmpty) {
      _snack(tr('fillProfile'));
      return;
    }
    setState(() { _suggesting = true; _suggestions = []; });
    try {
      final list = await Api.suggestPrompts(
        projectId: _editingId,
        name: _name.text.trim(),
        descricao: _desc.text.trim(),
        funcionalidades: _feat.text.trim(),
        publico: _pub.text.trim(),
        cta: _cta.text.trim(),
        language: langCtrl.current.value.code,
      );
      if (mounted) setState(() => _suggestions = list);
      if (list.isEmpty) _snack(tr('noSuggestions'));
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  void _usePrompt(String p) {
    Store.pendingObjective.value = p;
    _snack(tr('usedInExec'));
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final profiles = Store.profiles.value;
    final saved = Store.savedPrompts.value;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---------------- Meu app (perfil) ----------------
        Row(children: [
          Expanded(child: Text(tr('myApp'), style: Theme.of(context).textTheme.titleMedium)),
          TextButton.icon(
            onPressed: () => _loadInto(null),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr('newApp')),
          ),
        ]),
        Text(tr('oneProfilePerApp'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: profiles.any((p) => p.projectId == _editingId) ? _editingId : '',
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          items: [
            DropdownMenuItem(value: '', child: Text(tr('newApp'))),
            ...profiles.map((p) => DropdownMenuItem(value: p.projectId, child: Text(p.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) {
            if (v == null || v.isEmpty) {
              _loadInto(null);
            } else {
              _loadInto(profiles.firstWhere((p) => p.projectId == v));
            }
          },
        ),
        const SizedBox(height: 6),
        if (_editingId.isNotEmpty && profiles.any((p) => p.projectId == _editingId))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Icons.check_circle, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('editingApp', {'n': _name.text.trim()}),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary))),
            ]),
          ),
        _field(_name, tr('pName')),
        _field(_desc, tr('pDesc'), lines: 2),
        _field(_feat, tr('pFeatures'), lines: 2),
        _field(_pub, tr('pAudience')),
        _field(_cta, tr('pCta')),
        _field(_colors, tr('pColors')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _savingProfile ? null : _saveProfile,
              icon: _savingProfile
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(tr('saveProfile')),
            ),
          ),
          if (_editingId.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(tooltip: tr('delete'), onPressed: _deleteApp, icon: const Icon(Icons.delete_outline)),
          ],
        ]),
        const Divider(height: 32),

        // ---------------- Sugeridos pela IA ----------------
        Text(tr('suggested'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _suggesting ? null : _suggest,
          icon: _suggesting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_suggesting ? tr('suggesting') : tr('suggestPrompts')),
        ),
        const SizedBox(height: 8),
        for (final s in _suggestions) _promptCard(s, suggestion: true),
        const Divider(height: 32),

        // ---------------- Meus prompts ----------------
        Text(tr('myPrompts'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (saved.isEmpty)
          Padding(padding: const EdgeInsets.all(8), child: Text(tr('savedEmpty'), style: const TextStyle(color: Colors.grey, fontSize: 12))),
        for (final s in saved) _promptCard(s, suggestion: false),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 1,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  Widget _promptCard(String s, {required bool suggestion}) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(children: [
            Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
            TextButton(onPressed: () => _usePrompt(s), child: Text(tr('use'))),
            if (suggestion)
              IconButton(
                tooltip: tr('saved'),
                icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                onPressed: () { Store.addPrompt(s); _snack(tr('saved')); },
              )
            else
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => Store.removePrompt(s),
              ),
          ]),
        ),
      );
}
