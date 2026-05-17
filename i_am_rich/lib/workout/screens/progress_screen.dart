import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/workout_database.dart';
import '../models/exercise.dart';

enum _Interval { all, twoWeeks, oneMonth, threeMonths, sixMonths, custom }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _db = WorkoutDatabase.instance;
  List<Exercise> _exercises = [];
  Exercise? _selected;
  List<Map<String, dynamic>> _progressData = [];
  Map<String, dynamic>? _pr;
  int _streak = 0;
  int _weeklyCount = 0;
  bool _loading = true;
  bool _chartLoading = false;
  _Interval _interval = _Interval.all;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final exercises = await _db.getAllExercises();
    final streak = await _db.getWorkoutStreak();
    final weekly = await _db.getWeeklyWorkoutCount();
    if (mounted) {
      setState(() {
        _exercises = exercises;
        _streak = streak;
        _weeklyCount = weekly;
        _loading = false;
      });
    }
    if (exercises.isNotEmpty) _selectExercise(exercises.first);
  }

  String? _fromDate() {
    final now = DateTime.now();
    switch (_interval) {
      case _Interval.twoWeeks:
        return _fmt(now.subtract(const Duration(days: 14)));
      case _Interval.oneMonth:
        return _fmt(now.subtract(const Duration(days: 30)));
      case _Interval.threeMonths:
        return _fmt(now.subtract(const Duration(days: 90)));
      case _Interval.sixMonths:
        return _fmt(now.subtract(const Duration(days: 180)));
      case _Interval.custom:
        return _customFrom != null ? _fmt(_customFrom!) : null;
      default:
        return null;
    }
  }

  String? _toDate() {
    if (_interval == _Interval.custom && _customTo != null) {
      return _fmt(_customTo!);
    }
    return null;
  }

  Future<void> _selectExercise(Exercise ex) async {
    setState(() {
      _selected = ex;
      _chartLoading = true;
    });
    final data = await _db.getProgressForExercise(ex.id,
        fromDate: _fromDate(), toDate: _toDate());
    final pr = await _db.getPRForExercise(ex.id);
    if (mounted) {
      setState(() {
        _progressData = data;
        _pr = pr;
        _chartLoading = false;
      });
    }
  }

  Future<void> _setInterval(_Interval i) async {
    if (i == _Interval.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (range == null) return;
      _customFrom = range.start;
      _customTo = range.end;
    }
    setState(() => _interval = i);
    if (_selected != null) _selectExercise(_selected!);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        title: const Text('Progress',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOverviewCards(),
                const SizedBox(height: 24),
                _buildSectionHeader('Strength Progress'),
                const SizedBox(height: 12),
                _buildExercisePicker(),
                const SizedBox(height: 12),
                _buildIntervalChips(),
                const SizedBox(height: 16),
                _buildChart(),
                if (_pr != null) ...[
                  const SizedBox(height: 16),
                  _buildPRCard(),
                ],
                if (_progressData.length > 1) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('Session Detail'),
                  const SizedBox(height: 12),
                  _buildProgressDetail(),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildOverviewCards() => Row(
        children: [
          _OverviewCard(
            icon: Icons.local_fire_department,
            label: 'Current Streak',
            value: '$_streak days',
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 12),
          _OverviewCard(
            icon: Icons.calendar_today,
            label: 'This Week',
            value: '$_weeklyCount workouts',
            color: const Color(0xFF3498DB),
          ),
        ],
      );

  Widget _buildExercisePicker() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333355)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Exercise>(
            value: _selected,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF888899)),
            items: _exercises
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (e) {
              if (e != null) _selectExercise(e);
            },
          ),
        ),
      );

  Widget _buildIntervalChips() {
    final chips = [
      (_Interval.all, 'All'),
      (_Interval.twoWeeks, '2W'),
      (_Interval.oneMonth, '1M'),
      (_Interval.threeMonths, '3M'),
      (_Interval.sixMonths, '6M'),
      (_Interval.custom, 'Custom'),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips.map((c) {
          final selected = _interval == c.$1;
          String label = c.$2;
          if (c.$1 == _Interval.custom && _customFrom != null && _customTo != null) {
            label =
                '${DateFormat('d/M').format(_customFrom!)}–${DateFormat('d/M').format(_customTo!)}';
          }
          return GestureDetector(
            onTap: () => _setInterval(c.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF333355),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : const Color(0xFFCCCCDD),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    if (_chartLoading) {
      return const SizedBox(
        height: 220,
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }
    if (_progressData.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_outlined, color: Color(0xFF333355), size: 48),
              SizedBox(height: 12),
              Text('No data for this period',
                  style: TextStyle(color: Color(0xFF888899), fontSize: 14)),
              SizedBox(height: 4),
              Text('Complete workouts to see progress',
                  style: TextStyle(color: Color(0xFF555566), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    final dates = <double, String>{};
    for (int i = 0; i < _progressData.length; i++) {
      final row = _progressData[i];
      spots.add(FlSpot(i.toDouble(), (row['max_weight'] as num).toDouble()));
      dates[i.toDouble()] = row['date'] as String;
    }
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) < 5 ? 5.0 : (maxY - minY) * 0.15;

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY - yPad,
          maxY: maxY + yPad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFF333355), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text('${v.toInt()}kg',
                    style: const TextStyle(
                        color: Color(0xFF888899), fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: spots.length > 6
                    ? (spots.length / 4).roundToDouble()
                    : 1,
                getTitlesWidget: (v, _) {
                  final date = dates[v];
                  if (date == null) return const SizedBox.shrink();
                  try {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('d/M').format(DateTime.parse(date)),
                        style: const TextStyle(
                            color: Color(0xFF888899), fontSize: 10),
                      ),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFFFFD700),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFFFFD700),
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF0D0D1A),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33FFD700), Color(0x00FFD700)],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1A2E),
              tooltipBorder:
                  const BorderSide(color: Color(0xFFFFD700)),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} kg\n',
                        const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: dates[s.x] ?? '',
                            style: const TextStyle(
                                color: Color(0xFF888899),
                                fontSize: 11,
                                fontWeight: FontWeight.normal),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPRCard() {
    final pr = _pr!;
    final weight = (pr['weight'] as num).toDouble();
    final reps = pr['reps'] as int?;
    final date = pr['date'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [Color(0xFF2D1F00), Color(0xFF1A1A2E)]),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('PR',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal Record',
                    style: TextStyle(color: Color(0xFF888899), fontSize: 12)),
                Text(
                  '${_fmtW(weight)} kg${reps != null ? ' × $reps reps' : ''}',
                  style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                if (date != null) Text(_fmtDate(date),
                    style: const TextStyle(
                        color: Color(0xFF888899), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
        ],
      ),
    );
  }

  // ─── PROGRESS DETAIL ────────────────────────────────────────────────────────

  Widget _buildProgressDetail() {
    // Build from most-recent to oldest
    final entries = List.of(_progressData.reversed.toList());
    return Column(
      children: entries.asMap().entries.map((e) {
        final i = e.key;
        final row = e.value;
        final weight = (row['max_weight'] as num).toDouble();
        final date = row['date'] as String;

        // Compare to next entry (which is the previous session in reversed order)
        double? delta;
        if (i + 1 < entries.length) {
          final prevWeight =
              (entries[i + 1]['max_weight'] as num).toDouble();
          delta = weight - prevWeight;
        }

        return _ProgressDetailRow(
          date: date,
          weight: weight,
          delta: delta,
          isFirst: i == 0,
        );
      }).toList(),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) => Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      );

  String _fmtW(double w) =>
      w == w.truncate() ? w.toInt().toString() : w.toStringAsFixed(1);

  String _fmtDate(String date) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }
}

