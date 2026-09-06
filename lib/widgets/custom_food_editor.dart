import 'package:flutter/cupertino.dart';

import '../models/custom_food.dart';
import '../models/food_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

class CustomFoodEditor extends StatefulWidget {
  const CustomFoodEditor({super.key, this.existing});

  final FoodItem? existing;

  @override
  State<CustomFoodEditor> createState() => _CustomFoodEditorState();
}

class _CustomFoodEditorState extends State<CustomFoodEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _caloriesController = TextEditingController(
      text: existing == null ? '' : existing.calories.toString(),
    );
    _proteinController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.protein),
    );
    _carbsController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.carbohydrates),
    );
    _fatsController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.fats),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  bool get _isDirty {
    final existing = widget.existing;
    if (existing == null) {
      return _nameController.text.trim().isNotEmpty ||
          _caloriesController.text.trim().isNotEmpty ||
          _proteinController.text.trim().isNotEmpty ||
          _carbsController.text.trim().isNotEmpty ||
          _fatsController.text.trim().isNotEmpty;
    }
    return _nameController.text.trim() != existing.name ||
        _caloriesController.text.trim() != existing.calories.toString() ||
        _proteinController.text.trim() != _formatNumber(existing.protein) ||
        _carbsController.text.trim() != _formatNumber(existing.carbohydrates) ||
        _fatsController.text.trim() != _formatNumber(existing.fats);
  }

  void _onFieldChanged(String _) {
    if (_error != null) setState(() => _error = null);
  }

  void _save() {
    final parsed = CustomFoodInput.parse(
      name: _nameController.text,
      calories: _caloriesController.text,
      protein: _proteinController.text,
      carbohydrates: _carbsController.text,
      fats: _fatsController.text,
    );
    if (!parsed.isValid) {
      setState(() => _error = parsed.error);
      return;
    }

    Navigator.of(context).pop(parsed.value!.toFoodItem(id: widget.existing?.id));
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

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: AppStyle.fieldLabel,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      onChanged: _onFieldChanged,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppStyle.field,
    );
  }

  Widget _section({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _editorCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
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
                          _isEditing ? 'Edit custom food' : 'Create custom food',
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
                        _section(
                          children: [
                            _fieldLabel('Food name'),
                            _field(
                              controller: _nameController,
                              placeholder: 'Food name',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nutrition is per 1 serving.',
                              style: AppStyle.meta,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _section(
                          children: [
                            const Text(
                              'Nutrition',
                              style: AppStyle.sectionTitle,
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Calories'),
                            _field(
                              controller: _caloriesController,
                              placeholder: 'kcal',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Protein'),
                            _field(
                              controller: _proteinController,
                              placeholder: 'g',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Carbs'),
                            _field(
                              controller: _carbsController,
                              placeholder: 'g',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Fat'),
                            _field(
                              controller: _fatsController,
                              placeholder: 'g',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ],
                        ),
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
}

const _editorCardDecoration = AppStyle.card;
