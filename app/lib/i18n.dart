import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  pt('pt', 'Português', 'PT'),
  es('es', 'Espanhol', 'ES'),
  en('en', 'Inglês', 'EN');

  final String code;
  final String label;
  final String flag;
  const AppLanguage(this.code, this.label, this.flag);

  static AppLanguage fromCode(String c) =>
      values.firstWhere((l) => l.code == c, orElse: () => pt);
}

class LangController {
  static const _k = 'vixya_lang';
  final ValueNotifier<AppLanguage> current = ValueNotifier(AppLanguage.pt);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    current.value = AppLanguage.fromCode(p.getString(_k) ?? 'pt');
  }

  Future<void> set(AppLanguage l) async {
    current.value = l;
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, l.code);
  }
}

final langCtrl = LangController();
