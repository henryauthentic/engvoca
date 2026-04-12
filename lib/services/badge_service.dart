import '../db/database_helper.dart';
import '../models/badge.dart';

class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Get all badges with unlock status for user
  Future<List<Badge>> getAllBadges(String userId) async {
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);
    final unlockedMap = await _dbHelper.getUnlockedBadgesMap(userId);

    return Badge.allBadges.map((badge) {
      if (unlockedIds.contains(badge.id)) {
        return badge.copyWith(
          isUnlocked: true,
          unlockedAt: unlockedMap[badge.id],
        );
      }
      return badge;
    }).toList();
  }

  /// Check and unlock badges based on current stats. Returns newly unlocked badges.
  Future<List<Badge>> checkAndUnlockBadges(String userId) async {
    final List<Badge> newlyUnlocked = [];
    final unlockedIds = await _dbHelper.getUnlockedBadgeIds(userId);
    final userMap = await _dbHelper.getLocalUser(userId);
    if (userMap == null) return newlyUnlocked;

    final learnedWords = (userMap['words_learned'] ?? 0) as int;
    final currentStreak = (userMap['streak_days'] ?? 0) as int;
    final hour = DateTime.now().hour;

    // Word count badges
    if (learnedWords >= 1) await _tryUnlock('first_word', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 10) await _tryUnlock('word_10', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 50) await _tryUnlock('word_50', userId, unlockedIds, newlyUnlocked);
    if (learnedWords >= 100) await _tryUnlock('word_100', userId, unlockedIds, newlyUnlocked);

    // Streak badges
    if (currentStreak >= 3) await _tryUnlock('streak_3', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 7) await _tryUnlock('streak_7', userId, unlockedIds, newlyUnlocked);
    if (currentStreak >= 30) await _tryUnlock('streak_30', userId, unlockedIds, newlyUnlocked);

    // Time-based badges
    if (hour >= 0 && hour < 4) await _tryUnlock('night_owl', userId, unlockedIds, newlyUnlocked);
    if (hour >= 5 && hour <= 7) await _tryUnlock('early_bird', userId, unlockedIds, newlyUnlocked);

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
