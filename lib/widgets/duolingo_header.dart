import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/user.dart';

class DuolingoHeader extends StatelessWidget {
  final User? user;

  const DuolingoHeader({
    super.key,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 140 + topPadding, // 🔒 GIỮ NGUYÊN KÍCH THƯỚC NỀN
      padding: EdgeInsets.only(
        top: topPadding + 14,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF6C63FF), // tím hiện tại của bạn
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.local_fire_department,
                color: Colors.orangeAccent,
                value: '${user?.currentStreak ?? 0}',
                label: 'Streak',
              ),
              // 🐱 MÈO – Ở GIỮA
              SizedBox(
                height: 56,
                child: Lottie.asset(
                  'assets/animations/cat_learning.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
              _buildStatItem(
                icon: Icons.star,
                color: Colors.amber,
                value: '${user?.totalXp ?? 0}',
                label: 'XP',
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ✨ LEVEL & WELCOME
          Text(
            user != null ? 'Cấp độ ${user!.level}' : 'ENG VOCA',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
              shadows: const [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 6,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
