import 'package:flutter/material.dart';
import 'package:free_music_player/themes/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The appearance choices: light or dark (following the device by default),
/// and the theme color.
class ThemeService extends ChangeNotifier {
  static const String _modeKey = 'theme_mode';
  static const String _accentKey = 'theme_accent';

  final SharedPreferences _prefs;
  ThemeMode _mode;
  AppAccent _accent;

  ThemeService(this._prefs)
      : _mode = ThemeMode.values.asNameMap()[_prefs.getString(_modeKey)] ??
            ThemeMode.system,
        _accent = AppAccent.values.asNameMap()[_prefs.getString(_accentKey)] ??
            AppAccent.pink;

  ThemeMode get mode => _mode;
  AppAccent get accent => _accent;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    if (accent == _accent) return;
    _accent = accent;
    notifyListeners();
    await _prefs.setString(_accentKey, accent.name);
  }
}
