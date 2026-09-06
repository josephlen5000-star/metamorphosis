class FoodItem {
  final int? id;
  final String name;
  final int calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double omega6;
  final double omega3;

  FoodItem({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    required this.omega6,
    required this.omega3,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      carbohydrates: (map['carbohydrates'] as num).toDouble(),
      fats: (map['fats'] as num).toDouble(),
      omega6: (map['omega6'] as num).toDouble(),
      omega3: (map['omega3'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'omega6': omega6,
      'omega3': omega3,
    };
  }
}
