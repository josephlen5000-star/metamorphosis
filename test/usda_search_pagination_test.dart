import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.responses);

  final List<Object> responses;
  final List<Uri> requests = [];
  var _index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final next = responses[_index++];
    final body = next is String ? next : jsonEncode(next);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}

Map<String, dynamic> _food(int id, String description) {
  return {
    'fdcId': id,
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

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> foods,
  required int currentPage,
  required int totalPages,
  int? totalHits,
}) {
  return {
    'foods': foods,
    'currentPage': currentPage,
    'totalPages': totalPages,
    'totalHits': totalHits ?? (totalPages * foods.length),
  };
}

class _MemoryCache {
  final Map<String, List<UsdaSearchResult>> store = {};

  Future<List<UsdaSearchResult>?> read(String query) async {
    return store[query.trim().toLowerCase()];
  }

  Future<void> write(String query, List<UsdaSearchResult> results) async {
    store[query.trim().toLowerCase()] = results;
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
      searchPageSize: 2,
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

Future<void> _typeApple(WidgetTester tester, _ControllableClient client) async {
  await tester.enterText(find.byType(CupertinoTextField), 'apple');
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await client.waitForRequest();
}

Future<void> _loadNextPage(WidgetTester tester) async {
  loadNextUsdaSearchPage(tester.element(find.byType(FoodSearchPopup)));
  await tester.pump();
}

void main() {
  test('searchPage requests the first FDC page and reports remaining pages',
      () async {
    final client = _ScriptedClient([
      _page(
        foods: [_food(1, 'Apples, raw, with skin')],
        currentPage: 1,
        totalPages: 3,
        totalHits: 6,
      ),
    ]);
    final service = UsdaFoodService(httpClient: client, apiKey: 'test-key');

    final page = await service.searchPage('apple', pageSize: 2);

    expect(client.requests.single.queryParameters['pageNumber'], '1');
    expect(client.requests.single.queryParameters['pageSize'], '2');
    expect(page.results.single.item.name, 'Apples, raw, with skin');
    expect(page.results.single.servingLabel, 'Per 100 g');
    expect(page.pageNumber, 1);
    expect(page.totalPages, 3);
    expect(page.totalHits, 6);
    expect(page.hasMore, isTrue);
  });

  test('searchPage requests later pages and stops at totalPages', () async {
    final client = _ScriptedClient([
      _page(
        foods: [_food(3, 'Apple juice, canned')],
        currentPage: 2,
        totalPages: 2,
        totalHits: 4,
      ),
    ]);
    final service = UsdaFoodService(httpClient: client, apiKey: 'test-key');

    final page = await service.searchPage(
      'apple',
      pageSize: 2,
      pageNumber: 2,
    );

    expect(client.requests.single.queryParameters['pageNumber'], '2');
    expect(page.results.single.item.id, 3);
    expect(page.hasMore, isFalse);
  });

  test('search still returns the first page as a FoodItem list', () async {
    final client = _ScriptedClient([
      _page(
        foods: [_food(1, 'Apples, raw, with skin')],
        currentPage: 1,
        totalPages: 1,
      ),
    ]);
    final service = UsdaFoodService(httpClient: client, apiKey: 'test-key');

    final results = await service.search('apple', pageSize: 2);
    expect(results.single.item.name, 'Apples, raw, with skin');
    expect(client.requests.single.queryParameters['pageNumber'], '1');
  });

  testWidgets('first page shows results without requesting the next page', (
    tester,
  ) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.text('Apples, raw, gala'), findsOneWidget);
    expect(client.requests, hasLength(1));
    expect(client.requests.single.queryParameters['pageNumber'], '1');
  });

  testWidgets('loading the next page appends results to the first page', (
    tester,
  ) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    await _loadNextPage(tester);
    await client.waitForRequest();
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsWidgets);
    expect(client.requests.last.queryParameters['pageNumber'], '2');

