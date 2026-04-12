import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  Future<void> _updateTheme(String theme) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setThemeMode(theme);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển sang chế độ ${_getThemeName(theme)}'),
          backgroundColor: AppConstants.secondaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getThemeName(String theme) {
    switch (theme) {
      case 'light':
        return 'Sáng';
      case 'dark':
        return 'Tối';
      default:
        return 'Tự động';
    }
  }

  String _getThemeDescription(String theme) {
    switch (theme) {
      case 'light':
        return 'Giao diện sáng, dễ nhìn ban ngày';
      case 'dark':
        return 'Giao diện tối, dễ chịu cho mắt ban đêm';
      default:
        return 'Theo cài đặt hệ thống';
    }
  }

  IconData _getThemeIcon(String theme) {
    switch (theme) {
      case 'light':
        return Icons.wb_sunny;
      case 'dark':
        return Icons.nightlight_round;
      default:
        return Icons.brightness_auto;
    }
  }

  Color _getThemeColor(String theme, bool isDark) {
    switch (theme) {
      case 'light':
        return Colors.amber;
      case 'dark':
        return isDark ? Colors.indigo.shade300 : Colors.indigo;
      default:
        return isDark ? Colors.purple.shade300 : Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selectedTheme = themeProvider.themeModeString;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Giao diện'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // Current theme display
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getThemeColor(selectedTheme, isDark),
                  _getThemeColor(selectedTheme, isDark).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: _getThemeColor(selectedTheme, isDark).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  _getThemeIcon(selectedTheme),
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chế độ ${_getThemeName(selectedTheme)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getThemeDescription(selectedTheme),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
            child: Text(
              'Chọn giao diện',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textSecondary,
              ),
            ),
          ),

          // Theme options
          _buildThemeOption(
            theme: 'system',
            title: 'Tự động',
            description: 'Theo cài đặt hệ thống',
            icon: Icons.brightness_auto,
            color: isDark ? Colors.purple.shade300 : Colors.purple,
            isSelected: selectedTheme == 'system',
            isDark: isDark,
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          _buildThemeOption(
            theme: 'light',
            title: 'Sáng',
            description: 'Giao diện sáng',
            icon: Icons.wb_sunny,
            color: Colors.amber,
            isSelected: selectedTheme == 'light',
            isDark: isDark,
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          _buildThemeOption(
            theme: 'dark',
            title: 'Tối',
            description: 'Giao diện tối',
            icon: Icons.nightlight_round,
            color: isDark ? Colors.indigo.shade300 : Colors.indigo,
            isSelected: selectedTheme == 'dark',
            isDark: isDark,
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Info card
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.blue.shade900.withOpacity(0.3)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: isDark 
                    ? Colors.blue.shade700 
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mẹo sử dụng',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark 
                              ? Colors.blue.shade200 
                              : Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chế độ Tự động sẽ thay đổi giao diện theo cài đặt hệ thống của thiết bị. Chế độ Tối giúp giảm mỏi mắt khi sử dụng ban đêm.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark 
                              ? Colors.blue.shade100 
                              : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String theme,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _updateTheme(theme),
      child: AnimatedContainer(
        duration: AppConstants.mediumAnimation,
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: AppConstants.shortAnimation,
              child: isSelected
                  ? Container(
                      key: const ValueKey('selected'),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.white,
                      ),
                    )
                  : Container(
                      key: const ValueKey('unselected'),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}