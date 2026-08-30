import 'package:flutter/material.dart';

import 'config.dart';
import 'i18n.dart';
import 'store.dart';
import 'theme.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  await themeCtrl.load();
  await langCtrl.load();
  await Store.load();
  runApp(const VixyaApp());
  Config.refreshFromRemote(); // em background: não trava a abertura do app
}

class VixyaApp extends StatelessWidget {
  const VixyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VixyaTheme>(
      valueListenable: themeCtrl.current,
      builder: (context, t, _) => ValueListenableBuilder<AppLanguage>(
        valueListenable: langCtrl.current,
        builder: (context, l, _) => MaterialApp(
          title: 'Vixya',
          debugShowCheckedModeBanner: false,
          theme: t.toThemeData(),
          builder: (context, child) => DecoratedBox(
            decoration: t.backgroundDecoration,
            child: child,
          ),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
