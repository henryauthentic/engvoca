import 'package:flutter/material.dart';
import '../models/word.dart';
import '../utils/constants.dart';

class WordTile extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;

  const WordTile({
    super.key,
    required this.word,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: word.isLearned 
                ? AppConstants.secondaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            word.isLearned ? Icons.check_circle : Icons.circle_outlined,
            color: word.isLearned ? AppConstants.secondaryColor : Colors.grey,
          ),
        ),
        title: Text(
          word.word,
          style: AppConstants.titleStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              word.pronunciation,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              word.meaning,
              style: AppConstants.bodyStyle,
            ),
          ],
        ),
        trailing: word.isLearned
            ? Chip(
                label: Text(
                  'x${word.reviewCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppConstants.secondaryColor,
                padding: EdgeInsets.zero,
              )
            : null,
      ),
    );
  }
}