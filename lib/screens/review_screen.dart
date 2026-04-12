import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../models/user_word_progress.dart';
import '../models/study_session.dart';
import '../services/gamification_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/primary_button.dart';

class ReviewScreen extends StatefulWidget {
  final Topic? topic;

  const ReviewScreen({super.key, this.topic});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with TickerProviderStateMixin {
  final _dbHelper = DatabaseHelper.instance;
  final FlutterTts _flutterTts = FlutterTts();
  
  List<Word> _learnedWords = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _autoPlay = true;
  int _sessionXp = 0;
  int _reviewedCount = 0;
  
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initTts();
    _setupAnimations();
    _loadLearnedWords();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
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
  }

  Future<void> _loadLearnedWords() async {
    setState(() => _isLoading = true);
    try {
      List<Word> dueWords = [];
      
      if (widget.topic != null) {
        // Topic-specific review
        final userProgressList = await _dbHelper.getWordsToReview(DateTime.now());
        final allWordsInTopic = await _dbHelper.getWordsByTopic(widget.topic!.id!);
        final topicWordIds = allWordsInTopic.map((w) => w.id).toSet();
        
        final dueWordIds = userProgressList
            .where((p) => topicWordIds.contains(p.wordId))
            .map((p) => p.wordId)
            .toSet();

        dueWords = allWordsInTopic.where((w) => dueWordIds.contains(w.id)).toList();
      } else {
        // Global review across all topics
        dueWords = await _dbHelper.getGlobalDueWords(DateTime.now(), 20); // Maximum 20 words per session
      }

      if (dueWords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              widget.topic != null 
                ? 'Không có từ nào đến hạn ôn tập trong chủ đề này hôm nay!'
                : 'Tuyệt vời! Bạn không còn từ nào cần ôn tập hôm nay.'
            )),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      dueWords.shuffle();
      setState(() {
        _learnedWords = dueWords;
        _isLoading = false;
      });
      
      if (_autoPlay) {
        _speak(_learnedWords[0].word);
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
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  Future<void> _nextCard() async {
    if (_currentIndex >= _learnedWords.length - 1) {
      _showCompletionDialog();
      return;
    }

    await _slideController.forward();
    
    setState(() {
      _currentIndex++;
    });
    
    _flipController.reset();
    _slideController.reset();
    
    if (_autoPlay) {
      _speak(_learnedWords[_currentIndex].word);
    }
  }

  Future<void> _previousCard() async {
    if (_currentIndex <= 0) return;

    setState(() {
      _currentIndex--;
    });
    
    _flipController.reset();
    
    if (_autoPlay) {
      _speak(_learnedWords[_currentIndex].word);
    }
  }

  Future<void> _showCompletionDialog() async {
    // Save study session
    if (_dbHelper.currentUserId != null) {
      await GamificationService().updateStreak(_dbHelper.currentUserId!);
      final xp = _reviewedCount * 3; // 3 XP per reviewed word
      await GamificationService().addXp(_dbHelper.currentUserId!, xp);
      await _dbHelper.insertStudySession(StudySession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        xpEarned: _sessionXp > 0 ? _sessionXp : xp,
        wordsReviewed: _learnedWords.length,
        accuracyRate: 1.0,
      ));
      print('✅ ReviewScreen: saved study session with xp=${_sessionXp > 0 ? _sessionXp : xp}');
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardColor,
        title: const Text('🎉 Hoàn thành ôn tập!'),
        content: Text(
          'Bạn đã ôn lại ${_learnedWords.length} từ ${widget.topic != null ? "trong chủ đề ${widget.topic!.name}" : "tổng hợp"}.',
          style: TextStyle(
            color: context.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Về trang chủ'),
          ),
          PrimaryButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _learnedWords.shuffle();
              });
              _flipController.reset();
              if (_autoPlay) {
                _speak(_learnedWords[0].word);
              }
            },
            text: 'Ôn lại',
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

    final currentWord = _learnedWords[_currentIndex];
    final progress = (_currentIndex + 1) / _learnedWords.length;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(widget.topic != null ? 'Ôn tập: ${widget.topic!.name}' : 'Ôn tập tổng hợp'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_autoPlay ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() => _autoPlay = !_autoPlay);
            },
            tooltip: _autoPlay ? 'Tắt tự động phát âm' : 'Bật tự động phát âm',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: context.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, 
                          color: Colors.green.shade600, 
                          size: 20
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Từ đã học: ${_currentIndex + 1}/${_learnedWords.length}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: context.subtleBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green.shade600,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // Flashcard
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
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
                              ? _buildCardFront(currentWord)
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(pi),
                                  child: _buildCardBack(currentWord),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            decoration: BoxDecoration(
              color: context.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _currentIndex > 0 ? _previousCard : null,
                    icon: const Icon(Icons.arrow_back, size: 32),
                    color: Colors.green.shade600,
                    disabledColor: isDark ? Colors.grey[700] : Colors.grey,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade600.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _speak(currentWord.word),
                      icon: const Icon(Icons.volume_up, size: 32),
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.shade600.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _flipCard,
                      icon: const Icon(Icons.flip, size: 32),
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextCard,
                    icon: const Icon(Icons.arrow_forward, size: 32),
                    color: Colors.green.shade600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(Word word) {
    return _buildCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            word.pronunciation,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Icon(
            Icons.touch_app,
            color: Colors.white54,
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn để lật thẻ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.green.shade500,
          Colors.green.shade700,
        ],
      ),
    );
  }

  Widget _buildCardBack(Word word) {
    return _buildCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.translate,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              word.meaning,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Ví dụ:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.example,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.teal.shade500,
          Colors.teal.shade700,
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, required Gradient gradient}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 400,
        maxHeight: 500,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: child,
      ),
    );
  }
}