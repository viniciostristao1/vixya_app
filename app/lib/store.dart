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
  static final ValueNotifier<List<String>> savedPrompts = ValueNotifier([]);
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
      savedPrompts.value =
          (jsonDecode(p.getString(_kPrompts) ?? '[]') as List).map((e) => e.toString()).toList();
    } catch (_) {
      savedPrompts.value = [];
    }
    selectedProjectId.value = p.getString(_kSelected) ?? '';
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProfiles, jsonEncode(profiles.value.map((e) => e.toJson()).toList()));
    await p.setString(_kPrompts, jsonEncode(savedPrompts.value));
    await p.setString(_kSelected, selectedProjectId.value);
  }

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
    if (selectedProjectId.value == projectId) selectedProjectId.value = '';
    await _persist();
  }

  static Future<void> setSelected(String projectId) async {
    selectedProjectId.value = projectId;
    await _persist();
  }

  static Future<void> addPrompt(String s) async {
    s = s.trim();
    if (s.isEmpty || savedPrompts.value.contains(s)) return;
    savedPrompts.value = [s, ...savedPrompts.value];
    await _persist();
  }

  static Future<void> removePrompt(String s) async {
    savedPrompts.value = savedPrompts.value.where((e) => e != s).toList();
    await _persist();
  }

  static Future<void> reloadModels() async {
    models.value = await Api.models();
  }
}
