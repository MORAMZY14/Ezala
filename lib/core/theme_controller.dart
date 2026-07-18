import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _preferenceKey = 'ezla_theme_mode';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final savedMode = await _preferences.getString(_preferenceKey);
    _mode = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle() {
    return setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setString(
      _preferenceKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
