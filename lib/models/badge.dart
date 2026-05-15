/// Badge categories for grouping
enum BadgeCategory { vocabulary, streak, special, achievement }

class Badge {
  final String id;
  final String name;
  final String icon; // emoji
  final String description;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final BadgeCategory category;
  final int targetValue;     // mục tiêu (vd: 7 ngày, 100 từ)
  final int currentProgress; // giá trị hiện tại (tính runtime)

  const Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isUnlocked = false,
    this.unlockedAt,
    this.category = BadgeCategory.achievement,
    this.targetValue = 1,
    this.currentProgress = 0,
  });

  Badge copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentProgress,
  }) {
    return Badge(
      id: id,
      name: name,
      icon: icon,
      description: description,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      category: category,
      targetValue: targetValue,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }

  /// Progress ratio (0.0 → 1.0)
  double get progressRatio {
    if (isUnlocked) return 1.0;
    if (targetValue <= 0) return 0.0;
    return (currentProgress / targetValue).clamp(0.0, 1.0);
  }

  /// Whether badge is "in progress" (started but not yet unlocked)
  bool get isInProgress => !isUnlocked && currentProgress > 0;

  /// Serialize for Firebase
  Map<String, dynamic> toMap() {
    return {
      'badge_id': id,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  /// Category display name
  String get categoryName {
    switch (category) {
      case BadgeCategory.vocabulary:
        return '📚 Từ vựng';
      case BadgeCategory.streak:
        return '🔥 Chuỗi ngày';
      case BadgeCategory.special:
        return '⚡ Đặc biệt';
      case BadgeCategory.achievement:
        return '🏅 Thành tích';
    }
  }

  /// All available badges (expanded from 13 → 25)
  static List<Badge> get allBadges => [
    // ═══════════════════════════════════════
    // 📚 VOCABULARY — Từ vựng milestones
    // ═══════════════════════════════════════
    const Badge(
      id: 'first_word',
      name: 'Bước đầu tiên',
      icon: '🐣',
      description: 'Học từ vựng đầu tiên',
      category: BadgeCategory.vocabulary,
      targetValue: 1,
    ),
    const Badge(
      id: 'word_10',
      name: 'Nhà sưu tập',
      icon: '📚',
      description: 'Học được 10 từ vựng',
      category: BadgeCategory.vocabulary,
      targetValue: 10,
    ),
    const Badge(
      id: 'word_50',
      name: 'Thánh từ vựng',
      icon: '🏆',
      description: 'Học được 50 từ vựng',
      category: BadgeCategory.vocabulary,
      targetValue: 50,
    ),
    const Badge(
      id: 'word_100',
      name: 'Bậc thầy ngôn ngữ',
      icon: '🎓',
      description: 'Học được 100 từ vựng',
      category: BadgeCategory.vocabulary,
      targetValue: 100,
    ),
    const Badge(
      id: 'word_200',
      name: 'Kho từ vựng',
      icon: '📖',
      description: 'Học được 200 từ vựng',
      category: BadgeCategory.vocabulary,
      targetValue: 200,
    ),
    const Badge(
      id: 'word_500',
      name: 'Bách khoa toàn thư',
      icon: '🌟',
      description: 'Học được 500 từ vựng',
      category: BadgeCategory.vocabulary,
      targetValue: 500,
    ),
    const Badge(
      id: 'word_1000',
      name: 'Bậc thầy 1000 từ',
      icon: '👑',
      description: 'Học được 1000 từ vựng',
      category: BadgeCategory.vocabulary,
      targetValue: 1000,
    ),

    // ═══════════════════════════════════════
    // 🔥 STREAK — Chuỗi ngày học
    // ═══════════════════════════════════════
    const Badge(
      id: 'streak_3',
      name: 'Kiên trì 3 ngày',
      icon: '🔥',
      description: 'Duy trì chuỗi học 3 ngày liên tiếp',
      category: BadgeCategory.streak,
      targetValue: 3,
    ),
    const Badge(
      id: 'streak_7',
      name: 'Chuỗi 7 ngày',
      icon: '💪',
      description: 'Duy trì chuỗi học 7 ngày liên tiếp',
      category: BadgeCategory.streak,
      targetValue: 7,
    ),
    const Badge(
      id: 'streak_14',
      name: 'Chiến binh 2 tuần',
      icon: '🛡️',
      description: 'Duy trì chuỗi học 14 ngày liên tiếp',
      category: BadgeCategory.streak,
      targetValue: 14,
    ),
    const Badge(
      id: 'streak_30',
      name: 'Chiến binh 30 ngày',
      icon: '⚔️',
      description: 'Duy trì chuỗi học 30 ngày liên tiếp',
      category: BadgeCategory.streak,
      targetValue: 30,
    ),
    const Badge(
      id: 'streak_60',
      name: 'Huyền thoại 60 ngày',
      icon: '🏰',
      description: 'Duy trì chuỗi học 60 ngày liên tiếp',
      category: BadgeCategory.streak,
      targetValue: 60,
    ),
    const Badge(
      id: 'streak_100',
      name: 'Bất khả chiến bại',
      icon: '🐉',
      description: 'Duy trì chuỗi học 100 ngày liên tiếp',
      category: BadgeCategory.streak,
      targetValue: 100,
    ),

    // ═══════════════════════════════════════
    // ⚡ SPECIAL — Thời gian & tình huống đặc biệt
    // ═══════════════════════════════════════
    const Badge(
      id: 'night_owl',
      name: 'Cú đêm',
      icon: '🦉',
      description: 'Học bài lúc 0h - 4h sáng',
      category: BadgeCategory.special,
      targetValue: 1,
    ),
    const Badge(
      id: 'early_bird',
      name: 'Chim sớm',
      icon: '🐦',
      description: 'Học bài lúc 5h - 7h sáng',
      category: BadgeCategory.special,
      targetValue: 1,
    ),
    const Badge(
      id: 'speed_demon',
      name: 'Tốc độ ánh sáng',
      icon: '⚡',
      description: 'Hoàn thành quiz dưới 30 giây',
      category: BadgeCategory.special,
      targetValue: 1,
    ),

    // ═══════════════════════════════════════
    // 🏅 ACHIEVEMENT — Thành tích tổng hợp
    // ═══════════════════════════════════════
    const Badge(
      id: 'perfect_score',
      name: 'Hoàn hảo',
      icon: '💯',
      description: 'Đạt 100% trong bài quiz (≥10 câu)',
      category: BadgeCategory.achievement,
      targetValue: 1,
    ),
    const Badge(
      id: 'story_lover',
      name: 'Mọt truyện',
      icon: '📖',
      description: 'Tạo 5 truyện AI',
      category: BadgeCategory.achievement,
      targetValue: 5,
    ),
    const Badge(
      id: 'chat_master',
      name: 'Bậc thầy hội thoại',
      icon: '💬',
      description: 'Chat 10 cuộc hội thoại AI',
      category: BadgeCategory.achievement,
      targetValue: 10,
    ),
    const Badge(
      id: 'xp_500',
      name: 'Tích lũy 500 XP',
      icon: '⭐',
      description: 'Đạt tổng cộng 500 điểm kinh nghiệm',
      category: BadgeCategory.achievement,
      targetValue: 500,
    ),
    const Badge(
      id: 'xp_1000',
      name: 'Ngôi sao 1000 XP',
      icon: '🌟',
      description: 'Đạt tổng cộng 1000 điểm kinh nghiệm',
      category: BadgeCategory.achievement,
      targetValue: 1000,
    ),
    const Badge(
      id: 'xp_5000',
      name: 'Siêu sao 5000 XP',
      icon: '💎',
      description: 'Đạt tổng cộng 5000 điểm kinh nghiệm',
      category: BadgeCategory.achievement,
      targetValue: 5000,
    ),
    const Badge(
      id: 'quiz_10',
      name: 'Nhà giao tập',
      icon: '📝',
      description: 'Hoàn thành 10 bài quiz',
      category: BadgeCategory.achievement,
      targetValue: 10,
    ),
    const Badge(
      id: 'quiz_50',
      name: 'Vua trắc nghiệm',
      icon: '🎯',
      description: 'Hoàn thành 50 bài quiz',
      category: BadgeCategory.achievement,
      targetValue: 50,
    ),
  ];
}
