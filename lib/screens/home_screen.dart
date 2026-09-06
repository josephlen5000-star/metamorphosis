import 'package:flutter/cupertino.dart';

import '../models/food_item.dart';
import '../models/food_log_entry.dart';
import '../models/meal.dart';
import '../models/recipe.dart';
import '../models/saved_meal.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../services/food_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/diet_plate.dart';
import '../widgets/food_search_popup.dart';
import '../widgets/top_title_bar.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FoodLogEntry>? _todaysEntries;
  bool? _isLoadingEntries = true;
  User? _profile;
  bool? _profileLoadAttempted;
  int _todaysWater = 0;

  @override
  void initState() {
    super.initState();
    _todaysEntries = [];
    _isLoadingEntries = true;
    _loadTodaysEntries();
    _loadTodaysWater();
    _loadProfile();
  }

  @override
  void reassemble() {
    super.reassemble();
    _profileLoadAttempted = false;
    _loadProfile();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ProfileScreen(),
      ),
    );
    if (!mounted) return;
    await _loadProfile(force: true);
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ProgressScreen(),
      ),
    );
  }

  Future<void> _loadProfile({bool force = false}) async {
    if (!force && _profileLoadAttempted == true) return;
    _profileLoadAttempted = true;
    try {
      final profile = await FirebaseService().getUserProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profile = null);
    }
  }

  Future<void> _loadTodaysEntries() async {
    try {
      final entries = await FoodDatabase.instance.getLogEntriesForDate(
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _todaysEntries = entries;
        _isLoadingEntries = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingEntries = false);
      _showErrorDialog('Couldn\'t load today\'s foods.');
    }
  }

  Future<void> _loadTodaysWater() async {
    try {
      final glasses = await FoodDatabase.instance.getWaterGlassesForDate(
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _todaysWater = glasses);
    } catch (_) {
      if (!mounted) return;
      setState(() => _todaysWater = 0);
    }
  }

  Future<void> _setTodaysWater(int glasses) async {
    try {
      await FoodDatabase.instance.setWaterGlassesForDate(
        DateTime.now(),
        glasses,
      );
      if (!mounted) return;
      await _loadTodaysWater();
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Couldn\'t save water.');
    }
  }

  Future<void> _openFoodSearchPopup() async {
    final result = await showCupertinoModalPopup<FoodPickerResult>(
      context: context,
      builder: (_) => const FoodSearchPopup(),
    );
    if (!mounted || result == null) return;

    switch (result) {
      case PickedFood(:final food):
        await _logPickedFood(food);
      case PickedSavedMeal(:final meal):
        await _logSavedMeal(meal);
      case PickedRecipe(:final recipe):
        await _logRecipe(recipe);
    }
  }

  Future<void> _logPickedFood(FoodItem food) async {
    final choice = await _confirmServings(food);
    if (!mounted || choice == null) return;

    try {
      await FoodDatabase.instance.insertLogEntry(
        FoodLogEntry(
          food: food,
          servings: choice.servings,
          loggedAt: DateTime.now(),
          meal: choice.meal,
        ),
      );
      await _loadTodaysEntries();
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Couldn\'t save food.');
    }
  }

  Future<void> _logSavedMeal(SavedMeal meal) async {
    if (meal.items.isEmpty) {
      _showErrorDialog('This meal has no foods.');
      return;
    }

    final choice = await _confirmSavedMeal(meal);
    if (!mounted || choice == null) return;

    try {
      final loggedAt = DateTime.now();
      for (final entry in meal.toLogEntries(
        loggedAt: loggedAt,
        meal: choice.meal,
      )) {
        await FoodDatabase.instance.insertLogEntry(entry);
      }
      await _loadTodaysEntries();
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Couldn\'t save meal.');
    }
  }

  Future<void> _saveAsMeal() async {
    final entries = _todaysEntries ?? const <FoodLogEntry>[];
    if (entries.isEmpty) return;

    final selected = List<bool>.filled(entries.length, true);
    final nameController = TextEditingController(
      text: _defaultSavedMealName(entries),
    );

    final shouldSave = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('Save as meal'),
              content: Column(
                children: [
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'Meal name',
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const Text('Foods to include'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: entries.length > 4 ? 180 : null,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            GestureDetector(
                              onTap: () => setDialogState(() {
                                selected[i] = !selected[i];
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected[i]
                                          ? CupertinoIcons
                                              .check_mark_circled_solid
                                          : CupertinoIcons.circle,
                                      size: 20,
                                      color: selected[i]
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${entries[i].food.name} · ${_servingsLabel(entries[i].servings)}',
                                        textAlign: TextAlign.left,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final name = nameController.text.trim();
    nameController.dispose();
    if (shouldSave != true || !mounted) return;

    final items = [
      for (var i = 0; i < entries.length; i++)
        if (selected[i])
          SavedMealItem(food: entries[i].food, servings: entries[i].servings),
    ];
    if (name.isEmpty || items.isEmpty) {
      _showErrorDialog('Choose a name and at least one food.');
      return;
    }

    try {
      await FoodDatabase.instance.insertSavedMeal(
        SavedMeal(
          name: name,
          items: items,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Couldn\'t save meal.');
    }
  }

  String _defaultSavedMealName(List<FoodLogEntry> entries) {
    final meals = {for (final entry in entries) normalizeMeal(entry.meal)};
    if (meals.length == 1 && meals.single != mealOther) {
      return 'My ${mealLabel(meals.single)}';
    }
    return 'My Meal';
  }

  String _servingsLabel(double servings) {
    if (servings == 1) return '1 serving';
    final rounded = servings.round();
    return '$rounded servings';
  }

  String _clippedName(String name, {int maxChars = 80}) {
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars).trimRight()}…';
  }

  Future<void> _deleteEntry(FoodLogEntry entry) async {
    final id = entry.id;
    if (id == null) return;

    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete food?'),
        content: Text(
          'Remove ${_clippedName(entry.food.name)} from today\'s log?',
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
      await _loadTodaysEntries();
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Couldn\'t delete food.');
    }
  }

  Future<_LogChoice?> _confirmServings(FoodItem food) {
    var servings = 1.0;
    var meal = suggestedMealFor(DateTime.now());

    return showCupertinoDialog<_LogChoice>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(
                food.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              content: Column(
                children: [
                  const SizedBox(height: 12),
                  const Text('How many servings?'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: servings <= 1
                            ? null
                            : () => setDialogState(() => servings -= 1),
                        child: const Icon(CupertinoIcons.minus),
                      ),
                      Text(
                        servings.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: servings >= 99
                            ? null
                            : () => setDialogState(() => servings += 1),
                        child: const Icon(CupertinoIcons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Meal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _mealChips(
                    meal,
                    onChanged: (value) => setDialogState(() => meal = value),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _LogChoice(servings: servings, meal: meal),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logRecipe(Recipe recipe) async {
    if (recipe.items.isEmpty) {
      _showErrorDialog('This recipe has no foods.');
      return;
    }

    final choice = await _confirmRecipe(recipe);
    if (!mounted || choice == null) return;

    try {
      final loggedAt = DateTime.now();
      for (final entry in recipe.toLogEntries(
        loggedAt: loggedAt,
        meal: choice.meal,
      )) {
        await FoodDatabase.instance.insertLogEntry(entry);
      }
      await _loadTodaysEntries();
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Couldn\'t save recipe.');
    }
  }

  Future<_LogChoice?> _confirmSavedMeal(SavedMeal meal) {
    return _confirmMultiItemLog(
      name: meal.name,
      items: [
        for (final item in meal.items)
          (name: item.food.name, servings: item.servings),
      ],
    );
  }

  Future<_LogChoice?> _confirmRecipe(Recipe recipe) {
    return _confirmMultiItemLog(
      name: recipe.name,
      items: [
        for (final item in recipe.items)
          (name: item.food.name, servings: item.servings),
      ],
      nutritionSummary:
          '${recipe.calories.round()} kcal · ${_formatGrams(recipe.protein)}g P · ${_formatGrams(recipe.carbohydrates)}g C · ${_formatGrams(recipe.fats)}g F',
    );
  }

  Future<_LogChoice?> _confirmMultiItemLog({
    required String name,
    required List<({String name, double servings})> items,
    String? nutritionSummary,
  }) {
    var selectedMeal = suggestedMealFor(DateTime.now());

    return showCupertinoDialog<_LogChoice>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              content: Column(
                children: [
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: items.length > 4 ? 160 : null,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${item.name} · ${_servingsLabel(item.servings)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (nutritionSummary != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        nutritionSummary,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Meal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _mealChips(
                    selectedMeal,
                    onChanged: (value) => setDialogState(
                      () => selectedMeal = value,
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _LogChoice(servings: 1, meal: selectedMeal),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _mealChips(
    String meal, {
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final value in mealValues)
          GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: meal == value
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : AppColors.progressTrack,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: meal == value
                      ? AppColors.accent
                      : AppColors.toolbarDivider,
                ),
              ),
              child: Text(
                mealLabel(value),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: meal == value
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  _NutritionTotals _totalsFor(List<FoodLogEntry> entries) {
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
    return _NutritionTotals(
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fats: fats,
    );
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

  Widget _buildTodaysTotals(List<FoodLogEntry> entries) {
    if (_profile == null && _profileLoadAttempted != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfile();
      });
    }
    final totals = _totalsFor(entries);
    final target = _profile?.calorieTarget;
    final remaining = target == null ? null : target - totals.calories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _heroTile(
                  label: 'Calories',
                  value: _formatTotal(totals.calories, fractionDigits: 0),
                  unit: 'kcal',
                ),
              ),
              if (remaining != null && target != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _remainingTile(
                    remaining: remaining,
                    eaten: totals.calories,
                    target: target,
                  ),
                ),
              ],
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 8),
            Text(
              'Daily target  ${_formatTotal(target.toDouble(), fractionDigits: 0)} kcal',
              style: AppStyle.fieldLabel,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _macroTile(
                'Protein',
                _formatGrams(totals.protein),
                eaten: totals.protein,
                goal: _profile?.proteinGoal,
              ),
              const SizedBox(width: 8),
              _macroTile(
                'Carbs',
                _formatGrams(totals.carbohydrates),
                eaten: totals.carbohydrates,
                goal: _profile?.carbohydrateGoal,
              ),
              const SizedBox(width: 8),
              _macroTile(
                'Fats',
                _formatGrams(totals.fats),
                eaten: totals.fats,
                goal: _profile?.fatGoal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTile({
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppStyle.fieldLabel,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppStyle.heroValue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _remainingTile({
    required double remaining,
    required double eaten,
    required int target,
  }) {
    final progress = target <= 0 ? 0.0 : (eaten / target).clamp(0.0, 1.0);
    final over = remaining < 0;
    final valueColor = over ? AppColors.progressOver : AppColors.textPrimary;
    final barColor = over ? AppColors.progressOver : AppColors.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Remaining',
            style: AppStyle.fieldLabel,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatTotal(remaining, fractionDigits: 0),
              maxLines: 1,
              style: AppStyle.heroValue.copyWith(color: valueColor),
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
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
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
                        color: barColor,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroTile(
    String label,
    String value, {
    double? eaten,
    double? goal,
  }) {
    final hasGoal = goal != null && goal > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: _cardDecoration,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasGoal ? '$value / ${_formatGrams(goal)}' : value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              hasGoal ? 'g goal' : 'g',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasGoal && eaten != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 4,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = (eaten / goal).clamp(0.0, 1.0);
                      final over = eaten > goal;
                      return Stack(
                        children: [
                          const ColoredBox(
                            color: AppColors.progressTrack,
                            child: SizedBox.expand(),
                          ),
                          Container(
                            width: constraints.maxWidth * progress,
                            color: over
                                ? AppColors.progressOver
                                : AppColors.accent,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => AppStyle.card;

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysFoodLog() {
    if (_isLoadingEntries ?? true) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final entries = _todaysEntries ?? const <FoodLogEntry>[];
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Text(
          'No foods logged today.',
          style: AppStyle.bodySecondary,
        ),
      );
    }

    final sections = mealSections(entries);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 8 : 22, bottom: 12),
              child: Text(
                mealLabel(sections[i].key),
                style: AppStyle.subsectionTitle,
              ),
            ),
            for (final entry in sections[i].value) _foodLogRow(entry),
          ],
        ],
      ),
    );
  }

  Widget _foodLogRow(FoodLogEntry entry) {
    final servingsLabel = _servingsLabel(entry.servings);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: AppStyle.foodRowPadding,
        decoration: _cardDecoration,
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

  int get _waterGoal => _profile?.dailyWaterGoal ?? User.defaultWaterGoal;

  String _glassesLabel(int glasses) {
    return glasses == 1 ? '1 glass' : '$glasses glasses';
  }

  Widget _buildWaterSection() {
    final consumed = _todaysWater;
    final goal = _waterGoal;
    final progress = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final over = consumed > goal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Water',
              style: AppStyle.fieldLabel,
            ),
            const SizedBox(height: 6),
            Text(
              '$consumed / $goal glasses',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 6,
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
                          color: over
                              ? AppColors.progressOver
                              : AppColors.accent,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  onPressed: _addWater,
                  child: const Text(
                    '+ Add water',
                    style: AppStyle.accentAction,
                  ),
                ),
                if (consumed > 0)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    onPressed: () => _setTodaysWater(consumed - 1),
                    child: const Text(
                      'Remove 1',
                      style: TextStyle(
                        fontSize: 14,
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
    );
  }

  Future<void> _addWater() async {
    final choice = await showCupertinoDialog<int>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Add water'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('How many glasses?'),
          ),
          actions: [
            for (final glasses in const [1, 2, 3])
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(glasses),
                child: Text(_glassesLabel(glasses)),
              ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(-1),
              child: const Text('Custom'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (!mounted || choice == null) return;

    if (choice == -1) {
      await _addCustomWater();
      return;
    }

    await _setTodaysWater(_todaysWater + choice);
  }

  Future<void> _addCustomWater() async {
    final controller = TextEditingController();
    final raw = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Custom amount'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              placeholder: 'Glasses',
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim(),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || raw == null) return;

    final glasses = int.tryParse(raw);
    if (glasses == null || glasses <= 0) {
      _showErrorDialog('Enter a valid number of glasses.');
      return;
    }
    await _setTodaysWater(_todaysWater + glasses);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: TopTitleBar(
        onProfilePressed: _openProfile,
        onHistoryPressed: _openHistory,
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final plateHeight =
                (constraints.maxHeight * 0.44).clamp(236.0, 318.0);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: plateHeight,
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DietPlate(
                        onAddPressed: _openFoodSearchPopup,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Today',
                            style: AppStyle.pageTitle,
                          ),
                        ),
                        if ((_todaysEntries ?? const <FoodLogEntry>[])
                            .isNotEmpty)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            onPressed: _saveAsMeal,
                            child: const Text(
                              'Save as meal',
                              style: AppStyle.accentAction,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildTodaysTotals(
                    _todaysEntries ?? const <FoodLogEntry>[],
                  ),
                ),
                SliverToBoxAdapter(child: _buildTodaysFoodLog()),
                SliverToBoxAdapter(child: _buildWaterSection()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogChoice {
  const _LogChoice({required this.servings, required this.meal});

  final double servings;
  final String meal;
}

class _NutritionTotals {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;

  const _NutritionTotals({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
  });
}
