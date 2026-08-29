import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../i18n.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController(text: Config.backendUrl);
  final _token = TextEditingController(text: Config.token);
  String? _msg;
  bool _busy = false;
  bool _themesExpanded = false;
  bool _langsExpanded = false;

  Future<void> _test() async {
    setState(() { _busy = true; _msg = null; });
    await Config.save(_url.text, _token.text);
    try {
      final h = await Api.health();
      setState(() => _msg = tr('connected', {'n': '${h['disk_free_gb']}'}));
    } catch (e) {
      setState(() => _msg = tr('notConnected', {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() { _busy = true; _msg = null; });
    await Config.clearSaved();
    await Config.refreshFromRemote(force: true);
    _url.text = Config.backendUrl;
    _token.text = Config.token;
    try {
      final h = await Api.health();
      setState(() => _msg = tr('restored', {'n': '${h['disk_free_gb']}'}));
    } catch (e) {
      setState(() => _msg = tr('restoredFail', {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _themeTile(VixyaTheme t) {
    final selected = themeCtrl.current.value.id == t.id;
    return Card(
      child: ListTile(
        onTap: () async {
          await themeCtrl.set(t);
          if (mounted) setState(() {});
        },
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: LinearGradient(colors: t.btnGradient ?? [t.primary, t.accent]),
            boxShadow: t.glow
                ? [BoxShadow(color: t.primary.withValues(alpha: .28), blurRadius: 6, spreadRadius: -2)]
                : null,
          ),
        ),
        title: Text(t.name),
        subtitle: t.tag.isNotEmpty ? Text(t.tag) : null,
        trailing: selected ? Icon(Icons.check_circle, color: t.primary) : null,
      ),
    );
  }

  Widget _langTile(AppLanguage l) {
    final selected = langCtrl.current.value == l;
    return Card(
      child: ListTile(
        onTap: () async {
          await langCtrl.set(l);
          if (mounted) setState(() {});
        },
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: Text(l.flag, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        title: Text(l.label),
        subtitle: Text(l.code.toUpperCase()),
        trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ExpansionTile(
              title: Text(tr('themes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(themeCtrl.current.value.name, style: TextStyle(color: themeCtrl.current.value.muted, fontSize: 12)),
              trailing: Icon(_themesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              onExpansionChanged: (v) => setState(() => _themesExpanded = v),
              initiallyExpanded: _themesExpanded,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: kThemes.map(_themeTile).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              title: Text(tr('languages'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(langCtrl.current.value.label, style: TextStyle(color: themeCtrl.current.value.muted, fontSize: 12)),
              trailing: Icon(_langsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              onExpansionChanged: (v) => setState(() => _langsExpanded = v),
              initiallyExpanded: _langsExpanded,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: AppLanguage.values.map(_langTile).toList(),
            ),
          ),
          const Divider(height: 32),
          Text(tr('backendUrl')),
          const SizedBox(height: 6),
          TextField(controller: _url, keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://seu-servidor:8090', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Text(tr('token')),
          const SizedBox(height: 6),
          TextField(controller: _token, obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () async {
              await Config.save(_url.text, _token.text);
              if (mounted) Navigator.pop(context);
            },
            child: Text(tr('save')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _test, child: Text(tr('testConnection'))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.refresh),
            label: Text(tr('restoreAuto')),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg!)),
        ],
      ),
    );
  }
}
