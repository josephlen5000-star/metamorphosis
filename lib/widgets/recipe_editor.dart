import 'package:flutter/cupertino.dart';

import '../models/food_item.dart';
import '../models/recipe.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

class RecipeEditor extends StatefulWidget {
  const RecipeEditor({
    super.key,
    this.existing,
    required this.onPickIngredient,
  });

  final Recipe? existing;
  final Future<FoodItem?> Function() onPickIngredient;

  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  late final TextEditingController _nameController;
  late final List<RecipeItem> _items;
  late final List<RecipeItem> _initialItems;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _items = [
      if (existing != null)
        for (final item in existing.items) item,
    ];
    _initialItems = List<RecipeItem>.from(_items);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Recipe _draft() {
    return Recipe(
      id: widget.existing?.id,
      name: _nameController.text.trim(),
      items: List<RecipeItem>.from(_items),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
  }

  bool get _isDirty {
    if (_nameController.text.trim() != (widget.existing?.name ?? '')) {
      return true;
    }
    if (_items.length != _initialItems.length) return true;
    for (var i = 0; i < _items.length; i++) {
      final current = _items[i];
      final initial = _initialItems[i];
      if (current.food.id != initial.food.id ||
          current.food.name != initial.food.name ||
          current.servings != initial.servings) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addIngredient() async {
    final food = await widget.onPickIngredient();
    if (!mounted || food == null) return;
    setState(() {
      _items.add(RecipeItem(food: food, servings: 1));
      _error = null;
    });
  }

  Future<void> _removeIngredient(int index) async {
    final name = _items[index].food.name;
    final shouldRemove = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Remove ingredient?'),
        content: Text(
          'Remove ${_clippedName(name)} from this recipe?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;
    setState(() => _items.removeAt(index));
  }

  void _setServings(int index, double servings) {
    setState(() {
      _items[index] = _items[index].copyWith(servings: servings);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (!Recipe.canSave(name: name, items: _items)) {
      setState(() {
        _error = name.isEmpty
            ? 'Enter a recipe name.'
            : 'Add at least one ingredient.';
      });
      return;
    }
    Navigator.of(context).pop(_draft());
  }

  Future<void> _close() async {
    if (_isDirty) {
      final shouldDiscard = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your edits will not be saved.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (shouldDiscard != true || !mounted) return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  String _formatTotal(double value) {
    return value.round().toString();
  }

  String _formatGrams(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(1);
  }

  String _clippedName(String name, {int maxChars = 80}) {
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars).trimRight()}…';
  }

  String _servingsLabel(double servings) {
    return servings == 1
        ? '1 serving'
        : '${servings.toStringAsFixed(0)} servings';
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: AppStyle.fieldLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final draft = _draft();
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
                          _isEditing ? 'Edit recipe' : 'Create recipe',
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: _recipeCardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Recipe name'),
                              CupertinoTextField(
                                controller: _nameController,
                                placeholder: 'Recipe name',
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: AppStyle.field,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Ingredients',
                                style: AppStyle.subsectionTitle,
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              onPressed: _addIngredient,
                              child: const Text(
                                'Add food',
                                style: AppStyle.accentAction,
                              ),
                            ),
                          ],
                        ),
                        if (_items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                            decoration: _recipeCardDecoration,
                            child: const Text(
                              'Select foods and servings. Nutrition is calculated from those items.',
                              style: AppStyle.bodySecondary,
                            ),
                          ),
                        for (var i = 0; i < _items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _ingredientCard(i, _items[i]),
                        ],
                        if (_items.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _nutritionSummary(draft),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nutritionSummary(Recipe draft) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _recipeCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recipe total',
            style: AppStyle.fieldLabel,
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatTotal(draft.calories)} kcal',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatGrams(draft.protein)} g P  ·  '
            '${_formatGrams(draft.carbohydrates)} g C  ·  '
            '${_formatGrams(draft.fats)} g F',
            style: AppStyle.meta,
          ),
        ],
      ),
    );
  }

  Widget _ingredientCard(int index, RecipeItem item) {
    final calories = item.food.calories * item.servings;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: _recipeCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.food.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.cardTitle,
                ),
              ),
              AppStyle.iconAction(
                icon: CupertinoIcons.delete,
                onPressed: () => _removeIngredient(index),
              ),
            ],
          ),
          Text(
            '${_formatTotal(calories)} kcal · ${_servingsLabel(item.servings)}',
            style: AppStyle.meta,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: item.servings <= 1
                    ? null
                    : () => _setServings(index, item.servings - 1),
                child: Icon(
                  CupertinoIcons.minus,
                  color: item.servings <= 1
                      ? AppColors.textSecondary
                      : AppColors.accent,
                ),
              ),
              Text(
                item.servings.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: item.servings >= 99
                    ? null
                    : () => _setServings(index, item.servings + 1),
                child: Icon(
                  CupertinoIcons.add,
                  color: item.servings >= 99
                      ? AppColors.textSecondary
                      : AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _recipeCardDecoration = AppStyle.card;
