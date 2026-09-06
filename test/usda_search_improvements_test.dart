import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:metamorphosis/services/usda_food_service.dart';

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.body, {this.onRequest});

  final String body;
  final void Function(http.BaseRequest request)? onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest?.call(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}

Map<String, dynamic> _food({
  required int id,
  required String description,
  required String dataType,
  String? brandOwner,
  double? servingSize,
  String? servingSizeUnit,
  double energy = 52,
}) {
  return {
    'fdcId': id,
    'description': description,
    'dataType': dataType,
    'brandOwner': ?brandOwner,
    'servingSize': ?servingSize,
    'servingSizeUnit': ?servingSizeUnit,
    'foodNutrients': [
      {'nutrientId': 1008, 'value': energy, 'unitName': 'KCAL'},
      {'nutrientId': 1003, 'value': 0.3},
      {'nutrientId': 1005, 'value': 14},
      {'nutrientId': 1004, 'value': 0.2},
    ],
  };
}

void main() {
  test('requests Foundation, SR Legacy, Survey, and Branded', () async {
    late Uri uri;
    final service = UsdaFoodService(
      httpClient: _ScriptedClient(
        jsonEncode({'foods': []}),
        onRequest: (request) => uri = request.url,
      ),
      apiKey: 'test-key',
    );

    await service.search('apple');

    expect(uri.queryParametersAll['dataType'], [
      'Foundation',
      'SR Legacy',
      'Survey (FNDDS)',
      'Branded',
    ]);
  });

  test('ranks generic close matches ahead of branded products', () async {
    final service = UsdaFoodService(
      httpClient: _ScriptedClient(
        jsonEncode({
          'foods': [
            _food(
              id: 1,
              description: 'APPLE SLICES',
              dataType: 'Branded',
              brandOwner: 'SNACK CO',
              servingSize: 28,
              servingSizeUnit: 'g',
              energy: 200,
            ),
            _food(
              id: 2,
              description: 'Apples, raw, with skin',
              dataType: 'Foundation',
            ),
            _food(
              id: 3,
              description: 'Apple juice, canned or bottled, unsweetened',
              dataType: 'SR Legacy',
            ),
            _food(
              id: 4,
              description: 'Pineapple, raw',
              dataType: 'Foundation',
            ),
          ],
        }),
      ),
      apiKey: 'test-key',
    );

    final results = await service.search('apple');
    expect(results.map((r) => r.item.id).toList(), [2, 3, 1, 4]);
    expect(results.first.item.name, 'Apples, raw, with skin');
    expect(results.first.servingLabel, 'Per 100 g');
    expect(results[2].item.name, 'Apple Slices (Snack Co)');
    expect(results[2].servingLabel, '28 g serving');
    expect(results[2].item.calories, 56);
  });

  test('title-cases ALL-CAPS names and keeps mixed-case names', () {
    final service = UsdaFoodService(apiKey: 'test-key');
    final branded = service.mapSearchResult(
      _food(
        id: 10,
        description: 'CHEDDAR CHEESE',
        dataType: 'Branded',
        brandOwner: 'KRAFT HEINZ FOODS COMPANY',
        servingSize: 28,
        servingSizeUnit: 'g',
      ),
    );
    final generic = service.mapSearchResult(
      _food(
        id: 11,
        description: 'Apples, raw, with skin',
        dataType: 'Foundation',
      ),
    );

    expect(branded!.item.name, 'Cheddar Cheese (Kraft Heinz Foods Company)');
    expect(generic!.item.name, 'Apples, raw, with skin');
  });

  test('ranks generic chicken and milk ahead of branded close matches', () async {
    Future<List<UsdaSearchResult>> search(
      String query,
      List<Map<String, dynamic>> foods,
    ) {
      return UsdaFoodService(
        httpClient: _ScriptedClient(jsonEncode({'foods': foods})),
        apiKey: 'test-key',
      ).search(query);
    }

    final chicken = await search('chicken', [
      _food(
        id: 30,
        description: 'CHICKEN NUGGETS',
        dataType: 'Branded',
        brandOwner: 'Tyson Foods, Inc.',
        servingSize: 84,
        servingSizeUnit: 'g',
        energy: 250,
      ),
      _food(
        id: 31,
        description: 'Chicken, broilers or fryers, meat only, raw',
        dataType: 'Foundation',
        energy: 119,
      ),
    ]);
    expect(chicken.first.item.id, 31);
    expect(chicken.first.servingLabel, 'Per 100 g');
    expect(chicken.last.item.name, 'Chicken Nuggets (Tyson Foods, Inc.)');

    final milk = await search('milk', [
      _food(
        id: 32,
        description: 'WHOLE MILK',
        dataType: 'Branded',
        brandOwner: 'DAIRY FARM',
        servingSize: 240,
        servingSizeUnit: 'ml',
        energy: 61,
      ),
      _food(
        id: 33,
        description: 'Milk, whole, 3.25% milkfat',
        dataType: 'SR Legacy',
        energy: 61,
      ),
    ]);
    expect(milk.first.item.id, 33);
    expect(milk.first.item.name, 'Milk, whole, 3.25% milkfat');
    expect(milk.last.servingLabel, '240 ml serving');
  });

  test('serving label follows the same branded gram/ml scaling rules', () {
    final service = UsdaFoodService(apiKey: 'test-key');
    final branded = service.mapSearchResult(
      _food(
        id: 20,
        description: 'MILK',
        dataType: 'Branded',
        servingSize: 240,
        servingSizeUnit: 'ml',
        energy: 42,
      ),
    );
    final generic = service.mapSearchResult(
      _food(
        id: 21,
        description: 'Milk, whole, 3.25% milkfat',
        dataType: 'Survey (FNDDS)',
        energy: 61,
      ),
    );

    expect(branded!.servingLabel, '240 ml serving');
    expect(branded.item.calories, 101);
    expect(generic!.servingLabel, 'Per 100 g');
    expect(generic.item.calories, 61);
  });
}
