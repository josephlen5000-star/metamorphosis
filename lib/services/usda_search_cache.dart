import '../models/food_item.dart';
import 'usda_food_service.dart';

/// Successful USDA search hits are reused for this long, then ignored.
const usdaSearchCacheTtl = Duration(days: 7);

String normalizeUsdaSearchQuery(String query) => query.trim().toLowerCase();

class UsdaSearchCacheRecord {
  const UsdaSearchCacheRecord({
    required this.results,
    required this.cachedAt,
  });

  final List<UsdaSearchResult> results;
  final DateTime cachedAt;
}

bool isUsdaSearchCacheFresh(
  DateTime cachedAt, {
  DateTime? now,
  Duration ttl = usdaSearchCacheTtl,
}) {
  final clock = now ?? DateTime.now();
  return !clock.isAfter(cachedAt.add(ttl));
}

Map<String, dynamic> usdaSearchResultToCacheMap(UsdaSearchResult result) {
  return {
    ...result.item.toMap(),
    'servingLabel': result.servingLabel,
    if (result.dataType != null) 'dataType': result.dataType,
  };
}

UsdaSearchResult? usdaSearchResultFromCacheMap(Map<String, dynamic> map) {
  final name = map['name'];
  if (name is! String || name.isEmpty) return null;

  final calories = map['calories'];
  final protein = map['protein'];
  final carbohydrates = map['carbohydrates'];
  final fats = map['fats'];
  final omega6 = map['omega6'];
  final omega3 = map['omega3'];
  if (calories is! num ||
      protein is! num ||
      carbohydrates is! num ||
      fats is! num ||
      omega6 is! num ||
      omega3 is! num) {
    return null;
  }

  return UsdaSearchResult(
    item: FoodItem(
      id: (map['id'] as num?)?.toInt(),
      name: name,
      calories: calories.toInt(),
      protein: protein.toDouble(),
      carbohydrates: carbohydrates.toDouble(),
      fats: fats.toDouble(),
      omega6: omega6.toDouble(),
      omega3: omega3.toDouble(),
    ),
    servingLabel: (map['servingLabel'] as String?) ?? 'Per 100 g',
    dataType: map['dataType'] as String?,
  );
}

Map<String, dynamic> usdaSearchCacheRecordToMap(UsdaSearchCacheRecord record) {
  return {
    'cachedAt': record.cachedAt.millisecondsSinceEpoch,
    'results': [
      for (final result in record.results) usdaSearchResultToCacheMap(result),
    ],
  };
}

UsdaSearchCacheRecord? usdaSearchCacheRecordFromMap(Map<String, dynamic> map) {
  final cachedAtMs = map['cachedAt'];
  final rawResults = map['results'];
  if (cachedAtMs is! num || rawResults is! List) return null;

  final results = <UsdaSearchResult>[];
  for (final item in rawResults) {
    if (item is! Map) continue;
    final result = usdaSearchResultFromCacheMap(Map<String, dynamic>.from(item));
    if (result != null) results.add(result);
  }
  if (results.isEmpty) return null;

  return UsdaSearchCacheRecord(
    results: results,
    cachedAt: DateTime.fromMillisecondsSinceEpoch(cachedAtMs.toInt()),
  );
}

Map<String, dynamic> pruneUsdaSearchCacheMap(
  Map<String, dynamic> map, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final next = <String, dynamic>{};
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final record = usdaSearchCacheRecordFromMap(Map<String, dynamic>.from(value));
    if (record == null) continue;
    if (!isUsdaSearchCacheFresh(record.cachedAt, now: clock)) continue;
    next[entry.key] = value;
  }
  return next;
}
