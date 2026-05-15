import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _settingsService = SettingsService.instance;
  final _notificationService = NotificationService.instance;

  bool _dailyReminderEnabled = false;
  String _dailyReminderTime = '19:00';

  final Map<String, bool> _weeklyReminders = {};
  final Map<String, String> _weeklyReminderTimes = {};

  final List<Map<String, dynamic>> _weekdays = [
    {'day': 'Thứ 2', 'key': 'monday', 'id': 1},
    {'day': 'Thứ 3', 'key': 'tuesday', 'id': 2},
    {'day': 'Thứ 4', 'key': 'wednesday', 'id': 3},
    {'day': 'Thứ 5', 'key': 'thursday', 'id': 4},
    {'day': 'Thứ 6', 'key': 'friday', 'id': 5},
    {'day': 'Thứ 7', 'key': 'saturday', 'id': 6},
    {'day': 'Chủ nhật', 'key': 'sunday', 'id': 7},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _dailyReminderEnabled = _settingsService.getDailyReminderEnabled();
      _dailyReminderTime = _settingsService.getDailyReminderTime();

      _weeklyReminders['Thứ 2'] = _settingsService.getMondayReminderEnabled();
      _weeklyReminders['Thứ 3'] = _settingsService.getTuesdayReminderEnabled();
      _weeklyReminders['Thứ 4'] = _settingsService.getWednesdayReminderEnabled();
      _weeklyReminders['Thứ 5'] = _settingsService.getThursdayReminderEnabled();
      _weeklyReminders['Thứ 6'] = _settingsService.getFridayReminderEnabled();
      _weeklyReminders['Thứ 7'] = _settingsService.getSaturdayReminderEnabled();
      _weeklyReminders['Chủ nhật'] = _settingsService.getSundayReminderEnabled();

      _weeklyReminderTimes['Thứ 2'] = _settingsService.getMondayReminderTime();
      _weeklyReminderTimes['Thứ 3'] = _settingsService.getTuesdayReminderTime();
      _weeklyReminderTimes['Thứ 4'] = _settingsService.getWednesdayReminderTime();
      _weeklyReminderTimes['Thứ 5'] = _settingsService.getThursdayReminderTime();
      _weeklyReminderTimes['Thứ 6'] = _settingsService.getFridayReminderTime();
      _weeklyReminderTimes['Thứ 7'] = _settingsService.getSaturdayReminderTime();
      _weeklyReminderTimes['Chủ nhật'] = _settingsService.getSundayReminderTime();
    });
  }

  Future<void> _toggleDailyReminder(bool value) async {
    await _settingsService.setDailyReminderEnabled(value);

    if (value) {
      await _notificationService.scheduleDailyReminder(_dailyReminderTime);
    } else {
      await _notificationService.cancelDailyReminder();
    }

    setState(() {
      _dailyReminderEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Đã bật nhắc nhở hàng ngày' : 'Đã tắt nhắc nhở hàng ngày',
          ),
          backgroundColor: AppConstants.secondaryColor,
        ),
      );
    }
  }

  Future<void> _pickDailyTime() async {
    final currentTime = _parseTime(_dailyReminderTime);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      final formattedTime = _formatTime(time);
      await _settingsService.setDailyReminderTime(formattedTime);

      if (_dailyReminderEnabled) {
        await _notificationService.scheduleDailyReminder(formattedTime);
      }

      setState(() {
        _dailyReminderTime = formattedTime;
      });
    }
  }

  Future<void> _toggleWeeklyReminder(String day, String key, int id, bool value) async {
    switch (key) {
      case 'monday':
        await _settingsService.setMondayReminderEnabled(value);
        break;
      case 'tuesday':
        await _settingsService.setTuesdayReminderEnabled(value);
        break;
      case 'wednesday':
        await _settingsService.setWednesdayReminderEnabled(value);
        break;
      case 'thursday':
        await _settingsService.setThursdayReminderEnabled(value);
        break;
      case 'friday':
        await _settingsService.setFridayReminderEnabled(value);
        break;
      case 'saturday':
        await _settingsService.setSaturdayReminderEnabled(value);
        break;
      case 'sunday':
        await _settingsService.setSundayReminderEnabled(value);
        break;
    }

    if (value) {
      final time = _weeklyReminderTimes[day] ?? '19:00';
      await _notificationService.scheduleWeeklyReminder(
        dayOfWeek: id,
        time: time,
        notificationId: id,
      );
    } else {
      await _notificationService.cancelWeeklyReminder(id);
    }

    setState(() {
      _weeklyReminders[day] = value;
    });
  }

  Future<void> _pickWeeklyTime(String day, String key, int id) async {
    final currentTime = _parseTime(_weeklyReminderTimes[day] ?? '19:00');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      final formattedTime = _formatTime(time);

      switch (key) {
        case 'monday':
          await _settingsService.setMondayReminderTime(formattedTime);
          break;
        case 'tuesday':
          await _settingsService.setTuesdayReminderTime(formattedTime);
          break;
        case 'wednesday':
          await _settingsService.setWednesdayReminderTime(formattedTime);
          break;
        case 'thursday':
          await _settingsService.setThursdayReminderTime(formattedTime);
          break;
        case 'friday':
          await _settingsService.setFridayReminderTime(formattedTime);
          break;
        case 'saturday':
          await _settingsService.setSaturdayReminderTime(formattedTime);
          break;
        case 'sunday':
          await _settingsService.setSundayReminderTime(formattedTime);
          break;
      }

      if (_weeklyReminders[day] == true) {
        await _notificationService.scheduleWeeklyReminder(
          dayOfWeek: id,
          time: formattedTime,
          notificationId: id,
        );
      }

      setState(() {
        _weeklyReminderTimes[day] = formattedTime;
      });
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Nhắc nhở học tập'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // Daily Reminder Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
            child: Text(
              'Nhắc nhở hàng ngày',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textTertiary,
              ),
            ),
          ),

          Card(
            elevation: isDark ? 0 : 2,
            color: context.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _dailyReminderEnabled,
                  onChanged: _toggleDailyReminder,
                  title: Text(
                    'Nhắc nhở cố định',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Nhắc nhở vào cùng một giờ mỗi ngày',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _dailyReminderEnabled
                          ? context.primaryColor.withOpacity(0.1)
                          : (context.subtleBackground),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.alarm,
                      color: _dailyReminderEnabled
                          ? (context.primaryColor)
                          : (context.textTertiary),
                    ),
                  ),
                  activeColor: context.primaryColor,
                ),
                if (_dailyReminderEnabled) ...[
                  Divider(
                    height: 1,
                    indent: 72,
                    color: isDark ? context.subtleBackground : Colors.grey[300],
                  ),
                  ListTile(
                    leading: const SizedBox(width: 40),
                    title: Text(
                      'Thời gian nhắc nhở',
                      style: TextStyle(
                        color: context.textPrimary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dailyReminderTime,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: context.textTertiary,
                        ),
                      ],
                    ),
                    onTap: _pickDailyTime,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Weekly Reminder Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
            child: Text(
              'Nhắc nhở theo lịch tuần',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.textTertiary,
              ),
            ),
          ),

          Card(
            elevation: isDark ? 0 : 2,
            color: context.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Column(
              children: _weekdays.asMap().entries.map((entry) {
                final index = entry.key;
                final weekday = entry.value;
                final day = weekday['day'] as String;
                final key = weekday['key'] as String;
                final id = weekday['id'] as int;
                final isEnabled = _weeklyReminders[day] ?? false;
                final time = _weeklyReminderTimes[day] ?? '19:00';

                return Column(
                  children: [
                    if (index > 0) 
                      Divider(
                        height: 1,
                        indent: 16,
                        color: isDark ? context.subtleBackground : Colors.grey[300],
                      ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? (AppConstants.secondaryColor).withOpacity(0.1)
                                : (context.subtleBackground),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: isEnabled
                                ? (AppConstants.secondaryColor)
                                : (context.textTertiary),
                          ),
                        ),
                        title: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          isEnabled ? 'Nhắc lúc $time' : 'Tắt',
                          style: TextStyle(
                            fontSize: 12,
                            color: isEnabled
                                ? (AppConstants.secondaryColor)
                                : (context.textTertiary),
                          ),
                        ),
                        trailing: Switch(
                          value: isEnabled,
                          onChanged: (value) =>
                              _toggleWeeklyReminder(day, key, id, value),
                          activeColor: AppConstants.secondaryColor,
                        ),
                        children: [
                          if (isEnabled)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Thời gian:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _pickWeeklyTime(day, key, id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (AppConstants.secondaryColor).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: (AppConstants.secondaryColor).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            time,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppConstants.secondaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.access_time,
                                            size: 18,
                                            color: AppConstants.secondaryColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
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
                  Icons.info_outline,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn có thể thiết lập cả nhắc nhở hàng ngày và nhắc nhở theo tuần cùng lúc',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark 
                          ? Colors.blue.shade100 
                          : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}