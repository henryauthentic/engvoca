import 'dart:math';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import '../theme/theme_extensions.dart';
import 'flashcard_screen.dart';
import '../widgets/common/animated_list_item.dart';
import '../utils/topic_icons.dart';

class ExploreWordsScreen extends StatefulWidget {
  const ExploreWordsScreen({super.key});

  @override
  State<ExploreWordsScreen> createState() => _ExploreWordsScreenState();
}

class _ExploreWordsScreenState extends State<ExploreWordsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Topic> _parentTopics = [];
  Map<String, List<Topic>> _childrenMap = {};
  final Set<String> _expandedParentIds = {};
  final Set<String> _selectedTopicIds = {};
  int _wordCount = 10;
  bool _isLoading = true;
  final List<int> _wordCountOptions = [10, 20, 30, 50, 75];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
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
  }

  bool _isParentFullySelected(String parentId) {
    final children = _childrenMap[parentId] ?? [];
    if (children.isEmpty) return _selectedTopicIds.contains(parentId);
    return children.every((c) => _selectedTopicIds.contains(c.id));
  }

  bool _isParentPartiallySelected(String parentId) {
    final children = _childrenMap[parentId] ?? [];
    if (children.isEmpty) return false;
    final selectedCount = children.where((c) => _selectedTopicIds.contains(c.id)).length;
    return selectedCount > 0 && selectedCount < children.length;
  }

  void _toggleParentSelection(Topic parent) {
    final children = _childrenMap[parent.id!] ?? [];
    setState(() {
      if (children.isEmpty) {
        if (_selectedTopicIds.contains(parent.id)) {
          _selectedTopicIds.remove(parent.id);
        } else {
          _selectedTopicIds.add(parent.id!);
        }
      } else {
        // If fully selected OR partially selected, clicking the parent should DESELECT ALL
        if (_isParentFullySelected(parent.id!) || _isParentPartiallySelected(parent.id!)) {
          for (var c in children) {
            _selectedTopicIds.remove(c.id);
          }
        } else {
          // If empty, clicking should select all, BUT to avoid bad UX, maybe we just expand it if it's not expanded?
          // No, user clicked the checkbox specifically. So select all.
          for (var c in children) {
            _selectedTopicIds.add(c.id!);
          }
          // Also auto-expand so they see what got selected
          _expandedParentIds.add(parent.id!);
        }
      }
    });
  }

  void _toggleChildSelection(Topic child) {
    setState(() {
      if (_selectedTopicIds.contains(child.id)) {
        _selectedTopicIds.remove(child.id);
      } else {
        _selectedTopicIds.add(child.id!);
      }
    });
  }

  Future<void> _startExploring() async {
    if (_selectedTopicIds.isEmpty) return;

    final newWords = await _dbHelper.getNewWordsByTopics(_selectedTopicIds.toList());

    if (newWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không còn từ mới trong các chủ đề đã chọn!')),
        );
      }
      return;
    }

    newWords.shuffle(Random());
    final selectedWords = newWords.take(_wordCount).toList();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardScreen(
            topic: Topic(
              id: 'explore_${DateTime.now().millisecondsSinceEpoch}',
              name: 'Khám phá từ mới',
              description: 'Khám phá từ mới từ nhiều chủ đề',
              totalWords: selectedWords.length,
            ),
            preloadedWords: selectedWords,
            isNewWordsMode: true,
          ),
        ),
      ).then((_) => _loadTopics());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Soft background gradient at the top (like mockup 1)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 300,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isDark ? const Color(0xFF8B5CF6).withOpacity(0.3) : const Color(0xFF8B5CF6).withOpacity(0.15),
                          isDark ? context.backgroundColor : const Color(0xFFF8F9FA),
                        ],
                      ),
                    ),
                  ),
                ),
                // Decorative sparkles/circles
                Positioned(
                  top: 60,
                  right: 20,
                  child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.5), size: 32),
                ),
                Positioned(
                  top: 100,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 20),
                    ),
                  ),
                ),

                CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '🔍 Khám phá từ mới',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 40),
                                child: Text(
                                  'Chọn chủ đề và số lượng từ phù hợp để bắt đầu học',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Word Count Selector
                    SliverToBoxAdapter(
                      child: _buildWordCountSelector(isDark),
                    ),
                    // "Chọn chủ đề" header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chọn chủ đề',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedTopicIds.length} chủ đề',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Topic List
                    _buildTopicsList(isDark),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom bar
                  ],
                ),
                
                // Sticky Bottom Bar
                if (_selectedTopicIds.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomBar(isDark),
                  ),
              ],
            ),
    );
  }

  Widget _buildWordCountSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số lượng từ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Bạn muốn học bao nhiêu từ?',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _wordCountOptions.map((count) {
              final isSelected = _wordCount == count;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _wordCount = count),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)])
                          : null,
                      color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FA)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                          color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: const Color(0xFF8B5CF6).withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                'Số lượng từ ít hơn giúp bạn học hiệu quả hơn mỗi ngày',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsList(bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final parent = _parentTopics[index];
          final children = _childrenMap[parent.id!] ?? [];
          final hasChildren = children.isNotEmpty;
          final isExpanded = _expandedParentIds.contains(parent.id);
          final isFullySelected = _isParentFullySelected(parent.id!);
          final isPartial = _isParentPartiallySelected(parent.id!);

          return AnimatedListItem(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                children: [
                  // ── Parent topic row ──
                  GestureDetector(
                    onTap: () {
                      if (hasChildren) {
                        setState(() {
                          if (isExpanded) {
                            _expandedParentIds.remove(parent.id);
                          } else {
                            _expandedParentIds.add(parent.id!);
                          }
                        });
                      } else {
                        _toggleParentSelection(parent);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFullySelected || isPartial
                            ? const Color(0xFF8B5CF6).withOpacity(0.04)
                            : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFullySelected || isPartial
                              ? const Color(0xFF8B5CF6).withOpacity(0.3)
                              : (isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        boxShadow: isFullySelected || isPartial || isDark ? [] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: isFullySelected || isPartial
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                    )
                                  : null,
                              color: isFullySelected || isPartial ? null : (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FA)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              TopicIcons.get(parent.name),
                              color: isFullySelected || isPartial ? Colors.white : _getParentColor(index),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parent.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasChildren ? '${children.length} chủ đề · ${parent.totalWords} từ' : '${parent.totalWords} từ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Actions (Check + Expand)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _toggleParentSelection(parent),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isFullySelected 
                                        ? const Color(0xFF8B5CF6) 
                                        : (isPartial ? const Color(0xFF8B5CF6).withOpacity(0.5) : Colors.transparent),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isFullySelected || isPartial ? Colors.transparent : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: isFullySelected
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : (isPartial ? const Icon(Icons.remove, size: 16, color: Colors.white) : null),
                                ),
                              ),
                              if (hasChildren) ...[
                                const SizedBox(width: 12),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.expand_more,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Child topics (expandable) ──
                  if (hasChildren)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
                        child: Column(
                          children: children.map((child) {
                            final isChildSelected = _selectedTopicIds.contains(child.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GestureDetector(
                                onTap: () => _toggleChildSelection(child),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isChildSelected
                                        ? const Color(0xFF8B5CF6).withOpacity(0.08)
                                        : (isDark ? const Color(0xFF2A2A3E).withOpacity(0.5) : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isChildSelected
                                          ? const Color(0xFF8B5CF6).withOpacity(0.4)
                                          : (isDark ? Colors.transparent : Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: isChildSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isChildSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                                            width: 2,
                                          ),
                                        ),
                                        child: isChildSelected
                                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          child.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isChildSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${child.totalWords} từ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),
                ],
              ),
            ),
          );
        },
        childCount: _parentTopics.length,
      ),
    );
  }

  Color _getParentColor(int index) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF4ADE80), // Green
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFFF87171), // Red
      const Color(0xFF60A5FA), // Blue
      const Color(0xFFA78BFA), // Light Purple
      const Color(0xFFF472B6), // Pink
      const Color(0xFF2DD4BF), // Teal
    ];
    return colors[index % colors.length];
  }

  Widget _buildBottomBar(bool isDark) {
    // Count selected words based on child topics
    int selectedWordsCount = 0;
    for (var p in _parentTopics) {
      final children = _childrenMap[p.id!] ?? [];
      if (children.isEmpty && _selectedTopicIds.contains(p.id)) {
        selectedWordsCount += p.totalWords;
      } else {
        for (var c in children) {
          if (_selectedTopicIds.contains(c.id)) {
            selectedWordsCount += c.totalWords;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.layers, color: Color(0xFF8B5CF6), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedTopicIds.length} chủ đề đã chọn',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$selectedWordsCount từ sẽ được học',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _startExploring,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Bắt đầu học',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
