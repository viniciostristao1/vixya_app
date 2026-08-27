import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';

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

  Future<void> _test() async {
    setState(() { _busy = true; _msg = null; });
    await Config.save(_url.text, _token.text);
    try {
      final h = await Api.health();
      setState(() => _msg = 'Conectado ✓  (disco livre ${h['disk_free_gb']} GB)');
    } catch (e) {
      setState(() => _msg = 'Não conectou: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Endereço do backend (VPS)'),
          const SizedBox(height: 6),
          TextField(controller: _url, keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://seu-servidor:8090', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('Token (se o backend exigir)'),
          const SizedBox(height: 6),
          TextField(controller: _token, obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () async {
              await Config.save(_url.text, _token.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _test, child: const Text('Testar conexão')),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg!)),
        ],
      ),
    );
  }
}
