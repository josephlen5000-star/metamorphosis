import 'food_log_entry.dart';

const mealBreakfast = 'breakfast';
const mealLunch = 'lunch';
const mealDinner = 'dinner';
const mealSnack = 'snack';
const mealOther = 'other';

const mealValues = [mealBreakfast, mealLunch, mealDinner, mealSnack];
const mealDisplayOrder = [
  mealBreakfast,
  mealLunch,
  mealDinner,
  mealSnack,
  mealOther,
];

String normalizeMeal(String? meal) {
  switch (meal?.toLowerCase()) {
    case mealBreakfast:
    case mealLunch:
    case mealDinner:
    case mealSnack:
      return meal!.toLowerCase();
    default:
      return mealOther;
  }
}

String mealLabel(String? meal) {
  switch (normalizeMeal(meal)) {
    case mealBreakfast:
      return 'Breakfast';
    case mealLunch:
      return 'Lunch';
    case mealDinner:
      return 'Dinner';
    case mealSnack:
      return 'Snack';
    default:
      return 'Other';
  }
}

String suggestedMealFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 11) return mealBreakfast;
  if (hour >= 11 && hour < 16) return mealLunch;
  if (hour >= 16 && hour < 21) return mealDinner;
  return mealSnack;
}

Map<String, List<FoodLogEntry>> groupEntriesByMeal(List<FoodLogEntry> entries) {
  final grouped = <String, List<FoodLogEntry>>{
    for (final meal in mealDisplayOrder) meal: <FoodLogEntry>[],
  };
  for (final entry in entries) {
    grouped[normalizeMeal(entry.meal)]!.add(entry);
  }
  return grouped;
}

List<MapEntry<String, List<FoodLogEntry>>> mealSections(
  List<FoodLogEntry> entries,
) {
  final grouped = groupEntriesByMeal(entries);
  return [
    for (final meal in mealDisplayOrder)
      if (grouped[meal]!.isNotEmpty) MapEntry(meal, grouped[meal]!),
  ];
}
