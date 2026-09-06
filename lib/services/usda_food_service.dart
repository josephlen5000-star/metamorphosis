import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food_item.dart';
import 'barcode.dart';

/// USDA FoodData Central nutrient IDs used by the search mapper.
const int _energyKcalId = 1008;
const int _proteinId = 1003;
const int _carbohydrateId = 1005;
const int _fatId = 1004;

/// 18:2 n-6 c,c (linoleic), preferred when present.
const int _omega6LinoleicId = 1316;

/// PUFA 18:2 undifferentiated, common on SR Legacy / Survey search hits.
const int _omega6LinoleicUndiffId = 1269;

/// 18:3 n-6 c,c,c (GLA).
const int _omega6GlaId = 1326;

/// 20:4 n-6, preferred when present.
const int _omega6ArachidonicId = 1333;

/// PUFA 20:4 undifferentiated (arachidonic).
const int _omega6ArachidonicUndiffId = 1271;

/// 18:3 n-3 c,c,c (ALA), preferred when present.
const int _omega3AlaId = 1404;

/// PUFA 18:3 undifferentiated, common on SR Legacy / Survey search hits.
const int _omega3AlaUndiffId = 1270;

const int _omega3EpaId = 1278;
const int _omega3DhaId = 1272;
const int _omega3DpaId = 1280;

const _wordSplitPattern = r'[^a-z0-9%]+';
const _letterPattern = r'[A-Za-z]';
const _titleCaseBoundaryPattern = r'''[\s\-/\'&]''';

class UsdaFoodException implements Exception {
  const UsdaFoodException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One USDA search hit: a [FoodItem] plus display-only serving context.
class UsdaSearchResult {
  const UsdaSearchResult({
    required this.item,
    required this.servingLabel,
    this.dataType,
  });

  final FoodItem item;
  final String servingLabel;
  final String? dataType;
}

/// One FDC search page. [pageNumber] is the API's 1-based page.
class UsdaSearchPage {
  const UsdaSearchPage({
    required this.results,
    required this.pageNumber,
    required this.totalPages,
    required this.totalHits,
    required this.hasMore,
  });

  final List<UsdaSearchResult> results;
  final int pageNumber;
  final int totalPages;
  final int totalHits;
  final bool hasMore;
}

/// Searches USDA FoodData Central and maps hits onto [FoodItem].
///
/// Provide the API key at build time:
/// `flutter run --dart-define=USDA_API_KEY=...`
class UsdaFoodService {
  UsdaFoodService({
    http.Client? httpClient,
    String? apiKey,
  })  : _httpClient = httpClient ?? http.Client(),
        _apiKey = apiKey ?? const String.fromEnvironment('USDA_API_KEY');

  static const _host = 'api.nal.usda.gov';
  static const _searchPath = '/fdc/v1/foods/search';
  static const _searchDataTypes = [
    'Foundation',
    'SR Legacy',
    'Survey (FNDDS)',
    'Branded',
  ];

  final http.Client _httpClient;
  final String _apiKey;

  /// Full-text search of the first page. An empty query returns no results.
  Future<List<UsdaSearchResult>> search(
    String query, {
    int pageSize = 25,
  }) async {
    final page = await searchPage(query, pageSize: pageSize);
    return page.results;
  }

  /// One page of FDC search hits. [pageNumber] is 1-based.
  Future<UsdaSearchPage> searchPage(
    String query, {
    int pageSize = 25,
    int pageNumber = 1,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const UsdaSearchPage(
        results: [],
        pageNumber: 1,
        totalPages: 0,
        totalHits: 0,
        hasMore: false,
      );
    }

    if (_apiKey.isEmpty) {
      throw const UsdaFoodException(
        'USDA_API_KEY is missing. Pass --dart-define=USDA_API_KEY=...',
      );
    }

    final clampedPage = pageNumber < 1 ? 1 : pageNumber;
    final response = await _fetchSearchResponse(
      trimmed,
      dataTypes: _searchDataTypes,
      pageSize: pageSize,
      pageNumber: clampedPage,
    );

    final results = <UsdaSearchResult>[];
    for (final food in response.foods) {
      final item = mapSearchResult(food);
      if (item != null) results.add(item);
    }
    _rankResults(trimmed, results);

    final currentPage = response.currentPage ?? clampedPage;
    final totalPages = response.totalPages ??
        _inferredTotalPages(
          totalHits: response.totalHits,
          pageSize: pageSize,
          currentPage: currentPage,
          rawCount: response.foods.length,
        );
    final hasMore = response.foods.isNotEmpty && currentPage < totalPages;

    return UsdaSearchPage(
      results: results,
      pageNumber: currentPage,
      totalPages: totalPages,
      totalHits: response.totalHits ?? results.length,
      hasMore: hasMore,
    );
  }

