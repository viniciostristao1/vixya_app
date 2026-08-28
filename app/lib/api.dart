import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'config.dart';

/// Cliente HTTP do backend Vixya (na VPS).
///
/// Resolve o host do backend por DoH (DNS-over-HTTPS da Cloudflare, porta 443) e conecta pelo
/// IP mantendo o SNI = hostname original. Assim funciona mesmo em redes que bloqueiam o DNS
/// comum (UDP 53) — o que estava travando este usuário. Se o DoH falhar, cai no DNS normal.
class Api {
  static http.Client? _c;
  static http.Client get _client => _c ??= _makeDohClient();

  static http.Client _makeDohClient() {
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
        var target = uri.host;
        try {
          final ip = await _resolveDoH(uri.host);
          if (ip != null && ip.isNotEmpty) target = ip; // conecta pelo IP (bypassa DNS do celular)
        } catch (_) {/* cai no host normal */}
        // TLS é feito pelo HttpClient com SNI = uri.host (hostname), roteando certo no Cloudflare
        return Socket.startConnect(target, uri.port);
      };
    return IOClient(io);
  }

  /// Resolve um hostname via DoH (Cloudflare JSON). Retorna o 1º IPv4, ou null.
  static Future<String?> _resolveDoH(String host) async {
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) return host; // já é IP
    final r = await http
        .get(Uri.parse('https://cloudflare-dns.com/dns-query?name=$host&type=A'),
            headers: {'accept': 'application/dns-json'})
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final answers = data['Answer'] as List?;
    if (answers == null) return null;
    for (final a in answers) {
      if (a['type'] == 1) return (a['data'] as String).trim(); // type 1 = registro A
    }
    return null;
  }

  static Map<String, String> get _headers =>
      Config.token.isEmpty ? {} : {'X-Vixya-Token': Config.token};

  static Uri _u(String path) => Uri.parse('${Config.backendUrl}$path');

  static Future<Map<String, dynamic>> health() async {
    final r = await _client.get(_u('/health'), headers: _headers).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Lista de modelos de IA. Tenta 2x (re-descobre o endereço entre as tentativas).
  static Future<List<String>> models() async {
    for (var i = 0; i < 2; i++) {
      try {
        final r = await _client.get(_u('/models'), headers: _headers).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          final d = jsonDecode(r.body) as Map<String, dynamic>;
          return (d['models'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {/* re-descobre e tenta de novo */}
      await Config.refreshFromRemote();
    }
    return [];
  }

  static Future<String> createJob({
    required List<File> files,
    required String objective,
    String style = 'dinamico',
    String? model,
  }) async {
    Future<http.Response> attempt() async {
      final req = http.MultipartRequest('POST', _u('/jobs'))
        ..headers.addAll(_headers)
        ..fields['objective'] = objective
        ..fields['style'] = style;
      if (model != null && model.isNotEmpty) req.fields['model'] = model;
      for (final f in files) {
        req.files.add(await http.MultipartFile.fromPath('files', f.path));
      }
      return http.Response.fromStream(await _client.send(req).timeout(const Duration(minutes: 5)));
    }

    http.Response resp;
    try {
      resp = await attempt();
    } catch (_) {
      await Config.refreshFromRemote(); // re-descobre o endereço e tenta 1x
      resp = await attempt();
    }
    if (resp.statusCode >= 300) {
      throw Exception('Falha ao enviar (${resp.statusCode}): ${resp.body}');
    }
    return (jsonDecode(resp.body) as Map<String, dynamic>)['job'] as String;
  }

  static Future<Map<String, dynamic>> status(String id) async {
    final r = await _client.get(_u('/jobs/$id'), headers: _headers).timeout(const Duration(seconds: 20));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<void> requestVersion(String id) async {
    final r = await _client.post(_u('/jobs/$id/version'), headers: _headers);
    if (r.statusCode >= 300) throw Exception('Falha (${r.statusCode})');
  }

  static Future<void> approve(String id) async {
    final r = await _client.post(_u('/jobs/$id/approve'), headers: _headers);
    if (r.statusCode >= 300) throw Exception('Falha (${r.statusCode})');
  }

  /// Baixa o preview ou o vídeo final para `dest`.
  static Future<File> download(String path, File dest) async {
    final r = await _client.get(_u(path), headers: _headers).timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw Exception('Download falhou (${r.statusCode})');
    await dest.writeAsBytes(r.bodyBytes);
    return dest;
  }
}
