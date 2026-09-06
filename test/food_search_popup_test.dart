import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:metamorphosis/models/food_item.dart';
import 'package:metamorphosis/models/food_log_entry.dart';
import 'package:metamorphosis/models/recipe.dart';
import 'package:metamorphosis/models/saved_meal.dart';
import 'package:metamorphosis/services/barcode_scan.dart';
import 'package:metamorphosis/services/food_database.dart';
import 'package:metamorphosis/services/usda_food_service.dart';
import 'package:metamorphosis/widgets/food_search_popup.dart';

class _ControllableClient extends http.BaseClient {
  final List<Uri> requests = [];
  final List<Completer<String>> _pending = [];
  final List<Completer<void>> _requestWaiters = [];

  Future<void> waitForRequest() {
    if (_pending.isNotEmpty) return Future.value();
    final waiter = Completer<void>();
    _requestWaiters.add(waiter);
    return waiter.future;
  }

  void complete(Object body) {
    _pending.removeAt(0).complete(body is String ? body : jsonEncode(body));
  }

  void completeError() {
    _pending.removeAt(0).completeError(const UsdaFoodException('network'));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final bodyCompleter = Completer<String>();
    _pending.add(bodyCompleter);
    for (final waiter in _requestWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _requestWaiters.clear();
    final body = await bodyCompleter.future;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}

Map<String, dynamic> _food(String description) {
  return {
    'fdcId': 1750340,
    'description': description,
    'dataType': 'Foundation',
    'foodNutrients': [
      {'nutrientId': 1008, 'value': 52, 'unitName': 'KCAL'},
      {'nutrientId': 1003, 'value': 0.3},
      {'nutrientId': 1005, 'value': 14},
      {'nutrientId': 1004, 'value': 0.2},
    ],
  };
}

FoodItem _loggedFood({
  int id = 1,
  String name = 'Logged apple',
  int calories = 95,
}) {
  return FoodItem(
    id: id,
    name: name,
    calories: calories,
    protein: 0.5,
    carbohydrates: 25,
    fats: 0.3,
    omega6: 0.01,
    omega3: 0.03,
  );
}

SavedMeal _savedMeal({
  int id = 1,
  String name = 'My Breakfast',
  FoodItem? food,
  double servings = 1,
}) {
  return SavedMeal(
    id: id,
    name: name,
    createdAt: DateTime(2026, 9, 5, 8),
    items: [
      SavedMealItem(
        food: food ?? _loggedFood(),
        servings: servings,
      ),
    ],
  );
}

Recipe _recipe({
  int id = 1,
  String name = 'Chicken Rice Bowl',
  FoodItem? food,
  double servings = 1,
}) {
  return Recipe(
    id: id,
    name: name,
    createdAt: DateTime(2026, 9, 5, 8),
    items: [
      RecipeItem(
        food: food ?? _loggedFood(),
        servings: servings,
      ),
    ],
  );
}

Widget _app(
  UsdaFoodService service, {
  Future<List<FoodItem>> Function()? recentFoodsLoader,
  Future<List<FoodItem>> Function()? favoriteFoodsLoader,
  Future<List<SavedMeal>> Function()? savedMealsLoader,
  Future<List<FoodItem>> Function()? customFoodsLoader,
  Future<List<Recipe>> Function()? recipesLoader,
  Future<void> Function(SavedMeal meal, String name)? onRenameSavedMeal,
  Future<void> Function(SavedMeal meal)? onDeleteSavedMeal,
  Future<void> Function(FoodItem food)? onSaveCustomFood,
  Future<void> Function(FoodItem food)? onDeleteCustomFood,
  Future<void> Function(Recipe recipe)? onSaveRecipe,
  Future<void> Function(Recipe recipe)? onDeleteRecipe,
  BarcodeScanner? barcodeScanner,
}) {
  return CupertinoApp(
    home: FoodSearchPopup(
      foodService: service,
      recentFoodsLoader: recentFoodsLoader ?? () async => const [],
      favoriteFoodsLoader: favoriteFoodsLoader ?? () async => const [],
      savedMealsLoader: savedMealsLoader ?? () async => const [],
      customFoodsLoader: customFoodsLoader ?? () async => const [],
      recipesLoader: recipesLoader ?? () async => const [],
      onRenameSavedMeal: onRenameSavedMeal,
      onDeleteSavedMeal: onDeleteSavedMeal,
      onSaveCustomFood: onSaveCustomFood,
      onDeleteCustomFood: onDeleteCustomFood,
      onSaveRecipe: onSaveRecipe,
      onDeleteRecipe: onDeleteRecipe,
      barcodeScanner: barcodeScanner,
    ),
  );
}

void main() {
  testWidgets('autofocuses the search field and shows idle copy', (tester) async {
    await tester.pumpWidget(
      _app(UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test')),
    );
    await tester.pump();

    final field = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(find.text('Type to search foods.'), findsOneWidget);
  });

  testWidgets('shows a clear button and restores the idle state', (tester) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));

    expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsNothing);

    await tester.enterText(find.byType(CupertinoTextField), 'ap');
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
    await tester.pump();

    expect(tester.widget<CupertinoTextField>(find.byType(CupertinoTextField)).controller?.text, '');
    expect(find.text('Type to search foods.'), findsOneWidget);
    expect(client.requests, isEmpty);
  });

  testWidgets('does not request USDA for queries shorter than 2 characters', (tester) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));

    await tester.enterText(find.byType(CupertinoTextField), 'a');
    await tester.pump(const Duration(milliseconds: 400));

    expect(client.requests, isEmpty);
    expect(find.text('Type to search foods.'), findsOneWidget);
  });

  testWidgets('keeps results visible while a later search is loading', (tester) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));

    await tester.enterText(find.byType(CupertinoTextField), 'apple');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    client.complete({
      'foods': [_food('Apples, raw, with skin')],
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.textContaining('Per 100 g'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'chicken');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    client.complete({
      'foods': [_food('Chicken, broilers or fryers, meat only, raw')],
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Chicken, broilers or fryers, meat only, raw'), findsOneWidget);
    expect(find.text('Apples, raw, with skin'), findsNothing);
  });

  testWidgets('shows a friendly error and retries without raw exceptions', (tester) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));

    await tester.enterText(find.byType(CupertinoTextField), 'milk');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    client.completeError();
    await tester.pump();
    await tester.pump();

    expect(find.text('Couldn\'t load foods. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('UsdaFoodException'), findsNothing);
    expect(find.textContaining('network'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    await client.waitForRequest();
    client.complete({
      'foods': [_food('Milk, whole, 3.25% milkfat')],
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Milk, whole, 3.25% milkfat'), findsOneWidget);
  });

  testWidgets('shows a friendly empty state when USDA returns no foods', (
    tester,
  ) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));

    await tester.enterText(find.byType(CupertinoTextField), 'zzzzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    expect(find.text('Searching…'), findsOneWidget);
    client.complete({'foods': <Map<String, dynamic>>[]});
    await tester.pump();
    await tester.pump();

    expect(find.text('No matching foods found.'), findsOneWidget);
  });

  testWidgets('pops the selected FoodItem with per-serving nutrition', (tester) async {
    final client = _ControllableClient();
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(httpClient: client, apiKey: 'test'),
                  recentFoodsLoader: () async => const [],
                  favoriteFoodsLoader: () async => const [],
                  savedMealsLoader: () async => const [],
                  customFoodsLoader: () async => const [],
                  recipesLoader: () async => const [],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField), 'apple');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    client.complete({
      'foods': [_food('Apples, raw, with skin')],
    });
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Apples, raw, with skin'));
    await tester.pumpAndSettle();

    expect(selected, isA<PickedFood>());
    final food = (selected! as PickedFood).food;
    expect(food.name, 'Apples, raw, with skin');
    expect(food.calories, 52);
    expect(food.protein, 0.3);
    expect(food.carbohydrates, 14);
    expect(food.fats, 0.2);
  });

  testWidgets('shows recent foods when the search field is empty', (tester) async {
    final recent = _loggedFood();
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        recentFoodsLoader: () async => [recent],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Recent foods'), findsOneWidget);
    expect(find.text('Logged apple'), findsOneWidget);
    expect(find.text('Type to search foods.'), findsNothing);
  });

  testWidgets('keeps the idle state when there are no recent foods', (tester) async {
    await tester.pumpWidget(
      _app(UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test')),
    );
    await tester.pump();

    expect(find.text('Recent foods'), findsNothing);
    expect(find.text('Type to search foods.'), findsOneWidget);
  });

  testWidgets('tapping a recent food pops the logged FoodItem', (tester) async {
    final recent = _loggedFood(id: 1750340, calories: 95);
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(
                    httpClient: _ControllableClient(),
                    apiKey: 'test',
                  ),
                  recentFoodsLoader: () async => [recent],
                  favoriteFoodsLoader: () async => const [],
                  savedMealsLoader: () async => const [],
                  customFoodsLoader: () async => const [],
                  recipesLoader: () async => const [],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logged apple'));
    await tester.pumpAndSettle();

    expect(selected, isA<PickedFood>());
    final food = (selected! as PickedFood).food;
    expect(food.id, 1750340);
    expect(food.name, 'Logged apple');
    expect(food.calories, 95);
    expect(food.protein, 0.5);
  });

  test('uniqueRecentFoods keeps the 5 newest unique logged foods', () {
    FoodLogEntry entry(int id, String name, int minutesAgo) {
      return FoodLogEntry(
        food: _loggedFood(id: id, name: name),
        servings: 1,
        loggedAt: DateTime(2026, 9, 5, 16).subtract(Duration(minutes: minutesAgo)),
      );
    }

    final foods = FoodDatabase.uniqueRecentFoods([
      entry(1, 'Apple', 1),
      entry(2, 'Chicken', 2),
      entry(1, 'Apple again', 3),
      entry(3, 'Milk', 4),
      entry(4, 'Rice', 5),
      entry(5, 'Eggs', 6),
      entry(6, 'Oats', 7),
    ]);

    expect(foods.map((food) => food.id).toList(), [1, 2, 3, 4, 5]);
    expect(foods.first.name, 'Apple');
    expect(foods.length, 5);
  });

  testWidgets('shows favorite foods before recent foods', (tester) async {
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        recentFoodsLoader: () async => [_loggedFood(id: 2, name: 'Recent milk')],
        favoriteFoodsLoader: () async => [_loggedFood(id: 1, name: 'Favorite apple')],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Favorite foods'), findsOneWidget);
    expect(find.text('Favorite apple'), findsOneWidget);
    expect(find.text('Recent foods'), findsOneWidget);
    expect(find.text('Recent milk'), findsOneWidget);

    final favoriteY = tester.getTopLeft(find.text('Favorite foods')).dy;
    final recentY = tester.getTopLeft(find.text('Recent foods')).dy;
    expect(favoriteY, lessThan(recentY));
  });

  testWidgets('tapping a favorite pops the FoodItem', (tester) async {
    final favorite = _loggedFood(id: 9, name: 'Favorite chicken', calories: 120);
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(
                    httpClient: _ControllableClient(),
                    apiKey: 'test',
                  ),
                  recentFoodsLoader: () async => const [],
                  favoriteFoodsLoader: () async => [favorite],
                  savedMealsLoader: () async => const [],
                  customFoodsLoader: () async => const [],
                  recipesLoader: () async => const [],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorite chicken'));
    await tester.pumpAndSettle();

    expect(selected, isA<PickedFood>());
    final food = (selected! as PickedFood).food;
    expect(food.id, 9);
    expect(food.calories, 120);
  });

  testWidgets('shows saved meals before favorites when the search field is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        savedMealsLoader: () async => [_savedMeal()],
        favoriteFoodsLoader: () async => [_loggedFood(id: 1, name: 'Favorite apple')],
        recentFoodsLoader: () async => [_loggedFood(id: 2, name: 'Recent milk')],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Saved meals'), findsOneWidget);
    expect(find.text('My Breakfast'), findsOneWidget);
    expect(find.text('Favorite foods'), findsOneWidget);
    expect(find.text('Recent foods'), findsOneWidget);

    final savedY = tester.getTopLeft(find.text('Saved meals')).dy;
    final favoriteY = tester.getTopLeft(find.text('Favorite foods')).dy;
    expect(savedY, lessThan(favoriteY));
  });

  testWidgets('does not show an empty saved meals section', (tester) async {
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        recentFoodsLoader: () async => [_loggedFood()],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Saved meals'), findsNothing);
    expect(find.text('Recent foods'), findsOneWidget);
  });

  testWidgets('tapping a saved meal pops the template', (tester) async {
    final meal = _savedMeal(servings: 2);
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(
                    httpClient: _ControllableClient(),
                    apiKey: 'test',
                  ),
                  recentFoodsLoader: () async => const [],
                  favoriteFoodsLoader: () async => const [],
                  savedMealsLoader: () async => [meal],
                  customFoodsLoader: () async => const [],
                  recipesLoader: () async => const [],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Breakfast'));
    await tester.pumpAndSettle();

    expect(selected, isA<PickedSavedMeal>());
    final picked = (selected! as PickedSavedMeal).meal;
    expect(picked.name, 'My Breakfast');
    expect(picked.items.single.servings, 2);
    expect(picked.items.single.food.name, 'Logged apple');
  });

  testWidgets('renaming a saved meal updates the list', (tester) async {
    var meals = [_savedMeal()];

    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        savedMealsLoader: () async => meals,
        onRenameSavedMeal: (meal, name) async {
          meals = [meal.copyWith(name: name)];
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.pencil));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(CupertinoTextField, 'My Breakfast'), 'Protein Smoothie');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Protein Smoothie'), findsOneWidget);
    expect(find.text('My Breakfast'), findsNothing);
  });

  testWidgets('deleting a saved meal removes it from the list', (tester) async {
    var meals = [_savedMeal()];

    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        savedMealsLoader: () async => meals,
        onDeleteSavedMeal: (meal) async {
          meals = meals.where((saved) => saved.id != meal.id).toList();
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Saved meals'), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Saved meals'), findsNothing);
    expect(find.text('My Breakfast'), findsNothing);
    expect(find.text('Type to search foods.'), findsOneWidget);
  });

  testWidgets('ingredient picker hides create actions and recipes', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: FoodSearchPopup(
          pickIngredient: true,
          foodService: UsdaFoodService(
            httpClient: _ControllableClient(),
            apiKey: 'test',
          ),
          recentFoodsLoader: () async => const [],
          favoriteFoodsLoader: () async => const [],
          savedMealsLoader: () async => const [],
          customFoodsLoader: () async => const [],
          recipesLoader: () async => [_recipe()],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Add ingredient'), findsOneWidget);
    expect(find.text('Create custom food'), findsNothing);
    expect(find.text('Create recipe'), findsNothing);
    expect(find.text('Recipes'), findsNothing);
    expect(find.text('Chicken Rice Bowl'), findsNothing);
    expect(
      find.text('Search or pick a food to add to this recipe.'),
      findsOneWidget,
    );
  });

  testWidgets('shows compact create actions without crowding search', (tester) async {
    await tester.pumpWidget(
      _app(UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test')),
    );
    await tester.pump();

    expect(find.text('Create custom food'), findsOneWidget);
    expect(find.text('Create recipe'), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Add food'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
  });

  testWidgets('shows recipes before saved meals when the search field is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        recipesLoader: () async => [_recipe()],
        savedMealsLoader: () async => [_savedMeal()],
        favoriteFoodsLoader: () async => [_loggedFood(id: 1, name: 'Favorite apple')],
        recentFoodsLoader: () async => [_loggedFood(id: 2, name: 'Recent milk')],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Saved meals'), findsOneWidget);
    expect(find.text('Favorite foods'), findsOneWidget);

    final recipesY = tester.getTopLeft(find.text('Recipes')).dy;
    final savedY = tester.getTopLeft(find.text('Saved meals')).dy;
    expect(recipesY, lessThan(savedY));
  });

  testWidgets('shows custom foods alongside saved lists', (tester) async {
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        customFoodsLoader: () async => [
          _loggedFood(id: 20, name: 'Overnight oats', calories: 310),
        ],
        savedMealsLoader: () async => [_savedMeal()],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Custom foods'), findsOneWidget);
    expect(find.text('Overnight oats'), findsOneWidget);
    expect(find.text('Saved meals'), findsOneWidget);
  });

  testWidgets('tapping a custom food pops a FoodItem', (tester) async {
    final custom = _loggedFood(id: 20, name: 'Protein shake', calories: 220);
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(
                    httpClient: _ControllableClient(),
                    apiKey: 'test',
                  ),
                  recentFoodsLoader: () async => const [],
                  favoriteFoodsLoader: () async => const [],
                  savedMealsLoader: () async => const [],
                  customFoodsLoader: () async => [custom],
                  recipesLoader: () async => const [],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Protein shake'));
    await tester.pumpAndSettle();

    expect(selected, isA<PickedFood>());
    final food = (selected! as PickedFood).food;
    expect(food.id, 20);
    expect(food.calories, 220);
  });

  testWidgets('tapping a recipe pops the template', (tester) async {
    final recipe = _recipe(servings: 2);
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(
                    httpClient: _ControllableClient(),
                    apiKey: 'test',
                  ),
                  recentFoodsLoader: () async => const [],
                  favoriteFoodsLoader: () async => const [],
                  savedMealsLoader: () async => const [],
                  customFoodsLoader: () async => const [],
                  recipesLoader: () async => [recipe],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chicken Rice Bowl'));
    await tester.pumpAndSettle();

    expect(selected, isA<PickedRecipe>());
    final picked = (selected! as PickedRecipe).recipe;
    expect(picked.name, 'Chicken Rice Bowl');
    expect(picked.items.single.servings, 2);
    expect(picked.items.single.food.name, 'Logged apple');
  });

  testWidgets('scan barcode pops a matching USDA food through PickedFood', (
    tester,
  ) async {
    final client = _ControllableClient();
    FoodPickerResult? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              selected = await showCupertinoModalPopup<FoodPickerResult>(
                context: context,
                builder: (_) => FoodSearchPopup(
                  foodService: UsdaFoodService(
                    httpClient: client,
                    apiKey: 'test',
                  ),
                  recentFoodsLoader: () async => const [],
                  favoriteFoodsLoader: () async => const [],
                  savedMealsLoader: () async => const [],
                  customFoodsLoader: () async => const [],
                  recipesLoader: () async => const [],
                  barcodeScanner: (_) async =>
                      const BarcodeScanned('012345678905'),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    await client.waitForRequest();
    expect(find.text('Looking up barcode…'), findsOneWidget);
    client.complete({
      'foods': [
        {
          'fdcId': 1847890,
          'description': 'COLA',
          'dataType': 'Branded',
          'brandOwner': 'SODA CO',
          'gtinUpc': '012345678905',
          'servingSize': 355,
          'servingSizeUnit': 'ml',
          'foodNutrients': [
            {'nutrientId': 1008, 'value': 42, 'unitName': 'KCAL'},
            {'nutrientId': 1003, 'value': 0},
            {'nutrientId': 1005, 'value': 11},
            {'nutrientId': 1004, 'value': 0},
          ],
        },
      ],
    });
    await tester.pumpAndSettle();

    expect(selected, isA<PickedFood>());
    final food = (selected! as PickedFood).food;
    expect(food.name, 'Cola (Soda Co)');
    expect(food.calories, 149);
  });

  testWidgets('scan barcode shows Food not found and returns to search', (
    tester,
  ) async {
    final client = _ControllableClient();
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: client, apiKey: 'test'),
        barcodeScanner: (_) async => const BarcodeScanned('012345678905'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    await client.waitForRequest();
    client.complete({
      'foods': [
        {
          'fdcId': 1,
          'description': 'OTHER SODA',
          'dataType': 'Branded',
          'gtinUpc': '111111111111',
          'foodNutrients': [
            {'nutrientId': 1008, 'value': 10, 'unitName': 'KCAL'},
          ],
        },
      ],
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Food not found'), findsOneWidget);
    expect(
      find.text('This barcode isn\'t in USDA FoodData Central.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back to search'));
    await tester.pump();

    expect(find.text('Type to search foods.'), findsOneWidget);
    expect(find.text('Food not found'), findsNothing);
  });

  testWidgets('scan barcode handles invalid, permission, and unavailable', (
    tester,
  ) async {
    BarcodeScanOutcome outcome = const BarcodeScanned('not-a-upc');

    Future<BarcodeScanOutcome> scanner(BuildContext context) async => outcome;

    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: _ControllableClient(), apiKey: 'test'),
        barcodeScanner: scanner,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    expect(find.text('Couldn\'t read that barcode.'), findsOneWidget);
    await tester.tap(find.text('Back to search'));
    await tester.pump();

    outcome = const BarcodeScanPermissionDenied();
    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    expect(
      find.text('Camera access is needed to scan barcodes.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to search'));
    await tester.pump();

    outcome = const BarcodeScanUnavailable();
    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    expect(
      find.text('Barcode scanning isn\'t available on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('scan barcode retries a network failure and ignores a duplicate', (
    tester,
  ) async {
    final client = _ControllableClient();
    var scans = 0;
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: client, apiKey: 'test'),
        barcodeScanner: (_) async {
          scans++;
          return const BarcodeScanned('012345678905');
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    await client.waitForRequest();
    expect(find.text('Looking up barcode…'), findsOneWidget);

    await tester.tap(find.text('Scan barcode'));
    await tester.pump();
    expect(scans, 1);

    client.completeError();
    await tester.pump();
    await tester.pump();

    expect(find.text('Couldn\'t load foods. Try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await client.waitForRequest();
    client.complete({
      'foods': [
        {
          'fdcId': 1,
          'description': 'OTHER SODA',
          'dataType': 'Branded',
          'gtinUpc': '111111111111',
          'foodNutrients': [
            {'nutrientId': 1008, 'value': 10, 'unitName': 'KCAL'},
          ],
        },
      ],
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Food not found'), findsOneWidget);
    expect(scans, 1);
  });
}
