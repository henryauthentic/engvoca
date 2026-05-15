import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/topic.dart';
import '../services/topic_image_service.dart';
import '../utils/topic_icons.dart';

class ChildTopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;
  final bool isDark;

  const ChildTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (topic.imageUrl == null && topic.id != null) {
      TopicImageService.resolveAndSaveUrl(topic.id!, topic.name);
    }
    final imageUrlToShow = topic.imageUrl ?? TopicImageService.buildTempUrl(topic.name);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF8B5CF6).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon / Image with tinted background
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: imageUrlToShow,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            TopicIcons.get(topic.name),
                            size: 24,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topic.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Arrow Right
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom Progress Bar
                Row(
                  children: [
                    Text(
                      '${topic.learnedCount} / ${topic.wordCount} từ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: topic.progress > 0 
                            ? const Color(0xFF8B5CF6).withOpacity(0.1) 
                            : isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(topic.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: topic.progress > 0 ? const Color(0xFF8B5CF6) : (isDark ? Colors.white54 : Colors.grey.shade500),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: topic.wordCount > 0 ? topic.learnedCount / topic.wordCount : 0,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)), // Purple
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
