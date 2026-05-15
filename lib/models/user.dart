import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String displayName;
  final String avatar;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int totalWords;
  final int learnedWords;
  
  // Gamification fields
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final int level;

  // ✅ NEW: Onboarding & Personalization fields
  final String learningLevel;       // 'beginner', 'intermediate', 'advanced'
  final List<String> selectedTopics; // Topic IDs user chose during onboarding
  final int dailyGoal;              // Words per day (15, 20, 30)
  final bool isOnboarded;           // Has completed onboarding flow
  final int todayStudyTime;         // Seconds studied today
  final String? lastStudyDate;      // 'yyyy-MM-dd' format
  
  // Streak Grace Period
  final bool usedGracePeriod;         // Has used 1-day grace (prevents chaining)

  // Future Scale
  final Map<String, int> xpBreakdown; // {'review': 0, 'newWords': 0, 'quiz': 0}
  final DateTime? updatedAt;
  final String? deviceId;

  // ✅ Advanced Query: Denormalized stats for Web dashboard
  final Map<String, int> topicProgress; // {'topicId': learnedCount, ...}
  final int totalReviews;               // Total review actions across all words
  final int totalLapses;                // Total lapse (forgot) count

  // ✅ Smart Sync: Cross-platform sync metadata
  final String? lastSyncedAt;           // ISO8601 or Firestore Timestamp
  final String lastChangeSource;        // 'web' or 'mobile'

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatar = "assets/images/default_avatar.png", 
    required this.createdAt,
    this.lastLoginAt,
    this.totalWords = 0,
    this.learnedWords = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalXp = 0,
    this.level = 1,
    // ✅ NEW defaults
    this.learningLevel = 'beginner',
    this.selectedTopics = const [],
    this.dailyGoal = 15,
    this.isOnboarded = false,
    this.todayStudyTime = 0,
    this.lastStudyDate,
    this.usedGracePeriod = false,
    this.xpBreakdown = const {'review': 0, 'newWords': 0, 'quiz': 0},
    this.updatedAt,
    this.deviceId,
    // Advanced Query + Smart Sync
    this.topicProgress = const {},
    this.totalReviews = 0,
    this.totalLapses = 0,
    this.lastSyncedAt,
    this.lastChangeSource = 'mobile',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'totalWords': totalWords,
      'learnedWords': learnedWords,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalXp': totalXp,
      'level': level,
      // ✅ NEW fields
      'learningLevel': learningLevel,
      'selectedTopics': jsonEncode(selectedTopics), // stringified for SQLite
      'dailyGoal': dailyGoal,
      'isOnboarded': isOnboarded ? 1 : 0, // integer for SQLite
      'todayStudyTime': todayStudyTime,
      'lastStudyDate': lastStudyDate,
      'usedGracePeriod': usedGracePeriod ? 1 : 0, // integer for SQLite
      'xpBreakdown': jsonEncode(xpBreakdown), // stringified for SQLite
      'updatedAt': updatedAt?.toIso8601String(),
      'deviceId': deviceId,
      // Advanced Query + Smart Sync
      'topicProgress': jsonEncode(topicProgress),
      'totalReviews': totalReviews,
      'totalLapses': totalLapses,
      'lastSyncedAt': lastSyncedAt,
      'lastChangeSource': lastChangeSource,
    };
  }

  // Chuyển đổi chuẩn hóa cho Firestore
  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'avatar': avatar,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'totalWords': totalWords,
      'learnedWords': learnedWords,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalXp': totalXp,
      'level': level,
      'learningLevel': learningLevel,
      'selectedTopics': selectedTopics, // Natively array
      'dailyGoal': dailyGoal,
      'isOnboarded': isOnboarded, // Boolean
      'todayStudyTime': todayStudyTime,
      'lastStudyDate': lastStudyDate,
      'usedGracePeriod': usedGracePeriod,
      'xpBreakdown': xpBreakdown, // Natively map
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'deviceId': deviceId,
      // Advanced Query + Smart Sync
      'topicProgress': topicProgress, // Natively map
      'totalReviews': totalReviews,
      'totalLapses': totalLapses,
      'lastSyncedAt': FieldValue.serverTimestamp(), // Always use server time
      'lastChangeSource': lastChangeSource,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Handle both Firebase keys and SQLite column names
    
    // Parse selectedTopics from JSON string or List
    List<String> topics = [];
    final rawTopics = map['selectedTopics'] ?? map['selected_topics'];
    if (rawTopics is String && rawTopics.isNotEmpty) {
      try {
        topics = List<String>.from(jsonDecode(rawTopics));
      } catch (_) {}
    } else if (rawTopics is List) {
      topics = List<String>.from(rawTopics);
    }

    // Parse isOnboarded from int (SQLite) or bool (Firebase)
    bool onboarded = false;
    final rawOnboarded = map['isOnboarded'] ?? map['is_onboarded'];
    if (rawOnboarded is bool) {
      onboarded = rawOnboarded;
    } else if (rawOnboarded is int) {
      onboarded = rawOnboarded == 1;
    }

    return User(
      id: (map['id'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      displayName: (map['displayName'] ?? map['name'] ?? 'User').toString(),
      avatar: (map['avatar'] ?? map['avatar_url'] ?? 'assets/images/default_avatar.png').toString(),
      createdAt: _parseDateTime(map['createdAt'] ?? map['created_date']) ?? DateTime.now(),
      lastLoginAt: _parseDateTime(map['lastLoginAt'] ?? map['last_login_date']),
      totalWords: _parseInt(map['totalWords'] ?? map['total_words']),
      learnedWords: _parseInt(map['learnedWords'] ?? map['words_learned']),
      currentStreak: _parseInt(map['currentStreak'] ?? map['streak_days']),
      longestStreak: _parseInt(map['longestStreak'] ?? map['longest_streak']),
      totalXp: _parseInt(map['totalXp'] ?? map['total_points']),
      level: _parseInt(map['level'], 1),
      learningLevel: (map['learningLevel'] ?? map['learning_level'] ?? 'beginner').toString(),
      selectedTopics: topics,
      dailyGoal: _parseInt(map['dailyGoal'] ?? map['daily_goal'], 15),
      isOnboarded: onboarded,
      todayStudyTime: _parseInt(map['todayStudyTime'] ?? map['today_study_time']),
      lastStudyDate: map['lastStudyDate']?.toString() ?? map['last_study_date']?.toString(),
      usedGracePeriod: _parseBool(map['usedGracePeriod'] ?? map['used_grace_period']),
      xpBreakdown: _parseMap(map['xpBreakdown'] ?? map['xp_breakdown']),
      updatedAt: _parseDateTime(map['updatedAt'] ?? map['updated_at']),
      deviceId: map['deviceId']?.toString() ?? map['device_id']?.toString(),
      topicProgress: _parseIntMap(map['topicProgress'] ?? map['topic_progress']),
      totalReviews: _parseInt(map['totalReviews'] ?? map['total_reviews']),
      totalLapses: _parseInt(map['totalLapses'] ?? map['total_lapses']),
      lastSyncedAt: _parseTimestampString(map['lastSyncedAt'] ?? map['last_synced_at']),
      lastChangeSource: (map['lastChangeSource'] ?? map['last_change_source'] ?? 'mobile').toString(),
    );
  }

  /// Safe int parser: handles int, double (from Firebase increment), String
  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Safe DateTime parser: handles Timestamp, String, int (epoch ms), double
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  static Map<String, int> _parseMap(dynamic data) {
    if (data == null) return {'review': 0, 'newWords': 0, 'quiz': 0};
    if (data is Map) {
      try {
        return data.map((k, v) => MapEntry(k.toString(), _parseInt(v)));
      } catch (_) {}
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), _parseInt(v)));
        }
      } catch (_) {}
    }
    return {'review': 0, 'newWords': 0, 'quiz': 0};
  }

  /// Parse a generic Map<String, int> (for topicProgress)
  static Map<String, int> _parseIntMap(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
        }
      } catch (_) {}
    }
    return {};
  }

  /// Parse Firestore Timestamp or ISO string to String (for lastSyncedAt)
  static String? _parseTimestampString(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate().toIso8601String();
    if (val is String) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toIso8601String();
    if (val is double) return DateTime.fromMillisecondsSinceEpoch(val.toInt()).toIso8601String();
    return null;
  }

  static bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    return false;
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatar,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int? totalWords,
    int? learnedWords,
    int? currentStreak,
    int? longestStreak,
    int? totalXp,
    int? level,
    String? learningLevel,
    List<String>? selectedTopics,
    int? dailyGoal,
    bool? isOnboarded,
    int? todayStudyTime,
    String? lastStudyDate,
    bool? usedGracePeriod,
    Map<String, int>? xpBreakdown,
    DateTime? updatedAt,
    String? deviceId,
    Map<String, int>? topicProgress,
    int? totalReviews,
    int? totalLapses,
    String? lastSyncedAt,
    String? lastChangeSource,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      totalWords: totalWords ?? this.totalWords,
      learnedWords: learnedWords ?? this.learnedWords,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      learningLevel: learningLevel ?? this.learningLevel,
      selectedTopics: selectedTopics ?? this.selectedTopics,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      todayStudyTime: todayStudyTime ?? this.todayStudyTime,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      usedGracePeriod: usedGracePeriod ?? this.usedGracePeriod,
      xpBreakdown: xpBreakdown ?? this.xpBreakdown,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      topicProgress: topicProgress ?? this.topicProgress,
      totalReviews: totalReviews ?? this.totalReviews,
      totalLapses: totalLapses ?? this.totalLapses,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastChangeSource: lastChangeSource ?? this.lastChangeSource,
    );
  }
}