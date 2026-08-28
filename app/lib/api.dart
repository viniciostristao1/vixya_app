import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'config.dart';

class Api {
  static http.Client? _c;
  static http.Client get _client => _c ??= _makeDohClient();

  static const _hardcodedIp = {
    '2-24-13-102.sslip.io': '2.24.13.102',
  };

  static http.Client _makeDohClient() {
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
        var target = uri.host;
        if (_hardcodedIp.containsKey(uri.host)) {
          target = _hardcodedIp[uri.host]!;
        } else {
          try {
            final ip = await _resolveDoH(uri.host);
            if (ip != null && ip.isNotEmpty) target = ip;
          } catch (_) {}
        }
        return Socket.startConnect(target, uri.port);
      };
    return IOClient(io);
  }

  static Future<String?> _resolveDoH(String host) async {
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) return host;
    final endpoints = [
      'https://1.1.1.1/dns-query?name=$host&type=A',
      'https://8.8.8.8/resolve?name=$host&type=A',
      'https://104.16.248.249/dns-query?name=$host&type=A',
    ];
    for (final url in endpoints) {
      try {
        final r = await http
            .get(Uri.parse(url), headers: {'accept': 'application/dns-json'})
            .timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) continue;
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final answers = data['Answer'] as List?;
        if (answers == null) continue;
        for (final a in answers) {
          if (a['type'] == 1) return (a['data'] as String).trim();
        }
      } catch (_) {}
    }
    try {
      final r = await http
          .get(Uri.parse('https://cloudflare-dns.com/dns-query?name=$host&type=A'),
              headers: {'accept': 'application/dns-json'})
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final answers = data['Answer'] as List?;
        if (answers != null) {
          for (final a in answers) {
            if (a['type'] == 1) return (a['data'] as String).trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Map<String, String> get _headers =>
      Config.token.isEmpty ? {} : {'X-Vixya-Token': Config.token};

  static Uri _u(String path) => Uri.parse('${Config.backendUrl}$path');

  static String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup') || s.contains('errno = 7')) {
      return 'Sem conexão com o servidor (DNS bloqueado pela rede). Tente outra rede (WiFi/4G) ou aguarde — o app tenta contornar automaticamente.';
    }
    return s;
  }

  static Future<Map<String, dynamic>> health() async {
    try {
      final r = await _client.get(_u('/health'), headers: _headers).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}: ${r.body}');
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<List<String>> models() async {
    for (var i = 0; i < 2; i++) {
      try {
        final r = await _client.get(_u('/models'), headers: _headers).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          final d = jsonDecode(r.body) as Map<String, dynamic>;
          return (d['models'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {}
      await Config.refreshFromRemote(force: true);
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
    } catch (e) {
      final msg = _friendlyError(e);
      try {
        await Config.refreshFromRemote(force: true);
        resp = await attempt();
      } catch (e2) {
        throw Exception(msg.contains('DNS bloqueado') ? msg : _friendlyError(e2));
      }
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

  static Future<File> download(String path, File dest) async {
    final r = await _client.get(_u(path), headers: _headers).timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw Exception('Download falhou (${r.statusCode})');
    await dest.writeAsBytes(r.bodyBytes);
    return dest;
  }
}
