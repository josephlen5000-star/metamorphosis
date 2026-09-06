import 'food_item.dart';
import 'food_log_entry.dart';

/// One food inside a saved meal template, with the servings to log.
class SavedMealItem {
  final FoodItem food;
  final double servings;

  const SavedMealItem({
    required this.food,
    required this.servings,
  });

  factory SavedMealItem.fromMap(Map<String, dynamic> map) {
    return SavedMealItem(
      food: FoodItem(
        id: (map['foodId'] as num?)?.toInt(),
        name: map['name'] as String,
        calories: (map['calories'] as num).toInt(),
        protein: (map['protein'] as num).toDouble(),
        carbohydrates: (map['carbohydrates'] as num).toDouble(),
        fats: (map['fats'] as num).toDouble(),
        omega6: (map['omega6'] as num).toDouble(),
        omega3: (map['omega3'] as num).toDouble(),
      ),
      servings: (map['servings'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap({int? mealId}) {
    return {
      'mealId': ?mealId,
      'foodId': food.id,
      'name': food.name,
      'calories': food.calories,
      'protein': food.protein,
      'carbohydrates': food.carbohydrates,
      'fats': food.fats,
      'omega6': food.omega6,
      'omega3': food.omega3,
      'servings': servings,
    };
  }
}

/// A named reusable combination of existing [FoodItem]s and servings.
class SavedMeal {
  final int? id;
  final String name;
  final List<SavedMealItem> items;
  final DateTime createdAt;

  const SavedMeal({
    this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  factory SavedMeal.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = <SavedMealItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(SavedMealItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SavedMeal(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      items: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num).toInt(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': ?id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'items': [for (final item in items) item.toMap()],
    };
  }

  SavedMeal copyWith({
    int? id,
    String? name,
    List<SavedMealItem>? items,
    DateTime? createdAt,
  }) {
    return SavedMeal(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Logs this template as individual [FoodLogEntry]s using FoodItem × servings.
  List<FoodLogEntry> toLogEntries({
    required DateTime loggedAt,
    required String meal,
  }) {
    return [
      for (final item in items)
        FoodLogEntry(
          food: item.food,
          servings: item.servings,
          loggedAt: loggedAt,
          meal: meal,
        ),
    ];
  }

  double get calories {
    return items.fold<double>(
      0,
      (sum, item) => sum + item.food.calories * item.servings,
    );
  }

  double get protein {
    return items.fold<double>(
      0,
      (sum, item) => sum + item.food.protein * item.servings,
    );
  }

  double get carbohydrates {
    return items.fold<double>(
      0,
      (sum, item) => sum + item.food.carbohydrates * item.servings,
    );
  }

  double get fats {
    return items.fold<double>(
      0,
      (sum, item) => sum + item.food.fats * item.servings,
    );
  }
}
