import 'package:flutter_test/flutter_test.dart';
import 'package:metamorphosis/models/food_item.dart';
import 'package:metamorphosis/models/food_log_entry.dart';
import 'package:metamorphosis/models/meal.dart';
import 'package:metamorphosis/models/saved_meal.dart';
import 'package:metamorphosis/models/user.dart';
import 'package:metamorphosis/services/food_database.dart';

FoodItem _food({int? id = 1, String name = 'Apple'}) {
  return FoodItem(
    id: id,
    name: name,
    calories: 95,
    protein: 0.5,
    carbohydrates: 25,
    fats: 0.3,
    omega6: 0.01,
    omega3: 0.03,
  );
}

void main() {
  test('legacy log rows without meal stay readable as Other', () {
    final entry = FoodLogEntry.fromMap({
      'id': 3,
      'foodId': 10,
      'name': 'Apple',
      'calories': 95,
      'protein': 0.5,
      'carbohydrates': 25,
      'fats': 0.3,
      'omega6': 0.01,
      'omega3': 0.03,
      'servings': 1,
      'loggedAt': DateTime(2026, 9, 1).millisecondsSinceEpoch,
    });

    expect(entry.meal, isNull);
    expect(normalizeMeal(entry.meal), mealOther);
    expect(entry.toMap().containsKey('meal'), isFalse);
    expect(entry.food.calories, 95);
  });

  test('meal sections keep Breakfast before Other', () {
    final sections = mealSections([
      FoodLogEntry(
        food: _food(name: 'Yogurt'),
        servings: 1,
        loggedAt: DateTime(2026, 9, 5, 21),
      ),
      FoodLogEntry(
        food: _food(id: 2, name: 'Eggs'),
        servings: 1,
        loggedAt: DateTime(2026, 9, 5, 8),
        meal: mealBreakfast,
      ),
    ]);

    expect(sections.map((section) => section.key).toList(), [
      mealBreakfast,
      mealOther,
    ]);
    expect(sections.first.value.single.food.name, 'Eggs');
  });

  test('Mifflin calorie target remains the default until a custom goal is set', () {
    final user = User(
      userId: 'u1',
      username: 'Ada',
      age: 25,
      biologicalSex: 'female',
      heightCm: 165,
      weightKg: 60,
      activityLevel: 'sedentary',
      useMetric: true,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(user.calorieTarget, user.dailyCalorieTarget);

    final custom = User(
      userId: 'u1',
      username: 'Ada',
      age: 25,
      biologicalSex: 'female',
      heightCm: 165,
      weightKg: 60,
      activityLevel: 'sedentary',
      useMetric: true,
      createdAt: DateTime(2026, 1, 1),
      customCalorieTarget: 2100,
      proteinGoal: 140,
    );

    expect(custom.dailyCalorieTarget, user.dailyCalorieTarget);
    expect(custom.calorieTarget, 2100);
    expect(custom.proteinGoal, 140);
    expect(custom.carbohydrateGoal, isNull);
  });

  test('User.fromMap accepts profiles that predate nutrition goals', () {
    final user = User.fromMap({
      'userId': 'u1',
      'username': 'Ada',
      'age': 25,
      'biologicalSex': 'female',
      'heightCm': 165,
      'weightKg': 60,
      'activityLevel': 'sedentary',
      'useMetric': true,
      'createdAt': DateTime(2026, 1, 1),
    });

    expect(user.customCalorieTarget, isNull);
    expect(user.proteinGoal, isNull);
    expect(user.calorieTarget, user.dailyCalorieTarget);
    expect(user.waterGoal, isNull);
    expect(user.dailyWaterGoal, User.defaultWaterGoal);
  });

  test('water goal defaults to 8 glasses until a custom goal is set', () {
    final user = User(
      userId: 'u1',
      username: 'Ada',
      age: 25,
      biologicalSex: 'female',
      heightCm: 165,
      weightKg: 60,
      activityLevel: 'sedentary',
      useMetric: true,
      createdAt: DateTime(2026, 1, 1),
      waterGoal: 10,
    );

    expect(user.dailyWaterGoal, 10);
    expect(user.calorieTarget, user.dailyCalorieTarget);
  });

  test('water date keys are calendar days, not clock times', () {
    final morning = DateTime(2026, 9, 5, 8, 15);
    final night = DateTime(2026, 9, 5, 22, 40);
    final nextDay = DateTime(2026, 9, 6, 0, 5);

    expect(FoodDatabase.waterDateKey(morning), FoodDatabase.waterDateKey(night));
    expect(
      FoodDatabase.waterDateKey(morning),
      isNot(FoodDatabase.waterDateKey(nextDay)),
    );
  });

  test('saved meals serialize without inventing recipe nutrition', () {
    final meal = SavedMeal(
      id: 4,
      name: 'Protein Smoothie',
      createdAt: DateTime(2026, 9, 5, 8),
      items: [
        SavedMealItem(food: _food(id: 10, name: 'Milk'), servings: 2),
        SavedMealItem(food: _food(id: 11, name: 'Banana'), servings: 1),
      ],
    );

    final restored = SavedMeal.fromMap(meal.toMap());
    expect(restored.id, 4);
    expect(restored.name, 'Protein Smoothie');
    expect(restored.items.map((item) => item.food.id).toList(), [10, 11]);
    expect(restored.items.first.servings, 2);
    expect(restored.calories, 95 * 2 + 95);
    expect(restored.protein, 0.5 * 2 + 0.5);
  });

  test('saved meals log as existing FoodItem times servings', () {
    final meal = SavedMeal(
      name: 'My Breakfast',
      createdAt: DateTime(2026, 9, 5, 8),
      items: [
        SavedMealItem(food: _food(name: 'Eggs'), servings: 2),
        SavedMealItem(food: _food(id: 2, name: 'Toast'), servings: 1),
      ],
    );

    final entries = meal.toLogEntries(
      loggedAt: DateTime(2026, 9, 5, 8, 15),
      meal: mealBreakfast,
    );

    expect(entries.length, 2);
    expect(entries.first.food.name, 'Eggs');
    expect(entries.first.servings, 2);
    expect(entries.first.meal, mealBreakfast);
    expect(entries.first.food.calories * entries.first.servings, 190);
    expect(entries.last.food.calories * entries.last.servings, 95);
  });
}
