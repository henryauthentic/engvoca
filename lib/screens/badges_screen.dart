import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import '../models/badge.dart';
import '../services/badge_service.dart';
import '../db/database_helper.dart';
import '../theme/theme_extensions.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  List<Badge> _badges = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBadges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    final userId = DatabaseHelper.instance.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Check for new badges first
    await BadgeService().checkAndUnlockBadges(userId);

    final badges = await BadgeService().getAllBadges(userId);
    setState(() {
      _badges = badges;
      _isLoading = false;
    });
  }

  List<Badge> get _filteredBadges {
    switch (_tabController.index) {
      case 1: // Đang tiến hành
        return _badges.where((b) => b.isInProgress).toList();
      case 2: // Đã đạt
        return _badges.where((b) => b.isUnlocked).toList();
      default: // Tất cả
        return _badges;
    }
  }

  int get _unlockedCount => _badges.where((b) => b.isUnlocked).length;

  String get _motivationalText {
    final remaining = _badges.length - _unlockedCount;
    final ratio = _badges.isEmpty ? 0.0 : _unlockedCount / _badges.length;

    if (ratio >= 1.0) return 'Bạn đã sưu tập tất cả! 🎉';
    if (ratio >= 0.9) return 'Gần hoàn thành! Chỉ còn $remaining huy hiệu! 🔥';
    if (ratio >= 0.5) return 'Tuyệt vời! Đã đi được nửa đường! 💪';
    if (ratio >= 0.25) return 'Tiếp tục phát huy nhé! ⭐';
    return 'Thu thập thêm $remaining huy hiệu nữa nhé!';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F5FA),
      appBar: AppBar(
        title: const Text('Huy hiệu', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F5FA),
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_unlockedCount/${_badges.length}',
                  style: TextStyle(
                    color: context.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ═══ HEADER CARD ═══
                SliverToBoxAdapter(
                  child: _buildHeader(isDark),
                ),

                // ═══ TAB BAR ═══
                SliverToBoxAdapter(
                  child: _buildTabBar(isDark),
                ),

                // ═══ BADGE GRID ═══
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: _buildCategorizedGrid(isDark),
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // HEADER — Gradient card with progress
  // ═══════════════════════════════════════════
  Widget _buildHeader(bool isDark) {
    final progress = _badges.isEmpty ? 0.0 : _unlockedCount / _badges.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiến trình huy hiệu',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_unlockedCount / ${_badges.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _motivationalText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: trophy
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🏆', style: TextStyle(fontSize: 40)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.15, end: 0);
  }

  // ═══════════════════════════════════════════
  // TAB BAR — Tất cả / Đang tiến hành / Đã đạt
  // ═══════════════════════════════════════════
  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? context.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        labelColor: context.primaryColor,
        unselectedLabelColor: context.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorColor: context.primaryColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'Tất cả (${_badges.length})'),
          Tab(text: 'Đang tiến hành (${_badges.where((b) => b.isInProgress).length})'),
          Tab(text: 'Đã đạt ($_unlockedCount)'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BADGE GRID — Grouped by category
  // ═══════════════════════════════════════════
  Widget _buildCategorizedGrid(bool isDark) {
    final filtered = _filteredBadges;

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Text('🏅', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                _tabController.index == 1
                    ? 'Chưa có huy hiệu đang tiến hành'
                    : 'Chưa có huy hiệu nào',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group by category
    final categories = BadgeCategory.values;
    final List<Widget> sections = [];

    for (final cat in categories) {
      final badgesInCat = filtered.where((b) => b.category == cat).toList();
      if (badgesInCat.isEmpty) continue;

      // Section header
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            badgesInCat.first.categoryName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ),
      );

      // Grid of badges
      sections.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: badgesInCat.length,
          itemBuilder: (context, index) {
            return _buildBadgeItem(badgesInCat[index], index);
          },
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate(sections),
    );
  }

  // ═══════════════════════════════════════════
  // BADGE ITEM — 3 states: unlocked / progress / locked
  // ═══════════════════════════════════════════
  Widget _buildBadgeItem(Badge badge, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: badge.isUnlocked
              ? (isDark ? context.surfaceColor : Colors.white)
              : (isDark
                  ? context.surfaceColor.withOpacity(0.5)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.isUnlocked
                ? context.primaryColor.withOpacity(0.4)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            width: badge.isUnlocked ? 2 : 1,
          ),
          boxShadow: badge.isUnlocked
              ? [
                  BoxShadow(
                    color: context.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Text(
                    badge.isUnlocked ? badge.icon : '🔒',
                    style: TextStyle(
                      fontSize: badge.isUnlocked ? 36 : 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Name
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badge.isUnlocked
                          ? context.textPrimary
                          : context.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Progress indicator for in-progress badges
                  if (badge.isInProgress) ...[
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: badge.progressRatio,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(
                            context.primaryColor.withOpacity(0.7)),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${badge.currentProgress}/${badge.targetValue}',
                      style: TextStyle(
                        fontSize: 9,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  // Checkmark for unlocked
                  if (badge.isUnlocked && !badge.isInProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF22C55E),
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
            // Lock overlay for locked badges
            if (!badge.isUnlocked && !badge.isInProgress)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white)
                        .withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate(delay: (index * 50).ms)
     .fadeIn(duration: 300.ms)
     .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
  }

  // ═══════════════════════════════════════════
  // BADGE DETAIL — Bottom sheet
  // ═══════════════════════════════════════════
  void _showBadgeDetail(Badge badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Badge icon in circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: badge.isUnlocked
                    ? const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                      )
                    : null,
                color: badge.isUnlocked
                    ? null
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                shape: BoxShape.circle,
                boxShadow: badge.isUnlocked
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  badge.isUnlocked ? badge.icon : '🔒',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Description (điều kiện mở khóa)
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Progress bar (nếu đang tiến hành)
            if (!badge.isUnlocked && badge.targetValue > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${badge.currentProgress}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.primaryColor,
                    ),
                  ),
                  Text(
                    ' / ${badge.targetValue}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: badge.progressRatio,
                    backgroundColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(context.primaryColor),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badge.isUnlocked
                    ? const Color(0xFF22C55E).withOpacity(0.1)
                    : (badge.isInProgress
                        ? context.primaryColor.withOpacity(0.1)
                        : context.subtleBackground),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.isUnlocked
                    ? '✅ Đã mở khóa • ${DateFormat('dd/MM/yyyy').format(badge.unlockedAt!)}'
                    : (badge.isInProgress
                        ? '🔄 Đang tiến hành'
                        : '🔒 Chưa mở khóa'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked
                      ? const Color(0xFF22C55E)
                      : (badge.isInProgress
                          ? context.primaryColor
                          : context.textTertiary),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
