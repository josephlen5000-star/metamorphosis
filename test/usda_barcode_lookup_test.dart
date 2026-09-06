import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:metamorphosis/services/usda_food_service.dart';

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.responses);

  final List<Object> responses;
  final List<Uri> requests = [];
  var _index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final next = responses[_index++];
    if (next is Exception) throw next;
    final body = next is String ? next : jsonEncode(next);
    final status = next is Map && next.containsKey('_status')
        ? next['_status'] as int
        : 200;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
    );
  }
}

Map<String, dynamic> _brandedFood({
  required String gtinUpc,
  String description = 'COLA',
  String brandOwner = 'SODA CO',
  double servingSize = 355,
  String servingSizeUnit = 'ml',
  double energy = 42,
}) {
  return {
    'fdcId': 1847890,
    'description': description,
    'dataType': 'Branded',
    'brandOwner': brandOwner,
    'gtinUpc': gtinUpc,
    'servingSize': servingSize,
    'servingSizeUnit': servingSizeUnit,
    'foodNutrients': [
      {'nutrientId': 1008, 'value': energy, 'unitName': 'KCAL'},
      {'nutrientId': 1003, 'value': 0},
      {'nutrientId': 1005, 'value': 11},
      {'nutrientId': 1004, 'value': 0},
    ],
  };
}

void main() {
  test('looks up branded foods by GTIN and maps the existing serving path',
      () async {
    final client = _ScriptedClient([
      {
        'foods': [
          _brandedFood(gtinUpc: '999999999999'),
          _brandedFood(gtinUpc: '012345678905'),
        ],
      },
    ]);
    final service = UsdaFoodService(httpClient: client, apiKey: 'test-key');

    final result = await service.lookupBarcode('012345678905');

    expect(result, isNotNull);
    expect(result!.item.id, 1847890);
    expect(result.item.name, 'Cola (Soda Co)');
    expect(result.servingLabel, '355 ml serving');
    expect(result.item.calories, 149);
    expect(client.requests.single.queryParameters['query'], '012345678905');
    expect(client.requests.single.queryParametersAll['dataType'], ['Branded']);
  });

  test('returns null when USDA has no matching gtinUpc', () async {
    final service = UsdaFoodService(
      httpClient: _ScriptedClient([
        {
          'foods': [_brandedFood(gtinUpc: '111111111111')],
        },
      ]),
      apiKey: 'test-key',
    );

    expect(await service.lookupBarcode('012345678905'), isNull);
  });

  test('does not treat a name-only search hit as a barcode match', () async {
    final service = UsdaFoodService(
      httpClient: _ScriptedClient([
        {
          'foods': [
            _brandedFood(
              gtinUpc: '',
              description: 'APPLE JUICE',
            ),
          ],
        },
      ]),
      apiKey: 'test-key',
    );

    expect(await service.lookupBarcode('012345678905'), isNull);
  });

  test('throws for an invalid barcode without calling USDA', () async {
    final client = _ScriptedClient([]);
    final service = UsdaFoodService(httpClient: client, apiKey: 'test-key');

    expect(
      () => service.lookupBarcode('not-a-barcode'),
      throwsA(isA<UsdaFoodException>()),
    );
    expect(client.requests, isEmpty);
  });

  test('tries a padded GTIN when the first query is empty', () async {
    final client = _ScriptedClient([
      {'foods': <void>[]},
      {
        'foods': [_brandedFood(gtinUpc: '0012345678905')],
      },
    ]);
    final service = UsdaFoodService(httpClient: client, apiKey: 'test-key');

    final result = await service.lookupBarcode('012345678905');

    expect(result, isNotNull);
    expect(client.requests.length, 2);
    expect(client.requests[1].queryParameters['query'], '0012345678905');
  });

  test('surfaces a USDA network failure', () async {
    final service = UsdaFoodService(
      httpClient: _ScriptedClient([
        {'_status': 500, 'foods': <void>[]},
      ]),
      apiKey: 'test-key',
    );

    expect(
      () => service.lookupBarcode('012345678905'),
      throwsA(isA<UsdaFoodException>()),
    );
  });
}
