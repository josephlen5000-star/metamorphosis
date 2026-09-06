import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../models/food_item.dart';
import '../models/recipe.dart';
import '../models/saved_meal.dart';
import '../services/barcode.dart';
import '../services/barcode_scan.dart';
import '../services/food_database.dart';
import '../services/usda_food_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'custom_food_editor.dart';
import 'recipe_editor.dart';

sealed class FoodPickerResult {
  const FoodPickerResult();
}

class PickedFood extends FoodPickerResult {
  const PickedFood(this.food);

  final FoodItem food;
}

class PickedSavedMeal extends FoodPickerResult {
  const PickedSavedMeal(this.meal);

  final SavedMeal meal;
}

class PickedRecipe extends FoodPickerResult {
  const PickedRecipe(this.recipe);

  final Recipe recipe;
}

const usdaSearchResultsKey = Key('usda-search-results');

@visibleForTesting
void loadNextUsdaSearchPage(BuildContext context) {
  _FoodSearchPopupState? state;
  if (context is StatefulElement && context.state is _FoodSearchPopupState) {
    state = context.state as _FoodSearchPopupState;
  }
  state ??= context.findAncestorStateOfType<_FoodSearchPopupState>();
  unawaited(state?._loadNextPage() ?? Future<void>.value());
}

class FoodSearchPopup extends StatefulWidget {
  const FoodSearchPopup({
    super.key,
    this.pickIngredient = false,
    @visibleForTesting this.foodService,
    @visibleForTesting this.recentFoodsLoader,
    @visibleForTesting this.favoriteFoodsLoader,
    @visibleForTesting this.savedMealsLoader,
    @visibleForTesting this.customFoodsLoader,
    @visibleForTesting this.recipesLoader,
    @visibleForTesting this.onToggleFavorite,
    @visibleForTesting this.onRenameSavedMeal,
    @visibleForTesting this.onDeleteSavedMeal,
    @visibleForTesting this.onSaveCustomFood,
    @visibleForTesting this.onDeleteCustomFood,
    @visibleForTesting this.onSaveRecipe,
    @visibleForTesting this.onDeleteRecipe,
    @visibleForTesting this.cachedSearchLoader,
    @visibleForTesting this.onCacheSearch,
    @visibleForTesting this.barcodeScanner,
    @visibleForTesting this.searchPageSize = 25,
  });

  /// When true, hide create actions, recipes, and saved meals so the
  /// popup can be used to pick a single [FoodItem] ingredient.
  final bool pickIngredient;
  final UsdaFoodService? foodService;
  final Future<List<FoodItem>> Function()? recentFoodsLoader;
  final Future<List<FoodItem>> Function()? favoriteFoodsLoader;
  final Future<List<SavedMeal>> Function()? savedMealsLoader;
  final Future<List<FoodItem>> Function()? customFoodsLoader;
  final Future<List<Recipe>> Function()? recipesLoader;
  final Future<void> Function(FoodItem food)? onToggleFavorite;
  final Future<void> Function(SavedMeal meal, String name)? onRenameSavedMeal;
  final Future<void> Function(SavedMeal meal)? onDeleteSavedMeal;
  final Future<void> Function(FoodItem food)? onSaveCustomFood;
  final Future<void> Function(FoodItem food)? onDeleteCustomFood;
  final Future<void> Function(Recipe recipe)? onSaveRecipe;
  final Future<void> Function(Recipe recipe)? onDeleteRecipe;
  final Future<List<UsdaSearchResult>?> Function(String query)?
      cachedSearchLoader;
  final Future<void> Function(String query, List<UsdaSearchResult> results)?
      onCacheSearch;
  final BarcodeScanner? barcodeScanner;
  final int searchPageSize;

  @override
  State<FoodSearchPopup> createState() => _FoodSearchPopupState();
}

enum _BarcodeUi {
  idle,
  lookingUp,
  notFound,
  invalid,
  permissionDenied,
  unavailable,
  failed,
}

