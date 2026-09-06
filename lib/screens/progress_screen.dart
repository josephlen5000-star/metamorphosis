import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../models/food_log_entry.dart';
import '../models/user.dart';
import '../models/weekly_insights.dart';
import '../services/firebase_service.dart';
import '../services/food_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'history_screen.dart';

const progressWeekChartKey = Key('progress-week-calorie-chart');
const progressMacroBarPrefix = 'progress-macro-bar-';

List<DateTime> progressLast7Days(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
  ];
}

/// One day in the Progress week chart. [calories] is only meaningful when
/// [hasData] is true; empty days stay unset instead of becoming 0.
class ProgressWeekChartDay {
  const ProgressWeekChartDay({
    required this.date,
    required this.label,
    required this.hasData,
    required this.calories,
  });

  final DateTime date;
  final String label;
  final bool hasData;
  final double calories;
}

List<ProgressWeekChartDay> progressWeekChartDays({
  required DateTime now,
  required Map<DateTime, List<FoodLogEntry>> entriesByDate,
}) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return [
    for (final day in progressLast7Days(now))
      ProgressWeekChartDay(
        date: day,
        label: weekdays[day.weekday - 1],
        hasData: (entriesByDate[day] ?? const []).isNotEmpty,
        calories: historyTotalsFor(entriesByDate[day] ?? const []).calories,
      ),
  ];
}

