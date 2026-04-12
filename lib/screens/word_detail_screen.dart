import 'package:flutter/material.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/primary_button.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final _dbHelper = DatabaseHelper.instance;
  late Word _word;

  @override
  void initState() {
    super.initState();
    _word = widget.word;
  }

  Future<void> _toggleLearned() async {
    try {
      if (!_word.isLearned) {
        await _dbHelper.markWordAsLearned(_word.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đánh dấu là đã học!'),
              backgroundColor: AppConstants.secondaryColor,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
      
      final updatedWord = await _dbHelper.getWord(_word.id!);
      setState(() {
        _word = updatedWord;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'Chưa học';
    
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} ngày trước';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết từ vựng'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingLarge * 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.primaryColor,
                    context.primaryColor.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _word.word,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Text(
                    _word.pronunciation,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (_word.isLearned) ...[
                    const SizedBox(height: AppConstants.paddingMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMedium,
                        vertical: AppConstants.paddingSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Đã học',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Nghĩa',
                    icon: Icons.translate,
                    content: _word.meaning,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppConstants.paddingLarge),
                  _buildSection(
                    title: 'Ví dụ',
                    icon: Icons.format_quote,
                    content: _word.example,
                    isDark: isDark,
                  ),
                  if (_word.learnedAt != null && _word.learnedAt!.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.paddingLarge),
                    _buildSection(
                      title: 'Thời gian học',
                      icon: Icons.access_time,
                      content: _formatDateTime(_word.learnedAt),
                      isDark: isDark,
                    ),
                  ],
                  const SizedBox(height: AppConstants.paddingLarge * 2),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      onPressed: _word.isLearned ? null : _toggleLearned,
                      icon: Icon(
                        _word.isLearned ? Icons.check_circle : Icons.check_circle_outline,
                      ),
                      text: _word.isLearned ? 'Đã học' : 'Đánh dấu đã học',
                      backgroundColor: _word.isLearned 
                          ? (isDark ? Colors.grey[700] : AppConstants.secondaryColor)
                          : context.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: context.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        AppCard(
          color: context.subtleBackground,
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: context.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}