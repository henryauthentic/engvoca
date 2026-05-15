import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../models/user.dart';
import 'badge_service.dart';

class GamificationService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> addXp(String userId, int xpToAdd, {String? source}) async {
    try {
      final userMap = await _dbHelper.getLocalUser(userId);
      if (userMap == null) return;

      User localUser = User.fromMap(userMap);
      
      int newXp = localUser.totalXp + xpToAdd;
      // Công thức tính level (Ví dụ: Level = căn bậc 2 của (totalXp / 100) + 1)
      int newLevel = (newXp / 100).truncate() + 1; // Formula đơn giản

      // Cập nhật xpBreakdown nếu có source
      Map<String, int> newBreakdown = Map<String, int>.from(localUser.xpBreakdown);
      if (source != null && newBreakdown.containsKey(source)) {
        newBreakdown[source] = (newBreakdown[source] ?? 0) + xpToAdd;
      }

      final updatedUser = localUser.copyWith(
        totalXp: newXp,
        level: newLevel,
        xpBreakdown: newBreakdown,
      );

      // Save locally
      await _dbHelper.upsertUser(
        id: updatedUser.id,
        name: updatedUser.displayName,
        email: updatedUser.email,
        avatarUrl: updatedUser.avatar,
        level: updatedUser.level,
        totalPoints: updatedUser.totalXp,
        wordsLearned: updatedUser.learnedWords,
        streakDays: updatedUser.currentStreak,
        xpBreakdown: updatedUser.xpBreakdown,
      );

      // Save to Firebase
      await _firebaseService.updateUser(updatedUser);
      
      print('🌟 Xp added: +$xpToAdd, Total: $newXp, Level: $newLevel');

      // Check for new badges
      await BadgeService().checkAndUnlockBadges(userId);
    } catch (e) {
      print('❌ Error adding XP: $e');
    }
  }

  /// Called on App Login OR after Study Session.
  /// Option B Logic: Streak only increases if user studies (isStudyActivity = true).
  /// If isStudyActivity = false, it only checks if streak should be broken.
  Future<void> updateStreak([String? userId, bool isStudyActivity = true]) async {
    final uid = userId ?? _dbHelper.currentUserId;
    if (uid == null) return;
    try {
      final userMap = await _dbHelper.getLocalUser(uid);
      if (userMap == null) return;

      User localUser = User.fromMap(userMap);
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final lastStudyRaw = userMap['last_study_date'] as String?;
      DateTime? lastStudyDate;
      if (lastStudyRaw != null) {
         lastStudyDate = DateTime.tryParse(lastStudyRaw);
      }

      int newStreak = localUser.currentStreak;
      int newLongestStreak = localUser.longestStreak;
      bool newUsedGrace = localUser.usedGracePeriod;
      bool shouldUpdate = false;

      // ✅ FIX: If lastStudyDate is null, user has NEVER studied
      if (lastStudyDate == null) {
        if (isStudyActivity) {
          newStreak = 1;
          newUsedGrace = false;
          shouldUpdate = true;
          print('🔥 Study: First study ever! Streak = 1');
        } else if (newStreak > 0) {
          newStreak = 0;
          newUsedGrace = false;
          shouldUpdate = true;
          print('💀 Login Check: No study date found, streak reset');
        }
      } else {
      // ✅ Normal flow: lastStudyDate exists
      final todayDate = DateTime(now.year, now.month, now.day);
      final lastDate = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);
      final difference = todayDate.difference(lastDate).inDays;

      if (!isStudyActivity) {
         // --- LOGIN ONLY ---
         // We only BREAK or use GRACE. We NEVER increment.
         if (difference == 2 && !localUser.usedGracePeriod && newStreak > 0) {
            newUsedGrace = true;
            shouldUpdate = true;
            print('😴 Login Check: Grace period used! Streak kept: $newStreak');
         } else if (difference >= 2 && (difference > 2 || localUser.usedGracePeriod)) {
            newStreak = 0; // reset to 0 so next study makes it 1
            newUsedGrace = false;
            shouldUpdate = true;
            print('💀 Login Check: Streak reset (missed ${difference - 1} days)');
         }
      } else {
         // --- STUDY ACTIVITY ---
         if (difference == 0) {
            // Already studied today
            if (newStreak == 0) {
               newStreak = 1;
               shouldUpdate = true;
            }
         } else if (difference == 1) {
            // New day study
            newStreak++;
            newUsedGrace = false;
            shouldUpdate = true;
            print('🔥 Study: Streak incremented to $newStreak');
         } else if (difference == 2 && !localUser.usedGracePeriod) {
            // Missed a day but used grace
            newStreak++;
            newUsedGrace = true;
            shouldUpdate = true;
            print('🔥 Study: Streak incremented to $newStreak (grace period used yesterday)');
         } else {
            // Missed too many days
            newStreak = 1;
            newUsedGrace = false;
            shouldUpdate = true;
            print('🔥 Study: New streak started: 1');
         }
      }
      } // end of lastStudyDate != null block

      if (newStreak > newLongestStreak) {
        newLongestStreak = newStreak;
        shouldUpdate = true;
      }

      // ✅ FIX: Only update lastStudyDate when user actually studies
      final updatedUser = localUser.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
        usedGracePeriod: newUsedGrace,
        lastLoginAt: now,
        lastStudyDate: isStudyActivity ? todayStr : localUser.lastStudyDate,
      );

      // Save locally
      await _dbHelper.upsertUser(
        id: updatedUser.id,
        name: updatedUser.displayName,
        email: updatedUser.email,
        avatarUrl: updatedUser.avatar,
        level: updatedUser.level,
        totalPoints: updatedUser.totalXp,
        wordsLearned: updatedUser.learnedWords,
        streakDays: updatedUser.currentStreak,
        longestStreak: updatedUser.longestStreak,
        usedGracePeriod: updatedUser.usedGracePeriod,
        lastLoginDate: now,
        lastStudyDate: isStudyActivity ? todayStr : null,
      );

      // Save to Firebase
      await _firebaseService.updateUser(updatedUser);

      if (shouldUpdate) {
        print('🔥 Streak updated -> current: $newStreak (longest: $newLongestStreak, usedGrace: $newUsedGrace)');
        await BadgeService().checkAndUnlockBadges(uid);
      }
    } catch (e) {
      print('❌ Error updating streak: $e');
    }
  }
}
