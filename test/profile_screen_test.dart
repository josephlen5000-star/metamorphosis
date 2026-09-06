import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metamorphosis/models/user.dart';
import 'package:metamorphosis/screens/profile_screen.dart';

User _user({
  String username = 'Ada',
  int? calorieTarget = 2000,
  double? proteinGoal,
  int? waterGoal,
}) {
  return User(
    userId: 'u1',
    username: username,
    age: 25,
    biologicalSex: 'female',
    heightCm: 165,
    weightKg: 60,
    activityLevel: 'sedentary',
    useMetric: true,
    createdAt: DateTime(2026, 1, 1),
    customCalorieTarget: calorieTarget,
    proteinGoal: proteinGoal,
    waterGoal: waterGoal,
  );
}

Widget _app({
  Future<User?> Function()? profileLoader,
  ProfileSaver? profileSaver,
}) {
  return CupertinoApp(
    home: ProfileScreen(
      profileLoader: profileLoader ?? () async => _user(),
      profileSaver: profileSaver,
    ),
  );
}

void main() {
  testWidgets('loads profile fields and optional goal copy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        profileLoader: () async => _user(proteinGoal: 140, waterGoal: 8),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Daily target'), findsOneWidget);
    expect(find.text('2000'), findsWidgets);
    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Activity level'), findsOneWidget);
    expect(find.text('Sedentary'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Nutrition goals'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('Nutrition goals'), findsOneWidget);
    expect(
      find.text(
        'Leave a field blank to use the calculated calorie target or hide that macro goal.',
      ),
      findsOneWidget,
    );
    expect(find.text('140'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Water'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('Water'), findsOneWidget);
    expect(
      find.text('Leave blank to keep the default of 8 glasses a day.'),
      findsOneWidget,
    );
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('shows a friendly loading state', (tester) async {
    final completer = Completer<User?>();
    await tester.pumpWidget(_app(profileLoader: () => completer.future));
    await tester.pump();
    expect(find.text('Loading profile...'), findsOneWidget);
    completer.complete(_user());
    await tester.pump();
    await tester.pump();
  });

  testWidgets('shows a friendly error state with retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        profileLoader: () async {
          attempts += 1;
          if (attempts == 1) return null;
          return _user();
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Couldn\'t load your profile.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('cancel pops without saving', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => ProfileScreen(
                    profileLoader: () async => _user(),
                    profileSaver: ({
                      required userId,
                      required username,
                      required age,
                      required biologicalSex,
                      required heightCm,
                      required weightKg,
                      required activityLevel,
                      required useMetric,
                      customCalorieTarget,
                      proteinGoal,
                      carbohydrateGoal,
                      fatGoal,
                      waterGoal,
                    }) async {
                      saved = true;
                    },
                  ),
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
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('save keeps the existing profile persistence arguments', (
    tester,
  ) async {
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => ProfileScreen(
                    profileLoader: () async => _user(),
                    profileSaver: ({
                      required userId,
                      required username,
                      required age,
                      required biologicalSex,
                      required heightCm,
                      required weightKg,
                      required activityLevel,
                      required useMetric,
                      customCalorieTarget,
                      proteinGoal,
                      carbohydrateGoal,
                      fatGoal,
                      waterGoal,
                    }) async {
                      saved = {
                        'userId': userId,
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
                      };
                    },
                  ),
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
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, {
      'userId': 'u1',
      'username': 'Ada',
      'age': 25,
      'biologicalSex': 'female',
      'heightCm': 165,
      'weightKg': 60,
      'activityLevel': 'sedentary',
      'useMetric': true,
      'customCalorieTarget': 2000,
      'proteinGoal': null,
      'carbohydrateGoal': null,
      'fatGoal': null,
      'waterGoal': null,
    });
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('rejects a zero calorie target without saving', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var saved = false;
    await tester.pumpWidget(
      _app(
        profileSaver: ({
          required userId,
          required username,
          required age,
          required biologicalSex,
          required heightCm,
          required weightKg,
          required activityLevel,
          required useMetric,
          customCalorieTarget,
          proteinGoal,
          carbohydrateGoal,
          fatGoal,
          waterGoal,
        }) async {
          saved = true;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Custom calorie target'),
      240,
      scrollable: scrollable,
    );
    await tester.enterText(find.widgetWithText(CupertinoTextField, '2000'), '0');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text('Enter a valid calorie target or leave it blank.'),
      findsOneWidget,
    );
    expect(saved, isFalse);
  });

  testWidgets('rejects a negative macro goal without saving', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var saved = false;
    await tester.pumpWidget(
      _app(
        profileLoader: () async => _user(proteinGoal: 140),
        profileSaver: ({
          required userId,
          required username,
          required age,
          required biologicalSex,
          required heightCm,
          required weightKg,
          required activityLevel,
          required useMetric,
          customCalorieTarget,
          proteinGoal,
          carbohydrateGoal,
          fatGoal,
          waterGoal,
        }) async {
          saved = true;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Protein goal'),
      240,
      scrollable: scrollable,
    );
    await tester.enterText(find.widgetWithText(CupertinoTextField, '140'), '-5');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text('Enter a valid protein goal or leave it blank.'),
      findsOneWidget,
    );
    expect(saved, isFalse);
  });
}