    client.complete(
      _page(
        foods: [
          _food(3, 'Apple juice, canned'),
          _food(4, 'Apple sauce'),
        ],
        currentPage: 2,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.text('Apple juice, canned'), findsOneWidget);
    expect(find.text('Apple sauce'), findsOneWidget);
    expect(client.requests, hasLength(2));
  });

  testWidgets('scrolling the results list requests the next page', (tester) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.fling(find.byKey(usdaSearchResultsKey), const Offset(0, -400), 1000);
    await tester.pump();
    await client.waitForRequest();
    expect(client.requests.last.queryParameters['pageNumber'], '2');
    client.complete(
      _page(
        foods: [_food(3, 'Apple juice, canned')],
        currentPage: 2,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();
  });

  testWidgets('stops requesting once USDA reports no more pages', (tester) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 1,
      ),
    );
    await tester.pump();
    await tester.pump();

    await _loadNextPage(tester);
    await tester.pump();

    expect(client.requests, hasLength(1));
  });

  testWidgets('does not start a second page request while one is in flight', (
    tester,
  ) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 3,
      ),
    );
    await tester.pump();
    await tester.pump();

    await _loadNextPage(tester);
    await client.waitForRequest();
    await tester.pump();
    await _loadNextPage(tester);
    await tester.pump();

    expect(client.requests, hasLength(2));
    expect(
      client.requests.map((uri) => uri.queryParameters['pageNumber']),
      ['1', '2'],
    );
    client.complete(
      _page(
        foods: [_food(3, 'Apple juice, canned')],
        currentPage: 2,
        totalPages: 3,
      ),
    );
    await tester.pump();
    await tester.pump();
  });

  testWidgets('keeps visible results when a later page fails and retries it', (
    tester,
  ) async {
    final client = _ControllableClient();
    await tester.pumpWidget(_app(UsdaFoodService(httpClient: client, apiKey: 'test')));
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    await _loadNextPage(tester);
    await client.waitForRequest();
    client.completeError();
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.text('Couldn\'t load foods. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await client.waitForRequest();
    expect(client.requests.last.queryParameters['pageNumber'], '2');
    client.complete(
      _page(
        foods: [_food(3, 'Apple juice, canned')],
        currentPage: 2,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Apples, raw, with skin'), findsOneWidget);
    expect(find.text('Apple juice, canned'), findsOneWidget);
    expect(find.text('Couldn\'t load foods. Try again.'), findsNothing);
  });

  testWidgets('caches the combined successful pages under the existing query key',
      (tester) async {
    final client = _ControllableClient();
    final cache = _MemoryCache();
    await tester.pumpWidget(
      _app(
        UsdaFoodService(httpClient: client, apiKey: 'test'),
        cachedSearchLoader: cache.read,
        onCacheSearch: cache.write,
      ),
    );
    await _typeApple(tester, client);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      cache.store['apple']!.map((item) => item.item.name),
      containsAll(['Apples, raw, with skin', 'Apples, raw, gala']),
    );

    await _loadNextPage(tester);
    await client.waitForRequest();
    client.complete(
      _page(
        foods: [_food(3, 'Apple juice, canned')],
        currentPage: 2,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      cache.store['apple']!.map((item) => item.item.name),
      containsAll([
        'Apples, raw, with skin',
        'Apples, raw, gala',
        'Apple juice, canned',
      ]),
    );

    await tester.enterText(find.byType(CupertinoTextField), '');
    await tester.pump();
    await tester.enterText(find.byType(CupertinoTextField), 'APPLE');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await client.waitForRequest();
    await tester.pump();

    expect(find.text('Apple juice, canned'), findsOneWidget);
    client.complete(
      _page(
        foods: [
          _food(1, 'Apples, raw, with skin'),
          _food(2, 'Apples, raw, gala'),
        ],
        currentPage: 1,
        totalPages: 2,
      ),
    );
    await tester.pump();
    await tester.pump();
  });
}
