import 'package:flutter/material.dart';

class ThemeColorOption {
  final String id;
  final String label;
  final Color color;
  const ThemeColorOption(this.id, this.label, this.color);
}

/// 화면 테마에서 고를 수 있는 강조 색상 목록.
const kThemeColors = [
  ThemeColorOption('blue', '블루', Color(0xFF3D6BFF)),
  ThemeColorOption('green', '그린', Color(0xFF2E7D32)),
  ThemeColorOption('purple', '퍼플', Color(0xFF7B3FE4)),
  ThemeColorOption('orange', '오렌지', Color(0xFFE65100)),
  ThemeColorOption('pink', '핑크', Color(0xFFD81B60)),
  ThemeColorOption('teal', '틸', Color(0xFF00796B)),
  ThemeColorOption('red', '레드', Color(0xFFC62828)),
  ThemeColorOption('indigo', '인디고', Color(0xFF3949AB)),
  ThemeColorOption('brown', '브라운', Color(0xFF6D4C41)),
];

Color themeColorFor(String id) {
  final match = kThemeColors.where((c) => c.id == id);
  return match.isNotEmpty ? match.first.color : kThemeColors.first.color;
}
