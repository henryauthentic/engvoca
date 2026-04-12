import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../models/word.dart';
import '../db/database_helper.dart';
import '../utils/constants.dart';
import '../widgets/word_tile.dart';
import 'word_detail_screen.dart';
import 'flashcard_screen.dart';

class WordsScreen extends StatefulWidget {
  final Topic topic;

  const WordsScreen({super.key, required this.topic});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Word> _words = [];
  List<Word> _filteredWords = [];
  bool _isLoading = true;
  bool _showLearnedOnly = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWords();
    _searchController.addListener(_filterWords);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      print('🔍 Loading words for topic: ${widget.topic.id} (${widget.topic.name})');
      
      // Debug: Check what topic IDs exist in words table
      final allTopicIds = await _dbHelper.getTopicIdsFromWords();
      print('📋 Available topic IDs in words table: $allTopicIds');
      
      // Load words for this topic
      final words = await _dbHelper.getWordsByTopic(widget.topic.id!);
      print('✅ Found ${words.length} words for topic ${widget.topic.id}');
      
      if (words.isEmpty) {
        // Try to find similar topic IDs
        print('⚠️  No words found. Checking for similar IDs...');
        for (var tid in allTopicIds) {
          if (tid.toLowerCase().contains(widget.topic.id!.toLowerCase()) ||
              widget.topic.id!.toLowerCase().contains(tid.toLowerCase())) {
            print('   Similar ID found: $tid');
          }
        }
      }
      
      setState(() {
        _words = words;
        _filteredWords = words;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading words: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải từ vựng: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _filterWords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWords = _words.where((word) {
        final matchesSearch = word.word.toLowerCase().contains(query) ||
            word.meaning.toLowerCase().contains(query);
        final matchesFilter = !_showLearnedOnly || word.isLearned;
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _toggleFilter() {
    setState(() {
      _showLearnedOnly = !_showLearnedOnly;
      _filterWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.name),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.style),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FlashcardScreen(topic: widget.topic),
                ),
              );
            },
            tooltip: 'Học bằng Flashcard',
          ),
          IconButton(
            icon: Icon(
              _showLearnedOnly ? Icons.check_circle : Icons.filter_list,
            ),
            onPressed: _toggleFilter,
            tooltip: _showLearnedOnly ? 'Hiển thị tất cả' : 'Chỉ từ đã học',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm từ vựng...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    filled: true,
                    fillColor: AppConstants.backgroundColor,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tổng số',
                        '${_words.length}',
                        Icons.book,
                        AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: _buildStatCard(
                        'Đã học',
                        '${_words.where((w) => w.isLearned).length}',
                        Icons.check_circle,
                        AppConstants.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: AppConstants.paddingMedium),
                            Text(
                              'Không tìm thấy từ vựng',
                              style: AppConstants.subtitleStyle,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = _filteredWords[index];
                          return WordTile(
                            word: word,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => WordDetailScreen(word: word),
                                ),
                              );
                              _loadWords();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}