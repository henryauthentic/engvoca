import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../models/user_word_progress.dart';
import '../services/srs_service.dart';
import '../services/gamification_service.dart';
import '../services/sound_service.dart';
import '../services/ai_service.dart';
import '../models/study_session.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FlashcardScreen extends StatefulWidget {
  final Topic topic;
  final bool isNewWordsMode;
  final List<Word>? preloadedWords;

  const FlashcardScreen({
    super.key, 
    required this.topic,
    this.isNewWordsMode = false,
    this.preloadedWords,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TickerProviderStateMixin {
  final _dbHelper = DatabaseHelper.instance;
  final FlutterTts _flutterTts = FlutterTts();
  final _soundService = SoundService.instance;
  
  List<Word> _words = [];
  int _currentIndex = 0;
  int _learnedCount = 0;
  bool _isLoading = true;
  bool _autoPlay = true;
  bool _isMarkingLearned = false;
  bool _isFlipped = false;
  int _sessionXp = 0;
  bool _isAiLoading = false;
  final _aiService = AiService();
  
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _learnedButtonController;

  @override
  void initState() {
    super.initState();
    _initTts();
    _setupAnimations();
    _loadWords();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    _learnedButtonController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _setupAnimations() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.5, 0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _learnedButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      List<Word> words = [];
      if (widget.preloadedWords != null && widget.preloadedWords!.isNotEmpty) {
        words = widget.preloadedWords!;
      } else if (widget.isNewWordsMode) {
        words = await _dbHelper.getNewWords(20, topicId: widget.topic.id);
      } else {
        words = await _dbHelper.getWordsByTopic(widget.topic.id!);
      }
      
      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              widget.isNewWordsMode 
                ? 'Bạn đã học hết từ mới của chủ đề này!' 
                : 'Chủ đề này chưa có từ vựng'
            )),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      words.shuffle();
      
      final learnedWords = words.where((w) => w.isLearned).length;
      
      setState(() {
        _words = words;
        _learnedCount = learnedWords;
        _isLoading = false;
      });
      
      if (_autoPlay) {
        _speak(_words[0].word);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _flipCard() {
    setState(() => _isFlipped = !_isFlipped);
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  Future<void> _rateWord(int quality) async {
    if (_isMarkingLearned) return;
    
    setState(() => _isMarkingLearned = true);
    final currentWord = _words[_currentIndex];
    
    try {
      // 1. Get current progress
      var progress = await _dbHelper.getWordProgress(currentWord.id!);
      progress ??= UserWordProgress(wordId: currentWord.id!);

      // 2. Calculate next review
      final newProgress = SrsService.calculateNextReview(quality, progress);

      // 3. Save to DB
      await _dbHelper.upsertWordProgress(newProgress);
      
      // 4. Update isLearned for backward compatibility if mastered or currently learned
      if (quality >= 3 && !currentWord.isLearned) {
        await _dbHelper.markWordAsLearned(currentWord.id!);
        setState(() {
          _words[_currentIndex] = currentWord.copyWith(isLearned: true);
          _learnedCount++;
        });
      }

      int xpGained = quality >= 3 ? 5 : 1;
      _sessionXp += xpGained;
      if (_dbHelper.currentUserId != null) {
        await GamificationService().addXp(_dbHelper.currentUserId!, xpGained);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black12,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Lottie.asset(
              quality >= 3 ? 'assets/lottie/correct_check.json' : 'assets/lottie/wrong_cross.json',
              width: 150,
              height: 150,
              repeat: false,
            ),
          ),
        );
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.of(context).pop();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(quality >= 3 ? 'Tuyệt vời! +$xpGained XP' : 'Bạn cần ôn thêm từ này! +$xpGained XP'),
            backgroundColor: quality >= 3 ? Colors.green : Colors.orange,
            duration: const Duration(milliseconds: 1300),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        _nextCard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingLearned = false);
      }
    }
  }


  Future<void> _nextCard() async {
    if (_currentIndex >= _words.length - 1) {
      _showCompletionDialog();
      return;
    }

    await _slideController.forward();
    
    setState(() {
      _currentIndex++;
      _isFlipped = false;
    });
    
    _flipController.reset();
    _slideController.reset();
    
    if (_autoPlay) {
      _speak(_words[_currentIndex].word);
    }
  }

  Future<void> _previousCard() async {
    if (_currentIndex <= 0) return;

    setState(() {
      _currentIndex--;
      _isFlipped = false;
    });
    
    _flipController.reset();
    
    if (_autoPlay) {
      _speak(_words[_currentIndex].word);
    }
  }

  Future<void> _showCompletionDialog() async {
    // Phát âm thanh hoàn thành
    _soundService.playCompleted();

    print('🎉 _showCompletionDialog called! _sessionXp=$_sessionXp, words=${_words.length}, learnedCount=$_learnedCount');
    if (_dbHelper.currentUserId != null) {
      await GamificationService().updateStreak(_dbHelper.currentUserId!);
      print('📝 About to insert study session with xp=$_sessionXp');
      await _dbHelper.insertStudySession(StudySession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        xpEarned: _sessionXp,
        wordsReviewed: _words.length,
        accuracyRate: _words.isEmpty ? 0 : (_learnedCount / _words.length),
      ));
      print('✅ Study session saved from FlashcardScreen');
    } else {
      print('⚠️ currentUserId is null, skipping study session save');
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardColor,
        title: const Text('🎉 Hoàn thành!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bạn đã xem ${_words.length} từ trong chủ đề ${widget.topic.name}',
              style: TextStyle(
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (AppConstants.secondaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppConstants.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đã học: $_learnedCount/${_words.length} từ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Về trang chủ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _isFlipped = false;
                _words.shuffle();
              });
              _flipController.reset();
              if (_autoPlay) {
                _speak(_words[0].word);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Học lại'),
          ),
        ],
      ),
    );
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

    final currentWord = _words[_currentIndex];
    final progress = (_currentIndex + 1) / _words.length;
    final learnedProgress = _learnedCount / _words.length;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F5FA),
      appBar: AppBar(
        title: Text(
          widget.isNewWordsMode
              ? 'Khám phá từ mới: ${widget.topic.name}'
              : '${widget.topic.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: context.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _autoPlay ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: context.primaryColor,
            ),
            onPressed: () => setState(() => _autoPlay = !_autoPlay),
            tooltip: _autoPlay ? 'Tắt tự động phát âm' : 'Bật tự động phát âm',
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== PROGRESS SECTION =====
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: context.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Counter & Percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Thẻ ${_currentIndex + 1}/${_words.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Color(0xFF4ADE80)),
                              const SizedBox(width: 4),
                              Text(
                                '$_learnedCount/${_words.length}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4ADE80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? context.primaryColor : const Color(0xFF6C63FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: isDark ? Colors.grey.shade800 : const Color(0xFFE8E8F0),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== FLASHCARD AREA =====
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * pi;
                        final isFront = angle < pi / 2;

                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          child: isFront
                              ? _buildCardFront(currentWord, isDark)
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(pi),
                                  child: _buildCardBack(currentWord, isDark),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ===== RATING / FLIP BUTTONS =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: !_isFlipped
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _flipCard,
                      icon: const Icon(Icons.flip_rounded, size: 22),
                      label: const Text('Lật thẻ xem nghĩa',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      _buildRateButton('Quên', const Color(0xFFEF4444), 0),
                      const SizedBox(width: 8),
                      _buildRateButton('Khó', const Color(0xFFF59E0B), 3),
                      const SizedBox(width: 8),
                      _buildRateButton('Tốt', const Color(0xFF22C55E), 4),
                      const SizedBox(width: 8),
                      _buildRateButton('Dễ', const Color(0xFF3B82F6), 5),
                    ],
                  ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0, duration: 300.ms),
          ),

          // ===== BOTTOM CONTROLS =====
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            decoration: BoxDecoration(
              color: context.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Prev
                  _buildControlButton(
                    icon: Icons.arrow_back_ios_rounded,
                    onPressed: _currentIndex > 0 ? _previousCard : null,
                    isDark: isDark,
                  ),
                  // Speak
                  _buildControlButton(
                    icon: Icons.volume_up_rounded,
                    onPressed: () => _speak(currentWord.word),
                    isDark: isDark,
                    isPrimary: true,
                    primaryColor: const Color(0xFF22C55E),
                  ),
                  // Flip
                  _buildControlButton(
                    icon: Icons.flip_rounded,
                    onPressed: _flipCard,
                    isDark: isDark,
                    isPrimary: true,
                    primaryColor: const Color(0xFF6C63FF),
                  ),
                  // Next
                  _buildControlButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    onPressed: _nextCard,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    required bool isDark,
    bool isPrimary = false,
    Color? primaryColor,
  }) {
    final color = primaryColor ?? const Color(0xFF6C63FF);
    return Container(
      decoration: isPrimary
          ? BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: isPrimary ? 26 : 28),
        color: isPrimary
            ? Colors.white
            : (onPressed != null
                ? (isDark ? Colors.white70 : Colors.grey.shade700)
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade400)),
      ),
    );
  }

  Widget _buildRateButton(String label, Color color, int quality) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _isMarkingLearned ? null : () => _rateWord(quality),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
            shadowColor: color.withOpacity(0.4),
          ),
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }

  // ===== CARD FRONT: Từ tiếng Anh =====
  Widget _buildCardFront(Word word, bool isDark) {
    return _buildCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge "Đã học"
          if (word.isLearned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Đã học',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (word.isLearned) const SizedBox(height: 20),

          // Icon phát âm mini
          GestureDetector(
            onTap: () => _speak(word.word),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 20),

          // Từ vựng
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Phiên âm
          if (word.pronunciation.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                word.pronunciation,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.85),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const Spacer(),

          // Hint lật thẻ
          Column(
            children: [
              Icon(Icons.swipe_rounded,
                  color: Colors.white.withOpacity(0.4), size: 28),
              const SizedBox(height: 6),
              Text(
                'Chạm để lật thẻ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF7C3AED),
          Color(0xFF6C63FF),
          Color(0xFF818CF8),
        ],
        stops: [0.0, 0.5, 1.0],
      ),
    );
  }

  // ===== CARD BACK: Nghĩa tiếng Việt =====
  Widget _buildCardBack(Word word, bool isDark) {
    return _buildCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon dịch
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.translate_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),

            // Nghĩa
            Text(
              word.meaning,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Ví dụ
            if (word.example.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote_rounded,
                            color: Colors.white.withOpacity(0.6), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Ví dụ:',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      word.example,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // AI Button
            GestureDetector(
              onTap: () => _showAiBottomSheet(word),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Hỏi AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF059669),
          Color(0xFF10B981),
          Color(0xFF34D399),
        ],
        stops: [0.0, 0.5, 1.0],
      ),
    );
  }

  void _showAiBottomSheet(Word word) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiBottomSheet(
        word: word,
        aiService: _aiService,
        isDark: isDark,
      ),
    );
  }

  Widget _buildCard({required Widget child, required Gradient gradient}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 400,
        maxHeight: 520,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: child,
        ),
      ),
    );
  }
}

