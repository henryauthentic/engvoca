import 'dart:math';

class LevelService {
  static const int _a1Threshold = 100;
  static const int _a2Threshold = 500;
  static const int _b1Threshold = 1500;
  static const int _b2Threshold = 3000;

  /// Returns the effective score based on learned words and memory accuracy.
  static double calculateEffectiveScore(int wordsLearned, double memoryAccuracy) {
    return wordsLearned * memoryAccuracy;
  }

  /// Returns the CEFR level ID (e.g., 'a1', 'a2', 'b1', 'b2', 'c1').
  static String getLevelId(double score) {
    if (score < _a1Threshold) return 'a1';
    if (score < _a2Threshold) return 'a2';
    if (score < _b1Threshold) return 'b1';
    if (score < _b2Threshold) return 'b2';
    return 'c1';
  }

  /// Returns the localized, user-friendly label for the level.
  static String getLevelLabel(String levelId) {
    switch (levelId) {
      case 'a1': return 'A1 · Sơ cấp';
      case 'a2': return 'A2 · Tiền trung cấp';
      case 'b1': return 'B1 · Trung cấp';
      case 'b2': return 'B2 · Tiền cao cấp';
      case 'c1': return 'C1 · Cao cấp';
      default: return 'A1 · Sơ cấp';
    }
  }

  /// Calculates the progress percentage (0.0 to 1.0) towards the next level.
  static double getProgressToNextLevel(double score) {
    if (score < _a1Threshold) {
      return score / _a1Threshold;
    } else if (score < _a2Threshold) {
      return (score - _a1Threshold) / (_a2Threshold - _a1Threshold);
    } else if (score < _b1Threshold) {
      return (score - _a2Threshold) / (_b1Threshold - _a2Threshold);
    } else if (score < _b2Threshold) {
      return (score - _b1Threshold) / (_b2Threshold - _b1Threshold);
    } else {
      return 1.0; // Max level reached
    }
  }

  /// Returns the target score for the next level.
  static int getNextLevelTarget(double score) {
    if (score < _a1Threshold) return _a1Threshold;
    if (score < _a2Threshold) return _a2Threshold;
    if (score < _b1Threshold) return _b1Threshold;
    if (score < _b2Threshold) return _b2Threshold;
    return _b2Threshold; // Max level target is self
  }
}
