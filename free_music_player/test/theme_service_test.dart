import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('follows the device theme by default', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService(await SharedPreferences.getInstance());
    expect(service.mode, ThemeMode.system);
  });

  test('remembers the chosen mode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ThemeService(prefs).setMode(ThemeMode.dark);
    expect(ThemeService(prefs).mode, ThemeMode.dark);
  });

  test('an unknown stored value falls back to the device theme', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final service = ThemeService(await SharedPreferences.getInstance());
    expect(service.mode, ThemeMode.system);
  });
}
