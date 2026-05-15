import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/word.dart';
import '../models/dictionary_entry.dart';
import '../models/image_data.dart';
import '../db/database_helper.dart';
import '../services/dictionary_service.dart';
import '../services/unsplash_service.dart';
import '../utils/pos_normalizer.dart';
import '../theme/theme_extensions.dart';

class WordDetailScreen extends StatefulWidget {
  final List<Word> words;
  final int initialIndex;

  const WordDetailScreen({
    super.key,
    required this.words,
    this.initialIndex = 0,
  });

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final FlutterTts _tts = FlutterTts();
  final _dictService = DictionaryService();
  final _unsplashService = UnsplashService();

  late PageController _pageController;
  late int _currentIndex;

  // Caches
  final Map<String, DictionaryEntry?> _dictCache = {};
  final Set<String> _dictLoading = {};
  final Map<String, ImageData?> _unsplashCache = {};
  final Set<String> _unsplashLoading = {};
  final Map<String, bool> _difficultStates = {};
  final Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.88,
    );
    _initTts();
    _loadDifficultStates();
    _fetchDictForCurrent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _loadDifficultStates() async {
    for (final w in widget.words) {
      if (w.id != null) {
        final p = await _dbHelper.getWordProgress(w.id!);
        if (p != null) _difficultStates[w.id!] = p.isDifficult;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleBookmark(String wordId) async {
    await _dbHelper.toggleDifficult(wordId);
    final p = await _dbHelper.getWordProgress(wordId);
    if (mounted) {
      setState(() => _difficultStates[wordId] = p?.isDifficult ?? false);
    }
  }

  void _fetchDictForCurrent() {
    if (_currentIndex < widget.words.length) {
      _fetchDict(widget.words[_currentIndex].word);
    }
  }

  Future<void> _fetchDict(String wordText) async {
    final key = wordText.toLowerCase().trim();
    if (_dictCache.containsKey(key) || _dictLoading.contains(key)) return;
    _dictLoading.add(key);
    if (mounted) setState(() {});
    try {
      final results = await _dictService.searchWord(key);
      _dictCache[key] = results.isNotEmpty ? results.first : null;
    } catch (e) {
      _dictCache[key] = null;
    }
    _dictLoading.remove(key);
    if (mounted) setState(() {});
  }

  void _prefetchUnsplash(String wordText) {
    final key = wordText.toLowerCase().trim();
    if (_unsplashCache.containsKey(key) || _unsplashLoading.contains(key)) return;
    _unsplashLoading.add(key);
    _unsplashService.getImage(wordText).then((data) {
      if (mounted) setState(() {
        _unsplashCache[key] = data;
        _unsplashLoading.remove(key);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentWord = widget.words[_currentIndex];
    final isBookmarked = _difficultStates[currentWord.id] ?? false;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('Chi tiết từ vựng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          GestureDetector(
            onTap: () => _speak(currentWord.word),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withOpacity(0.12),
              ),
              child: const Icon(Icons.volume_up_rounded, color: Color(0xFF22C55E), size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { if (currentWord.id != null) _toggleBookmark(currentWord.id!); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBookmarked ? const Color(0xFFFFB400) : const Color(0xFFFFB400).withOpacity(0.12),
              ),
              child: Icon(
                isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isBookmarked ? Colors.white : const Color(0xFFFFB400),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.words.length,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                _fetchDict(widget.words[i].word);
                _prefetchUnsplash(widget.words[i].word);
              },
              itemBuilder: (context, index) {
                return _AnimatedCardWrapper(
                  pageController: _pageController,
                  currentIndex: _currentIndex,
                  index: index,
                  child: _buildCard(widget.words[index], isDark),
                );
              },
            ),
          ),
          // Footer hint
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chevron_left_rounded,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Vuốt trái hoặc phải để xem từ khác',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CARD
  // ═══════════════════════════════════════════
  Widget _buildCard(Word word, bool isDark) {
    final wordKey = word.word.toLowerCase().trim();
    final dictEntry = _dictCache[wordKey];
    final isDictLoading = _dictLoading.contains(wordKey);
    final posNormalized = PosNormalizer.normalize(word.pos);
    final primaryColor = context.primaryColor;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2B2D42);
    final textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF8D99AE);
    final cardBg = isDark ? const Color(0xFF1F2125) : Colors.white;
    final isExpanded = _expandedStates[wordKey] ?? false;

    // Section-specific colors
    const meaningColor = Color(0xFF6C63FF);   // Purple-blue (primary)
    const exampleColor = Color(0xFF22C55E);   // Green
    const dictColor = Color(0xFF3B82F6);      // Blue
    const synonymColor = Color(0xFF8B5CF6);   // Violet
    const saveColor = Color(0xFFFFB400);       // Amber

    _prefetchUnsplash(word.word);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : primaryColor).withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 28, spreadRadius: 0, offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
            blurRadius: 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1: Word + Image + POS ──
              _buildWordHeader(word, posNormalized, isDark, textPrimary, primaryColor),
              const SizedBox(height: 20),

              // ── Section 2: Meaning ──
              _buildSectionTitle('📖', 'Nghĩa', meaningColor),
              const SizedBox(height: 8),
              Text(word.meaning,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 20),

              // ── Section 3: Examples ──
              if (word.example.isNotEmpty) ...[
                _buildSectionTitle('❝', 'Ví dụ', exampleColor),
                const SizedBox(height: 8),
                _buildExampleBlock(word.example, isDark, textPrimary, exampleColor),
                const SizedBox(height: 20),
              ],

              // ── Section 4: Dict Extended (Expandable) ──
              if (isDictLoading)
                _buildDictShimmer(isDark)
              else if (dictEntry != null) ...[
                _buildDictSection(dictEntry, isDark, textPrimary, textSecondary, dictColor, synonymColor, isExpanded, wordKey),
              ],

              const SizedBox(height: 20),

              // ── Section 5: Save Button ──
              _buildSaveButton(word, isDark, saveColor),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // WORD HEADER: word + pronunciation + image + POS
  // ═══════════════════════════════════════════
  Widget _buildWordHeader(Word word, String? pos, bool isDark, Color textPrimary, Color accent) {
    final unsplashData = _unsplashCache[word.word.toLowerCase().trim()];
    final hasImage = unsplashData != null && unsplashData.imageUrl.isNotEmpty;

    const speakerColor = Color(0xFF22C55E);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(word.word,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _speak(word.word),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: speakerColor.withOpacity(0.12),
                      ),
                      child: Icon(Icons.volume_up_rounded, color: speakerColor, size: 16),
                    ),
                  ),
                ],
              ),
              if (word.pronunciation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(word.pronunciation,
                    style: TextStyle(fontSize: 15, color: accent.withOpacity(0.6), fontStyle: FontStyle.italic)),
                ),
              if (pos != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildPosPill(pos),
                ),
            ],
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              unsplashData!.imageUrl, width: 90, height: 90, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // EXAMPLE BLOCK
  // ═══════════════════════════════════════════
  Widget _buildExampleBlock(String example, bool isDark, Color textPrimary, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent.withOpacity(0.4), width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(example,
              style: TextStyle(fontSize: 15, color: textPrimary.withOpacity(0.85), fontStyle: FontStyle.italic, height: 1.5)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _speak(example),
            child: Icon(Icons.volume_up_rounded, color: accent.withOpacity(0.5), size: 20),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DICT SECTION (Expandable)
  // ═══════════════════════════════════════════
  Widget _buildDictSection(DictionaryEntry entry, bool isDark, Color textPrimary, Color textSecondary, Color accent, Color synonymColor, bool isExpanded, String wordKey) {
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand toggle
        GestureDetector(
          onTap: () => setState(() => _expandedStates[wordKey] = !isExpanded),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              Text('Nghĩa chi tiết', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
              const Spacer(),
              Text(isExpanded ? 'Thu gọn' : 'Xem thêm',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent.withOpacity(0.7))),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: accent.withOpacity(0.7), size: 20),
              ),
            ],
          ),
        ),
        Divider(color: dividerColor, height: 16),

        // Content
        AnimatedCrossFade(
          firstChild: _buildDictPreview(entry, textPrimary, textSecondary, accent),
          secondChild: _buildDictFull(entry, textPrimary, textSecondary, accent, isDark),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),

        // Synonyms (always visible)
        if (entry.meanings.any((m) => m.synonyms.isNotEmpty)) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.diamond_outlined, size: 16, color: synonymColor.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text('Từ đồng nghĩa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: entry.meanings
                .expand((m) => m.synonyms)
                .take(8)
                .map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: synonymColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 12, color: synonymColor, fontWeight: FontWeight.w600)),
                )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDictPreview(DictionaryEntry entry, Color textPrimary, Color textSecondary, Color accent) {
    // Show first meaning, first definition only
    if (entry.meanings.isEmpty) return const SizedBox.shrink();
    final m = entry.meanings.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPosPill(PosNormalizer.normalizeOrKeep(m.partOfSpeech)),
        const SizedBox(height: 6),
        if (m.definitions.isNotEmpty)
          Text('1. ${m.definitions.first.definition}',
            style: TextStyle(fontSize: 14, color: textPrimary, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        if (m.definitions.isNotEmpty && m.definitions.first.definitionVi != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('→ ${m.definitions.first.definitionVi}',
              style: TextStyle(fontSize: 13, color: textSecondary, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildDictFull(DictionaryEntry entry, Color textPrimary, Color textSecondary, Color accent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final meaning in entry.meanings) ...[
          _buildPosPill(PosNormalizer.normalizeOrKeep(meaning.partOfSpeech)),
          const SizedBox(height: 6),
          for (int i = 0; i < meaning.definitions.length && i < 3; i++) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${meaning.definitions[i].definition}',
                    style: TextStyle(fontSize: 14, color: textPrimary, height: 1.5)),
                  if (meaning.definitions[i].definitionVi != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('→ ${meaning.definitions[i].definitionVi}',
                        style: TextStyle(fontSize: 13, color: textSecondary, fontStyle: FontStyle.italic)),
                    ),
                  if (meaning.definitions[i].example != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('📌 ${meaning.definitions[i].example}',
                        style: TextStyle(fontSize: 13, color: textSecondary, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // SHIMMER
  // ═══════════════════════════════════════════
  Widget _buildDictShimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlight = isDark ? Colors.grey.shade600 : Colors.grey.shade100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Text('Đang tải...', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 14, width: [200.0, 260.0, 180.0][i],
              decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: highlight),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // SAVE BUTTON
  // ═══════════════════════════════════════════
  Widget _buildSaveButton(Word word, bool isDark, Color accent) {
    final isSaved = _difficultStates[word.id] ?? false;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () { if (word.id != null) _toggleBookmark(word.id!); },
        icon: Icon(isSaved ? Icons.star_rounded : Icons.star_outline_rounded, size: 20),
        label: Text(isSaved ? 'Đã lưu' : 'Lưu từ này',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSaved ? accent.withOpacity(0.12) : accent,
          foregroundColor: isSaved ? accent : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════
  Widget _buildSectionTitle(String emoji, String title, Color accent) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
      ],
    );
  }

  Widget _buildPosPill(String pos) {
    final style = PosNormalizer.getStyle(pos);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color(style.bgColorValue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(pos, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(style.textColorValue))),
    );
  }
}

// ═══════════════════════════════════════════
// ANIMATED CARD WRAPPER (scale + opacity effect)
// ═══════════════════════════════════════════
class _AnimatedCardWrapper extends StatelessWidget {
  final PageController pageController;
  final int currentIndex;
  final int index;
  final Widget child;

  const _AnimatedCardWrapper({
    required this.pageController,
    required this.currentIndex,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        double scale = 1.0;
        double opacity = 1.0;
        if (pageController.position.haveDimensions) {
          double page = pageController.page ?? currentIndex.toDouble();
          double diff = (page - index).abs();
          scale = 1.0 - (diff * 0.06).clamp(0.0, 0.06);
          opacity = 1.0 - (diff * 0.35).clamp(0.0, 0.35);
        }
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        );
      },
    );
  }
}