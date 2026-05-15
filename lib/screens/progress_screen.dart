import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../db/database_helper.dart';
import '../models/topic.dart';
import '../models/user_word_progress.dart';
import '../models/study_session.dart';
import '../models/practice_result.dart';
import '../utils/constants.dart';
import '../utils/topic_icons.dart';
import '../theme/theme_extensions.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/common/animated_list_item.dart';
import '../widgets/common/skeleton_loader.dart';
import 'daily_review_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;

  // Data
  int _totalWords = 0, _learnedWords = 0, _dueCount = 0;
  int _streak = 0, _longestStreak = 0, _xpToday = 0, _dailyGoal = 15;
  List<Topic> _topics = [];
  Map<String, int> _wordsPerDay = {};
  Map<String, int> _xpPerDay = {};
  int _smNew = 0, _smLearning = 0, _smReview = 0, _smMastered = 0;
  // Line chart
  List<FlSpot> _lineSpots = [];
  List<String> _lineLabels = [];
  String _heatmapFilter = '30d';
  String _lineChartFilter = '30d';
  int _growthCount = 0;
  double _growthPct = 0.0;
  // Performance
  String _bestDay = '--';
  int _bestDayCount = 0, _avgPerDay = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await _db.updateTopicCounts();
      final topics = await _db.getTopics();
      final parentTopics = topics.where((t) => t.isParent).toList();
      final total = parentTopics.fold(0, (s, t) => s + t.wordCount);
      final learned = parentTopics.fold(0, (s, t) => s + t.learnedCount);

      // Due words
      final dueWords = await _db.getWordsToReview(DateTime.now());

      // User streak & XP
      int streak = 0, longestStreak = 0, dailyGoal = 15;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final u = await _db.getLocalUser(uid);
        if (u != null) {
          streak = (u['streak_days'] as int?) ?? 0;
          longestStreak = (u['longest_streak'] as int?) ?? streak;
          dailyGoal = (u['daily_goal'] as int?) ?? 15;
        }
      }

      // XP today & per day
      // XP today
      final now = DateTime.now();
      final sessions = await _db.getRecentStudySessions(30);
      final practices = await _db.getPracticeHistory(limit: 200);
      Map<String, int> xpPerDay = {};
      for (int i = 29; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        xpPerDay['${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] = 0;
      }
      for (var s in sessions) {
        final k = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
        if (xpPerDay.containsKey(k)) xpPerDay[k] = (xpPerDay[k] ?? 0) + s.xpEarned;
      }
      for (var p in practices) {
        final d = p.createdAt;
        final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (xpPerDay.containsKey(k)) xpPerDay[k] = (xpPerDay[k] ?? 0) + p.xpEarned;
      }
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final xpToday = xpPerDay[todayKey] ?? 0;

      // Heatmap data (always fetch max 6m to allow client filtering)
      final wordsPerDay = await _db.getWordsLearnedPerDay(182);

      // SM-2 distribution
      final allProgress = await _db.getAllWordProgress();
      int smNew = 0, smLearning = 0, smReview = 0, smMastered = 0;
      for (var p in allProgress) {
        switch (p.status) {
          case 0: smNew++; break;
          case 1: smLearning++; break;
          case 2: smReview++; break;
          case 3: smMastered++; break;
        }
      }

      // Line chart — cumulative learned words
      int lineDays = 30;
      if (_lineChartFilter == '7d') lineDays = 7;
      else if (_lineChartFilter == '3m') lineDays = 91;
      
      final cumData = await _db.getCumulativeLearnedWords(lineDays);
      int cumTotal = 0;
      List<FlSpot> spots = [];
      List<String> labels = [];
      int firstPoint = -1;
      if (cumData.isNotEmpty) {
        for (int i = 0; i < cumData.length; i++) {
          final c = (cumData[i]['count'] as int?) ?? 0;
          if (firstPoint == -1 && c > 0) firstPoint = cumTotal + c;
          cumTotal += c;
          spots.add(FlSpot(i.toDouble(), cumTotal.toDouble()));
          final day = cumData[i]['day']?.toString() ?? '';
          labels.add(day.length >= 5 ? '${day.substring(8, 10)}/${day.substring(5, 7)}' : day);
        }
      }
      if (firstPoint == -1) firstPoint = 0;
      int growthCount = cumTotal - firstPoint;
      double growthPct = firstPoint > 0 ? (growthCount / firstPoint) * 100 : 0.0;

      // Performance stats
      String bestDay = '--';
      int bestDayCount = 0;
      wordsPerDay.forEach((k, v) {
        if (v > bestDayCount) { bestDayCount = v; bestDay = k; }
      });
      if (bestDay.length >= 10) {
        try {
          final d = DateTime.parse(bestDay);
          final dayName = DateFormat('EEEE', 'vi_VN').format(d);
          final datePart = DateFormat('dd/MM').format(d);
          bestDay = '$dayName ($datePart)';
        } catch (_) {}
      }
      final activeDays = wordsPerDay.values.where((v) => v > 0).length;
      final totalStudied = wordsPerDay.values.fold(0, (s, v) => s + v);
      final avg = activeDays > 0 ? (totalStudied / activeDays).round() : 0;

      setState(() {
        _topics = parentTopics;
        _totalWords = total;
        _learnedWords = learned;
        _dueCount = dueWords.length;
        _streak = streak;
        _longestStreak = longestStreak;
        _xpToday = xpToday;
        _dailyGoal = dailyGoal;
        _wordsPerDay = wordsPerDay;
        _xpPerDay = xpPerDay;
        _smNew = smNew;
        _smLearning = smLearning;
        _smReview = smReview;
        _smMastered = smMastered;
        _lineSpots = spots;
        _lineLabels = labels;
        _growthCount = growthCount;
        _growthPct = growthPct;
        _bestDay = bestDay;
        _bestDayCount = bestDayCount;
        _avgPerDay = avg;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading progress: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2B2D42);

    return Scaffold(
      backgroundColor: isDark ? context.backgroundColor : const Color(0xFFF7F8FA),
      body: _isLoading
          ? CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  title: Text('Tiến độ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.calendar_month_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      onPressed: null,
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    // 1. Stats Row Skeleton
                    SkeletonBox(height: 100, borderRadius: 20.0),
                    const SizedBox(height: 14),
                    // 2. Task Card Skeleton
                    SkeletonBox(height: 120, borderRadius: 20.0),
                    const SizedBox(height: 20),
                    // 3. Heatmap Skeleton
                    SkeletonBox(height: 280, borderRadius: 20.0),
                    const SizedBox(height: 20),
                    // 4. Line Chart Skeleton
                    SkeletonBox(height: 260, borderRadius: 20.0),
                  ])),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // AppBar
                  SliverAppBar(
                    title: Text('Tiến độ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                    backgroundColor: Colors.transparent,
                    elevation: 0, floating: true, snap: true,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.calendar_month_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReviewScreen())),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(delegate: SliverChildListDelegate([
                      // 1. Header
                      ProgressHeaderCard(streak: _streak, totalLearned: _learnedWords, xpToday: _xpToday),
                      const SizedBox(height: 14),
                      // 2. Daily Mission
                      DailyMissionCard(dueCount: _dueCount, onStartReview: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReviewScreen()));
                      }),
                      const SizedBox(height: 20),
                      // 3. Heatmap
                      LearningHeatmap(
                        wordsPerDay: _wordsPerDay, 
                        currentStreak: _streak,
                        selectedFilter: _heatmapFilter,
                        onFilterChanged: (v) => setState(() => _heatmapFilter = v),
                      ),
                      const SizedBox(height: 20),
                      // 4. Line Chart
                      _buildLineChartSection(isDark, textPrimary),
                      const SizedBox(height: 20),
                      // 5+6. SM-2 + Performance (2 columns on wide, stacked on narrow)
                      Sm2DistributionCard(newCount: _smNew, learningCount: _smLearning, reviewCount: _smReview, masteredCount: _smMastered),
                      const SizedBox(height: 14),
                      PerformanceStatsCard(bestDay: _bestDay, bestDayCount: _bestDayCount, longestStreak: _longestStreak, avgPerDay: _avgPerDay),
                      const SizedBox(height: 20),
                      // 7. Topic Progress
                      _buildTopicSection(isDark, textPrimary),
                      const SizedBox(height: 20),
                      // 8. Smart Insights
                      Text('Gợi ý dành cho bạn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                      const SizedBox(height: 10),
                      SmartInsightsRow(streak: _streak, dueCount: _dueCount, dailyGoal: _dailyGoal),
                    ])),
                  ),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════
  // LINE CHART
  // ═══════════════════════════════════════
  Widget _buildLineChartSection(bool isDark, Color textPrimary) {
    final cardBg = isDark ? const Color(0xFF1F2125) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Tiến trình học tập', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _lineChartFilter,
                isDense: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : const Color(0xFF4A4A68)),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _lineChartFilter = v);
                    _loadAll(); // Re-fetch chart data
                  }
                },
                items: const [
                  DropdownMenuItem(value: '7d', child: Text('7 ngày')),
                  DropdownMenuItem(value: '30d', child: Text('30 ngày')),
                  DropdownMenuItem(value: '3m', child: Text('3 tháng')),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text('Tổng từ đã học', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('$_learnedWords', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, height: 1)),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('từ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500))),
          const SizedBox(width: 12),
          if (_growthCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.arrow_upward_rounded, size: 10, color: Color(0xFF22C55E)),
                const SizedBox(width: 2),
                Text('+$_growthCount từ (${_growthPct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
              ]),
            ),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          height: 180,
          child: _lineSpots.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.trending_up_rounded, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ]))
              : LineChart(LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, strokeWidth: 0.8)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, _) {
                      return Text(val.toInt().toString(), style: TextStyle(fontSize: 9, color: Colors.grey.shade500));
                    })),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (_lineSpots.length / 4).ceilToDouble().clamp(1, 100),
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= _lineLabels.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6),
                          child: Text(_lineLabels[i], style: TextStyle(fontSize: 9, color: Colors.grey.shade500)));
                      })),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _lineSpots, isCurved: true, curveSmoothness: 0.3,
                      color: const Color(0xFF6C63FF), barWidth: 2.5,
                      dotData: FlDotData(show: true, getDotPainter: (spot, _, __, ___) =>
                        spot == _lineSpots.last
                          ? FlDotCirclePainter(radius: 4, color: const Color(0xFF6C63FF), strokeWidth: 2, strokeColor: Colors.white)
                          : FlDotCirclePainter(radius: 0, color: Colors.transparent)),
                      belowBarData: BarAreaData(show: true,
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [const Color(0xFF6C63FF).withOpacity(0.2), const Color(0xFF6C63FF).withOpacity(0.0)])),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        '${s.y.toInt()} từ', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      )).toList(),
                    ),
                  ),
                )),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // TOPIC PROGRESS (horizontal scroll)
  // ═══════════════════════════════════════
  Widget _buildTopicSection(bool isDark, Color textPrimary) {
    final colors = [const Color(0xFF6C63FF), const Color(0xFF22C55E), const Color(0xFFFF6B35), const Color(0xFF3B82F6), const Color(0xFF8B5CF6), const Color(0xFFF59E0B)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Tiến độ theo chủ đề', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
        const Spacer(),
        Text('${_topics.length} chủ đề', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _topics.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final t = _topics[i];
            final c = colors[i % colors.length];
            final pct = (t.progress * 100).round();
            return Container(
              width: 160, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2125) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.withOpacity(isDark ? 0.2 : 0.1)),
                boxShadow: [BoxShadow(color: c.withOpacity(isDark ? 0.08 : 0.06), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(TopicIcons.get(t.name), size: 16, color: c),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary), overflow: TextOverflow.ellipsis)),
                ]),
                Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: t.progress, backgroundColor: c.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(c), minHeight: 5),
                  )),
                  const SizedBox(width: 10),
                  Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
                ]),
                Text('${t.learnedCount} / ${t.wordCount} từ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}