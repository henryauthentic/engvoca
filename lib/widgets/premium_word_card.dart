import 'package:flutter/material.dart';
import '../models/word.dart';

class PremiumWordCard extends StatelessWidget {
  final Word word;
  final bool isDark;
  final VoidCallback onSpeak;
  final VoidCallback onToggleBookmark;
  final bool isBookmarked;
  final VoidCallback? onTap;

  const PremiumWordCard({
    super.key,
    required this.word,
    required this.isDark,
    required this.onSpeak,
    required this.onToggleBookmark,
    required this.isBookmarked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status
    String statusText;
    Color statusColor;
    Color statusBgColor;

    if (word.isLearned) {
      statusText = 'Đã học';
      statusColor = const Color(0xFF10B981); // Green
      statusBgColor = const Color(0xFF10B981).withOpacity(0.1);
    } else if (word.reviewCount > 0) {
      statusText = 'Đang học';
      statusColor = const Color(0xFF3B82F6); // Blue
      statusBgColor = const Color(0xFF3B82F6).withOpacity(0.1);
    } else {
      statusText = 'Chưa học';
      statusColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      statusBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF8B5CF6).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Icon/Thumb
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book_rounded, // You can make this dynamic if you want
                      size: 28,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Center Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.word,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (word.pronunciation.isNotEmpty)
                        Text(
                          word.pronunciation,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        word.meaning,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Right Side Actions & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons (Audio + Bookmark)
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.volume_up_rounded,
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                          onTap: onSpeak,
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: isBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isBookmarked ? Colors.orange : (isDark ? Colors.white54 : Colors.grey.shade400),
                          isDark: isDark,
                          onTap: onToggleBookmark,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
