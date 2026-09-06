import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String userId;
  final String username;
  final int age;
  final String biologicalSex; // 'male' or 'female'
  final double heightCm;
  final double weightKg;
  final String activityLevel; // 'sedentary', 'low_active', 'active', 'very_active'
  final bool useMetric;
  final DateTime createdAt;
  final int? customCalorieTarget;
  final double? proteinGoal;
  final double? carbohydrateGoal;
  final double? fatGoal;
  final int? waterGoal;

  static const defaultWaterGoal = 8;

  User({
    required this.userId,
    required this.username,
    required this.age,
    required this.biologicalSex,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.useMetric,
    required this.createdAt,
    this.customCalorieTarget,
    this.proteinGoal,
    this.carbohydrateGoal,
    this.fatGoal,
    this.waterGoal,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'age': age,
      'biologicalSex': biologicalSex,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activityLevel': activityLevel,
      'useMetric': useMetric,
      'createdAt': createdAt,
      'customCalorieTarget': customCalorieTarget,
      'proteinGoal': proteinGoal,
      'carbohydrateGoal': carbohydrateGoal,
      'fatGoal': fatGoal,
      'waterGoal': waterGoal,
    };
  }

  // Create User from Firestore document
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['userId'] as String,
      username: map['username'] as String,
      age: (map['age'] as num).toInt(),
      biologicalSex: map['biologicalSex'] as String,
      heightCm: (map['heightCm'] as num).toDouble(),
      weightKg: (map['weightKg'] as num).toDouble(),
      activityLevel: map['activityLevel'] as String,
      useMetric: map['useMetric'] as bool,
      createdAt: _parseDateTime(map['createdAt']),
      customCalorieTarget: (map['customCalorieTarget'] as num?)?.round(),
      proteinGoal: (map['proteinGoal'] as num?)?.toDouble(),
      carbohydrateGoal: (map['carbohydrateGoal'] as num?)?.toDouble(),
      fatGoal: (map['fatGoal'] as num?)?.toDouble(),
      waterGoal: (map['waterGoal'] as num?)?.round(),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    throw ArgumentError('Unsupported createdAt value: $value');
  }

  // Mifflin-St Jeor BMR, then multiplied by activity level.
  double get basalMetabolicRate {
    final bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    if (biologicalSex.toLowerCase() == 'female') {
      return bmr - 161;
    }
    return bmr + 5;
  }

  double get activityMultiplier {
    switch (activityLevel) {
      case 'sedentary':
        return 1.2;
      case 'low_active':
        return 1.375;
      case 'active':
        return 1.55;
      case 'very_active':
        return 1.725;
      default:
        return 1.2;
    }
  }

  int get dailyCalorieTarget =>
      (basalMetabolicRate * activityMultiplier).round();

  /// Custom calorie goal when set; otherwise the Mifflin-St Jeor target.
  int get calorieTarget => customCalorieTarget ?? dailyCalorieTarget;

  /// Custom water goal when set; otherwise 8 glasses.
  int get dailyWaterGoal {
    final goal = waterGoal;
    if (goal == null || goal <= 0) return defaultWaterGoal;
    return goal;
  }

  // For displaying height in user's preferred unit
  String getHeightDisplay() {
    if (useMetric) {
      return '${heightCm.toStringAsFixed(1)} cm';
    } else {
      int feet = (heightCm / 30.48).floor();
      int inches = ((heightCm % 30.48) / 2.54).round();
      return "$feet'$inches\"";
    }
  }

  // For displaying weight in user's preferred unit
  String getWeightDisplay() {
    if (useMetric) {
      return '${weightKg.toStringAsFixed(1)} kg';
    } else {
      double lbs = weightKg * 2.20462;
      return '${lbs.toStringAsFixed(1)} lbs';
    }
  }

  // Get activity level display name
  static String getActivityLevelDisplay(String level) {
    switch (level) {
      case 'sedentary':
        return 'Sedentary';
      case 'low_active':
        return 'Low Active';
      case 'active':
        return 'Active';
      case 'very_active':
        return 'Very Active';
      default:
        return 'Unknown';
    }
  }
}
