import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/topic.dart';
import '../services/auth_service.dart';
import '../firebase/firebase_service.dart';
import '../utils/constants.dart';
import 'quiz_screen.dart';

class QuizResultScreen extends StatefulWidget {
  final Topic? topic;
  final int totalQuestions;
  final int correctAnswers;
  final int timeSpent;

  const QuizResultScreen({
    super.key,
    this.topic,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timeSpent,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _firebaseService = FirebaseService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
    _saveResult();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveResult() async {
    setState(() => _isSaving = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Parse topicId as int if possible for Firebase (or keep as String)
        final topicIdInt = widget.topic != null ? (int.tryParse(widget.topic!.id ?? '0') ?? 0) : 0;
        
        await _firebaseService.saveQuizResult(
          user.uid,
          topicId: topicIdInt,
          totalQuestions: widget.totalQuestions,
          correctAnswers: widget.correctAnswers,
          timeSpent: widget.timeSpent,
        );
      }
    } catch (e) {
      print('Error saving quiz result: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  double get _score => (widget.correctAnswers / widget.totalQuestions) * 100;

  String get _performanceMessage {
    if (_score >= 90) return 'Xuất sắc! 🎉';
    if (_score >= 70) return 'Tốt lắm! 👏';
    if (_score >= 50) return 'Khá tốt! 👍';
    return 'Cố gắng hơn nhé! 💪';
  }

  Color get _scoreColor {
    if (_score >= 70) return AppConstants.secondaryColor;
    if (_score >= 50) return Colors.orange;
    return AppConstants.errorColor;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes phút $remainingSeconds giây';
  }

  void _retakeQuiz() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          topic: widget.topic,
          isMixedPractice: widget.topic == null,
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Kết quả'),
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.paddingLarge * 2),
                decoration: BoxDecoration(
                  color: _scoreColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  children: [
                    Text(
                      '${_score.toInt()}',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor,
                      ),
                    ),
                    const Text(
                      'ĐIỂM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              _performanceMessage,
              style: AppConstants.titleStyle.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            if (_score < 50) ...[
              const SizedBox(height: 16),
              Lottie.asset('assets/lottie/encouragement.json', height: 80, repeat: true),
            ],
            const SizedBox(height: AppConstants.paddingLarge * 2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  children: [
                    _buildResultRow(
                      icon: Icons.quiz,
                      label: 'Chủ đề',
                      value: widget.topic?.name ?? 'Luyện tập tự do',
                      color: AppConstants.primaryColor,
                    ),
                    const Divider(height: AppConstants.paddingLarge),
                    _buildResultRow(
                      icon: Icons.check_circle,
                      label: 'Câu đúng',
                      value: '${widget.correctAnswers}/${widget.totalQuestions}',
                      color: AppConstants.secondaryColor,
                    ),
                    const Divider(height: AppConstants.paddingLarge),
                    _buildResultRow(
                      icon: Icons.cancel,
                      label: 'Câu sai',
                      value: '${widget.totalQuestions - widget.correctAnswers}',
                      color: AppConstants.errorColor,
                    ),
                    const Divider(height: AppConstants.paddingLarge),
                    _buildResultRow(
                      icon: Icons.timer,
                      label: 'Thời gian',
                      value: _formatTime(widget.timeSpent),
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge * 2),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _retakeQuiz,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Làm lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _goHome,
                icon: const Icon(Icons.home),
                label: const Text(
                  'Về trang chủ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppConstants.primaryColor, width: 2),
                ),
              ),
            ),
            if (_isSaving) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đang lưu kết quả...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    if (_score >= 90)
      Positioned.fill(
        child: IgnorePointer(
          child: Lottie.asset('assets/lottie/success_confetti.json', repeat: false),
        ),
      ),
    ],
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: AppConstants.paddingMedium),
        Expanded(
          child: Text(
            label,
            style: AppConstants.bodyStyle.copyWith(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}