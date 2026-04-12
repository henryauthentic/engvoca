import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../models/user.dart';
import 'badge_service.dart';

class GamificationService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> addXp(String userId, int xpToAdd) async {
    try {
      final userMap = await _dbHelper.getLocalUser(userId);
      if (userMap == null) return;

      User localUser = User.fromMap(userMap);
      
      int newXp = localUser.totalXp + xpToAdd;
      // Công thức tính level (Ví dụ: Level = căn bậc 2 của (totalXp / 100) + 1)
      int newLevel = (newXp / 100).truncate() + 1; // Formula đơn giản

      final updatedUser = localUser.copyWith(
        totalXp: newXp,
        level: newLevel,
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

  Future<void> updateStreak(String userId) async {
    try {
      final userMap = await _dbHelper.getLocalUser(userId);
      if (userMap == null) {
        print('⚠️ updateStreak: user not found in local DB');
        return;
      }

      User localUser = User.fromMap(userMap);
      
      final now = DateTime.now();
      final lastActive = localUser.lastLoginAt ?? now.subtract(const Duration(days: 2));

      final todayDate = DateTime(now.year, now.month, now.day);
      final lastDate = DateTime(lastActive.year, lastActive.month, lastActive.day);
      final difference = todayDate.difference(lastDate).inDays;

      print('🔥 Streak check: today=$todayDate, lastActive=$lastDate, diff=$difference, currentStreak=${localUser.currentStreak}');

      int newStreak = localUser.currentStreak;
      int newLongestStreak = localUser.longestStreak;

      if (difference == 1) {
        // Học ngày tiếp theo → tăng streak
        newStreak++;
        print('🔥 Streak incremented: $newStreak');
      } else if (difference > 1) {
        // Bỏ lỡ ngày → reset
        newStreak = 1;
        print('🔥 Streak reset to 1 (missed ${difference - 1} days)');
      } else if (difference == 0 && newStreak == 0) {
        // Ngày đầu tiên học
        newStreak = 1;
        print('🔥 First day streak: 1');
      } else {
        // Vẫn trong cùng 1 ngày, không thay đổi
        print('🔥 Same day, streak unchanged: $newStreak');
        return;
      }

      if (newStreak > newLongestStreak) {
        newLongestStreak = newStreak;
      }

      final updatedUser = localUser.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
        lastLoginAt: now,
      );

      // Save locally - PASS lastLoginDate so it gets saved correctly
      await _dbHelper.upsertUser(
        id: updatedUser.id,
        name: updatedUser.displayName,
        email: updatedUser.email,
        avatarUrl: updatedUser.avatar,
        level: updatedUser.level,
        totalPoints: updatedUser.totalXp,
        wordsLearned: updatedUser.learnedWords,
        streakDays: updatedUser.currentStreak,
        lastLoginDate: now,
      );

      // Save to Firebase
      await _firebaseService.updateUser(updatedUser);

      print('🔥 Streak updated: $newStreak (longest: $newLongestStreak)');

      // Check for new badges
      await BadgeService().checkAndUnlockBadges(userId);
    } catch (e) {
      print('❌ Error updating streak: $e');
    }
  }
}
