import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../models/dictionary_entry.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../utils/pos_normalizer.dart';
import '../utils/topic_images.dart';
import '../theme/theme_extensions.dart';
import '../models/user_word_progress.dart';
import '../services/srs_service.dart';
import '../services/gamification_service.dart';
import '../services/sound_service.dart';
import '../services/ai_service.dart';
import '../services/dictionary_service.dart';
import '../services/unsplash_service.dart';
import '../models/image_data.dart';
import '../models/study_session.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/feedback_dialog.dart';

class FlashcardScreen extends StatefulWidget {
  final Topic topic;
  final Topic? parentTopic;
  final bool isNewWordsMode;
  final bool isQuickReview;
  final List<Word>? preloadedWords;

  const FlashcardScreen({
    super.key, 
    required this.topic,
    this.parentTopic,
    this.isNewWordsMode = false,
    this.isQuickReview = false,
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
  final _dictService = DictionaryService();
  final _unsplashService = UnsplashService();
  
  List<Word> _words = [];
  int _currentIndex = 0;
  int _learnedCount = 0;
  bool _isLoading = true;
  bool _autoPlay = true;
  bool _isMarkingLearned = false;
  bool _isFlipped = false;
  int _sessionXp = 0;
  bool _isSpeakerPressed = false;
  bool _sessionSaved = false;

  // Bookmark (Difficult) state and Word Progress cache per word
  final Map<String, bool> _difficultStates = {};
  final Map<String, UserWordProgress> _progressCache = {};
  final _aiService = AiService();

  // Dictionary cache
  final Map<String, DictionaryEntry?> _dictCache = {};
  final Set<String> _dictLoading = {};

  // Unsplash image cache
  final Map<String, ImageData?> _unsplashCache = {};
  final Set<String> _unsplashLoading = {};
  
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _learnedButtonController;

  /// Trích xuất level badge từ tên topic (B1, B2, IELTS, TOEIC...)
  String? get _levelBadge {
    final name = widget.topic.name.toUpperCase();
    final patterns = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'IELTS', 'TOEIC'];
    for (final p in patterns) {
      if (name.contains(p)) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _setupAnimations();
    _loadWords().then((_) {
      _loadWordProgressData();
    });
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
      // Fetch dictionary data on first flip
      final word = _words[_currentIndex].word.toLowerCase().trim();
      if (!_dictCache.containsKey(word) && !_dictLoading.contains(word)) {
        _fetchDictData(word);
      }
    }
  }

  /// Fetch dictionary data in background, no blocking
  Future<void> _fetchDictData(String word) async {
    _dictLoading.add(word);
    if (mounted) setState(() {});
    try {
      final results = await _dictService.searchWord(word);
      if (results.isNotEmpty) {
        _dictCache[word] = results.first;
      } else {
        _dictCache[word] = null;
      }
    } catch (e) {
      print('[Flashcard] Dict fetch failed for "$word": $e');
      _dictCache[word] = null;
    }
    _dictLoading.remove(word);
    if (mounted) setState(() {});
  }

  /// Load difficult states and progress data for all words in current set
  Future<void> _loadWordProgressData() async {
    for (final word in _words) {
      if (word.id != null) {
        final progress = await _dbHelper.getWordProgress(word.id!);
        if (progress != null) {
          _difficultStates[word.id!] = progress.isDifficult;
          _progressCache[word.id!] = progress;
        } else {
          _progressCache[word.id!] = UserWordProgress(wordId: word.id!);
        }
      }
    }
    if (mounted) setState(() {});
  }

  /// Toggle bookmark for a word
  Future<void> _toggleBookmark(String wordId) async {
    await _dbHelper.toggleDifficult(wordId);
    final progress = await _dbHelper.getWordProgress(wordId);
    if (mounted) {
      setState(() {
        _difficultStates[wordId] = progress?.isDifficult ?? false;
      });
    }
  }

  Future<void> _rateWord(int quality) async {
    if (_isMarkingLearned) return;
    
    setState(() => _isMarkingLearned = true);
    final currentWord = _words[_currentIndex];
    
    try {
      if (!widget.isQuickReview) {
        // 1. Get current progress from cache or DB
        var progress = _progressCache[currentWord.id!];
        if (progress == null) {
          progress = await _dbHelper.getWordProgress(currentWord.id!);
          progress ??= UserWordProgress(wordId: currentWord.id!);
        }

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
      }

      // Adaptive Learning: Update wrong count if user fails
      if (quality < 3) {
        await _dbHelper.updateWrongCount(currentWord.id!);
      }

      int xpGained = quality >= 3 ? 5 : 1;
      _sessionXp += xpGained;
      if (_dbHelper.currentUserId != null) {
        await GamificationService().addXp(_dbHelper.currentUserId!, xpGained, source: 'newWords');
      }

      // Play sound effect
      if (quality >= 3) {
        _soundService.playCorrect();
      } else {
        _soundService.playWrong();
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
    _soundService.playCompleted();

    if (!_sessionSaved && _dbHelper.currentUserId != null) {
      _sessionSaved = true;
      await GamificationService().updateStreak(_dbHelper.currentUserId!);
      await _dbHelper.insertStudySession(StudySession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        xpEarned: _sessionXp,
        wordsReviewed: _words.length,
        accuracyRate: _words.isEmpty ? 0 : (_learnedCount / _words.length),
      ));
    }

    if (!mounted) return;
    
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
              style: TextStyle(color: context.textPrimary),
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
                  Icon(Icons.check_circle, color: AppConstants.secondaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Đã học: $_learnedCount/${_words.length} từ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,
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
              if (_autoPlay) _speak(_words[0].word);
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

    return WillPopScope(
      onWillPop: () async {
        if (!_sessionSaved && _sessionXp > 0 && _dbHelper.currentUserId != null) {
          _sessionSaved = true;
          await GamificationService().updateStreak(_dbHelper.currentUserId!);
          await _dbHelper.insertStudySession(StudySession(
            sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
            date: DateTime.now(),
            xpEarned: _sessionXp,
            wordsReviewed: _currentIndex,
            accuracyRate: _currentIndex == 0 ? 0 : (_learnedCount / _currentIndex),
          ));
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F7FF),
      appBar: null,
      body: Stack(
        children: [
          // Background Gradient (Premium Soft Look)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.15),
                    const Color(0xFF3B82F6).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              // ===== HEADER SECTION =====
              _buildPremiumHeader(progress, isDark),

              // ===== FLASHCARD AREA =====
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

              // ===== SM2 RATING / FLIP BUTTONS =====
              _buildBottomActions(isDark),

              // ===== BOTTOM CONTROLS =====
              _buildNavigationBar(currentWord, isDark),
            ],
          ),
        ],
      ),
    ),
    );
  }

  // ═══════════════════════════════════════════
  // PREMIUM HEADER & PROGRESS
  // ═══════════════════════════════════════════
  Widget _buildPremiumHeader(double progress, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          children: [
            // Top Row: Back, Title, Audio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: isDark ? [] : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      size: 22,
                    ),
                  ),
                ),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.isQuickReview
                            ? 'Ôn tập từ khó'
                            : widget.isNewWordsMode
                                ? 'Khám phá từ mới'
                                : widget.topic.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Học từ vựng mỗi ngày ✨',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    // Report Button
                    GestureDetector(
                      onTap: () {
                        if (_words.isNotEmpty && _currentIndex < _words.length) {
                          FeedbackDialog.show(
                            context,
                            initialType: 'wrong_word',
                            wordId: _words[_currentIndex].id,
                            wordText: _words[_currentIndex].word,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                    // Audio Button
                    GestureDetector(
                      onTap: () => setState(() => _autoPlay = !_autoPlay),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _autoPlay 
                              ? const Color(0xFF8B5CF6).withOpacity(0.15)
                              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                          boxShadow: isDark || _autoPlay ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _autoPlay ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: _autoPlay ? const Color(0xFF8B5CF6) : Colors.grey.shade500,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Second Row: Progress Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thẻ ${_currentIndex + 1} / ${_words.length}',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Premium Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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

  // ═══════════════════════════════════════════
  // UNSPLASH IMAGE: Prefetch & Cache
  // ═══════════════════════════════════════════
  void _prefetchUnsplashImage(String wordText) {
    final key = wordText.toLowerCase().trim();
    if (_unsplashCache.containsKey(key) || _unsplashLoading.contains(key)) return;

    _unsplashLoading.add(key);
    _unsplashService.getImage(wordText).then((imageData) {
      if (mounted) {
        setState(() {
          _unsplashCache[key] = imageData;
          _unsplashLoading.remove(key);
        });
      }
    });
  }

  // ═══════════════════════════════════════════
  // CARD FRONT: Redesigned — Hero Image + Premium Layout
  // ═══════════════════════════════════════════
  Widget _buildCardFront(Word word, bool isDark) {
    final posNormalized = PosNormalizer.normalize(word.pos);
    final wordKey = word.word.toLowerCase().trim();
    final isBookmarked = _difficultStates[word.id] ?? false;

    // Prefetch ảnh Unsplash cho từ hiện tại + từ tiếp theo
    _prefetchUnsplashImage(word.word);
    if (_currentIndex + 1 < _words.length) {
      _prefetchUnsplashImage(_words[_currentIndex + 1].word);
    }

    // Fallback: ảnh topic
    final topicImgPath = TopicImages.getPath(widget.parentTopic?.name ?? '')
        ?? TopicImages.getPath(widget.topic.name);

    // Xác định ảnh hiển thị: Unsplash > Word.imageUrl > Topic image
    final unsplashData = _unsplashCache[wordKey];
    final isLoadingUnsplash = _unsplashLoading.contains(wordKey);

    Widget imageWidget;
    String? creditText;
    if (unsplashData != null && unsplashData.imageUrl.isNotEmpty) {
      imageWidget = Image.network(
        unsplashData.imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildImageShimmer();
        },
        errorBuilder: (_, __, ___) => _buildFallbackImage(word, topicImgPath),
      );
      creditText = 'Photo by ${unsplashData.authorName} on Unsplash';
    } else if (isLoadingUnsplash) {
      imageWidget = _buildImageShimmer();
    } else {
      imageWidget = _buildFallbackImage(word, topicImgPath);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF6C63FF)).withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Column(
              children: [
                // ===== HERO IMAGE (~38%) =====
                Expanded(
                  flex: 38,
                  child: _buildHeroImageSection(
                    imageWidget: imageWidget,
                    creditText: creditText,
                    isLearned: word.isLearned,
                    isDark: isDark,
                  ),
                ),
                // ===== TEXT & INFO (~62%) =====
                Expanded(
                  flex: 62,
                  child: _buildFrontTextSection(
                    word: word,
                    posNormalized: posNormalized,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            // ===== BOOKMARK ICON (top-right) =====
            Positioned(
              top: 14,
              right: 14,
              child: GestureDetector(
                onTap: () {
                  if (word.id != null) _toggleBookmark(word.id!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBookmarked
                        ? const Color(0xFF7C3AED)
                        : Colors.black.withOpacity(0.25),
                    boxShadow: isBookmarked ? [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero image section — full width, gradient overlay, credit, badge
  Widget _buildHeroImageSection({
    required Widget imageWidget,
    String? creditText,
    required bool isLearned,
    required bool isDark,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Ảnh nền fill toàn bộ
        imageWidget,

        // Gradient overlay: blend ảnh vào card gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  const Color(0xFF8B5CF6).withOpacity(0.3),
                  isDark ? const Color(0xFF1E1E2E) : Colors.white,
                ],
                stops: const [0.4, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // Credit text — góc dưới trái, semi-transparent pill
        if (creditText != null)
          Positioned(
            bottom: 8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                creditText,
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),

        // Badge "Đã học" — góc trên phải, nổi bật
        if (isLearned)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Đã học',
                    style: TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Text section: từ vựng, phiên âm, speaker, badges, hint
  Widget _buildFrontTextSection({
    required Word word,
    String? posNormalized,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final accentColor = const Color(0xFF7C3AED);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // POS + Level badges moved to top
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (posNormalized != null) ...[
                _buildPosBadge(posNormalized, onDark: false),
                const SizedBox(width: 8),
              ],
              if (_levelBadge != null) _buildLevelBadge(_levelBadge!),
            ],
          ),
          
          const Spacer(flex: 1),

          // Từ vựng
          Text(
            word.word,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Phiên âm
          if (word.pronunciation.isNotEmpty)
            Text(
              word.pronunciation,
              style: TextStyle(
                fontSize: 18,
                color: accentColor.withOpacity(0.7),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 24),
          
          // Nút phát âm to, đặt dưới phiên âm
          _buildSpeakerButton(word, isDark: isDark, size: 56, iconSize: 28),

          const Spacer(flex: 2),

          // Hint lật thẻ — nhỏ, tinh tế
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded,
                color: textSecondary.withOpacity(0.4), size: 16),
              const SizedBox(width: 6),
              Text(
                'Chạm để lật thẻ',
                style: TextStyle(
                  color: textSecondary.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Nút phát âm tròn — glow effect + scale animation
  Widget _buildSpeakerButton(Word word, {bool isDark = false, double size = 44, double iconSize = 22}) {
    final accentColor = const Color(0xFF7C3AED);
    return GestureDetector(
      onTapDown: (_) => setState(() => _isSpeakerPressed = true),
      onTapUp: (_) {
        setState(() => _isSpeakerPressed = false);
        _speak(word.word);
      },
      onTapCancel: () => setState(() => _isSpeakerPressed = false),
      child: AnimatedScale(
        scale: _isSpeakerPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withOpacity(isDark ? 0.2 : 0.08),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.volume_up_rounded, color: accentColor, size: iconSize),
        ),
      ),
    );
  }

  /// Shimmer loading placeholder cho ảnh — gradient + animation
  Widget _buildImageShimmer() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined,
              color: Colors.white.withOpacity(0.25), size: 36),
            const SizedBox(height: 10),
            SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    ).animate(onPlay: (c) => c.repeat())
      .shimmer(
        duration: 1500.ms,
        color: Colors.white.withOpacity(0.08),
      );
  }

  /// Fallback image: word.imageUrl → Topic image → icon
  Widget _buildFallbackImage(Word word, String? topicImgPath) {
    if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
      if (word.imageUrl!.startsWith('http')) {
        return Image.network(word.imageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => topicImgPath != null
              ? Image.asset(topicImgPath, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderIcon())
              : _buildPlaceholderIcon());
      } else {
        return Image.asset(word.imageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => topicImgPath != null
              ? Image.asset(topicImgPath, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderIcon())
              : _buildPlaceholderIcon());
      }
    } else if (topicImgPath != null) {
      return Image.asset(topicImgPath, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon());
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey.withOpacity(0.08),
      child: Center(
        child: Icon(Icons.image_outlined, color: Colors.grey.withOpacity(0.3), size: 36),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CARD BACK: Nghĩa + Từ điển mở rộng
  // ═══════════════════════════════════════════
  Widget _buildCardBack(Word word, bool isDark) {
    final wordKey = word.word.toLowerCase().trim();
    final dictEntry = _dictCache[wordKey];
    final isLoading = _dictLoading.contains(wordKey);
    final posNormalized = PosNormalizer.normalize(word.pos);

    final textPrimary = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final accentColor = const Color(0xFF7C3AED);
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF6C63FF)).withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Phần 1: Nghĩa chính từ DB ──
                    Center(
                      child: Column(
                        children: [
                          // POS badge
                          if (posNormalized != null) ...[
                            _buildPosBadge(posNormalized, onDark: false),
                            const SizedBox(height: 10),
                          ],
                          // Nghĩa
                          Text(
                            word.meaning,
                            style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w800,
                              color: textPrimary, height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Ví dụ từ DB ──
                    if (word.example.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border(
                            left: BorderSide(
                              color: accentColor.withOpacity(0.5),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_quote_rounded,
                                    color: accentColor.withOpacity(0.6), size: 18),
                                const SizedBox(width: 6),
                                Text('Ví dụ:',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _speak(word.example),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.volume_up_rounded, color: accentColor, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              word.example,
                              style: TextStyle(
                                fontSize: 15, color: textPrimary.withOpacity(0.85),
                                fontStyle: FontStyle.italic, height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Phần 2: Nghĩa mở rộng từ Dictionary API ──
                    if (isLoading)
                      _buildDictShimmer(isDark: isDark)
                    else if (dictEntry != null)
                      _buildDictExtended(dictEntry, isDark: isDark),
                  ],
                ),
              ),
            ),

            // ── Pinned AI Actions ──
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildAiActionButton(
                      icon: Icons.auto_awesome,
                      label: 'Hỏi AI',
                      color: const Color(0xFF8B5CF6), // Purple to match theme
                      onTap: () => _showAiBottomSheet(word),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAiActionButton(
                      icon: Icons.edit_note_rounded,
                      label: 'Đặt câu AI',
                      color: const Color(0xFF3B82F6), // Blue to match theme
                      onTap: () => _showAiSentencePractice(word),
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

  // ═══════════════════════════════════════════
  // DICTIONARY EXTENDED SECTION
  // ═══════════════════════════════════════════
  Widget _buildDictExtended(DictionaryEntry entry, {bool isDark = false}) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final accentColor = const Color(0xFF7C3AED);
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: dividerColor, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '📖 Nghĩa mở rộng',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13, fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: Divider(color: dividerColor, thickness: 1)),
          ],
        ),
        const SizedBox(height: 10),

        // Meanings grouped by POS
        for (final meaning in entry.meanings) ...[
          // POS header
          _buildPosBadge(
            PosNormalizer.normalizeOrKeep(meaning.partOfSpeech),
            onDark: false,
          ),
          const SizedBox(height: 6),

          // Definitions
          for (int i = 0; i < meaning.definitions.length && i < 3; i++) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Definition EN
                  Text(
                    '${i + 1}. ${meaning.definitions[i].definition}',
                    style: TextStyle(
                      fontSize: 14, color: textPrimary,
                      height: 1.5,
                    ),
                  ),
                  // Definition VI (if available)
                  if (meaning.definitions[i].definitionVi != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '→ ${meaning.definitions[i].definitionVi}',
                        style: TextStyle(
                          fontSize: 13, color: textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  // Example
                  if (meaning.definitions[i].example != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '📌 ${meaning.definitions[i].example}',
                        style: TextStyle(
                          fontSize: 13, color: textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Synonyms chips
          if (meaning.synonyms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: meaning.synonyms.take(6).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12, color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],

          // Antonyms chips
          if (meaning.antonyms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Text('Trái nghĩa: ', style: TextStyle(
                  fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold,
                )),
                ...meaning.antonyms.take(4).map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                )),
              ],
            ),
          ],

          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // SHIMMER LOADING FOR DICT
  // ═══════════════════════════════════════════
  Widget _buildDictShimmer({bool isDark = false}) {
    final shimmerBase = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final shimmerHighlight = isDark ? Colors.grey.shade600 : Colors.grey.shade100;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: dividerColor, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '📖 Đang tải...',
                style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: dividerColor, thickness: 1)),
          ],
        ),
        const SizedBox(height: 10),
        // Shimmer skeleton lines
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 14,
              width: [200.0, 260.0, 180.0, 220.0][i],
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(6),
              ),
            ).animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: shimmerHighlight,
              ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // SM2 / FLIP BUTTONS (Fixed bottom)
  // ═══════════════════════════════════════════
  Widget _buildBottomActions(bool isDark) {
    if (_words.isEmpty) return const SizedBox();
    final currentWord = _words[_currentIndex];
    final progress = _progressCache[currentWord.id] ?? UserWordProgress(wordId: currentWord.id!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: !_isFlipped
          ? SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _flipCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Lật thẻ xem nghĩa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ),
            )
          : Row(
              children: [
                _buildRateButton('Quên', '😵', const Color(0xFFEF4444), 0, progress),
                const SizedBox(width: 8),
                _buildRateButton('Khó', '😐', const Color(0xFFF59E0B), 3, progress),
                const SizedBox(width: 8),
                _buildRateButton('Tốt', '🙂', const Color(0xFF22C55E), 4, progress),
                const SizedBox(width: 8),
                _buildRateButton('Dễ', '😎', const Color(0xFF3B82F6), 5, progress),
              ],
            ).animate().fade(duration: 300.ms).slideY(begin: 0.15, end: 0, duration: 300.ms),
    );
  }

  String _formatInterval(int days) {
    if (days == 0) return 'Lại';
    if (days < 30) return '${days}d';
    if (days < 365) return '${(days / 30).round()}m';
    return '${(days / 365).round()}y';
  }

  Widget _buildRateButton(String label, String emoji, Color color, int quality, UserWordProgress progress) {
    final nextInterval = SrsService.previewNextIntervalDays(quality, progress);
    final intervalStr = quality < 3 ? '1d' : _formatInterval(nextInterval);

    return Expanded(
      child: SizedBox(
        height: 54,
        child: TextButton(
          onPressed: _isMarkingLearned ? null : () => _rateWord(quality),
          style: TextButton.styleFrom(
            backgroundColor: color.withOpacity(0.12),
            foregroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                ],
              ),
              const SizedBox(height: 2),
              Text(intervalStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BOTTOM NAVIGATION BAR
  // ═══════════════════════════════════════════
  Widget _buildNavigationBar(Word currentWord, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.arrow_back_ios_rounded,
              onPressed: _currentIndex > 0 ? _previousCard : null,
              isDark: isDark,
            ),
            _buildControlButton(
              icon: Icons.volume_up_rounded,
              onPressed: () => _speak(currentWord.word),
              isDark: isDark,
              isPrimary: true,
              primaryColor: const Color(0xFF22C55E),
            ),
            _buildControlButton(
              icon: Icons.flip_rounded,
              onPressed: _flipCard,
              isDark: isDark,
              isPrimary: true,
              primaryColor: const Color(0xFF7C3AED),
            ),
            _buildControlButton(
              icon: Icons.arrow_forward_ios_rounded,
              onPressed: _nextCard,
              isDark: isDark,
            ),
          ],
        ),
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
    final color = primaryColor ?? const Color(0xFF7C3AED);
    return Container(
      decoration: isPrimary
          ? BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            )
          : null,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: isPrimary ? 24 : 24),
        color: isPrimary
            ? Colors.white
            : (onPressed != null
                ? (isDark ? Colors.white70 : Colors.grey.shade600)
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade400)),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CARD CONTAINER
  // ═══════════════════════════════════════════
  Widget _buildCard({required Widget child, required Gradient gradient}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════
  Widget _buildPosBadge(String pos, {bool onDark = false}) {
    final style = PosNormalizer.getStyle(pos);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withOpacity(0.15)
            : Color(style.bgColorValue),
        borderRadius: BorderRadius.circular(10),
        border: onDark
            ? Border.all(color: Colors.white.withOpacity(0.2))
            : null,
      ),
      child: Text(
        pos,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: onDark ? Colors.white.withOpacity(0.9) : Color(style.textColorValue),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        level,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAiActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // AI Bottom Sheet (Hỏi AI) — giữ nguyên
  // ═══════════════════════════════════════════
  void _showAiBottomSheet(Word word) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiBottomSheet(
        word: word,
        aiService: _aiService,
        isDark: isDark,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // AI Sentence Practice (Luyện đặt câu AI)
  // ═══════════════════════════════════════════
  void _showAiSentencePractice(Word word) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiSentencePracticeSheet(
        word: word,
        aiService: _aiService,
        isDark: isDark,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ✨ AI Bottom Sheet Widget — Trợ lý Tipo (giữ nguyên logic)
// ═══════════════════════════════════════════════════════════════
class AiBottomSheet extends StatefulWidget {
  final Word word;
  final AiService aiService;
  final bool isDark;

  const AiBottomSheet({
    required this.word,
    required this.aiService,
    required this.isDark,
  });

  @override
  State<AiBottomSheet> createState() => AiBottomSheetState();
}

class AiBottomSheetState extends State<AiBottomSheet> with TickerProviderStateMixin {
  bool _isLoading = false;
  String _result = '';
  int _selectedAction = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cache cục bộ: tránh gọi lại cùng action cho cùng từ
  final Map<int, String> _localCache = {};

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
    // Nếu đã cache thì dùng lại, không gọi API
    if (_localCache.containsKey(action)) {
      setState(() {
        _selectedAction = action;
        _result = _localCache[action]!;
      });
      return;
    }

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
      _localCache[action] = response; // Cache lại
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
              blurRadius: 20, offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59B6), Color(0xFFE91E8C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🤖', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trợ lý Tipo',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Đang học từ: ${widget.word.word}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
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
            // Content
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
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Center(child: Text('🤖', style: TextStyle(fontSize: 36))),
              ),
            ),
            const SizedBox(height: 20),
            Text('Xin chào! Tôi là Tipo 👋',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('Tôi sẽ giúp bạn hiểu từ "${widget.word.word}" tốt hơn!\nHãy chọn một chức năng phía trên.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5,
                color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final labels = ['Ví dụ', 'Đồng nghĩa', 'Cách dùng'];
    final actionLabel = _selectedAction >= 0 && _selectedAction < labels.length
        ? labels[_selectedAction] : '';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(child: Text('🤔', style: TextStyle(fontSize: 28))),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tipo đang suy nghĩ...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 4),
          Text('Đang tạo $actionLabel cho "${widget.word.word}"',
            style: TextStyle(fontSize: 12,
              color: widget.isDark ? Colors.grey.shade500 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildResultState(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  blurRadius: 10, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFE91E8C)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Text('🤖', style: TextStyle(fontSize: 14))),
                    ),
                    const SizedBox(width: 8),
                    Text('Tipo',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: widget.isDark ? const Color(0xFF8B7CF6) : const Color(0xFF6C63FF))),
                    const Spacer(),
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF4ADE80)),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: _result,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 14.5, height: 1.6,
                      color: widget.isDark ? Colors.grey.shade300 : Colors.black87),
                    strong: TextStyle(fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B)),
                    em: TextStyle(fontStyle: FontStyle.italic,
                      color: widget.isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                    listBullet: TextStyle(fontSize: 14,
                      color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                    h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87),
                    h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87),
                    blockquoteDecoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF1F5F9),
                      border: const Border(left: BorderSide(color: Color(0xFF6C63FF), width: 3)),
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
            gradient: isSelected ? LinearGradient(colors: [color, color.withOpacity(0.8)]) : null,
            color: isSelected ? null : (widget.isDark ? const Color(0xFF2A2A3E) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ✨ AI Sentence Practice Sheet — Luyện đặt câu AI
// ═══════════════════════════════════════════════════════════════
class AiSentencePracticeSheet extends StatefulWidget {
  final Word word;
  final AiService aiService;
  final bool isDark;

  const AiSentencePracticeSheet({
    required this.word,
    required this.aiService,
    required this.isDark,
  });

  @override
  State<AiSentencePracticeSheet> createState() => AiSentencePracticeSheetState();
}

class AiSentencePracticeSheetState extends State<AiSentencePracticeSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String _result = '';

  Future<void> _submitSentence() async {
    final sentence = _controller.text.trim();
    if (sentence.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      _result = await widget.aiService.evaluateSentence(
        widget.word.word,
        sentence,
        meaning: widget.word.meaning,
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Luyện đặt câu',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: widget.isDark ? Colors.white : Colors.black87)),
                        Text('Hãy đặt câu với từ "${widget.word.word}"',
                          style: TextStyle(fontSize: 13,
                            color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Input area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Viết câu tiếng Anh có sử dụng từ "${widget.word.word}"...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: widget.isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: widget.isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: widget.isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                ),
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Submit button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitSentence,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_isLoading ? 'Đang kiểm tra...' : 'Kiểm tra câu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Result
            if (_result.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF2A2A3E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      ),
                    ),
                    child: MarkdownBody(
                      data: _result,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 14.5, height: 1.6,
                          color: widget.isDark ? Colors.grey.shade300 : Colors.black87),
                        strong: TextStyle(fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : const Color(0xFF1E293B)),
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
