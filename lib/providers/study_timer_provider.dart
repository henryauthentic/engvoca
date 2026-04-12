import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';

/// Provider quản lý Study Timer trên Home Screen
/// Đếm lên thời gian đã học (elapsedTime) hướng tới mục tiêu (dailyGoal)
class StudyTimerProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Timer? _timer;
  int _dailyGoalSeconds = 15 * 60; // Default: 15 phút = 900 giây
  int _elapsedSeconds = 0;         // Số giây đã học hôm nay
  bool _isRunning = false;
  String? _userId;
  String _todayKey = '';

  // === Getters ===
  int get dailyGoalSeconds => _dailyGoalSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isRunning => _isRunning;
  bool get isCompleted => _elapsedSeconds >= _dailyGoalSeconds;
  double get progress => _dailyGoalSeconds > 0
      ? (_elapsedSeconds / _dailyGoalSeconds).clamp(0.0, 1.0)
      : 0.0;

  /// Thời gian còn lại (giây)
  int get remainingSeconds => (_dailyGoalSeconds - _elapsedSeconds).clamp(0, _dailyGoalSeconds);

  /// Format mm:ss cho hiển thị
  String get remainingFormatted {
    final mins = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get elapsedFormatted {
    final mins = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// Khởi tạo timer với userId và dailyGoal từ User model
  Future<void> initialize(String userId, int dailyGoalMinutes) async {
    _userId = userId;
    _dailyGoalSeconds = dailyGoalMinutes * 60;
    _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Load existing study time from DB
    final userMap = await _dbHelper.getLocalUser(userId);
    if (userMap != null) {
      final lastStudyDate = userMap['last_study_date'] as String?;
      final todayStudyTime = userMap['today_study_time'] as int? ?? 0;

      if (lastStudyDate == _todayKey) {
        // Cùng ngày → tiếp tục từ vị trí cũ
        _elapsedSeconds = todayStudyTime;
      } else {
        // Ngày mới → reset
        _elapsedSeconds = 0;
        await _dbHelper.updateStudyTime(userId, 0, _todayKey);
      }
    }

    notifyListeners();
  }

  /// Bắt đầu hoặc tiếp tục timer
  void startTimer() {
    if (_isRunning || isCompleted) return;

    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsedSeconds >= _dailyGoalSeconds) {
        pauseTimer();
        _onGoalCompleted();
        return;
      }
      _elapsedSeconds++;
      notifyListeners();

      // Lưu DB mỗi 30 giây để tránh mất tiến trình
      if (_elapsedSeconds % 30 == 0) {
        _saveToDB();
      }
    });
    notifyListeners();
  }

  /// Tạm dừng timer
  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _saveToDB();
    notifyListeners();
  }

  /// Reset timer (cho ngày mới)
  void resetTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _elapsedSeconds = 0;
    _saveToDB();
    notifyListeners();
  }

  /// Callback khi user đạt mục tiêu
  VoidCallback? onGoalCompleted;

  void _onGoalCompleted() {
    _saveToDB();
    onGoalCompleted?.call();
  }

  /// Lưu tiến trình vào DB
  Future<void> _saveToDB() async {
    if (_userId != null) {
      // 1. Cập nhật field today_study_time của user entity
      await _dbHelper.updateStudyTime(_userId!, _elapsedSeconds, _todayKey);
      
      // 2. Lưu lịch sử học tập 1 ngày (Local)
      final goalMinutes = _dailyGoalSeconds ~/ 60;
      await _dbHelper.saveStudyTimeEntry(_todayKey, _elapsedSeconds, goalMinutes);

      // 3. Đẩy lịch sử lên Firebase (Cloud)
      await FirebaseService().saveStudyTimeEntry(
        _userId!, _todayKey, _elapsedSeconds, goalMinutes
      );
    }
  }

  /// Cập nhật dailyGoal (khi user thay đổi trong Settings)
  void updateDailyGoal(int minutes) {
    _dailyGoalSeconds = minutes * 60;
    notifyListeners();
  }

  /// Check nếu ngày hôm nay khác → reset
  void checkDailyReset() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_todayKey != today) {
      _todayKey = today;
      _elapsedSeconds = 0;
      _isRunning = false;
      _timer?.cancel();
      _timer = null;
      _saveToDB();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveToDB();
    super.dispose();
  }
}
