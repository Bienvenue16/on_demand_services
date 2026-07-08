import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';

import 'theme_preference_repository.dart';

/// Etat du theme de l'app. Par defaut (avant chargement de la preference et
/// quand le suivi automatique est desactive) : mode sombre force.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._repository) : super(ThemeMode.dark) {
    _load();
  }

  final ThemePreferenceRepository _repository;

  bool get isAutoThemeEnabled => state == ThemeMode.system;

  Future<void> _load() async {
    final enabled = await _repository.isAutoThemeEnabled();
    emit(enabled ? ThemeMode.system : ThemeMode.dark);
  }

  Future<void> setAutoThemeEnabled(bool enabled) async {
    await _repository.setAutoThemeEnabled(enabled);
    emit(enabled ? ThemeMode.system : ThemeMode.dark);
  }
}
