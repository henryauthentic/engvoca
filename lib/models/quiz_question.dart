class QuizQuestion {
  final String wordId;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? imageUrl;

  QuizQuestion({
    required this.wordId,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.imageUrl,
  });

  String get correctAnswer => options[correctAnswerIndex];

  bool isCorrect(int selectedIndex) => selectedIndex == correctAnswerIndex;

  Map<String, dynamic> toMap() {
    return {
      'wordId': wordId,
      'question': question,
      'options': options.join('|||'),
      'correctAnswerIndex': correctAnswerIndex,
      'imageUrl': imageUrl,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      wordId: map['wordId'] as String,
      question: map['question'] as String,
      options: (map['options'] as String).split('|||'),
      correctAnswerIndex: map['correctAnswerIndex'] as int,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}

enum QuizType {
  meaningToWord,
  wordToMeaning,
  listening,
  mixed,
}