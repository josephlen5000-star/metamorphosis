import 'package:flutter/cupertino.dart';

import '../models/food_log_entry.dart';
import '../models/meal.dart';
import '../models/user.dart';
import '../models/weekly_insights.dart';
import '../services/firebase_service.dart';
import '../services/food_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    @visibleForTesting this.datesLoader,
    @visibleForTesting this.entriesLoader,
    @visibleForTesting this.allEntriesLoader,
    @visibleForTesting this.profileLoader,
    @visibleForTesting this.waterForDateLoader,
    @visibleForTesting this.now,
  });

  final Future<List<DateTime>> Function()? datesLoader;
  final Future<List<FoodLogEntry>> Function(DateTime date)? entriesLoader;
  final Future<List<FoodLogEntry>> Function()? allEntriesLoader;
  final Future<User?> Function()? profileLoader;
  final Future<int> Function(DateTime date)? waterForDateLoader;
  final DateTime? now;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DateTime> _dates = [];
  Map<DateTime, List<FoodLogEntry>> _entriesByDate = {};
  Map<DateTime, int> _waterByDate = {};
  User? _profile;
  bool _includeWaterSummary = false;
  bool _isLoading = true;
  String? _error;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _loadHistory({bool showSpinner = true}) async {
    setState(() {
      if (showSpinner) _isLoading = true;
      _error = null;
    });

    try {
      final allLoader = widget.allEntriesLoader;
      if (allLoader != null) {
        await _applyEntries(await allLoader());
        return;
      }

      if (widget.datesLoader != null && widget.entriesLoader != null) {
        final dates = await widget.datesLoader!();
        final grouped = <DateTime, List<FoodLogEntry>>{};
        for (final date in dates) {
          grouped[_dayOf(date)] = await widget.entriesLoader!(date);
        }
        await _finishLoad(
          dates: [for (final date in dates) _dayOf(date)],
          grouped: grouped,
        );
        return;
      }

      final entries = await FoodDatabase.instance.getAllLogEntries();
      await _applyEntries(entries);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Couldn\'t load history.';
      });
    }
  }

  Future<void> _applyEntries(List<FoodLogEntry> entries) async {
    final grouped = <DateTime, List<FoodLogEntry>>{};
    for (final entry in entries) {
      final day = _dayOf(entry.loggedAt);
      grouped.putIfAbsent(day, () => []).add(entry);
    }
    await _finishLoad(
      dates: FoodDatabase.datesWithLogEntries(entries),
      grouped: grouped,
    );
  }

  Future<void> _finishLoad({
    required List<DateTime> dates,
    required Map<DateTime, List<FoodLogEntry>> grouped,
  }) async {
    final weekDays = _last7Days();
    final extras = await _loadSummaryExtras(weekDays);
    if (!mounted) return;
    setState(() {
      _dates = dates;
      _entriesByDate = grouped;
      _profile = extras.profile;
      _waterByDate = extras.waterByDate;
      _includeWaterSummary = extras.includeWater;
      _isLoading = false;
    });
  }

  Future<({User? profile, Map<DateTime, int> waterByDate, bool includeWater})>
      _loadSummaryExtras(List<DateTime> weekDays) async {
    User? profile;
    var waterByDate = <DateTime, int>{};
    var includeWater = false;

    try {
      if (widget.profileLoader != null) {
        profile = await widget.profileLoader!();
      } else if (widget.datesLoader == null && widget.allEntriesLoader == null) {
        profile = await FirebaseService().getUserProfile();
      }
    } catch (_) {
      profile = null;
    }

    try {
      if (widget.waterForDateLoader != null) {
        includeWater = true;
        waterByDate = {
          for (final day in weekDays) day: await widget.waterForDateLoader!(day),
        };
      } else if (widget.datesLoader == null && widget.allEntriesLoader == null) {
        includeWater = true;
        waterByDate = {
          for (final day in weekDays)
            day: await FoodDatabase.instance.getWaterGlassesForDate(day),
        };
      }
    } catch (_) {
      waterByDate = {};
    }

    return (
      profile: profile,
      waterByDate: waterByDate,
      includeWater: includeWater,
    );
  }

  Future<void> _openDate(DateTime date) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => HistoryDayScreen(
          date: date,
          entriesLoader: widget.entriesLoader ??
              FoodDatabase.instance.getLogEntriesForDate,
        ),
      ),
    );
    if (mounted) await _loadHistory(showSpinner: false);
  }

  List<DateTime> _last7Days() {
    final today = DateTime(_now.year, _now.month, _now.day);
    return [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
  }

  List<DateTime> _journalDates() {
    final week = _last7Days().reversed.toList();
    final weekSet = week.toSet();
    return [
      ...week,
      for (final date in _dates)
        if (!weekSet.contains(date)) date,
    ];
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
          'History',
          style: AppStyle.navTitle,
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _HistoryStatusPane(
        message: 'Loading history...',
        loading: true,
      );
    }

    if (_error != null) {
      return _HistoryStatusPane(
        message: _error!,
        onRetry: _loadHistory,
      );
    }

    if (_dates.isEmpty) {
      return const _HistoryEmptyCard(
        title: 'No logged foods yet.',
        detail: 'Foods you log will appear here as a journal.',
      );
    }

    final journalDates = _journalDates();
    return ListView(
      padding: AppStyle.pagePadding,
      children: [
        _buildSevenDaySummary(),
        const SizedBox(height: 22),
        const Text(
          'Journal',
          style: AppStyle.sectionTitle,
        ),
        const SizedBox(height: 4),
        ..._journalChildren(journalDates),
      ],
    );
  }

  List<Widget> _journalChildren(List<DateTime> dates) {
    final children = <Widget>[];
    DateTime? previous;
    for (final date in dates) {
      final newMonth = previous == null ||
          previous.year != date.year ||
          previous.month != date.month;
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: previous == null ? 12 : (newMonth ? 22 : 12),
            bottom: newMonth ? 8 : 0,
          ),
          child: newMonth
              ? Text(
                  formatHistoryMonth(date),
                  style: AppStyle.fieldLabel.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
      children.add(_dateRow(date));
      previous = date;
    }
    return children;
  }

  Widget _buildSevenDaySummary() {
    final days = _last7Days();
    final insights = WeeklyInsights.from(
      days: days,
      entriesByDate: _entriesByDate,
      waterByDate: _waterByDate,
      profile: _profile,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _historyCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 days',
            style: AppStyle.sectionTitle,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryStat(
                  'Average calories',
                  insights.averageCalories == null
                      ? 'No data'
                      : '${_formatTotal(insights.averageCalories!)} kcal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryStat(
                  'Daily target',
                  insights.calorieTarget == null
                      ? 'No data'
                      : '${_formatTotal(insights.calorieTarget!.toDouble(), fractionDigits: 0)} kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow(
            'Days logged',
            '${insights.daysWithFood} / ${WeeklyInsights.windowDays}',
          ),
          const SizedBox(height: 8),
          Text(
            'Weekly averages',
            style: AppStyle.fieldLabel.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _summaryRow('Protein', _averageGrams(insights.averageProtein)),
          _summaryRow('Carbs', _averageGrams(insights.averageCarbohydrates)),
          _summaryRow('Fat', _averageGrams(insights.averageFats)),
          if (_includeWaterSummary) ...[
            const SizedBox(height: 4),
            _summaryRow(
              'Water logged',
              '${insights.daysWithWater} / ${WeeklyInsights.windowDays}',
            ),
          ],
        ],
      ),
    );
  }

  String _averageGrams(double? value) {
    if (value == null) return 'No data';
    return '${_formatGrams(value)} g';
  }

  Widget _summaryStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyle.meta,
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppStyle.body,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _dateRow(DateTime date) {
    final entries = _entriesByDate[date] ?? const <FoodLogEntry>[];
    final hasFood = entries.isNotEmpty;
    final totals = historyTotalsFor(entries);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _openDate(date),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: _historyCardDecoration,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatHistoryDayTitle(date, now: _now),
                    style: AppStyle.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatHistoryDaySubtitle(date),
                    style: AppStyle.fieldLabel,
                  ),
                  const SizedBox(height: 12),
                  if (hasFood) ...[
                    Text(
                      '${_formatTotal(totals.calories, fractionDigits: 0)} kcal',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatGrams(totals.protein)} g P  ·  '
                      '${_formatGrams(totals.carbohydrates)} g C  ·  '
                      '${_formatGrams(totals.fats)} g F',
                      style: AppStyle.meta,
                    ),
                  ] else
                    const Text(
                      'No food logged',
                      style: AppStyle.bodySecondary,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryDayScreen extends StatefulWidget {
  const HistoryDayScreen({
    super.key,
    required this.date,
    @visibleForTesting this.entriesLoader,
  });

  final DateTime date;
  final Future<List<FoodLogEntry>> Function(DateTime date)? entriesLoader;

  @override
  State<HistoryDayScreen> createState() => _HistoryDayScreenState();
}

class _HistoryDayScreenState extends State<HistoryDayScreen> {
  List<FoodLogEntry> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final loader =
          widget.entriesLoader ?? FoodDatabase.instance.getLogEntriesForDate;
      final entries = await loader(widget.date);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Couldn\'t load this day.';
      });
    }
  }

  Future<void> _deleteEntry(FoodLogEntry entry) async {
    final id = entry.id;
    if (id == null) return;

    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete food?'),
        content: Text(
          'Remove ${_clippedHistoryName(entry.food.name)} from this day\'s log?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await FoodDatabase.instance.deleteLogEntry(id);
      await _loadEntries();
    } catch (_) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Could not delete food.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.chrome,
        border: AppStyle.navBorder,
        leading: AppStyle.backButton(
          context,
          previousPageTitle: 'History',
        ),
        middle: Text(
          formatHistoryDate(widget.date),
          style: AppStyle.navTitle,
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _HistoryStatusPane(
        message: 'Loading this day...',
        loading: true,
      );
    }

    if (_error != null) {
      return _HistoryStatusPane(
        message: _error!,
        onRetry: _loadEntries,
      );
    }

    if (_entries.isEmpty) {
      return const _HistoryEmptyCard(
        title: 'No food logged',
        detail: 'Nothing was saved for this day.',
      );
    }

    final totals = historyTotalsFor(_entries);
    final sections = mealSections(_entries);

    return ListView(
      padding: AppStyle.pagePadding,
      children: [
        _daySummary(totals),
        for (var i = 0; i < sections.length; i++) ...[
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 24 : 28, bottom: 10),
            child: Text(
              mealLabel(sections[i].key),
              style: AppStyle.subsectionTitle,
            ),
          ),
          for (final entry in sections[i].value) _foodRow(entry),
        ],
      ],
    );
  }

  Widget _daySummary(HistoryDayTotals totals) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _historyCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calories',
            style: AppStyle.fieldLabel,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatTotal(totals.calories, fractionDigits: 0),
              maxLines: 1,
              style: AppStyle.heroValue,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'kcal',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _macroStat('Protein', _formatGrams(totals.protein)),
              _macroStat('Carbs', _formatGrams(totals.carbohydrates)),
              _macroStat('Fat', _formatGrams(totals.fats)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Text(
            'g',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodRow(FoodLogEntry entry) {
    final servingsLabel = entry.servings == 1
        ? '1 serving'
        : '${entry.servings.toStringAsFixed(0)} servings';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: AppStyle.foodRowPadding,
        decoration: _historyCardDecoration,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    servingsLabel,
                    style: AppStyle.meta,
                  ),
                ],
              ),
            ),
            AppStyle.iconAction(
              icon: CupertinoIcons.delete,
              onPressed: () => _deleteEntry(entry),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryDayTotals {
  const HistoryDayTotals({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
  });

  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
}

/// Same per-entry servings math used by HomeScreen.
HistoryDayTotals historyTotalsFor(List<FoodLogEntry> entries) {
  var calories = 0.0;
  var protein = 0.0;
  var carbohydrates = 0.0;
  var fats = 0.0;
  for (final entry in entries) {
    final servings = entry.servings;
    calories += entry.food.calories * servings;
    protein += entry.food.protein * servings;
    carbohydrates += entry.food.carbohydrates * servings;
    fats += entry.food.fats * servings;
  }
  return HistoryDayTotals(
    calories: calories,
    protein: protein,
    carbohydrates: carbohydrates,
    fats: fats,
  );
}

String formatHistoryDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';

  return '${_historyWeekdays[day.weekday - 1]}, ${_historyShortMonths[day.month - 1]} ${day.day}, ${day.year}';
}

String formatHistoryDayTitle(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return _historyWeekdays[day.weekday - 1];
}

String formatHistoryDaySubtitle(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return '${_historyShortMonths[day.month - 1]} ${day.day}, ${day.year}';
}

String formatHistoryMonth(DateTime date) {
  return '${_historyMonths[date.month - 1]} ${date.year}';
}

const _historyWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _historyShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _historyMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _HistoryStatusPane extends StatelessWidget {
  const _HistoryStatusPane({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CupertinoActivityIndicator(),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppStyle.bodySecondary,
            ),
            if (onRetry != null)
              CupertinoButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: AppStyle.accentAction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          decoration: _historyCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppStyle.sectionTitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: AppStyle.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _clippedHistoryName(String name, {int maxChars = 80}) {
  if (name.length <= maxChars) return name;
  return '${name.substring(0, maxChars).trimRight()}…';
}

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

const _historyCardDecoration = AppStyle.card;
