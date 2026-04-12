import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import '../widgets/word_tile.dart';
import '../widgets/common/animated_list_item.dart';
import 'word_detail_screen.dart';
import 'add_word_screen.dart';

class VocabularyListScreen extends StatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  State<VocabularyListScreen> createState() => _VocabularyListScreenState();
}

class _VocabularyListScreenState extends State<VocabularyListScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  List<Word> _allWords = [];
  List<Word> _filteredWords = [];
  bool _isLoading = true;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadAllWords();
    _searchController.addListener(_filterWords);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllWords() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _dbHelper.getTopics();
      List<Word> allWords = [];
      
      for (var topic in topics) {
        final words = await _dbHelper.getWordsByTopic(topic.id!);
        allWords.addAll(words);
      }
      
      allWords.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      
      setState(() {
        _allWords = allWords;
        _filteredWords = allWords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải từ vựng: $e')),
        );
      }
    }
  }

  void _filterWords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWords = _allWords.where((word) {
        final matchesSearch = word.word.toLowerCase().contains(query) ||
            word.meaning.toLowerCase().contains(query);
        
        final matchesFilter = _filterType == 'all' ||
            (_filterType == 'learned' && word.isLearned) ||
            (_filterType == 'unlearned' && !word.isLearned);
        
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

  Future<void> _navigateToAddWord() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddWordScreen(),
      ),
    );

    if (result == true) {
      _loadAllWords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final learnedCount = _allWords.where((w) => w.isLearned).length;
    final unlearnedCount = _allWords.length - learnedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách từ vựng'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddWord,
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ'),
        backgroundColor: context.primaryColor,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            color: context.cardColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm từ vựng...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                filled: true,
                fillColor: context.subtleBackground,
              ),
            ),
          ),

          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingSmall,
            ),
            color: context.cardColor,
            child: Row(
              children: [
                Expanded(
                  flex: _filterType == 'all' ? 3 : 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: _buildFilterChip(
                      label: 'Tất cả (${_allWords.length})',
                      shortLabel: 'Tất cả',
                      selected: _filterType == 'all',
                      onTap: () => _changeFilter('all'),
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: _filterType == 'learned' ? 3 : 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: _buildFilterChip(
                      label: 'Đã học ($learnedCount)',
                      shortLabel: 'Đã học',
                      selected: _filterType == 'learned',
                      onTap: () => _changeFilter('learned'),
                      color: AppConstants.secondaryColor,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: _filterType == 'unlearned' ? 3 : 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: _buildFilterChip(
                      label: 'Chưa học ($unlearnedCount)',
                      shortLabel: 'Chưa học',
                      selected: _filterType == 'unlearned',
                      onTap: () => _changeFilter('unlearned'),
                      color: Colors.orange,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                              style: TextStyle(
                                fontSize: 16,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _navigateToAddWord,
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm từ vựng mới'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = _filteredWords[index];
                          return AnimatedListItem(
                            index: index,
                            child: WordTile(
                              word: word,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => WordDetailScreen(word: word),
                                  ),
                                );
                                _loadAllWords();
                              },
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
          color: selected
              ? (color ?? context.primaryColor)
              : context.subtleBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            selected ? label : shortLabel,
            style: TextStyle(
              color: selected 
                  ? Colors.white 
                  : context.textPrimary,
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