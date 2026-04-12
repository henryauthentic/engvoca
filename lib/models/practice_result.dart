import 'dart:convert';

class PracticeResult {
  final String id;
  final String mode; // 'quiz', 'fill_blank', 'mixed'
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final double accuracy;
  final int xpEarned;
  final int durationSeconds;
  final List<String> topicIds;
  final List<String> topicNames;
  final DateTime createdAt;
  final List<PracticeDetailItem> details;

  PracticeResult({
    required this.id,
    required this.mode,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.accuracy,
    this.xpEarned = 0,
    this.durationSeconds = 0,
    this.topicIds = const [],
    this.topicNames = const [],
    required this.createdAt,
    this.details = const [],
  });

  String get modeLabel {
    switch (mode) {
      case 'quiz': return 'Trắc nghiệm';
      case 'fill_blank': return 'Điền từ';
      case 'mixed': return 'Kết hợp';
      default: return mode;
    }
  }

  String get modeEmoji {
    switch (mode) {
      case 'quiz': return '📝';
      case 'fill_blank': return '✏️';
      case 'mixed': return '🔀';
      default: return '📝';
    }
  }

  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}p${seconds.toString().padLeft(2, '0')}s';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mode': mode,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'accuracy': accuracy,
      'xp_earned': xpEarned,
      'duration_seconds': durationSeconds,
      'topic_ids': jsonEncode(topicIds),
      'topic_names': jsonEncode(topicNames),
      'created_at': createdAt.toIso8601String(),
      'details': jsonEncode(details.map((d) => d.toMap()).toList()),
    };
  }

  factory PracticeResult.fromMap(Map<String, dynamic> map) {
    List<PracticeDetailItem> detailsList = [];
    if (map['details'] != null) {
      try {
        final decoded = jsonDecode(map['details'] as String) as List;
        detailsList = decoded.map((d) => PracticeDetailItem.fromMap(d)).toList();
      } catch (_) {}
    }

    List<String> topicIdsList = [];
    if (map['topic_ids'] != null) {
      try {
        topicIdsList = (jsonDecode(map['topic_ids'] as String) as List).cast<String>();
      } catch (_) {}
    }

    List<String> topicNamesList = [];
    if (map['topic_names'] != null) {
      try {
        topicNamesList = (jsonDecode(map['topic_names'] as String) as List).cast<String>();
      } catch (_) {}
    }

    return PracticeResult(
      id: map['id'] as String,
      mode: map['mode'] as String? ?? 'quiz',
      totalQuestions: map['total_questions'] as int? ?? 0,
      correctCount: map['correct_count'] as int? ?? 0,
      wrongCount: map['wrong_count'] as int? ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      xpEarned: map['xp_earned'] as int? ?? 0,
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      topicIds: topicIdsList,
      topicNames: topicNamesList,
      createdAt: DateTime.parse(map['created_at'] as String),
      details: detailsList,
    );
  }
}

class PracticeDetailItem {
  final String word;
  final String meaning;
  final String correctAnswer;
  final String userAnswer;
  final bool isCorrect;
  final String questionType; // 'quiz' or 'fill_blank'

  PracticeDetailItem({
    required this.word,
    required this.meaning,
    required this.correctAnswer,
    required this.userAnswer,
    required this.isCorrect,
    this.questionType = 'quiz',
  });

  Map<String, dynamic> toMap() => {
    'word': word,
    'meaning': meaning,
    'correctAnswer': correctAnswer,
    'userAnswer': userAnswer,
    'isCorrect': isCorrect,
    'questionType': questionType,
  };

  factory PracticeDetailItem.fromMap(Map<String, dynamic> map) => PracticeDetailItem(
    word: map['word'] as String? ?? '',
    meaning: map['meaning'] as String? ?? '',
    correctAnswer: map['correctAnswer'] as String? ?? '',
    userAnswer: map['userAnswer'] as String? ?? '',
    isCorrect: map['isCorrect'] as bool? ?? false,
    questionType: map['questionType'] as String? ?? 'quiz',
  );
}
