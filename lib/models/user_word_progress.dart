import 'package:cloud_firestore/cloud_firestore.dart';

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
  final DateTime? firstLearnedDate; // set when status goes 0→1+
  final DateTime? updatedAt;
  final DateTime? syncedAt;
  
  // Adaptive Learning (Difficult Words System)
  final bool isDifficult;
  final int wrongCount;
  final DateTime? lastSeenAt;

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
    this.firstLearnedDate,
    this.updatedAt,
    this.syncedAt,
    this.isDifficult = false,
    this.wrongCount = 0,
    this.lastSeenAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'status': status,
      'repetition': repetition,
      'easiness_factor': easinessFactor,
      'interval_days': intervalDays,
      // ✅ Always convert to LOCAL time before storing as ISO string
      // This ensures consistency with SQLite queries that use DateTime.now() (local)
      'next_review_date': nextReviewDate?.toLocal().toIso8601String(),
      'last_review_date': lastReviewDate?.toLocal().toIso8601String(),
      'review_count': reviewCount,
      'lapses': lapses,
      'first_learned_date': firstLearnedDate?.toLocal().toIso8601String(),
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
      'is_difficult': isDifficult ? 1 : 0,
      'wrong_count': wrongCount,
      'last_seen_at': lastSeenAt?.toLocal().toIso8601String(),
    };
  }

  // Chuẩn hóa cho Firebase
  Map<String, dynamic> toFirebaseMap() {
    return {
      'wordId': wordId,
      'status': status,
      'repetition': repetition,
      'easinessFactor': easinessFactor,
      'intervalDays': intervalDays,
      'nextReviewDate': nextReviewDate != null ? Timestamp.fromDate(nextReviewDate!) : null,
      'lastReviewDate': lastReviewDate != null ? Timestamp.fromDate(lastReviewDate!) : null,
      'reviewCount': reviewCount,
      'lapses': lapses,
      'firstLearnedDate': firstLearnedDate != null ? Timestamp.fromDate(firstLearnedDate!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'syncedAt': FieldValue.serverTimestamp(),
      'isDifficult': isDifficult,
      'wrongCount': wrongCount,
      'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
    };
  }

  static DateTime? _parseDate(dynamic snakeVal, dynamic camelVal) {
    // Prefer camelCase if it exists
    final val = camelVal ?? snakeVal;
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory UserWordProgress.fromMap(Map<String, dynamic> map) {
    return UserWordProgress(
      wordId: map['wordId'] as String? ?? map['word_id'] as String? ?? '',
      status: map['status'] as int? ?? 0,
      repetition: map['repetition'] as int? ?? 0,
      easinessFactor: (map['easinessFactor'] as num?)?.toDouble() ?? (map['easiness_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: map['intervalDays'] as int? ?? map['interval_days'] as int? ?? 0,
      nextReviewDate: _parseDate(map['next_review_date'], map['nextReviewDate']),
      lastReviewDate: _parseDate(map['last_review_date'], map['lastReviewDate']),
      reviewCount: map['reviewCount'] as int? ?? map['review_count'] as int? ?? 0,
      lapses: map['lapses'] as int? ?? 0,
      firstLearnedDate: _parseDate(map['first_learned_date'], map['firstLearnedDate']),
      updatedAt: _parseDate(map['updated_at'], map['updatedAt']),
      syncedAt: _parseDate(map['synced_at'], map['syncedAt']),
      isDifficult: map['isDifficult'] == true || map['is_difficult'] == 1,
      wrongCount: map['wrongCount'] as int? ?? map['wrong_count'] as int? ?? 0,
      lastSeenAt: _parseDate(map['last_seen_at'], map['lastSeenAt']),
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
    DateTime? firstLearnedDate,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDifficult,
    int? wrongCount,
    DateTime? lastSeenAt,
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
      firstLearnedDate: firstLearnedDate ?? this.firstLearnedDate,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isDifficult: isDifficult ?? this.isDifficult,
      wrongCount: wrongCount ?? this.wrongCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
