import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/workout_database.dart';
import '../models/exercise.dart';
import '../models/workout_plan_day.dart';
import '../models/workout_log.dart';
import 'workout_logging_screen.dart';
import 'workout_plan_screen.dart';
import 'exercise_library_screen.dart';
import 'progress_screen.dart';
import 'workout_history_screen.dart';
import 'quick_start_screen.dart';
import '../widgets/exercise_tile.dart';
import 'package:uuid/uuid.dart';

class WorkoutHomeScreen extends StatefulWidget {
  const WorkoutHomeScreen({super.key});

  @override
  State<WorkoutHomeScreen> createState() => _WorkoutHomeScreenState();
}

class _WorkoutHomeScreenState extends State<WorkoutHomeScreen> {
  final _db = WorkoutDatabase.instance;

  DateTime _selectedDate = DateTime.now();
  WorkoutPlanDay? _dayPlan;
  WorkoutLog? _dayLog;
  List<Exercise> _dayExercises = [];
  int _streak = 0;
  int _weeklyCount = 0;
  bool _loading = true;

  String get _dateStr {
    final d = _selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  bool get _isFuture => _selectedDate.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final planDay = await _db.getPlanDayForWeekday(_selectedDate.weekday);
      final log = await _db.getWorkoutLogForDate(_dateStr);
      final streak = await _db.getWorkoutStreak();
      final weekly = await _db.getWeeklyWorkoutCount();

      List<Exercise> exercises = [];
      if (planDay != null && !planDay.isRestDay) {
        final override = await _db.getDayOverride(_dateStr);
        final ids = override ?? planDay.exerciseIds;
        for (final id in ids) {
          final ex = await _db.getExerciseById(id);
          if (ex != null) exercises.add(ex);
        }
      }

      if (mounted) {
        setState(() {
          _dayPlan = planDay;
          _dayLog = log;
          _dayExercises = exercises;
          _streak = streak;
          _weeklyCount = weekly;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _load();
  }

  void _nextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _startWorkout() async {
    if (_dayPlan == null && _dayExercises.isEmpty) {
      _showQuickStart();
      return;
    }
    const uuid = Uuid();
    final log = await _db.createOrGetWorkoutLog(
      WorkoutLog(
        id: uuid.v4(),
        date: _dateStr,
        planDayId: _dayPlan?.id,
        workoutName: _dayPlan?.workoutName ?? 'Custom Workout',
      ),
    );
    if (log.exercises.isEmpty) {
      for (int i = 0; i < _dayExercises.length; i++) {
        final exLog = ExerciseLog(
          id: uuid.v4(),
          workoutLogId: log.id,
          exerciseId: _dayExercises[i].id,
          orderIndex: i,
        );
        await _db.createExerciseLog(exLog);
        log.exercises.add(exLog);
      }
    }
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => WorkoutLoggingScreen(workoutLog: log)));
    _load();
  }

  void _showQuickStart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickStartScreen(targetDate: _dateStr),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : RefreshIndicator(
              color: const Color(0xFFFFD700),
              backgroundColor: const Color(0xFF1A1A2E),
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildDateNav(),
                        const SizedBox(height: 12),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildTodayCard(),
                        const SizedBox(height: 20),
                        _buildQuickNav(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D1A),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
          child: const Row(
            children: [
              Icon(Icons.fitness_center, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 8),
              Text(
                'GYM TRACKER',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNav() {
    final dayName = _isToday
        ? 'Today'
        : _isFuture
            ? DateFormat('EEEE').format(_selectedDate)
            : DateFormat('EEEE').format(_selectedDate);
    final dateLabel = DateFormat('MMM d, yyyy').format(_selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _prevDay,
            ),
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Column(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        color: _isToday
                            ? const Color(0xFFFFD700)
                            : _isFuture
                                ? const Color(0xFF3498DB)
                                : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                          color: Color(0xFF888899), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: _isToday ? const Color(0xFF333355) : Colors.white,
              ),
              onPressed: _isToday ? null : _nextDay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.local_fire_department,
            label: 'Streak',
            value: '${_streak}d',
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.calendar_today,
            label: 'This Week',
            value: '$_weeklyCount / 7',
            color: const Color(0xFF3498DB),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: _dayLog?.completed == true
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            label: _isToday ? 'Today' : 'Status',
            value: _dayLog?.completed == true
                ? 'Done'
                : _dayLog != null
                    ? 'In Progress'
                    : 'Pending',
            color: _dayLog?.completed == true
                ? const Color(0xFF2ECC71)
                : _dayLog != null
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF888899),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    final isRest = _dayPlan?.isRestDay ?? false;
    final noPlan = _dayPlan == null;
    final isCompleted = _dayLog?.completed == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF2ECC71).withOpacity(0.4)
                : const Color(0xFFFFD700).withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDayHeader(isRest, noPlan, isCompleted),
            if (!isRest && !noPlan && _dayExercises.isNotEmpty) ...[
              const Divider(color: Color(0xFF333355), height: 1),
              _buildExerciseList(),
            ],
            _buildActionButtons(isRest, noPlan, isCompleted),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(bool isRest, bool noPlan, bool isCompleted) {
    String title;
    String subtitle;
    IconData icon;
    Color color;

    if (_dayLog?.completed == true) {
      title = _dayLog!.workoutName;
      subtitle = '${_dayLog!.totalSets} sets · ${_dayLog!.totalVolume.toStringAsFixed(0)} kg vol';
      icon = Icons.check_circle;
      color = const Color(0xFF2ECC71);
    } else if (noPlan) {
      title = 'No Plan Set';
      subtitle = 'Quick Start or setup weekly plan';
      icon = Icons.add_circle_outline;
      color = const Color(0xFF888899);
    } else if (isRest) {
      title = 'Rest Day';
      subtitle = 'Recovery is part of progress';
      icon = Icons.self_improvement;
      color = const Color(0xFF3498DB);
    } else {
      title = _dayPlan!.workoutName;
      subtitle = '${_dayExercises.length} exercises planned';
      icon = Icons.fitness_center;
      color = const Color(0xFFFFD700);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF888899), fontSize: 13)),
              ],
            ),
          ),
          if (_isFuture)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Upcoming',
                  style: TextStyle(
                      color: Color(0xFF3498DB),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _dayExercises.length.clamp(0, 5),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => ExerciseTile(exercise: _dayExercises[i], compact: true),
    );
  }

  Widget _buildActionButtons(bool isRest, bool noPlan, bool isCompleted) {
    if (isRest) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: noPlan
                  ? _showQuickStart
                  : isCompleted
                      ? _startWorkout
                      : _startWorkout,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCompleted
                        ? [const Color(0xFF2ECC71), const Color(0xFF27AE60)]
                        : [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    noPlan
                        ? 'Quick Start'
                        : isCompleted
                            ? 'View Workout'
                            : _isFuture
                                ? 'Plan Workout'
                                : 'Start Workout',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!noPlan) ...[
            const SizedBox(width: 10),
            _IconBtn(
              icon: Icons.auto_fix_high,
              tooltip: 'Quick Start',
              onTap: _showQuickStart,
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.edit,
              tooltip: 'Edit Plan',
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WorkoutPlanScreen()));
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACCESS',
            style: TextStyle(
              color: Color(0xFF888899),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _NavCard(
                icon: Icons.auto_fix_high,
                label: 'Quick Start',
                color: const Color(0xFFFFD700),
                onTap: _showQuickStart,
              ),
              _NavCard(
                icon: Icons.calendar_month,
                label: 'Weekly Plan',
                color: const Color(0xFF9B59B6),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WorkoutPlanScreen()));
                  _load();
                },
              ),
              _NavCard(
                icon: Icons.sports_gymnastics,
                label: 'Exercises',
                color: const Color(0xFF3498DB),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen())),
              ),
              _NavCard(
                icon: Icons.bar_chart,
                label: 'Progress',
                color: const Color(0xFF2ECC71),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProgressScreen())),
              ),
              _NavCard(
                icon: Icons.history,
                label: 'History',
                color: const Color(0xFFE67E22),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF888899), fontSize: 11)),
            ],
          ),
        ),
      );
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333355)),
            ),
            child: Icon(icon, color: const Color(0xFFFFD700), size: 20),
          ),
        ),
      );
}
