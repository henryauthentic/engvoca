import 'dart:async';
import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../models/quiz_question.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/quiz_option_tile.dart';
import 'quiz_result_screen.dart';
import '../services/gamification_service.dart';
import '../models/study_session.dart';

class QuizScreen extends StatefulWidget {
  final Topic? topic;
  final bool isMixedPractice;

  const QuizScreen({
    super.key, 
    this.topic,
    this.isMixedPractice = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
} 

class _QuizScreenState extends State<QuizScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<QuizQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;
  int _correctAnswers = 0;
  int _timeSpent = 0;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _timeSpent++);
    });
  }

  Future<void> _generateQuiz() async {
    try {
      List<Word> words = [];
      List<Word> allWords = [];
      
      if (widget.isMixedPractice) {
        final newWords = await _dbHelper.getNewWords(8);
        final dueWords = await _dbHelper.getGlobalDueWords(DateTime.now(), 8);
        final hardWords = await _dbHelper.getHardWords(4);
        
        final combined = [...newWords, ...dueWords, ...hardWords];
        final uniqueMap = <String, Word>{};
        for (var w in combined) {
           uniqueMap[w.id!] = w;
        }
        words = uniqueMap.values.toList();
        words.shuffle();
        
        allWords = await _dbHelper.getAllWords();
        
        // Ensure we don't exceed 20 or AppConstants.questionsPerQuiz
        if (words.length > AppConstants.questionsPerQuiz) {
          words = words.take(AppConstants.questionsPerQuiz).toList();
        }
      } else {
        if (widget.topic == null) throw Exception('Chủ đề không hợp lệ');
        words = await _dbHelper.getRandomWords(
          AppConstants.questionsPerQuiz,
          topicId: widget.topic!.id,
        );
        allWords = await _dbHelper.getWordsByTopic(widget.topic!.id!);
      }

      if (words.length < 4 || allWords.length < 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isMixedPractice 
                ? 'Chưa đủ từ vựng trong hệ thống để tạo bài luyện tập' 
                : 'Chủ đề này chưa đủ từ để tạo quiz (cần ít nhất 4 từ)'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final questions = <QuizQuestion>[];

      for (var word in words) {
        final wrongAnswers = allWords
            .where((w) => w.id != word.id!)
            .map((w) => w.meaning)
            .toList()
          ..shuffle();

        final options = [
          word.meaning,
          ...wrongAnswers.take(3),
        ]..shuffle();

        questions.add(QuizQuestion(
          wordId: word.id!,
          question: word.word,
          options: options,
          correctAnswerIndex: options.indexOf(word.meaning),
        ));
      }

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo quiz: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    setState(() {
      _selectedAnswerIndex = index;
      _hasAnswered = true;

      if (_questions[_currentQuestionIndex].isCorrect(index)) {
        _correctAnswers++;
      }
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _hasAnswered = false;
      });
    } else {
      await _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    
    if (_dbHelper.currentUserId != null) {
      final gamification = GamificationService();
      await gamification.updateStreak(_dbHelper.currentUserId!);
      await gamification.addXp(_dbHelper.currentUserId!, _correctAnswers * 10);
      
      await _dbHelper.insertStudySession(StudySession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        xpEarned: _correctAnswers * 10,
        wordsReviewed: _questions.length,
        accuracyRate: _questions.isEmpty ? 0 : (_correctAnswers / _questions.length),
      ));
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          topic: widget.topic,
          totalQuestions: _questions.length,
          correctAnswers: _correctAnswers,
          timeSpent: _timeSpent,
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.cardColor,
            title: Text(
              'Thoát quiz?',
              style: TextStyle(
                color: context.textPrimary,
              ),
            ),
            content: Text(
              'Tiến trình của bạn sẽ không được lưu.',
              style: TextStyle(
                color: context.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Tiếp tục'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Thoát'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          title: Text(widget.topic?.name ?? 'Luyện tập tự do'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingMedium),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_timeSpent),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              color: context.cardColor,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Câu ${_currentQuestionIndex + 1}/${_questions.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '$_correctAnswers đúng',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppConstants.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingSmall),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: context.subtleBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.primaryColor,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppConstants.paddingLarge),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      child: Text(
                        question.question,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingLarge),
                    Text(
                      'Chọn nghĩa đúng:',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    ...List.generate(
                      question.options.length,
                      (index) => QuizOptionTile(
                        option: question.options[index],
                        index: index,
                        isSelected: _selectedAnswerIndex == index,
                        isCorrect: _hasAnswered
                            ? index == question.correctAnswerIndex
                            : null,
                        onTap: () => _selectAnswer(index),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_hasAnswered)
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                color: context.cardColor,
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text(
                        _currentQuestionIndex < _questions.length - 1
                            ? AppStrings.next
                            : AppStrings.finish,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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