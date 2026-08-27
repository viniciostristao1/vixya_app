import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/new_video_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  runApp(const VixyaApp());
}

class VixyaApp extends StatelessWidget {
  const VixyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6C3CE0);
    return MaterialApp(
      title: 'Vixya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.dark),
      home: const NewVideoScreen(),
    );
  }
}
