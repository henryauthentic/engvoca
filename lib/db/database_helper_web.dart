// ============================================
// FILE: lib/db/database_helper_web.dart
// Database Helper cho Flutter Web
// Sử dụng Cloud Firestore thay vì SQLite
// CHỈ implement các core methods cần cho Auth + Dashboard
// ============================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';
import '../models/study_session.dart';
import '../models/practice_result.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static String? _currentUserId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DatabaseHelper._init();

  // ============================================
  // USER MANAGEMENT
  // ============================================

  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      print('🌐 [Web] Switching user to $userId');
      _currentUserId = userId;
    }
  }

  String? get currentUserId => _currentUserId;

  /// Lấy user từ Firestore
  Future<Map<String, dynamic>?> getLocalUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      // Map Firestore fields → format giống SQLite để tương thích với User.fromMap()
      return {
        'id': userId,
        'name': data['displayName'] ?? data['name'] ?? 'User',
        'email': data['email'] ?? '',
        'password': null,
        'avatar_url': data['avatar'] ?? data['avatarUrl'] ?? data['avatar_url'],
        'level': data['level'] ?? 1,
        'total_points': data['totalWords'] ?? data['total_points'] ?? 0,
        'words_learned': data['learnedWords'] ?? data['words_learned'] ?? 0,
        'streak_days': data['currentStreak'] ?? data['streak_days'] ?? 0,
        'last_active': data['lastLoginAt'] ?? data['last_active'],
        'created_date': _parseTimestamp(data['createdAt']),
        'last_login_date': _parseTimestamp(data['lastLoginAt']),
        'learning_level': data['learningLevel'] ?? 'beginner',
        'selected_topics': data['selectedTopics'] ?? '[]',
        'daily_goal': data['dailyGoal'] ?? 15,
        'is_onboarded': (data['isOnboarded'] == true || data['isOnboarded'] == 1) ? 1 : 0,
        'today_study_time': data['todayStudyTime'] ?? 0,
        'last_study_date': data['lastStudyDate'],
      };
    } catch (e) {
      print('🌐 [Web] Error getting user: $e');
      return null;
    }
  }

  /// Upsert user vào Firestore
  Future<void> upsertUser({
    required String id,
    required String name,
    required String email,
    String? avatarUrl,
    int? level,
    int? totalPoints,
    int? wordsLearned,
    int? streakDays,
    DateTime? lastLoginDate,
    String? learningLevel,
    String? selectedTopics,
    int? dailyGoal,
    bool? isOnboarded,
    int? todayStudyTime,
    String? lastStudyDate,
    Map<String, int>? xpBreakdown,
  }) async {
    try {
      await _firestore.collection('users').doc(id).set({
        'displayName': name,
        'email': email,
        'avatar': avatarUrl,
        if (level != null) 'level': level,
        if (totalPoints != null) 'totalWords': totalPoints,
        if (wordsLearned != null) 'learnedWords': wordsLearned,
        if (streakDays != null) 'currentStreak': streakDays,
        'lastLoginAt': (lastLoginDate ?? DateTime.now()).toIso8601String(),
        if (learningLevel != null) 'learningLevel': learningLevel,
        if (selectedTopics != null) 'selectedTopics': selectedTopics,
        if (dailyGoal != null) 'dailyGoal': dailyGoal,
        if (isOnboarded != null) 'isOnboarded': isOnboarded,
        if (todayStudyTime != null) 'todayStudyTime': todayStudyTime,
        if (lastStudyDate != null) 'lastStudyDate': lastStudyDate,
        if (xpBreakdown != null) 'xpBreakdown': xpBreakdown,
      }, SetOptions(merge: true));
      print('🌐 [Web] Upserted user $name ($id)');
    } catch (e) {
      print('🌐 [Web] Error upserting user: $e');
      rethrow;
    }
  }

  Future<void> deleteLocalUser(String userId) async {
    // Trên Web không cần xóa gì local, chỉ log out
    print('🌐 [Web] deleteLocalUser called (no-op on web)');
  }

  Future<void> updateStudyTime(String userId, int studyTimeSeconds, String dateKey) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'todayStudyTime': studyTimeSeconds,
        'lastStudyDate': dateKey,
      }, SetOptions(merge: true));
    } catch (e) {
      print('🌐 [Web] Error updating study time: $e');
    }
  }

  Future<void> updateOnboardingData({
    required String userId,
    required String learningLevel,
    required String selectedTopicsJson,
    required int dailyGoal,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'learningLevel': learningLevel,
        'selectedTopics': selectedTopicsJson,
        'dailyGoal': dailyGoal,
        'isOnboarded': true,
      }, SetOptions(merge: true));
      print('🌐 [Web] Onboarding data saved for user $userId');
    } catch (e) {
      print('🌐 [Web] Error saving onboarding data: $e');
      rethrow;
    }
  }

  // ============================================
  // TOPICS — Từ Firestore collection 'topics'
  // ============================================

  Future<List<Topic>> getTopics() async {
    try {
      final snap = await _firestore
          .collection('topics')
          .get();

      if (snap.docs.isEmpty) {
        print('🌐 [Web] No topics found in Firestore. Run data migration first.');
        return [];
      }

      final topics = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Topic.fromMap(data);
      }).toList();

      // Sort trong Dart (tránh cần Firestore index)
      topics.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      print('🌐 [Web] Loaded ${topics.length} topics from Firestore');
      return topics;
    } catch (e) {
      print('🌐 [Web] Error loading topics: $e');
      return [];
    }
  }

  /// Lấy các topic CHA (parent_id == null)
  Future<List<Topic>> getParentTopics() async {
    try {
      final allTopics = await getTopics();
      final parents = allTopics.where((t) => t.isParent).toList();
      print('🌐 [Web] Loaded ${parents.length} parent topics');
      return parents;
    } catch (e) {
      print('🌐 [Web] Error loading parent topics: $e');
      return [];
    }
  }

  /// Lấy các topic CON theo parent
  Future<List<Topic>> getChildTopics(String parentId) async {
    try {
      final allTopics = await getTopics();
      final children = allTopics.where((t) => t.parentId == parentId).toList();
      children.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      print('🌐 [Web] Loaded ${children.length} child topics for parent $parentId');
      return children;
    } catch (e) {
      print('🌐 [Web] Error loading child topics: $e');
      return [];
    }
  }

  /// Kiểm tra topic có topic con không
  Future<bool> hasChildren(String topicId) async {
    try {
      final allTopics = await getTopics();
      return allTopics.any((t) => t.parentId == topicId);
    } catch (e) {
      return false;
    }
  }

  /// Lấy tất cả từ thuộc topic cha (gộp từ các topic con)
  Future<List<Word>> getWordsByParentTopic(String parentId) async {
    try {
      final children = await getChildTopics(parentId);
      List<Word> allWords = [];
      for (final child in children) {
        final words = await getWordsByTopic(child.id!);
        allWords.addAll(words);
      }
      allWords.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      print('🌐 [Web] Loaded ${allWords.length} words for parent topic $parentId');
      return allWords;
    } catch (e) {
      print('🌐 [Web] Error loading words for parent topic: $e');
      return [];
    }
  }

  Future<Topic> getTopic(String id) async {
    final doc = await _firestore.collection('topics').doc(id).get();
    if (!doc.exists) throw Exception('Topic not found');
    final data = doc.data()!;
    data['id'] = doc.id;
    return Topic.fromMap(data);
  }

  /// Cập nhật ảnh cho Topic
  Future<void> updateTopicImage(String topicId, String imageUrl) async {
    try {
      await _firestore.collection('topics').doc(topicId).set(
        {'imageUrl': imageUrl}, 
        SetOptions(merge: true)
      );
    } catch (e) {
      print('🌐 [Web] Error updating topic image: $e');
    }
  }

  // ============================================
  // WORDS — Từ Firestore collection 'words'
  // ============================================

  Future<List<Word>> getWordsByTopic(String topicId) async {
    try {
      // Thử cả 2 field names vì migration lưu cả topic_id và a_topic_id
      var snap = await _firestore
          .collection('words')
          .where('topic_id', isEqualTo: topicId)
          .get();

      // Nếu không tìm thấy, thử a_topic_id
      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection('words')
            .where('a_topic_id', isEqualTo: topicId)
            .get();
      }

      final words = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Word.fromMap(data);
      }).toList();
      
      // Sort trong Dart (tránh cần Firestore composite index)
      words.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      
      print('🌐 [Web] Loaded ${words.length} words for topic $topicId');
      return words;
    } catch (e) {
      print('🌐 [Web] Error loading words for topic $topicId: $e');
      return [];
    }
  }

  Future<List<Word>> getAllWords() async {
    try {
      final snap = await _firestore.collection('words').get();
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Word.fromMap(data);
      }).toList();
    } catch (e) {
      print('🌐 [Web] Error loading all words: $e');
      return [];
    }
  }

  Future<Word> getWord(String id) async {
    final doc = await _firestore.collection('words').doc(id).get();
    if (!doc.exists) throw Exception('Word not found');
    final data = doc.data()!;
    data['id'] = doc.id;
    return Word.fromMap(data);
  }

  Future<int> countWordsByTopic(String topicId) async {
    try {
      var snap = await _firestore
          .collection('words')
          .where('topic_id', isEqualTo: topicId)
          .get();

      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection('words')
            .where('a_topic_id', isEqualTo: topicId)
            .get();
      }

      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Word>> getRandomWords(int count, {String? topicId}) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      
      if (topicId != null) {
        snap = await _firestore
            .collection('words')
            .where('topic_id', isEqualTo: topicId)
            .get();

        if (snap.docs.isEmpty) {
          snap = await _firestore
              .collection('words')
              .where('a_topic_id', isEqualTo: topicId)
              .get();
        }
      } else {
        snap = await _firestore.collection('words').limit(count * 3).get();
      }

      final words = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Word.fromMap(data);
      }).toList();
      words.shuffle();
      return words.take(count).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markWordAsLearned(String wordId) async {
    try {
      await _firestore.collection('words').doc(wordId).update({
        'is_learned': 0,
        'learned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('🌐 [Web] Error marking word as learned: $e');
    }
  }

  Future<int> countNewWords() async {
    // Đếm words chưa có trong user_word_progress
    if (_currentUserId == null) return 0;
    try {
      final progressSnap = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('wordProgress')
          .get();
      final learnedIds = progressSnap.docs.map((d) => d.id).toSet();

      final allWordsSnap = await _firestore.collection('words').count().get();
      final totalWords = allWordsSnap.count ?? 0;

      return totalWords - learnedIds.length;
    } catch (e) {
      return 0;
    }
  }

  // ============================================
  // SPACED REPETITION (SM-2) — User subcollection
  // ============================================

  Future<UserWordProgress?> getWordProgress(String wordId) async {
    if (_currentUserId == null) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('wordProgress')
          .doc(wordId)
          .get();

      if (!doc.exists) return null;
      return UserWordProgress.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  Future<void> upsertWordProgress(UserWordProgress progress) async {
    if (_currentUserId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('wordProgress')
          .doc(progress.wordId)
          .set(progress.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('🌐 [Web] Error upserting word progress: $e');
    }
  }

  Future<List<UserWordProgress>> getWordsToReview(DateTime targetDate) async {
    if (_currentUserId == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('wordProgress')
          .where('next_review_date', isLessThanOrEqualTo: targetDate.toIso8601String())
          .where('status', isGreaterThan: 0)
          .get();
      return snap.docs.map((d) => UserWordProgress.fromMap(d.data())).toList();
    } catch (e) {
      print('🌐 [Web] Error getting words to review: $e');
      return [];
    }
  }

  Future<int> countDueWords(DateTime targetDate) async {
    final words = await getWordsToReview(targetDate);
    return words.length;
  }

  Future<List<UserWordProgress>> getAllWordProgress() async {
    if (_currentUserId == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('wordProgress')
          .get();
      return snap.docs.map((d) => UserWordProgress.fromMap(d.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // STUDY SESSIONS
  // ============================================

  Future<void> insertStudySession(StudySession session) async {
    if (_currentUserId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('studySessions')
          .doc(session.sessionId)
          .set(session.toMap());
    } catch (e) {
      print('🌐 [Web] Error inserting study session: $e');
    }
  }

  Future<List<StudySession>> getRecentStudySessions(int days) async {
    if (_currentUserId == null) return [];
    try {
      final sinceDate = DateTime.now().subtract(Duration(days: days));
      final snap = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('studySessions')
          .where('date', isGreaterThanOrEqualTo: sinceDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();
      return snap.docs.map((d) => StudySession.fromMap(d.data())).toList();
    } catch (e) {
      print('🌐 [Web] Error getting recent sessions: $e');
      return [];
    }
  }

  // ============================================
  // PRACTICE RESULTS
  // ============================================

  Future<void> savePracticeResult(PracticeResult result) async {
    if (_currentUserId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('practiceHistory')
          .doc(result.id)
          .set(result.toMap());
    } catch (e) {
      print('🌐 [Web] Error saving practice result: $e');
    }
  }

  Future<List<PracticeResult>> getPracticeHistory({int limit = 50}) async {
    if (_currentUserId == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('practiceHistory')
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => PracticeResult.fromMap(d.data())).toList();
    } catch (e) {
      print('🌐 [Web] Error getting practice history: $e');
      return [];
    }
  }

  // ============================================
  // STUDY TIME HISTORY
  // ============================================

  Future<void> saveStudyTimeEntry(String date, int seconds, int goalMinutes) async {
    if (_currentUserId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('studyTimeHistory')
          .doc(date)
          .set({
        'date': date,
        'study_time_seconds': seconds,
        'goal_minutes': goalMinutes,
        'goal_reached': seconds >= (goalMinutes * 60) ? 1 : 0,
      }, SetOptions(merge: true));
    } catch (e) {
      print('🌐 [Web] Error saving study time entry: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStudyTimeHistory({int limit = 30}) async {
    if (_currentUserId == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('studyTimeHistory')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('🌐 [Web] Error getting study time history: $e');
      return [];
    }
  }

  /// Get study status for current week (Mon→Sun)
  Future<List<bool>> getWeeklyStreak() async {
    if (_currentUserId == null) return List.filled(7, false);
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));

      List<bool> streak = [];
      for (int i = 0; i < 7; i++) {
        final date = DateTime(monday.year, monday.month, monday.day + i);
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final doc = await _firestore
            .collection('users')
            .doc(_currentUserId!)
            .collection('studyTimeHistory')
            .doc(dateStr)
            .get();
        final hasStudied = doc.exists && (doc.data()?['study_time_seconds'] ?? 0) > 0;
        streak.add(hasStudied);
      }
      return streak;
    } catch (e) {
      print('🌐 [Web] Error getting weekly streak: $e');
      return List.filled(7, false);
    }
  }

  // ============================================
  // TOPIC COUNTS (Recalculate)
  // ============================================

  Future<void> updateTopicCounts() async {
    // Trên Web, topic counts được tính trực tiếp khi getTopics()
    // Có thể update lại Firestore nếu cần
    print('🌐 [Web] updateTopicCounts called (handled via Firestore aggregation)');
  }

  // ============================================
  // BADGES
  // ============================================

  Future<void> unlockBadge(String userId, String badgeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .set({
        'badge_id': badgeId,
        'unlocked_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('🌐 [Web] Error unlocking badge: $e');
    }
  }

  Future<Set<String>> getUnlockedBadgeIds(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, DateTime>> getUnlockedBadgesMap(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();
      final map = <String, DateTime>{};
      for (final d in snap.docs) {
        map[d.id] = DateTime.parse(d.data()['unlocked_at'] as String);
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  // ============================================
  // COUNTERS (story/chat badge tracking)
  // ============================================

  Future<int> getCounter(String userId, String key) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('counters')
          .doc(key)
          .get();
      if (!doc.exists) return 0;
      return doc.data()?['value'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> incrementCounter(String userId, String key) async {
    try {
      final current = await getCounter(userId, key);
      final newValue = current + 1;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('counters')
          .doc(key)
          .set({'value': newValue});
      return newValue;
    } catch (e) {
      return 0;
    }
  }

  // ============================================
  // STUB METHODS — Giữ API compatibility
  // Các method này chỉ cần trên Mobile nhưng khai báo
  // stub để tránh compile error trên Web.
  // ============================================

  // Database getter stub (Web không có SQLite database object)
  Future<dynamic> get database async => null;

  Future<int> insertTopic(Topic topic) async => 0;
  Future<int> updateTopic(Topic topic) async => 0;
  Future<int> deleteTopic(String id) async => 0;

  Future<int> insertWord(Word word) async => 0;
  Future<int> updateWord(Word word) async => 0;
  Future<int> deleteWord(String id) async => 0;

  Future<List<Word>> getLearnedWords() async => [];
  Future<List<Word>> getUnlearnedWords() async => [];
  Future<List<Word>> getLearnedWordsByTopic(String topicId) async => [];
  Future<int> countLearnedWordsByTopic(String topicId) async => 0;
  Future<List<String>> getTopicIdsFromWords() async => [];

  Future<List<Word>> getGlobalDueWords(DateTime targetDate, int limit) async => [];
  Future<List<Word>> getNewWords(int limit, {String? topicId}) async => [];
  Future<List<Word>> getHardWords(int limit) async => [];
  
  Future<double> getGlobalMemoryAccuracy() async => 1.0;
  Future<int> countReviewedToday() async => 0;

  Future<List<Word>> getLearnedWordsByTopics(List<String> topicIds) async => [];
  Future<List<Word>> getNewWordsByTopics(List<String> topicIds) async => [];
  Future<List<Word>> getAllLearnedWords() async => [];
  Future<int> getLearnedWordsCountByTopic(String topicId) async => 0;

  Future<PracticeResult?> getPracticeResultById(String id) async => null;

  Future<void> debugLearnedWords() async {}
  Future<void> close() async {}

  String get topicIdColumn => 'topic_id';

  // ============================================
  // HELPERS
  // ============================================

  int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
