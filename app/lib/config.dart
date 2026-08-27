import 'package:shared_preferences/shared_preferences.dart';

/// URL do backend (VPS) + token, guardados no aparelho.
/// Enquanto o backend não está exposto com HTTPS/token, o usuário preenche em Configurações.
class Config {
  static const _kUrl = 'backend_url';
  static const _kToken = 'api_token';

  static String backendUrl = '';
  static String token = '';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    backendUrl = p.getString(_kUrl) ?? '';
    token = p.getString(_kToken) ?? '';
  }

  static Future<void> save(String url, String tok) async {
    final p = await SharedPreferences.getInstance();
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), ''); // sem barra final
    token = tok.trim();
    await p.setString(_kUrl, backendUrl);
    await p.setString(_kToken, token);
  }

  static bool get isSet => backendUrl.isNotEmpty;
}
