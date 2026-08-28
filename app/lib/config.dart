import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Config do backend. O app já vem pré-configurado e, ao abrir, busca o endereço ATUAL do
/// backend de um ponteiro fixo (gist) que a VPS mantém — assim funciona mesmo se o túnel mudar.
class Config {
  static const _kUrl = 'backend_url';        // URL manual definida pelo usuário
  static const _kToken = 'api_token';
  static const _kResolvedUrl = 'resolved_url'; // último endereço que funcionou (cache)

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
    // prioridade: URL manual > último endereço que funcionou > padrão embutido
    backendUrl = _userSetUrl ? saved! : (p.getString(_kResolvedUrl) ?? _defaultUrl);
    // token: se o salvo estiver vazio/ausente, usa o embutido (evita 401 por token vazio)
    final savedTok = p.getString(_kToken);
    token = (savedTok != null && savedTok.isNotEmpty) ? savedTok : _defaultToken;
  }

  /// Busca a URL atual do backend no ponteiro fixo (com 3 tentativas). Best-effort.
  /// Não sobrescreve se o usuário definiu uma URL manual em Configurações.
  static Future<void> refreshFromRemote() async {
    if (_userSetUrl) return;
    for (var i = 0; i < 3; i++) {
      try {
        final r = await http.get(Uri.parse(_gistRawUrl)).timeout(const Duration(seconds: 8));
        final u = r.body.trim();
        if (r.statusCode == 200 && u.startsWith('http')) {
          backendUrl = u.replaceAll(RegExp(r'/+$'), '');
          final p = await SharedPreferences.getInstance();
          await p.setString(_kResolvedUrl, backendUrl);
          return;
        }
      } catch (_) {/* tenta de novo */}
      await Future.delayed(const Duration(seconds: 2));
    }
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
