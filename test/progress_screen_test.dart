import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metamorphosis/models/food_item.dart';
import 'package:metamorphosis/models/food_log_entry.dart';
import 'package:metamorphosis/models/user.dart';
import 'package:metamorphosis/models/weekly_insights.dart';
import 'package:metamorphosis/screens/history_screen.dart';
import 'package:metamorphosis/screens/progress_screen.dart';

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
}) {
  return FoodLogEntry(
    food: food ?? _food(),
    servings: servings,
    loggedAt: loggedAt,
  );
}

User _user({
  int calorieTarget = 2000,
  double? proteinGoal,
  double? carbohydrateGoal,
  double? fatGoal,
  int? waterGoal,
}) {
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
    proteinGoal: proteinGoal,
    carbohydrateGoal: carbohydrateGoal,
    fatGoal: fatGoal,
    waterGoal: waterGoal,
  );
}

Widget _app({
  User? profile,
  List<FoodLogEntry> today = const [],
  List<FoodLogEntry> all = const [],
  int water = 0,
  Map<DateTime, int> waterByDate = const {},
  DateTime? now,
}) {
  final clock = now ?? DateTime(2026, 9, 5, 16);
  return CupertinoApp(
    home: ProgressScreen(
      profileLoader: () async => profile,
      todaysEntriesLoader: () async => today,
      allEntriesLoader: () async => all,
      todaysWaterLoader: () async => water,
      waterForDateLoader: waterByDate.isEmpty
          ? null
          : (date) async {
              final day = DateTime(date.year, date.month, date.day);
              return waterByDate[day] ?? 0;
            },
      now: clock,
    ),
  );
}

