import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../models/user.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../utils/topic_icons.dart';
import '../utils/topic_images.dart';
import '../theme/theme_extensions.dart';
import '../widgets/common/animated_list_item.dart';
import '../widgets/word_tile.dart';
import '../widgets/premium_word_card.dart';
import 'word_detail_screen.dart';
import 'add_word_screen.dart';
import 'flashcard_screen.dart';
import 'topic_word_list_screen.dart';
import 'sub_topic_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/topic_image_service.dart';
import '../services/auth_service.dart';
import '../widgets/common/premium_highlight_card.dart';

/// Tab "Từ vựng" — duyệt chủ đề lớn → chủ đề con → danh sách từ.
class VocabularyListScreen extends StatefulWidget {
  final String? filterParentId;
  final String? title;
  final String? scrollToTopicId;

  const VocabularyListScreen({super.key, this.filterParentId, this.title, this.scrollToTopicId});

  @override
  State<VocabularyListScreen> createState() => _VocabularyListScreenState();
}

class _VocabularyListScreenState extends State<VocabularyListScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  // Data
  List<Topic> _parentTopics = [];
  Map<String, List<Topic>> _childrenMap = {};
  bool _isLoading = true;

  // Scrolling
  final Map<String, GlobalKey<PremiumHighlightCardState>> _topicKeys = {};
  bool _hasScrolled = false;

  // Flat word list mode (khi có filterParentId hoặc search)
  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  String _filterType = 'all';
  bool _isWordListMode = false;
  
  // TTS & Word interactions
  final FlutterTts _tts = FlutterTts();
  Set<String> _difficultWordIds = {};

  User? _user;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initTts();
    _loadUserData();
    if (widget.filterParentId != null) {
      _isWordListMode = true;
      _loadWordsForParent();
    } else {
      _loadTopics();
    }
  }

  Future<void> _loadUserData() async {
    final userId = AuthService().currentUser?.uid;
    if (userId != null) {
      final userMap = await _dbHelper.getLocalUser(userId);
      if (userMap != null && mounted) {
        setState(() {
          _user = User.fromMap(userMap);
        });
      }
    }
  }

  @override
  void didUpdateWidget(VocabularyListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToTopicId != oldWidget.scrollToTopicId && widget.scrollToTopicId != null) {
      _hasScrolled = false;
      _scrollToTargetTopic();
    }
  }

  void _scrollToTargetTopic() {
    if (widget.scrollToTopicId != null && !_hasScrolled && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _topicKeys[widget.scrollToTopicId!];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.1, // Scroll so it's near the top
          ).then((_) {
            // Trigger highlight animation when scrolling finishes
            key.currentState?.playHighlight();
          });
          _hasScrolled = true;
        }
      });
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
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

  @override
  void dispose() {
    _tts.stop();
    _searchController.dispose();
    super.dispose();
  }

  // ── Load dữ liệu chủ đề 2 cấp ──
  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      await _dbHelper.updateTopicCounts();
      final parents = await _dbHelper.getParentTopics();
      Map<String, List<Topic>> childrenMap = {};
      for (var p in parents) {
        final children = await _dbHelper.getChildTopics(p.id!);
        childrenMap[p.id!] = children;
      }
      setState(() {
        _parentTopics = parents;
        _childrenMap = childrenMap;
        _isLoading = false;
      });
      _scrollToTargetTopic();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Load từ vựng flat (khi filterParentId) ──
  Future<void> _loadWordsForParent() async {
    setState(() => _isLoading = true);
    try {
      List<Word> allWords = [];
      if (widget.filterParentId != null) {
        allWords = await _dbHelper.getWordsByParentTopic(widget.filterParentId!);
      } else {
        allWords = await _dbHelper.getAllWords();
      }
      allWords.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      
      // Load difficult words for the list
      final difficultWords = await _dbHelper.getDifficultWords(limit: 5000); // Get all difficult
      final difficultIds = difficultWords.map((w) => w.id!).toSet();

      setState(() {
        _allWords = allWords;
        _filteredWords = allWords;
        _difficultWordIds = difficultIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_isWordListMode) {
      _filterWords();
    } else {
      setState(() {}); // Rebuild topic sections with filter
    }
  }

  void _filterWords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWords = _allWords.where((word) {
        final matchesSearch = word.word.toLowerCase().contains(query) ||
            word.meaning.toLowerCase().contains(query);
        final isLearning = !word.isLearned && word.reviewCount > 0;
        final isNew = !word.isLearned && word.reviewCount == 0;
        
        final matchesFilter = _filterType == 'all' ||
            (_filterType == 'learned' && word.isLearned) ||
            (_filterType == 'learning' && isLearning) ||
            (_filterType == 'unlearned' && isNew);
            
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _changeFilter(String type) {
    setState(() {
      _filterType = type;
      _filterWords();
    });
  }

  Color _getParentColor(int index) {
    final colors = [
      const Color(0xFF6C63FF), // purple
      const Color(0xFF4ADE80), // green
      const Color(0xFF3B82F6), // blue
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
      const Color(0xFF14B8A6), // teal
      const Color(0xFF8B5CF6), // violet
      const Color(0xFFEF4444), // red
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFF97316), // orange
      const Color(0xFF84CC16), // lime
      const Color(0xFFE11D48), // rose
      const Color(0xFF0EA5E9), // sky
      const Color(0xFFA855F7), // purple-bright
      const Color(0xFFE67E22), // orange-warm
      const Color(0xFF2980B9), // blue-deep
      const Color(0xFF8E44AD), // purple-deep
      const Color(0xFF1ABC9C), // teal-green
      const Color(0xFFE74C3C), // red-warm
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isWordListMode) {
      return _buildWordListMode(context);
    }
    return _buildTopicBrowser(context);
  }

  // ══════════════════════════════════════════════════════════════
  // MODE 1: Topic Browser (main tab)
  // ══════════════════════════════════════════════════════════════
  Widget _buildTopicBrowser(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int totalChildTopics = 0;
    _childrenMap.forEach((key, value) {
      totalChildTopics += value.length;
    });

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Từ vựng ✨',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Học từ vựng mỗi ngày, tiến bộ mỗi ngày ✨',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Search & Filter ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Tìm kiếm chủ đề...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.tune, color: AppConstants.primaryColor, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Bộ lọc',
                                style: TextStyle(
                                  color: AppConstants.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Stats Section ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('📘', _user?.learnedWords.toString() ?? '0', 'Từ đã học'),
                          _buildDivider(),
                          _buildStatItem('🔥', _user?.currentStreak.toString() ?? '0', 'Ngày streak'),
                          _buildDivider(),
                          _buildStatItem('⭐', _user?.totalXp.toString() ?? '0', 'XP hôm nay'),
                          _buildDivider(),
                          _buildStatItem('🎯', totalChildTopics.toString(), 'Chủ đề'),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Topic sections ──
                ..._buildTopicSections(isDark),

                // Bottom padding
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTopicSections(bool isDark) {
    final query = _searchController.text.toLowerCase();
    final List<Widget> sections = [];

    for (int i = 0; i < _parentTopics.length; i++) {
      final parent = _parentTopics[i];
      final children = _childrenMap[parent.id!] ?? [];
      final color = _getParentColor(i);

      // Filter children by search query
      final filteredChildren = query.isEmpty
          ? children
          : children.where((c) => c.name.toLowerCase().contains(query) || parent.name.toLowerCase().contains(query)).toList();

      if (query.isNotEmpty && filteredChildren.isEmpty && !parent.name.toLowerCase().contains(query)) {
        continue;
      }

      final displayChildren = filteredChildren.isEmpty ? children : filteredChildren;

      // Assign global key for scrolling
      if (!_topicKeys.containsKey(parent.id!)) {
        _topicKeys[parent.id!] = GlobalKey<PremiumHighlightCardState>();
      }
      final sectionKey = _topicKeys[parent.id!];

      // Combine Header and Horizontal List into a single PremiumHighlightCard
      sections.add(
        SliverPadding(
          padding: const EdgeInsets.only(top: 12),
          sliver: SliverToBoxAdapter(
            child: PremiumHighlightCard(
              key: sectionKey,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            TopicIcons.get(parent.name),
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            parent.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubTopicScreen(parentTopic: parent),
                              ),
                            ).then((_) {
                              _loadTopics();
                              _loadUserData();
                            });
                          },
                          child: Text(
                            'Xem thêm',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Horizontal topic cards
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayChildren.length,
                      itemBuilder: (context, index) {
                        final child = displayChildren[index];
                        return _buildChildTopicCard(child, parent, color, isDark);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return sections;
  }

  /// Derive badge label and color from parent topic name
  Map<String, dynamic>? _getBadgeInfo(String parentName) {
    final lower = parentName.toLowerCase();
    
    // Nếu là chủ đề Lớp
    if (lower.contains('lớp 6')) return {'label': 'G6', 'color': Colors.blue};
    if (lower.contains('lớp 7')) return {'label': 'G7', 'color': Colors.indigo};
    if (lower.contains('lớp 8')) return {'label': 'G8', 'color': Colors.teal};
    if (lower.contains('lớp 9')) return {'label': 'G9', 'color': Colors.green};
    if (lower.contains('lớp 10')) return {'label': 'G10', 'color': Colors.orange};
    if (lower.contains('lớp 11')) return {'label': 'G11', 'color': Colors.deepOrange};
    if (lower.contains('lớp 12')) return {'label': 'G12', 'color': Colors.red};
    
    // Nếu là bằng cấp
    if (lower.contains('ielts')) return {'label': 'IELTS', 'color': Colors.green};
    if (lower.contains('toeic')) return {'label': 'TOEIC', 'color': Colors.blue};
    if (lower.contains('b1')) return {'label': 'B1', 'color': const Color(0xFF8B5CF6)}; // Tím như mockup
    if (lower.contains('b2')) return {'label': 'B2', 'color': Colors.purple};
    if (lower.contains('c1')) return {'label': 'C1', 'color': Colors.deepPurple};
    if (lower.contains('c2')) return {'label': 'C2', 'color': Colors.pink};

    // Cơ bản
    if (lower.contains('cơ bản') || lower.contains('thông dụng')) {
      return {'label': 'BASIC', 'color': const Color(0xFFF97316)}; // Cam
    }

    // Các chủ đề tự do (như travel, giao tiếp...) -> null (Không hiện badge)
    return null;
  }

  Widget _buildChildTopicCard(Topic topic, Topic parentTopic, Color parentColor, bool isDark) {
    final progress = topic.wordCount > 0 ? (topic.learnedCount / topic.wordCount) : 0.0;
    final pctText = '${(progress * 100).toInt()}%';
    
    if (topic.imageUrl == null && topic.id != null) {
      TopicImageService.resolveAndSaveUrl(topic.id!, topic.name);
    }
    final imageUrlToShow = topic.imageUrl ?? TopicImageService.buildTempUrl(topic.name);
    
    final badgeInfo = _getBadgeInfo(parentTopic.name);

    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => isHovered = true),
            onTapUp: (_) => setState(() => isHovered = false),
            onTapCancel: () => setState(() => isHovered = false),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopicWordListScreen(
                    topic: topic,
                    parentTopic: parentTopic,
                  ),
                ),
              );
              _loadTopics();
              _loadUserData(); // Update XP, Streak, etc.
            },
            child: AnimatedScale(
              scale: isHovered ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              child: Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nửa trên: Ảnh ──
                    Expanded(
                      flex: 5,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: CachedNetworkImage(
                              imageUrl: imageUrlToShow,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          
                          // Badge (Góc trái trên)
                          if (badgeInfo != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeInfo['color'],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeInfo['label'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // ── Nửa dưới: Nền trắng, thông tin ──
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tên chủ đề
                            Text(
                              topic.name,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            
                            // Số từ x/y và Progress text
                            Row(
                              children: [
                                Icon(Icons.menu_book, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '${topic.learnedCount}/${topic.wordCount} từ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  pctText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            
                            // Thanh Progress bar mỏng
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.isNaN || progress.isInfinite ? 0 : progress,
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                color: badgeInfo != null ? badgeInfo['color'] : parentColor,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MODE 2: Flat word list (khi filterParentId hoặc từ route khác)
  // ══════════════════════════════════════════════════════════════
  Widget _buildWordListMode(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final learnedCount = _allWords.where((w) => w.isLearned).length;
    final learningCount = _allWords.where((w) => !w.isLearned && w.reviewCount > 0).length;
    final unlearnedCount = _allWords.where((w) => !w.isLearned && w.reviewCount == 0).length;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title ?? 'Danh sách từ vựng'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWordScreen()),
          );
          if (result == true) _loadWordsForParent();
        },
        backgroundColor: const Color(0xFF8B5CF6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng số: ${_allWords.length} từ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.swap_vert, size: 16, color: isDark ? Colors.white54 : Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Sắp xếp: A → Z',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Header with Gradient & Search Overlap
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 60, // Short gradient header
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
              ),
              // Overlapping Search Bar
              Positioned(
                left: 20,
                right: 20,
                bottom: -24,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm từ vựng...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _filterWords();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (val) => _filterWords(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Tất cả (${_allWords.length})',
                  shortLabel: 'Tất cả',
                  selected: _filterType == 'all',
                  onTap: () => _changeFilter('all'),
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Đã học ($learnedCount)',
                  shortLabel: 'Đã học',
                  selected: _filterType == 'learned',
                  onTap: () => _changeFilter('learned'),
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Đang học ($learningCount)',
                  shortLabel: 'Đang học',
                  selected: _filterType == 'learning',
                  onTap: () => _changeFilter('learning'),
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Chưa học ($unlearnedCount)',
                  shortLabel: 'Chưa học',
                  selected: _filterType == 'unlearned',
                  onTap: () => _changeFilter('unlearned'),
                  color: Colors.grey.shade600,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Words list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/lottie/empty_box.json',
                              width: 150,
                              height: 150,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy từ vựng',
                              style: TextStyle(fontSize: 16, color: context.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = _filteredWords[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: AnimatedListItem(
                              index: index,
                              child: PremiumWordCard(
                                word: word,
                                isDark: isDark,
                                isBookmarked: _difficultWordIds.contains(word.id),
                                onToggleBookmark: () => _toggleDifficult(word.id!),
                                onSpeak: () => _speak(word.word),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WordDetailScreen(
                                        words: _filteredWords,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                  _loadWordsForParent();
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String shortLabel,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? (color ?? context.primaryColor) : context.subtleBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            selected ? label : shortLabel,
            style: TextStyle(
              color: selected ? Colors.white : context.textPrimary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: selected ? 14 : 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}