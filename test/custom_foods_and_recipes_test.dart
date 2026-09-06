import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metamorphosis/models/custom_food.dart';
import 'package:metamorphosis/models/food_item.dart';
import 'package:metamorphosis/models/food_log_entry.dart';
import 'package:metamorphosis/models/meal.dart';
import 'package:metamorphosis/models/recipe.dart';
import 'package:metamorphosis/services/food_database.dart';
import 'package:metamorphosis/widgets/custom_food_editor.dart';
import 'package:metamorphosis/widgets/food_search_popup.dart';
import 'package:metamorphosis/widgets/recipe_editor.dart';

FoodItem _food({
  int? id = 1,
  String name = 'Apple',
  int calories = 95,
  double protein = 0.5,
  double carbohydrates = 25,
  double fats = 0.3,
}) {
  return FoodItem(
    id: id,
    name: name,
    calories: calories,
    protein: protein,
    carbohydrates: carbohydrates,
    fats: fats,
    omega6: 0.01,
    omega3: 0.03,
  );
}

void main() {
  group('custom food validation', () {
    test('requires a name and rejects negative nutrition', () {
      expect(
        CustomFoodInput.parse(
          name: '  ',
          calories: '100',
          protein: '1',
          carbohydrates: '2',
          fats: '3',
        ).error,
        'Enter a food name.',
      );
      expect(
        CustomFoodInput.parse(
          name: 'Oats',
          calories: '-10',
          protein: '1',
          carbohydrates: '2',
          fats: '3',
        ).error,
        'Calories cannot be negative.',
      );
      expect(
        CustomFoodInput.parse(
          name: 'Oats',
          calories: 'abc',
          protein: '1',
          carbohydrates: '2',
          fats: '3',
        ).error,
        'Calories must be a number.',
      );
    });

    test('parses per-serving nutrition and defaults omitted omegas to 0', () {
      final parsed = CustomFoodInput.parse(
        name: '  Overnight oats  ',
        calories: '310',
        protein: '18.5',
        carbohydrates: '42',
        fats: '',
      );

      expect(parsed.isValid, isTrue);
      final food = parsed.value!.toFoodItem(id: 20);
      expect(food.name, 'Overnight oats');
      expect(food.calories, 310);
      expect(food.protein, 18.5);
      expect(food.carbohydrates, 42);
      expect(food.fats, 0);
      expect(food.omega3, 0);
      expect(food.omega6, 0);
    });
  });

  group('custom food persistence', () {
    test('keeps seeded foods out of the custom catalog', () {
      final rows = [
        {
          'id': 1,
          'name': 'Apple',
          'calories': 95,
          'protein': 0.5,
          'carbohydrates': 25.0,
          'fats': 0.3,
          'omega6': 0.01,
          'omega3': 0.03,
        },
        FoodDatabase.customFoodRow(
          _food(id: 4, name: 'Protein shake', calories: 220),
          id: 4,
        ),
      ];

      final custom = FoodDatabase.customFoodsFromRows(rows);
      expect(custom, hasLength(1));
      expect(custom.single.name, 'Protein shake');
      expect(custom.single.id, 4);
      expect(FoodDatabase.rowIsCustomFood(rows.first), isFalse);
    });

    test('round-trips create, edit, and delete through stored rows', () {
      var rows = <Map<String, dynamic>>[
        {
          'id': 1,
          'name': 'Apple',
          'calories': 95,
          'protein': 0.5,
          'carbohydrates': 25.0,
          'fats': 0.3,
          'omega6': 0.01,
          'omega3': 0.03,
        },
      ];

      final created = CustomFoodInput.parse(
        name: 'Cottage cheese',
        calories: '120',
        protein: '14',
        carbohydrates: '4',
        fats: '5',
      ).value!.toFoodItem();
      rows = [
        ...rows,
        FoodDatabase.customFoodRow(created, id: 5),
      ];

      var custom = FoodDatabase.customFoodsFromRows(rows);
      expect(custom.single.name, 'Cottage cheese');
      expect(custom.single.calories, 120);

      final edited = CustomFoodInput.parse(
        name: 'Cottage cheese',
        calories: '130',
        protein: '15',
        carbohydrates: '4',
        fats: '5',
      ).value!.toFoodItem(id: 5);
      rows = [
        for (final row in rows)
          if (row['id'] == 5)
            FoodDatabase.customFoodRow(edited, id: 5)
          else
            row,
      ];
      custom = FoodDatabase.customFoodsFromRows(rows);
      expect(custom.single.calories, 130);
      expect(custom.single.protein, 15);

      rows = [
        for (final row in rows)
          if (!(row['id'] == 5 && FoodDatabase.rowIsCustomFood(row))) row,
      ];
      expect(FoodDatabase.customFoodsFromRows(rows), isEmpty);
      expect(rows.single['name'], 'Apple');
    });
  });

  group('custom food logging', () {
    test('logs through the existing FoodItem times servings path', () {
      final food = CustomFoodInput.parse(
        name: 'Protein shake',
        calories: '220',
        protein: '24',
        carbohydrates: '8',
        fats: '6',
      ).value!.toFoodItem(id: 20);

      final entry = FoodLogEntry(
        food: food,
        servings: 2,
        loggedAt: DateTime(2026, 9, 5, 8, 15),
        meal: mealBreakfast,
      );
      final restored = FoodLogEntry.fromMap(entry.toMap());

      expect(restored.food.id, 20);
      expect(restored.food.name, 'Protein shake');
      expect(restored.food.calories * restored.servings, 440);
      expect(restored.food.protein * restored.servings, 48);
      expect(restored.meal, mealBreakfast);
    });
  });

  group('recipes', () {
    test('requires a name and at least one ingredient', () {
      expect(Recipe.canSave(name: '', items: [RecipeItem(food: _food(), servings: 1)]), isFalse);
      expect(Recipe.canSave(name: 'Chili', items: const []), isFalse);
      expect(
        Recipe.canSave(
          name: 'Chili',
          items: [RecipeItem(food: _food(), servings: 1)],
        ),
        isTrue,
      );
    });

    test('creates a recipe from multiple FoodItem servings', () {
      final recipe = Recipe(
        id: 8,
        name: 'Chicken rice bowl',
        createdAt: DateTime(2026, 9, 5, 18),
        items: [
          RecipeItem(
            food: _food(id: 10, name: 'Chicken', calories: 165, protein: 31, carbohydrates: 0, fats: 3.6),
            servings: 2,
          ),
          RecipeItem(
            food: _food(id: 11, name: 'Rice', calories: 205, protein: 4.3, carbohydrates: 45, fats: 0.4),
            servings: 1,
          ),
        ],
      );

      expect(recipe.items, hasLength(2));
      expect(recipe.calories, 165 * 2 + 205);
      expect(recipe.protein, 31 * 2 + 4.3);
      expect(recipe.carbohydrates, 45);
      expect(recipe.fats, 3.6 * 2 + 0.4);
    });

    test('persists and reopens with ingredient snapshots', () {
      final recipe = Recipe(
        id: 8,
        name: 'Chicken rice bowl',
        createdAt: DateTime(2026, 9, 5, 18),
        items: [
          RecipeItem(food: _food(id: 10, name: 'Chicken'), servings: 2),
          RecipeItem(food: _food(id: 11, name: 'Rice'), servings: 1),
        ],
      );

      final rows = [recipe.toMap()];
      final restored = FoodDatabase.recipesFromRows(rows).single;
      expect(restored.id, 8);
      expect(restored.name, 'Chicken rice bowl');
      expect(restored.items.map((item) => item.food.id).toList(), [10, 11]);
      expect(restored.items.first.servings, 2);
      expect(restored.calories, 95 * 2 + 95);
    });

    test('keeps a USDA ingredient snapshot without a local catalog lookup', () {
      final usda = _food(
        id: 1750340,
        name: 'Apples, raw, with skin',
        calories: 52,
        protein: 0.3,
        carbohydrates: 14,
        fats: 0.2,
      );
      final recipe = Recipe(
        name: 'Snack apples',
        createdAt: DateTime(2026, 9, 5, 15),
        items: [RecipeItem(food: usda, servings: 2)],
      );

      final restored = Recipe.fromMap(recipe.toMap());
      expect(restored.items.single.food.id, 1750340);
      expect(restored.items.single.food.calories, 52);
      expect(restored.items.single.food.name, 'Apples, raw, with skin');

      final entries = restored.toLogEntries(
        loggedAt: DateTime(2026, 9, 5, 15, 10),
        meal: mealSnack,
      );
      expect(entries.single.food.calories * entries.single.servings, 104);
      expect(entries.single.food.id, 1750340);
    });

    test('renames and deletes without inventing nutrition', () {
      final recipe = Recipe(
        id: 3,
        name: 'Original',
        createdAt: DateTime(2026, 9, 5, 12),
        items: [
          RecipeItem(food: _food(id: 10, name: 'Chicken', calories: 165), servings: 1),
        ],
      );
      var rows = [recipe.toMap()];

      rows[0] = {...rows[0], 'name': 'Weeknight chicken'};
      final renamed = FoodDatabase.recipesFromRows(rows).single;
      expect(renamed.name, 'Weeknight chicken');
      expect(renamed.calories, 165);

      rows = rows.where((row) => row['id'] != 3).toList();
      expect(FoodDatabase.recipesFromRows(rows), isEmpty);
    });

    test('logs as existing FoodItems without changing meal selection', () {
      final recipe = Recipe(
        name: 'Dinner bowl',
        createdAt: DateTime(2026, 9, 5, 18),
        items: [
          RecipeItem(food: _food(name: 'Chicken'), servings: 2),
          RecipeItem(food: _food(id: 2, name: 'Rice'), servings: 1),
        ],
      );

      final entries = recipe.toLogEntries(
        loggedAt: DateTime(2026, 9, 5, 18, 10),
        meal: mealDinner,
      );

      expect(entries, hasLength(2));
      expect(entries.every((entry) => entry.meal == mealDinner), isTrue);
      expect(entries.first.food.name, 'Chicken');
      expect(entries.first.servings, 2);
      expect(entries.first.food.calories * entries.first.servings, 190);
      expect(mealValues, [mealBreakfast, mealLunch, mealDinner, mealSnack]);
    });
  });

  group('editors', () {
    testWidgets('creates and edits a custom food', (tester) async {
      FoodItem? created;
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async {
                created = await showCupertinoModalPopup<FoodItem>(
                  context: context,
                  builder: (_) => const CustomFoodEditor(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final fields = find.byType(CupertinoTextField);
      await tester.enterText(fields.at(0), 'Oat bowl');
      await tester.enterText(fields.at(1), '310');
      await tester.enterText(fields.at(2), '18');
      await tester.enterText(fields.at(3), '42');
      await tester.enterText(fields.at(4), '7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.name, 'Oat bowl');
      expect(created!.calories, 310);
      expect(created!.protein, 18);
    });

    testWidgets('rejects an invalid custom food', (tester) async {
      await tester.pumpWidget(const CupertinoApp(home: CustomFoodEditor()));
      await tester.pump();
      expect(find.text('Nutrition is per 1 serving.'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a food name.'), findsOneWidget);
    });

    testWidgets('asks before discarding custom food edits', (tester) async {
      await tester.pumpWidget(const CupertinoApp(home: CustomFoodEditor()));
      await tester.pump();
      await tester.enterText(find.byType(CupertinoTextField).first, 'Oats');
      await tester.tap(find.byIcon(CupertinoIcons.xmark));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Create custom food'), findsOneWidget);
    });

    testWidgets('creates a recipe from multiple selected foods', (tester) async {
      final picks = [
        _food(id: 10, name: 'Chicken', calories: 165, protein: 31, carbohydrates: 0, fats: 3.6),
        _food(id: 11, name: 'Rice', calories: 205, protein: 4.3, carbohydrates: 45, fats: 0.4),
      ];
      var pickIndex = 0;
      Recipe? saved;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async {
                saved = await showCupertinoModalPopup<Recipe>(
                  context: context,
                  builder: (_) => RecipeEditor(
                    onPickIngredient: () async => picks[pickIndex++],
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
      await tester.enterText(find.byType(CupertinoTextField), 'Chicken rice bowl');
      await tester.tap(find.text('Add food'));
      await tester.pump();
      await tester.tap(find.text('Add food'));
      await tester.pump();

      expect(find.text('Chicken'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.textContaining('370 kcal'), findsOneWidget);
      expect(find.text('Select foods and servings. Nutrition is calculated from those items.'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.name, 'Chicken rice bowl');
      expect(saved!.items, hasLength(2));
      expect(saved!.calories, 370);
    });

    testWidgets('confirms before removing a recipe ingredient', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: RecipeEditor(
            onPickIngredient: () async => _food(name: 'Chicken'),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          'Select foods and servings. Nutrition is calculated from those items.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a recipe name.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'Bowl');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Add at least one ingredient.'), findsOneWidget);

      await tester.tap(find.text('Add food'));
      await tester.pump();
      expect(find.text('Chicken'), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.delete));
      await tester.pumpAndSettle();
      expect(find.text('Remove ingredient?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Chicken'), findsNothing);
    });

    testWidgets('edits and deletes a custom food from Add food', (tester) async {
      var foods = [_food(id: 20, name: 'Protein shake', calories: 220)];

      await tester.pumpWidget(
        CupertinoApp(
          home: FoodSearchPopup(
            recentFoodsLoader: () async => const [],
            favoriteFoodsLoader: () async => const [],
            savedMealsLoader: () async => const [],
            customFoodsLoader: () async => foods,
            recipesLoader: () async => const [],
            onSaveCustomFood: (food) async {
              foods = [
                _food(
                  id: 20,
                  name: food.name,
                  calories: food.calories,
                  protein: food.protein,
                  carbohydrates: food.carbohydrates,
                  fats: food.fats,
                ),
              ];
            },
            onDeleteCustomFood: (food) async {
              foods = foods.where((item) => item.id != food.id).toList();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Protein shake'), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.pencil));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(CupertinoTextField, 'Protein shake'), 'Whey shake');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Whey shake'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Whey shake'), findsNothing);
      expect(find.text('Custom foods'), findsNothing);
    });

    testWidgets('renames and deletes a recipe from Add food', (tester) async {
      var recipes = [
        Recipe(
          id: 3,
          name: 'Original bowl',
          createdAt: DateTime(2026, 9, 5, 12),
          items: [RecipeItem(food: _food(), servings: 1)],
        ),
      ];

      await tester.pumpWidget(
        CupertinoApp(
          home: FoodSearchPopup(
            recentFoodsLoader: () async => const [],
            favoriteFoodsLoader: () async => const [],
            savedMealsLoader: () async => const [],
            customFoodsLoader: () async => const [],
            recipesLoader: () async => recipes,
            onSaveRecipe: (recipe) async {
              recipes = [recipe.copyWith(id: 3)];
            },
            onDeleteRecipe: (recipe) async {
              recipes = recipes.where((item) => item.id != recipe.id).toList();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Original bowl'), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.pencil));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(CupertinoTextField, 'Original bowl'),
        'Weeknight bowl',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Weeknight bowl'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Weeknight bowl'), findsNothing);
      expect(find.text('Recipes'), findsNothing);
    });
  });
}
