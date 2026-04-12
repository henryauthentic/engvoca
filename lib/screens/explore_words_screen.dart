import 'dart:math';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import 'flashcard_screen.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/animated_list_item.dart';
import '../widgets/common/primary_button.dart';

class ExploreWordsScreen extends StatefulWidget {
  const ExploreWordsScreen({super.key});

  @override
  State<ExploreWordsScreen> createState() => _ExploreWordsScreenState();
}

class _ExploreWordsScreenState extends State<ExploreWordsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Topic> _topics = [];
  final Set<String> _selectedTopicIds = {};
  int _wordCount = 20;
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
    setState(() {
      _topics = topics;
      _isLoading = false;
    });
  }

  Future<void> _startExploring() async {
    if (_selectedTopicIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 chủ đề!')),
      );
      return;
    }

    // Lấy từ chưa học từ các topics đã chọn
    final newWords = await _dbHelper.getNewWordsByTopics(_selectedTopicIds.toList());

    if (newWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không còn từ mới trong các chủ đề đã chọn!')),
        );
      }
      return;
    }

    // Random & giới hạn số lượng
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
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('🔍 Khám phá từ mới'),
        backgroundColor: context.surfaceColor,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selected topics chips
                if (_selectedTopicIds.isNotEmpty) _buildSelectedChips(isDark),
                // Word count selector
                _buildWordCountSelector(isDark),
                // Topics list
                Expanded(child: _buildTopicsList(isDark)),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildSelectedChips(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _selectedTopicIds.map((id) {
          final topic = _topics.firstWhere((t) => t.id == id);
          return Chip(
            label: Text(topic.name, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => setState(() => _selectedTopicIds.remove(id)),
            backgroundColor: isDark ? const Color(0xFF6C63FF).withOpacity(0.2) : const Color(0xFF6C63FF).withOpacity(0.1),
            labelStyle: TextStyle(color: isDark ? Colors.white : const Color(0xFF6C63FF)),
            deleteIconColor: isDark ? Colors.white70 : const Color(0xFF6C63FF),
            side: BorderSide.none,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWordCountSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số lượng từ: $_wordCount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
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
                          ? const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)])
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

  Widget _buildTopicsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _topics.length,
      itemBuilder: (context, index) {
        final topic = _topics[index];
        final isSelected = _selectedTopicIds.contains(topic.id);

        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: EdgeInsets.zero,
              color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
              hasShadow: !isSelected,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4ADE80).withOpacity(0.15)
                    : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.folder_outlined,
                color: isSelected ? const Color(0xFF4ADE80) : Colors.grey,
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
              '${topic.totalWords} từ',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedTopicIds.add(topic.id!);
                  } else {
                    _selectedTopicIds.remove(topic.id);
                  }
                });
              },
              activeColor: const Color(0xFF4ADE80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedTopicIds.remove(topic.id);
                } else {
                  _selectedTopicIds.add(topic.id!);
                }
              });
            },
          ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
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
                    '${_selectedTopicIds.length} chủ đề đã chọn',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Sẽ random $_wordCount từ mới',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            PrimaryButton(
              onPressed: _selectedTopicIds.isEmpty ? null : _startExploring,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              text: 'Bắt đầu',
              backgroundColor: const Color(0xFF4ADE80),
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
