import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/theme_extensions.dart';

// ═══════════════════════════════════════
// 1. HEADER SNAPSHOT CARD
// ═══════════════════════════════════════
class ProgressHeaderCard extends StatelessWidget {
  final int streak, totalLearned, xpToday;
  const ProgressHeaderCard({super.key, required this.streak, required this.totalLearned, required this.xpToday});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2125) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _stat(Icons.local_fire_department_rounded, '$streak', 'ngày', 'Streak', const Color(0xFFFF6B35), isDark),
          _vDivider(isDark),
          _stat(Icons.menu_book_rounded, '$totalLearned', 'từ', 'Tổng đã học', const Color(0xFF3B82F6), isDark),
          _vDivider(isDark),
          _stat(Icons.bolt_rounded, '+$xpToday', 'XP', 'Hôm nay', const Color(0xFFFFB400), isDark),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String unit, String label, Color color, bool isDark) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF2B2D42))),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
      ]),
    );
  }

  Widget _vDivider(bool isDark) => Container(width: 1, height: 48, color: isDark ? Colors.grey.shade800 : Colors.grey.shade100);
}

// ═══════════════════════════════════════
// 2. DAILY MISSION CARD
// ═══════════════════════════════════════
class DailyMissionCard extends StatelessWidget {
  final int dueCount;
  final VoidCallback onStartReview;
  const DailyMissionCard({super.key, required this.dueCount, required this.onStartReview});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDue = dueCount > 0;
    
