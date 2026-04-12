class Topic {
  final String? id;
  final String name;
  final String description;
  final String? iconUrl;  // icon_url from database
  final String? colorHex;  // color_hex from database
  final int totalWords;   // totar_words from database
  final int learnedWords; // learned_words from database
  final bool isUnlocked;  // is_unlocked from database
  final int orderIndex;   // order_index from database

  Topic({
    this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    this.colorHex,
    this.totalWords = 0,
    this.learnedWords = 0,
    this.isUnlocked = true,
    this.orderIndex = 0,
  });

  // For backward compatibility with UI
  String get iconName => iconUrl ?? '📚';
  int get wordCount => totalWords;
  int get learnedCount => learnedWords;

  double get progress => totalWords > 0 ? learnedWords / totalWords : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'color_hex': colorHex,
      'totar_words': totalWords,
      'learned_words': learnedWords,
      'is_unlocked': isUnlocked ? 1 : 0,
      'order_index': orderIndex,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map) {
    // Try multiple possible column names for total_words
    int totalWords = 0;
    if (map.containsKey('total_words')) {
      totalWords = map['total_words'] as int? ?? 0;
    } else if (map.containsKey('totar_words')) {
      totalWords = map['totar_words'] as int? ?? 0;
    } else if (map.containsKey('wordCount')) {
      totalWords = map['wordCount'] as int? ?? 0;
    }
    
    // Try multiple possible column names for learned_words
    int learnedWords = 0;
    if (map.containsKey('learned_words')) {
      learnedWords = map['learned_words'] as int? ?? 0;
    } else if (map.containsKey('learnedCount')) {
      learnedWords = map['learnedCount'] as int? ?? 0;
    }
    
    return Topic(
      id: map['id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      iconUrl: map['icon_url'] as String?,
      colorHex: map['color_hex'] as String?,
      totalWords: totalWords,
      learnedWords: learnedWords,
      isUnlocked: (map['is_unlocked'] as int?) == 1,
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }

  Topic copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? colorHex,
    int? totalWords,
    int? learnedWords,
    bool? isUnlocked,
    int? orderIndex,
  }) {
    return Topic(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      colorHex: colorHex ?? this.colorHex,
      totalWords: totalWords ?? this.totalWords,
      learnedWords: learnedWords ?? this.learnedWords,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}