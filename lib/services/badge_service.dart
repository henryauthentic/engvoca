import '../db/database_helper.dart';
import '../models/badge.dart';

class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Get all badges with unlock status AND progress for user
  Future<List<Badge>> getAllBadges(String userId) async {
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);
    final unlockedMap = await _dbHelper.getUnlockedBadgesMap(userId);

    // Fetch stats for progress calculation
    final stats = await _getUserStats(userId);

    return Badge.allBadges.map((badge) {
      final isUnlocked = unlockedIds.contains(badge.id);
      final progress = _calculateProgress(badge.id, stats);

      return badge.copyWith(
        isUnlocked: isUnlocked,
        unlockedAt: isUnlocked ? unlockedMap[badge.id] : null,
        currentProgress: isUnlocked ? badge.targetValue : progress,
      );
    }).toList();
  }

  /// Get only unlocked count (fast, for Home screen)
  Future<int> getUnlockedCount(String userId) async {
    final ids = await _dbHelper.getUnlockedBadgeIds(userId);
    return ids.length;
  }

  /// Get recently unlocked badges (for Home screen preview)
  Future<List<Badge>> getRecentUnlocked(String userId, {int limit = 3}) async {
    final unlockedMap = await _dbHelper.getUnlockedBadgesMap(userId);
    
    // Sort by unlock date desc
    final sortedEntries = unlockedMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final recentIds = sortedEntries.take(limit).map((e) => e.key).toSet();
    
    return Badge.allBadges
        .where((b) => recentIds.contains(b.id))
        .map((b) => b.copyWith(
          isUnlocked: true,
          unlockedAt: unlockedMap[b.id],
          currentProgress: b.targetValue,
        ))
        .toList();
  }

  /// Fetch all stats needed for progress calculation
  Future<Map<String, int>> _getUserStats(String userId) async {
    final userMap = await _dbHelper.getLocalUser(userId);
    if (userMap == null) return {};

    final learnedWords = (userMap['words_learned'] ?? 0) as int;
    final currentStreak = (userMap['streak_days'] ?? 0) as int;
    final totalXp = (userMap['total_xp'] ?? 0) as int;
    
    // Counters
    final storyCount = await _dbHelper.getCounter(userId, 'story_count');
    final chatCount = await _dbHelper.getCounter(userId, 'chat_count');
    final quizCount = await _dbHelper.getCounter(userId, 'quiz_completed');

    return {
      'learnedWords': learnedWords,
      'currentStreak': currentStreak,
      'totalXp': totalXp,
      'storyCount': storyCount,
      'chatCount': chatCount,
      'quizCount': quizCount,
    };
  }

  /// Calculate current progress for a specific badge
  int _calculateProgress(String badgeId, Map<String, int> stats) {
    final words = stats['learnedWords'] ?? 0;
    final streak = stats['currentStreak'] ?? 0;
    final xp = stats['totalXp'] ?? 0;
    final stories = stats['storyCount'] ?? 0;
    final chats = stats['chatCount'] ?? 0;
    final quizzes = stats['quizCount'] ?? 0;

    switch (badgeId) {
      // Vocabulary
      case 'first_word': return words.clamp(0, 1);
      case 'word_10': return words.clamp(0, 10);
      case 'word_50': return words.clamp(0, 50);
      case 'word_100': return words.clamp(0, 100);
      case 'word_200': return words.clamp(0, 200);
      case 'word_500': return words.clamp(0, 500);
      case 'word_1000': return words.clamp(0, 1000);
      
      // Streak
      case 'streak_3': return streak.clamp(0, 3);
      case 'streak_7': return streak.clamp(0, 7);
      case 'streak_14': return streak.clamp(0, 14);
      case 'streak_30': return streak.clamp(0, 30);
      case 'streak_60': return streak.clamp(0, 60);
      case 'streak_100': return streak.clamp(0, 100);
      
      // Special — these are one-time events, no progress tracking
      case 'night_owl': return 0;
      case 'early_bird': return 0;
      case 'speed_demon': return 0;
      
      // Achievement
      case 'perfect_score': return 0;
      case 'story_lover': return stories.clamp(0, 5);
      case 'chat_master': return chats.clamp(0, 10);
      case 'xp_500': return xp.clamp(0, 500);
      case 'xp_1000': return xp.clamp(0, 1000);
      case 'xp_5000': return xp.clamp(0, 5000);
      case 'quiz_10': return quizzes.clamp(0, 10);
      case 'quiz_50': return quizzes.clamp(0, 50);
      
      default: return 0;
    }
  }

  /// Check and unlock badges based on current stats. Returns newly unlocked badges.
  Future<List<Badge>> checkAndUnlockBadges(String userId) async {
    final List<Badge> newlyUnlocked = [];
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);
    final userMap = await _dbHelper.getLocalUser(userId);
    if (userMap == null) return newlyUnlocked;

    final learnedWords = (userMap['words_learned'] ?? 0) as int;
    final currentStreak = (userMap['streak_days'] ?? 0) as int;
    final totalXp = (userMap['total_xp'] ?? 0) as int;
    final hour = DateTime.now().hour;

    // Word count badges
    if (learnedWords >= 1) await _tryUnlock('first_word', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 10) await _tryUnlock('word_10', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 50) await _tryUnlock('word_50', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 100) await _tryUnlock('word_100', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 200) await _tryUnlock('word_200', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 500) await _tryUnlock('word_500', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 1000) await _tryUnlock('word_1000', userId, unlockedIds, newlyUnlocked);

    // Streak badges
    if (currentStreak >= 3) await _tryUnlock('streak_3', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 7) await _tryUnlock('streak_7', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 14) await _tryUnlock('streak_14', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 30) await _tryUnlock('streak_30', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 60) await _tryUnlock('streak_60', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 100) await _tryUnlock('streak_100', userId, unlockedIds, newlyUnlocked);

    // Time-based badges
    if (hour >= 0 && hour < 4) await _tryUnlock('night_owl', userId, unlockedIds, newlyUnlocked);
    if (hour >= 5 && hour <= 7) await _tryUnlock('early_bird', userId, unlockedIds, newlyUnlocked);

    // XP badges
    if (totalXp >= 500) await _tryUnlock('xp_500', userId, unlockedIds, newlyUnlocked);
    if (totalXp >= 1000) await _tryUnlock('xp_1000', userId, unlockedIds, newlyUnlocked);
    if (totalXp >= 5000) await _tryUnlock('xp_5000', userId, unlockedIds, newlyUnlocked);

    // Quiz count badges
    final quizCount = await _dbHelper.getCounter(userId, 'quiz_completed');
    if (quizCount >= 10) await _tryUnlock('quiz_10', userId, unlockedIds, newlyUnlocked);
    if (quizCount >= 50) await _tryUnlock('quiz_50', userId, unlockedIds, newlyUnlocked);

    return newlyUnlocked;
  }

  /// Check quiz-specific badges
  Future<List<Badge>> checkQuizBadges(String userId, {
    required int totalQuestions,
    required int correctCount,
    required int durationSeconds,
  }) async {
    final List<Badge> newlyUnlocked = [];
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);

    // Perfect score: 100% with at least 10 questions
    if (totalQuestions >= 10 && correctCount == totalQuestions) {
      await _tryUnlock('perfect_score', userId, unlockedIds, newlyUnlocked);
    }

    // Speed demon: under 30 seconds total
    if (durationSeconds < 30 && totalQuestions >= 5) {
      await _tryUnlock('speed_demon', userId, unlockedIds, newlyUnlocked);
    }

    return newlyUnlocked;
  }

  /// Check story count badge
  Future<List<Badge>> checkStoryBadge(String userId, int storyCount) async {
    final List<Badge> newlyUnlocked = [];
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);

    if (storyCount >= 5) {
      await _tryUnlock('story_lover', userId, unlockedIds, newlyUnlocked);
    }

    return newlyUnlocked;
  }

  /// Check chat count badge
  Future<List<Badge>> checkChatBadge(String userId, int chatCount) async {
    final List<Badge> newlyUnlocked = [];
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);

    if (chatCount >= 10) {
      await _tryUnlock('chat_master', userId, unlockedIds, newlyUnlocked);
    }

    return newlyUnlocked;
  }

  Future<void> _tryUnlock(
    String badgeId,
    String userId,
    Set<String> alreadyUnlocked,
    List<Badge> newlyUnlocked,
  ) async {
    if (alreadyUnlocked.contains(badgeId)) return;

    await _dbHelper.unlockBadge(userId, badgeId);
    alreadyUnlocked.add(badgeId);

    final badge = Badge.allBadges.firstWhere((b) => b.id == badgeId);
    newlyUnlocked.add(badge.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    print('🏅 Badge unlocked: ${badge.name}');
  }
}
