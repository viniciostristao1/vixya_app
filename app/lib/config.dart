import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Config do backend. O app já vem pré-configurado e, ao abrir, busca o endereço ATUAL do
/// backend de um ponteiro fixo (gist) que a VPS mantém — assim funciona mesmo se o túnel mudar.
class Config {
  static const _kUrl = 'backend_url';
  static const _kToken = 'api_token';

  // ponteiro fixo: a VPS atualiza a URL atual do backend aqui
  static const _gistRawUrl =
      'https://gist.githubusercontent.com/viniciostristao1/6795f2486e00131239017af51e5db38c/raw/vixya_backend.txt';

  static const _defaultUrl = 'https://economics-expenditures-hair-creature.trycloudflare.com';
  static const _defaultToken = 'Xl3nDJw0a5HBq_D3aBgB18Tn00RsGPfD';

  static String backendUrl = _defaultUrl;
  static String token = _defaultToken;
  static bool _userSetUrl = false;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kUrl);
    _userSetUrl = saved != null && saved.isNotEmpty;
    backendUrl = _userSetUrl ? saved! : _defaultUrl;
    token = p.getString(_kToken) ?? _defaultToken;
  }

  /// Busca a URL atual do backend no ponteiro fixo (best-effort).
  /// Não sobrescreve se o usuário tiver definido uma URL manual em Configurações.
  static Future<void> refreshFromRemote() async {
    if (_userSetUrl) return;
    try {
      final r = await http.get(Uri.parse(_gistRawUrl)).timeout(const Duration(seconds: 6));
      final u = r.body.trim();
      if (r.statusCode == 200 && u.startsWith('http')) {
        backendUrl = u.replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {/* mantém o padrão embutido */}
  }

  static Future<void> save(String url, String tok) async {
    final p = await SharedPreferences.getInstance();
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    token = tok.trim();
    _userSetUrl = backendUrl.isNotEmpty;
    await p.setString(_kUrl, backendUrl);
    await p.setString(_kToken, token);
  }

  static bool get isSet => backendUrl.isNotEmpty;
}
