import '../screens/history_screen.dart';
import 'food_log_entry.dart';
import 'user.dart';

/// 7-day Progress summary built only from stored food and water logs.
class WeeklyInsights {
  const WeeklyInsights({
    required this.daysWithFood,
    required this.daysWithWater,
    required this.daysBelowCalorieTarget,
    required this.averageCalories,
    required this.calorieTarget,
    required this.averageProtein,
    required this.averageCarbohydrates,
    required this.averageFats,
    required this.proteinGoal,
    required this.carbohydrateGoal,
    required this.fatGoal,
    required this.averageWater,
    required this.waterGoal,
    required this.observations,
  });

  final int daysWithFood;
  final int daysWithWater;
  final int daysBelowCalorieTarget;
  final double? averageCalories;
  final int? calorieTarget;
  final double? averageProtein;
  final double? averageCarbohydrates;
  final double? averageFats;
  final double? proteinGoal;
  final double? carbohydrateGoal;
  final double? fatGoal;
  final double? averageWater;
  final int waterGoal;
  final List<String> observations;

  static const windowDays = 7;

  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Averages use days that have stored data. Missing days are omitted.
  factory WeeklyInsights.from({
    required List<DateTime> days,
    required Map<DateTime, List<FoodLogEntry>> entriesByDate,
    required Map<DateTime, int> waterByDate,
    User? profile,
  }) {
    final foodDays = <DateTime>[];
    final waterDays = <DateTime>[];
    var calorieSum = 0.0;
    var proteinSum = 0.0;
    var carbSum = 0.0;
    var fatSum = 0.0;
    var daysBelowTarget = 0;
    var waterSum = 0;
    final target = profile?.calorieTarget;

    for (final day in days) {
      final key = dayOf(day);
      final entries = entriesByDate[key] ?? const <FoodLogEntry>[];
      if (entries.isNotEmpty) {
        foodDays.add(key);
        final totals = historyTotalsFor(entries);
        calorieSum += totals.calories;
        proteinSum += totals.protein;
        carbSum += totals.carbohydrates;
        fatSum += totals.fats;
        if (target != null && totals.calories < target) {
          daysBelowTarget++;
        }
      }

      final glasses = waterByDate[key] ?? 0;
      if (glasses > 0) {
        waterDays.add(key);
        waterSum += glasses;
      }
    }

    final foodCount = foodDays.length;
    final waterCount = waterDays.length;

    final insights = WeeklyInsights(
      daysWithFood: foodCount,
      daysWithWater: waterCount,
      daysBelowCalorieTarget: daysBelowTarget,
      averageCalories: foodCount == 0 ? null : calorieSum / foodCount,
      calorieTarget: target,
      averageProtein: foodCount == 0 ? null : proteinSum / foodCount,
      averageCarbohydrates: foodCount == 0 ? null : carbSum / foodCount,
      averageFats: foodCount == 0 ? null : fatSum / foodCount,
      proteinGoal: profile?.proteinGoal,
      carbohydrateGoal: profile?.carbohydrateGoal,
      fatGoal: profile?.fatGoal,
      averageWater: waterCount == 0 ? null : waterSum / waterCount,
      waterGoal: profile?.dailyWaterGoal ?? User.defaultWaterGoal,
      observations: const [],
    );

    return WeeklyInsights(
      daysWithFood: insights.daysWithFood,
      daysWithWater: insights.daysWithWater,
      daysBelowCalorieTarget: insights.daysBelowCalorieTarget,
      averageCalories: insights.averageCalories,
      calorieTarget: insights.calorieTarget,
      averageProtein: insights.averageProtein,
      averageCarbohydrates: insights.averageCarbohydrates,
      averageFats: insights.averageFats,
      proteinGoal: insights.proteinGoal,
      carbohydrateGoal: insights.carbohydrateGoal,
      fatGoal: insights.fatGoal,
      averageWater: insights.averageWater,
      waterGoal: insights.waterGoal,
      observations: weeklyInsightObservations(insights),
    );
  }
}

List<String> weeklyInsightObservations(WeeklyInsights insights) {
  final notes = <String>[
    'You logged food on ${insights.daysWithFood} of the last 7 days.',
  ];

  final averageCalories = insights.averageCalories;
  final target = insights.calorieTarget;
  if (averageCalories != null && target != null) {
    if (averageCalories < target) {
      notes.add('Your average calorie intake was below your daily target.');
    } else if (averageCalories > target) {
      notes.add('Your average calorie intake was above your daily target.');
    } else {
      notes.add('Your average calorie intake matched your daily target.');
    }
  }

  final averageWater = insights.averageWater;
  if (averageWater != null) {
    notes.add(
      'You averaged ${formatInsightNumber(averageWater)} glasses of water per day.',
    );
  } else if (notes.length < 3) {
    notes.add(
      'You logged water on ${insights.daysWithWater} of the last 7 days.',
    );
  }

  return notes.take(3).toList();
}

String formatInsightNumber(double value, {int fractionDigits = 1}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(fractionDigits);
}

