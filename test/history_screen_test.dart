import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metamorphosis/models/food_item.dart';
import 'package:metamorphosis/models/food_log_entry.dart';
import 'package:metamorphosis/models/meal.dart';
import 'package:metamorphosis/models/user.dart';
import 'package:metamorphosis/models/weekly_insights.dart';
import 'package:metamorphosis/screens/history_screen.dart';
import 'package:metamorphosis/services/food_database.dart';

FoodItem _food({
  int id = 1,
  String name = 'Logged apple',
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

FoodLogEntry _entry({
  required DateTime loggedAt,
  FoodItem? food,
  double servings = 1,
  String? meal,
  int? id,
}) {
  return FoodLogEntry(
    id: id,
    food: food ?? _food(),
    servings: servings,
    loggedAt: loggedAt,
    meal: meal,
  );
}

User _user({int calorieTarget = 2000}) {
  return User(
    userId: 'u1',
    username: 'Ada',
    age: 25,
    biologicalSex: 'female',
    heightCm: 165,
    weightKg: 60,
    activityLevel: 'sedentary',
    useMetric: true,
    createdAt: DateTime(2026, 1, 1),
    customCalorieTarget: calorieTarget,
  );
}

void main() {
  test('datesWithLogEntries keeps unique newest-first days', () {
    final today = DateTime(2026, 9, 5, 16);
    final yesterday = DateTime(2026, 9, 4, 9);

    final dates = FoodDatabase.datesWithLogEntries([
      _entry(loggedAt: today),
      _entry(loggedAt: today.subtract(const Duration(hours: 2))),
      _entry(loggedAt: yesterday),
    ]);

    expect(dates, [
      DateTime(2026, 9, 5),
      DateTime(2026, 9, 4),
    ]);
  });

  test('history date labels keep Today, Yesterday, and a quieter calendar date', () {
    final now = DateTime(2026, 9, 5, 16);
    final today = DateTime(2026, 9, 5);
    final yesterday = DateTime(2026, 9, 4);
    final earlier = DateTime(2026, 8, 30);

    expect(formatHistoryDayTitle(today, now: now), 'Today');
    expect(formatHistoryDayTitle(yesterday, now: now), 'Yesterday');
    expect(formatHistoryDayTitle(earlier, now: now), 'Sunday');
    expect(formatHistoryDaySubtitle(today), 'Sep 5, 2026');
    expect(formatHistoryDaySubtitle(earlier), 'Aug 30, 2026');
    expect(formatHistoryMonth(today), 'September 2026');
    expect(formatHistoryMonth(earlier), 'August 2026');
    expect(formatHistoryDate(DateTime.now()), 'Today');
    expect(formatHistoryDate(DateTime(2025, 3, 18)), 'Tuesday, Mar 18, 2025');
  });

  test('historyTotalsFor uses the same servings math as HomeScreen', () {
    final totals = historyTotalsFor([
      _entry(
        loggedAt: DateTime(2026, 9, 5),
        food: _food(calories: 95, protein: 0.5, carbohydrates: 25, fats: 0.3),
        servings: 2,
      ),
      _entry(
        loggedAt: DateTime(2026, 9, 5),
        food: _food(
          id: 2,
          name: 'Chicken',
          calories: 120,
          protein: 22,
          carbohydrates: 0,
          fats: 3,
        ),
      ),
    ]);

    expect(totals.calories, 310);
    expect(totals.protein, 23);
    expect(totals.carbohydrates, 50);
    expect(totals.fats, 3.6);
  });

  testWidgets('shows logged days and the selected day totals', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayEntry = _entry(
      loggedAt: today.add(const Duration(hours: 15)),
      servings: 2,
    );
    final yesterdayEntry = _entry(
      loggedAt: yesterday.add(const Duration(hours: 8)),
      food: _food(id: 2, name: 'Chicken', calories: 120, protein: 22),
    );
    final todayTotals = historyTotalsFor([todayEntry]);
    final yesterdayTotals = historyTotalsFor([yesterdayEntry]);

    await tester.pumpWidget(
      CupertinoApp(
        home: HistoryScreen(
          datesLoader: () async => [today, yesterday],
          entriesLoader: (date) async {
            if (date == today) return [todayEntry];
            if (date == yesterday) return [yesterdayEntry];
            return [];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text(formatHistoryDaySubtitle(yesterday)), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('${todayTotals.calories.round()} kcal'), findsOneWidget);
    expect(
      find.text(
        '${_grams(todayTotals.protein)} g P  ·  '
        '${_grams(todayTotals.carbohydrates)} g C  ·  '
        '${_grams(todayTotals.fats)} g F',
      ),
      findsOneWidget,
    );
    expect(
      find.text('${yesterdayTotals.calories.round()} kcal'),
      findsOneWidget,
    );

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    expect(find.text('History'), findsWidgets);
    expect(find.text('Logged apple'), findsOneWidget);
    expect(find.text('2 servings'), findsOneWidget);
    expect(find.text('190'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('0.6'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();

    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('1 serving'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('shows an empty history state', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: HistoryScreen(
          datesLoader: () async => const [],
          entriesLoader: (_) async => const [],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No logged foods yet.'), findsOneWidget);
    expect(
      find.text('Foods you log will appear here as a journal.'),
      findsOneWidget,
    );
  });

  testWidgets('days with no food stay as No food logged', (tester) async {
    final now = DateTime(2026, 9, 5, 16);
    final today = DateTime(now.year, now.month, now.day);
    final emptyDay = today.subtract(const Duration(days: 2));
    final todayEntry = _entry(loggedAt: today.add(const Duration(hours: 10)));

    await tester.pumpWidget(
      CupertinoApp(
        home: HistoryScreen(
          now: now,
          datesLoader: () async => [today],
          entriesLoader: (date) async {
            if (date == today) return [todayEntry];
            return [];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No food logged'), findsWidgets);
    expect(find.text('0 kcal'), findsNothing);

    expect(find.text(formatHistoryMonth(today)), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(formatHistoryDaySubtitle(emptyDay)),
      180,
    );
    await tester.pumpAndSettle();
    expect(find.text(formatHistoryDayTitle(emptyDay, now: now)), findsOneWidget);
    await tester.tap(find.text(formatHistoryDaySubtitle(emptyDay)));
    await tester.pumpAndSettle();

    expect(find.text('No food logged'), findsOneWidget);
    expect(find.text('Nothing was saved for this day.'), findsOneWidget);
    expect(find.text('Logged apple'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('weekly summary uses the existing WeeklyInsights calculations', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 5, 16);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayEntry = _entry(
      loggedAt: today.add(const Duration(hours: 15)),
      servings: 2,
    );
    final yesterdayEntry = _entry(
      loggedAt: yesterday.add(const Duration(hours: 8)),
      food: _food(id: 2, name: 'Chicken', calories: 120, protein: 22),
    );
    final profile = _user();
    final weekDays = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final insights = WeeklyInsights.from(
      days: weekDays,
      entriesByDate: {
        today: [todayEntry],
        yesterday: [yesterdayEntry],
      },
      waterByDate: {today: 3},
      profile: profile,
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: HistoryScreen(
          now: now,
          profileLoader: () async => profile,
          waterForDateLoader: (date) async => date == today ? 3 : 0,
          datesLoader: () async => [today, yesterday],
          entriesLoader: (date) async {
            if (date == today) return [todayEntry];
            if (date == yesterday) return [yesterdayEntry];
            return [];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Average calories'), findsOneWidget);
    expect(find.text('${_total(insights.averageCalories!)} kcal'), findsOneWidget);
    expect(find.text('Daily target'), findsOneWidget);
    expect(find.text('${insights.calorieTarget} kcal'), findsOneWidget);
    expect(find.text('Days logged'), findsOneWidget);
    expect(
      find.text('${insights.daysWithFood} / ${WeeklyInsights.windowDays}'),
      findsOneWidget,
    );
    expect(find.text('${_grams(insights.averageProtein!)} g'), findsOneWidget);
    expect(
      find.text('${_grams(insights.averageCarbohydrates!)} g'),
      findsOneWidget,
    );
    expect(find.text('${_grams(insights.averageFats!)} g'), findsOneWidget);
    expect(find.text('Water logged'), findsOneWidget);
    expect(
      find.text('${insights.daysWithWater} / ${WeeklyInsights.windowDays}'),
      findsOneWidget,
    );
  });

  testWidgets('groups history foods by meal and keeps uncategorized as Other', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final breakfast = FoodLogEntry(
      food: _food(name: 'Oats'),
      servings: 1,
      loggedAt: today.add(const Duration(hours: 8)),
      meal: mealBreakfast,
    );
    final leftover = FoodLogEntry(
      food: _food(id: 3, name: 'Old log'),
      servings: 1,
      loggedAt: today.add(const Duration(hours: 20)),
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: HistoryDayScreen(
          date: today,
          entriesLoader: (_) async => [breakfast, leftover],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Old log'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Dinner'), findsNothing);
    expect(find.text('Snack'), findsNothing);
    expect(find.byIcon(CupertinoIcons.delete), findsNWidgets(2));
  });

  testWidgets('opening a day still shows the correct foods', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final breakfast = _entry(
      loggedAt: today.add(const Duration(hours: 8)),
      food: _food(name: 'Oats'),
      meal: mealBreakfast,
    );
    final lunch = _entry(
      loggedAt: today.add(const Duration(hours: 13)),
      food: _food(id: 2, name: 'Chicken', calories: 120, protein: 22),
      meal: mealLunch,
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: HistoryScreen(
          datesLoader: () async => [today],
          entriesLoader: (date) async => date == today ? [breakfast, lunch] : [],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('Dinner'), findsNothing);
    expect(find.text('Other'), findsNothing);
  });
}

String _total(double value, {int fractionDigits = 1}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(fractionDigits);
}

String _grams(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toStringAsFixed(0);
  }
  return rounded.toStringAsFixed(1);
}
