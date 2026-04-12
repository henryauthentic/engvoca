class StudySession {
  final String sessionId;
  final DateTime date;
  final int xpEarned;
  final int wordsReviewed;
  final double accuracyRate; // 0.0 to 1.0

  StudySession({
    required this.sessionId,
    required this.date,
    this.xpEarned = 0,
    this.wordsReviewed = 0,
    this.accuracyRate = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'date': date.toIso8601String(),
      'xp_earned': xpEarned,
      'words_reviewed': wordsReviewed,
      'accuracy_rate': accuracyRate,
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      sessionId: map['session_id'] as String,
      date: DateTime.parse(map['date'] as String),
      xpEarned: map['xp_earned'] as int? ?? 0,
      wordsReviewed: map['words_reviewed'] as int? ?? 0,
      accuracyRate: (map['accuracy_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
