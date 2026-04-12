import 'package:flutter/material.dart' hide Badge;
import 'package:lottie/lottie.dart';
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

class _BadgesScreenState extends State<BadgesScreen> {
  List<Badge> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
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

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Huy hiệu'),
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
                  '$unlockedCount/${_badges.length}',
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
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(AppConstants.paddingMedium),
                  padding: const EdgeInsets.all(AppConstants.paddingLarge),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700),
                        const Color(0xFFFFA500),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lottie/Award Badge.json',
                        height: 80,
                        repeat: true,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bộ sưu tập huy hiệu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đã mở khóa $unlockedCount/${_badges.length} huy hiệu',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _badges.isEmpty ? 0 : unlockedCount / _badges.length,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

                // Badge grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _badges.length,
                    itemBuilder: (context, index) {
                      return _buildBadgeItem(_badges[index], index);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBadgeItem(Badge badge, int index) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: badge.isUnlocked
              ? context.cardColor
              : context.subtleBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.isUnlocked
                ? const Color(0xFFFFD700).withOpacity(0.5)
                : context.dividerColor,
            width: badge.isUnlocked ? 2 : 1,
          ),
          boxShadow: badge.isUnlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Text(
              badge.isUnlocked ? badge.icon : '🔒',
              style: TextStyle(
                fontSize: badge.isUnlocked ? 40 : 32,
              ),
            ),
            const SizedBox(height: 8),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                badge.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked
                      ? context.textPrimary
                      : context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 60).ms)
     .fadeIn(duration: 300.ms)
     .scale(begin: const Offset(0.8, 0.8));
  }

  void _showBadgeDetail(Badge badge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            // Badge icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: badge.isUnlocked
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      )
                    : null,
                color: badge.isUnlocked ? null : context.subtleBackground,
                shape: BoxShape.circle,
                boxShadow: badge.isUnlocked
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  badge.isUnlocked ? badge.icon : '🔒',
                  style: const TextStyle(fontSize: 44),
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
            // Description
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badge.isUnlocked
                    ? Colors.green.withOpacity(0.1)
                    : context.subtleBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.isUnlocked
                    ? '✅ Đã mở khóa • ${DateFormat('dd/MM/yyyy').format(badge.unlockedAt!)}'
                    : '🔒 Chưa mở khóa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked
                      ? Colors.green
                      : context.textTertiary,
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
