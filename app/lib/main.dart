import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';
import 'screens/new_video_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  await themeCtrl.load();
  runApp(const VixyaApp());
  Config.refreshFromRemote(); // em background: não trava a abertura do app
}

class VixyaApp extends StatelessWidget {
  const VixyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VixyaTheme>(
      valueListenable: themeCtrl.current,
      builder: (context, t, _) => MaterialApp(
        title: 'Vixya',
        debugShowCheckedModeBanner: false,
        theme: t.toThemeData(),
        // pinta o fundo (sólido ou degradê) atrás de todas as telas
        builder: (context, child) => DecoratedBox(
          decoration: t.backgroundDecoration,
          child: child,
        ),
        home: const NewVideoScreen(),
      ),
    );
  }
}
