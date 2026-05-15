// ============================================
// FILE: lib/services/sync_service.dart - ADVANCED QUERY + SMART SYNC
// ============================================
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../models/user_word_progress.dart';
import '../models/practice_result.dart';
import '../models/user.dart';
import '../models/study_session.dart';
import 'settings_service.dart';
import 'notification_service.dart';
import 'gamification_service.dart';
import '../models/content_update_info.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseService _firebaseService = FirebaseService();

  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _localWordsVersionKey = 'local_words_version';
  static const String _localTopicsVersionKey = 'local_topics_version';
  static const String _lastContentCheckKey = 'last_content_check_at';

  Timer? _autoSyncTimer;

  // ============================================
  // ✅ UPLOAD: Push local data lên Firebase
  // ============================================

  /// Upload local data lên Firebase
  Future<void> syncData(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ Invalid userId, skipping sync');
      return;
    }

    try {
      print('📤 Starting upload to Firebase for user: $userId');

      // 1. Get all word progress from local database
      final progresses = await _dbHelper.getAllWordProgress();
      print('📤 Found ${progresses.length} word progress records locally');

      // 2. Sync word progress to Firebase in smaller batches
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

      // 3. ✅ ADVANCED QUERY: Compute aggregated stats from SQLite
      final aggregatedStats = await _computeAggregatedStats();
      
      // 4. Update user progress and full profile
      final topics = await _dbHelper.getParentTopics();
      final totalWords = topics.fold(0, (sum, topic) => sum + topic.wordCount);
      final learnedCount = topics.fold(0, (sum, topic) => sum + topic.learnedCount);

      // Get local user profile to push all stats (streak, xp, level, etc.)
      final localUserMap = await _dbHelper.getLocalUser(userId);
      if (localUserMap != null) {
        final localUser = User.fromMap(localUserMap);
        
        // Update user stats with latest counts + aggregated stats
        final updatedUser = localUser.copyWith(
          totalWords: totalWords,
          learnedWords: learnedCount,
          lastLoginAt: DateTime.now(),
          topicProgress: aggregatedStats['topicProgress'] as Map<String, int>,
          totalReviews: aggregatedStats['totalReviews'] as int,
          totalLapses: aggregatedStats['totalLapses'] as int,
          lastChangeSource: 'mobile',
        );
        
        // Push full user profile to Firebase
        await _firebaseService.updateUser(updatedUser);
        print('✅ Updated full user profile (streak: ${updatedUser.currentStreak}, level: ${updatedUser.level})');
        print('✅ Aggregated stats pushed: topics=${(aggregatedStats['topicProgress'] as Map).length}, '
            'reviews=${aggregatedStats['totalReviews']}, lapses=${aggregatedStats['totalLapses']}');

        // ✅ Also update local SQLite users.words_learned to stay in sync
        final db = await _dbHelper.database;
        await db.update(
          'users',
          {'words_learned': learnedCount},
          where: 'id = ?',
          whereArgs: [userId],
        );
      } else {
        // Fallback if local user not found
        await _firebaseService.updateUserProgress(userId, totalWords, learnedCount);
        // Still push aggregated stats separately
        await _firebaseService.updateAggregatedStats(
          userId,
          topicProgress: aggregatedStats['topicProgress'] as Map<String, int>,
          totalReviews: aggregatedStats['totalReviews'] as int,
          totalLapses: aggregatedStats['totalLapses'] as int,
        );
        print('✅ Updated progress only: $learnedCount / $totalWords');
      }

      // ✅ Push dailyWordCounts for Web Heatmap & Charts
      final dailyWordCounts = await _dbHelper.getWordsLearnedPerDay(180);
      if (dailyWordCounts.isNotEmpty) {
        await _firebaseService.updateDailyWordCounts(userId, dailyWordCounts);
      }

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

      // ✅ 8. Sync Badges
      final unlockedBadges = await _dbHelper.getUnlockedBadgesMap(userId);
      if (unlockedBadges.isNotEmpty) {
        await _firebaseService.syncBadges(userId, unlockedBadges);
        print('✅ Uploaded ${unlockedBadges.length} badges');
      }

      // ✅ 9. Sync Counters
      final counterKeys = ['story_count', 'chat_count', 'quiz_completed'];
      final counters = <String, int>{};
      for (final key in counterKeys) {
        counters[key] = await _dbHelper.getCounter(userId, key);
      }
      await _firebaseService.syncCounters(userId, counters);
      print('✅ Uploaded counters: $counters');

      // ✅ 10. Update sync metadata (server timestamp)
      await _firebaseService.updateSyncMetadata(userId, 'mobile');

      // Save last sync time locally
      await _saveLastSyncTime();
    } catch (e) {
      print('❌ Upload sync error: $e');
      rethrow;
    }
  }

  // ============================================
  // ✅ ADVANCED QUERY: Compute Topic Progress + Memory Stats from SQLite
  // ============================================

  /// Scan SQLite to compute absolute aggregated stats.
  /// Uses status >= 2 in user_word_progress (consistent with Web counting).
  /// Returns { topicProgress: Map<String,int>, totalReviews: int, totalLapses: int }
  Future<Map<String, dynamic>> _computeAggregatedStats() async {
    try {
      final db = await _dbHelper.database;
      final topicIdCol = _dbHelper.topicIdColumn;

      // 1. Count learned words (status >= 2) per PARENT topic
      // Join: user_word_progress → words → topics to find parent
      final topicResults = await db.rawQuery('''
        SELECT 
          COALESCE(t.parent_id, t.id) as parent_topic_id,
          COUNT(*) as learned_count
        FROM user_word_progress p
        JOIN words w ON p.word_id = w.id
        JOIN topics t ON w.$topicIdCol = t.id
        WHERE p.status >= 2
        GROUP BY parent_topic_id
      ''');

      final Map<String, int> topicProgress = {};
      for (final row in topicResults) {
        final parentId = row['parent_topic_id'] as String?;
        final count = row['learned_count'] as int? ?? 0;
        if (parentId != null && parentId.isNotEmpty) {
          topicProgress[parentId] = count;
        }
      }

      // 2. Compute total reviews and total lapses (absolute count from SQLite)
      final statsResult = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(review_count), 0) as total_reviews,
          COALESCE(SUM(lapses), 0) as total_lapses
        FROM user_word_progress
      ''');

      int totalReviews = 0;
      int totalLapses = 0;
      if (statsResult.isNotEmpty) {
        totalReviews = (statsResult.first['total_reviews'] as num?)?.toInt() ?? 0;
        totalLapses = (statsResult.first['total_lapses'] as num?)?.toInt() ?? 0;
      }

      print('📊 Aggregated stats: ${topicProgress.length} topics, $totalReviews reviews, $totalLapses lapses');
      return {
        'topicProgress': topicProgress,
        'totalReviews': totalReviews,
        'totalLapses': totalLapses,
      };
    } catch (e) {
      print('❌ Error computing aggregated stats: $e');
      return {
        'topicProgress': <String, int>{},
        'totalReviews': 0,
        'totalLapses': 0,
      };
    }
  }

  // ============================================
  // ✅ DOWNLOAD: Firebase data về local (Delta Sync)
  // ============================================

  /// Download Firebase data về local (supports Delta Sync)
  /// Sử dụng LWW (Last Write Wins) conflict resolution chuẩn.
  Future<void> downloadProgress(String userId, {bool deltaOnly = true}) async {
    if (userId.isEmpty) {
      print('⚠️ Invalid userId, skipping download');
      return;
    }

    try {
      print('📥 Starting download (delta=$deltaOnly) for user: $userId');

      // ✅ 1. Lấy user info từ Firebase và cập nhật SQLite
      final firebaseUser = await _firebaseService.getUser(userId);
      if (firebaseUser != null) {
        print('📥 Firebase user data: totalWords=${firebaseUser.totalWords}, learnedWords=${firebaseUser.learnedWords}, streak=${firebaseUser.currentStreak}, longest=${firebaseUser.longestStreak}');
        
        // Sync user stats từ Firebase → SQLite
        await _dbHelper.upsertUser(
          id: userId,
          name: firebaseUser.displayName,
          email: firebaseUser.email,
          avatarUrl: firebaseUser.avatar,
          level: firebaseUser.level,
          totalPoints: firebaseUser.totalXp,
          wordsLearned: firebaseUser.learnedWords,
          streakDays: firebaseUser.currentStreak,
          longestStreak: firebaseUser.longestStreak,
          usedGracePeriod: firebaseUser.usedGracePeriod,
          learningLevel: firebaseUser.learningLevel,
          selectedTopics: firebaseUser.selectedTopics?.join(','),
          dailyGoal: firebaseUser.dailyGoal,
          isOnboarded: firebaseUser.isOnboarded,
          lastStudyDate: firebaseUser.lastStudyDate,
        );
        print('✅ Synced Firebase user stats → SQLite');
      }

      // ✅ 2. Lấy word progress từ Firebase (Delta or Full)
      List<Map<String, dynamic>> cloudProgresses;
      
      if (deltaOnly) {
        final lastSync = await getLastSyncTime();
        if (lastSync != null) {
          // Delta Sync: only fetch records changed since last sync
          cloudProgresses = await _firebaseService.getWordProgressSince(userId, lastSync);
          print('📥 Delta sync: ${cloudProgresses.length} changed records');
        } else {
          // First time sync: download everything
          cloudProgresses = await _firebaseService.getWordProgressList(userId);
          print('📥 First sync: ${cloudProgresses.length} total records');
        }
      } else {
        // Forced full download
        cloudProgresses = await _firebaseService.getWordProgressList(userId);
        print('📥 Full download: ${cloudProgresses.length} total records');
      }

      if (cloudProgresses.isEmpty) {
        print('⚠️ No progress found on Firebase');
        await _saveLastSyncTime();
        return;
      }

      // ✅ 3. Update local database (LWW conflict resolution)
      int successCount = 0;
      int skipCount = 0;
      int errorCount = 0;
      int webXpEarnedToday = 0;
      int webWordsReviewedToday = 0;
      final now = DateTime.now();

      for (var data in cloudProgresses) {
        try {
          final wordId = data['word_id'] as String? ?? data['wordId'] as String?;
          if (wordId == null) continue;
          
          final cloudProgress = UserWordProgress.fromMap(data);
          final localProgress = await _dbHelper.getWordProgress(wordId);
          
          // ✅ LWW Conflict Resolution: chỉ ghi đè khi cloud mới hơn
          if (localProgress != null) {
            final localTime = localProgress.updatedAt ?? localProgress.lastReviewDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final cloudTime = cloudProgress.updatedAt ?? cloudProgress.lastReviewDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            
            final cloudIsNewerByReviews = cloudProgress.reviewCount > localProgress.reviewCount;
            final cloudIsNewerByTime = cloudTime.isAfter(localTime);
            
            if (!cloudIsNewerByReviews && !cloudIsNewerByTime) {
              skipCount++;
              continue;
            }
          }

          // ✅ Caculate XP if activity was done today on Web
          final cloudTime = cloudProgress.updatedAt ?? cloudProgress.lastReviewDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final isToday = cloudTime.year == now.year && cloudTime.month == now.month && cloudTime.day == now.day;
          
          if (isToday) {
            if (localProgress == null) {
              webXpEarnedToday += (cloudProgress.status >= 2) ? 15 : (cloudProgress.reviewCount * 3);
              webWordsReviewedToday += cloudProgress.reviewCount > 0 ? cloudProgress.reviewCount : 1;
            } else {
              if (localProgress.status < 2 && cloudProgress.status >= 2) {
                webXpEarnedToday += 15;
                webWordsReviewedToday += 1;
              } else if (cloudProgress.reviewCount > localProgress.reviewCount) {
                int diff = cloudProgress.reviewCount - localProgress.reviewCount;
                webXpEarnedToday += diff * 3;
                webWordsReviewedToday += diff;
              }
            }
          }

          // ✅ Handle custom words saved from Web Portal FIRST (so word exists before marking)
          if (data.containsKey('word') && data['word'] != null) {
            final wordText = data['word'] as String;
            final meaning = data['meaning'] as String? ?? 'Không có nghĩa';
            final pronunciation = data['pronunciation'] as String? ?? '';
            
            // Upsert into words table BEFORE marking as learned
            await _dbHelper.upsertCustomWord(
              id: wordId,
              word: wordText,
              meaning: meaning,
              pronunciation: pronunciation,
            );
          }

          // Update local with cloud progress
          await _dbHelper.upsertWordProgress(cloudProgress);
          if (cloudProgress.status > 0) {
             await _dbHelper.markWordAsLearned(wordId);
          }
          
          successCount++;
          
        } catch (e) {
          errorCount++;
          print('⚠️ Error processing progress record: $e');
        }
      }

      print('✅ Download complete: $successCount updated, $skipCount skipped, $errorCount errors');

      // ✅ Create a dummy StudySession to award "Today's XP" from Web activity
      if (webXpEarnedToday > 0) {
        await GamificationService().addXp(userId, webXpEarnedToday, source: 'web_sync');
        await _dbHelper.insertStudySession(StudySession(
          sessionId: 'web_sync_${now.millisecondsSinceEpoch}',
          date: now,
          xpEarned: webXpEarnedToday,
          wordsReviewed: webWordsReviewedToday,
          accuracyRate: 1.0,
        ));
        print('🎉 Awarded $webXpEarnedToday XP for $webWordsReviewedToday words learned/reviewed on Web today!');
      }

      // ✅ 4. Update topic counts
      await _dbHelper.updateTopicCounts();
      print('✅ Updated local topic counts');

      // ✅ 4b. Sync users.words_learned with actual topic counts
      // Cần làm vì downloadProgress ban đầu ghi giá trị cũ từ Firebase vào SQLite
      // nhưng sau khi download progress + updateTopicCounts, số thực tế có thể khác
      final freshTopics = await _dbHelper.getParentTopics();
      final freshLearnedCount = freshTopics.fold(0, (sum, t) => sum + t.learnedCount);
      final db = await _dbHelper.database;
      await db.update(
        'users',
        {'words_learned': freshLearnedCount},
        where: 'id = ?',
        whereArgs: [userId],
      );
      print('✅ Synced users.words_learned = $freshLearnedCount (from topics)');

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

      // ✅ 8. Download Badges
      final cloudBadges = await _firebaseService.getBadges(userId);
      if (cloudBadges.isNotEmpty) {
        for (final badge in cloudBadges) {
          final badgeId = badge['badge_id'] as String?;
          if (badgeId != null) {
            await _dbHelper.unlockBadge(userId, badgeId);
          }
        }
        print('✅ Downloaded ${cloudBadges.length} badges');
      }

      // ✅ 9. Download Counters
      final cloudCounters = await _firebaseService.getCounters(userId);
      if (cloudCounters.isNotEmpty) {
        for (final entry in cloudCounters.entries) {
          final localVal = await _dbHelper.getCounter(userId, entry.key);
          // Lấy giá trị lớn hơn (merge)
          if (entry.value > localVal) {
            // Set counter to cloud value
            for (int i = localVal; i < entry.value; i++) {
              await _dbHelper.incrementCounter(userId, entry.key);
            }
          }
        }
        print('✅ Merged counters from Firebase: $cloudCounters');
      }

      await _saveLastSyncTime();
    } catch (e) {
      print('❌ Download error: $e');
      rethrow;
    }
  }

  // ============================================
  // ✅ SMART SYNC: Check if Web has newer data
  // ============================================

  /// Check if there are changes from Web that need to be downloaded.
  /// Returns a SmartSyncResult with whether sync is needed and info about the source.
  /// This costs only 1 Firebase Read (getUserDoc).
  Future<SmartSyncResult> checkForWebChanges(String userId) async {
    try {
      final serverDoc = await _firebaseService.getUserDoc(userId);
      if (serverDoc == null) {
        return SmartSyncResult(needsSync: false, reason: 'No server data');
      }

      final serverSource = serverDoc['lastChangeSource'] as String? ?? 'unknown';
      
      // Parse server timestamp
      DateTime? serverSyncedAt;
      final rawTs = serverDoc['lastSyncedAt'];
      if (rawTs is Timestamp) {
        serverSyncedAt = rawTs.toDate();
      } else if (rawTs is String) {
        serverSyncedAt = DateTime.tryParse(rawTs);
      }

      if (serverSyncedAt == null) {
        return SmartSyncResult(needsSync: false, reason: 'No server timestamp');
      }

      // Compare with local last sync time
      final localSyncTime = await getLastSyncTime();
      
      if (localSyncTime == null) {
        // Never synced before → need full download
        return SmartSyncResult(
          needsSync: true, 
          reason: 'First time sync',
          source: serverSource,
          serverTime: serverSyncedAt,
        );
      }

      // ✅ Only suggest sync if server is newer AND change came from web
      if (serverSyncedAt.isAfter(localSyncTime) && serverSource == 'web') {
        return SmartSyncResult(
          needsSync: true,
          reason: 'Web has newer data',
          source: serverSource,
          serverTime: serverSyncedAt,
        );
      }

      return SmartSyncResult(needsSync: false, reason: 'Local data is up to date');
    } catch (e) {
      print('❌ Smart sync check error: $e');
      return SmartSyncResult(needsSync: false, reason: 'Error: $e');
    }
  }

  // ============================================
  // ✅ SMART CONTENT SYNC (Phase 4)
  // ============================================

  /// Kiểm tra xem có bản cập nhật hay không và trả về quyết định UX (Patch, Minor, Major).
  /// Chỉ tốn rất ít Read (1 cho version, 2 cho count aggregation).
  Future<ContentUpdateInfo> checkContentUpdateNeeded({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Check throttle (30 mins)
      if (!force) {
        final lastCheckMillis = prefs.getInt(_lastContentCheckKey) ?? 0;
        final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
        if (now.difference(lastCheck).inMinutes < 30) {
          return ContentUpdateInfo(hasUpdate: false);
        }
      }

      // 1. Get system version
      final systemVer = await _firebaseService.getSystemContentVersion();
      if (systemVer == null) return ContentUpdateInfo(hasUpdate: false);

      final serverWordsVersion = systemVer['wordsVersion'] as int? ?? 1;
      final serverTopicsVersion = systemVer['topicsVersion'] as int? ?? 1;
      final serverSchemaVersion = systemVer['schemaVersion'] as int? ?? 1;
      final title = systemVer['latestUpdateTitle'] as String? ?? 'Cập nhật nội dung';

      int localWordsVersion = prefs.getInt(_localWordsVersionKey) ?? 1;
      int localTopicsVersion = prefs.getInt(_localTopicsVersionKey) ?? 1;
      int localSchemaVersion = prefs.getInt('local_schema_version') ?? 1;

      // 2. Check if we need schema migration
      if (serverSchemaVersion > localSchemaVersion) {
        return ContentUpdateInfo(
          hasUpdate: true,
          uxType: UpdateUXType.major,
          title: title,
          requiresSchemaMigration: true,
        );
      }

      // 3. Check for regular updates
      if (serverWordsVersion <= localWordsVersion && serverTopicsVersion <= localTopicsVersion) {
        await prefs.setInt(_lastContentCheckKey, now.millisecondsSinceEpoch);
        return ContentUpdateInfo(hasUpdate: false);
      }

      // 4. Get exact delta counts
      final counts = await _firebaseService.getDeltaCounts(localWordsVersion, localTopicsVersion);
      final deltaWords = counts['words'] ?? 0;
      final deltaTopics = counts['topics'] ?? 0;
      final totalChanges = deltaWords + deltaTopics;

      // 5. UX Escalation Logic
      UpdateUXType uxType = UpdateUXType.patch;
      if (totalChanges > 100 || deltaTopics > 5) {
        uxType = UpdateUXType.major;
      } else if (totalChanges >= 20) {
        uxType = UpdateUXType.minor;
      } else if (totalChanges > 0) {
        uxType = UpdateUXType.patch;
      }

      return ContentUpdateInfo(
        hasUpdate: totalChanges > 0,
        uxType: uxType,
        title: title,
        deltaWords: deltaWords,
        deltaTopics: deltaTopics,
      );

    } catch (e) {
      print('⚠️ Error in checkContentUpdateNeeded: $e');
      return ContentUpdateInfo(hasUpdate: false);
    }
  }

  // ============================================
  // CONTENT SYNC (Phase 3)
  // ============================================

  /// Download and sync content delta.
  /// LƯU Ý: Không dùng force parameter nữa, hãy dùng checkContentUpdateNeeded trước.
  Future<ContentSyncStatus> syncContentData({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMillis = prefs.getInt(_lastContentCheckKey) ?? 0;
      final now = DateTime.now();

      // 1. Throttle: Chỉ check mỗi 30 phút trừ khi force
      if (!force && lastCheckMillis > 0) {
        final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
        if (now.difference(lastCheck).inMinutes < 30) {
          return ContentSyncStatus.idle; // Chưa đến lúc
        }
      }

      print('🔄 Bắt đầu kiểm tra cập nhật nội dung (Content Sync)...');

      // 2. Fetch System Content Version
      final systemVer = await _firebaseService.getSystemContentVersion();
      if (systemVer == null) {
        return ContentSyncStatus.failed;
      }

      final serverWordsVersion = systemVer['wordsVersion'] as int? ?? 1;
      final serverTopicsVersion = systemVer['topicsVersion'] as int? ?? 1;

      int localWordsVersion = prefs.getInt(_localWordsVersionKey) ?? 1;
      int localTopicsVersion = prefs.getInt(_localTopicsVersionKey) ?? 1;

      bool hasUpdates = false;

      // 3. Sync Topics
      if (serverTopicsVersion > localTopicsVersion) {
        hasUpdates = true;
        final topicsDelta = await _firebaseService.getTopicsDelta(localTopicsVersion);
        for (final topic in topicsDelta) {
          await _dbHelper.upsertTopic(topic);
        }
        await prefs.setInt(_localTopicsVersionKey, serverTopicsVersion);
        print('✅ Đồng bộ xong ${topicsDelta.length} topics');
      }

      // 4. Sync Words
      if (serverWordsVersion > localWordsVersion) {
        hasUpdates = true;
        final wordsDelta = await _firebaseService.getWordsDelta(localWordsVersion);
        for (final word in wordsDelta) {
          await _dbHelper.upsertWord(word);
        }
        await prefs.setInt(_localWordsVersionKey, serverWordsVersion);
        print('✅ Đồng bộ xong ${wordsDelta.length} words');
      }

      // 5. HOTFIX: Tự động sửa lỗi dữ liệu is_learned
      // a) Đánh dấu is_learned = 0 cho từ nào CÓ tiến trình học (status > 0)
      // b) Reset is_learned = 1 cho từ nào KHÔNG có tiến trình hợp lệ
      try {
        final db = await _dbHelper.database;
        // Đánh dấu đã học cho từ có tiến trình
        await db.rawUpdate('''
          UPDATE words 
          SET is_learned = 0 
          WHERE is_learned = 1 
          AND id IN (
            SELECT word_id FROM user_word_progress WHERE status > 0
          )
        ''');
        // Reset từ bị đánh dấu sai (is_learned=0 nhưng không có tiến trình)
        await db.rawUpdate('''
          UPDATE words 
          SET is_learned = 1 
          WHERE is_learned = 0 
          AND id NOT IN (
            SELECT word_id FROM user_word_progress WHERE status > 0
          )
        ''');
      } catch (e) {
        print('⚠️ Hotfix is_learned error: $e');
      }

      // 6. Cập nhật lại số đếm sau khi sync hoặc hotfix
      if (hasUpdates || force) {
        await _dbHelper.updateTopicCounts();
      }

      // 7. Lưu lại schema version nếu có
      final serverSchemaVersion = systemVer['schemaVersion'] as int? ?? 1;
      await prefs.setInt('local_schema_version', serverSchemaVersion);

      // 8. Cập nhật mốc thời gian check
      await prefs.setInt(_lastContentCheckKey, now.millisecondsSinceEpoch);

      return hasUpdates ? ContentSyncStatus.success : ContentSyncStatus.latest;
    } catch (e) {
      print('❌ Lỗi đồng bộ nội dung: $e');
      return ContentSyncStatus.failed;
    }
  }

  // ============================================
  // SYNC ORCHESTRATION
  // ============================================

  /// ✅ Full sync: Upload + Download (with Delta support)
  Future<void> fullSync(String userId) async {
    if (userId.isEmpty) {
      print('⚠️ Invalid userId, skipping full sync');
      return;
    }

    try {
      print('🔄 Starting full sync for user: $userId');
      
      // ✅ 1. Content Sync (Topics/Words)
      await syncContentData(force: true);

      // ✅ 2. Progress Sync (Upload + Download)
      await downloadProgress(userId, deltaOnly: true);
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

  /// ✅ Auto sync: Smart check first, then full sync (prevent data overwrite)
  Future<void> autoSync(String userId) async {
    if (await needsSync()) {
      print('⏰ Auto sync triggered — running full sync');
      await fullSync(userId);
    } else {
      print('⏭️ Skipping auto sync (too soon)');
    }
  }

  /// Force sync (ignore time check) — still uses Delta download
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

/// Result of a Smart Sync check
class SmartSyncResult {
  final bool needsSync;
  final String reason;
  final String? source;
  final DateTime? serverTime;

  SmartSyncResult({
    required this.needsSync,
    required this.reason,
    this.source,
    this.serverTime,
  });

  @override
  String toString() => 'SmartSyncResult(needsSync=$needsSync, reason=$reason, source=$source)';
}