void main() {
  final today = DateTime(2026, 9, 5, 12);

  test('progressLast7Days is the current day and the six before it', () {
    final days = progressLast7Days(DateTime(2026, 9, 5, 16));
    expect(days, [
      DateTime(2026, 8, 30),
      DateTime(2026, 8, 31),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 2),
      DateTime(2026, 9, 3),
      DateTime(2026, 9, 4),
      DateTime(2026, 9, 5),
    ]);
  });

  testWidgets('shows today calories, target, and remaining', (tester) async {
    await tester.pumpWidget(
      _app(
        profile: _user(calorieTarget: 2000),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [_entry(loggedAt: today, servings: 2)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('kcal eaten'), findsOneWidget);
    expect(find.text('190'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('1810'), findsOneWidget);
  });

  testWidgets('keeps remaining neutral when calories exceed the target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        profile: _user(calorieTarget: 100),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [_entry(loggedAt: today, servings: 2)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('190'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('-90'), findsOneWidget);
    expect(find.textContaining('over'), findsNothing);
  });

  testWidgets('shows macro grams without inventing goals', (tester) async {
    await tester.pumpWidget(
      _app(
        profile: _user(),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [_entry(loggedAt: today, servings: 2)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('1 g'), findsWidgets);
    expect(find.text('50 g'), findsWidgets);
    expect(find.text('0.6 g'), findsWidgets);
    expect(find.text('1 / 140 g'), findsNothing);
  });

  testWidgets('shows consumed / goal when macro goals are set', (tester) async {
    await tester.pumpWidget(
      _app(
        profile: _user(proteinGoal: 140, carbohydrateGoal: 200, fatGoal: 60),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [_entry(loggedAt: today, servings: 2)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('1 / 140 g'), findsWidgets);
    expect(find.text('50 / 200 g'), findsWidgets);
    expect(find.text('0.6 / 60 g'), findsWidgets);
  });

  testWidgets('shows existing water consumed and goal', (tester) async {
    await tester.pumpWidget(
      _app(
        profile: _user(waterGoal: 8),
        water: 6,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('6 / 8 glasses'), findsOneWidget);
    expect(find.text('+ Add water'), findsNothing);
  });

  testWidgets('last 7 days includes empty days as no data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final yesterday = DateTime(2026, 9, 4, 9);
    await tester.pumpWidget(
      _app(
        profile: _user(),
        today: [_entry(loggedAt: today)],
        all: [
          _entry(loggedAt: today),
          _entry(loggedAt: yesterday, food: _food(id: 2, calories: 120)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Last 7 days'), 200);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sat'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);

    final chart = find.byKey(progressWeekChartKey);
    expect(chart, findsOneWidget);
    expect(find.descendant(of: chart, matching: find.text('95')), findsOneWidget);
    expect(find.descendant(of: chart, matching: find.text('120')), findsOneWidget);
    expect(find.descendant(of: chart, matching: find.text('0')), findsNothing);
    expect(
      find.descendant(of: chart, matching: find.text('2000')),
      findsOneWidget,
    );
  });

  test('week chart days use History calorie totals and leave empty days unset', () {
    final now = DateTime(2026, 9, 5, 16);
    final days = progressWeekChartDays(
      now: now,
      entriesByDate: {
        DateTime(2026, 9, 5): [_entry(loggedAt: today, servings: 2)],
        DateTime(2026, 9, 4): [
          _entry(
            loggedAt: DateTime(2026, 9, 4, 9),
            food: _food(id: 2, calories: 120),
          ),
        ],
      },
    );

    expect(days.map((day) => day.label).toList(), [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ]);
    expect(days.where((day) => day.hasData).length, 2);
    expect(days.last.hasData, isTrue);
    expect(days.last.calories, 190);
    expect(days[5].hasData, isTrue);
    expect(days[5].calories, 120);
    expect(days.take(5).every((day) => !day.hasData), isTrue);

    expect(
      progressWeekChartMaxCalories(days: days, target: 2000),
      2000,
    );
    expect(
      progressWeekChartMaxCalories(days: days, target: 100),
      190,
    );
  });

  testWidgets('macro grams-only display stays when goals are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        profile: _user(),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [_entry(loggedAt: today, servings: 2)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('${progressMacroBarPrefix}Protein')), findsNothing);
    expect(find.byKey(const Key('${progressMacroBarPrefix}Carbs')), findsNothing);
    expect(find.byKey(const Key('${progressMacroBarPrefix}Fat')), findsNothing);
    expect(find.text('1 g'), findsWidgets);
    expect(find.text('1 / 140 g'), findsNothing);
  });

  testWidgets('macro progress bars appear when custom goals exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        profile: _user(proteinGoal: 140, carbohydrateGoal: 200, fatGoal: 60),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [_entry(loggedAt: today, servings: 2)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('1 / 140 g'), findsWidgets);
    expect(find.text('50 / 200 g'), findsWidgets);
    expect(find.text('0.6 / 60 g'), findsWidgets);
    expect(find.byKey(const Key('${progressMacroBarPrefix}Protein')), findsOneWidget);
    expect(find.byKey(const Key('${progressMacroBarPrefix}Carbs')), findsOneWidget);
    expect(find.byKey(const Key('${progressMacroBarPrefix}Fat')), findsOneWidget);
  });

  test('weekly insights omit missing days from calorie averages', () {
    final days = progressLast7Days(DateTime(2026, 9, 5, 16));
    final today = DateTime(2026, 9, 5);
    final yesterday = DateTime(2026, 9, 4);

    final insights = WeeklyInsights.from(
      days: days,
      entriesByDate: {
        today: [_entry(loggedAt: today, servings: 2)],
        yesterday: [
          _entry(
            loggedAt: yesterday,
            food: _food(id: 2, calories: 120, protein: 22, fats: 3),
          ),
        ],
      },
      waterByDate: const {},
      profile: _user(calorieTarget: 2000),
    );

    expect(insights.daysWithFood, 2);
    expect(insights.daysWithWater, 0);
    expect(insights.averageCalories, (190 + 120) / 2);
    expect(insights.calorieTarget, 2000);
    expect(insights.daysBelowCalorieTarget, 2);
    expect(insights.averageProtein, (1 + 22) / 2);
    expect(insights.averageCarbohydrates, (50 + 25) / 2);
    expect(insights.averageFats, (0.6 + 3) / 2);
    expect(insights.averageWater, isNull);
  });

  test('weekly insights treat days without logs as no data, not zero', () {
    final insights = WeeklyInsights.from(
      days: progressLast7Days(DateTime(2026, 9, 5)),
      entriesByDate: const {},
      waterByDate: const {},
      profile: _user(),
    );

    expect(insights.daysWithFood, 0);
    expect(insights.daysWithWater, 0);
    expect(insights.averageCalories, isNull);
    expect(insights.averageProtein, isNull);
    expect(insights.averageWater, isNull);
    expect(insights.daysBelowCalorieTarget, 0);
  });

  test('weekly water average uses only days with water logged', () {
    final today = DateTime(2026, 9, 5);
    final midweek = DateTime(2026, 9, 2);

    final insights = WeeklyInsights.from(
      days: progressLast7Days(today),
      entriesByDate: const {},
      waterByDate: {
        today: 8,
        midweek: 5,
      },
      profile: _user(waterGoal: 8),
    );

    expect(insights.daysWithWater, 2);
    expect(insights.averageWater, 6.5);
    expect(insights.waterGoal, 8);
  });

  test('weekly macro averages compare to custom goals when set', () {
    final today = DateTime(2026, 9, 5);
    final insights = WeeklyInsights.from(
      days: progressLast7Days(today),
      entriesByDate: {
        today: [_entry(loggedAt: today, servings: 2)],
      },
      waterByDate: const {},
      profile: _user(proteinGoal: 140, carbohydrateGoal: 200, fatGoal: 60),
    );

    expect(insights.averageProtein, 1);
    expect(insights.proteinGoal, 140);
    expect(insights.carbohydrateGoal, 200);
    expect(insights.fatGoal, 60);
  });

  test('generated observations stay factual and skip missing data', () {
    final today = DateTime(2026, 9, 5);
    final withFood = WeeklyInsights.from(
      days: progressLast7Days(today),
      entriesByDate: {
        today: [_entry(loggedAt: today, servings: 2)],
        DateTime(2026, 9, 4): [_entry(loggedAt: DateTime(2026, 9, 4))],
      },
      waterByDate: {
        today: 6,
        DateTime(2026, 9, 3): 7,
      },
      profile: _user(calorieTarget: 2000, waterGoal: 8),
    );

    expect(withFood.observations, [
      'You logged food on 2 of the last 7 days.',
      'Your average calorie intake was below your daily target.',
      'You averaged 6.5 glasses of water per day.',
    ]);

    final empty = WeeklyInsights.from(
      days: progressLast7Days(today),
      entriesByDate: const {},
      waterByDate: const {},
      profile: _user(),
    );

    expect(empty.observations, [
      'You logged food on 0 of the last 7 days.',
      'You logged water on 0 of the last 7 days.',
    ]);
    expect(
      empty.observations.join(' '),
      isNot(contains('health')),
    );
  });

  testWidgets('shows weekly insights below the last 7 days', (tester) async {
    final today = DateTime(2026, 9, 5, 12);
    await tester.pumpWidget(
      _app(
        profile: _user(calorieTarget: 2000, proteinGoal: 140, waterGoal: 8),
        today: [_entry(loggedAt: today, servings: 2)],
        all: [
          _entry(loggedAt: today, servings: 2),
          _entry(loggedAt: DateTime(2026, 9, 4, 9)),
        ],
        waterByDate: {
          DateTime(2026, 9, 5): 6,
          DateTime(2026, 9, 3): 7,
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Weekly Insights'), 300);
    expect(find.text('Weekly Insights'), findsOneWidget);
    expect(find.text('142.5 kcal'), findsOneWidget);
    expect(find.text('2 / 7'), findsWidgets);
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('0.8 / 140 g'), findsOneWidget);
    expect(find.text('6.5 glasses'), findsOneWidget);
    expect(find.text('You logged food on 2 of the last 7 days.'), findsOneWidget);
    expect(
      find.text('Your average calorie intake was below your daily target.'),
      findsOneWidget,
    );
    expect(
      find.text('You averaged 6.5 glasses of water per day.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping History opens the existing HistoryScreen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(profile: _user()));
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Last 7 days'), 200);
    expect(find.byType(HistoryScreen), findsNothing);

    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
