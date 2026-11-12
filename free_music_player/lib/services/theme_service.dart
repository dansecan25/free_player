import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The appearance choice: follow the device (default), or always light or dark.
class ThemeService extends ChangeNotifier {
  static const String _modeKey = 'theme_mode';

  final SharedPreferences _prefs;
  ThemeMode _mode;

  ThemeService(this._prefs)
      : _mode = ThemeMode.values.asNameMap()[_prefs.getString(_modeKey)] ??
            ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(_modeKey, mode.name);
  }
}
