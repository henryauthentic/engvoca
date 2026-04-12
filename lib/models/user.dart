import 'dart:convert';

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
  final int dailyGoal;              // Minutes (10, 15, 30)
  final bool isOnboarded;           // Has completed onboarding flow
  final int todayStudyTime;         // Seconds studied today
  final String? lastStudyDate;      // 'yyyy-MM-dd' format

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
      'selectedTopics': jsonEncode(selectedTopics),
      'dailyGoal': dailyGoal,
      'isOnboarded': isOnboarded,
      'todayStudyTime': todayStudyTime,
      'lastStudyDate': lastStudyDate,
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
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: (map['displayName'] ?? map['name']) as String? ?? 'User',
      avatar: (map['avatar'] ?? map['avatar_url']) as String? ?? "assets/images/default_avatar.png",
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : (map['created_date'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(map['created_date'] as int)
              : DateTime.now()),
      lastLoginAt: map['lastLoginAt'] != null 
          ? DateTime.parse(map['lastLoginAt'] as String) 
          : (map['last_login_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['last_login_date'] as int)
              : null),
      totalWords: (map['totalWords'] ?? map['total_words']) as int? ?? 0,
      learnedWords: (map['learnedWords'] ?? map['words_learned']) as int? ?? 0,
      currentStreak: (map['currentStreak'] ?? map['streak_days']) as int? ?? 0,
      longestStreak: (map['longestStreak'] ?? map['longest_streak']) as int? ?? 0,
      totalXp: (map['totalXp'] ?? map['total_points']) as int? ?? 0,
      level: map['level'] as int? ?? 1,
      // ✅ NEW fields
      learningLevel: (map['learningLevel'] ?? map['learning_level']) as String? ?? 'beginner',
      selectedTopics: topics,
      dailyGoal: (map['dailyGoal'] ?? map['daily_goal']) as int? ?? 15,
      isOnboarded: onboarded,
      todayStudyTime: (map['todayStudyTime'] ?? map['today_study_time']) as int? ?? 0,
      lastStudyDate: (map['lastStudyDate'] ?? map['last_study_date']) as String?,
    );
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
    );
  }
}