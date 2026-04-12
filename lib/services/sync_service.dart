// ============================================
// FILE: lib/services/sync_service.dart - UPDATED with Auto-Sync
// ============================================
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../models/user_word_progress.dart';
import '../models/practice_result.dart';
import 'settings_service.dart';
import 'notification_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseService _firebaseService = FirebaseService();

  static const String _lastSyncKey = 'last_sync_timestamp';

  Timer? _autoSyncTimer;

  /// ✅ Upload local data lên Firebase
  Future<void> syncData(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ Invalid userId, skipping sync');
      return;
    }

    try {
      print('📤 Starting upload to Firebase for user: $userId');

      // Get all word progress from local database
      final progresses = await _dbHelper.getAllWordProgress();
      print('📤 Found ${progresses.length} word progress records locally');

      // Sync to Firebase in smaller batches to avoid permission issues
      if (progresses.isNotEmpty) {
        const batchSize = 20;
        for (var i = 0; i < progresses.length; i += batchSize) {
          final end = (i + batchSize > progresses.length)
              ? progresses.length
              : i + batchSize;
          final batch = progresses.sublist(i, end);
          
          try {
            await _firebaseService.syncWordProgress(userId, batch);
            print('✅ Uploaded batch ${i ~/ batchSize + 1}: ${batch.length} records');
          } catch (e) {
            print('⚠️ Batch ${i ~/ batchSize + 1} failed: $e');
            // Continue with other batches instead of stopping entirely
          }
        }
      }

      // 4. Update user progress
      final topics = await _dbHelper.getTopics();
      final totalWords = topics.fold(0, (sum, topic) => sum + topic.wordCount);
      final learnedCount = topics.fold(0, (sum, topic) => sum + topic.learnedCount);

      await _firebaseService.updateUserProgress(userId, totalWords, learnedCount);
      print('✅ Updated progress: $learnedCount / $totalWords');

      // ✅ 5. Sync Practice History
      final practiceHistory = await _dbHelper.getPracticeHistory();
      if (practiceHistory.isNotEmpty) {
        for (final practice in practiceHistory) {
          await _firebaseService.syncPracticeResult(userId, practice);
        }
        print('✅ Uploaded ${practiceHistory.length} practice records');
      }

      // ✅ 6. Sync Notification Settings
      final settingsService = SettingsService.instance;
      await _firebaseService.updateNotificationSettings(userId, {
        'studyReminderEnabled': settingsService.getStudyReminderEnabled(),
        'studyReminderHour': settingsService.getStudyReminderHour(),
        'studyReminderMinute': settingsService.getStudyReminderMinute(),
        'reviewReminderEnabled': settingsService.getReviewReminderEnabled(),
        'reviewReminderHour': settingsService.getReviewReminderHour(),
        'reviewReminderMinute': settingsService.getReviewReminderMinute(),
      });
      print('✅ Uploaded notification settings');

      // ✅ 7. Sync Study Time History (local to Cloud)
      final studyHistory = await _dbHelper.getStudyTimeHistory();
      if (studyHistory.isNotEmpty) {
        for (final entry in studyHistory) {
          final date = entry['date'] as String;
          final seconds = entry['study_time_seconds'] as int;
          final goalMinutes = entry['goal_minutes'] as int;
          await _firebaseService.saveStudyTimeEntry(userId, date, seconds, goalMinutes);
        }
        print('✅ Uploaded ${studyHistory.length} study time entries');
      }

      // Save last sync time
      await _saveLastSyncTime();
    } catch (e) {
      print('❌ Upload sync error: $e');
      rethrow;
    }
  }

  /// ✅ Download Firebase data về local
  Future<void> downloadProgress(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ Invalid userId, skipping download');
      return;
    }

    try {
      print('📥 Starting download from Firebase for user: $userId');

      // ✅ 1. Lấy user info từ Firebase
      final firebaseUser = await _firebaseService.getUser(userId);
      if (firebaseUser != null) {
        print('📥 Firebase user data: totalWords=${firebaseUser.totalWords}, learnedWords=${firebaseUser.learnedWords}');
      }

      // ✅ 2. Lấy word progress từ Firebase
      final cloudProgresses = await _firebaseService.getWordProgressList(userId);
      print('📥 Found ${cloudProgresses.length} progress records on Firebase');

      if (cloudProgresses.isEmpty) {
        print('⚠️ No progress found on Firebase');
        await _saveLastSyncTime();
        return;
      }

      // ✅ 3. Update local database
      int successCount = 0;
      int skipCount = 0;
      int errorCount = 0;

      for (var data in cloudProgresses) {
        try {
          final wordId = data['word_id'] as String?;
          if (wordId == null) continue;
          
          final cloudProgress = UserWordProgress.fromMap(data);
          final localProgress = await _dbHelper.getWordProgress(wordId);
          
          if (localProgress != null && localProgress.reviewCount >= cloudProgress.reviewCount) {
             // Local is newer or equal
             skipCount++;
             continue;
          }

          // Update local with cloud progress
          await _dbHelper.upsertWordProgress(cloudProgress);
          if (cloudProgress.status >= 2) {
             await _dbHelper.markWordAsLearned(wordId);
          }
          
          successCount++;
          
        } catch (e) {
          errorCount++;
          print('⚠️ Error processing progress record: $e');
        }
      }

      print('✅ Download complete: $successCount updated, $skipCount skipped, $errorCount errors');

      // ✅ 4. Update topic counts
      await _dbHelper.updateTopicCounts();
      print('✅ Updated local topic counts');

      // ✅ 5. Download & Restore Notification Settings
      final cloudSettings = await _firebaseService.getNotificationSettings(userId);
      if (cloudSettings != null) {
        final settingsService = SettingsService.instance;
        
        // Setup values
        await settingsService.setStudyReminderEnabled(cloudSettings['studyReminderEnabled'] ?? true);
        await settingsService.setStudyReminderTime(
          cloudSettings['studyReminderHour'] ?? 20,
          cloudSettings['studyReminderMinute'] ?? 0,
        );
        await settingsService.setReviewReminderEnabled(cloudSettings['reviewReminderEnabled'] ?? true);
        await settingsService.setReviewReminderTime(
          cloudSettings['reviewReminderHour'] ?? 8,
          cloudSettings['reviewReminderMinute'] ?? 0,
        );

        // Reschedule notifications base on new settings
        await NotificationService.instance.scheduleStudyReminder(
          cloudSettings['studyReminderHour'] ?? 20,
          cloudSettings['studyReminderMinute'] ?? 0,
        );
        await NotificationService.instance.scheduleReviewReminder(
          hour: cloudSettings['reviewReminderHour'] ?? 8,
          minute: cloudSettings['reviewReminderMinute'] ?? 0,
        );
        print('✅ Downloaded and restored notification settings');
      }

      // ✅ 6. Download Practice History
      final practiceRecords = await _firebaseService.getPracticeHistory(userId);
      if (practiceRecords.isNotEmpty) {
        for (final record in practiceRecords) {
          final practiceResult = PracticeResult.fromMap(record);
          await _dbHelper.savePracticeResult(practiceResult);
        }
        print('✅ Downloaded ${practiceRecords.length} practice records into SQLite');
      }

      // ✅ 7. Download Study Time History
      final studyTimeRecords = await _firebaseService.getStudyTimeHistory(userId);
      if (studyTimeRecords.isNotEmpty) {
        for (final record in studyTimeRecords) {
          final date = record['date'] as String;
          final seconds = record['studyTimeSeconds'] as int;
          final goalMinutes = record['goalMinutes'] as int;
          await _dbHelper.saveStudyTimeEntry(date, seconds, goalMinutes);
        }
        print('✅ Downloaded ${studyTimeRecords.length} study time entries into SQLite');
      }

      await _saveLastSyncTime();
    } catch (e) {
      print('❌ Download error: $e');
      rethrow;
    }
  }

  /// ✅ Full sync: Upload + Download
  Future<void> fullSync(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ Invalid userId, skipping full sync');
      return;
    }

    try {
      print('🔄 Starting full sync for user: $userId');
      
      await downloadProgress(userId);
      await syncData(userId);
      
      print('✅ Full sync complete');
    } catch (e) {
      print('❌ Full sync error: $e');
      rethrow;
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Save last sync time
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    print('💾 Saved sync timestamp');
  }

  /// Check if sync is needed
  Future<bool> needsSync() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    final difference = DateTime.now().difference(lastSync);
    return difference.inHours >= 1;
  }

  /// Auto sync if needed
  Future<void> autoSync(String userId) async {
    if (await needsSync()) {
      print('⏰ Auto sync triggered');
      await fullSync(userId);
    } else {
      print('⏭️ Skipping auto sync (too soon)');
    }
  }

  /// Force sync (ignore time check)
  Future<void> forceSync(String userId) async {
    print('🔨 Force sync triggered');
    await fullSync(userId);
  }

  // ============================================
  // AUTO-SYNC SCHEDULING
  // ============================================

  /// Start the auto-sync timer that checks every minute
  /// if current time matches the scheduled sync time
  void startAutoSyncTimer(String userId) {
    stopAutoSyncTimer();
    
    final settings = SettingsService.instance;
    if (!settings.getAutoSyncEnabled()) {
      print('⏭️ Auto-sync is disabled');
      return;
    }

    print('⏰ Starting auto-sync timer for user: $userId');
    
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndAutoSync(userId);
    });
  }

  /// Stop the auto-sync timer
  void stopAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Check if current time matches the scheduled sync time
  Future<void> _checkAndAutoSync(String userId) async {
    final settings = SettingsService.instance;
    if (!settings.getAutoSyncEnabled()) return;

    final now = DateTime.now();
    final targetHour = settings.getAutoSyncHour();
    final targetMinute = settings.getAutoSyncMinute();

    if (now.hour == targetHour && now.minute == targetMinute) {
      // Also check we haven't synced in the last 30 minutes to avoid double sync
      final lastSync = await getLastSyncTime();
      if (lastSync != null && now.difference(lastSync).inMinutes < 30) {
        return;
      }
      
      print('🔄 Scheduled auto-sync triggered at ${now.hour}:${now.minute}');
      try {
        await fullSync(userId);
        print('✅ Scheduled auto-sync complete');
      } catch (e) {
        print('❌ Scheduled auto-sync failed: $e');
      }
    }
  }
}