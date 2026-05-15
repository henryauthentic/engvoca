import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import 'quiz_screen.dart';

class QuizMenuScreen extends StatefulWidget {
  const QuizMenuScreen({super.key});

  @override
  State<QuizMenuScreen> createState() => _QuizMenuScreenState();
}

class _QuizMenuScreenState extends State<QuizMenuScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Topic> _topics = [];
  bool _isLoading = true;
  Topic? _selectedTopic;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _dbHelper.getTopics();
      setState(() {
        _topics = topics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _startQuiz() {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn chủ đề'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizScreen(topic: _selectedTopic!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Kiểm tra'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingLarge),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.primaryColor.withOpacity(0.8),
                          context.primaryColor.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppConstants.paddingMedium),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.quiz,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingMedium),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kiểm tra kiến thức',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${AppConstants.questionsPerQuiz} câu hỏi',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLarge),
                  Text(
                    'Chọn chủ đề',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      final topic = _topics[index];
                      final isSelected = _selectedTopic?.id == topic.id;

                      return Card(
                        elevation: isDark ? 0 : 2,
                        color: context.cardColor,
                        margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.primaryColor.withOpacity(0.2)
                                  : (context.subtleBackground),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                            ),
                            child: Center(
                              child: Text(
                                topic.iconName,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          title: Text(
                            topic.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${topic.wordCount} từ',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                          trailing: Radio<Topic>(
                            value: topic,
                            groupValue: _selectedTopic,
                            onChanged: (Topic? value) {
                              setState(() => _selectedTopic = value);
                            },
                            activeColor: context.primaryColor,
                          ),
                          onTap: () {
                            setState(() => _selectedTopic = topic);
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppConstants.paddingLarge),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _selectedTopic == null ? null : _startQuiz,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Bắt đầu kiểm tra',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}