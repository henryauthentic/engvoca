class UserWordProgress {
  final String wordId;
  final int status; // 0: New, 1: Learning, 2: Reviewing, 3: Mastered
  final int repetition; // N
  final double easinessFactor; // EF
  final int intervalDays; // I
  final DateTime? nextReviewDate;
  final DateTime? lastReviewDate;
  final int reviewCount;
  final int lapses;

  UserWordProgress({
    required this.wordId,
    this.status = 0,
    this.repetition = 0,
    this.easinessFactor = 2.5,
    this.intervalDays = 0,
    this.nextReviewDate,
    this.lastReviewDate,
    this.reviewCount = 0,
    this.lapses = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'status': status,
      'repetition': repetition,
      'easiness_factor': easinessFactor,
      'interval_days': intervalDays,
      'next_review_date': nextReviewDate?.toIso8601String(),
      'last_review_date': lastReviewDate?.toIso8601String(),
      'review_count': reviewCount,
      'lapses': lapses,
    };
  }

  factory UserWordProgress.fromMap(Map<String, dynamic> map) {
    return UserWordProgress(
      wordId: map['word_id'] as String,
      status: map['status'] as int? ?? 0,
      repetition: map['repetition'] as int? ?? 0,
      easinessFactor: (map['easiness_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: map['interval_days'] as int? ?? 0,
      nextReviewDate: map['next_review_date'] != null
          ? DateTime.parse(map['next_review_date'] as String)
          : null,
      lastReviewDate: map['last_review_date'] != null
          ? DateTime.parse(map['last_review_date'] as String)
          : null,
      reviewCount: map['review_count'] as int? ?? 0,
      lapses: map['lapses'] as int? ?? 0,
    );
  }

  UserWordProgress copyWith({
    String? wordId,
    int? status,
    int? repetition,
    double? easinessFactor,
    int? intervalDays,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    int? reviewCount,
    int? lapses,
  }) {
    return UserWordProgress(
      wordId: wordId ?? this.wordId,
      status: status ?? this.status,
      repetition: repetition ?? this.repetition,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      reviewCount: reviewCount ?? this.reviewCount,
      lapses: lapses ?? this.lapses,
    );
  }
}
