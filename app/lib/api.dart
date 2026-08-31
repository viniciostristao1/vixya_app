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
    String language = 'pt',
    String aspect = '9:16',
    double speed = 1.0,
    String voice = 'none',
    String? projectId,
  }) async {
    Future<http.Response> attempt() async {
      final req = http.MultipartRequest('POST', _u('/jobs'))
        ..headers.addAll(_headers)
        ..fields['objective'] = objective
        ..fields['style'] = style
        ..fields['language'] = language
        ..fields['aspect'] = aspect
        ..fields['speed'] = speed.toString()
        ..fields['voice'] = voice;
      if (model != null && model.isNotEmpty) req.fields['model'] = model;
      if (projectId != null && projectId.isNotEmpty) req.fields['project_id'] = projectId;
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

  /// Nova versão do preview. Se `planJson` vier, troca o VideoPlan (ajuste manual de textos).
  static Future<void> requestVersion(String id, {String? planJson}) async {
    http.Response r;
    if (planJson != null && planJson.isNotEmpty) {
      final req = http.MultipartRequest('POST', _u('/jobs/$id/version'))
        ..headers.addAll(_headers)
        ..fields['plan'] = planJson;
      r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
    } else {
      r = await http.post(_u('/jobs/$id/version'), headers: _headers);
    }
    if (r.statusCode >= 300) throw Exception('Falha (${r.statusCode})');
  }

  /// VideoPlan atual do job (Map) para o usuário ajustar. Null se ainda não houver plano.
  static Future<Map<String, dynamic>?> getPlan(String id) async {
    final r = await http.get(_u('/jobs/$id/plan'), headers: _headers).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('Falha (${r.statusCode})');
    return (jsonDecode(r.body) as Map<String, dynamic>)['plan'] as Map<String, dynamic>?;
  }

  static Future<void> approve(String id) async {
    final r = await http.post(_u('/jobs/$id/approve'), headers: _headers);
    if (r.statusCode >= 300) throw Exception('Falha (${r.statusCode})');
  }

  /// Cadastra/atualiza o perfil de um app no backend. Retorna o project_id.
  static Future<String> upsertProject({
    required String name,
    String projectId = '',
    String descricao = '',
    String funcionalidades = '',
    String publico = '',
    String cta = '',
    String cores = '',
  }) async {
    final req = http.MultipartRequest('POST', _u('/projects'))
      ..headers.addAll(_headers)
      ..fields['name'] = name;
    if (projectId.isNotEmpty) req.fields['project_id'] = projectId;
    void put(String k, String v) {
      if (v.trim().isNotEmpty) req.fields[k] = v.trim();
    }
    put('descricao', descricao);
    put('funcionalidades', funcionalidades);
    put('publico', publico);
    put('cta', cta);
    put('cores', cores);
    final resp = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
    if (resp.statusCode >= 300) throw Exception('Falha ao salvar perfil (${resp.statusCode})');
    return (jsonDecode(resp.body) as Map<String, dynamic>)['project_id'] as String;
  }

  /// Pede à IA sugestões de prompts a partir do perfil (por project_id OU campos avulsos).
  static Future<List<String>> suggestPrompts({
    String projectId = '',
    String name = '',
    String descricao = '',
    String funcionalidades = '',
    String publico = '',
    String cta = '',
    String language = 'pt',
  }) async {
    final req = http.MultipartRequest('POST', _u('/suggest_prompts'))
      ..headers.addAll(_headers)
      ..fields['language'] = language;
    if (projectId.isNotEmpty) req.fields['project_id'] = projectId;
    void put(String k, String v) {
      if (v.trim().isNotEmpty) req.fields[k] = v.trim();
    }
    put('name', name);
    put('descricao', descricao);
    put('funcionalidades', funcionalidades);
    put('publico', publico);
    put('cta', cta);
    final resp = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    if (resp.statusCode >= 300) throw Exception('Falha (${resp.statusCode})');
    final d = jsonDecode(resp.body) as Map<String, dynamic>;
    return ((d['prompts'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  /// Baixa o preview ou o vídeo final para `dest`.
  static Future<File> download(String path, File dest) async {
    final r = await http.get(_u(path), headers: _headers).timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw Exception('Download falhou (${r.statusCode})');
    await dest.writeAsBytes(r.bodyBytes);
    return dest;
  }
}
