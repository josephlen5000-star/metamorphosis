import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:metamorphosis/models/food_item.dart';
import 'package:metamorphosis/services/food_database.dart';
import 'package:metamorphosis/services/usda_food_service.dart';
import 'package:metamorphosis/services/usda_search_cache.dart';
import 'package:metamorphosis/widgets/food_search_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

UsdaSearchResult _cachedApple() {
  return UsdaSearchResult(
    item: FoodItem(
      id: 1750340,
      name: 'Apples, raw, with skin',
      calories: 52,
      protein: 0.3,
      carbohydrates: 14,
      fats: 0.2,
      omega6: 0,
      omega3: 0,
    ),
    servingLabel: 'Per 100 g',
    dataType: 'Foundation',
  );
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

class _MemoryCache {
  final Map<String, List<UsdaSearchResult>> store = {};

  Future<List<UsdaSearchResult>?> read(String query) async {
    return store[normalizeUsdaSearchQuery(query)];
  }

  Future<void> write(String query, List<UsdaSearchResult> results) async {
    store[normalizeUsdaSearchQuery(query)] = results;
  }
}

Widget _app(
  UsdaFoodService service, {
  Future<List<UsdaSearchResult>?> Function(String query)? cachedSearchLoader,
  Future<void> Function(String query, List<UsdaSearchResult> results)?
      onCacheSearch,
}) {
  return CupertinoApp(
    home: FoodSearchPopup(
      foodService: service,
      recentFoodsLoader: () async => const [],
      favoriteFoodsLoader: () async => const [],
      savedMealsLoader: () async => const [],
      customFoodsLoader: () async => const [],
      recipesLoader: () async => const [],
      cachedSearchLoader: cachedSearchLoader,
      onCacheSearch: onCacheSearch,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('normalizes capitalization and surrounding whitespace', () {
    expect(normalizeUsdaSearchQuery('  Apple '), 'apple');
    expect(normalizeUsdaSearchQuery('APPLE'), 'apple');
    expect(normalizeUsdaSearchQuery('apple'), 'apple');
  });

  test('does not treat expired cache as fresh', () {
    final cachedAt = DateTime(2026, 8, 1);
    expect(
      isUsdaSearchCacheFresh(cachedAt, now: DateTime(2026, 8, 8)),
      isTrue,
    );
    expect(
      isUsdaSearchCacheFresh(cachedAt, now: DateTime(2026, 8, 8, 0, 0, 1)),
      isFalse,
    );
  });

  test('round-trips cached FoodItem mapping without changing contracts', () {
    final original = _cachedApple();
    final restored = usdaSearchResultFromCacheMap(
      usdaSearchResultToCacheMap(original),
    );

    expect(restored, isNotNull);
    expect(restored!.item.id, original.item.id);
    expect(restored.item.name, original.item.name);
    expect(restored.item.calories, original.item.calories);
    expect(restored.item.protein, original.item.protein);
    expect(restored.servingLabel, original.servingLabel);
    expect(restored.dataType, original.dataType);
  });

  test('successful search is cached and reused under a normalized query', () async {
    final results = [_cachedApple()];
    await FoodDatabase.instance.saveUsdaSearchCache(' Apple', results);

    final cached = await FoodDatabase.instance.getUsdaSearchCache('APPLE');
    expect(cached, isNotNull);
    expect(cached!.single.item.name, 'Apples, raw, with skin');
    expect(cached.single.item.calories, 52);
    expect(cached.single.servingLabel, 'Per 100 g');
  });

  test('failed and empty searches do not create cache entries', () async {
    await FoodDatabase.instance.saveUsdaSearchCache('banana', const []);
    expect(await FoodDatabase.instance.getUsdaSearchCache('banana'), isNull);

    SharedPreferences.setMockInitialValues({});
    expect(await FoodDatabase.instance.getUsdaSearchCache('pear'), isNull);
  });

  test('expired cache is ignored and not reused', () async {
    final results = [_cachedApple()];
    final cachedAt = DateTime(2026, 8, 1);
    await FoodDatabase.instance.saveUsdaSearchCache(
      'apple',
      results,
      now: cachedAt,
    );

    expect(
      await FoodDatabase.instance.getUsdaSearchCache(
        'apple',
        now: cachedAt.add(usdaSearchCacheTtl),
      ),
      isNotNull,
    );
    expect(
      await FoodDatabase.instance.getUsdaSearchCache(
        'apple',
        now: cachedAt.add(usdaSearchCacheTtl).add(const Duration(seconds: 1)),
      ),
      isNull,
    );
  });

  testWidgets('successful search writes cache and a later search shows it first', (
    tester,
  ) async {
    final client = _ControllableClient();
    final cache = _MemoryCache();

    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: client, apiKey: 'test'),
        cachedSearchLoader: cache.read,
        onCacheSearch: cache.write,
      ),
    );

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
    expect(cache.store[normalizeUsdaSearchQuery('APPLE')], isNotEmpty);

    await tester.enterText(find.byType(CupertinoTextField), '');
    await tester.pump();
    await tester.enterText(find.byType(CupertinoTextField), 'APPLE');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(client.requests, hasLength(2));
    await client.waitForRequest();
    client.complete({
      'foods': [_food('Apples, raw, gala')],
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, gala'), findsOneWidget);
    expect(
      cache.store[normalizeUsdaSearchQuery('apple')]!.single.item.name,
      'Apples, raw, gala',
    );
  });

  testWidgets('cached results stay visible when a refresh fails', (tester) async {
    final client = _ControllableClient();
    final cache = _MemoryCache();
    cache.store['apple'] = [_cachedApple()];

    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: client, apiKey: 'test'),
        cachedSearchLoader: cache.read,
        onCacheSearch: cache.write,
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'apple');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);

    client.completeError();
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.text('Couldn\'t load foods. Try again.'), findsNothing);
  });

  testWidgets('failed and empty USDA responses do not write cache', (
    tester,
  ) async {
    final client = _ControllableClient();
    final cache = _MemoryCache();

    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: client, apiKey: 'test'),
        cachedSearchLoader: cache.read,
        onCacheSearch: cache.write,
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'milk');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    client.completeError();
    await tester.pump();
    await tester.pump();

    expect(cache.store, isEmpty);
    expect(find.text('Couldn\'t load foods. Try again.'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'oats');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    client.complete({'foods': <Map<String, dynamic>>[]});
    await tester.pump();
    await tester.pump();

    expect(cache.store, isEmpty);
    expect(find.text('No matching foods found.'), findsOneWidget);
  });
}
