/// 🛠 File test riêng biệt - KHÔNG nằm trong app production
/// Chạy bằng: flutter run -t test_tools/seed_test_data.dart
///
/// Mô phỏng 30 ngày học từ vựng thật bằng thuật toán SM-2.
/// Tạo đầy đủ dữ liệu: user_word_progress, study_sessions, user profile
/// để test các tính năng: Dynamic Level, Memory Accuracy, Progress Bar, Flashcard intervals.

import 'package:flutter/material.dart';
import 'package:vocabulary_app/db/database_helper.dart';
import 'package:vocabulary_app/models/user_word_progress.dart';
import 'package:vocabulary_app/services/srs_service.dart';
import 'package:vocabulary_app/services/auth_service.dart';
import 'package:vocabulary_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

void main() async {
  // Cần binding để dùng được rootBundle (đọc asset DB)
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase (cần cho AuthService)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SeedTestApp());
}

class SeedTestApp extends StatelessWidget {
  const SeedTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seed Test Data',
      home: const SeedTestScreen(),
    );
  }
}

class SeedTestScreen extends StatefulWidget {
  const SeedTestScreen({super.key});

  @override
  State<SeedTestScreen> createState() => _SeedTestScreenState();
}

class _SeedTestScreenState extends State<SeedTestScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;
  bool _isDone = false;

  void _log(String msg) {
    setState(() => _logs.add(msg));
    print(msg);
  }

  Future<void> _runSeed(int profileType) async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) {
        _log('❌ Chưa đăng nhập! Hãy mở app chính, đăng nhập, rồi chạy lại file này.');
        setState(() => _isRunning = false);
        return;
      }
      _log('👤 User: ${user.displayName ?? user.email ?? user.uid}');

      final dbHelper = DatabaseHelper.instance;
      dbHelper.setCurrentUser(user.uid);
      final db = await dbHelper.database;

      await _generateRealisticMockData(db, dbHelper, profileType);

      _log('');
      _log('🎉 XONG! Mở app chính và Firebase Sync để đẩy dữ liệu lên Web.');
      setState(() => _isDone = true);
    } catch (e, st) {
      _log('❌ Lỗi: $e');
      _log('Stack: $st');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  /// 🛠 History Replay - Mô phỏng dữ liệu học tập bằng SM-2
  Future<void> _generateRealisticMockData(Database db, DatabaseHelper dbHelper, int profileType) async {
    final random = math.Random(42 + profileType); // Seed khác nhau cho mỗi profile

    // Cấu hình profile
    int simulateDays = 30;
    int stopDayOffset = 0; // The last day they studied (0=today, 2=2 days ago/grace, 5=5 days ago/broken)
    int baseNewWords = 5;
    Set<int> restDays = {};
    double accuracyBase = 0.85;

    if (profileType == 1) {
      // Profile 1: Beginner (Mất streak: Học 10 ngày, nghỉ 4 ngày qua, VÀ học lại hôm nay)
      _log('🛠 [HistoryReplay] Bắt đầu mô phỏng Beginner (Nghỉ 4 ngày, vừa học hôm nay)...');
      simulateDays = 15;
      stopDayOffset = 0; // Dừng ở hôm nay (vì có học hôm nay)
      baseNewWords = 3;
      restDays = {1, 2, 3, 4}; // Nghỉ 4 ngày qua (1, 2, 3, 4)
      accuracyBase = 0.60;
    } else if (profileType == 2) {
      // Profile 2: Normal (Grace Period: Học 30 ngày, quên học hôm qua)
      _log('🛠 [HistoryReplay] Bắt đầu mô phỏng Normal (Quên học hôm qua)...');
      simulateDays = 30;
      stopDayOffset = 2; // Dừng học từ 2 ngày trước
      baseNewWords = 5;
      restDays = {5, 10, 15, 20, 25};
      accuracyBase = 0.75;
    } else if (profileType == 3) {
      // Profile 3: Expert (Active Streak: Học liên tục đến hôm nay)
      _log('🛠 [HistoryReplay] Bắt đầu mô phỏng Expert (Vừa học hôm nay)...');
      simulateDays = 60;
      stopDayOffset = 0; // Học đến hôm nay
      baseNewWords = 10;
      restDays = {}; // Không nghỉ ngày nào
      accuracyBase = 0.90;
    }

    // 1. Xóa sạch dữ liệu tiến độ cũ
    await db.delete('study_sessions');
    await db.delete('practice_results');
    await db.delete('user_word_progress');
    _log('🧹 Đã xóa dữ liệu tiến độ cũ');

    // 2. Lấy danh sách từ vựng có sẵn
    final wordRecords = await db.query('words', columns: ['id']);
    if (wordRecords.isEmpty) {
      _log('❌ Không có từ vựng nào trong DB!');
      return;
    }
    List<String> allWordIds = wordRecords.map((w) => w['id'] as String).toList();
    allWordIds.shuffle(random);
    _log('📚 Có ${allWordIds.length} từ vựng trong DB');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int wordIndex = 0;
    int currentStreak = 0;
    int maxStreak = 0;
    int totalXp = 0;

    for (int dayOffset = simulateDays; dayOffset >= stopDayOffset; dayOffset--) {
      final currentDate = today.subtract(Duration(days: dayOffset));

      // Ngày nghỉ (Ngày cuối cùng - stopDayOffset - luôn phải học để chốt last_study_date)
      if (restDays.contains(dayOffset) && dayOffset != stopDayOffset) {
        currentStreak = 0;
        _log('   📅 Day -$dayOffset: nghỉ');
        continue;
      }

      currentStreak++;
      if (currentStreak > maxStreak) maxStreak = currentStreak;

      // --- Bước 1: Học từ mới ---
      int newWordsToLearn = baseNewWords + random.nextInt(profileType == 3 ? 10 : 6);
      if (wordIndex >= allWordIds.length) {
        newWordsToLearn = 0;
      } else if (wordIndex + newWordsToLearn > allWordIds.length) {
        newWordsToLearn = allWordIds.length - wordIndex;
      }

      int dailyXp = 0;
      int totalReviewedToday = 0;

      for (int j = 0; j < newWordsToLearn; j++) {
        final wordId = allWordIds[wordIndex++];

        var progress = UserWordProgress(
          wordId: wordId,
          status: 0,
          intervalDays: 0,
          easinessFactor: 2.5,
          repetition: 0,
          reviewCount: 0,
          lapses: 0,
          firstLearnedDate: currentDate,
        );

        // Lần đầu học → quality = 4 (Good)
        progress = SrsService.calculateNextReview(4, progress, now: currentDate);

        await db.insert(
          'user_word_progress',
          progress.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        // Đánh dấu từ đã học vào bảng words gốc để đếm chính xác
        await db.update(
          'words',
          {'is_learned': 0, 'learned_at': currentDate.toIso8601String()},
          where: 'id = ?',
          whereArgs: [wordId],
        );
        totalReviewedToday++;
        dailyXp += 5;
      }

      // --- Bước 2: Ôn tập từ đến hạn (Due words) ---
      final endOfDay = currentDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      final dueQuery = await db.query(
        'user_word_progress',
        where: 'next_review_date IS NOT NULL AND next_review_date <= ? AND status > 0',
        whereArgs: [endOfDay.toIso8601String()],
      );

      List<UserWordProgress> dueWords = dueQuery
          .map((row) => UserWordProgress.fromMap(row))
          .toList();

      // Ôn 70-100% từ due (nhưng KHÔNG ôn ngày hôm nay → để user test)
      int reviewCount = 0;
      if (dayOffset > 0) {
        reviewCount = dueWords.isEmpty
            ? 0
            : (dueWords.length * (0.7 + random.nextDouble() * 0.3)).round();
      }

      for (int j = 0; j < reviewCount; j++) {
        var progress = dueWords[j];

        // Quality phân bố dựa trên accuracyBase
        int quality;
        double roll = random.nextDouble();
        
        if (roll < (1.0 - accuracyBase)) {
          quality = 2; // Fail
        } else if (roll < (1.0 - accuracyBase) + 0.15) {
          quality = 3; // OK
        } else if (roll < 0.90) {
          quality = 4; // Good
        } else {
          quality = 5; // Easy
        }

        progress = SrsService.calculateNextReview(quality, progress, now: currentDate);

        await db.update(
          'user_word_progress',
          progress.toMap(),
          where: 'word_id = ?',
          whereArgs: [progress.wordId],
        );
        totalReviewedToday++;
        dailyXp += quality >= 3 ? 5 : 1;
      }

      // --- Bước 3: Ghi Study Session ---
      if (totalReviewedToday > 0) {
        final sessionId = 'mock_${currentDate.millisecondsSinceEpoch}';
        await db.insert('study_sessions', {
          'session_id': sessionId,
          'date': currentDate.toIso8601String(),
          'xp_earned': dailyXp,
          'words_reviewed': totalReviewedToday,
          'accuracy_rate': accuracyBase + (random.nextDouble() * 0.1),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        totalXp += dailyXp;
      }

      _log('   📅 Day -$dayOffset: +$newWordsToLearn new, $reviewCount reviewed, ${dailyXp}xp');
    }

    // --- Bước 4: Đảm bảo có từ Due Today ---
    final dueTodayCheck = await db.query(
      'user_word_progress',
      where: 'next_review_date IS NOT NULL AND next_review_date <= ? AND status > 0',
      whereArgs: [today.add(const Duration(hours: 23, minutes: 59)).toIso8601String()],
    );
    _log('📋 Từ due hôm nay: ${dueTodayCheck.length}');

    if (dueTodayCheck.length < 15 && wordIndex > 0) {
      _log('🔧 Ép thêm từ thành Due Today để test...');
      int forceDueCount = 20 - dueTodayCheck.length;
      if (forceDueCount > 0) {
        final notDueQuery = await db.query(
          'user_word_progress',
          where: 'next_review_date IS NOT NULL AND next_review_date > ? AND status > 0',
          whereArgs: [today.add(const Duration(hours: 23, minutes: 59)).toIso8601String()],
          limit: forceDueCount,
        );
        for (var row in notDueQuery) {
          await db.update(
            'user_word_progress',
            {'next_review_date': today.subtract(const Duration(hours: 1)).toIso8601String()},
            where: 'word_id = ?',
            whereArgs: [row['word_id']],
          );
        }
      }
    }

    // --- Bước 5: Cập nhật User Profile ---
    final uid = dbHelper.currentUserId;
    final totalLearned = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM user_word_progress WHERE status > 0'),
    ) ?? 0;

    final lastStudyDateObj = today.subtract(Duration(days: stopDayOffset));
    final updateData = {
      'streak_days': currentStreak,
      'longest_streak': maxStreak,
      'daily_goal': 20,
      'total_points': totalXp,
      'words_learned': totalLearned,
      'last_login_date': today.millisecondsSinceEpoch, // Always login today
      'last_active': today.toIso8601String(),
      'last_study_date': DateFormat('yyyy-MM-dd').format(lastStudyDateObj),
    };

    if (uid != null) {
      await db.update('users', updateData, where: 'id = ?', whereArgs: [uid]);
    } else {
      await db.update('users', updateData);
    }

    // --- Summary ---
    final finalWordCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM user_word_progress'),
    );
    final finalSessionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM study_sessions'),
    );
    final accuracy = await dbHelper.getGlobalMemoryAccuracy();

    _log('');
    _log('✅ [HistoryReplay] HOÀN TẤT!');
    _log('   📊 Tổng từ đã học: $finalWordCount');
    _log('   📊 Tổng sessions: $finalSessionCount');
    _log('   📊 Streak hiện tại: $currentStreak, Max: $maxStreak');
    _log('   📊 Tổng XP: $totalXp');
    _log('   📊 Từ due hôm nay: ${dueTodayCheck.length}+');
    _log('   📊 Memory Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠 Seed Test Data'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : () => _runSeed(1),
                    icon: const Icon(Icons.baby_changing_station),
                    label: const Text('Tạo Beginner\n(5 ngày)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : () => _runSeed(2),
                    icon: const Icon(Icons.person),
                    label: const Text('Tạo Normal\n(30 ngày)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : () => _runSeed(3),
                    icon: const Icon(Icons.local_fire_department),
                    label: const Text('Tạo Expert\n(60 ngày)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Chú ý: Đăng nhập vào từng tài khoản khác nhau trên app, rồi mở công cụ này và chọn bộ dữ liệu tương ứng. '
              'Sau đó về lại app chính, đợi nó Auto-Sync lên Firebase Web Portal.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
