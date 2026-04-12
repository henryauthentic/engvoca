import '../models/user_word_progress.dart';

class SrsService {
  /// SM-2 Algorithm parameters
  static const double _minimumEasinessFactor = 1.3;

  /// Calculate the next review schedule using the SM-2 algorithm
  /// 
  /// [quality] is the user's self-assessed recall quality from 0 to 5:
  /// 5: Perfect response
  /// 4: Correct response after a hesitation
  /// 3: Correct response recalled with serious difficulty
  /// 2: Incorrect response; where the correct one seemed easy to recall
  /// 1: Incorrect response; the correct one remembered
  /// 0: Complete blackout
  static UserWordProgress calculateNextReview(
    int quality,
    UserWordProgress currentProgress,
  ) {
    if (quality < 0) quality = 0;
    if (quality > 5) quality = 5;

    int newRepetition = currentProgress.repetition;
    double newEasinessFactor = currentProgress.easinessFactor;
    int newInterval = currentProgress.intervalDays;
    int newLapses = currentProgress.lapses;

    if (quality >= 3) {
      // Correct response
      if (newRepetition == 0) {
        newInterval = 1;
      } else if (newRepetition == 1) {
        newInterval = 6;
      } else {
        newInterval = (newInterval * newEasinessFactor).round();
      }
      newRepetition++;
    } else {
      // Incorrect response
      newRepetition = 0;
      newInterval = 1;
      newLapses++;
    }

    newEasinessFactor = newEasinessFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEasinessFactor < _minimumEasinessFactor) {
      newEasinessFactor = _minimumEasinessFactor;
    }

    final now = DateTime.now();
    final nextReview = now.add(Duration(days: newInterval));
    
    // Determine new status
    int newStatus = currentProgress.status;
    if (currentProgress.status == 0) {
      newStatus = 1; // From New to Learning
    } else if (currentProgress.status == 1 && quality >= 4) {
      newStatus = 2; // From Learning to Reviewing
    }
    if (newInterval > 60) {
      newStatus = 3; // Mastered
    } else if (newInterval <= 60 && newStatus == 3) {
      newStatus = 2; // Demoted back to Reviewing if forgotten
    }

    return currentProgress.copyWith(
      status: newStatus,
      repetition: newRepetition,
      easinessFactor: newEasinessFactor,
      intervalDays: newInterval,
      nextReviewDate: nextReview,
      lastReviewDate: now,
      reviewCount: currentProgress.reviewCount + 1,
      lapses: newLapses,
    );
  }
}
