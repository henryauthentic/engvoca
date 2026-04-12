class Word {
  final String? id;
  final String word;
  final String pronunciation;
  final String meaning;
  final String example;
  final String? imageUrl;
  final String? audioUrl;
  final String topicId;
  final bool isFavorite;
  final bool isLearned; // true = đã học (DB: 0)
  final int difficultyLevel;
  final String? createdAt;
  final String? learnedAt;
  final int reviewCount;

  Word({
    this.id,
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.example,
    this.imageUrl,
    this.audioUrl,
    required this.topicId,
    this.isFavorite = false,
    this.isLearned = false,
    this.difficultyLevel = 1,
    this.createdAt,
    this.learnedAt,
    this.reviewCount = 0,
  });

  /// ================================
  /// Convert Object -> Map (save to DB)
  /// ================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'pronunciation': pronunciation,
      'meaning': meaning,
      'example': example,
      'image_url': imageUrl,
      'audio_url': audioUrl,
      'a_topic_id': topicId,

      // 1 = favorite, 0 = not
      'is_favorite': isFavorite ? 1 : 0,

      // NEW LOGIC:
      // isLearned = true  -> 0
      // isLearned = false -> 1
      'is_learned': isLearned ? 0 : 1,

      'difficulty_level': difficultyLevel,
      'created_at': createdAt,
      'learned_at': learnedAt,
    };
  }

  /// ================================
  /// Convert Map -> Object (read from DB)
  /// ================================
  factory Word.fromMap(Map<String, dynamic> map) {
    // Parse topic ID (multiple possible column names)
    final String topicId =
        map['topic_id']?.toString() ??
        map['a_topic_id']?.toString() ??
        map['topicId']?.toString() ??
        '';

    // Parse favorite (1 = true)
    bool isFavorite = false;
    final fav = map['is_favorite'];
    if (fav is int) isFavorite = fav == 1;
    if (fav is String) isFavorite = fav == '1';

    // Parse learned (NEW LOGIC)
    // 0 = đã học → true
    // 1 = chưa học → false
    bool isLearned = false;
    final learned = map['is_learned'];
    if (learned is int) isLearned = learned == 0;
    if (learned is String) isLearned = learned == '0';

    return Word(
      id: map['id']?.toString(),
      word: map['word'] ?? '',
      pronunciation: map['pronunciation'] ?? '',
      meaning: map['meaning'] ?? '',
      example: map['example'] ?? '',
      imageUrl: map['image_url'],
      audioUrl: map['audio_url'],
      topicId: topicId,
      isFavorite: isFavorite,
      isLearned: isLearned,
      difficultyLevel: map['difficulty_level'] is int
          ? map['difficulty_level']
          : int.tryParse(map['difficulty_level']?.toString() ?? '1') ?? 1,
      createdAt: map['created_at'],
      learnedAt: map['learned_at'],
      reviewCount: 0,
    );
  }

  /// ================================
  /// CopyWith
  /// ================================
  Word copyWith({
    String? id,
    String? word,
    String? pronunciation,
    String? meaning,
    String? example,
    String? imageUrl,
    String? audioUrl,
    String? topicId,
    bool? isFavorite,
    bool? isLearned,
    int? difficultyLevel,
    String? createdAt,
    String? learnedAt,
    int? reviewCount,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      pronunciation: pronunciation ?? this.pronunciation,
      meaning: meaning ?? this.meaning,
      example: example ?? this.example,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      topicId: topicId ?? this.topicId,
      isFavorite: isFavorite ?? this.isFavorite,
      isLearned: isLearned ?? this.isLearned,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      createdAt: createdAt ?? this.createdAt,
      learnedAt: learnedAt ?? this.learnedAt,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}