class _FoodSearchPopupState extends State<FoodSearchPopup> {
  static const _searchErrorMessage = 'Couldn\'t load foods. Try again.';
  static const _foodNotFoundMessage = 'Food not found';
  static const _foodNotFoundDetail =
      'This barcode isn\'t in USDA FoodData Central.';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final UsdaFoodService _usdaFoodService;

  List<UsdaSearchResult> _results = [];
  List<FoodItem> _recentFoods = [];
  List<FoodItem> _favoriteFoods = [];
  List<FoodItem> _customFoods = [];
  List<SavedMeal> _savedMeals = [];
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  bool _isLoadingCatalog = true;
  String? _error;
  String? _catalogError;
  Timer? _debounce;
  int _searchGeneration = 0;
  _BarcodeUi _barcodeUi = _BarcodeUi.idle;
  String? _barcodeLookupCode;
  bool _barcodeLookupInFlight = false;
  bool _isLoadingPage = false;
  bool _hasMoreResults = false;
  int _loadedPage = 0;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _usdaFoodService = widget.foodService ?? UsdaFoodService();
    _searchController.addListener(_onSearchChanged);
    _loadSavedFoods();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadSavedFoods({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoadingCatalog = true;
        _catalogError = null;
      });
    }

    try {
      final recentLoader =
          widget.recentFoodsLoader ?? FoodDatabase.instance.getRecentFoods;
      final favoriteLoader =
          widget.favoriteFoodsLoader ?? FoodDatabase.instance.getFavoriteFoods;
      final savedMealsLoader =
          widget.savedMealsLoader ?? FoodDatabase.instance.getSavedMeals;
      final customFoodsLoader =
          widget.customFoodsLoader ?? FoodDatabase.instance.getCustomFoods;
      final recipesLoader =
          widget.recipesLoader ?? FoodDatabase.instance.getRecipes;
      final recent = await recentLoader();
      final favorites = await favoriteLoader();
      final savedMeals = await savedMealsLoader();
      if (!mounted) return;
      setState(() {
        _recentFoods = recent;
        _favoriteFoods = favorites;
        _savedMeals = savedMeals;
      });

      var customFoods = const <FoodItem>[];
      var recipes = const <Recipe>[];
      var catalogFailed = false;
      try {
        customFoods = await customFoodsLoader();
      } catch (_) {
        catalogFailed = true;
      }
      try {
        recipes = await recipesLoader();
      } catch (_) {
        catalogFailed = true;
      }
      if (!mounted) return;
      setState(() {
        _customFoods = customFoods;
        _recipes = recipes;
        _isLoadingCatalog = false;
        _catalogError = catalogFailed
            ? 'Couldn\'t load custom foods or recipes.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCatalog = false;
        if (!_hasIdleLists) {
          _catalogError = 'Couldn\'t load saved foods.';
        }
      });
    }
  }

  bool get _hasIdleLists {
    return _favoriteFoods.isNotEmpty ||
        _recentFoods.isNotEmpty ||
        _customFoods.isNotEmpty ||
        _savedMeals.any((meal) => meal.items.isNotEmpty) ||
        (!widget.pickIngredient &&
            _recipes.any((recipe) => recipe.items.isNotEmpty));
  }

  List<FoodItem> _matchingCustomFoods(String query) {
    final needle = query.toLowerCase();
    return [
      for (final food in _customFoods)
        if (food.name.toLowerCase().contains(needle)) food,
    ];
  }

  List<Recipe> _matchingRecipes(String query) {
    final needle = query.toLowerCase();
    return [
      for (final recipe in _recipes)
        if (recipe.items.isNotEmpty &&
            recipe.name.toLowerCase().contains(needle))
          recipe,
    ];
  }

  bool _isFavorite(FoodItem food) {
    final key = FoodDatabase.foodIdentity(food);
    return _favoriteFoods.any(
      (favorite) => FoodDatabase.foodIdentity(favorite) == key,
    );
  }

  Future<void> _toggleFavorite(FoodItem food) async {
    try {
      final toggle = widget.onToggleFavorite ?? FoodDatabase.instance.toggleFavorite;
      await toggle(food);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current favorite state if persistence fails.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    if (_barcodeUi != _BarcodeUi.idle) {
      setState(() {
        _barcodeUi = _BarcodeUi.idle;
        _barcodeLookupCode = null;
        _barcodeLookupInFlight = false;
      });
    }
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _searchGeneration++;
      setState(() {
        _results = [];
        _isLoading = false;
        _isLoadingPage = false;
        _hasMoreResults = false;
        _loadedPage = 0;
        _error = null;
        _pageError = null;
      });
      return;
    }

    setState(() {});

    if (query.length < 2) return;

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<List<UsdaSearchResult>?> _readCachedResults(String query) async {
    try {
      final loader = widget.cachedSearchLoader;
      if (loader != null) return loader(query);
      if (widget.foodService != null) return null;
      return FoodDatabase.instance.getUsdaSearchCache(query);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedResults(
    String query,
    List<UsdaSearchResult> results,
  ) async {
    if (results.isEmpty) return;
    try {
      final writer = widget.onCacheSearch;
      if (writer != null) {
        await writer(query, results);
        return;
      }
      if (widget.foodService != null) return;
      await FoodDatabase.instance.saveUsdaSearchCache(query, results);
    } catch (_) {
      // Keep search usable if the cache cannot be written.
    }
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _isLoadingPage = false;
      _hasMoreResults = false;
      _loadedPage = 0;
      _error = null;
      _pageError = null;
    });

    var usedNetworkResults = false;
    unawaited(
      _readCachedResults(query)
          .then((cached) {
            if (!mounted ||
                generation != _searchGeneration ||
                usedNetworkResults) {
              return;
            }
            if (cached == null || cached.isEmpty) return;
            setState(() {
              _results = cached;
              _error = null;
            });
          })
          .catchError((_) {}),
    );

    try {
      final page = await _usdaFoodService.searchPage(
        query,
        pageSize: widget.searchPageSize,
        pageNumber: 1,
      );
      usedNetworkResults = true;
      if (page.results.isNotEmpty) {
        unawaited(_writeCachedResults(query, page.results));
      }
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = page.results;
        _loadedPage = page.pageNumber;
        _hasMoreResults = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isLoading = false;
        _hasMoreResults = false;
        if (_results.isEmpty) {
          _error = _searchErrorMessage;
        }
      });
    }
  }

  bool get _canLoadNextPage {
    return !_isLoading &&
        !_isLoadingPage &&
        _hasMoreResults &&
        _pageError == null &&
        _searchController.text.trim().length >= 2;
  }

  Future<void> _loadNextPage() async {
    if (!_canLoadNextPage) return;

    final query = _searchController.text.trim();
    final generation = _searchGeneration;
    final nextPage = _loadedPage + 1;
    setState(() => _isLoadingPage = true);

    try {
      final page = await _usdaFoodService.searchPage(
        query,
        pageSize: widget.searchPageSize,
        pageNumber: nextPage,
      );
      if (!mounted || generation != _searchGeneration) return;

      final combined = _appendUniqueResults(_results, page.results);
      setState(() {
        _results = combined;
        _loadedPage = page.pageNumber;
        _hasMoreResults = page.hasMore;
        _isLoadingPage = false;
        _pageError = null;
      });
      if (combined.isNotEmpty) {
        unawaited(_writeCachedResults(query, combined));
      }
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isLoadingPage = false;
        _pageError = _searchErrorMessage;
      });
    }
  }

  List<UsdaSearchResult> _appendUniqueResults(
    List<UsdaSearchResult> current,
    List<UsdaSearchResult> incoming,
  ) {
    final seen = <int>{
      for (final result in current)
        if (result.item.id != null) result.item.id!,
    };
    return [
      ...current,
      for (final result in incoming)
        if (result.item.id == null || seen.add(result.item.id!)) result,
    ];
  }

  bool _onSearchScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 240) {
      unawaited(_loadNextPage());
    }
    return false;
  }

  void _retrySearch() {
    if (_barcodeUi == _BarcodeUi.failed && _barcodeLookupCode != null) {
      unawaited(_lookupScannedBarcode(_barcodeLookupCode!));
      return;
    }
    if (_pageError != null && _results.isNotEmpty) {
      setState(() => _pageError = null);
      unawaited(_loadNextPage());
      return;
    }
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    _search(query);
  }

  void _returnToSearch() {
    setState(() {
      _barcodeUi = _BarcodeUi.idle;
      _barcodeLookupCode = null;
      _barcodeLookupInFlight = false;
    });
  }

  Future<void> _scanBarcode() async {
    if (_barcodeLookupInFlight) return;
    _searchFocusNode.unfocus();

    final scanner = widget.barcodeScanner ?? scanBarcode;
    final outcome = await scanner(context);
    if (!mounted) return;

    switch (outcome) {
      case BarcodeScanCancelled():
        return;
      case BarcodeScanUnavailable():
        setState(() => _barcodeUi = _BarcodeUi.unavailable);
      case BarcodeScanPermissionDenied():
        setState(() => _barcodeUi = _BarcodeUi.permissionDenied);
      case BarcodeScanned(:final code):
        await _lookupScannedBarcode(code);
    }
  }

  Future<void> _lookupScannedBarcode(String raw) async {
    if (_barcodeLookupInFlight && _barcodeLookupCode == raw) return;

    final parsed = parseUpcEan(raw);
    if (parsed == null) {
      setState(() {
        _barcodeUi = _BarcodeUi.invalid;
        _barcodeLookupCode = raw;
      });
      return;
    }

    setState(() {
      _barcodeUi = _BarcodeUi.lookingUp;
      _barcodeLookupCode = raw;
      _barcodeLookupInFlight = true;
      _error = null;
    });

    try {
      final result = await _usdaFoodService.lookupBarcode(raw);
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(PickedFood(result.item));
        return;
      }
      setState(() {
        _barcodeUi = _BarcodeUi.notFound;
        _barcodeLookupInFlight = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _barcodeUi = _BarcodeUi.failed;
        _barcodeLookupInFlight = false;
        _error = _searchErrorMessage;
      });
    }
  }

  Widget _barcodeStatus() {
    switch (_barcodeUi) {
      case _BarcodeUi.idle:
        return const SizedBox.shrink();
      case _BarcodeUi.lookingUp:
        return _statusMessage(
          message: 'Looking up barcode…',
          loading: true,
        );
      case _BarcodeUi.notFound:
        return _statusMessage(
          message: _foodNotFoundMessage,
          detail: _foodNotFoundDetail,
          onRetry: _returnToSearch,
          retryLabel: 'Back to search',
        );
      case _BarcodeUi.invalid:
        return _statusMessage(
          message: 'Couldn\'t read that barcode.',
          detail: 'Try scanning a UPC or EAN code.',
          onRetry: _returnToSearch,
          retryLabel: 'Back to search',
        );
      case _BarcodeUi.permissionDenied:
        return _statusMessage(
          message: 'Camera access is needed to scan barcodes.',
          onRetry: _returnToSearch,
          retryLabel: 'Back to search',
        );
      case _BarcodeUi.unavailable:
        return _statusMessage(
          message: 'Barcode scanning isn\'t available on this device.',
          onRetry: _returnToSearch,
          retryLabel: 'Back to search',
        );
      case _BarcodeUi.failed:
        return _statusMessage(
          message: _error ?? _searchErrorMessage,
          onRetry: _retrySearch,
        );
    }
  }

  Widget _buildErrorAction({required bool compact}) {
    return _statusMessage(
      message: _error!,
      compact: compact,
      onRetry: _retrySearch,
    );
  }

  Widget _statusMessage({
    required String message,
    String? detail,
    bool compact = false,
    bool loading = false,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const CupertinoActivityIndicator(),
          const SizedBox(height: 12),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppStyle.bodySecondary,
        ),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: AppStyle.meta,
          ),
        ],
        if (onRetry != null)
          CupertinoButton(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : null,
            onPressed: onRetry,
            child: Text(
              retryLabel,
              style: AppStyle.accentAction,
            ),
          ),
      ],
    );
  }

  Widget _idleEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.pickIngredient
                  ? 'Search or pick a food to add to this recipe.'
                  : 'Type to search foods.',
              textAlign: TextAlign.center,
              style: AppStyle.bodySecondary,
            ),
            if (!widget.pickIngredient) ...[
              const SizedBox(height: 8),
              const Text(
                'Or create a custom food or recipe.',
                textAlign: TextAlign.center,
                style: AppStyle.meta,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultBody() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      if (_hasIdleLists) {
        return _buildSavedFoods();
      }
      if (_catalogError != null) {
        return Center(
          child: _statusMessage(
            message: _catalogError!,
            onRetry: () => _loadSavedFoods(showSpinner: true),
          ),
        );
      }
      if (_isLoadingCatalog) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CupertinoActivityIndicator(),
              ),
              _idleEmptyState(),
            ],
          ),
        );
      }
      return _idleEmptyState();
    }

    final customMatches = _matchingCustomFoods(query);
    final recipeMatches =
        widget.pickIngredient ? const <Recipe>[] : _matchingRecipes(query);
    final hasLocalMatches =
        customMatches.isNotEmpty || recipeMatches.isNotEmpty;

    if (query.length < 2 && _results.isEmpty && !hasLocalMatches) {
      return _idleEmptyState();
    }

    if (_results.isEmpty && _error != null && !hasLocalMatches) {
      return Center(child: _buildErrorAction(compact: false));
    }

    if (_results.isEmpty && _isLoading && !hasLocalMatches) {
      return const Center(
        child: Text(
          'Searching…',
          style: AppStyle.bodySecondary,
        ),
      );
    }

    if (_results.isEmpty && !_isLoading && !hasLocalMatches) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No matching foods found.',
            textAlign: TextAlign.center,
            style: AppStyle.bodySecondary,
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onSearchScroll,
      child: CupertinoScrollbar(
        radius: const Radius.circular(12),
        thumbVisibility: true,
        child: ListView(
          key: usdaSearchResultsKey,
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (recipeMatches.isNotEmpty) ...[
              _sectionTitle('Recipes'),
              for (var i = 0; i < recipeMatches.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _recipeCard(recipeMatches[i]),
              ],
              if (customMatches.isNotEmpty || _results.isNotEmpty)
                const SizedBox(height: 24),
            ],
            if (customMatches.isNotEmpty) ...[
              _sectionTitle('Custom foods'),
              for (var i = 0; i < customMatches.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _customFoodCard(customMatches[i], showManageActions: false),
              ],
              if (_results.isNotEmpty) const SizedBox(height: 24),
            ],
            for (var i = 0; i < _results.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _selectableFoodCard(
                result: _results[i],
                onSelect: () => Navigator.of(context).pop(
                  PickedFood(_results[i].item),
                ),
              ),
            ],
            if (_isLoadingPage)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (_pageError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _statusMessage(
                  message: _pageError!,
                  compact: true,
                  onRetry: _retrySearch,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameSavedMeal(SavedMeal meal) async {
    final controller = TextEditingController(text: meal.name);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Rename meal'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'Meal name',
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim(),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == meal.name) return;

    try {
      final rename = widget.onRenameSavedMeal ??
          (saved, nextName) async {
            final id = saved.id;
            if (id == null) {
              throw ArgumentError('Cannot rename a saved meal without an id');
            }
            await FoodDatabase.instance.renameSavedMeal(id, nextName);
          };
      await rename(meal, name);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current saved meals if persistence fails.
    }
  }

  Future<void> _deleteSavedMeal(SavedMeal meal) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete saved meal?'),
        content: Text('Remove ${_clippedName(meal.name)}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      final delete = widget.onDeleteSavedMeal ??
          (saved) async {
            final id = saved.id;
            if (id == null) {
              throw ArgumentError('Cannot delete a saved meal without an id');
            }
            await FoodDatabase.instance.deleteSavedMeal(id);
          };
      await delete(meal);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current saved meals if persistence fails.
    }
  }

  Future<FoodItem?> _pickRecipeIngredient() async {
    final result = await showCupertinoModalPopup<FoodPickerResult>(
      context: context,
      builder: (_) => FoodSearchPopup(
        pickIngredient: true,
        foodService: _usdaFoodService,
        recentFoodsLoader: widget.recentFoodsLoader,
        favoriteFoodsLoader: widget.favoriteFoodsLoader,
        customFoodsLoader: widget.customFoodsLoader,
        savedMealsLoader: () async => const [],
        recipesLoader: () async => const [],
        onToggleFavorite: widget.onToggleFavorite,
      ),
    );
    if (result is PickedFood) return result.food;
    return null;
  }

  Future<void> _createCustomFood() async {
    await _editCustomFood();
  }

  Future<void> _editCustomFood([FoodItem? existing]) async {
    final food = await showCupertinoModalPopup<FoodItem>(
      context: context,
      builder: (_) => CustomFoodEditor(existing: existing),
    );
    if (!mounted || food == null) return;

    try {
      final save = widget.onSaveCustomFood ??
          (next) async {
            if (next.id == null) {
              await FoodDatabase.instance.insertCustomFood(next);
            } else {
              await FoodDatabase.instance.updateCustomFood(next);
            }
          };
      await save(food);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current custom foods if persistence fails.
    }
  }

  Future<void> _deleteCustomFood(FoodItem food) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete custom food?'),
        content: Text('Remove ${_clippedName(food.name)}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      final delete = widget.onDeleteCustomFood ??
          (next) async {
            final id = next.id;
            if (id == null) {
              throw ArgumentError('Cannot delete a custom food without an id');
            }
            await FoodDatabase.instance.deleteCustomFood(id);
          };
      await delete(food);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current custom foods if persistence fails.
    }
  }

  Future<void> _createRecipe() async {
    await _editRecipe();
  }

  Future<void> _editRecipe([Recipe? existing]) async {
    final recipe = await showCupertinoModalPopup<Recipe>(
      context: context,
      builder: (_) => RecipeEditor(
        existing: existing,
        onPickIngredient: _pickRecipeIngredient,
      ),
    );
    if (!mounted || recipe == null) return;

    try {
      final save = widget.onSaveRecipe ??
          (next) async {
            if (next.id == null) {
              await FoodDatabase.instance.insertRecipe(next);
            } else {
              await FoodDatabase.instance.updateRecipe(next);
            }
          };
      await save(recipe);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current recipes if persistence fails.
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Remove ${_clippedName(recipe.name)}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      final delete = widget.onDeleteRecipe ??
          (saved) async {
            final id = saved.id;
            if (id == null) {
              throw ArgumentError('Cannot delete a recipe without an id');
            }
            await FoodDatabase.instance.deleteRecipe(id);
          };
      await delete(recipe);
      if (!mounted) return;
      await _loadSavedFoods();
    } catch (_) {
      // Leave the current recipes if persistence fails.
    }
  }

  String _formatTotal(double value) {
    return value.round().toString();
  }

  String _clippedName(String name, {int maxChars = 80}) {
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars).trimRight()}…';
  }

  String _formatGrams(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(1);
  }

  Widget _iconAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppStyle.iconAction(icon: icon, onPressed: onTap);
  }

  Widget _recipeCard(Recipe recipe) {
    final foodCount = recipe.items.length;
    final foodsLabel = foodCount == 1 ? '1 food' : '$foodCount foods';

    return Stack(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(PickedRecipe(recipe)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 88, 14),
            decoration: _listCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.cardTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  '$foodsLabel · ${_formatTotal(recipe.calories)} kcal',
                  style: AppStyle.bodySecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatGrams(recipe.protein)} g P  ·  '
                  '${_formatGrams(recipe.carbohydrates)} g C  ·  '
                  '${_formatGrams(recipe.fats)} g F',
                  style: AppStyle.meta,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Row(
            children: [
              _iconAction(
                icon: CupertinoIcons.pencil,
                onTap: () => _editRecipe(recipe),
              ),
              _iconAction(
                icon: CupertinoIcons.delete,
                onTap: () => _deleteRecipe(recipe),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customFoodCard(FoodItem food, {required bool showManageActions}) {
    return _selectableFoodCard(
      result: UsdaSearchResult(
        item: food,
        servingLabel: 'Custom · per serving',
      ),
      onSelect: () => Navigator.of(context).pop(PickedFood(food)),
      leadingActions: showManageActions
          ? [
              _iconAction(
                icon: CupertinoIcons.pencil,
                onTap: () => _editCustomFood(food),
              ),
              _iconAction(
                icon: CupertinoIcons.delete,
                onTap: () => _deleteCustomFood(food),
              ),
            ]
          : const [],
    );
  }

  Widget _savedMealCard(SavedMeal meal) {
    final foodCount = meal.items.length;
    final foodsLabel = foodCount == 1 ? '1 food' : '$foodCount foods';

    return Stack(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(PickedSavedMeal(meal)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 72, 14),
            decoration: _listCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.cardTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  '$foodsLabel · ${_formatTotal(meal.calories)} kcal',
                  style: AppStyle.bodySecondary,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              _iconAction(
                icon: CupertinoIcons.pencil,
                onTap: () => _renameSavedMeal(meal),
              ),
              _iconAction(
                icon: CupertinoIcons.delete,
                onTap: () => _deleteSavedMeal(meal),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppStyle.subsectionTitle,
      ),
    );
  }

  Widget _buildSavedFoods() {
    final visibleRecipes = [
      for (final recipe in _recipes)
        if (recipe.items.isNotEmpty) recipe,
    ];
    final visibleSavedMeals = [
      for (final meal in _savedMeals)
        if (meal.items.isNotEmpty) meal,
    ];
    final showRecipes = !widget.pickIngredient && visibleRecipes.isNotEmpty;
    final showSavedMeals = !widget.pickIngredient && visibleSavedMeals.isNotEmpty;
    final showCustomFoods = _customFoods.isNotEmpty;
    final showFavorites = _favoriteFoods.isNotEmpty;
    final showRecent = _recentFoods.isNotEmpty;

    return CupertinoScrollbar(
      radius: const Radius.circular(12),
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (_catalogError != null) ...[
            _statusMessage(
              message: _catalogError!,
              compact: true,
              onRetry: () => _loadSavedFoods(showSpinner: true),
            ),
            const SizedBox(height: 16),
          ],
          if (showRecipes) ...[
            _sectionTitle('Recipes'),
            for (var i = 0; i < visibleRecipes.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _recipeCard(visibleRecipes[i]),
            ],
          ],
          if (showRecipes &&
              (showSavedMeals || showCustomFoods || showFavorites || showRecent))
            const SizedBox(height: 24),
          if (showSavedMeals) ...[
            _sectionTitle('Saved meals'),
            for (var i = 0; i < visibleSavedMeals.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _savedMealCard(visibleSavedMeals[i]),
            ],
          ],
          if (showSavedMeals &&
              (showCustomFoods || showFavorites || showRecent))
            const SizedBox(height: 24),
          if (showCustomFoods) ...[
            _sectionTitle('Custom foods'),
            for (var i = 0; i < _customFoods.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _customFoodCard(_customFoods[i], showManageActions: true),
            ],
          ],
          if (showCustomFoods && (showFavorites || showRecent))
            const SizedBox(height: 24),
          if (showFavorites) ...[
            _sectionTitle('Favorite foods'),
            for (var i = 0; i < _favoriteFoods.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _selectableFoodCard(
                result: UsdaSearchResult(
                  item: _favoriteFoods[i],
                  servingLabel: 'Per serving',
                ),
                onSelect: () => Navigator.of(context).pop(
                  PickedFood(_favoriteFoods[i]),
                ),
              ),
            ],
          ],
          if (showFavorites && showRecent) const SizedBox(height: 24),
          if (showRecent) ...[
            _sectionTitle('Recent foods'),
            for (var i = 0; i < _recentFoods.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _selectableFoodCard(
                result: UsdaSearchResult(
                  item: _recentFoods[i],
                  servingLabel: 'Per serving',
                ),
                onSelect: () => Navigator.of(context).pop(
                  PickedFood(_recentFoods[i]),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _selectableFoodCard({
    required UsdaSearchResult result,
    required VoidCallback onSelect,
    List<Widget> leadingActions = const [],
  }) {
    return Stack(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onSelect,
          child: _FoodResultCard(
            result: result,
            trailingPadding: leadingActions.isEmpty ? 36 : 120,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              ...leadingActions,
              GestureDetector(
                onTap: () => _toggleFavorite(result.item),
                child: Icon(
                  _isFavorite(result.item)
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  size: 22,
                  color: _isFavorite(result.item)
                      ? CupertinoColors.systemRed
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_barcodeUi != _BarcodeUi.idle) {
      return Center(child: _barcodeStatus());
    }

    return Column(
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: CupertinoActivityIndicator(),
          ),
        if (_error != null && _results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildErrorAction(compact: true),
          ),
        Expanded(child: _buildResultBody()),
      ],
    );
  }

  static const _listCardDecoration = AppStyle.card;

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SizedBox(
      width: double.infinity,
      height: media.size.height,
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            bottom: media.viewInsets.bottom == 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.pickIngredient ? 'Add ingredient' : 'Add food',
                          style: AppStyle.pageTitle,
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: _close,
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    placeholder: 'Search foods',
                    decoration: AppStyle.searchField,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(
                        CupertinoIcons.search,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    suffix: _searchController.text.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: _clearSearch,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        onPressed: _scanBarcode,
                        child: const Text(
                          'Scan barcode',
                          style: AppStyle.accentAction,
                        ),
                      ),
                      if (!widget.pickIngredient) ...[
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          onPressed: _createCustomFood,
                          child: const Text(
                            'Create custom food',
                            style: AppStyle.accentAction,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          onPressed: _createRecipe,
                          child: const Text(
                            'Create recipe',
                            style: AppStyle.accentAction,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildResults()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodResultCard extends StatelessWidget {
  const _FoodResultCard({
    required this.result,
    this.trailingPadding = 36,
  });

  final UsdaSearchResult result;
  final double trailingPadding;

  String _formatGrams(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final food = result.item;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, trailingPadding, 14),
      decoration: _FoodSearchPopupState._listCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppStyle.cardTitle,
          ),
          const SizedBox(height: 6),
          Text(
            '${food.calories} kcal · ${result.servingLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyle.bodySecondary,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _macroColumn('Protein', _formatGrams(food.protein)),
              _macroColumn('Carbs', _formatGrams(food.carbohydrates)),
              _macroColumn('Fats', _formatGrams(food.fats)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value g',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
