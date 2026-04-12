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
  List<Topic> _topics = [];
  Map<String, int> _learnedCounts = {};
  final Set<String> _selectedTopicIds = {};
  bool _selectAll = false;
  int _wordCount = 20;
  String _mode = 'quiz'; // 'quiz', 'fill_blank', 'mixed'
  bool _isLoading = true;
  final List<int> _wordCountOptions = [10, 20, 30, 50, 75];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    final topics = await _dbHelper.getTopics();
    Map<String, int> learnedCounts = {};

    for (var topic in topics) {
      final count = await _dbHelper.getLearnedWordsCountByTopic(topic.id!);
      learnedCounts[topic.id!] = count;
    }

    setState(() {
      _topics = topics;
      _learnedCounts = learnedCounts;
      _isLoading = false;
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

    final topicNames = _topics
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
        _selectedTopicIds.addAll(_topics
            .where((t) => (_learnedCounts[t.id] ?? 0) > 0)
            .map((t) => t.id!));
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
      itemCount: _topics.length,
      itemBuilder: (context, index) {
        final topic = _topics[index];
        final isSelected = _selectedTopicIds.contains(topic.id);
        final learnedCount = _learnedCounts[topic.id] ?? 0;
        final hasLearnedWords = learnedCount > 0;

        return Opacity(
          opacity: hasLearnedWords ? 1.0 : 0.5,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isSelected ? Border.all(color: const Color(0xFF6C63FF), width: 2) : null,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6C63FF).withOpacity(0.15)
                      : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.folder_outlined,
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
                ),
              ),
              title: Text(
                topic.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                '$learnedCount từ đã học / ${topic.totalWords} tổng',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              trailing: Checkbox(
                value: isSelected,
                onChanged: hasLearnedWords
                    ? (v) {
                        setState(() {
                          if (v == true) {
                            _selectedTopicIds.add(topic.id!);
                          } else {
                            _selectedTopicIds.remove(topic.id);
                          }
                        });
                      }
                    : null,
                activeColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onTap: hasLearnedWords
                  ? () {
                      setState(() {
                        if (isSelected) {
                          _selectedTopicIds.remove(topic.id);
                        } else {
                          _selectedTopicIds.add(topic.id!);
                        }
                      });
                    }
                  : null,
            ),
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
