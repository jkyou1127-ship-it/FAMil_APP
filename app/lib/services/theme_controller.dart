import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme_colors.dart';

/// 라이트/다크/시스템 설정 테마 모드와 강조 색상을 관리하고 기기에 저장한다.
class ThemeController extends ChangeNotifier {
  static const _modeKey = 'theme_mode';
  static const _colorKey = 'theme_color_id';

  ThemeMode _mode = ThemeMode.system;
  String _colorId = kThemeColors.first.id;

  ThemeMode get mode => _mode;
  String get colorId => _colorId;
  Color get seedColor => themeColorFor(_colorId);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _parseMode(prefs.getString(_modeKey));
    _colorId = prefs.getString(_colorKey) ?? kThemeColors.first.id;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, _encodeMode(mode));
  }

  Future<void> setColorId(String id) async {
    _colorId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorKey, id);
  }

  ThemeMode _parseMode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  String _encodeMode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
