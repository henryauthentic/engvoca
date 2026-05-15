import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';
import '../utils/constants.dart';
import '../theme/theme_extensions.dart';
import 'flashcard_screen.dart';
import '../models/topic.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/animated_list_item.dart';

class DailyReviewScreen extends StatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  State<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends State<DailyReviewScreen> {
  final _dbHelper = DatabaseHelper.instance;
  int _selectedDayIndex = 0; // 0 = hôm nay
  List<DateTime> _days = [];
  Map<String, List<_ReviewWordItem>> _wordsByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateDays();
    _loadAllDueWords();
  }

  void _generateDays() {
    final today = DateTime.now();
    _days = List.generate(14, (i) {
      return DateTime(today.year, today.month, today.day - i);
    });
  }

  Future<void> _loadAllDueWords() async {
    setState(() => _isLoading = true);
    try {
      final allProgress = await _dbHelper.getAllWordProgress();
      final db = await _dbHelper.database;

      // --- Batch load tất cả words liên quan (1 query thay vì N query) ---
      final wordIds = allProgress.map((p) => p.wordId).toSet().toList();
      final wordMap = await _batchLoadWords(db, wordIds);

      Map<String, List<_ReviewWordItem>> grouped = {};
      for (var day in _days) {
        grouped[DateFormat('yyyy-MM-dd').format(day)] = [];
      }

      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final addedWordIds = <String, Set<String>>{}; // dateKey -> Set<wordId>
      for (var key in grouped.keys) {
        addedWordIds[key] = {};
      }

      // ═══ TẦNG 1: Từ ĐÃ ÔN vào đúng ngày đó (dựa trên lastReviewDate) ═══
      for (var progress in allProgress) {
        if (progress.lastReviewDate == null) continue;
        
        // Bỏ qua các từ mới học (lastReviewDate trùng firstLearnedDate)
        if (progress.firstLearnedDate != null) {
          final learnedDay = DateFormat('yyyy-MM-dd').format(progress.firstLearnedDate!);
          final reviewedDay = DateFormat('yyyy-MM-dd').format(progress.lastReviewDate!);
          if (learnedDay == reviewedDay) continue; // Đây là từ mới, không tính là đã ôn
        }

        final reviewedOnKey = DateFormat('yyyy-MM-dd').format(progress.lastReviewDate!);
        
        if (grouped.containsKey(reviewedOnKey)) {
          final word = wordMap[progress.wordId];
          if (word != null && !addedWordIds[reviewedOnKey]!.contains(progress.wordId)) {
            grouped[reviewedOnKey]!.add(_ReviewWordItem(
              word: word,
              progress: progress,
              isReviewed: true,
            ));
            addedWordIds[reviewedOnKey]!.add(progress.wordId);
          }
        }
      }

      // ═══ TẦNG 2: Từ ĐẾN HẠN vào ngày đó nhưng CHƯA ôn (dựa trên nextReviewDate) ═══
      for (var progress in allProgress) {
        if (progress.nextReviewDate == null || progress.status == 0) continue;
        final dueOnKey = DateFormat('yyyy-MM-dd').format(progress.nextReviewDate!);
        
        if (grouped.containsKey(dueOnKey)) {
          // Chỉ thêm nếu chưa được thêm bởi Tầng 1
          if (!addedWordIds[dueOnKey]!.contains(progress.wordId)) {
            final word = wordMap[progress.wordId];
            if (word != null) {
              grouped[dueOnKey]!.add(_ReviewWordItem(
                word: word,
                progress: progress,
                isReviewed: false,
              ));
              addedWordIds[dueOnKey]!.add(progress.wordId);
            }
          }
        }
      }

      // ═══ TẦNG 3: Từ QUÁ HẠN gom vào Hôm nay (chỉ cho tab Today) ═══
      final now = DateTime.now();
      for (var progress in allProgress) {
        if (progress.nextReviewDate == null || progress.status == 0) continue;
        final nextReview = progress.nextReviewDate!;
        final dueOnKey = DateFormat('yyyy-MM-dd').format(nextReview);

        // Nếu nextReviewDate nằm trước hôm nay VÀ chưa ôn hôm nay
        if (nextReview.isBefore(now) && dueOnKey != todayKey) {
          if (!addedWordIds[todayKey]!.contains(progress.wordId)) {
            final word = wordMap[progress.wordId];
            if (word != null) {
              grouped[todayKey]!.add(_ReviewWordItem(
                word: word,
                progress: progress,
                isReviewed: false,
                isOverdue: true,
              ));
              addedWordIds[todayKey]!.add(progress.wordId);
            }
          }
        }
      }

      // Sắp xếp: từ chưa ôn lên trước, đã ôn xuống sau
      for (var key in grouped.keys) {
        grouped[key]!.sort((a, b) {
          if (a.isReviewed != b.isReviewed) return a.isReviewed ? 1 : -1;
          if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
          return 0;
        });
      }

      setState(() {
        _wordsByDate = grouped;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading due words: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Batch load words by IDs (chia batch 500 để tránh SQLite limit)
  Future<Map<String, Word>> _batchLoadWords(dynamic db, List<String> wordIds) async {
    final Map<String, Word> result = {};
    const batchSize = 500;
    
    for (int i = 0; i < wordIds.length; i += batchSize) {
      final batch = wordIds.sublist(i, (i + batchSize).clamp(0, wordIds.length));
      final placeholders = List.filled(batch.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT * FROM words WHERE id IN ($placeholders)',
        batch,
      );
      for (var row in rows) {
        final word = Word.fromMap(row);
        result[word.id.toString()] = word;
      }
    }
    return result;
  }

  String _getDateKey(int index) {
    return DateFormat('yyyy-MM-dd').format(_days[index]);
  }

  List<_ReviewWordItem> get _currentWords {
    return _wordsByDate[_getDateKey(_selectedDayIndex)] ?? [];
  }



  bool _isDayComplete(String dateKey) {
    final words = _wordsByDate[dateKey] ?? [];
    return words.isNotEmpty && words.every((w) => w.isReviewed);
  }

  void _startReview() {
    final unreviewedWords =
        _currentWords.where((w) => !w.isReviewed).map((w) => w.word).toList();
    if (unreviewedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả từ đã được ôn tập!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashcardScreen(
          topic: Topic(
            id: 'review_${_getDateKey(_selectedDayIndex)}',
            name: 'Ôn tập ${DateFormat('dd/MM').format(_days[_selectedDayIndex])}',
            description: 'Ôn tập hàng ngày',
            totalWords: unreviewedWords.length,
          ),
          preloadedWords: unreviewedWords,
        ),
      ),
    ).then((_) => _loadAllDueWords());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('📅 Ôn tập hàng ngày'),
        backgroundColor: context.surfaceColor,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar ngang
                _buildCalendarStrip(isDark),
                // Thông tin ngày đã chọn
                _buildDayInfo(isDark),
                // Danh sách từ
                Expanded(child: _buildWordList(isDark)),
              ],
            ),
      floatingActionButton: _currentWords.any((w) => !w.isReviewed)
          ? FloatingActionButton.extended(
              onPressed: _startReview,
              backgroundColor: const Color(0xFF6C63FF),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: Text(
                'Bắt đầu ôn (${_currentWords.where((w) => !w.isReviewed).length} từ)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildCalendarStrip(bool isDark) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final isSelected = index == _selectedDayIndex;
          final wordCount = (_wordsByDate[dateKey] ?? []).length;
          final isComplete = _isDayComplete(dateKey);
          final isToday = index == 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFF6C63FF), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayLabel(day),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white70
                          : (isDark ? Colors.grey.shade400 : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isComplete && wordCount > 0)
                    const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 14)
                  else if (wordCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFFFF6B6B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$wordCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFFFF6B6B),
                        ),
                      ),
                    )
                  else
                    Text('—',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white54 : Colors.grey,
                        )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayInfo(bool isDark) {
    final words = _currentWords;
    final reviewed = words.where((w) => w.isReviewed).length;
    final unreviewedDue = words.where((w) => !w.isReviewed && !w.isOverdue).length;
    final overdue = words.where((w) => w.isOverdue).length;
    final total = words.length;
    final isToday = _selectedDayIndex == 0;
    final isPast = _selectedDayIndex > 0;
    final isComplete = isToday 
        ? (total > 0 && words.where((w) => !w.isReviewed).isEmpty)
        : (reviewed > 0); // Ngày quá khứ: có ôn = hoàn thành

    // Subtitle text
    String subtitle;
    if (isToday) {
      if (total == 0) {
        subtitle = 'Không có từ cần ôn';
      } else if (words.where((w) => !w.isReviewed).isEmpty) {
        subtitle = '🎉 Hoàn thành! Đã ôn $reviewed từ';
      } else {
        subtitle = '$reviewed/$total từ đã ôn';
      }
    } else {
      // Ngày quá khứ
      if (reviewed > 0 && unreviewedDue == 0) {
        subtitle = '✅ Đã ôn $reviewed từ';
      } else if (reviewed > 0 && unreviewedDue > 0) {
        subtitle = '✅ $reviewed đã ôn · ⚠️ $unreviewedDue bỏ sót';
      } else if (unreviewedDue > 0) {
        subtitle = '⚠️ $unreviewedDue từ bỏ sót';
      } else {
        subtitle = 'Không có hoạt động';
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isComplete && total > 0
            ? const LinearGradient(
                colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)],
              )
            : (total > 0
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  )
                : LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2A2A3E), const Color(0xFF3A3A4E)]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                  )),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isComplete && total > 0
                ? Icons.celebration
                : (total > 0 ? Icons.pending_actions : Icons.event_available),
            color: (isComplete && total > 0) || total > 0 ? Colors.white : Colors.grey,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? 'Hôm nay'
                      : DateFormat('dd/MM (EEEE)').format(_days[_selectedDayIndex]),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: (isComplete && total > 0) || total > 0 ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: (isComplete && total > 0) || total > 0
                        ? Colors.white.withOpacity(0.9)
                        : (isDark ? Colors.grey.shade400 : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            CircularProgressIndicator(
              value: total > 0 ? reviewed / total : 0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              strokeWidth: 3,
            ),
        ],
      ),
    );
  }

  Widget _buildWordList(bool isDark) {
    final words = _currentWords;
    if (words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text(
              'Không có từ cần ôn!',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final item = words[index];
        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: EdgeInsets.zero,
              color: item.isReviewed
                  ? (isDark ? const Color(0xFF1A3A2A) : const Color(0xFFF0FDF4))
                  : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
              hasShadow: !item.isOverdue && !item.isReviewed,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.isReviewed
                    ? const Color(0xFF4ADE80).withOpacity(0.15)
                    : (item.isOverdue
                        ? Colors.orange.withOpacity(0.1)
                        : const Color(0xFF6C63FF).withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.isReviewed
                    ? Icons.check_circle
                    : (item.isOverdue ? Icons.warning_amber_rounded : Icons.schedule),
                color: item.isReviewed
                    ? const Color(0xFF4ADE80)
                    : (item.isOverdue ? Colors.orange : const Color(0xFF6C63FF)),
                size: 22,
              ),
            ),
            title: Text(
              item.word.word,
              style: TextStyle(
                fontWeight: item.isReviewed ? FontWeight.w500 : FontWeight.w600,
                color: item.isReviewed
                    ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            subtitle: Text(
              item.word.meaning,
              style: TextStyle(
                fontSize: 13,
                color: item.isReviewed
                    ? (isDark ? Colors.green.shade200.withOpacity(0.7) : Colors.green.shade600)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
            trailing: item.isOverdue
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Quá hạn',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  )
                : (item.isReviewed
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF4ADE80).withOpacity(0.15) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Đã ôn',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF4ADE80) : Colors.green.shade700,
                          ),
                        ),
                      )
                    : null),
          ),
        ),
          ),
        );
      },
    );
  }

  String _getDayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(day.year, day.month, day.day)).inDays;
    if (diff == 0) return 'Nay';
    if (diff == 1) return 'Qua';
    final weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return weekdays[day.weekday % 7];
  }
}

class _ReviewWordItem {
  final Word word;
  final UserWordProgress progress;
  final bool isReviewed;
  final bool isOverdue;

  _ReviewWordItem({
    required this.word,
    required this.progress,
    this.isReviewed = false,
    this.isOverdue = false,
  });
}
