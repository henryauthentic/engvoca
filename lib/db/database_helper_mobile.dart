import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';
import '../models/study_session.dart';
import '../models/practice_result.dart';
import '../services/srs_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _currentUserId;

  DatabaseHelper._init();

  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      print('🔄 Switching user from $_currentUserId to $userId');
      _currentUserId = userId;
      _database = null;
    }
  }

  String? get currentUserId => _currentUserId;

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    final dbName = _currentUserId != null 
        ? 'vocabulary_$_currentUserId.db'
        : 'vocabulary.db';
        
    _database = await _initDB(dbName);
    return _database!;
  }

  // ============================================
  // ASSET DB VERSION — Tăng số này mỗi khi cập nhật file
  // assets/database/EnglishMaster_cleaned.db
  // ============================================
  static const int _assetDbVersion = 4; // v4 = Thêm 5 chủ đề mới (Business, Tech, Academic, Travel, Health)

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final exists = await databaseExists(path);

    if (!exists) {
      // ── Lần đầu: copy toàn bộ DB từ assets ──
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join('assets', 'database', 'EnglishMaster_cleaned.db'));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        print('✅ Database copied for user $_currentUserId to: $path');
        
        final tempDb = await openDatabase(path);
        try {
          await tempDb.delete('users');
          print('🧹 Cleaned old users from template DB');
          
          final tables = await tempDb.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'"
          );
          final tableNames = tables.map((t) => t['name'] as String).toSet();
          
          for (final table in [
            'user_word_progress', 'study_sessions', 'practice_results',
            'study_time_history', 'user_badges', 'user_counters'
          ]) {
            if (tableNames.contains(table)) {
              await tempDb.delete(table);
              print('🧹 Cleaned $table from template DB');
            }
          }
        } finally {
          await tempDb.close();
        }
        // Ghi version marker
        await _writeAssetDbVersion(dbPath, filePath, _assetDbVersion);
      } catch (e) {
        print('❌ Error copying database from assets: $e');
        throw Exception('Failed to load database. Make sure EnglishMaster_cleaned.db is in assets/database/');
      }
    } else {
      print('📂 Database already exists for user $_currentUserId at: $path');
      
      // ── Kiểm tra có cần merge data mới không ──
      final currentVer = await _readAssetDbVersion(dbPath, filePath);
      if (currentVer < _assetDbVersion) {
        print('🔄 Asset DB updated (v$currentVer → v$_assetDbVersion). Merging new data...');
        await _mergeAssetData(path);
        await _writeAssetDbVersion(dbPath, filePath, _assetDbVersion);
        print('✅ Merge complete');
      }
    }

    final db = await openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        print('📂 Database opened successfully for user $_currentUserId');
        await _verifyTables(db);
        await _migrateTopicsTable(db);  // migrate parent_id
        await _migrateUsersTable(db);
        await _migrateWordProgressTable(db);
        await _createLocalTables(db);
      },
    );
    
    return db;
  }

  // ── Version marker helpers ──────────────────────
  Future<int> _readAssetDbVersion(String dbPath, String filePath) async {
    try {
      final versionFile = File(join(dbPath, '${filePath}.version'));
      if (await versionFile.exists()) {
        return int.tryParse(await versionFile.readAsString()) ?? 1;
      }
    } catch (_) {}
    return 1; // DB cũ chưa có marker → v1
  }

  Future<void> _writeAssetDbVersion(String dbPath, String filePath, int version) async {
    try {
      final versionFile = File(join(dbPath, '${filePath}.version'));
      await versionFile.writeAsString(version.toString());
    } catch (e) {
      print('⚠️ Could not write DB version marker: $e');
    }
  }

  // ── Merge data mới từ asset DB vào DB đang dùng ──
  // Giữ nguyên: users, user_word_progress, study_sessions, badges...
  // Cập nhật: topics (thêm mới + update), words (thêm mới + update)
  Future<void> _mergeAssetData(String userDbPath) async {
    try {
      // 1) Load asset DB vào file tạm
      final dbPath = await getDatabasesPath();
      final tempPath = join(dbPath, '_temp_asset_merge.db');
      ByteData data = await rootBundle.load(join('assets', 'database', 'EnglishMaster_cleaned.db'));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(tempPath).writeAsBytes(bytes, flush: true);

      // 2) Mở cả 2 DB
      final userDb = await openDatabase(userDbPath);
      final assetDb = await openDatabase(tempPath);

      try {
        // 3) Migrate cột parent_id nếu chưa có
        final tableInfo = await userDb.rawQuery('PRAGMA table_info(topics)');
        final columns = tableInfo.map((c) => c['name'] as String).toList();
        if (!columns.contains('parent_id')) {
          await userDb.execute('ALTER TABLE topics ADD COLUMN parent_id TEXT');
          print('  ➕ Added parent_id column');
        }

        // 4) Merge topics — INSERT OR REPLACE
        final assetTopics = await assetDb.query('topics');
        print('  📥 Merging ${assetTopics.length} topics...');
        for (final topic in assetTopics) {
          await userDb.insert('topics', topic, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // 5) Merge words — INSERT OR REPLACE (giữ is_learned, is_favorite của user)
        final assetWords = await assetDb.query('words');
        print('  📥 Merging ${assetWords.length} words...');
        for (final word in assetWords) {
          final wordId = word['id'] as String;
          // Kiểm tra user đã có word này chưa
          final existing = await userDb.query('words', where: 'id = ?', whereArgs: [wordId]);
          if (existing.isEmpty) {
            // Từ mới hoàn toàn → insert
            await userDb.insert('words', word);
          } else {
            // Từ đã có → chỉ update nội dung, GIỮ NGUYÊN is_learned, is_favorite
            final oldWord = existing.first;
            final merged = Map<String, dynamic>.from(word);
            merged['is_learned'] = oldWord['is_learned'];     // giữ trạng thái đã học
            merged['is_favorite'] = oldWord['is_favorite'];   // giữ yêu thích
            merged['learned_at'] = oldWord['learned_at'];     // giữ ngày học
            await userDb.update('words', merged, where: 'id = ?', whereArgs: [wordId]);
          }
        }

        // 6) Xóa topics/words cũ không còn trong asset DB mới
        final assetTopicIds = assetTopics.map((t) => t['id'] as String).toSet();
        final userTopics = await userDb.query('topics', columns: ['id']);
        int removedTopics = 0;
        for (final ut in userTopics) {
          if (!assetTopicIds.contains(ut['id'])) {
            await userDb.delete('topics', where: 'id = ?', whereArgs: [ut['id']]);
            removedTopics++;
          }
        }
        if (removedTopics > 0) print('  🗑️ Removed $removedTopics obsolete topics');

        // 7) Xóa words cũ
        final assetWordIds = assetWords.map((w) => w['id'] as String).toSet();
        final userWords = await userDb.query('words', columns: ['id']);
        int removedWords = 0;
        for (final uw in userWords) {
          if (!assetWordIds.contains(uw['id'])) {
            await userDb.delete('words', where: 'id = ?', whereArgs: [uw['id']]);
            removedWords++;
          }
        }
        if (removedWords > 0) print('  🗑️ Removed $removedWords obsolete words');

        print('  ✅ Data merge successful');
      } finally {
        await assetDb.close();
        await userDb.close();
        // Dọn file tạm
        try { await File(tempPath).delete(); } catch (_) {}
      }
    } catch (e) {
      print('❌ Error merging asset data: $e');
      // Không rethrow — app vẫn mở được với data cũ
    }
  }

  // ============================================
  // MIGRATIONS
  // ============================================

  /// Thêm cột parent_id vào bảng topics nếu chưa có
  Future<void> _migrateTopicsTable(Database db) async {
    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info(topics)');
      final columns = tableInfo.map((c) => c['name'] as String).toList();

      if (!columns.contains('parent_id')) {
        print('➕ Adding parent_id column to topics...');
        await db.execute('ALTER TABLE topics ADD COLUMN parent_id TEXT');
        print('✅ parent_id column added to topics');
      }
      if (!columns.contains('image_url')) {
        print('➕ Adding image_url column to topics...');
        await db.execute('ALTER TABLE topics ADD COLUMN image_url TEXT');
        print('✅ image_url column added to topics');
      }
    } catch (e) {
      print('❌ Error migrating topics table: $e');
      // Không rethrow – tiếp tục dù migrate lỗi
    }
  }

  Future<void> _migrateUsersTable(Database db) async {
    try {
      print('🔄 Checking users table schema...');
      
      final tableInfo = await db.rawQuery('PRAGMA table_info(users)');
      final columns = tableInfo.map((c) => c['name'] as String).toList();
      
      print('📊 Current users columns: $columns');
      
      if (!columns.contains('last_active')) {
        await db.execute('ALTER TABLE users ADD COLUMN last_active TEXT');
      }
      if (!columns.contains('avatar_url')) {
        await db.execute('ALTER TABLE users ADD COLUMN avatar_url TEXT');
      }
      if (!columns.contains('level')) {
        await db.execute('ALTER TABLE users ADD COLUMN level INTEGER DEFAULT 1');
      }
      if (!columns.contains('total_points')) {
        await db.execute('ALTER TABLE users ADD COLUMN total_points INTEGER DEFAULT 0');
      }
      if (!columns.contains('words_learned')) {
        await db.execute('ALTER TABLE users ADD COLUMN words_learned INTEGER DEFAULT 0');
      }
      if (!columns.contains('streak_days')) {
        await db.execute('ALTER TABLE users ADD COLUMN streak_days INTEGER DEFAULT 0');
      }
      if (!columns.contains('learning_level')) {
        await db.execute("ALTER TABLE users ADD COLUMN learning_level TEXT DEFAULT 'beginner'");
      }
      if (!columns.contains('selected_topics')) {
        await db.execute("ALTER TABLE users ADD COLUMN selected_topics TEXT DEFAULT '[]'");
      }
      if (!columns.contains('daily_goal')) {
        await db.execute('ALTER TABLE users ADD COLUMN daily_goal INTEGER DEFAULT 15');
      }
      if (!columns.contains('is_onboarded')) {
        await db.execute('ALTER TABLE users ADD COLUMN is_onboarded INTEGER DEFAULT 0');
      }
      if (!columns.contains('today_study_time')) {
        await db.execute('ALTER TABLE users ADD COLUMN today_study_time INTEGER DEFAULT 0');
      }
      if (!columns.contains('last_study_date')) {
        await db.execute('ALTER TABLE users ADD COLUMN last_study_date TEXT');
      }
      if (!columns.contains('xp_breakdown')) {
        await db.execute("ALTER TABLE users ADD COLUMN xp_breakdown TEXT DEFAULT '{}'");
      }
      if (!columns.contains('used_grace_period')) {
        await db.execute('ALTER TABLE users ADD COLUMN used_grace_period INTEGER DEFAULT 0');
      }
      if (!columns.contains('longest_streak')) {
        await db.execute('ALTER TABLE users ADD COLUMN longest_streak INTEGER DEFAULT 0');
      }
      
      print('✅ Users table migration completed');
    } catch (e) {
      print('❌ Error migrating users table: $e');
    }
  }

  Future<void> _migrateWordProgressTable(Database db) async {
    try {
      print('🔄 Checking user_word_progress table schema...');
      
      final tableInfo = await db.rawQuery('PRAGMA table_info(user_word_progress)');
      final columns = tableInfo.map((c) => c['name'] as String).toList();
      
      if (!columns.contains('updated_at')) {
        await db.execute('ALTER TABLE user_word_progress ADD COLUMN updated_at INTEGER');
      }
      if (!columns.contains('synced_at')) {
        await db.execute('ALTER TABLE user_word_progress ADD COLUMN synced_at INTEGER');
      }
      
      // Adaptive Learning (Difficult Words System)
      if (!columns.contains('is_difficult')) {
        await db.execute('ALTER TABLE user_word_progress ADD COLUMN is_difficult INTEGER DEFAULT 0');
      }
      if (!columns.contains('wrong_count')) {
        await db.execute('ALTER TABLE user_word_progress ADD COLUMN wrong_count INTEGER DEFAULT 0');
      }
      if (!columns.contains('last_seen_at')) {
        await db.execute('ALTER TABLE user_word_progress ADD COLUMN last_seen_at TEXT');
      }
      
      print('✅ user_word_progress table migration completed');
    } catch (e) {
      print('❌ Error migrating user_word_progress table: $e');
    }
  }

  Future<void> _createLocalTables(Database db) async {
    try {
      print('🔄 Creating local tracking tables if not exists...');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_word_progress (
          word_id TEXT PRIMARY KEY,
          status INTEGER DEFAULT 0,
          repetition INTEGER DEFAULT 0,
          easiness_factor REAL DEFAULT 2.5,
          interval_days INTEGER DEFAULT 0,
          next_review_date TEXT,
          last_review_date TEXT,
          review_count INTEGER DEFAULT 0,
          lapses INTEGER DEFAULT 0,
          first_learned_date TEXT,
          updated_at INTEGER,
          synced_at INTEGER,
          is_difficult INTEGER DEFAULT 0,
          wrong_count INTEGER DEFAULT 0,
          last_seen_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_sessions (
          session_id TEXT PRIMARY KEY,
          date TEXT,
          xp_earned INTEGER DEFAULT 0,
          words_reviewed INTEGER DEFAULT 0,
          accuracy_rate REAL DEFAULT 0.0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS practice_results (
          id TEXT PRIMARY KEY,
          mode TEXT NOT NULL DEFAULT 'quiz',
          total_questions INTEGER DEFAULT 0,
          correct_count INTEGER DEFAULT 0,
          wrong_count INTEGER DEFAULT 0,
          accuracy REAL DEFAULT 0.0,
          xp_earned INTEGER DEFAULT 0,
          duration_seconds INTEGER DEFAULT 0,
          topic_ids TEXT DEFAULT '[]',
          topic_names TEXT DEFAULT '[]',
          created_at TEXT NOT NULL,
          details TEXT DEFAULT '[]'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_time_history (
          date TEXT PRIMARY KEY,
          study_time_seconds INTEGER DEFAULT 0,
          goal_minutes INTEGER DEFAULT 15,
          goal_reached INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_badges (
          user_id TEXT NOT NULL,
          badge_id TEXT NOT NULL,
          unlocked_at TEXT NOT NULL,
          PRIMARY KEY (user_id, badge_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_counters (
          user_id TEXT NOT NULL,
          counter_key TEXT NOT NULL,
          counter_value INTEGER DEFAULT 0,
          PRIMARY KEY (user_id, counter_key)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS dictionary_cache (
          word TEXT PRIMARY KEY,
          data TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      print('✅ Local tracking tables created successfully');
      // Migration: Add first_learned_date column if missing
      try {
        final progressCols = await db.rawQuery('PRAGMA table_info(user_word_progress)');
        final progressColNames = progressCols.map((c) => c['name'] as String).toList();
        if (!progressColNames.contains('first_learned_date')) {
          await db.execute('ALTER TABLE user_word_progress ADD COLUMN first_learned_date TEXT');
          print('✅ Added first_learned_date column to user_word_progress');
        }
      } catch (e) {
        print('⚠️ Migration first_learned_date: $e');
      }
    } catch (e) {
      print('❌ Error creating local tracking tables: $e');
    }
  }

  Future<void> _verifyTables(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'"
    );
    
    print('📋 Available tables: ${tables.map((t) => t['name']).toList()}');
    
    final topicsExists = tables.any((t) => t['name'] == 'topics');
    if (!topicsExists) {
      print('❌ Topics table not found!');
      throw Exception('Database is missing topics table');
    }
    
    final wordsExists = tables.any((t) => t['name'] == 'words');
    if (!wordsExists) {
      print('❌ Words table not found!');
      throw Exception('Database is missing words table');
    }
    
    final topicsInfo = await db.rawQuery('PRAGMA table_info(topics)');
    final topicsColumns = topicsInfo.map((c) => c['name'] as String).toList();
    print('📊 Topics columns: $topicsColumns');
    
    if (topicsColumns.contains('total_words')) {
      _totalWordsColumnName = 'total_words';
    } else if (topicsColumns.contains('totar_words')) {
      _totalWordsColumnName = 'totar_words';
    }
    
    if (topicsColumns.contains('learned_words')) {
      _learnedWordsColumnName = 'learned_words';
    }
    
    print('✅ Total words column: $_totalWordsColumnName');
    print('✅ Learned words column: $_learnedWordsColumnName');
    
    final wordsInfo = await db.rawQuery('PRAGMA table_info(words)');
    final wordsColumns = wordsInfo.map((c) => c['name'] as String).toList();
    print('📊 Words columns: $wordsColumns');
    
    if (wordsColumns.contains('topic_id')) {
      _topicIdColumnName = 'topic_id';
    } else if (wordsColumns.contains('a_topic_id')) {
      _topicIdColumnName = 'a_topic_id';
    } else if (wordsColumns.contains('topicId')) {
      _topicIdColumnName = 'topicId';
    } else {
      print('⚠️  Warning: No topic_id column found in words table!');
    }
    
    print('✅ Using column name for topic ID: $_topicIdColumnName');
    
    final topicsCount = await db.rawQuery('SELECT COUNT(*) as count FROM topics');
    final wordsCount = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    
    print('📈 Topics count: ${topicsCount.first['count']}');
    print('📈 Words count: ${wordsCount.first['count']}');
    
    final sampleTopic = await db.rawQuery('SELECT * FROM topics LIMIT 1');
    if (sampleTopic.isNotEmpty) {
      print('🔍 Sample topic data: ${sampleTopic.first}');
    }
    
    final sampleWord = await db.rawQuery('SELECT * FROM words LIMIT 1');
    if (sampleWord.isNotEmpty) {
      print('🔍 Sample word data: ${sampleWord.first}');
    }
  }

  String _topicIdColumnName = 'topic_id';
  String _totalWordsColumnName = 'total_words';
  String _learnedWordsColumnName = 'learned_words';
  
  String get topicIdColumn => _topicIdColumnName;

  // ============================================
  // USER MANAGEMENT IN SQLITE
  // ============================================

  Future<void> upsertUser({
    required String id,
    required String name,
    required String email,
    String? avatarUrl,
    int? level,
    int? totalPoints,
    int? wordsLearned,
    int? streakDays,
    int? longestStreak,
    bool? usedGracePeriod,
    DateTime? lastLoginDate,
    String? learningLevel,
    String? selectedTopics,
    int? dailyGoal,
    bool? isOnboarded,
    int? todayStudyTime,
    String? lastStudyDate,
    Map<String, int>? xpBreakdown,
  }) async {
    final db = await database;
    
    try {
      final existingById = await db.query('users', where: 'id = ?', whereArgs: [id]);
      final existingByEmail = await db.query('users', where: 'email = ?', whereArgs: [email]);
      final existing = existingById.isNotEmpty ? existingById : existingByEmail;
      int? existingCreatedDate;
      int? existingLastLoginDate;
      String? existingLearningLevel;
      String? existingSelectedTopics;
      int? existingDailyGoal;
      int? existingIsOnboarded;
      int? existingTodayStudyTime;
      String? existingLastStudyDate;
      int? existingLevel;
      int? existingTotalPoints;
      int? existingWordsLearned;
      int? existingStreakDays;
      int? existingLongestStreak;
      int? existingUsedGracePeriod;
      String? existingXpBreakdown;
      
      if (existing.isNotEmpty) {
        existingCreatedDate = existing.first['created_date'] as int?;
        existingLastLoginDate = existing.first['last_login_date'] as int?;
        existingLearningLevel = existing.first['learning_level'] as String?;
        existingSelectedTopics = existing.first['selected_topics'] as String?;
        existingDailyGoal = existing.first['daily_goal'] as int?;
        existingIsOnboarded = existing.first['is_onboarded'] as int?;
        existingTodayStudyTime = existing.first['today_study_time'] as int?;
        existingLastStudyDate = existing.first['last_study_date'] as String?;
        existingLevel = existing.first['level'] as int?;
        existingTotalPoints = existing.first['total_points'] as int?;
        existingWordsLearned = existing.first['words_learned'] as int?;
        existingStreakDays = existing.first['streak_days'] as int?;
        existingLongestStreak = existing.first['longest_streak'] as int?;
        existingUsedGracePeriod = existing.first['used_grace_period'] as int?;
        existingXpBreakdown = existing.first['xp_breakdown'] as String?;
      }
      
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
      await db.delete('users', where: 'email = ?', whereArgs: [email]);
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final loginDateMs = lastLoginDate?.millisecondsSinceEpoch ?? existingLastLoginDate ?? now;
      final createdDateMs = existingCreatedDate ?? now;
      
      await db.insert(
        'users',
        {
          'id': id,
          'name': name,
          'email': email,
          'password': null,
          'avatar_url': avatarUrl,
          'level': level ?? existingLevel ?? 1,
          'total_points': totalPoints ?? existingTotalPoints ?? 0,
          'words_learned': wordsLearned ?? existingWordsLearned ?? 0,
          'streak_days': streakDays ?? existingStreakDays ?? 0,
          'last_active': DateTime.now().toIso8601String(),
          'created_date': createdDateMs,
          'last_login_date': loginDateMs,
          'learning_level': learningLevel ?? existingLearningLevel ?? 'beginner',
          'selected_topics': selectedTopics ?? existingSelectedTopics ?? '[]',
          'daily_goal': dailyGoal ?? existingDailyGoal ?? 15,
          'is_onboarded': isOnboarded == true ? 1 : (existingIsOnboarded ?? 0),
          'today_study_time': todayStudyTime ?? existingTodayStudyTime ?? 0,
          'last_study_date': lastStudyDate ?? existingLastStudyDate,
          'longest_streak': longestStreak ?? existingLongestStreak ?? 0,
          'used_grace_period': usedGracePeriod == true ? 1 : (existingUsedGracePeriod ?? 0),
          'xp_breakdown': xpBreakdown != null ? jsonEncode(xpBreakdown) : existingXpBreakdown,
        },
      );
      
      print('✅ Upserted user $name ($id), streak=${streakDays ?? existingStreakDays ?? 0}, longest=${longestStreak ?? existingLongestStreak ?? 0}, onboarded=${isOnboarded ?? existingIsOnboarded}');
    } catch (e) {
      print('❌ Error upserting user: $e');
      rethrow;
    }
  }

  Future<void> updateStudyTime(String userId, int studyTimeSeconds, String dateKey) async {
    final db = await database;
    try {
      await db.update(
        'users',
        {'today_study_time': studyTimeSeconds, 'last_study_date': dateKey},
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('❌ Error updating study time: $e');
    }
  }

  Future<void> updateOnboardingData({
    required String userId,
    required String learningLevel,
    required String selectedTopicsJson,
    required int dailyGoal,
  }) async {
    final db = await database;
    try {
      await db.update(
        'users',
        {
          'learning_level': learningLevel,
          'selected_topics': selectedTopicsJson,
          'daily_goal': dailyGoal,
          'is_onboarded': 1,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      print('✅ Onboarding data saved for user $userId');
    } catch (e) {
      print('❌ Error saving onboarding data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLocalUser(String userId) async {
    final db = await database;
    try {
      final result = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (result.isEmpty) return null;
      print('📖 Retrieved user from SQLite: ${result.first}');
      return result.first;
    } catch (e) {
      print('❌ Error getting local user: $e');
      return null;
    }
  }

  Future<void> deleteLocalUser(String userId) async {
    final db = await database;
    try {
      await db.delete('users', where: 'id = ?', whereArgs: [userId]);
      print('🗑️ Deleted user $userId from SQLite');
    } catch (e) {
      print('❌ Error deleting local user: $e');
    }
  }

  // ============================================
  // TOPIC CRUD – hỗ trợ 2 cấp (parent / child)
  // ============================================

  /// Cập nhật ảnh cho Topic
  Future<void> updateTopicImage(String topicId, String imageUrl) async {
    final db = await database;
    try {
      await db.update(
        'topics',
        {'image_url': imageUrl},
        where: 'id = ?',
        whereArgs: [topicId],
      );
    } catch (e) {
      print('❌ Error updating topic image: $e');
    }
  }

  /// Lấy toàn bộ topic (dùng nội bộ / debug)
  Future<List<Topic>> getTopics() async {
    final db = await database;
    try {
      final result = await db.query('topics', orderBy: 'order_index, name');
      print('📚 Loaded ${result.length} topics from database for user $_currentUserId');
      return result.map((json) => Topic.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error loading topics: $e');
      rethrow;
    }
  }

  /// Lấy các topic CHA (Basic, IELTS, B1, B2, C1, C2, Lớp 6–12, ...) — dùng cho HomeScreen
  Future<List<Topic>> getParentTopics() async {
    final db = await database;
    try {
      final result = await db.query(
        'topics',
        where: 'parent_id IS NULL',
        orderBy: 'order_index',
      );
      print('📚 Loaded ${result.length} parent topics');
      return result.map((json) => Topic.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error loading parent topics: $e');
      rethrow;
    }
  }

  /// Lấy topic CON theo topic cha — dùng cho SubTopicScreen
  Future<List<Topic>> getChildTopics(String parentId) async {
    final db = await database;
    try {
      final result = await db.query(
        'topics',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'order_index, name',
      );
      print('📚 Loaded ${result.length} child topics for parent $parentId');
      return result.map((json) => Topic.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error loading child topics: $e');
      rethrow;
    }
  }

  /// Kiểm tra topic cha có topic con không
  Future<bool> hasChildren(String topicId) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM topics WHERE parent_id = ?',
        [topicId],
      );
      return (Sqflite.firstIntValue(result) ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  Future<Topic> getTopic(String id) async {
    final db = await database;
    final maps = await db.query('topics', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) throw Exception('Topic not found');
    return Topic.fromMap(maps.first);
  }

  Future<int> insertTopic(Topic topic) async {
    final db = await database;
    await db.insert('topics', topic.toMap());
    return 1;
  }

  Future<int> updateTopic(Topic topic) async {
    final db = await database;
    return await db.update('topics', topic.toMap(), where: 'id = ?', whereArgs: [topic.id]);
  }

  /// Xóa topic (xóa con trước nếu là topic cha)
  Future<int> deleteTopic(String id) async {
    final db = await database;
    await db.delete('topics', where: 'parent_id = ?', whereArgs: [id]);
    return await db.delete('topics', where: 'id = ?', whereArgs: [id]);
  }

  /// Upsert Topic (Dynamic Content Sync)
  Future<void> upsertTopic(Map<String, dynamic> data) async {
    final db = await database;
    final topicId = data['id'] as String;
    
    if (data['deleted'] == true || data['status'] == 'archived') {
      await deleteTopic(topicId);
      return;
    }

    // Filter out Firestore metadata fields not in SQLite
    final Map<String, dynamic> topicData = {
      'id': topicId,
      'name': data['name'],
      'description': data['description'],
      'image_url': data['image_url'],
      'parent_id': data['parent_id']?.toString().isEmpty ?? true ? null : data['parent_id'],
      'is_unlocked': data['is_unlocked'] ?? 1,
      'order_index': data['order_index'] ?? 0,
      'total_words': data['total_words'] ?? 0,
    };

    final existing = await db.query('topics', where: 'id = ?', whereArgs: [topicId]);
    if (existing.isEmpty) {
      await db.insert('topics', topicData);
    } else {
      await db.update('topics', topicData, where: 'id = ?', whereArgs: [topicId]);
    }
  }

  // ============================================
  // WORD CRUD
  // ============================================

  /// Upsert Word (Dynamic Content Sync)
  Future<void> upsertWord(Map<String, dynamic> data) async {
    final db = await database;
    final wordId = data['id'] as String;
    
    if (data['deleted'] == true) {
      await db.delete('words', where: 'id = ?', whereArgs: [wordId]);
      return;
    }

    final Map<String, dynamic> wordData = {
      'id': wordId,
      'word': data['word'],
      'meaning': data['meaning'],
      'pronunciation': data['pronunciation'],
      'example': data['example'],
      'pos': data['pos'],
      'difficulty_level': data['difficulty_level'] ?? 1,
      'audio_url': data['audio_url'],
      'image_url': data['image_url'],
    };
    
    // Assign topic_id safely based on DB structure
    wordData[_topicIdColumnName] = data['topic_id'] ?? data['a_topic_id'];

    final existing = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    if (existing.isEmpty) {
      wordData['is_learned'] = 1; // 1 means NOT learned in SQLite
      wordData['is_favorite'] = 0;
      await db.insert('words', wordData);
    } else {
      // Giữ nguyên trạng thái học tập của User
      wordData['is_learned'] = existing.first['is_learned'];
      wordData['is_favorite'] = existing.first['is_favorite'];
      wordData['learned_at'] = existing.first['learned_at'];
      await db.update('words', wordData, where: 'id = ?', whereArgs: [wordId]);
    }
  }

  Future<List<Word>> getWordsByTopic(String topicId) async {
    final db = await database;
    try {
      final result = await db.query(
        'words', 
        where: '$_topicIdColumnName = ?',
        whereArgs: [topicId],
        orderBy: 'word'
      );
      print('📖 Loaded ${result.length} words for topic $topicId (user: $_currentUserId)');
      return result.map((json) => Word.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error loading words for topic $topicId: $e');
      rethrow;
    }
  }

  /// Lấy TẤT CẢ từ vựng thuộc topic cha (gộp các topic con lại)
  Future<List<Word>> getWordsByParentTopic(String parentId) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        '''SELECT w.* FROM words w
           JOIN topics t ON w.$_topicIdColumnName = t.id
           WHERE t.parent_id = ?
           ORDER BY w.word''',
        [parentId],
      );
      print('📖 Loaded ${result.length} words for parent topic $parentId');
      return result.map((json) => Word.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error loading words for parent topic $parentId: $e');
      rethrow;
    }
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    try {
      final result = await db.query('words');
      return result.map((json) => Word.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error loading all words: $e');
      return [];
    }
  }

  Future<Word> getWord(String id) async {
    final db = await database;
    final maps = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) throw Exception('Word not found');
    return Word.fromMap(maps.first);
  }

  Future<int> insertWord(Word word) async {
    final db = await database;
    await db.insert('words', word.toMap());
    return 1;
  }

  Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<int> deleteWord(String id) async {
    final db = await database;
    return await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markWordAsLearned(String wordId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'words',
      {'is_learned': 0, 'learned_at': now},
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<List<Word>> getLearnedWords() async {
    final db = await database;
    final result = await db.query('words', where: 'is_learned = ?', whereArgs: [0]);
    print('📚 Found ${result.length} learned words for user $_currentUserId');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getUnlearnedWords() async {
    final db = await database;
    final result = await db.query('words', where: 'is_learned = ?', whereArgs: [1]);
    print('📚 Found ${result.length} unlearned words for user $_currentUserId');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getLearnedWordsByTopic(String topicId) async {
    final db = await database;
    final result = await db.query(
      'words',
      where: '$_topicIdColumnName = ? AND is_learned = ?',
      whereArgs: [topicId, 0],
      orderBy: 'learned_at DESC',
    );
    print('📖 Found ${result.length} learned words for topic $topicId (user: $_currentUserId)');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<int> countLearnedWordsByTopic(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE $_topicIdColumnName = ? AND is_learned = 0',
      [topicId]
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    print('📊 Topic $topicId has $count learned words (user: $_currentUserId)');
    return count;
  }

  Future<List<Word>> getRandomWords(int count, {String? topicId}) async {
    final db = await database;
    String query = 'SELECT * FROM words';
    List<dynamic> args = [];
    
    if (topicId != null) {
      query += ' WHERE $_topicIdColumnName = ?';
      args.add(topicId);
    }
    
    query += ' ORDER BY RANDOM() LIMIT ?';
    args.add(count);
    
    final result = await db.rawQuery(query, args);
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<String>> getTopicIdsFromWords() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT $_topicIdColumnName FROM words ORDER BY $_topicIdColumnName'
    );
    return result.map((row) => row[_topicIdColumnName] as String).toList();
  }

  Future<int> countWordsByTopic(String topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE $_topicIdColumnName = ?',
      [topicId]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Cập nhật số từ cho cả topic con lẫn topic cha (2 cấp)
  Future<void> updateTopicCounts() async {
    final db = await database;
    try {
      print('🔄 Updating topic counts (2-level) for user $_currentUserId...');

      // 1. Cập nhật topic CON – đếm từ vựng trực tiếp
      final childTopics = await db.query(
        'topics',
        where: 'parent_id IS NOT NULL',
      );

      for (var topicMap in childTopics) {
        final topicId = topicMap['id'] as String;

        final totalResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM words WHERE $_topicIdColumnName = ?',
          [topicId],
        );
        final totalWords = Sqflite.firstIntValue(totalResult) ?? 0;

        final learnedResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM words WHERE $_topicIdColumnName = ? AND is_learned = 0',
          [topicId],
        );
        final learnedWords = Sqflite.firstIntValue(learnedResult) ?? 0;

        await db.update(
          'topics',
          {_totalWordsColumnName: totalWords, _learnedWordsColumnName: learnedWords},
          where: 'id = ?',
          whereArgs: [topicId],
        );
      }

      // 2. Cập nhật topic CHA (tổng của các topic con + từ trực tiếp của nó)
      final parentTopics = await db.query(
        'topics',
        where: 'parent_id IS NULL',
      );

      for (var topicMap in parentTopics) {
        final topicId = topicMap['id'] as String;

        final totalResult = await db.rawQuery(
          '''SELECT COUNT(*) as count FROM words w
             JOIN topics t ON w.$_topicIdColumnName = t.id
             WHERE t.parent_id = ? OR t.id = ?''',
          [topicId, topicId],
        );
        final totalWords = Sqflite.firstIntValue(totalResult) ?? 0;

        final learnedResult = await db.rawQuery(
          '''SELECT COUNT(*) as count FROM words w
             JOIN topics t ON w.$_topicIdColumnName = t.id
             WHERE (t.parent_id = ? OR t.id = ?) AND w.is_learned = 0''',
          [topicId, topicId],
        );
        final learnedWords = Sqflite.firstIntValue(learnedResult) ?? 0;

        await db.update(
          'topics',
          {_totalWordsColumnName: totalWords, _learnedWordsColumnName: learnedWords},
          where: 'id = ?',
          whereArgs: [topicId],
        );

        print('  ✅ Parent "$topicId": $learnedWords / $totalWords learned');
      }

      print('✅ Successfully updated counts (2-level) for user $_currentUserId');
    } catch (e) {
      print('❌ Error updating topic counts: $e');
      rethrow;
    }
  }

  // ============================================
  // SPACED REPETITION (SM-2) CRUD
  // ============================================

  Future<UserWordProgress?> getWordProgress(String wordId) async {
    final db = await database;
    try {
      final result = await db.query(
        'user_word_progress',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      if (result.isNotEmpty) return UserWordProgress.fromMap(result.first);
      return null;
    } catch (e) {
      print('❌ Error getting word progress: $e');
      return null;
    }
  }

  Future<void> upsertWordProgress(UserWordProgress progress) async {
    final db = await database;
    try {
      final existing = await db.query(
        'user_word_progress',
        where: 'word_id = ?',
        whereArgs: [progress.wordId],
      );

      final map = progress.toMap();

      // ✅ Normalize ALL date fields to 10-char (YYYY-MM-DD) format for SQLite query compatibility
      if (map['last_review_date'] != null && (map['last_review_date'] as String).length > 10) {
        map['last_review_date'] = (map['last_review_date'] as String).substring(0, 10);
      }
      if (map['next_review_date'] != null && (map['next_review_date'] as String).length > 10) {
        map['next_review_date'] = (map['next_review_date'] as String).substring(0, 10);
      }

      // Set first_learned_date when word is learned for the first time
      if (existing.isEmpty) {
        if (progress.status > 0) {
          map['first_learned_date'] = progress.firstLearnedDate?.toIso8601String().substring(0, 10) ?? DateTime.now().toIso8601String().substring(0, 10);
        }
      } else {
        final oldStatus = existing.first['status'] as int? ?? 0;
        final existingFirstDate = existing.first['first_learned_date'] as String?;
        
        if (oldStatus == 0 && progress.status > 0 && existingFirstDate == null) {
          map['first_learned_date'] = progress.firstLearnedDate?.toIso8601String().substring(0, 10) ?? DateTime.now().toIso8601String().substring(0, 10);
        } else if (existingFirstDate != null) {
          // If the cloud explicitly sent a different valid date, keep the oldest one, otherwise use existing
          final cloudDateStr = progress.firstLearnedDate?.toIso8601String().substring(0, 10);
          if (cloudDateStr != null && cloudDateStr.compareTo(existingFirstDate) < 0) {
            map['first_learned_date'] = cloudDateStr;
          } else {
            map['first_learned_date'] = existingFirstDate;
          }
        }
      }

      // Ensure updated_at is set for sync logic
      map['updated_at'] ??= DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        'user_word_progress',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ✅ Auto-sync is_learned flag in words table
      if (progress.status > 0) {
        await db.update(
          'words',
          {'is_learned': 0, 'learned_at': DateTime.now().toIso8601String()},
          where: 'id = ? AND is_learned = 1',
          whereArgs: [progress.wordId],
        );
      }
    } catch (e) {
      print('❌ Error upserting word progress: $e');
    }
  }

  Future<void> upsertCustomWord({
    required String id,
    required String word,
    required String meaning,
    required String pronunciation,
  }) async {
    final db = await database;
    try {
      final existing = await db.query('words', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('words', {
          'id': id,
          'word': word,
          'pronunciation': pronunciation,
          'meaning': meaning,
          'example': '',
          _topicIdColumnName: 'dictionary_saved',
          'is_favorite': 0,
          'is_learned': 0,
          'difficulty_level': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ Inserted custom word from Web into SQLite: \$word');
      }
    } catch (e) {
      print('❌ Error upserting custom word: \$e');
    }
  }

  Future<List<UserWordProgress>> getWordsToReview(DateTime targetDate) async {
    final db = await database;
    try {
      final result = await db.query(
        'user_word_progress',
        where: 'next_review_date <= ? AND status > 0',
        whereArgs: [targetDate.toIso8601String()],
      );
      return result.map((m) => UserWordProgress.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting words to review: $e');
      return [];
    }
  }

  Future<int> countDueWords(DateTime targetDate) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_word_progress WHERE next_review_date <= ? AND status > 0',
        [targetDate.toIso8601String()]
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Word>> getGlobalDueWords(DateTime targetDate, int limit) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        '''SELECT w.* FROM words w
           JOIN user_word_progress p ON w.id = p.word_id
           WHERE p.next_review_date <= ? AND p.status > 0
           ORDER BY RANDOM() LIMIT ?''',
        [targetDate.toIso8601String(), limit]
      );
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting global due words: $e');
      return [];
    }
  }

  Future<int> countNewWords() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM words WHERE id NOT IN (SELECT word_id FROM user_word_progress)'
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Tính tỷ lệ nhớ tổng thể: (tổng review - tổng lapses) / tổng review
  /// Dữ liệu lấy từ cột review_count và lapses trong user_word_progress
  Future<double> getGlobalMemoryAccuracy() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        '''SELECT SUM(review_count) as total_reviews, SUM(lapses) as total_lapses 
           FROM user_word_progress 
           WHERE status > 0'''
      );
      if (result.isEmpty || result.first['total_reviews'] == null) return 1.0;
      final totalReviews = (result.first['total_reviews'] as num?)?.toInt() ?? 0;
      final totalLapses = (result.first['total_lapses'] as num?)?.toInt() ?? 0;
      if (totalReviews == 0) return 1.0;
      return (totalReviews - totalLapses) / totalReviews;
    } catch (e) {
      print('❌ Error getting global memory accuracy: $e');
      return 1.0;
    }
  }

  /// Đếm số từ ĐÃ ÔN hôm nay (DISTINCT word_id, status > 0, last_review_date = today)
  Future<int> countReviewedToday() async {
    final db = await database;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        '''SELECT COUNT(DISTINCT word_id) as count FROM user_word_progress 
           WHERE last_review_date LIKE ? 
           AND (first_learned_date NOT LIKE ? OR first_learned_date IS NULL)
           AND status > 0''',
        ['$today%', '$today%'],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error counting reviewed today: $e');
      return 0;
    }
  }

  /// Đếm số từ MỚI đã học hôm nay (first_learned_date = today)
  Future<int> countNewLearnedToday() async {
    final db = await database;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_word_progress WHERE first_learned_date LIKE ?',
        ['$today%'],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error counting new learned today: $e');
      return 0;
    }
  }

  Future<List<Word>> getNewWords(int limit, {String? topicId}) async {
    final db = await database;
    try {
      String query = 'SELECT * FROM words WHERE id NOT IN (SELECT word_id FROM user_word_progress)';
      List<dynamic> args = [];
      
      if (topicId != null) {
        query += ' AND $_topicIdColumnName = ?';
        args.add(topicId);
      }
      
      query += ' ORDER BY RANDOM() LIMIT ?';
      args.add(limit);
      
      final result = await db.rawQuery(query, args);
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting new words: $e');
      return [];
    }
  }

  Future<List<Word>> getHardWords(int limit) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        '''SELECT w.* FROM words w
           JOIN user_word_progress p ON w.id = p.word_id
           WHERE p.status > 0 AND p.ease_factor < 2.0 
           ORDER BY RANDOM() LIMIT ?''',
        [limit]
      );
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting hard words: $e');
      return [];
    }
  }

  Future<List<UserWordProgress>> getAllWordProgress() async {
    final db = await database;
    try {
      final result = await db.query('user_word_progress');
      return result.map((m) => UserWordProgress.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting all word progress: $e');
      return [];
    }
  }
  
  // ============================================
  // STUDY SESSIONS CRUD
  // ============================================
  
  Future<void> insertStudySession(StudySession session) async {
    final db = await database;
    try {
      print('📝 Inserting study session: id=${session.sessionId}, xp=${session.xpEarned}, words=${session.wordsReviewed}');
      final result = await db.insert(
        'study_sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Study session inserted, rowId=$result');
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM study_sessions'));
      print('📊 Total study sessions in DB: $count');
    } catch (e) {
      print('❌ Error inserting study session: $e');
    }
  }
  
  Future<List<StudySession>> getRecentStudySessions(int days) async {
    final db = await database;
    try {
      final sinceDate = DateTime.now().subtract(Duration(days: days));
      print('📊 Querying study_sessions since: ${sinceDate.toIso8601String()}');
      
      final totalCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM study_sessions'));
      print('📊 Total study sessions in DB: $totalCount');
      
      if (totalCount != null && totalCount > 0) {
        final allRows = await db.query('study_sessions', limit: 10, orderBy: 'date DESC');
        for (var row in allRows) {
          print('📊 Session: date=${row['date']}, xp=${row['xp_earned']}');
        }
      }
      
      final result = await db.query(
        'study_sessions',
        where: 'date >= ?',
        whereArgs: [sinceDate.toIso8601String()],
        orderBy: 'date DESC',
      );
      print('📊 Found ${result.length} sessions in last $days days');
      return result.map((m) => StudySession.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting recent study sessions: $e');
      return [];
    }
  }

  /// Lấy số từ đã học mỗi ngày trong N ngày gần nhất (cho Heatmap)
  Future<Map<String, int>> getWordsLearnedPerDay(int days) async {
    final db = await database;
    try {
      final sinceDate = DateTime.now().subtract(Duration(days: days));
      // Lấy từ study_sessions
      final sessions = await db.query(
        'study_sessions',
        where: 'date >= ?',
        whereArgs: [sinceDate.toIso8601String()],
      );
      
      Map<String, int> perDay = {};
      for (var s in sessions) {
        final dateStr = s['date']?.toString() ?? '';
        if (dateStr.length >= 10) {
          final dayKey = dateStr.substring(0, 10);
          perDay[dayKey] = (perDay[dayKey] ?? 0) + ((s['words_reviewed'] as int?) ?? 0);
        }
      }
      
      // Bổ sung từ practice_results
      final practices = await db.query(
        'practice_results',
        where: 'created_at >= ?',
        whereArgs: [sinceDate.millisecondsSinceEpoch],
      );
      for (var p in practices) {
        final ms = p['created_at'] as int?;
        if (ms != null) {
          final d = DateTime.fromMillisecondsSinceEpoch(ms);
          final dayKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          perDay[dayKey] = (perDay[dayKey] ?? 0) + ((p['total_questions'] as int?) ?? 0);
        }
      }
      
      return perDay;
    } catch (e) {
      print('❌ Error getWordsLearnedPerDay: $e');
      return {};
    }
  }

  /// Lấy tổng từ đã học tích lũy theo ngày (cho Line Chart)
  Future<List<Map<String, dynamic>>> getCumulativeLearnedWords(int days) async {
    final db = await database;
    try {
      final sinceDate = DateTime.now().subtract(Duration(days: days));
      final result = await db.rawQuery('''
        SELECT DATE(first_learned_date) as day, COUNT(*) as count 
        FROM user_word_progress 
        WHERE first_learned_date IS NOT NULL 
          AND first_learned_date != ''
          AND first_learned_date >= ?
        GROUP BY DATE(first_learned_date) 
        ORDER BY day ASC
      ''', [sinceDate.toIso8601String()]);
      return result;
    } catch (e) {
      print('❌ Error getCumulativeLearnedWords: $e');
      return [];
    }
  }

  Future<void> debugLearnedWords() async {
    final db = await database;
    print('\n🔍 ===== DEBUG LEARNED WORDS (User: $_currentUserId) =====');
    final learned0 = await db.rawQuery('SELECT COUNT(*) as count FROM words WHERE is_learned = 0');
    final learned1 = await db.rawQuery('SELECT COUNT(*) as count FROM words WHERE is_learned = 1');
    print('📊 is_learned = 0 (ĐÃ HỌC): ${Sqflite.firstIntValue(learned0)}');
    print('📊 is_learned = 1 (CHƯA HỌC): ${Sqflite.firstIntValue(learned1)}');
    final examples = await db.query('words', where: 'is_learned = 0', limit: 5);
    print('\n📖 Sample learned words:');
    for (var word in examples) {
      print('  - ${word['word']}: is_learned=${word['is_learned']}, learned_at=${word['learned_at']}');
    }
    print('================================\n');
  }

  // ============================================
  // STUDY TIME HISTORY CRUD
  // ============================================

  Future<void> saveStudyTimeEntry(String date, int seconds, int goalMinutes) async {
    final db = await database;
    try {
      await db.insert(
        'study_time_history',
        {
          'date': date,
          'study_time_seconds': seconds,
          'goal_minutes': goalMinutes,
          'goal_reached': seconds >= (goalMinutes * 60) ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error saving study time entry: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStudyTimeHistory({int limit = 30}) async {
    final db = await database;
    try {
      return await db.query('study_time_history', orderBy: 'date DESC', limit: limit);
    } catch (e) {
      print('❌ Error getting study time history: $e');
      return [];
    }
  }

  /// Get study status for rolling 7 days (5 past + today + 1 future)
  /// Returns list of 7 integers: 0 = not studied (future/today), 1 = studied, 2 = grace period, 3 = missed past
  Future<List<int>> getWeeklyStreak() async {
    final db = await database;
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 5));

      // Get user's current streak as fallback
      final userMaps = await db.query('users', where: 'id = ?', whereArgs: [_currentUserId]);
      int currentStreak = 0;
      String? lastStudyDate;
      bool usedGracePeriod = false;
      if (userMaps.isNotEmpty) {
        currentStreak = userMaps.first['streak_days'] as int? ?? 0;
        lastStudyDate = userMaps.first['last_study_date'] as String?;
        usedGracePeriod = (userMaps.first['used_grace_period'] as int? ?? 0) == 1;
      }

      List<int> streak = [];
      for (int i = 0; i < 7; i++) {
        final date = DateTime(startDate.year, startDate.month, startDate.day + i);
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final result = await db.query(
          'study_time_history',
          where: 'date = ? AND study_time_seconds > 0',
          whereArgs: [dateStr],
        );
        
        bool studied = result.isNotEmpty;
        int state = studied ? 1 : 0;
        
        // Backfill UI for days within the active streak window
        if (state == 0 && currentStreak > 0 && lastStudyDate != null) {
           final lastDate = DateTime.tryParse(lastStudyDate);
           if (lastDate != null) {
              // 1. Check if this date is the grace period day
              if (usedGracePeriod) {
                 final graceDay = lastDate.add(const Duration(days: 1));
                 if (date.year == graceDay.year && date.month == graceDay.month && date.day == graceDay.day) {
                    state = 2;
                 }
              }
              
              // 2. Check if this date is within the streak window
              if (state == 0) {
                 final streakStartDate = lastDate.subtract(Duration(days: currentStreak - 1));
                 final normalizedDate = DateTime(date.year, date.month, date.day);
                 final normalizedStart = DateTime(streakStartDate.year, streakStartDate.month, streakStartDate.day);
                 final normalizedLast = DateTime(lastDate.year, lastDate.month, lastDate.day);
                 
                 if (!normalizedDate.isBefore(normalizedStart) && !normalizedDate.isAfter(normalizedLast)) {
                    state = 1;
                 }
              }
           }
        }
        
        // Mark missed past days as 3
        if (state == 0) {
           final normalizedDate = DateTime(date.year, date.month, date.day);
           final normalizedNow = DateTime(now.year, now.month, now.day);
           if (normalizedDate.isBefore(normalizedNow)) {
              state = 3;
           }
        }
        
        streak.add(state);
      }
      return streak;
    } catch (e) {
      print('❌ Error getting weekly streak: $e');
      return List.filled(7, 0);
    }
  }

  // ============================================
  // PRACTICE RESULTS CRUD
  // ============================================

  Future<void> savePracticeResult(PracticeResult result) async {
    final db = await database;
    try {
      await db.insert('practice_results', result.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('✅ Practice result saved: ${result.id}');
    } catch (e) {
      print('❌ Error saving practice result: $e');
    }
  }

  Future<List<PracticeResult>> getPracticeHistory({int limit = 50}) async {
    final db = await database;
    try {
      final result = await db.query(
        'practice_results',
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return result.map((m) => PracticeResult.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting practice history: $e');
      return [];
    }
  }

  Future<PracticeResult?> getPracticeResultById(String id) async {
    final db = await database;
    try {
      final result = await db.query('practice_results', where: 'id = ?', whereArgs: [id]);
      if (result.isNotEmpty) return PracticeResult.fromMap(result.first);
      return null;
    } catch (e) {
      print('❌ Error getting practice result: $e');
      return null;
    }
  }

  Future<List<Word>> getLearnedWordsByTopics(List<String> topicIds) async {
    final db = await database;
    try {
      if (topicIds.isEmpty) return [];
      final placeholders = topicIds.map((_) => '?').join(',');
      final params = [...topicIds, ...topicIds];
      final result = await db.rawQuery(
        '''SELECT w.* FROM words w
           LEFT JOIN topics t ON w.$_topicIdColumnName = t.id
           WHERE (t.id IN ($placeholders) OR t.parent_id IN ($placeholders)) 
           AND w.is_learned = 0''',
        params,
      );
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting learned words by topics: $e');
      return [];
    }
  }

  Future<List<Word>> getNewWordsByTopics(List<String> topicIds) async {
    final db = await database;
    try {
      if (topicIds.isEmpty) return [];
      final placeholders = topicIds.map((_) => '?').join(',');
      // Hỗ trợ 2 cấp: lấy từ dựa vào topic con hoặc topic cha
      final params = [...topicIds, ...topicIds];
      final result = await db.rawQuery(
        '''SELECT w.* FROM words w
           LEFT JOIN topics t ON w.$_topicIdColumnName = t.id
           WHERE (t.id IN ($placeholders) OR t.parent_id IN ($placeholders)) 
           AND w.is_learned = 1''',
        params,
      );
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting new words by topics: $e');
      return [];
    }
  }

  Future<List<Word>> getAllLearnedWords() async {
    final db = await database;
    try {
      final result = await db.query('words', where: 'is_learned = 0');
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting all learned words: $e');
      return [];
    }
  }

  Future<int> getLearnedWordsCountByTopic(String topicId) async {
    final db = await database;
    try {
      final result = Sqflite.firstIntValue(await db.rawQuery(
        '''SELECT COUNT(*) FROM words w
           LEFT JOIN topics t ON w.$_topicIdColumnName = t.id
           WHERE (t.id = ? OR t.parent_id = ?) AND w.is_learned = 0''',
        [topicId, topicId],
      ));
      return result ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ==========================================
  // BADGES
  // ==========================================

  Future<void> unlockBadge(String userId, String badgeId) async {
    final db = await database;
    await db.insert(
      'user_badges',
      {'user_id': userId, 'badge_id': badgeId, 'unlocked_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<Set<String>> getUnlockedBadgeIds(String userId) async {
    final db = await database;
    final results = await db.query(
      'user_badges',
      columns: ['badge_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.map((r) => r['badge_id'] as String).toSet();
  }

  Future<Map<String, DateTime>> getUnlockedBadgesMap(String userId) async {
    final db = await database;
    final results = await db.query('user_badges', where: 'user_id = ?', whereArgs: [userId]);
    final map = <String, DateTime>{};
    for (final r in results) {
      map[r['badge_id'] as String] = DateTime.parse(r['unlocked_at'] as String);
    }
    return map;
  }

  // ==========================================
  // COUNTERS
  // ==========================================

  Future<int> getCounter(String userId, String key) async {
    final db = await database;
    final results = await db.query(
      'user_counters',
      columns: ['counter_value'],
      where: 'user_id = ? AND counter_key = ?',
      whereArgs: [userId, key],
    );
    if (results.isEmpty) return 0;
    return results.first['counter_value'] as int;
  }

  Future<int> incrementCounter(String userId, String key) async {
    final db = await database;
    final current = await getCounter(userId, key);
    final newValue = current + 1;
    await db.insert(
      'user_counters',
      {'user_id': userId, 'counter_key': key, 'counter_value': newValue},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newValue;
  }

  // ============================================
  // DICTIONARY CACHE CRUD
  // ============================================

  Future<String?> getDictionaryCache(String word) async {
    final db = await database;
    try {
      final result = await db.query(
        'dictionary_cache',
        columns: ['data'],
        where: 'word = ?',
        whereArgs: [word.toLowerCase()],
      );
      if (result.isNotEmpty) return result.first['data'] as String;
      return null;
    } catch (e) {
      print('❌ Error getting dictionary cache: $e');
      return null;
    }
  }

  Future<void> saveDictionaryCache(String word, String data) async {
    final db = await database;
    try {
      await db.insert(
        'dictionary_cache',
        {
          'word': word.toLowerCase(),
          'data': data,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error saving dictionary cache: $e');
    }
  }

  // ============================================
  // ADAPTIVE LEARNING (DIFFICULT WORDS)
  // ============================================

  Future<void> toggleDifficult(String wordId) async {
    final db = await database;
    try {
      final existing = await db.query('user_word_progress', where: 'word_id = ?', whereArgs: [wordId]);
      if (existing.isEmpty) {
        await db.insert('user_word_progress', {
          'word_id': wordId,
          'is_difficult': 1,
          'last_seen_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final current = existing.first['is_difficult'] == 1;
        await db.update(
          'user_word_progress',
          {
            'is_difficult': current ? 0 : 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'word_id = ?',
          whereArgs: [wordId],
        );
      }
    } catch (e) {
      print('❌ Error toggling difficult word: $e');
    }
  }

  Future<void> updateWrongCount(String wordId) async {
    final db = await database;
    try {
      final existing = await db.query('user_word_progress', where: 'word_id = ?', whereArgs: [wordId]);
      final now = DateTime.now().toIso8601String();
      if (existing.isEmpty) {
        await db.insert('user_word_progress', {
          'word_id': wordId,
          'wrong_count': 1,
          'last_seen_at': now,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final currentWrong = existing.first['wrong_count'] as int? ?? 0;
        await db.update(
          'user_word_progress',
          {
            'wrong_count': currentWrong + 1,
            'last_seen_at': now,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'word_id = ?',
          whereArgs: [wordId],
        );
      }
    } catch (e) {
      print('❌ Error updating wrong count: $e');
    }
  }

  Future<List<Word>> getDifficultWords({String? topicId, int limit = 30}) async {
    final db = await database;
    try {
      final progressList = await db.rawQuery(
        '''SELECT * FROM user_word_progress 
           WHERE is_difficult = 1 OR wrong_count >= 3'''
      );

      if (progressList.isEmpty) return [];

      List<Map<String, dynamic>> scoredProgress = progressList.map((p) {
        final isDifficult = p['is_difficult'] == 1;
        final wrongCount = p['wrong_count'] as int? ?? 0;
        final repetition = p['repetition'] as int? ?? 0;
        final score = (isDifficult ? 50 : 0) + (wrongCount * 10) - (repetition * 5);
        return {
          ...p,
          'difficulty_score': score,
        };
      }).toList();

      scoredProgress.sort((a, b) {
        final scoreCompare = (b['difficulty_score'] as int).compareTo(a['difficulty_score'] as int);
        if (scoreCompare != 0) return scoreCompare;
        
        final timeA = a['last_seen_at'] as String? ?? '';
        final timeB = b['last_seen_at'] as String? ?? '';
        return timeA.compareTo(timeB);
      });

      scoredProgress = scoredProgress.where((p) => p['difficulty_score'] as int > 0 || p['is_difficult'] == 1).toList();

      final targetWordIds = scoredProgress.take(limit).map((p) => p['word_id'] as String).toList();
      if (targetWordIds.isEmpty) return [];

      final placeholders = targetWordIds.map((_) => '?').join(',');
      String query = '''SELECT w.* FROM words w
                        LEFT JOIN topics t ON w.$_topicIdColumnName = t.id
                        WHERE w.id IN ($placeholders)''';
      List<dynamic> args = [...targetWordIds];

      if (topicId != null) {
        query += ' AND (t.id = ? OR t.parent_id = ?)';
        args.addAll([topicId, topicId]);
      }

      final wordsData = await db.rawQuery(query, args);
      
      final wordMap = {for (var w in wordsData) w['id'] as String: Word.fromMap(w)};
      return targetWordIds.where((id) => wordMap.containsKey(id)).map((id) => wordMap[id]!).toList();
    } catch (e) {
      print('❌ Error getting difficult words: $e');
      return [];
    }
  }
}