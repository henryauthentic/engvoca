import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/topic.dart';
import '../utils/constants.dart';
import '../utils/topic_icons.dart';
import '../theme/theme_extensions.dart';
import '../services/topic_image_service.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;

  const TopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  String? _getLocalImagePath(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('từ vựng cơ bản')) return 'assets/images/topics/topic_basic_vocab.png';
    if (lowerName.contains('ielts')) return 'assets/images/topics/topic_ielts.png';
    if (lowerName.contains('toeic')) return 'assets/images/topics/topic_toeic.png';
    if (lowerName.contains('b1') || lowerName.contains('b2')) return 'assets/images/topics/topic_level_b.png';
    if (lowerName.contains('c1') || lowerName.contains('c2')) return 'assets/images/topics/topic_level_c.png';
    if (lowerName.contains('công nghệ')) return 'assets/images/topics/topic_technology.png';
    if (lowerName.contains('công việc')) return 'assets/images/topics/topic_business.png';
    if (lowerName.contains('du lịch')) return 'assets/images/topics/topic_travel.png';
    if (lowerName.contains('sức khỏe')) return 'assets/images/topics/topic_health.png';
    if (lowerName.contains('học thuật')) return 'assets/images/topics/topic_academic.png';
    if (lowerName.contains('lớp')) return 'assets/images/topics/topic_school.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Nếu topic chưa có imageUrl (bản lưu DB thật), ta trigger background resolve
    if (topic.imageUrl == null && topic.id != null) {
      TopicImageService.resolveAndSaveUrl(topic.id!, topic.name);
    }

    final imageUrlToShow = topic.imageUrl ?? TopicImageService.buildTempUrl(topic.name);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      child: CachedNetworkImage(
                        imageUrl: imageUrlToShow,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          'assets/images/topics/topic_basic_vocab.png', // Temporary fallback if asset not found
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(TopicIcons.get(topic.name), size: 28, color: AppConstants.primaryColor),
                        ),
                      ),
                    ),
                    ), // Center
                  ), // Container
                  const SizedBox(width: AppConstants.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.name,
                          style: AppConstants.titleStyle.copyWith(
                            fontSize: 18,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic.description,
                          style: AppConstants.subtitleStyle.copyWith(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${topic.learnedCount}/${topic.wordCount} từ',
                          style: AppConstants.bodyStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: topic.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppConstants.secondaryColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(topic.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}