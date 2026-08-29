import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Cliente HTTP do backend Vixya.
///
/// Conexão PADRÃO (igual à do navegador) — o Chrome do celular prova que a rede resolve
/// `2-24-13-102.sslip.io` e faz TLS normalmente. Removido o connectionFactory/DoH/IP-na-mão
/// que a versão anterior usava (causava reset de conexão — errno 104/32).
class Api {
  static Map<String, String> get _headers =>
      Config.token.isEmpty ? {} : {'X-Vixya-Token': Config.token};

  static Uri _u(String path) => Uri.parse('${Config.backendUrl}$path');

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup')) {
      return 'Não consegui resolver o endereço do servidor. Tente outra rede (Wi-Fi/4G).';
    }
    if (s.contains('errno = 1')) {
      return 'O Android bloqueou a rede deste app. Verifique VPN, economia de dados, ou libere o acesso a dados do app.';
    }
    return s;
  }

  static Future<Map<String, dynamic>> health() async {
    try {
      final r = await http.get(_u('/health'), headers: _headers).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}: ${r.body}');
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  /// Lista de modelos de IA. Tenta 2x (re-descobre o endereço entre as tentativas).
  static Future<List<String>> models() async {
    for (var i = 0; i < 2; i++) {
      try {
        final r = await http.get(_u('/models'), headers: _headers).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          final d = jsonDecode(r.body) as Map<String, dynamic>;
          return (d['models'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {/* re-descobre e tenta de novo */}
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
      return http.Response.fromStream(await req.send().timeout(const Duration(minutes: 5)));
    }

    http.Response resp;
    try {
      resp = await attempt();
    } catch (e) {
      try {
        await Config.refreshFromRemote(force: true);
        resp = await attempt(); // 1 retry
      } catch (_) {
        throw Exception(_friendly(e));
      }
    }
    if (resp.statusCode >= 300) {
      throw Exception('Falha ao enviar (${resp.statusCode}): ${resp.body}');
    }
    return (jsonDecode(resp.body) as Map<String, dynamic>)['job'] as String;
  }

  static Future<Map<String, dynamic>> status(String id) async {
    final r = await http.get(_u('/jobs/$id'), headers: _headers).timeout(const Duration(seconds: 20));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<void> requestVersion(String id) async {
    final r = await http.post(_u('/jobs/$id/version'), headers: _headers);
    if (r.statusCode >= 300) throw Exception('Falha (${r.statusCode})');
  }

  static Future<void> approve(String id) async {
    final r = await http.post(_u('/jobs/$id/approve'), headers: _headers);
    if (r.statusCode >= 300) throw Exception('Falha (${r.statusCode})');
  }

  /// Baixa o preview ou o vídeo final para `dest`.
  static Future<File> download(String path, File dest) async {
    final r = await http.get(_u(path), headers: _headers).timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw Exception('Download falhou (${r.statusCode})');
    await dest.writeAsBytes(r.bodyBytes);
    return dest;
  }
}
