import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Cliente HTTP do backend Vixya (na VPS).
class Api {
  static Map<String, String> get _headers =>
      Config.token.isEmpty ? {} : {'X-Vixya-Token': Config.token};

  static Uri _u(String path) => Uri.parse('${Config.backendUrl}$path');

  static Future<Map<String, dynamic>> health() async {
    final r = await http
        .get(_u('/health'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Lista de modelos de IA (para o usuário escolher). Vazia se indisponível.
  static Future<List<String>> models() async {
    try {
      final r = await http
          .get(_u('/models'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return [];
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return (d['models'] as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Cria o job (upload de vídeo + prints). Retorna o id do job.
  static Future<String> createJob({
    required List<File> files,
    required String objective,
    String style = 'dinamico',
    String? model,
  }) async {
    final req = http.MultipartRequest('POST', _u('/jobs'))
      ..headers.addAll(_headers)
      ..fields['objective'] = objective
      ..fields['style'] = style;
    if (model != null && model.isNotEmpty) req.fields['model'] = model;
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath('files', f.path));
    }
    final resp = await http.Response.fromStream(
        await req.send().timeout(const Duration(minutes: 5)));
    if (resp.statusCode >= 300) {
      throw Exception('Falha ao enviar (${resp.statusCode}): ${resp.body}');
    }
    return (jsonDecode(resp.body) as Map<String, dynamic>)['job'] as String;
  }

  static Future<Map<String, dynamic>> status(String id) async {
    final r = await http
        .get(_u('/jobs/$id'), headers: _headers)
        .timeout(const Duration(seconds: 15));
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

  /// Baixa o preview (`/jobs/{id}/preview`) ou o vídeo final (`/jobs/{id}/video`) para `dest`.
  static Future<File> download(String path, File dest) async {
    final r = await http
        .get(_u(path), headers: _headers)
        .timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw Exception('Download falhou (${r.statusCode})');
    await dest.writeAsBytes(r.bodyBytes);
    return dest;
  }
}
