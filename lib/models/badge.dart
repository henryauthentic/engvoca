class Badge {
  final String id;
  final String name;
  final String icon; // emoji
  final String description;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Badge copyWith({bool? isUnlocked, DateTime? unlockedAt}) {
    return Badge(
      id: id,
      name: name,
      icon: icon,
      description: description,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  /// All available badges
  static List<Badge> get allBadges => [
    const Badge(
      id: 'first_word',
      name: 'Bước đầu tiên',
      icon: '🐣',
      description: 'Học từ vựng đầu tiên',
    ),
    const Badge(
      id: 'word_10',
      name: 'Nhà sưu tập',
      icon: '📚',
      description: 'Học được 10 từ vựng',
    ),
    const Badge(
      id: 'word_50',
      name: 'Thánh từ vựng',
      icon: '🏆',
      description: 'Học được 50 từ vựng',
    ),
    const Badge(
      id: 'word_100',
      name: 'Bậc thầy ngôn ngữ',
      icon: '🎓',
      description: 'Học được 100 từ vựng',
    ),
    const Badge(
      id: 'streak_3',
      name: 'Kiên trì 3 ngày',
      icon: '🔥',
      description: 'Duy trì chuỗi học 3 ngày liên tiếp',
    ),
    const Badge(
      id: 'streak_7',
      name: 'Chuỗi 7 ngày',
      icon: '💪',
      description: 'Duy trì chuỗi học 7 ngày liên tiếp',
    ),
    const Badge(
      id: 'streak_30',
      name: 'Chiến binh 30 ngày',
      icon: '⚔️',
      description: 'Duy trì chuỗi học 30 ngày liên tiếp',
    ),
    const Badge(
      id: 'night_owl',
      name: 'Cú đêm',
      icon: '🦉',
      description: 'Học bài lúc 0h - 4h sáng',
    ),
    const Badge(
      id: 'early_bird',
      name: 'Chim sớm',
      icon: '🐦',
      description: 'Học bài lúc 5h - 7h sáng',
    ),
    const Badge(
      id: 'speed_demon',
      name: 'Tốc độ ánh sáng',
      icon: '⚡',
      description: 'Hoàn thành quiz dưới 30 giây',
    ),
    const Badge(
      id: 'perfect_score',
      name: 'Hoàn hảo',
      icon: '💯',
      description: 'Đạt 100% trong bài quiz (≥10 câu)',
    ),
    const Badge(
      id: 'story_lover',
      name: 'Mọt truyện',
      icon: '📖',
      description: 'Tạo 5 truyện AI',
    ),
    const Badge(
      id: 'chat_master',
      name: 'Bậc thầy hội thoại',
      icon: '💬',
      description: 'Chat 10 cuộc hội thoại AI',
    ),
  ];
}
