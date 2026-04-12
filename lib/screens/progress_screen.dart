import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import '../utils/constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/study_session.dart';
import '../models/practice_result.dart';
import '../utils/topic_icons.dart';
import '../widgets/progress_indicator.dart';
import 'practice_result_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/common/animated_list_item.dart';
import '../widgets/common/app_card.dart';
import '../theme/theme_extensions.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with AutomaticKeepAliveClientMixin {
  final _dbHelper = DatabaseHelper.instance;
  List<Topic> _topics = [];
  bool _isLoading = true;
  int _totalWords = 0;
  int _learnedWords = 0;
  
  // Gamification & Analytics Data
  int _dueWordsCount = 0;
  Map<String, int> _xpPerDay = {};
  List<PracticeResult> _practiceHistory = [];

  // ✅ Giữ state khi chuyển tab
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  // ✅ Tự động reload khi quay lại màn hình này
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data mỗi khi màn hình được hiển thị
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      // ✅ Cập nhật lại số lượng từ từ database trước
      await _dbHelper.updateTopicCounts();
      
      final topics = await _dbHelper.getTopics();
      final total = topics.fold(0, (sum, topic) => sum + topic.wordCount);
      final learned = topics.fold(0, (sum, topic) => sum + topic.learnedCount);

      // Fetch Gamification & SRS data
      final dueWords = await _dbHelper.getWordsToReview(DateTime.now());
      final recentSessions = await _dbHelper.getRecentStudySessions(7);
      
      // Calculate XP per day for the last 7 days using date string keys
      Map<String, int> xpPerDay = {};
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        xpPerDay[key] = 0; 
      }
      
      for (var session in recentSessions) {
        final sessionKey = '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}-${session.date.day.toString().padLeft(2, '0')}';
        if (xpPerDay.containsKey(sessionKey)) {
          xpPerDay[sessionKey] = (xpPerDay[sessionKey] ?? 0) + session.xpEarned;
        }
      }

      print('📊 XP per day: $xpPerDay');

      print('📊 Progress Screen - Total: $total, Learned: $learned, Due: ${dueWords.length}');

      // Load practice history
      final practiceHistory = await _dbHelper.getPracticeHistory(limit: 10);

      setState(() {
        _topics = topics;
        _totalWords = total;
        _learnedWords = learned;
        _dueWordsCount = dueWords.length;
        _xpPerDay = xpPerDay;
        _practiceHistory = practiceHistory;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading progress: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin
    
    final overallProgress = _totalWords > 0 ? _learnedWords / _totalWords : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.progress),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // ✅ Thêm nút refresh thủ công
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProgress,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProgress,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              AppConstants.primaryColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                        ),
                        padding: const EdgeInsets.all(AppConstants.paddingLarge),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tiến độ tổng thể',
                                  style: AppConstants.titleStyle,
                                ),
                                // ✅ Hiển thị thời gian cập nhật cuối
                                Text(
                                  'Cập nhật',
                                  style: AppConstants.subtitleStyle.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.paddingLarge),
                            CustomProgressIndicator(
                              progress: overallProgress,
                              label: '$_learnedWords / $_totalWords từ',
                              color: AppConstants.primaryColor,
                              size: 140,
                            ),
                            const SizedBox(height: AppConstants.paddingLarge),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStat(
                                  'Tổng số',
                                  '$_totalWords',
                                  Icons.book,
                                  AppConstants.primaryColor,
                                ),
                                _buildStat(
                                  'Đã học',
                                  '$_learnedWords',
                                  Icons.check_circle,
                                  AppConstants.secondaryColor,
                                ),
                                _buildStat(
                                  'Còn lại',
                                  '${_totalWords - _learnedWords}',
                                  Icons.pending,
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingLarge),

                    // SRS Due Words Card
                    if (_dueWordsCount > 0)
                      AppCard(
                        color: Colors.orange.shade50,
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_active, color: Colors.orange.shade800),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nhiệm vụ hôm nay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade900)),
                                  const SizedBox(height: 4),
                                  Text('Bạn có $_dueWordsCount từ vựng đã đến hạn ôn tập!', style: TextStyle(color: Colors.orange.shade800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppConstants.paddingLarge),

                    // XP Bar Chart
                    Text(
                      'XP Tuần này',
                      style: AppConstants.titleStyle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    SizedBox(
                      height: 200,
                      child: AppCard(
                        padding: const EdgeInsets.only(top: 24.0, right: 16, left: 16, bottom: 8),
                        child: _buildXpChart(),
                      ),
                    ),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // 📊 Lịch sử luyện tập
                    if (_practiceHistory.isNotEmpty) ...[
                      Text(
                        'Lịch sử luyện tập',
                        style: AppConstants.titleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppConstants.paddingMedium),
                      ..._practiceHistory.map((result) => _buildPracticeHistoryCard(result)),
                      const SizedBox(height: AppConstants.paddingLarge),
                    ],

                    Text(
                      'Tiến độ theo chủ đề',
                      style: AppConstants.titleStyle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topics.length,
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        return AnimatedListItem(
                          index: index,
                          child: Padding(
                          padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        TopicIcons.get(topic.name),
                                        size: 28,
                                        color: AppConstants.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppConstants.paddingMedium),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            topic.name,
                                            style: AppConstants.titleStyle.copyWith(fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${topic.learnedCount} / ${topic.wordCount} từ',
                                            style: AppConstants.subtitleStyle.copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getProgressColor(topic.progress),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getProgressColor(topic.progress).withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${(topic.progress * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppConstants.paddingMedium),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: topic.progress,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getProgressColor(topic.progress),
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        );
                      },
                    ),
                    const SizedBox(height: 80), // ✅ Padding để tránh bottom nav
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppConstants.subtitleStyle.copyWith(fontSize: 12),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return AppConstants.errorColor;
    if (progress < 0.7) return Colors.orange;
    return AppConstants.secondaryColor;
  }

  Widget _buildXpChart() {
    final totalXp = _xpPerDay.values.fold(0, (sum, v) => sum + v);
    
    if (_xpPerDay.isEmpty || totalXp == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Chưa có dữ liệu XP tuần này',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Học từ vựng hoặc làm quiz để nhận XP!',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Prepare data
    final now = DateTime.now();
    List<BarChartGroupData> barGroups = [];
    List<String> days = [];
    
    // Pre-calculate maxXP
    int maxXP = _xpPerDay.values.fold(0, (max, v) => v > max ? v : max);
    final chartMaxY = maxXP > 0 ? (maxXP * 1.3).toDouble() : 100.0;
    
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      days.add(DateFormat('E', 'vi_VN').format(d));
      
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      int xp = _xpPerDay[key] ?? 0;
      
      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: xp.toDouble(),
              color: i == 0 ? AppConstants.primaryColor : Colors.blue.shade200,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMaxY,
                color: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        barGroups: barGroups,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueAccent,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} XP\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    days[idx],
                    style: TextStyle(
                      color: idx == 6 ? AppConstants.primaryColor : Colors.grey,
                      fontWeight: idx == 6 ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPracticeHistoryCard(PracticeResult result) {
    final percentage = (result.accuracy * 100).round();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(result.createdAt);

    Color accentColor;
    if (percentage >= 80) {
      accentColor = const Color(0xFF4ADE80);
    } else if (percentage >= 60) {
      accentColor = const Color(0xFFFBBF24);
    } else {
      accentColor = const Color(0xFFFF6B6B);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PracticeResultScreen(result: result),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Score circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(result.modeEmoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          result.modeLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '✅ ${result.correctCount}/${result.totalQuestions} câu đúng • ⭐ +${result.xpEarned} XP • ⏱️ ${result.durationFormatted}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (result.topicNames.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📚 ${result.topicNames.take(3).join(', ')}${result.topicNames.length > 3 ? '...' : ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}