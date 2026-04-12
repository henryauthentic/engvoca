import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../models/practice_result.dart';
import '../db/database_helper.dart';
import '../firebase/firebase_service.dart';
import '../services/gamification_service.dart';
import '../services/sound_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'practice_result_screen.dart';

class PracticeScreen extends StatefulWidget {
  final List<Word> words;
  final String mode; // 'quiz', 'fill_blank', 'mixed', 'listening'
  final List<String> topicIds;
  final List<String> topicNames;

  const PracticeScreen({
    super.key,
    required this.words,
    required this.mode,
    this.topicIds = const [],
    this.topicNames = const [],
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with SingleTickerProviderStateMixin {
  final _dbHelper = DatabaseHelper.instance;
  final _firebaseService = FirebaseService();
  final _soundService = SoundService.instance;
  final FlutterTts _flutterTts = FlutterTts();
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _answered = false;
  int? _selectedOption;
  final _fillController = TextEditingController();
  final _fillFocusNode = FocusNode();
  final List<PracticeDetailItem> _details = [];
  late DateTime _startTime;
  late List<_QuestionItem> _questions;
  late AnimationController _shakeController;
  bool _hasPlayedAudio = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _generateQuestions();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _initTts();
    _fillController.addListener(() => setState(() {}));
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakWord(String word) async {
    await _flutterTts.speak(word);
    setState(() => _hasPlayedAudio = true);
  }

  @override
  void dispose() {
    _fillController.dispose();
    _fillFocusNode.dispose();
    _shakeController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _generateQuestions() {
    final random = Random();
    _questions = widget.words.map((word) {
      String type;
      if (widget.mode == 'quiz') {
        type = 'quiz';
      } else if (widget.mode == 'fill_blank') {
        type = 'fill_blank';
      } else if (widget.mode == 'listening') {
        type = 'listening';
      } else {
        // mixed mode
        final r = random.nextInt(3);
        type = r == 0 ? 'quiz' : (r == 1 ? 'fill_blank' : 'listening');
      }

      List<String> options = [];
      if (type == 'quiz') {
        options = _generateOptions(word);
      }

      // Tạo câu có đục lỗ
      String blankSentence = '';
      if (type == 'fill_blank' || type == 'listening') {
        blankSentence = _createBlankSentence(word);
      }

      return _QuestionItem(
        word: word,
        type: type,
        options: options,
        blankSentence: blankSentence,
      );
    }).toList();
  }

  List<String> _generateOptions(Word correctWord) {
    final random = Random();
    final options = <String>[correctWord.meaning];

    // Lấy 3 đáp án sai từ danh sách
    final otherWords = widget.words.where((w) => w.id != correctWord.id).toList();
    otherWords.shuffle(random);

    for (var word in otherWords) {
      if (options.length >= 4) break;
      if (!options.contains(word.meaning)) {
        options.add(word.meaning);
      }
    }

    // Nếu chưa đủ 4 đáp án, thêm placeholder
    while (options.length < 4) {
      options.add('Đáp án ${options.length + 1}');
    }

    options.shuffle(random);
    return options;
  }

  String _createBlankSentence(Word word) {
    if (word.example.isNotEmpty) {
      // Ẩn từ trong câu ví dụ
      return word.example.replaceAll(
        RegExp(word.word, caseSensitive: false),
        '_____',
      );
    }
    return 'The word "_____" means: ${word.meaning}';
  }

  void _checkAnswer() {
    final question = _questions[_currentIndex];
    bool isCorrect;
    String userAnswer;

    if (question.type == 'quiz') {
      if (_selectedOption == null) {
        userAnswer = '(không chọn)';
        isCorrect = false;
      } else {
        userAnswer = question.options[_selectedOption!];
        isCorrect = userAnswer == question.word.meaning;
      }
    } else {
      // fill_blank hoặc listening
      userAnswer = _fillController.text.trim();
      if (userAnswer.isEmpty) {
        userAnswer = '(bỏ trống)';
        isCorrect = false;
      } else {
        isCorrect = userAnswer.toLowerCase() == question.word.word.toLowerCase();
      }
    }

    _details.add(PracticeDetailItem(
      word: question.word.word,
      meaning: question.word.meaning,
      correctAnswer: question.type == 'quiz' ? question.word.meaning : question.word.word,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      questionType: question.type,
    ));

    setState(() {
      _answered = true;
      if (isCorrect) {
        _correctCount++;
        _soundService.playCorrect();
      } else {
        _wrongCount++;
        _soundService.playWrong();
        // Shake animation khi sai
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    });
    
    _showResultAnimation(isCorrect);
  }

  void _showResultAnimation(bool isCorrect) {
    showDialog(
      context: context,
      barrierColor: Colors.black12,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Lottie.asset(
          isCorrect ? 'assets/lottie/correct_check.json' : 'assets/lottie/wrong_cross.json',
          width: 150,
          height: 150,
          repeat: false,
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
        _fillController.clear();
        _hasPlayedAudio = false;
      });
      final nextType = _questions[_currentIndex].type;
      if (nextType == 'fill_blank' || nextType == 'listening') {
        Future.delayed(const Duration(milliseconds: 300), () {
          _fillFocusNode.requestFocus();
        });
      }
    } else {
      _finishPractice();
    }
  }

  Future<void> _finishPractice() async {
    final duration = DateTime.now().difference(_startTime).inSeconds;
    final total = _questions.length;
    final accuracy = total > 0 ? _correctCount / total : 0.0;
    final xpEarned = (_correctCount * 10) + (accuracy > 0.8 ? 50 : 0);

    final result = PracticeResult(
      id: 'practice_${DateTime.now().millisecondsSinceEpoch}',
      mode: widget.mode,
      totalQuestions: total,
      correctCount: _correctCount,
      wrongCount: _wrongCount,
      accuracy: accuracy,
      xpEarned: xpEarned,
      durationSeconds: duration,
      topicIds: widget.topicIds,
      topicNames: widget.topicNames,
      createdAt: DateTime.now(),
      details: _details,
    );

    // Phát âm thanh hoàn thành
    _soundService.playCompleted();

    // Lưu vào DB
    await _dbHelper.savePracticeResult(result);

    // Sync lên Firebase
    if (_dbHelper.currentUserId != null) {
      await _firebaseService.syncPracticeResult(_dbHelper.currentUserId!, result);
    }

    // Cộng XP
    if (_dbHelper.currentUserId != null) {
      await GamificationService().addXp(_dbHelper.currentUserId!, xpEarned);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeResultScreen(result: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Thoát luyện tập?'),
            content: const Text('Tiến trình sẽ không được lưu.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
                child: const Text('Thoát', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            'Câu ${_currentIndex + 1}/${_questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: context.surfaceColor,
          foregroundColor: context.textPrimary,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  _buildScoreBadge('✅', _correctCount, const Color(0xFF4ADE80)),
                  const SizedBox(width: 8),
                  _buildScoreBadge('❌', _wrongCount, const Color(0xFFFF6B6B)),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Animated progress bar
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                minHeight: 5,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: question.type == 'quiz'
                      ? _buildQuizQuestion(question, isDark)
                      : question.type == 'listening'
                          ? _buildListeningQuestion(question, isDark)
                          : _buildFillBlankQuestion(question, isDark),
                ).animate()
                 .fade(duration: 300.ms)
                 .slideY(begin: 0.1, end: 0, duration: 300.ms)
                 .animate(target: _answered && _details.isNotEmpty && !_details.last.isCorrect ? 1 : 0)
                 .shake(hz: 6, offset: const Offset(5, 0), duration: 300.ms),
              ),
            ),
            _buildBottomButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge(String emoji, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$emoji $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildQuizQuestion(_QuestionItem question, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge chế độ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📝', style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text('Trắc nghiệm', style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Từ cần trả lời
        Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  question.word.word,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (question.word.pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    question.word.pronunciation,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                // ✅ Hiển thị ví dụ trong quiz nếu có
                if (question.word.example.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '💬  ${question.word.example}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Chọn nghĩa đúng:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        // Các đáp án
        ...List.generate(question.options.length, (i) {
          final option = question.options[i];
          final isSelected = _selectedOption == i;
          final isCorrect = option == question.word.meaning;

          Color bgColor;
          Color borderColor;
          IconData? trailingIcon;

          if (_answered) {
            if (isCorrect) {
              bgColor = const Color(0xFF4ADE80).withOpacity(0.15);
              borderColor = const Color(0xFF4ADE80);
              trailingIcon = Icons.check_circle;
            } else if (isSelected && !isCorrect) {
              bgColor = const Color(0xFFFF6B6B).withOpacity(0.15);
              borderColor = const Color(0xFFFF6B6B);
              trailingIcon = Icons.cancel;
            } else {
              bgColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50;
              borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
            }
          } else {
            bgColor = isSelected
                ? const Color(0xFF6C63FF).withOpacity(0.1)
                : (isDark ? const Color(0xFF2A2A3E) : Colors.white);
            borderColor = isSelected
                ? const Color(0xFF6C63FF)
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);
          }

          return GestureDetector(
            onTap: _answered ? null : () => setState(() => _selectedOption = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isSelected || (_answered && isCorrect)
                          ? borderColor
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Center(
                      child: _answered && trailingIcon != null
                          ? Icon(trailingIcon, color: Colors.white, size: 18)
                          : Text(
                              String.fromCharCode(65 + i),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? Colors.white : borderColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected || (_answered && isCorrect) ? FontWeight.bold : FontWeight.normal,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildListeningQuestion(_QuestionItem question, bool isDark) {
    final isCorrectAnswer = _answered && _details.last.isCorrect;

    // Auto-play audio on first load
    if (!_hasPlayedAudio && !_answered) {
      Future.microtask(() => _speakWord(question.word.word));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎧', style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text('Luyện nghe', style: TextStyle(fontSize: 13, color: Color(0xFFEC4899), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Speaker button
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _speakWord(question.word.word),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nhấn để nghe lại',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              // Slow speed button
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await _flutterTts.setSpeechRate(0.25);
                  await _flutterTts.speak(question.word.word);
                  await Future.delayed(const Duration(seconds: 2));
                  await _flutterTts.setSpeechRate(0.45);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.slow_motion_video, size: 16,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text('Nghe chậm', style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Input field
        Text(
          'Nghe và gõ lại từ tiếng Anh:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fillController,
          focusNode: _fillFocusNode,
          enabled: !_answered,
          autocorrect: false,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _answered
                ? (isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B))
                : (isDark ? Colors.white : Colors.black87),
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Gõ từ bạn nghe được...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              fontSize: 18,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          ),
          onSubmitted: (_) {
            if (!_answered) _checkAnswer();
          },
        ),

        // Show correct answer after answering
        if (_answered) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrectAnswer
                  ? const Color(0xFF4ADE80).withOpacity(0.1)
                  : const Color(0xFFFF6B6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  isCorrectAnswer ? '🎉 Chính xác!' : '❌ Sai rồi!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đáp án: ${question.word.word}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  question.word.meaning,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFillBlankQuestion(_QuestionItem question, bool isDark) {
    final isCorrectAnswer = _answered && _details.last.isCorrect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge chế độ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✏️', style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text('Điền từ', style: TextStyle(fontSize: 13, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ===== Thẻ nghĩa tiếng Việt =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFE91E8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Nghĩa:',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                question.word.meaning,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              // ✅ Menu hint button
              if (!_answered) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    // Show hint: first letter + word length
                    final w = question.word.word;
                    final hint = '${w[0]}${'_' * (w.length - 1)} (${w.length} ký tự)';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('💡 Gợi ý: $hint'),
                        backgroundColor: const Color(0xFF8B5CF6),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Gợi ý', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ===== Câu ví dụ đục lỗ (TO HƠN) =====
        if (question.blankSentence.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : const Color(0xFFE0E0E0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6C63FF),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ví dụ:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6C63FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  question.blankSentence,
                  style: TextStyle(
                    fontSize: 18,  // ✅ TO HƠN (từ 15 → 18)
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey.shade200 : Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ===== Ô nhập =====
        Text(
          'Điền từ tiếng Anh:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fillController,
          focusNode: _fillFocusNode,
          enabled: !_answered,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (_) {
            // ✅ Cho phép submit luôn (kể cả rỗng → sẽ coi là sai)
            if (!_answered) _checkAnswer();
          },
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _answered
                ? (isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B))
                : (isDark ? Colors.white : Colors.black87),
          ),
          decoration: InputDecoration(
            hintText: 'Nhập từ tiếng Anh...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                _answered
                    ? (isCorrectAnswer ? Icons.check_circle : Icons.cancel)
                    : Icons.edit_outlined,
                color: _answered
                    ? (isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B))
                    : const Color(0xFF8B5CF6),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _answered
                    ? (isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B))
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
          ),
        ),

        // ===== Kết quả đúng/sai =====
        if (_answered) ...[
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrectAnswer
                  ? const Color(0xFF4ADE80).withOpacity(0.1)
                  : const Color(0xFFFF6B6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrectAnswer
                    ? const Color(0xFF4ADE80).withOpacity(0.3)
                    : const Color(0xFFFF6B6B).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrectAnswer ? Icons.celebration : Icons.info_outline,
                      color: isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCorrectAnswer ? 'Chính xác! 🎉' : 'Sai rồi!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCorrectAnswer ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isCorrectAnswer) ...[
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey.shade300 : Colors.black87,
                      ),
                      children: [
                        const TextSpan(text: 'Đáp án đúng: '),
                        TextSpan(
                          text: question.word.word,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4ADE80),
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // ✅ Hiện ví dụ đầy đủ sau khi trả lời
                if (question.word.example.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '📝 ${question.word.example}',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomButton(bool isDark) {
    final question = _questions[_currentIndex];
    // ✅ Chỉ cho phép nhấn nút khi đã chọn đáp án (quiz) hoặc đã nhập (fill_blank)
    final bool canCheck;
    if (_answered) {
      canCheck = true;
    } else if (question.type == 'quiz') {
      canCheck = _selectedOption != null;
    } else {
      canCheck = _fillController.text.trim().isNotEmpty;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton(
              onPressed: canCheck
                  ? (_answered ? _nextQuestion : _checkAnswer)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _answered
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                disabledForegroundColor: isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade500,
                elevation: canCheck ? 3 : 0,
                shadowColor: (_answered
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF6C63FF))
                    .withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _answered
                        ? (_currentIndex < _questions.length - 1
                            ? 'Câu tiếp theo'
                            : 'Xem kết quả 🏆')
                        : (canCheck ? 'Kiểm tra' : 'Chọn đáp án để tiếp tục'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (_answered) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionItem {
  final Word word;
  final String type; // 'quiz', 'fill_blank', or 'listening'
  final List<String> options;
  final String blankSentence;

  _QuestionItem({
    required this.word,
    required this.type,
    this.options = const [],
    this.blankSentence = '',
  });
}
