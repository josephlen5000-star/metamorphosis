import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:metamorphosis/models/user.dart' as model;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user is first-time user
  Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstTimeUser') ?? true;
  }

  // Mark user as not first-time
  Future<void> setUserNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTimeUser', false);
  }

  // Create anonymous user and save profile
  Future<model.User> createUserProfile({
    required String username,
    required int age,
    required String biologicalSex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required bool useMetric,
  }) async {
    try {
      // Sign in anonymously
      final userCredential = await _auth.signInAnonymously();
      final userId = userCredential.user!.uid;

      // Create user object
      final user = model.User(
        userId: userId,
        username: username,
        age: age,
        biologicalSex: biologicalSex,
        heightCm: heightCm,
        weightKg: weightKg,
        activityLevel: activityLevel,
        useMetric: useMetric,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(user.toMap());

      // Mark as not first-time user
      await setUserNotFirstTime();

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<auth.User?> _resolvedAuthUser() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return _auth.currentUser;
    } catch (_) {
      return _auth.currentUser;
    }
  }

  // Get current user profile
  Future<model.User?> getUserProfile() async {
    try {
      final currentUser = await _resolvedAuthUser();
      if (currentUser == null) return null;

      final doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        return model.User.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    required String username,
    required int age,
    required String biologicalSex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required bool useMetric,
    int? customCalorieTarget,
    double? proteinGoal,
    double? carbohydrateGoal,
    double? fatGoal,
    int? waterGoal,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'username': username,
        'age': age,
        'biologicalSex': biologicalSex,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel,
        'useMetric': useMetric,
        'customCalorieTarget': customCalorieTarget,
        'proteinGoal': proteinGoal,
        'carbohydrateGoal': carbohydrateGoal,
        'fatGoal': fatGoal,
        'waterGoal': waterGoal,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if user is logged in
  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }
}
