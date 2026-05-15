import 'dart:math';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import 'practice_screen.dart';

class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Topic> _parentTopics = [];
  Map<String, List<Topic>> _childrenMap = {};
  Map<String, int> _learnedCounts = {}; // key = topic id (con hoặc cha)
  final Set<String> _expandedParentIds = {};
  final Set<String> _selectedTopicIds = {};
  bool _selectAll = false;
  int _wordCount = 20;
  String _mode = 'quiz';
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
    Map<String, int> learnedCounts = {};

    for (var p in parents) {
      final children = await _dbHelper.getChildTopics(p.id!);
      childrenMap[p.id!] = children;

      if (children.isEmpty) {
        // Topic cha không có con → đếm trực tiếp
        final count = await _dbHelper.getLearnedWordsCountByTopic(p.id!);
        learnedCounts[p.id!] = count;
      } else {
        // Có con → đếm từng con và tổng cho cha
        int parentTotal = 0;
        for (var c in children) {
          final count = await _dbHelper.getLearnedWordsCountByTopic(c.id!);
          learnedCounts[c.id!] = count;
          parentTotal += count;
        }
        learnedCounts[p.id!] = parentTotal;
      }
    }

    setState(() {
      _parentTopics = parents;
      _childrenMap = childrenMap;
      _learnedCounts = learnedCounts;
      _isLoading = false;
    });
  }

  bool _isParentFullySelected(String parentId) {
    final children = _childrenMap[parentId] ?? [];
    if (children.isEmpty) return _selectedTopicIds.contains(parentId);
    final selectableChildren = children.where((c) => (_learnedCounts[c.id] ?? 0) > 0);
    if (selectableChildren.isEmpty) return false;
    return selectableChildren.every((c) => _selectedTopicIds.contains(c.id));
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
        if ((_learnedCounts[parent.id] ?? 0) == 0) return;
        if (_selectedTopicIds.contains(parent.id)) {
          _selectedTopicIds.remove(parent.id);
        } else {
          _selectedTopicIds.add(parent.id!);
        }
      } else {
        if (_isParentFullySelected(parent.id!)) {
          for (var c in children) {
            _selectedTopicIds.remove(c.id);
          }
        } else {
          for (var c in children) {
            if ((_learnedCounts[c.id] ?? 0) > 0) {
              _selectedTopicIds.add(c.id!);
            }
          }
        }
      }
    });
  }

  void _toggleChildSelection(Topic child) {
    if ((_learnedCounts[child.id] ?? 0) == 0) return;
    setState(() {
      if (_selectedTopicIds.contains(child.id)) {
        _selectedTopicIds.remove(child.id);
      } else {
        _selectedTopicIds.add(child.id!);
      }
    });
  }

  int get _totalLearnedSelected {
    int total = 0;
    for (var id in _selectedTopicIds) {
      total += _learnedCounts[id] ?? 0;
    }
    return total;
  }

  Future<void> _startPractice() async {
    if (_selectedTopicIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 chủ đề!')),
      );
      return;
    }

    final learnedWords = await _dbHelper.getLearnedWordsByTopics(_selectedTopicIds.toList());

    if (learnedWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ đã học trong các chủ đề này!')),
        );
      }
      return;
    }

    if (learnedWords.length < _wordCount) {
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Không đủ từ'),
            content: Text(
              'Bạn chọn $_wordCount câu nhưng chỉ có ${learnedWords.length} từ đã học.\nBạn muốn luyện tập với ${learnedWords.length} từ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đồng ý'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    learnedWords.shuffle(Random());
    final selectedWords = learnedWords.take(_wordCount).toList();

    // Tìm tên topic tương ứng
    final allTopics = <Topic>[];
    for (var p in _parentTopics) {
      allTopics.add(p);
      allTopics.addAll(_childrenMap[p.id!] ?? []);
    }
    final topicNames = allTopics
        .where((t) => _selectedTopicIds.contains(t.id))
        .map((t) => t.name)
        .toList();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeScreen(
            words: selectedWords,
            mode: _mode,
            topicIds: _selectedTopicIds.toList(),
            topicNames: topicNames,
          ),
        ),
      ).then((_) => _loadTopics());
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        for (var p in _parentTopics) {
          final children = _childrenMap[p.id!] ?? [];
          if (children.isEmpty) {
            if ((_learnedCounts[p.id] ?? 0) > 0) {
              _selectedTopicIds.add(p.id!);
            }
          } else {
            for (var c in children) {
              if ((_learnedCounts[c.id] ?? 0) > 0) {
                _selectedTopicIds.add(c.id!);
              }
            }
          }
        }
      } else {
        _selectedTopicIds.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('💪 Luyện tập tự do'),
        backgroundColor: context.surfaceColor,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildModeSelector(isDark),
                _buildWordCountSelector(isDark),
                _buildSelectAllButton(isDark),
                Expanded(child: _buildTopicsList(isDark)),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chế độ luyện tập',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildModeChip('📝', 'Trắc nghiệm', 'quiz', const Color(0xFF3B82F6), isDark),
              const SizedBox(width: 6),
              _buildModeChip('✏️', 'Điền từ', 'fill_blank', const Color(0xFF8B5CF6), isDark),
              const SizedBox(width: 6),
              _buildModeChip('🔀', 'Kết hợp', 'mixed', const Color(0xFF14B8A6), isDark),
              const SizedBox(width: 6),
              _buildModeChip('🎧', 'Nghe', 'listening', const Color(0xFFEC4899), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String emoji, String label, String mode, Color color, bool isDark) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(colors: [color, color.withOpacity(0.8)]) : null,
            color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordCountSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số lượng câu: $_wordCount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _wordCountOptions.map((count) {
              final isSelected = _wordCount == count;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _wordCount = count),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)])
                          : null,
                      color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            'Chọn chủ đề (chỉ từ đã học)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _toggleSelectAll,
            icon: Icon(
              _selectAll ? Icons.deselect : Icons.select_all,
              size: 18,
            ),
            label: Text(_selectAll ? 'Bỏ chọn' : 'Tất cả'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _parentTopics.length,
      itemBuilder: (context, index) {
        final parent = _parentTopics[index];
        final children = _childrenMap[parent.id!] ?? [];
        final hasChildren = children.isNotEmpty;
        final isExpanded = _expandedParentIds.contains(parent.id);
        final isFullySelected = _isParentFullySelected(parent.id!);
        final parentLearnedCount = _learnedCounts[parent.id] ?? 0;
        final hasLearnedWords = parentLearnedCount > 0;

        return Opacity(
          opacity: hasLearnedWords ? 1.0 : 0.5,
          child: Column(
            children: [
              // ── Parent topic row ──
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: isFullySelected ? Border.all(color: const Color(0xFF6C63FF), width: 2) : null,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFullySelected
                          ? const Color(0xFF6C63FF).withOpacity(0.15)
                          : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isFullySelected ? Icons.check_circle : Icons.folder_outlined,
                      color: isFullySelected ? const Color(0xFF6C63FF) : Colors.grey,
                    ),
                  ),
                  title: Text(
                    parent.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    hasChildren
                        ? '$parentLearnedCount từ đã học / ${parent.totalWords} tổng'
                        : '$parentLearnedCount từ đã học / ${parent.totalWords} tổng',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: isFullySelected,
                        tristate: true,
                        onChanged: hasLearnedWords ? (_) => _toggleParentSelection(parent) : null,
                        activeColor: const Color(0xFF6C63FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      if (hasChildren)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedParentIds.remove(parent.id);
                              } else {
                                _expandedParentIds.add(parent.id!);
                              }
                            });
                          },
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.expand_more,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    if (hasChildren) {
                      setState(() {
                        if (isExpanded) {
                          _expandedParentIds.remove(parent.id);
                        } else {
                          _expandedParentIds.add(parent.id!);
                        }
                      });
                    } else if (hasLearnedWords) {
                      _toggleParentSelection(parent);
                    }
                  },
                ),
              ),

              // ── Child topics (expandable) ──
              if (hasChildren)
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 8),
                    child: Column(
                      children: children.map((child) {
                        final isChildSelected = _selectedTopicIds.contains(child.id);
                        final childLearned = _learnedCounts[child.id] ?? 0;
                        final childHasLearned = childLearned > 0;

                        return Opacity(
                          opacity: childHasLearned ? 1.0 : 0.5,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? (isChildSelected ? const Color(0xFF1A2A3A) : const Color(0xFF232338))
                                    : (isChildSelected ? const Color(0xFFEDE7F6) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(12),
                                border: isChildSelected
                                    ? Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5), width: 1)
                                    : null,
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                leading: Icon(
                                  isChildSelected ? Icons.check_circle : Icons.circle_outlined,
                                  size: 20,
                                  color: isChildSelected ? const Color(0xFF6C63FF) : Colors.grey.shade400,
                                ),
                                title: Text(
                                  child.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  '$childLearned từ đã học / ${child.totalWords} tổng',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                trailing: Checkbox(
                                  value: isChildSelected,
                                  onChanged: childHasLearned ? (_) => _toggleChildSelection(child) : null,
                                  activeColor: const Color(0xFF6C63FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                onTap: childHasLearned ? () => _toggleChildSelection(child) : null,
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
        );
      },
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedTopicIds.length} chủ đề • $_totalLearnedSelected từ đã học',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Chế độ: ${_mode == 'quiz' ? 'Trắc nghiệm' : (_mode == 'fill_blank' ? 'Điền từ' : (_mode == 'listening' ? 'Luyện nghe' : 'Kết hợp'))}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _selectedTopicIds.isEmpty ? null : _startPractice,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('Bắt đầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