/// Chart scale: the larger of the existing daily target and the week's
/// logged calorie totals. Empty days are ignored so they do not become 0.
double progressWeekChartMaxCalories({
  required List<ProgressWeekChartDay> days,
  required int? target,
}) {
  var maxCalories = 0.0;
  for (final day in days) {
    if (day.hasData && day.calories > maxCalories) {
      maxCalories = day.calories;
    }
  }
  if (target != null && target > maxCalories) {
    return target.toDouble();
  }
  return maxCalories;
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    @visibleForTesting this.profileLoader,
    @visibleForTesting this.todaysEntriesLoader,
    @visibleForTesting this.allEntriesLoader,
    @visibleForTesting this.todaysWaterLoader,
    @visibleForTesting this.waterForDateLoader,
    @visibleForTesting this.now,
  });

  final Future<User?> Function()? profileLoader;
  final Future<List<FoodLogEntry>> Function()? todaysEntriesLoader;
  final Future<List<FoodLogEntry>> Function()? allEntriesLoader;
  final Future<int> Function()? todaysWaterLoader;
  final Future<int> Function(DateTime date)? waterForDateLoader;
  final DateTime? now;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  User? _profile;
  List<FoodLogEntry> _todaysEntries = [];
  Map<DateTime, List<FoodLogEntry>> _entriesByDate = {};
  Map<DateTime, int> _waterByDate = {};
  int _todaysWater = 0;
  bool _isLoading = true;
  String? _error;

  DateTime get _now => widget.now ?? DateTime.now();

  DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileLoader =
          widget.profileLoader ?? FirebaseService().getUserProfile;
      final todaysLoader = widget.todaysEntriesLoader ??
          () => FoodDatabase.instance.getLogEntriesForDate(_now);
      final allLoader =
          widget.allEntriesLoader ?? FoodDatabase.instance.getAllLogEntries;
      final waterLoader = widget.todaysWaterLoader ??
          () => FoodDatabase.instance.getWaterGlassesForDate(_now);

      final profile = await profileLoader();
      final todayEntries = await todaysLoader();
      final allEntries = await allLoader();
      final water = await waterLoader();
      final weekDays = progressLast7Days(_now);
      final waterByDate = await _loadWeekWater(weekDays, todayWater: water);

      final grouped = <DateTime, List<FoodLogEntry>>{};
      for (final entry in allEntries) {
        grouped.putIfAbsent(_dayOf(entry.loggedAt), () => []).add(entry);
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _todaysEntries = todayEntries;
        _entriesByDate = grouped;
        _waterByDate = waterByDate;
        _todaysWater = waterByDate[_dayOf(_now)] ?? water;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Couldn\'t load progress.';
      });
    }
  }

  Future<Map<DateTime, int>> _loadWeekWater(
    List<DateTime> days, {
    required int todayWater,
  }) async {
    final loader = widget.waterForDateLoader;
    if (loader != null) {
      return {
        for (final day in days) day: await loader(day),
      };
    }
    if (widget.todaysWaterLoader != null) {
      final today = _dayOf(_now);
      return {
        for (final day in days) day: day == today ? todayWater : 0,
      };
    }
    return {
      for (final day in days)
        day: await FoodDatabase.instance.getWaterGlassesForDate(day),
    };
  }

  void _openHistory() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const HistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.chrome,
        border: AppStyle.navBorder,
        leading: AppStyle.backButton(context),
        middle: const Text(
          'Progress',
          style: AppStyle.navTitle,
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppStyle.bodySecondary,
            ),
            CupertinoButton(
              onPressed: _load,
              child: const Text(
                'Retry',
                style: AppStyle.accentAction,
              ),
            ),
          ],
        ),
      );
    }

    final totals = historyTotalsFor(_todaysEntries);
    return ListView(
      padding: AppStyle.pagePadding,
      children: [
        _calorieCard(totals),
        const SizedBox(height: 14),
        _macroCard(totals),
        const SizedBox(height: 14),
        _waterCard(),
        const SizedBox(height: 14),
        _weekCard(),
        const SizedBox(height: 14),
        _insightsCard(),
      ],
    );
  }

  Widget _calorieCard(HistoryDayTotals totals) {
    final target = _profile?.calorieTarget;
    final remaining = target == null ? null : target - totals.calories;
    final progress = target == null || target <= 0
        ? 0.0
        : (totals.calories / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: _cardDecoration,
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Today',
              style: AppStyle.sectionTitle,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 168,
            height: 168,
            child: CustomPaint(
              painter: _CalorieRingPainter(progress: progress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatTotal(totals.calories, fractionDigits: 0),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'kcal eaten',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (target != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _statColumn(
                  'Target',
                  _formatTotal(target.toDouble(), fractionDigits: 0),
                ),
                _statColumn(
                  'Remaining',
                  _formatTotal(remaining!, fractionDigits: 0),
                  valueColor: remaining < 0
                      ? AppColors.progressOver
                      : AppColors.textPrimary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statColumn(
    String label,
    String value, {
    Color valueColor = AppColors.textPrimary,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppStyle.fieldLabel,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCard(HistoryDayTotals totals) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Macros',
            style: AppStyle.sectionTitle,
          ),
          const SizedBox(height: 14),
          _macroRow('Protein', totals.protein, _profile?.proteinGoal),
          const SizedBox(height: 14),
          _macroRow('Carbs', totals.carbohydrates, _profile?.carbohydrateGoal),
          const SizedBox(height: 14),
          _macroRow('Fat', totals.fats, _profile?.fatGoal),
        ],
      ),
    );
  }

  Widget _macroRow(String label, double eaten, double? goal) {
    final hasGoal = goal != null && goal > 0;
    final over = hasGoal && eaten > goal;
    final progress = hasGoal ? (eaten / goal).clamp(0.0, 1.0) : null;
    final value = hasGoal
        ? '${_formatGrams(eaten)} / ${_formatGrams(goal)} g'
        : '${_formatGrams(eaten)} g';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: over ? AppColors.progressOver : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          KeyedSubtree(
            key: Key('$progressMacroBarPrefix$label'),
            child: _thinBar(progress, height: 8, over: over),
          ),
        ],
      ],
    );
  }

  Widget _waterCard() {
    final goal = _profile?.dailyWaterGoal ?? User.defaultWaterGoal;
    final progress = goal <= 0 ? 0.0 : (_todaysWater / goal).clamp(0.0, 1.0);
    final over = goal > 0 && _todaysWater > goal;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water',
            style: AppStyle.sectionTitle,
          ),
          const SizedBox(height: 8),
          Text(
            '$_todaysWater / $goal glasses',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: over ? AppColors.progressOver : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _thinBar(progress, over: over),
        ],
      ),
    );
  }

  Widget _weekCard() {
    final days = progressWeekChartDays(
      now: _now,
      entriesByDate: _entriesByDate,
    );
    final target = _profile?.calorieTarget;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Last 7 days',
                  style: AppStyle.sectionTitle,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                onPressed: _openHistory,
                child: const Text(
                  'History',
                  style: AppStyle.accentAction,
                ),
              ),
            ],
          ),
          const Text(
            'Calories vs daily target',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _WeekCalorieChart(
            days: days,
            target: target,
          ),
        ],
      ),
    );
  }

  Widget _insightsCard() {
    final insights = WeeklyInsights.from(
      days: progressLast7Days(_now),
      entriesByDate: _entriesByDate,
      waterByDate: _waterByDate,
      profile: _profile,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Insights',
            style: AppStyle.sectionTitle,
          ),
          const SizedBox(height: 16),
          _insightSubtitle('Calories'),
          _insightRow(
            'Average eaten',
            insights.averageCalories == null
                ? 'No data'
                : '${_formatTotal(insights.averageCalories!)} kcal',
          ),
          _insightRow(
            'Daily target',
            insights.calorieTarget == null
                ? 'No data'
                : '${_formatTotal(insights.calorieTarget!.toDouble(), fractionDigits: 0)} kcal',
          ),
          _insightRow(
            'Days logged',
            '${insights.daysWithFood} / ${WeeklyInsights.windowDays}',
          ),
          _insightRow(
            'Below target',
            insights.averageCalories == null || insights.calorieTarget == null
                ? 'No data'
                : '${insights.daysBelowCalorieTarget} days',
          ),
          const SizedBox(height: 14),
          _insightSubtitle('Macros'),
          _insightMacroRow(
            'Protein',
            insights.averageProtein,
            insights.proteinGoal,
          ),
          _insightMacroRow(
            'Carbs',
            insights.averageCarbohydrates,
            insights.carbohydrateGoal,
          ),
          _insightMacroRow('Fat', insights.averageFats, insights.fatGoal),
          const SizedBox(height: 14),
          _insightSubtitle('Consistency'),
          _insightRow(
            'Food logged',
            '${insights.daysWithFood} / ${WeeklyInsights.windowDays}',
          ),
          _insightRow(
            'Water logged',
            '${insights.daysWithWater} / ${WeeklyInsights.windowDays}',
          ),
          _insightRow(
            'Average water',
            insights.averageWater == null
                ? 'No data'
                : '${_formatTotal(insights.averageWater!)} glasses',
          ),
          _insightRow('Water goal', '${insights.waterGoal} glasses'),
          const SizedBox(height: 14),
          _insightSubtitle('This week'),
          for (var i = 0; i < insights.observations.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(
              insights.observations[i],
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightSubtitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _insightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightMacroRow(String label, double? average, double? goal) {
    if (average == null) {
      return _insightRow(label, 'No data');
    }
    final hasGoal = goal != null && goal > 0;
    final value = hasGoal
        ? '${_formatGrams(average)} / ${_formatGrams(goal)} g'
        : '${_formatGrams(average)} g';
    return _insightRow(label, value);
  }

  Widget _thinBar(double progress, {double height = 6, bool over = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                const ColoredBox(
                  color: AppColors.progressTrack,
                  child: SizedBox.expand(),
                ),
                Container(
                  width: constraints.maxWidth * progress,
                  color: over ? AppColors.progressOver : AppColors.accent,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeekCalorieChart extends StatelessWidget {
  const _WeekCalorieChart({
    required this.days,
    required this.target,
  });

  static const _valueHeight = 20.0;
  static const _plotHeight = 132.0;

  final List<ProgressWeekChartDay> days;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final maxCalories = progressWeekChartMaxCalories(
      days: days,
      target: target,
    );
    final showTarget = target != null && target! > 0 && maxCalories > 0;
    final targetTop = showTarget
        ? _valueHeight + _plotHeight * (1 - (target! / maxCalories))
        : null;

    return KeyedSubtree(
      key: progressWeekChartKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: _valueHeight + _plotHeight,
                  child: Stack(
                    children: [
                      if (targetTop != null)
                        Positioned(
                          top: targetTop - 0.5,
                          left: 0,
                          right: 0,
                          child: const ColoredBox(
                            color: AppColors.toolbarDivider,
                            child: SizedBox(height: 1),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final day in days)
                            Expanded(
                              child: _WeekChartColumn(
                                day: day,
                                maxCalories: maxCalories,
                                valueHeight: _valueHeight,
                                plotHeight: _plotHeight,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final day in days)
                      Expanded(
                        child: Text(
                          day.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (showTarget) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 32,
              height: _valueHeight + _plotHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: targetTop! - 7,
                    left: 0,
                    right: 0,
                    child: Text(
                      _formatTotal(target!.toDouble(), fractionDigits: 0),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekChartColumn extends StatelessWidget {
  const _WeekChartColumn({
    required this.day,
    required this.maxCalories,
    required this.valueHeight,
    required this.plotHeight,
  });

  final ProgressWeekChartDay day;
  final double maxCalories;
  final double valueHeight;
  final double plotHeight;

  @override
  Widget build(BuildContext context) {
    final barHeight = !day.hasData || maxCalories <= 0
        ? 0.0
        : plotHeight * (day.calories / maxCalories).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          SizedBox(
            height: valueHeight,
            child: day.hasData
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatTotal(day.calories, fractionDigits: 0),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
          SizedBox(
            height: plotHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: day.hasData
                  ? Container(
                      width: 16,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  const _CalorieRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.progressTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

const _cardDecoration = AppStyle.card;

String _formatTotal(double value, {int fractionDigits = 1}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(fractionDigits);
}

String _formatGrams(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toStringAsFixed(0);
  }
  return rounded.toStringAsFixed(1);
}