// ✨ AI Bottom Sheet Widget - Trợ lý Tipo
class _AiBottomSheet extends StatefulWidget {
  final Word word;
  final AiService aiService;
  final bool isDark;

  const _AiBottomSheet({
    required this.word,
    required this.aiService,
    required this.isDark,
  });

  @override
  State<_AiBottomSheet> createState() => _AiBottomSheetState();
}

class _AiBottomSheetState extends State<_AiBottomSheet> with TickerProviderStateMixin {
  bool _isLoading = false;
  String _result = '';
  int _selectedAction = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callAi(int action) async {
    setState(() {
      _isLoading = true;
      _result = '';
      _selectedAction = action;
    });

    String response;
    switch (action) {
      case 0:
        response = await widget.aiService.generateExamples(
          widget.word.word,
          meaning: widget.word.meaning,
        );
        break;
      case 1:
        response = await widget.aiService.explainSynonyms(widget.word.word);
        break;
      case 2:
        response = await widget.aiService.explainUsage(widget.word.word);
        break;
      default:
        response = '';
    }

    if (mounted) {
      setState(() {
        _result = response;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.93,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ✨ Gradient Header with Tipo branding
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59B6), Color(0xFFE91E8C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Tipo avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trợ lý Tipo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đang học từ: ${widget.word.word}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Online', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildActionChip(icon: '📝', label: 'Ví dụ', index: 0, color: const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _buildActionChip(icon: '🔄', label: 'Đồng nghĩa', index: 1, color: const Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  _buildActionChip(icon: '📚', label: 'Cách dùng', index: 2, color: const Color(0xFF14B8A6)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Content area
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _result.isEmpty
                      ? _buildGreetingState()
                      : _buildResultState(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  // 👋 Greeting state khi mới mở
  Widget _buildGreetingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 36)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Xin chào! Tôi là Tipo 👋',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tôi sẽ giúp bạn hiểu từ "${widget.word.word}" tốt hơn!\nHãy chọn một chức năng phía trên để bắt đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⏳ Loading state
  Widget _buildLoadingState() {
    final labels = ['Ví dụ', 'Đồng nghĩa', 'Cách dùng'];
    final actionLabel = _selectedAction >= 0 && _selectedAction < labels.length
        ? labels[_selectedAction]
        : '';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text('🤔', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tipo đang suy nghĩ...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đang tạo $actionLabel cho "${widget.word.word}"',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? Colors.grey.shade500 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Result state with markdown rendering
  Widget _buildResultState(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo response bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF2A2A3E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo label
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('🤖', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tipo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? const Color(0xFF8B7CF6) : const Color(0xFF6C63FF),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: const Color(0xFF4ADE80),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Markdown rendered content
                MarkdownBody(
                  data: _result,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: widget.isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    em: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: widget.isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                    listBullet: TextStyle(
                      fontSize: 14,
                      color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                    h1: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    h2: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF1F5F9),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFF6C63FF),
                          width: 3,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    code: TextStyle(
                      backgroundColor: widget.isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                      color: widget.isDark ? const Color(0xFF93C5FD) : const Color(0xFF6366F1),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required String icon,
    required String label,
    required int index,
    required Color color,
  }) {
    final isSelected = _selectedAction == index;
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : () => _callAi(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(
              colors: [color, color.withOpacity(0.8)],
            ) : null,
            color: isSelected ? null : (widget.isDark ? const Color(0xFF2A2A3E) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}