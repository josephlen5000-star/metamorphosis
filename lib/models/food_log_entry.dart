import 'food_item.dart';

class FoodLogEntry {
  final int? id;
  final FoodItem food;
  final double servings;
  final DateTime loggedAt;
  final String? meal;

  FoodLogEntry({
    this.id,
    required this.food,
    required this.servings,
    required this.loggedAt,
    this.meal,
  });

  factory FoodLogEntry.fromMap(Map<String, dynamic> map) {
    return FoodLogEntry(
      id: map['id'] as int?,
      food: FoodItem(
        id: map['foodId'] as int?,
        name: map['name'] as String,
        calories: map['calories'] as int,
        protein: (map['protein'] as num).toDouble(),
        carbohydrates: (map['carbohydrates'] as num).toDouble(),
        fats: (map['fats'] as num).toDouble(),
        omega6: (map['omega6'] as num).toDouble(),
        omega3: (map['omega3'] as num).toDouble(),
      ),
      servings: (map['servings'] as num).toDouble(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(map['loggedAt'] as int),
      meal: map['meal'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'foodId': food.id,
      'name': food.name,
      'calories': food.calories,
      'protein': food.protein,
      'carbohydrates': food.carbohydrates,
      'fats': food.fats,
      'omega6': food.omega6,
      'omega3': food.omega3,
      'servings': servings,
      'loggedAt': loggedAt.millisecondsSinceEpoch,
      if (meal != null && meal!.isNotEmpty) 'meal': meal,
    };
  }
}
