import 'package:shared_preferences/shared_preferences.dart';

/// Persiste le choix de l'utilisateur : suivre le theme du telephone ou non.
class ThemePreferenceRepository {
  static const _autoThemeKey = 'auto_theme_enabled';

  Future<bool> isAutoThemeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Desactive par defaut : le mode sombre force s'applique tant que
    // l'utilisateur n'a pas explicitement active le suivi automatique.
    return prefs.getBool(_autoThemeKey) ?? false;
  }

  Future<void> setAutoThemeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoThemeKey, enabled);
  }
}
