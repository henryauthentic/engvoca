import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../models/topic.dart';
import '../services/ai_service.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';

class AiStoryScreen extends StatefulWidget {
  const AiStoryScreen({super.key});

  @override
  State<AiStoryScreen> createState() => _AiStoryScreenState();
}

class _AiStoryScreenState extends State<AiStoryScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _aiService = AiService();

  List<Topic> _topics = [];
  List<Word> _allLearnedWords = [];
  final Set<String> _selectedWordIds = {};
  bool _isLoadingWords = true;
  bool _isGenerating = false;
  String? _story;
  String? _errorMessage;
  bool _useRandom = true; // true = random, false = manual pick

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoadingWords = true);
    try {
      final topics = await _dbHelper.getTopics();
      final learnedWords = await _dbHelper.getLearnedWords();
      setState(() {
        _topics = topics;
        _allLearnedWords = learnedWords;
        _isLoadingWords = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWords = false;
        _errorMessage = 'Lỗi tải dữ liệu: $e';
      });
    }
  }

  List<Word> _getSelectedWords() {
    if (_useRandom) {
      final words = List<Word>.from(_allLearnedWords);
      words.shuffle(Random());
      return words.take(5).toList();
    } else {
      return _allLearnedWords
          .where((w) => _selectedWordIds.contains(w.id))
          .toList();
    }
  }

  Future<void> _generateStory() async {
    final words = _getSelectedWords();
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 từ vựng!')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _story = null;
      _errorMessage = null;
    });

    try {
      final wordStrings = words.map((w) => w.word).toList();
      final result = await _aiService.generateStory(wordStrings);
      if (mounted) {
        setState(() {
          _story = result;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi tạo truyện: $e';
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('✨ AI Story Builder'),
        backgroundColor: context.surfaceColor,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: _isLoadingWords
          ? Center(child: Lottie.asset('assets/lottie/ai_loading.json', height: 150))
          : _isGenerating
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset('assets/lottie/ai_loading.json', height: 200),
                      const SizedBox(height: 16),
                      Text('AI đang sáng tác...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                )
              : _story != null
                  ? _buildStoryView(isDark)
                  : _buildSetupView(isDark),
    );
  }

  // ============================================
  // SETUP VIEW: chọn từ vựng
  // ============================================
  Widget _buildSetupView(bool isDark) {
    return Column(
      children: [
        // Header card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                '📖 Sáng tác truyện từ từ vựng',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI sẽ viết một câu chuyện thú vị giúp bạn ghi nhớ từ vựng lâu hơn!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fade(duration: 400.ms).slideY(begin: -0.2, end: 0, duration: 400.ms),

        // Mode toggle
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildModeTab('🎲 Ngẫu nhiên 5 từ', true, isDark),
              const SizedBox(width: 4),
              _buildModeTab('✋ Tự chọn từ', false, isDark),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Word list (manual mode) or info (random mode)
        Expanded(
          child: _useRandom
              ? _buildRandomInfo(isDark)
              : _buildManualPicker(isDark),
        ),

        // Generate button
        _buildGenerateButton(isDark),
      ],
    );
  }

  Widget _buildModeTab(String label, bool isRandom, bool isDark) {
    final isSelected = _useRandom == isRandom;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _useRandom = isRandom;
          if (isRandom) _selectedWordIds.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF6C63FF) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRandomInfo(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF6C63FF)),
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1500.ms),
          const SizedBox(height: 24),
          Text(
            'AI sẽ chọn ngẫu nhiên 5 từ\ntừ ${_allLearnedWords.length} từ bạn đã học',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn "Tạo truyện" để bắt đầu!',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Chọn tối đa 5 từ (${_selectedWordIds.length}/5)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _allLearnedWords.length,
            itemBuilder: (context, index) {
              final word = _allLearnedWords[index];
              final isSelected = _selectedWordIds.contains(word.id);
              final canSelect = _selectedWordIds.length < 5 || isSelected;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF6C63FF), width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.text_fields,
                      color: isSelected ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    word.word,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    word.meaning,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: canSelect
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedWordIds.remove(word.id);
                            } else {
                              _selectedWordIds.add(word.id!);
                            }
                          });
                        }
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton(bool isDark) {
    final canGenerate = _useRandom
        ? _allLearnedWords.isNotEmpty
        : _selectedWordIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canGenerate && !_isGenerating ? _generateStory : null,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_stories, color: Colors.white),
            label: Text(
              _isGenerating ? 'AI đang sáng tác...' : '✨ Tạo truyện',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // STORY VIEW: đọc truyện
  // ============================================
  Widget _buildStoryView(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book icon header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_stories, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Câu chuyện của bạn',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Story content (Markdown)
                  MarkdownBody(
                    data: _story ?? '',
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: isDark ? Colors.grey.shade200 : Colors.black87,
                      ),
                      h2: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      h3: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6C63FF),
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6C63FF),
                        fontSize: 16,
                      ),
                      listBullet: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey.shade200 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 600.ms).slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
          ),
        ),
        // Bottom action buttons
        Container(
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
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _story = null;
                      _selectedWordIds.clear();
                    }),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Chọn lại từ'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      foregroundColor: const Color(0xFF6C63FF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateStory,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Viết lại',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
