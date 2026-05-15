import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../utils/topic_icons.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import '../widgets/common/app_card.dart';
import 'review_screen.dart';

class LearningModeScreen extends StatefulWidget {
  final Topic topic;

  const LearningModeScreen({super.key, required this.topic});

  @override
  State<LearningModeScreen> createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen> {
  final _dbHelper = DatabaseHelper.instance;
  int _totalWords = 0;
  int _learnedWords = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final words = await _dbHelper.getWordsByTopic(widget.topic.id!);
      final learned = words.where((w) => w.isLearned).length;
      
      setState(() {
        _totalWords = words.length;
        _learnedWords = learned;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(widget.topic.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Topic info card
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.paddingLarge),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.primaryColor.withOpacity(0.8),
                            context.primaryColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              TopicIcons.get(widget.topic.name),
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingMedium),
                          Text(
                            widget.topic.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingSmall),
                          Text(
                            widget.topic.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppConstants.paddingLarge),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                icon: Icons.book,
                                label: 'Tổng số',
                                value: '$_totalWords',
                                color: Colors.white,
                              ),
                              _buildStatItem(
                                icon: Icons.check_circle,
                                label: 'Đã học',
                                value: '$_learnedWords',
                                color: Colors.greenAccent,
                              ),
                              _buildStatItem(
                                icon: Icons.pending,
                                label: 'Còn lại',
                                value: '${_totalWords - _learnedWords}',
                                color: Colors.orangeAccent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.paddingLarge * 2),
                  
                  Text(
                    'Chọn chế độ học',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.paddingLarge),
                  
                  // Learning modes
                  _buildModeCard(
                    icon: Icons.style,
                    title: 'Flashcard',
                    description: 'Học từ vựng với thẻ ghi nhớ sinh động',
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade400,
                        Colors.purple.shade600,
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashcardScreen(topic: widget.topic),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: AppConstants.paddingMedium),
                  
                  _buildModeCard(
                    icon: Icons.quiz,
                    title: 'Kiểm tra',
                    description: 'Làm bài kiểm tra để đánh giá kiến thức',
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.blue.shade600,
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(topic: widget.topic),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: AppConstants.paddingMedium),
                  
                  _buildModeCard(
                    icon: Icons.replay,
                    title: 'Ôn tập',
                    description: 'Ôn lại các từ đã học ($_learnedWords từ)',
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                    ),
                    badge: _learnedWords > 0 ? '$_learnedWords' : null,
                    enabled: _learnedWords > 0,
                    onTap: _learnedWords > 0
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReviewScreen(topic: widget.topic),
                              ),
                            );
                          }
                        : null,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required bool isDark,
    String? badge,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            gradient: enabled ? gradient : null,
            color: enabled 
                ? null 
                : context.subtleBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: enabled 
                                ? Colors.white 
                                : context.textTertiary,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: gradient.colors.first,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled 
                            ? Colors.white70 
                            : context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: enabled 
                    ? Colors.white 
                    : context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}