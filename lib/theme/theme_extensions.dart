import 'package:flutter/material.dart';

/// Extension giúp mọi widget lấy màu chuẩn từ Theme
/// thay vì phải viết `isDark ? AppConstants.darkX : AppConstants.Y`
extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDark => theme.brightness == Brightness.dark;

  /// Primary brand color (auto light/dark)
  Color get primaryColor => colorScheme.primary;

  /// Background / scaffold
  Color get backgroundColor => theme.scaffoldBackgroundColor;

  /// Surface (card, dialog, bottom sheet)
  Color get surfaceColor => colorScheme.surface;

  /// Text colors
  Color get textPrimary => isDark ? const Color(0xFFFCFCFD) : const Color(0xFF2B2D42);
  Color get textSecondary => isDark ? const Color(0xFF777E90) : const Color(0xFF8D99AE);
  Color get textTertiary => isDark ? const Color(0xFF555A6E) : const Color(0xFFB0B7C3);

  /// Card background
  Color get cardColor => isDark ? const Color(0xFF1F2125) : Colors.white;

  /// Divider / border
  Color get dividerColor => isDark ? const Color(0xFF353945) : const Color(0xFFEAEDF2);

  /// Subtle container background (search bars, chips)
  Color get subtleBackground => isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F1F5);
}
