import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._init();
  static SharedPreferences? _prefs;

  SettingsService._init();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==========================================
  // THEME SETTINGS
  // ==========================================
  
  static const String _keyThemeMode = 'theme_mode';
  
  Future<void> setThemeMode(String mode) async {
    await _prefs?.setString(_keyThemeMode, mode);
  }
  
  String getThemeMode() {
    return _prefs?.getString(_keyThemeMode) ?? 'system';
  }

  // ==========================================
  // NOTIFICATION SETTINGS
  // ==========================================
  
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_keyNotificationsEnabled, enabled);
  }
  
  bool getNotificationsEnabled() {
    return _prefs?.getBool(_keyNotificationsEnabled) ?? true;
  }

  // ✅ NEW: Study Reminder (Nhắc học tập)
  static const String _keyStudyReminderEnabled = 'study_reminder_enabled';
  static const String _keyStudyReminderHour = 'study_reminder_hour';
  static const String _keyStudyReminderMinute = 'study_reminder_minute';

  Future<void> setStudyReminderEnabled(bool enabled) async {
    await _prefs?.setBool(_keyStudyReminderEnabled, enabled);
  }

  bool getStudyReminderEnabled() {
    return _prefs?.getBool(_keyStudyReminderEnabled) ?? true;
  }

  Future<void> setStudyReminderTime(int hour, int minute) async {
    await _prefs?.setInt(_keyStudyReminderHour, hour);
    await _prefs?.setInt(_keyStudyReminderMinute, minute);
  }

  int getStudyReminderHour() => _prefs?.getInt(_keyStudyReminderHour) ?? 20;
  int getStudyReminderMinute() => _prefs?.getInt(_keyStudyReminderMinute) ?? 0;

  String getStudyReminderTimeFormatted() {
    final h = getStudyReminderHour().toString().padLeft(2, '0');
    final m = getStudyReminderMinute().toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ✅ NEW: Review Reminder (Nhắc ôn tập)
  static const String _keyReviewReminderEnabled = 'review_reminder_enabled';
  static const String _keyReviewReminderHour = 'review_reminder_hour';
  static const String _keyReviewReminderMinute = 'review_reminder_minute';

  Future<void> setReviewReminderEnabled(bool enabled) async {
    await _prefs?.setBool(_keyReviewReminderEnabled, enabled);
  }

  bool getReviewReminderEnabled() {
    return _prefs?.getBool(_keyReviewReminderEnabled) ?? true;
  }

  Future<void> setReviewReminderTime(int hour, int minute) async {
    await _prefs?.setInt(_keyReviewReminderHour, hour);
    await _prefs?.setInt(_keyReviewReminderMinute, minute);
  }

  int getReviewReminderHour() => _prefs?.getInt(_keyReviewReminderHour) ?? 8;
  int getReviewReminderMinute() => _prefs?.getInt(_keyReviewReminderMinute) ?? 0;

  String getReviewReminderTimeFormatted() {
    final h = getReviewReminderHour().toString().padLeft(2, '0');
    final m = getReviewReminderMinute().toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ==========================================
  // AUDIO SETTINGS
  // ==========================================
  
  static const String _keySpeechRate = 'speech_rate';
  static const String _keyAutoPlay = 'auto_play';
  static const String _keyVolume = 'volume';
  
  Future<void> setSpeechRate(double rate) async {
    await _prefs?.setDouble(_keySpeechRate, rate);
  }
  
  double getSpeechRate() {
    return _prefs?.getDouble(_keySpeechRate) ?? 1.0;
  }
  
  Future<void> setAutoPlay(bool enabled) async {
    await _prefs?.setBool(_keyAutoPlay, enabled);
  }
  
  bool getAutoPlay() {
    return _prefs?.getBool(_keyAutoPlay) ?? false;
  }
  
  Future<void> setVolume(double volume) async {
    await _prefs?.setDouble(_keyVolume, volume);
  }
  
  double getVolume() {
    return _prefs?.getDouble(_keyVolume) ?? 1.0;
  }

  // ==========================================
  // DAILY REMINDER SETTINGS
  // ==========================================
  
  static const String _keyDailyReminderEnabled = 'daily_reminder_enabled';
  static const String _keyDailyReminderTime = 'daily_reminder_time';
  
  Future<void> setDailyReminderEnabled(bool enabled) async {
    await _prefs?.setBool(_keyDailyReminderEnabled, enabled);
  }
  
  bool getDailyReminderEnabled() {
    return _prefs?.getBool(_keyDailyReminderEnabled) ?? false;
  }
  
  Future<void> setDailyReminderTime(String time) async {
    await _prefs?.setString(_keyDailyReminderTime, time);
  }
  
  String getDailyReminderTime() {
    return _prefs?.getString(_keyDailyReminderTime) ?? '19:00';
  }

  // ==========================================
  // WEEKLY REMINDER SETTINGS
  // ==========================================
  
  // Monday
  Future<void> setMondayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('monday_enabled', enabled);
  }
  
  bool getMondayReminderEnabled() {
    return _prefs?.getBool('monday_enabled') ?? false;
  }
  
  Future<void> setMondayReminderTime(String time) async {
    await _prefs?.setString('monday_time', time);
  }
  
  String getMondayReminderTime() {
    return _prefs?.getString('monday_time') ?? '19:00';
  }
  
  // Tuesday
  Future<void> setTuesdayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('tuesday_enabled', enabled);
  }
  
  bool getTuesdayReminderEnabled() {
    return _prefs?.getBool('tuesday_enabled') ?? false;
  }
  
  Future<void> setTuesdayReminderTime(String time) async {
    await _prefs?.setString('tuesday_time', time);
  }
  
  String getTuesdayReminderTime() {
    return _prefs?.getString('tuesday_time') ?? '19:00';
  }
  
  // Wednesday
  Future<void> setWednesdayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('wednesday_enabled', enabled);
  }
  
  bool getWednesdayReminderEnabled() {
    return _prefs?.getBool('wednesday_enabled') ?? false;
  }
  
  Future<void> setWednesdayReminderTime(String time) async {
    await _prefs?.setString('wednesday_time', time);
  }
  
  String getWednesdayReminderTime() {
    return _prefs?.getString('wednesday_time') ?? '19:00';
  }
  
  // Thursday
  Future<void> setThursdayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('thursday_enabled', enabled);
  }
  
  bool getThursdayReminderEnabled() {
    return _prefs?.getBool('thursday_enabled') ?? false;
  }
  
  Future<void> setThursdayReminderTime(String time) async {
    await _prefs?.setString('thursday_time', time);
  }
  
  String getThursdayReminderTime() {
    return _prefs?.getString('thursday_time') ?? '19:00';
  }
  
  // Friday
  Future<void> setFridayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('friday_enabled', enabled);
  }
  
  bool getFridayReminderEnabled() {
    return _prefs?.getBool('friday_enabled') ?? false;
  }
  
  Future<void> setFridayReminderTime(String time) async {
    await _prefs?.setString('friday_time', time);
  }
  
  String getFridayReminderTime() {
    return _prefs?.getString('friday_time') ?? '19:00';
  }
  
  // Saturday
  Future<void> setSaturdayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('saturday_enabled', enabled);
  }
  
  bool getSaturdayReminderEnabled() {
    return _prefs?.getBool('saturday_enabled') ?? false;
  }
  
  Future<void> setSaturdayReminderTime(String time) async {
    await _prefs?.setString('saturday_time', time);
  }
  
  String getSaturdayReminderTime() {
    return _prefs?.getString('saturday_time') ?? '19:00';
  }
  
  // Sunday
  Future<void> setSundayReminderEnabled(bool enabled) async {
    await _prefs?.setBool('sunday_enabled', enabled);
  }
  
  bool getSundayReminderEnabled() {
    return _prefs?.getBool('sunday_enabled') ?? false;
  }
  
  Future<void> setSundayReminderTime(String time) async {
    await _prefs?.setString('sunday_time', time);
  }
  
  String getSundayReminderTime() {
    return _prefs?.getString('sunday_time') ?? '19:00';
  }

  // ==========================================
  // AUTO SYNC SETTINGS
  // ==========================================
  
  static const String _keyAutoSyncEnabled = 'auto_sync_enabled';
  static const String _keyAutoSyncHour = 'auto_sync_hour';
  static const String _keyAutoSyncMinute = 'auto_sync_minute';
  
  Future<void> setAutoSyncEnabled(bool enabled) async {
    await _prefs?.setBool(_keyAutoSyncEnabled, enabled);
  }
  
  bool getAutoSyncEnabled() {
    return _prefs?.getBool(_keyAutoSyncEnabled) ?? false;
  }
  
  Future<void> setAutoSyncTime(int hour, int minute) async {
    await _prefs?.setInt(_keyAutoSyncHour, hour);
    await _prefs?.setInt(_keyAutoSyncMinute, minute);
  }
  
  int getAutoSyncHour() {
    return _prefs?.getInt(_keyAutoSyncHour) ?? 23;
  }
  
  int getAutoSyncMinute() {
    return _prefs?.getInt(_keyAutoSyncMinute) ?? 0;
  }
  
  String getAutoSyncTimeFormatted() {
    final h = getAutoSyncHour().toString().padLeft(2, '0');
    final m = getAutoSyncMinute().toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================
  
  Map<String, bool> getWeeklyReminders() {
    return {
      'Thứ 2': getMondayReminderEnabled(),
      'Thứ 3': getTuesdayReminderEnabled(),
      'Thứ 4': getWednesdayReminderEnabled(),
      'Thứ 5': getThursdayReminderEnabled(),
      'Thứ 6': getFridayReminderEnabled(),
      'Thứ 7': getSaturdayReminderEnabled(),
      'Chủ nhật': getSundayReminderEnabled(),
    };
  }
  
  Map<String, String> getWeeklyReminderTimes() {
    return {
      'Thứ 2': getMondayReminderTime(),
      'Thứ 3': getTuesdayReminderTime(),
      'Thứ 4': getWednesdayReminderTime(),
      'Thứ 5': getThursdayReminderTime(),
      'Thứ 6': getFridayReminderTime(),
      'Thứ 7': getSaturdayReminderTime(),
      'Chủ nhật': getSundayReminderTime(),
    };
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }
}