    final bgDark = const Color(0xFF231C3B);
    final bgLight = const Color(0xFFF8F6FF);
    final primaryColor = const Color(0xFF4B36CC);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: hasDue
            ? (isDark ? bgDark : bgLight)
            : (isDark ? const Color(0xFF1E3A2F) : const Color(0xFFF0FDF4)),
        child: Stack(
          children: [
            // Faded background icon on the right
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                hasDue ? Icons.assignment_turned_in_rounded : Icons.emoji_events_rounded,
                size: 100,
                color: (hasDue ? primaryColor : const Color(0xFF22C55E)).withOpacity(isDark ? 0.05 : 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: hasDue ? (isDark ? primaryColor.withOpacity(0.3) : Colors.white) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasDue && !isDark ? [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
                  ),
                  child: Icon(hasDue ? Icons.track_changes_rounded : Icons.check_circle_rounded, 
                    color: hasDue ? primaryColor : const Color(0xFF22C55E), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nhiệm vụ hôm nay', style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF4A4A68), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  Text(
                    hasDue ? 'Bạn có $dueCount từ cần ôn tập' : 'Tuyệt vời! Bạn đã hoàn thành 🎉',
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF2B2D42), fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  if (hasDue) ...[
                    const SizedBox(height: 4),
                    Text('Ôn tập để củng cố trí nhớ và tăng XP', style: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF6B6B80), fontSize: 10)),
                  ]
                ])),
                const SizedBox(width: 10),
                if (hasDue) ElevatedButton(
                  onPressed: onStartReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  child: Row(children: const [
                    Text('Bắt đầu ôn tập', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10),
                  ]),
                ) else ElevatedButton(
                  onPressed: onStartReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text('Ôn tập thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 3. HEATMAP (ACTIVITY)
// ═══════════════════════════════════════
class LearningHeatmap extends StatelessWidget {
  final Map<String, int> wordsPerDay;
  final int currentStreak;
  final String selectedFilter; // '7d', '30d', '3m', '6m'
  final ValueChanged<String> onFilterChanged;

  const LearningHeatmap({
    super.key, 
    required this.wordsPerDay, 
    required this.currentStreak,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  Color _heatColor(int val, int maxVal, bool isDark) {
    if (val == 0) return isDark ? Colors.grey.shade800 : const Color(0xFFEBEDF0);
    // Strict scale: 0: #EBEDF0, 1: #C6E48B, 2: #7BC96F, 3: #239A3B, 4+: #196127
    if (maxVal <= 0) return const Color(0xFFC6E48B);
    final pct = val / maxVal;
    if (pct <= 0.25) return const Color(0xFFC6E48B);
    if (pct <= 0.50) return const Color(0xFF7BC96F);
    if (pct <= 0.75) return const Color(0xFF239A3B);
    return const Color(0xFF196127);
  }

  List<Widget> _buildLegend(bool isDark) {
    final colors = [
      isDark ? Colors.grey.shade800 : const Color(0xFFEBEDF0),
      const Color(0xFFC6E48B),
      const Color(0xFF7BC96F),
      const Color(0xFF239A3B),
      const Color(0xFF196127)
    ];
    return [
      Text('Ít', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      const SizedBox(width: 6),
      ...colors.map((c) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 10, height: 10,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          )),
      const SizedBox(width: 6),
      Text('Nhiều', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2125) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B2D42);
    final now = DateTime.now();
    final maxVal = wordsPerDay.values.isEmpty ? 1 : wordsPerDay.values.fold(1, (a, b) => a > b ? a : b);

    int totalDays;
    switch (selectedFilter) {
      case '7d': totalDays = 7; break;
      case '3m': totalDays = 91; break;
      case '6m': totalDays = 182; break;
      case '30d': 
      default: totalDays = 30; break;
    }

    final allDays = List.generate(totalDays, (i) => now.subtract(Duration(days: totalDays - 1 - i)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Hoạt động học tập', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedFilter,
                isDense: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : const Color(0xFF4A4A68)),
                onChanged: (v) { if (v != null) onFilterChanged(v); },
                items: const [
                  DropdownMenuItem(value: '7d', child: Text('7 ngày')),
                  DropdownMenuItem(value: '30d', child: Text('30 ngày')),
                  DropdownMenuItem(value: '3m', child: Text('3 tháng')),
                  DropdownMenuItem(value: '6m', child: Text('6 tháng')),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: _buildLegend(isDark)),
        const SizedBox(height: 14),
        // Grid Builder
        LayoutBuilder(builder: (context, constraints) {
          return selectedFilter == '7d' 
              ? _build7dGrid(allDays, maxVal, now, isDark)
              : _buildHorizontalGridWidget(allDays, maxVal, now, isDark);
        }),
        const SizedBox(height: 20),
        Row(children: [
          Icon(Icons.local_fire_department_rounded, color: const Color(0xFFFF6B35), size: 16),
          const SizedBox(width: 6),
          Text('Chuỗi hiện tại: ', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          Text('$currentStreak ngày', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF6B35))),
          const Spacer(),
          Text('Duy trì thêm 1 ngày để đạt ${currentStreak + 1} ngày!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }

  Widget _buildCell(DateTime d, int maxVal, DateTime now, bool isDark, double cellSize, double gap) {
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final val = wordsPerDay[key] ?? 0;
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final displayDate = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Tooltip(
        message: '📅 $displayDate\n📚 $val từ',
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        child: Container(
          width: cellSize, height: cellSize,
          decoration: BoxDecoration(
            color: _heatColor(val, maxVal, isDark),
            borderRadius: BorderRadius.circular(4),
            border: isToday ? Border.all(color: const Color(0xFF6C63FF), width: 1.5) : null,
            boxShadow: isToday ? [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 4)] : [],
          ),
        ),
      ),
    );
  }

  Widget _build7dGrid(List<DateTime> allDays, int maxVal, DateTime now, bool isDark) {
    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final cellSize = 28.0; // Slightly larger for 1 row, but < 30px
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Fills full width
      children: allDays.map((d) {
        return Column(children: [
          _buildCell(d, maxVal, now, isDark, cellSize, 4.0),
          const SizedBox(height: 4),
          Text(dayLabels[d.weekday - 1], style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]);
      }).toList(),
    );
  }

  Widget _buildHorizontalGridWidget(List<DateTime> allDays, int maxVal, DateTime now, bool isDark) {
    final startWeekday = allDays.first.weekday - 1; // 0=Mon, 6=Sun
    final totalCells = allDays.length + startWeekday;
    final exactCols = (totalCells / 7).ceil();
    
    // Allow scroll for 3m/6m. Fixed width (space-between) for 30d.
    bool isScrollable = exactCols > 7; 
    double cellSize = isScrollable ? 16.0 : 22.0;
    double gap = 4.0;

    List<List<DateTime?>> grid = List.generate(exactCols, (_) => List.filled(7, null));
    for (int i = 0; i < allDays.length; i++) {
      final d = allDays[i];
      final index = i + startWeekday;
      final col = index ~/ 7;
      final row = index % 7;
      if (col < exactCols) grid[col][row] = d;
    }

    Widget gridContent = Row(
      mainAxisAlignment: isScrollable ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
      children: grid.map((col) => Padding(
        padding: EdgeInsets.only(right: isScrollable ? gap : 0),
        child: Column(children: col.map((d) {
          if (d == null) return SizedBox(width: cellSize, height: cellSize + gap);
          return _buildCell(d, maxVal, now, isDark, cellSize, gap);
        }).toList()),
      )).toList(),
    );

    // Y-axis labels: T2 (0), T4 (2), T6 (4)
    Widget content = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 20,
        child: Column(children: List.generate(7, (i) {
          final text = (i == 0) ? 'T2' : (i == 2) ? 'T4' : (i == 4) ? 'T6' : '';
          return Container(
            height: cellSize + gap, alignment: Alignment.centerLeft,
            child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
          );
        })),
      ),
      const SizedBox(width: 8),
      isScrollable ? gridContent : Expanded(child: gridContent),
    ]);

    if (isScrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // Scroll to right (today)
        child: content,
      );
    }
    return content;
  }
}


// ═══════════════════════════════════════
// 4. SM-2 DISTRIBUTION DONUT
// ═══════════════════════════════════════
class Sm2DistributionCard extends StatelessWidget {
  final int newCount, learningCount, reviewCount, masteredCount;
  const Sm2DistributionCard({super.key, required this.newCount, required this.learningCount, required this.reviewCount, required this.masteredCount});

  int get total => newCount + learningCount + reviewCount + masteredCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2125) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B2D42);
    
    // Updated colors based on design sketch
    final colNew = const Color(0xFF8B5CF6);      // Purple
    final colLearn = const Color(0xFF3B82F6);    // Blue
    final colReview = const Color(0xFFF59E0B);   // Amber
    final colMaster = const Color(0xFF22C55E);   // Green

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Phân bố theo SM-2', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 20),
        Row(children: [
          SizedBox(
            width: 120, height: 120,
            child: total > 0 ? PieChart(PieChartData(
              sectionsSpace: 3, centerSpaceRadius: 32,
              sections: [
                _section(newCount, colNew),
                _section(learningCount, colLearn),
                _section(reviewCount, colReview),
                _section(masteredCount, colMaster),
              ],
            )) : Center(child: Text('Chưa có\ndữ liệu', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(children: [
            _row('Mới', newCount, colNew, isDark),
            const SizedBox(height: 10),
            _row('Đang học', learningCount, colLearn, isDark),
            const SizedBox(height: 10),
            _row('Ôn tập', reviewCount, colReview, isDark),
            const SizedBox(height: 10),
            _row('Đã nhớ lâu', masteredCount, colMaster, isDark),
          ])),
        ]),
      ]),
    );
  }

  PieChartSectionData _section(int val, Color c) => PieChartSectionData(
    value: val > 0 ? val.toDouble() : 0.001, color: c, radius: 24, showTitle: false,
  );

  Widget _row(String label, int count, Color color, bool isDark) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700))),
      Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF2B2D42))),
      const SizedBox(width: 6),
      SizedBox(width: 36, child: Text('$pct%', textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
    ]);
  }
}

