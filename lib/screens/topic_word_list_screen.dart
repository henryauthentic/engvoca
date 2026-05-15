import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../utils/topic_images.dart';
import '../utils/pos_normalizer.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/skeleton_loader.dart';
import 'flashcard_screen.dart';
import 'word_detail_screen.dart';

/// Màn hình danh sách từ vựng của 1 chủ đề con.
/// Đóng vai trò bước đệm trước khi vào Flashcard.
class TopicWordListScreen extends StatefulWidget {
  final Topic topic;
  final Topic? parentTopic;

  const TopicWordListScreen({
    super.key,
    required this.topic,
    this.parentTopic,
  });

  @override
  State<TopicWordListScreen> createState() => _TopicWordListScreenState();
}

class _TopicWordListScreenState extends State<TopicWordListScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final FlutterTts _tts = FlutterTts();

  List<Word> _words = [];
  Set<String> _difficultWordIds = {};
  bool _isLoading = true;
  int _learnedCount = 0;

  /// Lấy ảnh topic: ưu tiên parent, rồi topic hiện tại
  String? get _topicImagePath {
    if (widget.parentTopic != null) {
      final p = TopicImages.getPath(widget.parentTopic!.name);
      if (p != null) return p;
    }
    return TopicImages.getPath(widget.topic.name);
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      final words = await _dbHelper.getWordsByTopic(widget.topic.id!);
      words.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      
      final difficultWords = await _dbHelper.getDifficultWords(topicId: widget.topic.id!, limit: 1000);
      final difficultIds = difficultWords.map((w) => w.id!).toSet();

      setState(() {
        _words = words;
        _difficultWordIds = difficultIds;
        _learnedCount = words.where((w) => w.isLearned).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDifficult(String wordId) async {
    await _dbHelper.toggleDifficult(wordId);
    setState(() {
      if (_difficultWordIds.contains(wordId)) {
        _difficultWordIds.remove(wordId);
      } else {
        _difficultWordIds.add(wordId);
      }
    });
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _openFlashcard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          topic: widget.topic,
          parentTopic: widget.parentTopic,
          preloadedWords: _words,
        ),
      ),
    );
    _loadWords(); // refresh sau khi học
  }

  void _openFlashcardRandom() async {
    final shuffled = List<Word>.from(_words)..shuffle();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          topic: widget.topic,
          parentTopic: widget.parentTopic,
          preloadedWords: shuffled,
        ),
      ),
    );
    _loadWords(); // refresh sau khi học
  }

  void _openFlashcardDifficult() async {
    final difficultWords = await _dbHelper.getDifficultWords(topicId: widget.topic.id!, limit: 50);
    if (difficultWords.isEmpty) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          topic: widget.topic,
          parentTopic: widget.parentTopic,
          preloadedWords: difficultWords,
          isQuickReview: true, // Không cập nhật lịch SM-2 nếu user chọn "Chỉ ôn từ khó"
        ),
      ),
    );
    _loadWords(); // refresh
  }

  void _showPracticeModeSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PracticeModeBottomSheet(
        isDark: isDark,
        onSequential: () {
          Navigator.pop(ctx);
          _openFlashcard();
        },
        onRandom: () {
          Navigator.pop(ctx);
          _openFlashcardRandom();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _words.isEmpty ? 0.0 : _learnedCount / _words.length;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ═══ CUSTOM HEADER (MOCKUP STYLE) ═══
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Background Gradient
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFE8EAF6),
                        const Color(0xFFC5CAE9),
                      ],
                    ),
                  ),
                ),
                
                // Back Button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // White Card Header
                Container(
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 20, right: 20, bottom: 10,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Parent Topic (Tiếng Anh lớp 11)
                            Row(
                              children: [
                                Icon(Icons.menu_book_rounded, size: 16, color: Colors.indigo.shade400),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.parentTopic?.name ?? 'Chủ đề',
                                    style: TextStyle(
                                      color: Colors.indigo.shade400,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Current Topic
                            Text(
                              widget.topic.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.isNaN || progress.isInfinite ? 0 : progress,
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.indigo.shade50,
                                color: Colors.indigoAccent,
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Stats Text
                            Row(
                              children: [
                                Text(
                                  '${_words.length} từ vựng',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4, height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Đã học $_learnedCount từ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Illustration (Right side)
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(Icons.school_rounded, size: 40, color: Colors.indigo.shade200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ═══ BIG ACTION BUTTON ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _words.isEmpty ? null : _openFlashcard,
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
                        label: const Text(
                          'Tiếp tục học',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: Colors.indigoAccent.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 54,
                    width: 54,
                    child: ElevatedButton(
                      onPressed: _words.isEmpty ? null : _showPracticeModeSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                        foregroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══ HEADER ROW ("Từ vựng (14)" & "Chọn chế độ học") ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Từ vựng (${_words.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: _words.isEmpty ? null : _showPracticeModeSheet,
                    child: Row(
                      children: [
                        Text(
                          'Chọn chế độ học',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.indigoAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.checklist_rtl_rounded, size: 16, color: Colors.indigoAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══ ÔN TỪ KHÓ BUTTON ═══
          if (!_isLoading && _difficultWordIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: _openFlashcardDifficult,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ôn tập ${_difficultWordIds.length} từ khó',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.orange.shade300 : Colors.orange.shade800),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ═══ LOADING STATE ═══
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SkeletonCard(height: 90),
                  ),
                  childCount: 6,
                ),
              ),
            ),

          // ═══ EMPTY STATE ═══
          if (!_isLoading && _words.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có từ vựng nào',
                      style: TextStyle(fontSize: 16, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

          // ═══ WORD LIST ═══
          if (!_isLoading && _words.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final word = _words[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WordCard(
                        word: word,
                        index: index,
                        isDifficult: _difficultWordIds.contains(word.id),
                        onToggleDifficult: () => _toggleDifficult(word.id!),
                        topicImagePath: _topicImagePath,
                        isDark: isDark,
                        onSpeak: () => _speak(word.word),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WordDetailScreen(
                                words: _words,
                                initialIndex: index,
                              ),
                            ),
                          );
                          _loadWords();
                        },
                      ),
                    );
                  },
                  childCount: _words.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// WORD CARD — Thẻ từ vựng premium
// ═══════════════════════════════════════════════════
class _WordCard extends StatelessWidget {
  final Word word;
  final int index;
  final bool isDifficult;
  final VoidCallback onToggleDifficult;
  final String? topicImagePath;
  final bool isDark;
  final VoidCallback onSpeak;
  final VoidCallback onTap;

  const _WordCard({
    required this.word,
    required this.index,
    required this.isDifficult,
    required this.onToggleDifficult,
    this.topicImagePath,
    required this.isDark,
    required this.onSpeak,
    required this.onTap,
  });

  Color _getStripColor(int index) {
    final colors = [
      Colors.indigoAccent,
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final posNormalized = PosNormalizer.normalize(word.pos);
    final posStyle = posNormalized != null ? PosNormalizer.getStyle(posNormalized) : null;
    final stripColor = _getStripColor(index);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4), // margin cho shadow
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Dải màu viền trái ──
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: stripColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              // ── Ảnh minh họa (Hình vuông bo tròn) ──
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _buildImage(),
                  ),
                ),
              ),

              // ── Nội dung bên phải ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Row 1: Tên từ + Bookmark
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word.word,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (word.pronunciation.isNotEmpty)
                                  Text(
                                    word.pronunciation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.indigoAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onToggleDifficult,
                            child: Icon(
                              isDifficult ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isDifficult ? Colors.orange : Colors.indigoAccent,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Row 2: Nghĩa tiếng Việt + Các nút Action
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Nghĩa
                          Expanded(
                            child: Text(
                              word.meaning,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Action buttons (Loa, Mic, Chat) thu nhỏ
                          Row(
                            children: [
                              _ActionIcon(
                                icon: Icons.volume_up_rounded,
                                onTap: onSpeak,
                                isDark: isDark,
                                color: stripColor,
                              ),
                              const SizedBox(width: 8),
                              _ActionIcon(
                                icon: Icons.mic_rounded,
                                onTap: () {},
                                isDark: isDark,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 8),
                              _ActionIcon(
                                icon: Icons.chat_bubble_outline_rounded,
                                onTap: onTap,
                                isDark: isDark,
                                color: Colors.redAccent,
                              ),
                            ],
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

  Widget _buildImage() {
    // Ưu tiên ảnh riêng của từ, nếu không có → ảnh topic
    if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
      if (word.imageUrl!.startsWith('http')) {
        return Image.network(
          word.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackImage(),
        );
      }
      return Image.asset(
        word.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    if (topicImagePath != null) {
      return Image.asset(
        topicImagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFE8E8F0),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 32, color: Colors.grey),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ACTION ICON BUTTON
// ═══════════════════════════════════════════════════
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color color;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// BOTTOM SHEET — Chọn chế độ luyện tập
// ═══════════════════════════════════════════════════
class _PracticeModeBottomSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSequential;
  final VoidCallback onRandom;

  const _PracticeModeBottomSheet({
    required this.isDark,
    required this.onSequential,
    required this.onRandom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Chế độ học',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Practice modes
          _PracticeModeItem(
            icon: '🎓',
            label: 'Học theo thứ tự',
            isDark: isDark,
            onTap: onSequential,
          ),
          _PracticeModeItem(
            icon: '🔀',
            label: 'Ôn tập ngẫu nhiên',
            isDark: isDark,
            onTap: onRandom,
          ),
          _PracticeModeItem(
            icon: '⚙️',
            label: 'Cài đặt học tập',
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng cài đặt đang phát triển...')),
              );
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _PracticeModeItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _PracticeModeItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
