import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';
import '../models/practice_result.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../services/ai_service.dart';

class PracticeResultScreen extends StatefulWidget {
  final PracticeResult result;

  const PracticeResultScreen({super.key, required this.result});

  @override
  State<PracticeResultScreen> createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: widget.result.accuracy)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.result;
    final percentage = (r.accuracy * 100).round();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F6FA),
          appBar: AppBar(
            title: const Text('Kết quả luyện tập'),
            backgroundColor: context.surfaceColor,
            foregroundColor: context.textPrimary,
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Score card
                _buildScoreCard(isDark, r),
                const SizedBox(height: 16),
                // Stats row
                _buildStatsRow(isDark, r),
                const SizedBox(height: 16),
                // Topics
                if (r.topicNames.isNotEmpty) _buildTopicChips(isDark, r),
                const SizedBox(height: 16),
                // Action buttons
                _buildActionButtons(isDark),
                const SizedBox(height: 16),
                // Detail toggle
                _buildDetailSection(isDark, r),
              ],
            ),
          ),
        ),
        if (percentage >= 90)
          Positioned.fill(
            child: IgnorePointer(
              child: Lottie.asset('assets/lottie/success_confetti.json', repeat: false),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard(bool isDark, PracticeResult r) {
    final percentage = (r.accuracy * 100).round();
    Color scoreColor;
    String emoji;
    String message;

    if (percentage >= 90) {
      scoreColor = const Color(0xFF4ADE80);
      emoji = '🏆';
      message = 'Xuất sắc!';
    } else if (percentage >= 70) {
      scoreColor = const Color(0xFF3B82F6);
      emoji = '👏';
      message = 'Tốt lắm!';
    } else if (percentage >= 50) {
      scoreColor = const Color(0xFFFBBF24);
      emoji = '💪';
      message = 'Cần cố gắng thêm!';
    } else {
      scoreColor = const Color(0xFFFF6B6B);
      emoji = '📖';
      message = 'Hãy ôn tập lại nhé!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scoreColor.withOpacity(0.9), scoreColor.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (percentage < 50)
            Lottie.asset('assets/lottie/encouragement.json', height: 80, repeat: true)
          else
            Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Animated circular score
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _CircleScorePainter(
                    progress: _scoreAnimation.value,
                    color: Colors.white,
                    bgColor: Colors.white.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Text(
                      '${(_scoreAnimation.value * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '${r.correctCount}/${r.totalQuestions} câu đúng',
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, PracticeResult r) {
    return Row(
      children: [
        _buildStatBox('⏱️', 'Thời gian', r.durationFormatted, isDark),
        const SizedBox(width: 10),
        _buildStatBox('⭐', 'XP', '+${r.xpEarned}', isDark),
        const SizedBox(width: 10),
        _buildStatBox(r.modeEmoji, 'Chế độ', r.modeLabel, isDark),
      ],
    );
  }

  Widget _buildStatBox(String emoji, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicChips(bool isDark, PracticeResult r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📚 Chủ đề', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: r.topicNames.map((name) => Chip(
              label: Text(name, style: const TextStyle(fontSize: 11)),
              backgroundColor: isDark ? const Color(0xFF6C63FF).withOpacity(0.2) : const Color(0xFF6C63FF).withOpacity(0.1),
              labelStyle: TextStyle(color: isDark ? Colors.white : const Color(0xFF6C63FF)),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home, color: Colors.white),
            label: const Text('Trang chủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            icon: Icon(_showDetails ? Icons.visibility_off : Icons.visibility),
            label: Text(_showDetails ? 'Ẩn chi tiết' : 'Xem chi tiết'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(bool isDark, PracticeResult r) {
    if (!_showDetails) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi tiết câu hỏi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 12),
        ...r.details.asMap().entries.map((entry) {
          final i = entry.key;
          final detail = entry.value;
          return _DetailCard(
            index: i,
            detail: detail,
            isDark: isDark,
          );
        }),
      ],
    );
  }
}

// Animated circular painter
class _CircleScorePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _CircleScorePainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 6;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleScorePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Detail card with AI button
class _DetailCard extends StatefulWidget {
  final int index;
  final PracticeDetailItem detail;
  final bool isDark;

  const _DetailCard({required this.index, required this.detail, required this.isDark});

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  String? _aiExplanation;
  bool _isAiLoading = false;

  Future<void> _askTipo() async {
    setState(() => _isAiLoading = true);
    final aiService = AiService();
    final d = widget.detail;
    final prompt = '''Trong bài luyện tập, người học gặp câu hỏi:
- Từ: "${d.word}" (nghĩa: ${d.meaning})
- Loại câu: ${d.questionType == 'quiz' ? 'Trắc nghiệm' : 'Điền từ'}
- Đáp án đúng: "${d.correctAnswer}"
- Người học chọn: "${d.userAnswer}"
- Kết quả: ${d.isCorrect ? 'ĐÚNG' : 'SAI'}

Hãy giải thích ngắn gọn (tối đa 100 từ, bằng tiếng Việt):
1. Tại sao đáp án đúng là "${d.correctAnswer}"
2. ${d.isCorrect ? 'Cho thêm 1 ví dụ sử dụng từ này' : 'Giúp người học phân biệt với đáp án họ đã chọn'}
''';

    final response = await aiService.generateExamples(d.word, meaning: d.meaning);
    if (mounted) {
      setState(() {
        _aiExplanation = response;
        _isAiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d.isCorrect ? const Color(0xFF4ADE80).withOpacity(0.3) : const Color(0xFFFF6B6B).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: d.isCorrect 
                    ? const Color(0xFF4ADE80).withOpacity(0.15)
                    : const Color(0xFFFF6B6B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  d.isCorrect ? '✅' : '❌',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            title: Text(
              d.word,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nghĩa: ${d.meaning}',
                    style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey.shade400 : Colors.grey)),
                if (!d.isCorrect)
                  Text('Bạn chọn: ${d.userAnswer}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B))),
              ],
            ),
            trailing: !d.isCorrect
                ? IconButton(
                    onPressed: _isAiLoading ? null : _askTipo,
                    icon: _isAiLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('🤖', style: TextStyle(fontSize: 20)),
                    tooltip: 'Hỏi Tipo',
                  )
                : null,
          ),
          if (_aiExplanation != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🤖', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Tipo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _aiExplanation!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: widget.isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