// ═══════════════════════════════════════
// 5. PERFORMANCE STATS CARD
// ═══════════════════════════════════════
class PerformanceStatsCard extends StatelessWidget {
  final String bestDay;
  final int bestDayCount, longestStreak, avgPerDay;
  const PerformanceStatsCard({super.key, required this.bestDay, required this.bestDayCount, required this.longestStreak, required this.avgPerDay});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2125) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B2D42);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hiệu suất học tập', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 20),
        _statRow(Icons.emoji_events_rounded, 'Ngày học nhiều nhất', bestDay, '+$bestDayCount từ', const Color(0xFFFFB400), isDark),
        const SizedBox(height: 20),
        _statRow(Icons.local_fire_department_rounded, 'Chuỗi dài nhất', '$longestStreak ngày', '', const Color(0xFFFF6B35), isDark),
        const SizedBox(height: 20),
        _statRow(Icons.speed_rounded, 'Trung bình mỗi ngày', '$avgPerDay từ/ngày', '', const Color(0xFF6C63FF), isDark),
      ]),
    );
  }

  Widget _statRow(IconData icon, String label, String value, String extra, Color color, bool isDark) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF2B2D42))),
      ])),
      if (extra.isNotEmpty)
        Text(extra, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
    ]);
  }
}

// ═══════════════════════════════════════
// 6. SMART INSIGHTS (Pastel Cards)
// ═══════════════════════════════════════
class SmartInsightsRow extends StatelessWidget {
  final int streak, dueCount, dailyGoal;
  const SmartInsightsRow({super.key, required this.streak, required this.dueCount, required this.dailyGoal});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cards = <_InsightData>[];
    if (streak >= 3) cards.add(_InsightData('Tuyệt vời!', 'Bạn đã duy trì học tập $streak ngày liên tiếp.', const Color(0xFF22C55E), Icons.trending_up_rounded));
    if (dueCount > 0) cards.add(_InsightData('Gợi ý', 'Học thêm $dueCount từ hôm nay để giữ chuỗi streak! 🔥', const Color(0xFFFFB400), Icons.lightbulb_rounded));
    if (dailyGoal > 0) cards.add(_InsightData('Thử thách', 'Hoàn thành $dailyGoal từ mỗi ngày để đạt mục tiêu tháng!', const Color(0xFFFF6B35), Icons.track_changes_rounded));
    if (cards.isEmpty) cards.add(_InsightData('Bắt đầu nào!', 'Học từ vựng mỗi ngày để xây dựng thói quen tốt.', const Color(0xFF6C63FF), Icons.rocket_launch_rounded));

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = cards[i];
          return Container(
            width: 220, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.color.withOpacity(isDark ? 0.1 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(c.icon, color: c.color, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(c.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.color))),
              ]),
              const SizedBox(height: 10),
              Expanded(child: Text(c.body,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : const Color(0xFF4A4A68), height: 1.4),
                maxLines: 3, overflow: TextOverflow.ellipsis)),
            ]),
          );
        },
      ),
    );
  }
}

class _InsightData {
  final String title, body;
  final Color color;
  final IconData icon;
  _InsightData(this.title, this.body, this.color, this.icon);
}
