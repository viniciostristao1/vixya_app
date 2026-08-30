import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Perfil de um app do usuário. Cadastrado 1x -> todo vídeo daquele app já sai bom SEM prompt.
/// `projectId` é o id no backend (vazio até salvar/sincronizar).
class AppProfile {
  String projectId;
  String name;
  String descricao;
  String funcionalidades;
  String publico;
  String cta;
  String cores;

  AppProfile({
    this.projectId = '',
    this.name = '',
    this.descricao = '',
    this.funcionalidades = '',
    this.publico = '',
    this.cta = '',
    this.cores = '',
  });

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'name': name,
        'descricao': descricao,
        'funcionalidades': funcionalidades,
        'publico': publico,
        'cta': cta,
        'cores': cores,
      };

  factory AppProfile.fromJson(Map<String, dynamic> j) => AppProfile(
        projectId: (j['projectId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        descricao: (j['descricao'] ?? '').toString(),
        funcionalidades: (j['funcionalidades'] ?? '').toString(),
        publico: (j['publico'] ?? '').toString(),
        cta: (j['cta'] ?? '').toString(),
        cores: (j['cores'] ?? '').toString(),
      );

  AppProfile copy() => AppProfile.fromJson(toJson());
}

/// Estado local persistente: perfis de app, prompts salvos, app selecionado e a lista de IAs.
/// Tudo em SharedPreferences (nada sensível). A UI observa os ValueNotifier.
class Store {
  static const _kProfiles = 'vixya_profiles';
  static const _kPrompts = 'vixya_prompts';
  static const _kSelected = 'vixya_selected_project';

  static final ValueNotifier<List<AppProfile>> profiles = ValueNotifier([]);
  // prompts salvos POR APP (chave = projectId; '' = geral/sem app). Cada app tem os seus.
  static final ValueNotifier<Map<String, List<String>>> promptsByApp = ValueNotifier({});
  static final ValueNotifier<String> selectedProjectId = ValueNotifier(''); // '' = nenhum
  static final ValueNotifier<List<String>> models = ValueNotifier([]);
  // "usar" um prompt na aba Prompts joga o texto aqui; a aba Execução lê e preenche o campo.
  static final ValueNotifier<String?> pendingObjective = ValueNotifier(null);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      profiles.value = (jsonDecode(p.getString(_kProfiles) ?? '[]') as List)
          .map((e) => AppProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      profiles.value = [];
    }
    try {
      final raw = jsonDecode(p.getString(_kPrompts) ?? '{}');
      if (raw is Map) {
        promptsByApp.value = raw.map((k, v) =>
            MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()));
      } else if (raw is List) {
        // migração do formato antigo (lista única) -> tudo no balde "geral" ('')
        promptsByApp.value = {'': raw.map((e) => e.toString()).toList()};
      }
    } catch (_) {
      promptsByApp.value = {};
    }
    selectedProjectId.value = p.getString(_kSelected) ?? '';
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProfiles, jsonEncode(profiles.value.map((e) => e.toJson()).toList()));
    await p.setString(_kPrompts, jsonEncode(promptsByApp.value));
    await p.setString(_kSelected, selectedProjectId.value);
  }

  static List<String> promptsFor(String projectId) =>
      List<String>.from(promptsByApp.value[projectId] ?? const []);

  static AppProfile? get selected {
    final id = selectedProjectId.value;
    for (final pr in profiles.value) {
      if (pr.projectId == id && id.isNotEmpty) return pr;
    }
    return null;
  }

  /// Salva o perfil no backend (pega/gera o projectId) e persiste localmente. Seleciona-o.
  static Future<void> saveProfile(AppProfile pr) async {
    final id = await Api.upsertProject(   // pode lançar (rede) — quem chama trata
      name: pr.name,
      projectId: pr.projectId,
      descricao: pr.descricao,
      funcionalidades: pr.funcionalidades,
      publico: pr.publico,
      cta: pr.cta,
      cores: pr.cores,
    );
    pr.projectId = id;
    final list = [...profiles.value];
    final i = list.indexWhere((e) => e.projectId == id);
    if (i >= 0) {
      list[i] = pr;
    } else {
      list.add(pr);
    }
    profiles.value = list;
    selectedProjectId.value = id;
    await _persist();
  }

  static Future<void> removeProfile(String projectId) async {
    profiles.value = profiles.value.where((e) => e.projectId != projectId).toList();
    final map = {...promptsByApp.value}..remove(projectId); // apaga os prompts do app junto
    promptsByApp.value = map;
    if (selectedProjectId.value == projectId) selectedProjectId.value = '';
    await _persist();
  }

  static Future<void> setSelected(String projectId) async {
    selectedProjectId.value = projectId;
    await _persist();
  }

  static Future<void> addPrompt(String projectId, String s) async {
    s = s.trim();
    if (s.isEmpty) return;
    final map = {...promptsByApp.value};
    final list = [...(map[projectId] ?? const <String>[])];
    if (list.contains(s)) return;
    map[projectId] = [s, ...list];
    promptsByApp.value = map;
    await _persist();
  }

  static Future<void> removePrompt(String projectId, String s) async {
    final map = {...promptsByApp.value};
    map[projectId] = [...(map[projectId] ?? const <String>[])].where((e) => e != s).toList();
    promptsByApp.value = map;
    await _persist();
  }

  static Future<void> reloadModels() async {
    models.value = await Api.models();
  }
}
