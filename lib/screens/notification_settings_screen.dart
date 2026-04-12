import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _settingsService = SettingsService.instance;
  final _notificationService = NotificationService.instance;
  final _firebaseService = FirebaseService();

  bool _notificationsEnabled = false;
  bool _permissionGranted = false;

  // ✅ NEW: Study & Review reminder state
  bool _studyReminderEnabled = true;
  bool _reviewReminderEnabled = true;
  late int _studyHour;
  late int _studyMinute;
  late int _reviewHour;
  late int _reviewMinute;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _notificationsEnabled = _settingsService.getNotificationsEnabled();
      _studyReminderEnabled = _settingsService.getStudyReminderEnabled();
      _reviewReminderEnabled = _settingsService.getReviewReminderEnabled();
      _studyHour = _settingsService.getStudyReminderHour();
      _studyMinute = _settingsService.getStudyReminderMinute();
      _reviewHour = _settingsService.getReviewReminderHour();
      _reviewMinute = _settingsService.getReviewReminderMinute();
    });
  }

  Future<void> _checkPermissions() async {
    final granted = await _notificationService.checkPermissions();
    setState(() => _permissionGranted = granted);
  }

  Future<void> _syncToFirebase() async {
    final userId = DatabaseHelper.instance.currentUserId;
    if (userId != null) {
      await _firebaseService.updateNotificationSettings(userId, {
        'studyReminderEnabled': _settingsService.getStudyReminderEnabled(),
        'studyReminderHour': _settingsService.getStudyReminderHour(),
        'studyReminderMinute': _settingsService.getStudyReminderMinute(),
        'reviewReminderEnabled': _settingsService.getReviewReminderEnabled(),
        'reviewReminderHour': _settingsService.getReviewReminderHour(),
        'reviewReminderMinute': _settingsService.getReviewReminderMinute(),
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value && !_permissionGranted) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền thông báo trong Cài đặt'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
        return;
      }
      setState(() => _permissionGranted = true);
    }

    await _settingsService.setNotificationsEnabled(value);
    setState(() => _notificationsEnabled = value);

    if (!value) {
      // Tắt tất cả → hủy notifications
      await _notificationService.cancelStudyReminder();
      await _notificationService.cancelReviewReminder();
    } else {
      // Bật lại → reschedule
      await _rescheduleAll();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Đã bật thông báo' : 'Đã tắt thông báo'),
          backgroundColor: AppConstants.secondaryColor,
        ),
      );
    }
  }

  // ✅ Toggle nhắc học tập
  Future<void> _toggleStudyReminder(bool value) async {
    await _settingsService.setStudyReminderEnabled(value);
    setState(() => _studyReminderEnabled = value);

    if (value) {
      await _notificationService.scheduleStudyReminder(_studyHour, _studyMinute);
    } else {
      await _notificationService.cancelStudyReminder();
    }
    
    _syncToFirebase();
  }

  // ✅ Toggle nhắc ôn tập
  Future<void> _toggleReviewReminder(bool value) async {
    await _settingsService.setReviewReminderEnabled(value);
    setState(() => _reviewReminderEnabled = value);

    if (value) {
      await _notificationService.scheduleReviewReminder(
        hour: _reviewHour,
        minute: _reviewMinute,
      );
    } else {
      await _notificationService.cancelReviewReminder();
    }
    
    _syncToFirebase();
  }

  // ✅ Chọn giờ nhắc học tập
  Future<void> _pickStudyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _studyHour, minute: _studyMinute),
      helpText: 'Chọn giờ nhắc học tập',
    );
    if (picked != null) {
      await _settingsService.setStudyReminderTime(picked.hour, picked.minute);
      setState(() {
        _studyHour = picked.hour;
        _studyMinute = picked.minute;
      });
      if (_studyReminderEnabled) {
        await _notificationService.scheduleStudyReminder(picked.hour, picked.minute);
      }
      
      _syncToFirebase();
    }
  }

  // ✅ Chọn giờ nhắc ôn tập
  Future<void> _pickReviewTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reviewHour, minute: _reviewMinute),
      helpText: 'Chọn giờ nhắc ôn tập',
    );
    if (picked != null) {
      await _settingsService.setReviewReminderTime(picked.hour, picked.minute);
      setState(() {
        _reviewHour = picked.hour;
        _reviewMinute = picked.minute;
      });
      if (_reviewReminderEnabled) {
        await _notificationService.scheduleReviewReminder(
          hour: picked.hour,
          minute: picked.minute,
        );
      }
      
      _syncToFirebase();
    }
  }

  Future<void> _rescheduleAll() async {
    if (_studyReminderEnabled) {
      await _notificationService.scheduleStudyReminder(_studyHour, _studyMinute);
    }
    if (_reviewReminderEnabled) {
      await _notificationService.scheduleReviewReminder(
        hour: _reviewHour,
        minute: _reviewMinute,
      );
    }
  }

  Future<void> _sendTestNotification() async {
    final wordsToReview = await DatabaseHelper.instance.getWordsToReview(DateTime.now());
    await _notificationService.showTestNotification(dueWordsCount: wordsToReview.length);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi thông báo thử nghiệm'),
          backgroundColor: AppConstants.secondaryColor,
        ),
      );
    }
  }

  String _formatTime(int h, int m) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo học tập')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // === Master Toggle ===
          Card(
            elevation: isDark ? 0 : 2,
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              title: const Text(
                'Bật thông báo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _notificationsEnabled
                    ? 'Nhận nhắc nhở về việc học từ vựng'
                    : 'Bạn sẽ không nhận được thông báo',
                style: const TextStyle(fontSize: 13),
              ),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _notificationsEnabled
                      ? (context.primaryColor)
                          .withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _notificationsEnabled
                      ? (context.primaryColor)
                      : Colors.grey,
                ),
              ),
              activeColor: context.primaryColor,
            ),
          ),

          const SizedBox(height: 8),

          // Permission warning
          if (!_permissionGranted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Quyền thông báo chưa được cấp.\nVui lòng bật trong Cài đặt hệ thống.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // === Notification Types (only if enabled) ===
          if (_notificationsEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'LOẠI THÔNG BÁO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            // --- Nhắc học tập ---
            _buildReminderCard(
              isDark: isDark,
              icon: Icons.timer,
              iconColor: const Color(0xFF6C63FF),
              title: 'Nhắc học tập',
              subtitle: 'Nhắc khi chưa đạt mục tiêu hàng ngày',
              enabled: _studyReminderEnabled,
              onToggle: _toggleStudyReminder,
              time: _formatTime(_studyHour, _studyMinute),
              onPickTime: _pickStudyTime,
            ),

            const SizedBox(height: 12),

            // --- Nhắc ôn tập ---
            _buildReminderCard(
              isDark: isDark,
              icon: Icons.history_edu,
              iconColor: const Color(0xFF4ADE80),
              title: 'Nhắc ôn tập',
              subtitle: 'Nhắc khi có từ cần ôn theo SM-2',
              enabled: _reviewReminderEnabled,
              onToggle: _toggleReviewReminder,
              time: _formatTime(_reviewHour, _reviewMinute),
              onPickTime: _pickReviewTime,
            ),

            const SizedBox(height: 24),

            // Test button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.send),
                label: const Text('Gửi thông báo thử nghiệm'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.primaryColor,
                  side: BorderSide(
                    color: context.primaryColor,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Widget card cho mỗi loại nhắc nhở
  Widget _buildReminderCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required String time,
    required VoidCallback onPickTime,
  }) {
    return Card(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            SwitchListTile(
              value: enabled,
              onChanged: onToggle,
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor),
              ),
              activeColor: iconColor,
            ),
            if (enabled) ...[
              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ListTile(
                leading: const SizedBox(width: 40),
                title: const Text('Giờ nhắc', style: TextStyle(fontSize: 14)),
                trailing: GestureDetector(
                  onTap: onPickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}