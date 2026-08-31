import 'dart:convert';

import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';

/// Ajuste MANUAL dos textos do vídeo (o usuário corrige qual frase aparece em qual cena).
/// A IA acerta o tempo (troca a frase na transição); aqui o usuário conserta o CONTEXTO:
/// editar o texto de cada cena ou mover a frase p/ a cena vizinha (↑ ↓). Refaz o preview.
class AdjustScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> plan;
  const AdjustScreen({super.key, required this.jobId, required this.plan});
  @override
  State<AdjustScreen> createState() => _AdjustScreenState();
}

class _Entry {
  final int scene;
  final int eff;
  final TextEditingController ctrl;
  _Entry(this.scene, this.eff, String text) : ctrl = TextEditingController(text: text);
}

class _AdjustScreenState extends State<AdjustScreen> {
  late Map<String, dynamic> _plan;
  final List<_Entry> _entries = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plan = jsonDecode(jsonEncode(widget.plan)) as Map<String, dynamic>; // cópia editável
    final scenes = (_plan['scenes'] as List?) ?? [];
    for (var s = 0; s < scenes.length; s++) {
      final effs = (scenes[s]['effects'] as List?) ?? [];
      for (var e = 0; e < effs.length; e++) {
        final op = (effs[e]['op'] ?? '').toString();
        if (op == 'text' || op == 'caption') {
          _entries.add(_Entry(s, e, (effs[e]['text'] ?? '').toString()));
        }
      }
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.ctrl.dispose();
    }
    super.dispose();
  }

  void _swap(int i, int j) {
    if (j < 0 || j >= _entries.length) return;
    final t = _entries[i].ctrl.text;
    _entries[i].ctrl.text = _entries[j].ctrl.text;
    _entries[j].ctrl.text = t;
    setState(() {});
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final scenes = _plan['scenes'] as List;
      for (final e in _entries) {
        (scenes[e.scene]['effects'] as List)[e.eff]['text'] = e.ctrl.text.trim();
      }
      await Api.requestVersion(widget.jobId, planJson: jsonEncode(_plan));
      if (mounted) Navigator.pop(context, true); // volta -> a tela de progresso repolla o novo preview
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('adjustTitle'))),
      body: _entries.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('noCaptions'), textAlign: TextAlign.center)))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(tr('adjustHelp'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: e.ctrl,
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: tr('sceneN', {'n': '${e.scene + 1}'}),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          Column(children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_upward, size: 20),
                              onPressed: i > 0 ? () => _swap(i, i - 1) : null,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_downward, size: 20),
                              onPressed: i < _entries.length - 1 ? () => _swap(i, i + 1) : null,
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _apply,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(tr('applyRedo')),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ]),
    );
  }
}
