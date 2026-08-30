import 'package:flutter/material.dart';

import '../config.dart';
import '../i18n.dart';
import '../store.dart';
import 'execution_screen.dart';
import 'prompts_screen.dart';
import 'settings_screen.dart';

/// Casca do app: AppBar (logo + recarregar IAs + configurações) e duas abas na base:
/// **Execução** (gerar o vídeo) e **Prompts** (perfil do app + sugestões da IA + salvos).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Store.reloadModels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Config.isSet) _openSettings();
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await Store.reloadModels();
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    await Store.reloadModels();
    if (!mounted) return;
    final n = Store.models.value.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0 ? tr('noConnection') : tr('iasAvailable', {'n': '$n'}))));
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(tooltip: tr('reloadIA'), icon: const Icon(Icons.refresh), onPressed: _reload),
          IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [ExecutionScreen(), PromptsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.movie_creation_outlined), selectedIcon: const Icon(Icons.movie_creation), label: tr('tabExec')),
          NavigationDestination(icon: const Icon(Icons.lightbulb_outline), selectedIcon: const Icon(Icons.lightbulb), label: tr('tabPrompts')),
        ],
      ),
    );
  }
}
