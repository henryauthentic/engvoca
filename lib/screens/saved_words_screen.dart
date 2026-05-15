import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../theme/theme_extensions.dart';
import 'flashcard_screen.dart';

class SavedWordsScreen extends StatefulWidget {
  const SavedWordsScreen({super.key});

  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final FlutterTts _tts = FlutterTts();
  
  List<Word> _difficultWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      final words = await _dbHelper.getDifficultWords(limit: 1000);
      setState(() {
        _difficultWords = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDifficult(String wordId) async {
    await _dbHelper.toggleDifficult(wordId);
    _loadWords();
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _openQuickReview() {
    if (_difficultWords.isEmpty) return;
    
    // Create a dummy topic for the flashcard screen
    final dummyTopic = Topic(
      id: 'difficult_words',
      name: 'Từ khó của bạn',
      description: 'Ôn tập các từ bạn hay sai',
      totalWords: _difficultWords.length,
      orderIndex: 0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          topic: dummyTopic,
          preloadedWords: _difficultWords.take(30).toList(), // Limit to 30 for quick review
          isQuickReview: true,
        ),
      ),
    ).then((_) => _loadWords());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ═══ APP BAR ═══
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? context.surfaceColor : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Từ khó của bạn',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF4A2511), const Color(0xFF2A1508)]
                        : [const Color(0xFFFFE4D6), const Color(0xFFFFF2E8)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: 20,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 140,
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.deepOrange.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ═══ ÔN TẬP BUTTON ═══
          if (!_isLoading && _difficultWords.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: GestureDetector(
                  onTap: _openQuickReview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A00), Color(0xFFFF5C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7A00).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Ôn tập Adaptive (Max 30 từ)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ═══ STATS ═══
          if (!_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Text(
                      'Tất cả từ khó (${_difficultWords.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ═══ LIST ═══
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
            )
          else if (_difficultWords.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Tuyệt vời!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bạn không có từ khó nào cần ôn.',
                      style: TextStyle(fontSize: 15, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final word = _difficultWords[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildWordCard(word, index, isDark),
                    );
                  },
                  childCount: _difficultWords.length,
                ),
              ),
            ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildWordCard(Word word, int index, bool isDark) {
    // Style B: Card đẹp
    return Container(
      decoration: BoxDecoration(
        color: isDark ? context.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Color strip
              Container(
                width: 6,
                color: Colors.deepOrange.shade400,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    word.word,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  word.pronunciation.isNotEmpty ? '/${word.pronunciation}/' : '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              word.meaning,
                              style: TextStyle(
                                fontSize: 15,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Actions
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _toggleDifficult(word.id!),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.orange,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _speak(word.word),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.volume_up_rounded,
                                color: Colors.blue,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
