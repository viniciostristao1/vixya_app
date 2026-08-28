import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static const _kUrl = 'backend_url';
  static const _kToken = 'api_token';
  static const _kResolvedUrl = 'resolved_url';

  static const _gistRawUrl =
      'https://gist.githubusercontent.com/viniciostristao1/6795f2486e00131239017af51e5db38c/raw/vixya_backend.txt';

  static const _defaultUrl = 'http://2-24-13-102.sslip.io';
  static const _defaultToken = 'Xl3nDJw0a5HBq_D3aBgB18Tn00RsGPfD';

  static String backendUrl = _defaultUrl;
  static String token = _defaultToken;
  static bool _userSetUrl = false;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kUrl);
    _userSetUrl = saved != null && saved.isNotEmpty;
    backendUrl = _userSetUrl ? saved! : (p.getString(_kResolvedUrl) ?? _defaultUrl);
    final savedTok = p.getString(_kToken);
    token = (savedTok != null && savedTok.isNotEmpty) ? savedTok : _defaultToken;
  }

  static Future<void> refreshFromRemote({bool force = false}) async {
    if (_userSetUrl && !force) return;
    final endpoints = [
      _gistRawUrl,
      'https://1.1.1.1/dns-query'.isEmpty ? '' : _gistRawUrl,
    ];
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
      } catch (_) {}
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

  static Future<void> clearSaved() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUrl);
    await p.remove(_kToken);
    await p.remove(_kResolvedUrl);
    _userSetUrl = false;
    backendUrl = _defaultUrl;
    token = _defaultToken;
  }

  static bool get isSet => backendUrl.isNotEmpty;
}
