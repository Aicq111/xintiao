// ============================================================
// 薪跳 · 主题系统（4 主题色 × 深浅外观，小组件共享同一套 Token）
// ============================================================
import 'package:flutter/material.dart';

class AppTheme {
  static const accentNames = ['翡翠绿', '财富金', '天空蓝', '中国红'];

  static const accents = [
    Color(0xFF34D399),
    Color(0xFFF0C24B),
    Color(0xFF60A5FA),
    Color(0xFFF87171),
  ];

  static const darkBgs = [
    Color(0xFF0B1220),
    Color(0xFF131009),
    Color(0xFF0A1424),
    Color(0xFF170B0E),
  ];

  static const lightBgs = [
    Color(0xFFF5F7FB),
    Color(0xFFFBF8F0),
    Color(0xFFF4F7FC),
    Color(0xFFFBF5F5),
  ];

  static ThemeData build(int accentIdx, Brightness brightness) {
    final accent = accents[accentIdx];
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? darkBgs[accentIdx] : lightBgs[accentIdx],
    );
  }
}

/// 通用配色助手（页面里用，避免依赖 ThemeData 内部卡片色版本差异）
class C {
  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  static Color card(BuildContext c) =>
      isDark(c) ? const Color(0xFF111A2C) : Colors.white;

  static Color line(BuildContext c) =>
      isDark(c) ? const Color(0xFF1E2A40) : const Color(0xFFE3E9F2);

  static Color dim(BuildContext c) =>
      isDark(c) ? const Color(0xFF8FA3BF) : const Color(0xFF64748B);

  static Color gold(BuildContext c) =>
      isDark(c) ? const Color(0xFFF5C451) : const Color(0xFFA67C00);

  static Color blue(BuildContext c) =>
      isDark(c) ? const Color(0xFF60A5FA) : const Color(0xFF2F6FDE);

  static Color red(BuildContext c) =>
      isDark(c) ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  static Color goldDim(BuildContext c) =>
      isDark(c) ? const Color(0x24F5C451) : const Color(0xFFF7EFD8);

  static Color blueDim(BuildContext c) =>
      isDark(c) ? const Color(0x2660A5FA) : const Color(0xFFE3EDFB);

  static Color redDim(BuildContext c) =>
      isDark(c) ? const Color(0x24F87171) : const Color(0xFFFBE2E2);

  static Color accentDim(BuildContext c) =>
      Theme.of(c).colorScheme.primary.withAlpha(isDark(c) ? 34 : 36);
}
