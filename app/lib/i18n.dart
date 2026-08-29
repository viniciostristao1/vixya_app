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

const _strings = {
  'pt': {
    'settings': 'Configurações',
    'themes': 'Temas',
    'languages': 'Idiomas',
    'backendUrl': 'Endereço do backend (VPS)',
    'token': 'Token (se o backend exigir)',
    'save': 'Salvar',
    'testConnection': 'Testar conexão',
    'restoreAuto': 'Restaurar endereço automático',
    'addVideo': 'Adicionar vídeo (gravação de tela)',
    'addPrints': 'Adicionar prints (opcional)',
    'printsCount': '{n} print(s)',
    'objective': 'O que você quer divulgar?',
    'style': 'Estilo',
    'langLabel': 'Idioma da legenda',
    'ia': 'IA',
    'iaDefault': 'padrão',
    'generate': 'GERAR VÍDEO',
    'sending': 'Enviando...',
    'reloadIA': 'Recarregar IAs',
    'backendNeeded': 'Toque em ⚙️ e informe o endereço do backend para começar.',
    'noConnection': 'Ainda sem conexão',
    'iasAvailable': '{n} IAs disponíveis',
    'yourVideo': 'Seu vídeo',
    'queued': 'Na fila...',
    'analyzing': 'Analisando o material...',
    'planning': 'A IA está criando o roteiro...',
    'rendering': 'Montando o vídeo...',
    'preparingPreview': 'Preparando o preview...',
    'otherVersion': 'Outra versão',
    'approve': 'Aprovar',
    'saveShare': 'Salvar / Compartilhar',
    'failed': 'Não deu certo.',
    'connected': 'Conectado ✓  (disco livre {n} GB)',
    'notConnected': 'Não conectou: {e}',
    'restored': 'Restaurado ✓  (disco livre {n} GB)',
    'restoredFail': 'Restaurado, mas não conectou: {e}',
  },
  'es': {
    'settings': 'Configuración',
    'themes': 'Temas',
    'languages': 'Idiomas',
    'backendUrl': 'Dirección del backend (VPS)',
    'token': 'Token (si el backend lo exige)',
    'save': 'Guardar',
    'testConnection': 'Probar conexión',
    'restoreAuto': 'Restaurar dirección automática',
    'addVideo': 'Añadir video (grabación de pantalla)',
    'addPrints': 'Añadir capturas (opcional)',
    'printsCount': '{n} captura(s)',
    'objective': '¿Qué quieres promocionar?',
    'style': 'Estilo',
    'langLabel': 'Idioma de subtítulos',
    'ia': 'IA',
    'iaDefault': 'predeterminado',
    'generate': 'GENERAR VIDEO',
    'sending': 'Enviando...',
    'reloadIA': 'Recargar IAs',
    'backendNeeded': 'Toca ⚙️ e informa la dirección del backend para comenzar.',
    'noConnection': 'Aún sin conexión',
    'iasAvailable': '{n} IAs disponibles',
    'yourVideo': 'Tu video',
    'queued': 'En cola...',
    'analyzing': 'Analizando el material...',
    'planning': 'La IA está creando el guion...',
    'rendering': 'Montando el video...',
    'preparingPreview': 'Preparando la vista previa...',
    'otherVersion': 'Otra versión',
    'approve': 'Aprobar',
    'saveShare': 'Guardar / Compartir',
    'failed': 'Algo salió mal.',
    'connected': 'Conectado ✓  (disco libre {n} GB)',
    'notConnected': 'No se pudo conectar: {e}',
    'restored': 'Restaurado ✓  (disco libre {n} GB)',
    'restoredFail': 'Restaurado, pero no se pudo conectar: {e}',
  },
  'en': {
    'settings': 'Settings',
    'themes': 'Themes',
    'languages': 'Languages',
    'backendUrl': 'Backend address (VPS)',
    'token': 'Token (if backend requires)',
    'save': 'Save',
    'testConnection': 'Test connection',
    'restoreAuto': 'Restore automatic address',
    'addVideo': 'Add video (screen recording)',
    'addPrints': 'Add screenshots (optional)',
    'printsCount': '{n} screenshot(s)',
    'objective': 'What do you want to promote?',
    'style': 'Style',
    'langLabel': 'Subtitle language',
    'ia': 'AI',
    'iaDefault': 'default',
    'generate': 'GENERATE VIDEO',
    'sending': 'Sending...',
    'reloadIA': 'Reload AIs',
    'backendNeeded': 'Tap ⚙️ and enter the backend address to start.',
    'noConnection': 'Still offline',
    'iasAvailable': '{n} AIs available',
    'yourVideo': 'Your video',
    'queued': 'Queued...',
    'analyzing': 'Analyzing material...',
    'planning': 'AI is creating the script...',
    'rendering': 'Building video...',
    'preparingPreview': 'Preparing preview...',
    'otherVersion': 'Other version',
    'approve': 'Approve',
    'saveShare': 'Save / Share',
    'failed': 'Something went wrong.',
    'connected': 'Connected ✓  (free disk {n} GB)',
    'notConnected': 'Could not connect: {e}',
    'restored': 'Restored ✓  (free disk {n} GB)',
    'restoredFail': 'Restored, but could not connect: {e}',
  },
};

String tr(String key, [Map<String, String> params = const {}]) {
  final code = langCtrl.current.value.code;
  var s = _strings[code]?[key] ?? _strings['pt']![key] ?? key;
  params.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}
