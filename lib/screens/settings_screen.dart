import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import 'package:intl/intl.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';
import 'notification_settings_screen.dart';
import 'audio_settings_screen.dart';
import 'reminder_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'help_screen.dart';
import '../widgets/feedback_dialog.dart';
import '../db/database_helper.dart';
import '../services/level_service.dart';
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

  // User stats
  int _streak = 0;
  int _totalXp = 0;
  int _learnedWords = 0;
  double _memoryAccuracy = 1.0;
  bool _notificationsEnabled = true;

  int _localWordsVersion = 1;
  int _localTopicsVersion = 1;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
    _loadUserAvatar();
    _loadAutoSyncSettings();
    _loadUserStats();
    _notificationsEnabled = _settingsService.getNotificationsEnabled();
    _loadLocalVersions();
  }

  Future<void> _loadLocalVersions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _localWordsVersion = prefs.getInt('local_words_version') ?? 1;
      _localTopicsVersion = prefs.getInt('local_topics_version') ?? 1;
    });
  }

  void _loadAutoSyncSettings() {
    setState(() {
      _autoSyncEnabled = _settingsService.getAutoSyncEnabled();
      _autoSyncTime = _settingsService.getAutoSyncTimeFormatted();
    });
  }

  Future<void> _loadUserStats() async {
    final user = _authService.currentUser;
    if (user != null) {
      final localUser = await _dbHelper.getLocalUser(user.uid);
      final accuracy = await _dbHelper.getGlobalMemoryAccuracy();
      
      if (localUser != null && mounted) {
        setState(() {
          _streak = (localUser['streak_days'] ?? localUser['currentStreak'] ?? 0) as int;
          _totalXp = (localUser['total_points'] ?? localUser['totalXp'] ?? 0) as int;
          _learnedWords = (localUser['words_learned'] ?? localUser['learnedWords'] ?? 0) as int;
          _memoryAccuracy = accuracy;
        });
      }
    }
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
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để đồng bộ'), backgroundColor: AppConstants.errorColor),
        );
      }
      return;
    }
    setState(() => _isSyncing = true);
    try {
      await _syncService.fullSync(user.uid);
      await _loadLastSyncTime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đồng bộ thành công!'), backgroundColor: AppConstants.secondaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Lỗi đồng bộ: $e';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Lỗi quyền truy cập Firestore.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: AppConstants.errorColor, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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

  Future<void> _toggleNotifications(bool enabled) async {
    await _settingsService.setNotificationsEnabled(enabled);
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardColor,
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
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
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String _formatLastSync(DateTime? dateTime) {
    if (dateTime == null) return 'Chưa đồng bộ';
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }



  String _getThemeLabel() {
    final mode = _settingsService.getThemeMode();
    switch (mode) {
      case 'light': return 'Sáng';
      case 'dark': return 'Tối';
      default: return 'Hệ thống';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? context.backgroundColor : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    Text('Cài đặt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
            ),

            // ── PROFILE CARD ──
            _buildProfileCard(user, isDark),

            const SizedBox(height: 12),

            // ── STATS ROW ──
            _buildStatsRow(isDark),

            const SizedBox(height: 24),

            // ── DỮ LIỆU ──
            _sectionTitle('Dữ liệu', isDark),
            _card(isDark, [
              _tile(
                icon: Icons.cloud_sync_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Đồng bộ dữ liệu',
                subtitle: 'Lần cuối: ${_formatLastSync(_lastSyncTime)}',
                trailing: _isSyncing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
                onTap: _isSyncing ? null : _syncNow,
                isDark: isDark,
              ),
              _divider(isDark),
              _toggleTile(
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF14B8A6),
                title: 'Tự động đồng bộ',
                subtitle: 'Tự động đồng bộ dữ liệu khi có kết nối Wi-Fi',
                value: _autoSyncEnabled,
                onChanged: _toggleAutoSync,
                isDark: isDark,
              ),
            ]),

            const SizedBox(height: 24),

            // ── TÀI KHOẢN ──
            _sectionTitle('Tài khoản', isDark),
            _card(isDark, [
              _tile(
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Thông tin cá nhân',
                subtitle: 'Xem và cập nhật thông tin của bạn',
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  if (result == true && mounted) {
                    await _loadUserAvatar();
                    await _loadUserStats();
                    setState(() {});
                  }
                },
                isDark: isDark,
              ),
              _divider(isDark),
              _tile(
                icon: Icons.lock_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Đổi mật khẩu',
                subtitle: 'Thay đổi mật khẩu tài khoản',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                isDark: isDark,
              ),
            ]),

            const SizedBox(height: 24),

            // ── TRẢI NGHIỆM HỌC TẬP ──
            _sectionTitle('Trải nghiệm học tập', isDark),
            _card(isDark, [
              _toggleTile(
                icon: Icons.notifications_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Thông báo học tập',
                subtitle: 'Nhắc nhở và thông báo về việc học',
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
              ),
              _divider(isDark),
              _tile(
                icon: Icons.volume_up_rounded,
                iconColor: const Color(0xFFEC4899),
                title: 'Âm thanh & phát âm',
                subtitle: 'Cấu hình âm thanh và phát âm',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioSettingsScreen())),
                isDark: isDark,
              ),
              _divider(isDark),
              _tile(
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Nhắc nhở học tập',
                subtitle: 'Đặt lịch nhắc nhở học tập mỗi ngày',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderSettingsScreen())),
                isDark: isDark,
              ),
            ]),

            const SizedBox(height: 24),

            // ── GIAO DIỆN ──
            _sectionTitle('Giao diện', isDark),
            _card(isDark, [
              _tile(
                icon: Icons.palette_rounded,
                iconColor: const Color(0xFF22C55E),
                title: 'Theme & giao diện',
                subtitle: 'Tùy chỉnh giao diện ứng dụng',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _settingsService.getThemeMode() == 'dark' ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(_getThemeLabel(), style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()));
                  if (mounted) setState(() {});
                },
                isDark: isDark,
              ),
            ]),

            const SizedBox(height: 24),

            // ── HỖ TRỢ & THÔNG TIN ──
            _sectionTitle('Hỗ trợ & thông tin', isDark),
            _card(isDark, [
              _tile(
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Trợ giúp',
                subtitle: 'Câu hỏi thường gặp và hướng dẫn',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                isDark: isDark,
              ),
              _divider(isDark),
              _tile(
                icon: Icons.feedback_outlined,
                iconColor: const Color(0xFFF43F5E),
                title: 'Gửi góp ý / Báo lỗi',
                subtitle: 'Gửi phản hồi cho nhà phát triển',
                onTap: () => FeedbackDialog.show(context),
                isDark: isDark,
              ),

              _divider(isDark),
              _tile(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF64748B),
                title: 'Về ứng dụng',
                subtitle: 'Phiên bản 1.2.0.${_localWordsVersion + _localTopicsVersion}',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: AppStrings.appName,
                    applicationVersion: '1.2.0.${_localWordsVersion + _localTopicsVersion}',
                    applicationIcon: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.school, size: 48, color: Color(0xFF8B5CF6)),
                    ),
                    children: const [
                      SizedBox(height: 16),
                      Text('Ứng dụng học từ vựng tiếng Anh đa nền tảng', textAlign: TextAlign.center),
                      SizedBox(height: 8),
                      Text('Phát triển với Flutter & Firebase', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  );
                },
                isDark: isDark,
              ),
            ]),

            const SizedBox(height: 32),

            // ── LOGOUT ──
            Center(
              child: TextButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
                label: Text(AppStrings.logout, style: TextStyle(color: Colors.red.shade400, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // PROFILE CARD
  // ══════════════════════════════════════════
  Widget _buildProfileCard(dynamic user, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Avatar
                Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                    ),
                    child: _buildAvatarWidget(radius: 36),
                  ),
                ),
                const SizedBox(width: 16),
                // Name + Email + Level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Level Badge and Progress Bar
                      Builder(
                        builder: (context) {
                          final score = LevelService.calculateEffectiveScore(_learnedWords, _memoryAccuracy);
                          final levelId = LevelService.getLevelId(score);
                          final progress = LevelService.getProgressToNextLevel(score);
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFFDE047), size: 14),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              LevelService.getLevelLabel(levelId),
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${(progress * 100).toInt()}%', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Edit button (top-right)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  if (result == true && mounted) {
                    await _loadUserAvatar();
                    await _loadUserStats();
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Sửa', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // STATS ROW
  // ══════════════════════════════════════════
  Widget _buildStatsRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard('🔥', '$_streak', 'Ngày streak', const Color(0xFFFF6B35), isDark),
          const SizedBox(width: 10),
          _statCard('🧠', '${(_memoryAccuracy * 100).toInt()}%', 'Độ nhớ', const Color(0xFF14B8A6), isDark),
          const SizedBox(width: 10),
          _statCard('📚', '$_learnedWords', 'Từ đã học', const Color(0xFF3B82F6), isDark),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return n.toString();
  }

  // ══════════════════════════════════════════
  // REUSABLE BUILDERS
  // ══════════════════════════════════════════
  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3)),
    );
  }

  Widget _card(bool isDark, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // AVATAR
  // ══════════════════════════════════════════
  Widget _buildAvatarWidget({double radius = 35}) {
    final user = _authService.currentUser;
    if (_avatarUrl != null && _avatarUrl!.startsWith('/')) {
      return ClipOval(
        child: Image.file(
          File(_avatarUrl!),
          width: radius * 2, height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackAvatar(user, radius),
        ),
      );
    }
    return _fallbackAvatar(user, radius);
  }

  Widget _fallbackAvatar(dynamic user, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Text(
        user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
        style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
      ),
    );
  }
}