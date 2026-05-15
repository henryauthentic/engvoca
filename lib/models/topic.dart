class Topic {
  final String? id;
  final String name;
  final String description;
  final String? iconUrl;
  final String? colorHex;
  final int totalWords;
  final int learnedWords;
  final bool isUnlocked;
  final int orderIndex;
  final String? parentId; // null = topic cha, có giá trị = topic con
  final String? imageUrl;

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
    this.parentId,
    this.imageUrl,
  });

  // ── Helpers ──────────────────────────────────────
  String get iconName => iconUrl ?? '📚';
  int get wordCount => totalWords;
  int get learnedCount => learnedWords;
  double get progress => totalWords > 0 ? learnedWords / totalWords : 0.0;

  /// true nếu đây là topic CHA (Basic, IELTS, B1, B2, C1, C2)
  bool get isParent => parentId == null;

  /// true nếu đây là topic CON (Gia đình, Du lịch, ...)
  bool get isChild => parentId != null;

  // ── DB ───────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'color_hex': colorHex,
      'total_words': totalWords,
      'learned_words': learnedWords,
      'is_unlocked': isUnlocked ? 1 : 0,
      'order_index': orderIndex,
      'parent_id': parentId,
      'image_url': imageUrl,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map) {
    int totalWords = 0;
    if (map.containsKey('total_words')) {
      totalWords = map['total_words'] as int? ?? 0;
    } else if (map.containsKey('totar_words')) {
      totalWords = map['totar_words'] as int? ?? 0;
    } else if (map.containsKey('wordCount')) {
      totalWords = map['wordCount'] as int? ?? 0;
    }

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
      isUnlocked: (map['is_unlocked'] as int? ?? map['isUnlocked'] as int? ?? 1) == 1,
      orderIndex: map['order_index'] as int? ?? map['orderIndex'] as int? ?? 0,
      parentId: map['parent_id'] as String? ?? map['parentId'] as String?,
      imageUrl: map['image_url'] as String? ?? map['imageUrl'] as String?,
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
    String? parentId,
    String? imageUrl,
    bool clearParentId = false, // ← dùng để set parentId = null
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
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}