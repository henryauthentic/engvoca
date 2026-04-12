import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';
import 'package:intl/intl.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';
import 'notification_settings_screen.dart';
import 'audio_settings_screen.dart';
import 'reminder_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'help_screen.dart';
import '../db/database_helper.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _syncService = SyncService();
  final _settingsService = SettingsService.instance;
  final _dbHelper = DatabaseHelper.instance;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _avatarUrl;
  bool _autoSyncEnabled = false;
  String _autoSyncTime = '23:00';

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
    _loadUserAvatar();
    _loadAutoSyncSettings();
  }

  void _loadAutoSyncSettings() {
    setState(() {
      _autoSyncEnabled = _settingsService.getAutoSyncEnabled();
      _autoSyncTime = _settingsService.getAutoSyncTimeFormatted();
    });
  }

  Future<void> _loadUserAvatar() async {
    final user = _authService.currentUser;
    if (user != null) {
      final localUser = await _dbHelper.getLocalUser(user.uid);
      if (localUser != null && mounted) {
        setState(() {
          _avatarUrl = localUser['avatar_url'] as String?;
        });
      }
    }
  }

  Future<void> _loadLastSyncTime() async {
    final lastSync = await _syncService.getLastSyncTime();
    setState(() => _lastSyncTime = lastSync);
  }

  Future<void> _syncNow() async {
    final user = _authService.currentUser;
    
    // ✅ Kiểm tra user có tồn tại không
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để đồng bộ'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);
    
    try {
      // ✅ Truyền userId vào syncData
      await _syncService.syncData(user.uid);
      await _loadLastSyncTime();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đồng bộ thành công!'),
            backgroundColor: AppConstants.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Lỗi đồng bộ: $e';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Lỗi quyền truy cập Firestore. Vui lòng cập nhật Security Rules trên Firebase Console (xem file firestore.rules trong project).';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppConstants.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _toggleAutoSync(bool enabled) async {
    await _settingsService.setAutoSyncEnabled(enabled);
    setState(() => _autoSyncEnabled = enabled);
    
    final user = _authService.currentUser;
    if (enabled && user != null) {
      _syncService.startAutoSyncTimer(user.uid);
    } else {
      _syncService.stopAutoSyncTimer();
    }
  }

  Future<void> _pickAutoSyncTime() async {
    final currentHour = _settingsService.getAutoSyncHour();
    final currentMinute = _settingsService.getAutoSyncMinute();
    
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      helpText: 'Chọn giờ đồng bộ tự động',
    );
    
    if (picked != null) {
      await _settingsService.setAutoSyncTime(picked.hour, picked.minute);
      setState(() {
        _autoSyncTime = _settingsService.getAutoSyncTimeFormatted();
      });
      
      // Restart timer with new time
      final user = _authService.currentUser;
      if (_autoSyncEnabled && user != null) {
        _syncService.startAutoSyncTimer(user.uid);
      }
    }
  }

  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardColor,
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppConstants.errorColor),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.logout();
    }
  }

  String _formatLastSync(DateTime? dateTime) {
    if (dateTime == null) return 'Chưa đồng bộ';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // User Profile Card
          Container(
            margin: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.primaryColor,
                  context.primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: context.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  
                  if (result == true && mounted) {
                    await _loadUserAvatar();
                    setState(() {});
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLarge),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: _buildAvatarWidget(),
                      ),
                      const SizedBox(width: AppConstants.paddingMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'User',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Dữ liệu
          _buildSection('Dữ liệu', isDark),
          _buildCard(isDark, [
            _buildListTile(
              icon: Icons.sync,
              title: AppStrings.syncData,
              subtitle: 'Lần cuối: ${_formatLastSync(_lastSyncTime)}',
              trailing: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isSyncing ? null : _syncNow,
              isDark: isDark,
            ),
            Divider(height: 1, indent: 72, color: context.dividerColor),
            SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  color: context.primaryColor,
                  size: 24,
                ),
              ),
              title: const Text(
                'Tự động đồng bộ',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              subtitle: Text(
                _autoSyncEnabled ? 'Đồng bộ lúc $_autoSyncTime mỗi ngày' : 'Tắt',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
              value: _autoSyncEnabled,
              onChanged: _toggleAutoSync,
              activeColor: context.primaryColor,
            ),
            if (_autoSyncEnabled) ...[
              Divider(height: 1, indent: 72, color: context.dividerColor),
              _buildListTile(
                icon: Icons.access_time,
                title: 'Giờ đồng bộ',
                subtitle: _autoSyncTime,
                onTap: _pickAutoSyncTime,
                isDark: isDark,
              ),
            ],
          ]),

          // Tài khoản
          _buildSection('Tài khoản', isDark),
          _buildCard(isDark, [
            _buildListTile(
              icon: Icons.person,
              title: 'Thông tin cá nhân',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              isDark: isDark,
            ),
            Divider(height: 1, indent: 72, color: context.dividerColor),
            _buildListTile(
              icon: Icons.lock,
              title: 'Đổi mật khẩu',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
          ]),

          // Ứng dụng
          _buildSection('Ứng dụng', isDark),
          _buildCard(isDark, [
            _buildListTile(
              icon: Icons.notifications,
              title: 'Thông báo học tập',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            Divider(height: 1, indent: 72, color: context.dividerColor),
            _buildListTile(
              icon: Icons.volume_up,
              title: 'Âm thanh & phát âm',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AudioSettingsScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            Divider(height: 1, indent: 72, color: context.dividerColor),
            _buildListTile(
              icon: Icons.alarm,
              title: 'Nhắc nhở học tập',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReminderSettingsScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            Divider(height: 1, indent: 72, color: context.dividerColor),
            _buildListTile(
              icon: Icons.palette,
              title: 'Giao diện',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSettingsScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
          ]),

          // Khác
          _buildSection('Khác', isDark),
          _buildCard(isDark, [
            _buildListTile(
              icon: Icons.help,
              title: 'Trợ giúp',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
            Divider(height: 1, indent: 72, color: context.dividerColor),
            _buildListTile(
              icon: Icons.info,
              title: 'Về ứng dụng',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: AppStrings.appName,
                  applicationVersion: '1.0.0',
                  applicationIcon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school,
                      size: 48,
                      color: context.primaryColor,
                    ),
                  ),
                  children: const [
                    SizedBox(height: 16),
                    Text(
                      'Ứng dụng học từ vựng tiếng Anh đa nền tảng',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Phát triển với Flutter & Firebase',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
              isDark: isDark,
            ),
          ]),

          const SizedBox(height: AppConstants.paddingMedium),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text(
                AppStrings.logout,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.paddingMedium,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
        AppConstants.paddingSmall,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: context.primaryColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
              ),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildAvatarWidget() {
    final user = _authService.currentUser;
    
    if (_avatarUrl != null && _avatarUrl!.startsWith('/')) {
      return ClipOval(
        child: Image.file(
          File(_avatarUrl!),
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: Text(
                user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? context.primaryColor
                      : AppConstants.primaryColor,
                ),
              ),
            );
          },
        ),
      );
    }
    
    return CircleAvatar(
      radius: 35,
      backgroundColor: Colors.white,
      child: Text(
        user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? context.primaryColor
              : AppConstants.primaryColor,
        ),
      ),
    );
  }
}