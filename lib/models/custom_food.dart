import 'food_item.dart';

/// Parsed custom-food form values. Nutrition is per 1 serving.
class CustomFoodInput {
  const CustomFoodInput({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
  });

  final String name;
  final int calories;
  final double protein;
  final double carbohydrates;
  final double fats;

  FoodItem toFoodItem({int? id}) {
    return FoodItem(
      id: id,
      name: name,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fats: fats,
      omega6: 0,
      omega3: 0,
    );
  }

  /// Validates a custom-food form. Empty nutrition fields count as 0.
  static CustomFoodParseResult parse({
    required String name,
    required String calories,
    required String protein,
    required String carbohydrates,
    required String fats,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const CustomFoodParseResult(
        error: 'Enter a food name.',
      );
    }

    final parsedCalories = _parseNonNegative(calories, label: 'Calories');
    if (parsedCalories.error != null) {
      return CustomFoodParseResult(error: parsedCalories.error);
    }
    final parsedProtein = _parseNonNegative(protein, label: 'Protein');
    if (parsedProtein.error != null) {
      return CustomFoodParseResult(error: parsedProtein.error);
    }
    final parsedCarbs = _parseNonNegative(carbohydrates, label: 'Carbs');
    if (parsedCarbs.error != null) {
      return CustomFoodParseResult(error: parsedCarbs.error);
    }
    final parsedFats = _parseNonNegative(fats, label: 'Fat');
    if (parsedFats.error != null) {
      return CustomFoodParseResult(error: parsedFats.error);
    }

    return CustomFoodParseResult(
      value: CustomFoodInput(
        name: trimmedName,
        calories: parsedCalories.value!.round(),
        protein: parsedProtein.value!,
        carbohydrates: parsedCarbs.value!,
        fats: parsedFats.value!,
      ),
    );
  }

  static ({double? value, String? error}) _parseNonNegative(
    String raw, {
    required String label,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return (value: 0, error: null);

    final value = double.tryParse(text);
    if (value == null || value.isNaN || value.isInfinite) {
      return (value: null, error: '$label must be a number.');
    }
    if (value < 0) {
      return (value: null, error: '$label cannot be negative.');
    }
    return (value: value, error: null);
  }
}

class CustomFoodParseResult {
  const CustomFoodParseResult({this.value, this.error});

  final CustomFoodInput? value;
  final String? error;

  bool get isValid => value != null;
}