// ─── PROGRESS DETAIL ROW ─────────────────────────────────────────────────────

class _ProgressDetailRow extends StatelessWidget {
  final String date;
  final double weight;
  final double? delta;
  final bool isFirst;

  const _ProgressDetailRow({
    required this.date,
    required this.weight,
    required this.delta,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (delta == null) {
      statusColor = const Color(0xFF888899);
      statusIcon = Icons.fiber_new;
      statusText = 'First session';
    } else if (delta! > 0) {
      statusColor = const Color(0xFF2ECC71);
      statusIcon = Icons.arrow_upward;
      statusText =
          '+${_fmtW(delta!)} kg (+${(delta! / (weight - delta!) * 100).toStringAsFixed(1)}%)';
    } else if (delta! < 0) {
      statusColor = const Color(0xFFE74C3C);
      statusIcon = Icons.arrow_downward;
      statusText =
          '${_fmtW(delta!)} kg (${(delta! / (weight - delta!) * 100).toStringAsFixed(1)}%)';
    } else {
      statusColor = const Color(0xFFF39C12);
      statusIcon = Icons.remove;
      statusText = 'No change';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(date),
                  style: const TextStyle(
                      color: Color(0xFF888899), fontSize: 11),
                ),
                Text(
                  '${_fmtW(weight)} kg',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtW(double w) =>
      w == w.truncate() ? w.toInt().toString() : w.toStringAsFixed(1);

  String _fmtDate(String date) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF888899), fontSize: 12)),
            ],
          ),
        ),
      );
}