  /// Looks up a UPC/EAN using FDC branded foods (`gtinUpc`).
  ///
  /// Returns null when the code is valid but USDA has no matching food.
  /// Throws [UsdaFoodException] for a missing API key or network failure.
  Future<UsdaSearchResult?> lookupBarcode(String raw) async {
    final parsed = parseUpcEan(raw);
    if (parsed == null) {
      throw const UsdaFoodException('Invalid barcode.');
    }

    if (_apiKey.isEmpty) {
      throw const UsdaFoodException(
        'USDA_API_KEY is missing. Pass --dart-define=USDA_API_KEY=...',
      );
    }

    for (final query in parsed.lookupQueries) {
      final foods = await _fetchFoods(
        query,
        dataTypes: const ['Branded'],
        pageSize: 25,
      );
      for (final food in foods) {
        final gtin = food['gtinUpc']?.toString();
        final matches = gtinMatches(gtin, parsed.digits) ||
            parsed.lookupQueries.any(
              (candidate) => gtinMatches(gtin, candidate),
            );
        if (!matches) continue;
        final mapped = mapSearchResult(food);
        if (mapped != null) return mapped;
      }
      if (foods.isNotEmpty) return null;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchFoods(
    String query, {
    required List<String> dataTypes,
    int pageSize = 25,
  }) async {
    final response = await _fetchSearchResponse(
      query,
      dataTypes: dataTypes,
      pageSize: pageSize,
    );
    return response.foods;
  }

  Future<_FdcSearchResponse> _fetchSearchResponse(
    String query, {
    required List<String> dataTypes,
    int pageSize = 25,
    int? pageNumber,
  }) async {
    final clampedPageSize = pageSize.clamp(1, 200);
    final uri = Uri.https(_host, _searchPath, {
      'api_key': _apiKey,
      'query': query,
      'pageSize': '$clampedPageSize',
      'dataType': dataTypes,
      if (pageNumber != null) 'pageNumber': '$pageNumber',
    });

    final response = await _httpClient.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw UsdaFoodException(
        'USDA FoodData Central search failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UsdaFoodException(
        'USDA FoodData Central returned an unexpected response.',
      );
    }

    final body = Map<String, dynamic>.from(decoded);
    final foods = body['foods'];
    return _FdcSearchResponse(
      foods: [
        if (foods is List)
          for (final food in foods)
            if (food is Map) Map<String, dynamic>.from(food),
      ],
      currentPage: _asInt(body['currentPage']),
      totalPages: _asInt(body['totalPages']),
      totalHits: _asInt(body['totalHits']),
    );
  }

  int _inferredTotalPages({
    required int? totalHits,
    required int pageSize,
    required int currentPage,
    required int rawCount,
  }) {
    if (totalHits != null && pageSize > 0) {
      final pages = (totalHits + pageSize - 1) ~/ pageSize;
      return pages < 1 ? 1 : pages;
    }
    if (rawCount >= pageSize) return currentPage + 1;
    return currentPage;
  }

  /// Maps one FDC search hit to a display wrapper around [FoodItem].
  UsdaSearchResult? mapSearchResult(Map<String, dynamic> food) {
    final item = mapSearchFood(food);
    if (item == null) return null;

    final rawType = food['dataType'];
    return UsdaSearchResult(
      item: item,
      servingLabel: _servingLabel(food),
      dataType: rawType is String ? rawType : null,
    );
  }

  /// Maps one FDC search hit to [FoodItem]. Returns null without an id or name.
  ///
  /// Nutrition is stored as one serving:
  /// * Branded foods with a gram/ml `servingSize` are scaled from per-100g
  ///   search values onto the labeled serving.
  /// * Foundation, SR Legacy, Survey, and branded rows without a usable
  ///   serving size keep per-100g values (100g = 1 serving).
  FoodItem? mapSearchFood(Map<String, dynamic> food) {
    final fdcId = _asInt(food['fdcId']);
    final name = _displayName(food);
    if (fdcId == null || name.isEmpty) return null;

    final nutrients = _nutrientMap(food['foodNutrients']);
    final factor = _servingFactor(food);

    return FoodItem(
      id: fdcId,
      name: name,
      calories: (_energyKcal(nutrients) * factor).round(),
      protein: _value(nutrients, _proteinId) * factor,
      carbohydrates: _value(nutrients, _carbohydrateId) * factor,
      fats: _value(nutrients, _fatId) * factor,
      omega6: _omega6(nutrients) * factor,
      omega3: _omega3(nutrients) * factor,
    );
  }

  String _displayName(Map<String, dynamic> food) {
    final description = _readableText(
      (food['description'] as String?)?.trim() ?? '',
    );
    if (description.isEmpty) return '';

    final brand = _readableText((food['brandOwner'] as String?)?.trim() ?? '');
    if (brand.isEmpty) return description;
    return '$description ($brand)';
  }

  String _readableText(String value) {
    if (value.isEmpty || !_isMostlyUpperCase(value)) return value;
    return _toTitleCase(value);
  }

  bool _isMostlyUpperCase(String value) {
    var letters = 0;
    var uppers = 0;
    for (final unit in value.runes) {
      final char = String.fromCharCode(unit);
      if (!RegExp(_letterPattern).hasMatch(char)) continue;
      letters++;
      if (char == char.toUpperCase() && char != char.toLowerCase()) {
        uppers++;
      }
    }
    if (letters < 2) return false;
    return uppers / letters >= 0.8;
  }

  String _toTitleCase(String value) {
    final buffer = StringBuffer();
    var capitalizeNext = true;
    for (final unit in value.runes) {
      final char = String.fromCharCode(unit);
      if (RegExp(_letterPattern).hasMatch(char)) {
        buffer.write(capitalizeNext ? char.toUpperCase() : char.toLowerCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        capitalizeNext = RegExp(_titleCaseBoundaryPattern).hasMatch(char);
      }
    }
    return buffer.toString();
  }

  ({double size, String unit})? _brandedGramOrMlServing(
    Map<String, dynamic> food,
  ) {
    final dataType = (food['dataType'] as String?)?.toLowerCase() ?? '';
    if (dataType != 'branded') return null;

    final size = (food['servingSize'] as num?)?.toDouble();
    final unit = (food['servingSizeUnit'] as String?)?.toLowerCase();
    if (size == null || size <= 0 || unit == null) return null;
    if (unit == 'g' ||
        unit == 'gram' ||
        unit == 'grams' ||
        unit == 'ml' ||
        unit == 'mlt') {
      return (size: size, unit: unit);
    }
    return null;
  }

  double _servingFactor(Map<String, dynamic> food) {
    final serving = _brandedGramOrMlServing(food);
    if (serving == null) return 1.0;
    return serving.size / 100.0;
  }

  String _servingLabel(Map<String, dynamic> food) {
    final serving = _brandedGramOrMlServing(food);
    if (serving == null) return 'Per 100 g';

    final sizeLabel = _formatServingSize(serving.size);
    final unitLabel =
        serving.unit == 'ml' || serving.unit == 'mlt' ? 'ml' : 'g';
    return '$sizeLabel $unitLabel serving';
  }

  String _formatServingSize(double size) {
    final rounded = size.round();
    if ((size - rounded).abs() < 0.05) return '$rounded';
    return size.toStringAsFixed(1);
  }

  void _rankResults(String query, List<UsdaSearchResult> results) {
    results.sort((a, b) {
      final scoreCompare = _relevanceScore(query, b).compareTo(
        _relevanceScore(query, a),
      );
      if (scoreCompare != 0) return scoreCompare;
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
  }

  double _relevanceScore(String query, UsdaSearchResult result) {
    final generic = !_isBranded(result.dataType);
    final close = _closelyMatches(query, result.item.name);
    var score = _nameMatchScore(query, result.item.name);
    if (generic && close) score += 1000;
    score += _dataTypeBonus(result.dataType);
    return score;
  }

  bool _isBranded(String? dataType) {
    return (dataType ?? '').toLowerCase() == 'branded';
  }

  double _dataTypeBonus(String? dataType) {
    switch ((dataType ?? '').toLowerCase()) {
      case 'foundation':
        return 3;
      case 'sr legacy':
        return 2;
      case 'survey (fndds)':
      case 'survey':
        return 1;
      default:
        return 0;
    }
  }

  bool _closelyMatches(String query, String name) {
    final queryWords = _words(query);
    if (queryWords.isEmpty) return false;

    final headWords = _words(_nameHead(name));
    if (headWords.isEmpty) return false;

    return queryWords.every(
      (queryWord) => headWords.any(
        (headWord) => _sameFoodWord(queryWord, headWord),
      ),
    );
  }

  double _nameMatchScore(String query, String name) {
    final queryWords = _words(query);
    final head = _nameHead(name);
    final headWords = _words(head);
    if (queryWords.isEmpty || headWords.isEmpty) return 0;

    if (_normalize(head) == _normalize(query)) return 100;
    if (headWords.length == queryWords.length &&
        _listEquals(
          headWords,
          queryWords,
          _sameFoodWord,
        )) {
      return 95;
    }
    if (headWords.length == 1 &&
        queryWords.length == 1 &&
        _sameFoodWord(headWords.first, queryWords.first)) {
      return 90;
    }

    var score = 0.0;
    if (queryWords.every(
      (queryWord) => headWords.any(
        (headWord) => _sameFoodWord(queryWord, headWord),
      ),
    )) {
      score = 70;
      score -= (headWords.length - queryWords.length).clamp(0, 20) * 2;
    } else if (_normalize(name).contains(_normalize(query))) {
      score = 30;
    }

    final full = _normalize(name);
    if (full.contains(', raw') ||
        full.contains(' raw') ||
        full.startsWith('raw ')) {
      score += 5;
    }
    return score;
  }

  String _nameHead(String name) {
    var trimmed = name.trim();
    final paren = trimmed.lastIndexOf(' (');
    if (paren != -1 && trimmed.endsWith(')')) {
      trimmed = trimmed.substring(0, paren);
    }
    return trimmed.split(',').first.trim();
  }

  String _normalize(String value) => value.toLowerCase().trim();

  List<String> _words(String value) {
    return _normalize(value)
        .split(RegExp(_wordSplitPattern))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  bool _sameFoodWord(String left, String right) {
    if (left == right) return true;
    if (left.length < 3 || right.length < 3) return false;
    if (left == '${right}s' || right == '${left}s') return true;
    if (left.endsWith('es') && left.substring(0, left.length - 2) == right) {
      return true;
    }
    if (right.endsWith('es') && right.substring(0, right.length - 2) == left) {
      return true;
    }
    return false;
  }

  bool _listEquals(
    List<String> left,
    List<String> right,
    bool Function(String, String) equals,
  ) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!equals(left[i], right[i])) return false;
    }
    return true;
  }

  Map<int, _NutrientReading> _nutrientMap(Object? raw) {
    final result = <int, _NutrientReading>{};
    if (raw is! List) return result;

    for (final item in raw) {
      if (item is! Map) continue;
      final nutrient = Map<String, dynamic>.from(item);
      final id = _nutrientId(nutrient);
      final amount = _nutrientAmount(nutrient);
      if (id == null || amount == null) continue;
      result[id] = _NutrientReading(
        amount: amount,
        unitName: (nutrient['unitName'] as String?)?.toUpperCase(),
      );
    }
    return result;
  }

  int? _nutrientId(Map<String, dynamic> nutrient) {
    final id = _asInt(nutrient['nutrientId']);
    if (id != null) return id;

    final nested = nutrient['nutrient'];
    if (nested is Map) {
      return _asInt(nested['id']);
    }
    return null;
  }

  double? _nutrientAmount(Map<String, dynamic> nutrient) {
    final value = nutrient['value'] ?? nutrient['amount'];
    if (value is num) return value.toDouble();
    return null;
  }

  double _energyKcal(Map<int, _NutrientReading> nutrients) {
    final reading = nutrients[_energyKcalId];
    if (reading == null) return 0;
    final unit = reading.unitName;
    if (unit == 'KJ') return 0;
    return reading.amount;
  }

  double _omega6(Map<int, _NutrientReading> nutrients) {
    final linoleic = nutrients.containsKey(_omega6LinoleicId)
        ? _value(nutrients, _omega6LinoleicId)
        : _value(nutrients, _omega6LinoleicUndiffId);
    final arachidonic = nutrients.containsKey(_omega6ArachidonicId)
        ? _value(nutrients, _omega6ArachidonicId)
        : _value(nutrients, _omega6ArachidonicUndiffId);
    return linoleic + arachidonic + _value(nutrients, _omega6GlaId);
  }

  double _omega3(Map<int, _NutrientReading> nutrients) {
    final ala = nutrients.containsKey(_omega3AlaId)
        ? _value(nutrients, _omega3AlaId)
        : _value(nutrients, _omega3AlaUndiffId);
    return ala +
        _value(nutrients, _omega3EpaId) +
        _value(nutrients, _omega3DhaId) +
        _value(nutrients, _omega3DpaId);
  }

  double _value(Map<int, _NutrientReading> nutrients, int id) {
    return nutrients[id]?.amount ?? 0;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

class _NutrientReading {
  const _NutrientReading({required this.amount, this.unitName});

  final double amount;
  final String? unitName;
}

class _FdcSearchResponse {
  const _FdcSearchResponse({
    required this.foods,
    this.currentPage,
    this.totalPages,
    this.totalHits,
  });

  final List<Map<String, dynamic>> foods;
  final int? currentPage;
  final int? totalPages;
  final int? totalHits;
}
