import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';
import '../models/practice_result.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ==========================
  ///  USER COLLECTION
  /// ==========================
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Tạo user mới
  Future<void> createUser(User user) async {
    try {
      await _users.doc(user.id).set({
        'id': user.id,
        'email': user.email,
        'displayName': user.displayName,
        'avatar': user.avatar,
        'createdAt': user.createdAt.toIso8601String(),
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
        'totalWords': user.totalWords,
        'learnedWords': user.learnedWords,
        // ✅ NEW: Onboarding & Timer fields
        'learningLevel': user.learningLevel,
        'selectedTopics': user.selectedTopics,
        'dailyGoal': user.dailyGoal,
        'isOnboarded': user.isOnboarded,
        'todayStudyTime': user.todayStudyTime,
        'lastStudyDate': user.lastStudyDate,
      }, SetOptions(merge: true));
    } catch (e) {
      print('🔥 createUser error: $e');
      rethrow;
    }
  }

  /// Lấy dữ liệu user
  Future<User?> getUser(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!; // đã đúng kiểu Map<String, dynamic>

      return User.fromMap(data);
    } catch (e) {
      print('🔥 getUser error: $e');
      return null;
    }
  }

  /// Cập nhật user
  Future<void> updateUser(User user) async {
    try {
      await _users.doc(user.id).set(
        user.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('🔥 updateUser error: $e');
      rethrow;
    }
  }

  /// Cập nhật tiến độ học
  /// Cập nhật tiến độ học
  Future<bool> updateUserProgress(
      String userId, int totalWords, int learnedWords) async {
    try {
      if (userId.isEmpty) {
        throw Exception("❌ userId bị rỗng");
      }
      if (totalWords < 0 || learnedWords < 0) {
        throw Exception("❌ Số lượng từ không hợp lệ");
      }

      final data = {
        'totalWords': totalWords,
        'learnedWords': learnedWords,
        'lastLoginAt': DateTime.now().toIso8601String(),
      };

      print('📤 Đang upload progress: $data');

      await _users.doc(userId).set(data, SetOptions(merge: true));

      print('✅ Cập nhật thành công!');
      return true;
    } catch (e) {
      print('🔥 updateUserProgress error: $e');
      return false;
    }
  }


  /// ==========================
  ///  WORD PROGRESS (SM-2)
  /// ==========================

  CollectionReference<Map<String, dynamic>> _wordProgress(String userId) {
    return _users.doc(userId).collection('wordProgress');
  }

  /// Sync danh sách tiến độ học từ (SM-2)
  Future<void> syncWordProgress(String userId, List<UserWordProgress> progresses) async {
    try {
      final batch = _firestore.batch();
      final ref = _wordProgress(userId);

      for (var p in progresses) {
        final doc = ref.doc(p.wordId);

        batch.set(doc, {
          ...p.toMap(),
          'syncedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('🔥 syncWordProgress error: $e');
      rethrow;
    }
  }

  /// Lấy danh sách tiến độ học từ (SM-2)
  Future<List<Map<String, dynamic>>> getWordProgressList(String userId) async {
    try {
      final snap = await _wordProgress(userId).get();

      return snap.docs.map((d) => d.data()).toList(); // ⭐ đúng kiểu luôn
    } catch (e) {
      print('🔥 getWordProgressList error: $e');
      return [];
    }
  }

  /// ==========================
  ///  QUIZ RESULTS
  /// ==========================

  CollectionReference<Map<String, dynamic>> _quizResults(String userId) {
    return _users.doc(userId).collection('quizResults');
  }

  /// Lưu kết quả quiz
  Future<void> saveQuizResult(
    String userId, {
    required int topicId,
    required int totalQuestions,
    required int correctAnswers,
    required int timeSpent,
  }) async {
    try {
      await _quizResults(userId).add({
        'topicId': topicId,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'score': ((correctAnswers / totalQuestions) * 100).round(),
        'timeSpent': timeSpent,
        'completedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('🔥 saveQuizResult error: $e');
      rethrow;
    }
  }

  /// Lấy lịch sử quiz – trả đúng Future<List<Map<String, dynamic>>>
  Future<List<Map<String, dynamic>>> getQuizHistory(
    String userId, {
    int? topicId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _quizResults(userId)
          .orderBy('completedAt', descending: true)
          .limit(20);

      if (topicId != null) {
        query = query.where('topicId', isEqualTo: topicId);
      }

      final snap = await query.get();

      return snap.docs.map((d) => d.data()).toList(); // ⭐ không còn lỗi List<Object?>
    } catch (e) {
      print('🔥 getQuizHistory error: $e');
      return [];
    }
  }

  /// ==========================
  ///  PRACTICE HISTORY
  /// ==========================

  CollectionReference<Map<String, dynamic>> _practiceHistory(String userId) {
    return _users.doc(userId).collection('practiceHistory');
  }

  /// Sync 1 bài practice (hoặc batch nếu bạn viết lại sau)
  Future<void> syncPracticeResult(String userId, PracticeResult result) async {
    try {
      await _practiceHistory(userId).doc(result.id).set(
        result.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('🔥 syncPracticeResult error: $e');
    }
  }

  /// Lấy toàn bộ lịch sử practice
  Future<List<Map<String, dynamic>>> getPracticeHistory(String userId) async {
    try {
      final snap = await _practiceHistory(userId).orderBy('created_at', descending: true).get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('🔥 getPracticeHistory error: $e');
      return [];
    }
  }

  /// ==========================
  ///  NOTIFICATION SETTINGS
  /// ==========================

  /// Lưu object notificationSettings vào User Document
  Future<void> updateNotificationSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _users.doc(userId).set({
        'notificationSettings': settings,
      }, SetOptions(merge: true));
    } catch (e) {
      print('🔥 updateNotificationSettings error: $e');
    }
  }

  /// Lấy notificationSettings (nếu có)
  Future<Map<String, dynamic>?> getNotificationSettings(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data.containsKey('notificationSettings')) {
        return data['notificationSettings'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('🔥 getNotificationSettings error: $e');
      return null;
    }
  }

  /// ==========================
  ///  STUDY TIME HISTORY
  /// ==========================

  CollectionReference<Map<String, dynamic>> _studyTimeHistory(String userId) {
    return _users.doc(userId).collection('studyTimeHistory');
  }

  /// Push entry 1 ngày
  Future<void> saveStudyTimeEntry(
    String userId, 
    String date, 
    int seconds, 
    int goalMinutes,
  ) async {
    try {
      await _studyTimeHistory(userId).doc(date).set({
        'date': date,
        'studyTimeSeconds': seconds,
        'goalMinutes': goalMinutes,
        'goalReached': seconds >= goalMinutes * 60,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('🔥 saveStudyTimeEntry error: $e');
    }
  }

  /// Kéo về client
  Future<List<Map<String, dynamic>>> getStudyTimeHistory(String userId) async {
    try {
      final snap = await _studyTimeHistory(userId).orderBy('date', descending: true).limit(30).get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('🔥 getStudyTimeHistory error: $e');
      return [];
    }
  }
}
