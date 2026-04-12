import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';
import '../models/study_session.dart';
import '../models/practice_result.dart';

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

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final exists = await databaseExists(path);

    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join('assets', 'database', 'EnglishMaster.db'));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        print('✅ Database copied for user $_currentUserId to: $path');
      } catch (e) {
        print('❌ Error copying database from assets: $e');
        throw Exception('Failed to load database. Make sure EnglishMaster.db is in assets/database/');
      }
    } else {
      print('📂 Database already exists for user $_currentUserId at: $path');
    }

    final db = await openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        print('📂 Database opened successfully for user $_currentUserId');
        await _verifyTables(db);
        await _migrateUsersTable(db);
        await _createLocalTables(db);
      },
    );
    
    return db;
  }

  /// Migrate users table to add missing columns
  Future<void> _migrateUsersTable(Database db) async {
    try {
      print('🔄 Checking users table schema...');
      
      final tableInfo = await db.rawQuery('PRAGMA table_info(users)');
      final columns = tableInfo.map((c) => c['name'] as String).toList();
      
      print('📊 Current users columns: $columns');
      
      // Add missing columns
      if (!columns.contains('last_active')) {
        print('➕ Adding last_active column...');
        await db.execute('ALTER TABLE users ADD COLUMN last_active TEXT');
      }
      
      if (!columns.contains('avatar_url')) {
        print('➕ Adding avatar_url column...');
        await db.execute('ALTER TABLE users ADD COLUMN avatar_url TEXT');
      }
      
      if (!columns.contains('level')) {
        print('➕ Adding level column...');
        await db.execute('ALTER TABLE users ADD COLUMN level INTEGER DEFAULT 1');
      }
      
      if (!columns.contains('total_points')) {
        print('➕ Adding total_points column...');
        await db.execute('ALTER TABLE users ADD COLUMN total_points INTEGER DEFAULT 0');
      }
      
      if (!columns.contains('words_learned')) {
        print('➕ Adding words_learned column...');
        await db.execute('ALTER TABLE users ADD COLUMN words_learned INTEGER DEFAULT 0');
      }
      
      if (!columns.contains('streak_days')) {
        print('➕ Adding streak_days column...');
        await db.execute('ALTER TABLE users ADD COLUMN streak_days INTEGER DEFAULT 0');
      }

      // ✅ NEW: Onboarding & Study Timer columns
      if (!columns.contains('learning_level')) {
        print('➕ Adding learning_level column...');
        await db.execute("ALTER TABLE users ADD COLUMN learning_level TEXT DEFAULT 'beginner'");
      }
      if (!columns.contains('selected_topics')) {
        print('➕ Adding selected_topics column...');
        await db.execute("ALTER TABLE users ADD COLUMN selected_topics TEXT DEFAULT '[]'");
      }
      if (!columns.contains('daily_goal')) {
        print('➕ Adding daily_goal column...');
        await db.execute('ALTER TABLE users ADD COLUMN daily_goal INTEGER DEFAULT 15');
      }
      if (!columns.contains('is_onboarded')) {
        print('➕ Adding is_onboarded column...');
        await db.execute('ALTER TABLE users ADD COLUMN is_onboarded INTEGER DEFAULT 0');
      }
      if (!columns.contains('today_study_time')) {
        print('➕ Adding today_study_time column...');
        await db.execute('ALTER TABLE users ADD COLUMN today_study_time INTEGER DEFAULT 0');
      }
      if (!columns.contains('last_study_date')) {
        print('➕ Adding last_study_date column...');
        await db.execute('ALTER TABLE users ADD COLUMN last_study_date TEXT');
      }
      
      print('✅ Users table migration completed');
    } catch (e) {
      print('❌ Error migrating users table: $e');
      // Don't rethrow - continue even if migration fails
    }
  }

  Future<void> _createLocalTables(Database db) async {
    try {
      print('🔄 Creating local tracking tables if not exists...');
      
      // Bảng Spaced Repetition cho từng User
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
          lapses INTEGER DEFAULT 0
        )
      ''');

      // Bảng Study Sessions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_sessions (
          session_id TEXT PRIMARY KEY,
          date TEXT,
          xp_earned INTEGER DEFAULT 0,
          words_reviewed INTEGER DEFAULT 0,
          accuracy_rate REAL DEFAULT 0.0
        )
      ''');

      // Bảng Practice Results (Lịch sử luyện tập)
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

      // Bảng Study Time History (Lịch sử thời gian học theo ngày)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_time_history (
          date TEXT PRIMARY KEY,
          study_time_seconds INTEGER DEFAULT 0,
          goal_minutes INTEGER DEFAULT 15,
          goal_reached INTEGER DEFAULT 0
        )
      ''');

      // Bảng User Badges (Huy hiệu đã mở khóa)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_badges (
          user_id TEXT NOT NULL,
          badge_id TEXT NOT NULL,
          unlocked_at TEXT NOT NULL,
          PRIMARY KEY (user_id, badge_id)
        )
      ''');

      // Bảng User Counters (Đếm story/chat cho badge)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_counters (
          user_id TEXT NOT NULL,
          counter_key TEXT NOT NULL,
          counter_value INTEGER DEFAULT 0,
          PRIMARY KEY (user_id, counter_key)
        )
      ''');
      
      print('✅ Local tracking tables created successfully');
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
      print('   Available columns: $wordsColumns');
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

  /// Create or update user in local SQLite
  Future<void> upsertUser({
    required String id,
    required String name,
    required String email,
    String? avatarUrl,
    int level = 1,
    int totalPoints = 0,
    int wordsLearned = 0,
    int streakDays = 0,
    DateTime? lastLoginDate,
    // ✅ NEW: Onboarding & Timer fields
    String? learningLevel,
    String? selectedTopics,
    int? dailyGoal,
    bool? isOnboarded,
    int? todayStudyTime,
    String? lastStudyDate,
  }) async {
    final db = await database;
    
    try {
      // ✅ Lấy dữ liệu cũ trước khi xóa (bảo toàn created_date & last_login_date)
      // Check by ID first, then by email
      final existingById = await db.query('users', where: 'id = ?', whereArgs: [id]);
      final existingByEmail = await db.query('users', where: 'email = ?', whereArgs: [email]);
      final existing = existingById.isNotEmpty ? existingById : existingByEmail;
      int? existingCreatedDate;
      int? existingLastLoginDate;
      // Preserve existing onboarding data
      String? existingLearningLevel;
      String? existingSelectedTopics;
      int? existingDailyGoal;
      int? existingIsOnboarded;
      int? existingTodayStudyTime;
      String? existingLastStudyDate;
      
      if (existing.isNotEmpty) {
        existingCreatedDate = existing.first['created_date'] as int?;
        existingLastLoginDate = existing.first['last_login_date'] as int?;
        existingLearningLevel = existing.first['learning_level'] as String?;
        existingSelectedTopics = existing.first['selected_topics'] as String?;
        existingDailyGoal = existing.first['daily_goal'] as int?;
        existingIsOnboarded = existing.first['is_onboarded'] as int?;
        existingTodayStudyTime = existing.first['today_study_time'] as int?;
        existingLastStudyDate = existing.first['last_study_date'] as String?;
      }
      
      // ✅ Delete by BOTH id AND email to avoid UNIQUE constraint
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
      await db.delete('users', where: 'email = ?', whereArgs: [email]);
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // ✅ Ưu tiên: parameter > existing > default
      final loginDateMs = lastLoginDate?.millisecondsSinceEpoch
          ?? existingLastLoginDate
          ?? now;
      final createdDateMs = existingCreatedDate ?? now;
      
      await db.insert(
        'users',
        {
          'id': id,
          'name': name,
          'email': email,
          'password': null,
          'avatar_url': avatarUrl,
          'level': level,
          'total_points': totalPoints,
          'words_learned': wordsLearned,
          'streak_days': streakDays,
          'last_active': DateTime.now().toIso8601String(),
          'created_date': createdDateMs,
          'last_login_date': loginDateMs,
          // ✅ NEW fields (parameter > existing > default)
          'learning_level': learningLevel ?? existingLearningLevel ?? 'beginner',
          'selected_topics': selectedTopics ?? existingSelectedTopics ?? '[]',
          'daily_goal': dailyGoal ?? existingDailyGoal ?? 15,
          'is_onboarded': isOnboarded == true ? 1 : (existingIsOnboarded ?? 0),
          'today_study_time': todayStudyTime ?? existingTodayStudyTime ?? 0,
          'last_study_date': lastStudyDate ?? existingLastStudyDate,
        },
      );
      
      print('✅ Upserted user $name ($id), streak=$streakDays, onboarded=${isOnboarded ?? existingIsOnboarded}');
    } catch (e) {
      print('❌ Error upserting user: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Update study time for current user
  Future<void> updateStudyTime(String userId, int studyTimeSeconds, String dateKey) async {
    final db = await database;
    try {
      await db.update(
        'users',
        {
          'today_study_time': studyTimeSeconds,
          'last_study_date': dateKey,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('❌ Error updating study time: $e');
    }
  }

  /// ✅ NEW: Update onboarding data for current user
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

  /// Get user from local SQLite
  Future<Map<String, dynamic>?> getLocalUser(String userId) async {
    final db = await database;
    
    try {
      final result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (result.isEmpty) return null;
      
      print('📖 Retrieved user from SQLite: ${result.first}');
      return result.first;
    } catch (e) {
      print('❌ Error getting local user: $e');
      return null;
    }
  }

  /// Delete user from local SQLite (on logout)
  Future<void> deleteLocalUser(String userId) async {
    final db = await database;
    
    try {
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      print('🗑️ Deleted user $userId from SQLite');
    } catch (e) {
      print('❌ Error deleting local user: $e');
    }
  }

  // ============================================
  // TOPIC CRUD
  // ============================================

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

  Future<int> deleteTopic(String id) async {
    final db = await database;
    return await db.delete('topics', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // WORD CRUD
  // ============================================

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
      {
        'is_learned': 0,
        'learned_at': now,
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
    
    print('✅ Marked word $wordId as learned for user $_currentUserId');
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
    final result = await db.rawQuery('SELECT DISTINCT $_topicIdColumnName FROM words ORDER BY $_topicIdColumnName');
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

  Future<void> updateTopicCounts() async {
    final db = await database;
    
    try {
      final topics = await db.query('topics');
      
      print('🔄 Updating counts for ${topics.length} topics (user: $_currentUserId)...');
      
      for (var topicMap in topics) {
        final topicId = topicMap['id'] as String;
        
        final totalResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM words WHERE $_topicIdColumnName = ?',
          [topicId]
        );
        final totalWords = Sqflite.firstIntValue(totalResult) ?? 0;
        
        final learnedResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM words WHERE $_topicIdColumnName = ? AND is_learned = 0',
          [topicId]
        );
        final learnedWords = Sqflite.firstIntValue(learnedResult) ?? 0;
        
        await db.update(
          'topics',
          {
            _totalWordsColumnName: totalWords,
            _learnedWordsColumnName: learnedWords,
          },
          where: 'id = ?',
          whereArgs: [topicId],
        );
        
        print('  ✅ Topic "$topicId": $learnedWords / $totalWords learned');
      }
      
      print('✅ Successfully updated counts for ${topics.length} topics (user: $_currentUserId)');
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
      if (result.isNotEmpty) {
        return UserWordProgress.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('❌ Error getting word progress: $e');
      return null;
    }
  }

  Future<void> upsertWordProgress(UserWordProgress progress) async {
    final db = await database;
    try {
      await db.insert(
        'user_word_progress',
        progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error upserting word progress: $e');
    }
  }

  Future<List<UserWordProgress>> getWordsToReview(DateTime targetDate) async {
    final db = await database;
    try {
      // Find all words where next_review_date is less than or equal to targetDate
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
        '''
        SELECT w.* FROM words w
        JOIN user_word_progress p ON w.id = p.word_id
        WHERE p.next_review_date <= ? AND p.status > 0
        ORDER BY RANDOM() LIMIT ?
        ''',
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
      // Get words with low ease factor or low repetition
      final result = await db.rawQuery(
        '''
        SELECT w.* FROM words w
        JOIN user_word_progress p ON w.id = p.word_id
        WHERE p.status > 0 AND p.ease_factor < 2.0 
        ORDER BY RANDOM() LIMIT ?
        ''',
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
      print('📝 Inserting study session: id=${session.sessionId}, date=${session.date.toIso8601String()}, xp=${session.xpEarned}, words=${session.wordsReviewed}');
      final result = await db.insert(
        'study_sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Study session inserted successfully, rowId=$result');
      
      // Verify insertion
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
      
      // First check how many total rows exist
      final totalCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM study_sessions'));
      print('📊 Total study sessions in DB: $totalCount');
      
      // Show all sessions for debugging
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
      return await db.query(
        'study_time_history',
        orderBy: 'date DESC',
        limit: limit,
      );
    } catch (e) {
      print('❌ Error getting study time history: $e');
      return [];
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
      final result = await db.query('practice_results',
          where: 'id = ?', whereArgs: [id]);
      if (result.isNotEmpty) {
        return PracticeResult.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('❌ Error getting practice result: $e');
      return null;
    }
  }

  /// Lấy từ ĐÃ HỌC từ các topics cụ thể (dùng cho Luyện tập tự do)
  Future<List<Word>> getLearnedWordsByTopics(List<String> topicIds) async {
    final db = await database;
    try {
      if (topicIds.isEmpty) return [];
      final placeholders = topicIds.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT * FROM words WHERE $_topicIdColumnName IN ($placeholders) AND is_learned = 0',
        topicIds,
      );
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting learned words by topics: $e');
      return [];
    }
  }

  /// Lấy từ CHƯA HỌC từ các topics cụ thể (dùng cho Khám phá từ mới)
  Future<List<Word>> getNewWordsByTopics(List<String> topicIds) async {
    final db = await database;
    try {
      if (topicIds.isEmpty) return [];
      final placeholders = topicIds.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT * FROM words WHERE $_topicIdColumnName IN ($placeholders) AND is_learned = 1',
        topicIds,
      );
      return result.map((m) => Word.fromMap(m)).toList();
    } catch (e) {
      print('❌ Error getting new words by topics: $e');
      return [];
    }
  }

  /// Lấy tất cả từ ĐÃ HỌC (cho nút "Tất cả" trong luyện tập)
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

  /// Đếm số từ ĐÃ HỌC theo topic
  Future<int> getLearnedWordsCountByTopic(String topicId) async {
    final db = await database;
    try {
      final result = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM words WHERE $_topicIdColumnName = ? AND is_learned = 0',
        [topicId],
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
      {
        'user_id': userId,
        'badge_id': badgeId,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
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
    final results = await db.query(
      'user_badges',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final map = <String, DateTime>{};
    for (final r in results) {
      map[r['badge_id'] as String] = DateTime.parse(r['unlocked_at'] as String);
    }
    return map;
  }

  // ==========================================
  // COUNTERS (for story/chat badge tracking)
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
      {
        'user_id': userId,
        'counter_key': key,
        'counter_value': newValue,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newValue;
  }
}