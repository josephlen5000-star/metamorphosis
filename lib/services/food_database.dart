import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_item.dart';
import '../models/food_log_entry.dart';
import '../models/recipe.dart';
import '../models/saved_meal.dart';
import 'usda_food_service.dart';
import 'usda_search_cache.dart';

class FoodDatabase {
  static final FoodDatabase instance = FoodDatabase._init();

  static Database? _database;

  static const _foodsKey = 'food_database.foods';
  static const _logEntriesKey = 'food_database.food_log_entries';
  static const _favoritesKey = 'food_database.favorite_foods';
  static const _savedMealsKey = 'food_database.saved_meals';
  static const _dailyWaterKey = 'food_database.daily_water';
  static const _recipesKey = 'food_database.recipes';
  static const _usdaSearchCacheKey = 'food_database.usda_search_cache';

  FoodDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('food_database.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, fileName);
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbohydrates REAL NOT NULL,
        fats REAL NOT NULL,
        omega6 REAL NOT NULL,
        omega3 REAL NOT NULL,
        isCustom INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createFoodLogTable(db);
    await _createFavoritesTable(db);
    await _createSavedMealsTables(db);
    await _createDailyWaterTable(db);
    await _createRecipesTables(db);
    await _insertExampleFoods(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFoodLogTable(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE food_log_entries ADD COLUMN meal TEXT');
      await _createFavoritesTable(db);
    }
    if (oldVersion < 4) {
      await _createSavedMealsTables(db);
    }
    if (oldVersion < 5) {
      await _createDailyWaterTable(db);
    }
    if (oldVersion < 6) {
      await _addCustomFoodColumn(db);
      await _createRecipesTables(db);
    }
  }

  Future<void> _createFoodLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE food_log_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodId INTEGER,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbohydrates REAL NOT NULL,
        fats REAL NOT NULL,
        omega6 REAL NOT NULL,
        omega3 REAL NOT NULL,
        servings REAL NOT NULL,
        loggedAt INTEGER NOT NULL,
        meal TEXT
      )
    ''');
  }

  Future<void> _createFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodId INTEGER,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbohydrates REAL NOT NULL,
        fats REAL NOT NULL,
        omega6 REAL NOT NULL,
        omega3 REAL NOT NULL,
        favoritedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createSavedMealsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_meals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_meal_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mealId INTEGER NOT NULL,
        foodId INTEGER,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbohydrates REAL NOT NULL,
        fats REAL NOT NULL,
        omega6 REAL NOT NULL,
        omega3 REAL NOT NULL,
        servings REAL NOT NULL
      )
    ''');
  }

  Future<void> _createDailyWaterTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_water(
        date INTEGER PRIMARY KEY,
        glasses INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _addCustomFoodColumn(Database db) async {
    await db.execute(
      'ALTER TABLE foods ADD COLUMN isCustom INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _createRecipesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipeId INTEGER NOT NULL,
        foodId INTEGER,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbohydrates REAL NOT NULL,
        fats REAL NOT NULL,
        omega6 REAL NOT NULL,
        omega3 REAL NOT NULL,
        servings REAL NOT NULL
      )
    ''');
  }

  List<FoodItem> _exampleFoods() {
    return [
      FoodItem(
        name: 'Apple',
        calories: 95,
        protein: 0.5,
        carbohydrates: 25.0,
        fats: 0.3,
        omega6: 0.01,
        omega3: 0.03,
      ),
      FoodItem(
        name: 'Potato',
        calories: 163,
        protein: 4.3,
        carbohydrates: 37.0,
        fats: 0.2,
        omega6: 0.02,
        omega3: 0.01,
      ),
      FoodItem(
        name: 'Spicy Deluxe McCrispy',
        calories: 540,
        protein: 28.0,
        carbohydrates: 46.0,
        fats: 28.0,
        omega6: 2.0,
        omega3: 0.2,
      ),
    ];
  }

  Future<void> _insertExampleFoods(Database db) async {
    for (final food in _exampleFoods()) {
      await db.insert('foods', food.toMap());
    }
  }

  Future<List<FoodItem>> getAllFoods() async {
    if (kIsWeb) {
      final rows = await _webReadRows(_foodsKey);
      final foods = rows.map(FoodItem.fromMap).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return foods;
    }

    final db = await instance.database;
    final result = await db.query('foods', orderBy: 'name ASC');
    return result.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<int> insertFood(FoodItem food) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_foodsKey);
      final id = _nextId(rows);
      rows.add({...food.toMap(), 'id': id});
      await _webWriteRows(_foodsKey, rows);
      return id;
    }

    final db = await instance.database;
    return await db.insert('foods', food.toMap());
  }

  Future<List<FoodItem>> getCustomFoods() async {
    if (kIsWeb) {
      return customFoodsFromRows(await _webReadRows(_foodsKey));
    }

    final db = await instance.database;
    final result = await db.query(
      'foods',
      where: 'isCustom = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return result.map(FoodItem.fromMap).toList();
  }

  Future<int> insertCustomFood(FoodItem food) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_foodsKey);
      final id = _nextId(rows);
      rows.add(customFoodRow(food, id: id));
      await _webWriteRows(_foodsKey, rows);
      return id;
    }

    final db = await instance.database;
    return db.insert('foods', {
      ...food.toMap()..remove('id'),
      'isCustom': 1,
    });
  }

  Future<int> updateCustomFood(FoodItem food) async {
    final id = food.id;
    if (id == null) {
      throw ArgumentError('Cannot update a custom food without an id');
    }

    if (kIsWeb) {
      final rows = await _webReadRows(_foodsKey);
      final index = rows.indexWhere((row) => row['id'] == id);
      if (index < 0 || !rowIsCustomFood(rows[index])) return 0;
      rows[index] = customFoodRow(food, id: id);
      await _webWriteRows(_foodsKey, rows);
      await _syncFavoriteSnapshot(food);
      return 1;
    }

    final db = await instance.database;
    final updated = await db.update(
      'foods',
      {
        'name': food.name,
        'calories': food.calories,
        'protein': food.protein,
        'carbohydrates': food.carbohydrates,
        'fats': food.fats,
        'omega6': food.omega6,
        'omega3': food.omega3,
      },
      where: 'id = ? AND isCustom = ?',
      whereArgs: [id, 1],
    );
    if (updated > 0) {
      await _syncFavoriteSnapshot(food);
    }
    return updated;
  }

  Future<int> deleteCustomFood(int id) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_foodsKey);
      FoodItem? removed;
      final next = <Map<String, dynamic>>[];
      for (final row in rows) {
        if (row['id'] == id && rowIsCustomFood(row)) {
          removed = FoodItem.fromMap(row);
          continue;
        }
        next.add(row);
      }
      if (removed == null) return 0;
      await _webWriteRows(_foodsKey, next);
      await removeFavorite(removed);
      return 1;
    }

    final db = await instance.database;
    final existing = await db.query(
      'foods',
      where: 'id = ? AND isCustom = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (existing.isEmpty) return 0;
    final food = FoodItem.fromMap(existing.first);
    final deleted = await db.delete(
      'foods',
      where: 'id = ? AND isCustom = ?',
      whereArgs: [id, 1],
    );
    if (deleted > 0) {
      await removeFavorite(food);
    }
    return deleted;
  }

  Future<void> _syncFavoriteSnapshot(FoodItem food) async {
    if (await isFavorite(food)) {
      await addFavorite(food);
    }
  }

  Future<int> insertLogEntry(FoodLogEntry entry) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_logEntriesKey);
      final id = _nextId(rows);
      rows.add({...entry.toMap(), 'id': id});
      await _webWriteRows(_logEntriesKey, rows);
      return id;
    }

    final db = await instance.database;
    return await db.insert('food_log_entries', entry.toMap());
  }

  Future<List<int>> insertLogEntries(List<FoodLogEntry> entries) async {
    if (entries.isEmpty) return const [];

    if (kIsWeb) {
      final rows = await _webReadRows(_logEntriesKey);
      final ids = <int>[];
      var nextId = _nextId(rows);
      for (final entry in entries) {
        rows.add({...entry.toMap(), 'id': nextId});
        ids.add(nextId);
        nextId += 1;
      }
      await _webWriteRows(_logEntriesKey, rows);
      return ids;
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      final ids = <int>[];
      for (final entry in entries) {
        ids.add(await txn.insert('food_log_entries', entry.toMap()));
      }
      return ids;
    });
  }

  Future<FoodLogEntry?> getLogEntry(int id) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_logEntriesKey);
      for (final row in rows) {
        if (row['id'] == id) return FoodLogEntry.fromMap(row);
      }
      return null;
    }

    final db = await instance.database;
    final result = await db.query(
      'food_log_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return FoodLogEntry.fromMap(result.first);
  }

  Future<List<FoodLogEntry>> getAllLogEntries() async {
    if (kIsWeb) {
      final entries = (await _webReadRows(_logEntriesKey))
          .map(FoodLogEntry.fromMap)
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return entries;
    }

    final db = await instance.database;
    final result = await db.query(
      'food_log_entries',
      orderBy: 'loggedAt DESC',
    );
    return result.map((map) => FoodLogEntry.fromMap(map)).toList();
  }

  /// Most recently logged unique foods, newest first.
  ///
  /// Uses existing [FoodLogEntry] snapshots. Foods with an id are treated as
  /// the same food; otherwise the name is used.
  Future<List<FoodItem>> getRecentFoods({int limit = 5}) async {
    final entries = await getAllLogEntries();
    return uniqueRecentFoods(entries, limit: limit);
  }

  /// Distinct calendar days that have at least one log entry, newest first.
  Future<List<DateTime>> getDatesWithLogEntries() async {
    final entries = await getAllLogEntries();
    return datesWithLogEntries(entries);
  }

  static List<DateTime> datesWithLogEntries(Iterable<FoodLogEntry> entries) {
    final seen = <int>{};
    final dates = <DateTime>[];
    for (final entry in entries) {
      final day = DateTime(
        entry.loggedAt.year,
        entry.loggedAt.month,
        entry.loggedAt.day,
      );
      if (seen.add(day.millisecondsSinceEpoch)) {
        dates.add(day);
      }
    }
    return dates;
  }

  static String foodIdentity(FoodItem food) {
    if (food.id != null) return 'id:${food.id}';
    return 'name:${food.name.toLowerCase()}';
  }

  Future<List<FoodItem>> getFavoriteFoods() async {
    final rows = await _favoriteRows();
    rows.sort((a, b) {
      final aAt = (a['favoritedAt'] as num?)?.toInt() ?? 0;
      final bAt = (b['favoritedAt'] as num?)?.toInt() ?? 0;
      return bAt.compareTo(aAt);
    });
    return [
      for (final row in rows) _favoriteFoodFromRow(row),
    ];
  }

  Future<bool> isFavorite(FoodItem food) async {
    final key = foodIdentity(food);
    final rows = await _favoriteRows();
    return rows.any((row) => _favoriteIdentity(row) == key);
  }

  Future<void> toggleFavorite(FoodItem food) async {
    if (await isFavorite(food)) {
      await removeFavorite(food);
    } else {
      await addFavorite(food);
    }
  }

  Future<void> addFavorite(FoodItem food) async {
    final key = foodIdentity(food);
    final rows = await _favoriteRows();
    rows.removeWhere((row) => _favoriteIdentity(row) == key);
    rows.add({
      ...food.toMap(),
      'foodId': food.id,
      'favoritedAt': DateTime.now().millisecondsSinceEpoch,
    });
    rows.sort((a, b) {
      final aAt = (a['favoritedAt'] as num?)?.toInt() ?? 0;
      final bAt = (b['favoritedAt'] as num?)?.toInt() ?? 0;
      return bAt.compareTo(aAt);
    });
    await _writeFavoriteRows(rows);
  }

  Future<void> removeFavorite(FoodItem food) async {
    final key = foodIdentity(food);
    final rows = await _favoriteRows();
    final next = rows.where((row) => _favoriteIdentity(row) != key).toList();
    await _writeFavoriteRows(next);
  }

  Future<List<Map<String, dynamic>>> _favoriteRows() async {
    if (kIsWeb) {
      return _webReadRows(_favoritesKey);
    }

    final db = await instance.database;
    return db.query('favorite_foods', orderBy: 'favoritedAt DESC');
  }

  Future<void> _writeFavoriteRows(List<Map<String, dynamic>> rows) async {
    if (kIsWeb) {
      await _webWriteRows(_favoritesKey, rows);
      return;
    }

    final db = await instance.database;
    await db.delete('favorite_foods');
    for (final row in rows) {
      await db.insert('favorite_foods', {
        if (row['id'] is int) 'id': row['id'],
        'foodId': row['foodId'] ?? row['id'],
        'name': row['name'],
        'calories': row['calories'],
        'protein': row['protein'],
        'carbohydrates': row['carbohydrates'],
        'fats': row['fats'],
        'omega6': row['omega6'],
        'omega3': row['omega3'],
        'favoritedAt': row['favoritedAt'] ?? 0,
      });
    }
  }

  FoodItem _favoriteFoodFromRow(Map<String, dynamic> row) {
    return FoodItem(
      id: (row['foodId'] as num?)?.toInt() ?? (row['id'] as num?)?.toInt(),
      name: row['name'] as String,
      calories: (row['calories'] as num).toInt(),
      protein: (row['protein'] as num).toDouble(),
      carbohydrates: (row['carbohydrates'] as num).toDouble(),
      fats: (row['fats'] as num).toDouble(),
      omega6: (row['omega6'] as num).toDouble(),
      omega3: (row['omega3'] as num).toDouble(),
    );
  }

  String _favoriteIdentity(Map<String, dynamic> row) {
    final id = (row['foodId'] as num?)?.toInt() ?? (row['id'] as num?)?.toInt();
    if (id != null) return 'id:$id';
    return 'name:${(row['name'] as String).toLowerCase()}';
  }

  Future<List<SavedMeal>> getSavedMeals() async {
    if (kIsWeb) {
      final meals = (await _webReadRows(_savedMealsKey))
          .map(SavedMeal.fromMap)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return meals;
    }

    final db = await instance.database;
    final mealRows = await db.query('saved_meals', orderBy: 'createdAt DESC');
    if (mealRows.isEmpty) return [];

    final itemRows = await db.query('saved_meal_items');
    final itemsByMealId = <int, List<SavedMealItem>>{};
    for (final row in itemRows) {
      final mealId = (row['mealId'] as num).toInt();
      itemsByMealId
          .putIfAbsent(mealId, () => <SavedMealItem>[])
          .add(SavedMealItem.fromMap(row));
    }

    return [
      for (final row in mealRows)
        SavedMeal(
          id: (row['id'] as num).toInt(),
          name: row['name'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (row['createdAt'] as num).toInt(),
          ),
          items: itemsByMealId[(row['id'] as num).toInt()] ?? const [],
        ),
    ];
  }

  Future<int> insertSavedMeal(SavedMeal meal) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_savedMealsKey);
      final id = _nextId(rows);
      rows.add({...meal.toMap(), 'id': id});
      await _webWriteRows(_savedMealsKey, rows);
      return id;
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      final id = await txn.insert('saved_meals', {
        'name': meal.name,
        'createdAt': meal.createdAt.millisecondsSinceEpoch,
      });
      for (final item in meal.items) {
        await txn.insert('saved_meal_items', item.toMap(mealId: id));
      }
      return id;
    });
  }

  Future<int> renameSavedMeal(int id, String name) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_savedMealsKey);
      final index = rows.indexWhere((row) => row['id'] == id);
      if (index < 0) return 0;
      rows[index] = {...rows[index], 'name': name};
      await _webWriteRows(_savedMealsKey, rows);
      return 1;
    }

    final db = await instance.database;
    return db.update(
      'saved_meals',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSavedMeal(int id) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_savedMealsKey);
      final next = rows.where((row) => row['id'] != id).toList();
      final deleted = rows.length - next.length;
      if (deleted > 0) {
        await _webWriteRows(_savedMealsKey, next);
      }
      return deleted;
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      await txn.delete(
        'saved_meal_items',
        where: 'mealId = ?',
        whereArgs: [id],
      );
      return txn.delete(
        'saved_meals',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Recipe>> getRecipes() async {
    if (kIsWeb) {
      return recipesFromRows(await _webReadRows(_recipesKey));
    }

    final db = await instance.database;
    final recipeRows = await db.query('recipes', orderBy: 'createdAt DESC');
    if (recipeRows.isEmpty) return [];

    final itemRows = await db.query('recipe_items');
    final itemsByRecipeId = <int, List<RecipeItem>>{};
    for (final row in itemRows) {
      final recipeId = (row['recipeId'] as num).toInt();
      itemsByRecipeId
          .putIfAbsent(recipeId, () => <RecipeItem>[])
          .add(RecipeItem.fromMap(row));
    }

    return [
      for (final row in recipeRows)
        Recipe(
          id: (row['id'] as num).toInt(),
          name: row['name'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (row['createdAt'] as num).toInt(),
          ),
          items: itemsByRecipeId[(row['id'] as num).toInt()] ?? const [],
        ),
    ];
  }

  Future<int> insertRecipe(Recipe recipe) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_recipesKey);
      final id = _nextId(rows);
      rows.add({...recipe.toMap(), 'id': id});
      await _webWriteRows(_recipesKey, rows);
      return id;
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      final id = await txn.insert('recipes', {
        'name': recipe.name,
        'createdAt': recipe.createdAt.millisecondsSinceEpoch,
      });
      for (final item in recipe.items) {
        await txn.insert('recipe_items', item.toMap(recipeId: id));
      }
      return id;
    });
  }

  Future<int> updateRecipe(Recipe recipe) async {
    final id = recipe.id;
    if (id == null) {
      throw ArgumentError('Cannot update a recipe without an id');
    }

    if (kIsWeb) {
      final rows = await _webReadRows(_recipesKey);
      final index = rows.indexWhere((row) => row['id'] == id);
      if (index < 0) return 0;
      rows[index] = {...recipe.toMap(), 'id': id};
      await _webWriteRows(_recipesKey, rows);
      return 1;
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      final updated = await txn.update(
        'recipes',
        {'name': recipe.name},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) return 0;
      await txn.delete(
        'recipe_items',
        where: 'recipeId = ?',
        whereArgs: [id],
      );
      for (final item in recipe.items) {
        await txn.insert('recipe_items', item.toMap(recipeId: id));
      }
      return updated;
    });
  }

  Future<int> renameRecipe(int id, String name) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_recipesKey);
      final index = rows.indexWhere((row) => row['id'] == id);
      if (index < 0) return 0;
      rows[index] = {...rows[index], 'name': name};
      await _webWriteRows(_recipesKey, rows);
      return 1;
    }

    final db = await instance.database;
    return db.update(
      'recipes',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecipe(int id) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_recipesKey);
      final next = rows.where((row) => row['id'] != id).toList();
      final deleted = rows.length - next.length;
      if (deleted > 0) {
        await _webWriteRows(_recipesKey, next);
      }
      return deleted;
    }

    final db = await instance.database;
    return db.transaction((txn) async {
      await txn.delete(
        'recipe_items',
        where: 'recipeId = ?',
        whereArgs: [id],
      );
      return txn.delete(
        'recipes',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static bool rowIsCustomFood(Map<String, dynamic> row) {
    final flag = row['isCustom'];
    return flag == 1 || flag == true;
  }

  static Map<String, dynamic> customFoodRow(FoodItem food, {required int id}) {
    return {
      ...food.toMap(),
      'id': id,
      'isCustom': 1,
    };
  }

  static List<FoodItem> customFoodsFromRows(List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows)
        if (rowIsCustomFood(row)) FoodItem.fromMap(row),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  static List<Recipe> recipesFromRows(List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows) Recipe.fromMap(row),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static List<FoodItem> uniqueRecentFoods(
    Iterable<FoodLogEntry> entries, {
    int limit = 5,
  }) {
    final seen = <String>{};
    final foods = <FoodItem>[];
    for (final entry in entries) {
      final food = entry.food;
      final key = foodIdentity(food);
      if (!seen.add(key)) continue;
      foods.add(food);
      if (foods.length >= limit) break;
    }
    return foods;
  }

  Future<List<FoodLogEntry>> getLogEntriesForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    if (kIsWeb) {
      final entries = (await _webReadRows(_logEntriesKey))
          .map(FoodLogEntry.fromMap)
          .where(
            (entry) =>
                !entry.loggedAt.isBefore(start) && entry.loggedAt.isBefore(end),
          )
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return entries;
    }

    final db = await instance.database;
    final result = await db.query(
      'food_log_entries',
      where: 'loggedAt >= ? AND loggedAt < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'loggedAt DESC',
    );
    return result.map((map) => FoodLogEntry.fromMap(map)).toList();
  }

  Future<int> updateLogEntry(FoodLogEntry entry) async {
    final id = entry.id;
    if (id == null) {
      throw ArgumentError('Cannot update a food log entry without an id');
    }

    if (kIsWeb) {
      final rows = await _webReadRows(_logEntriesKey);
      final index = rows.indexWhere((row) => row['id'] == id);
      if (index < 0) return 0;
      rows[index] = entry.toMap();
      await _webWriteRows(_logEntriesKey, rows);
      return 1;
    }

    final db = await instance.database;
    return await db.update(
      'food_log_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteLogEntry(int id) async {
    if (kIsWeb) {
      final rows = await _webReadRows(_logEntriesKey);
      final next = rows.where((row) => row['id'] != id).toList();
      final deleted = rows.length - next.length;
      if (deleted > 0) {
        await _webWriteRows(_logEntriesKey, next);
      }
      return deleted;
    }

    final db = await instance.database;
    return await db.delete(
      'food_log_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static int waterDateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  }

  Future<int> getWaterGlassesForDate(DateTime date) async {
    final key = waterDateKey(date);
    if (kIsWeb) {
      final rows = await _webReadRows(_dailyWaterKey);
      for (final row in rows) {
        if ((row['date'] as num?)?.toInt() == key) {
          return (row['glasses'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    }

    final db = await instance.database;
    final result = await db.query(
      'daily_water',
      where: 'date = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return 0;
    return (result.first['glasses'] as num?)?.toInt() ?? 0;
  }

  Future<void> setWaterGlassesForDate(DateTime date, int glasses) async {
    final key = waterDateKey(date);
    final amount = glasses < 0 ? 0 : glasses;

    if (kIsWeb) {
      final rows = await _webReadRows(_dailyWaterKey);
      final index = rows.indexWhere(
        (row) => (row['date'] as num?)?.toInt() == key,
      );
      if (amount == 0) {
        if (index >= 0) {
          rows.removeAt(index);
          await _webWriteRows(_dailyWaterKey, rows);
        }
        return;
      }
      final row = {'date': key, 'glasses': amount};
      if (index >= 0) {
        rows[index] = row;
      } else {
        rows.add(row);
      }
      await _webWriteRows(_dailyWaterKey, rows);
      return;
    }

    final db = await instance.database;
    if (amount == 0) {
      await db.delete('daily_water', where: 'date = ?', whereArgs: [key]);
      return;
    }
    await db.insert(
      'daily_water',
      {'date': key, 'glasses': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UsdaSearchResult>?> getUsdaSearchCache(
    String query, {
    DateTime? now,
  }) async {
    final record = await readUsdaSearchCache(query, now: now);
    return record?.results;
  }

  Future<UsdaSearchCacheRecord?> readUsdaSearchCache(
    String query, {
    DateTime? now,
  }) async {
    final key = normalizeUsdaSearchQuery(query);
    if (key.isEmpty) return null;

    try {
      final map = await _readUsdaSearchCacheMap();
      final raw = map[key];
      if (raw is! Map) return null;
      final record = usdaSearchCacheRecordFromMap(
        Map<String, dynamic>.from(raw),
      );
      if (record == null) return null;
      if (!isUsdaSearchCacheFresh(record.cachedAt, now: now)) return null;
      return record;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUsdaSearchCache(
    String query,
    List<UsdaSearchResult> results, {
    DateTime? now,
  }) async {
    if (results.isEmpty) return;
    final key = normalizeUsdaSearchQuery(query);
    if (key.isEmpty) return;

    try {
      final clock = now ?? DateTime.now();
      final map = pruneUsdaSearchCacheMap(
        await _readUsdaSearchCacheMap(),
        now: clock,
      );
      map[key] = usdaSearchCacheRecordToMap(
        UsdaSearchCacheRecord(results: results, cachedAt: clock),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usdaSearchCacheKey, jsonEncode(map));
    } catch (_) {
      // Search still works if the cache cannot be written.
    }
  }

  Future<Map<String, dynamic>> _readUsdaSearchCacheMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usdaSearchCacheKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> close() async {
    if (kIsWeb) return;
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<SharedPreferences> _webPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_foodsKey)) {
      final rows = <Map<String, dynamic>>[];
      final foods = _exampleFoods();
      for (var i = 0; i < foods.length; i++) {
        rows.add({...foods[i].toMap(), 'id': i + 1});
      }
      await prefs.setString(_foodsKey, jsonEncode(rows));
    }
    if (!prefs.containsKey(_logEntriesKey)) {
      await prefs.setString(_logEntriesKey, jsonEncode(const []));
    }
    if (!prefs.containsKey(_favoritesKey)) {
      await prefs.setString(_favoritesKey, jsonEncode(const []));
    }
    if (!prefs.containsKey(_savedMealsKey)) {
      await prefs.setString(_savedMealsKey, jsonEncode(const []));
    }
    if (!prefs.containsKey(_dailyWaterKey)) {
      await prefs.setString(_dailyWaterKey, jsonEncode(const []));
    }
    if (!prefs.containsKey(_recipesKey)) {
      await prefs.setString(_recipesKey, jsonEncode(const []));
    }
    return prefs;
  }

  Future<List<Map<String, dynamic>>> _webReadRows(String key) async {
    final prefs = await _webPrefs();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<void> _webWriteRows(
    String key,
    List<Map<String, dynamic>> rows,
  ) async {
    final prefs = await _webPrefs();
    await prefs.setString(key, jsonEncode(rows));
  }

  int _nextId(List<Map<String, dynamic>> rows) {
    var maxId = 0;
    for (final row in rows) {
      final id = row['id'];
      if (id is int && id > maxId) maxId = id;
    }
    return maxId + 1;
  }
}
