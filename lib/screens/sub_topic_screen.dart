import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../db/database_helper.dart';
import '../theme/theme_extensions.dart';
import '../utils/constants.dart';
import '../widgets/child_topic_card.dart';
import '../utils/topic_icons.dart';
import '../widgets/common/skeleton_loader.dart';
import 'topic_word_list_screen.dart';
import 'vocabulary_list_screen.dart';

/// Màn hình hiển thị khi user tap vào 1 topic cha.
/// - Nếu topic cha có topic con  → hiển thị danh sách topic con
/// - Nếu không có topic con      → chuyển thẳng vào LearningModeScreen
class SubTopicScreen extends StatefulWidget {
  final Topic parentTopic;

  const SubTopicScreen({super.key, required this.parentTopic});

  @override
  State<SubTopicScreen> createState() => _SubTopicScreenState();
}

class _SubTopicScreenState extends State<SubTopicScreen> {
  final _db = DatabaseHelper.instance;
  List<Topic> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await _db.updateTopicCounts();
      final children = await _db.getChildTopics(widget.parentTopic.id!);
      if (mounted) setState(() { _children = children; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parentTopic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF5B21B6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 48, bottom: 40, right: 16),
              title: Text(
                parent.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Mờ nhạt phía sau
                      Positioned(
                        right: -30,
                        top: -10,
                        child: Opacity(
                          opacity: 0.15,
                          child: Icon(TopicIcons.get(parent.name), size: 160, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(TopicIcons.get(parent.name), size: 24, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                _ProgressPill(learned: parent.learnedWords, total: parent.totalWords),
                              ],
                            ),
                            const Spacer(),
                            // Subtitle nằm dưới cùng
                            Text(
                              '${_children.length} chủ đề · ${parent.totalWords} từ vựng',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Loading skeleton ─────────────────────────────────────
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonCard(height: 110),
                  ),
                  childCount: 5,
                ),
              ),
            ),

          // ── Empty state ──────────────────────────────────────────
          if (!_isLoading && _children.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có chủ đề con nào',
                      style: TextStyle(
                        fontSize: 16,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Subtitle ─────────────────────────────────────────────
          if (!_isLoading && _children.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Các chủ đề con',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),

          // ── Child topic list ─────────────────────────────────────
          if (!_isLoading && _children.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final child = _children[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChildTopicCard(
                        topic: child,
                        isDark: isDark,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicWordListScreen(
                                topic: child,
                                parentTopic: widget.parentTopic,
                              ),
                            ),
                          );
                          _load(); // refresh progress sau khi học xong
                        },
                      ),
                    );
                  },
                  childCount: _children.length,
                ),
              ),
            ),
        ],
      ),

      // ── FAB: xem tất cả từ vựng của cấp này ────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (!_isLoading && _children.isNotEmpty)
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 56,
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VocabularyListScreen(
                        filterParentId: widget.parentTopic.id,
                        title: 'Từ vựng ${widget.parentTopic.name}',
                      ),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF8B5CF6), // Premium purple
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
                label: const Text(
                  'Xem tất cả từ trong chủ đề',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )
          : null,
    );
  }

}

// ── Pill hiển thị tiến độ ────────────────────────────────────────────────────
class _ProgressPill extends StatelessWidget {
  final int learned;
  final int total;

  const _ProgressPill({required this.learned, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (learned / total * 100).toInt() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$learned / $total từ  ($pct%)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}