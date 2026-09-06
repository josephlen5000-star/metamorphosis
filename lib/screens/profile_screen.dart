import 'package:flutter/cupertino.dart';

import '../models/user.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

typedef ProfileSaver = Future<void> Function({
  required String userId,
  required String username,
  required int age,
  required String biologicalSex,
  required double heightCm,
  required double weightKg,
  required String activityLevel,
  required bool useMetric,
  int? customCalorieTarget,
  double? proteinGoal,
  double? carbohydrateGoal,
  double? fatGoal,
  int? waterGoal,
});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    @visibleForTesting this.profileLoader,
    @visibleForTesting this.profileSaver,
  });

  final Future<User?> Function()? profileLoader;
  final ProfileSaver? profileSaver;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  FirebaseService? _firebaseService;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _heightFeetController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _calorieGoalController = TextEditingController();
  final TextEditingController _proteinGoalController = TextEditingController();
  final TextEditingController _carbGoalController = TextEditingController();
  final TextEditingController _fatGoalController = TextEditingController();
  final TextEditingController _waterGoalController = TextEditingController();

  User? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  String _selectedSex = 'male';
  String _selectedActivityLevel = 'sedentary';
  bool _useMetric = true;
  int _age = 25;
  double _heightCm = 170;
  double _weightKg = 70;

  static const _activityLevels = [
    'sedentary',
    'low_active',
    'active',
    'very_active',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _calorieGoalController.dispose();
    _proteinGoalController.dispose();
    _carbGoalController.dispose();
    _fatGoalController.dispose();
    _waterGoalController.dispose();
    super.dispose();
  }

  FirebaseService _firebase() => _firebaseService ??= FirebaseService();

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final loader =
          widget.profileLoader ?? _firebase().getUserProfile;
      final profile = await loader();
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _isLoading = false;
          _error = 'Couldn\'t load your profile.';
        });
        return;
      }
      _applyProfile(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Couldn\'t load your profile.';
      });
    }
  }

  void _applyProfile(User profile) {
    _profile = profile;
    _usernameController.text = profile.username;
    _selectedSex = profile.biologicalSex;
    _selectedActivityLevel = profile.activityLevel;
    _useMetric = profile.useMetric;
    _age = profile.age;
    _heightCm = profile.heightCm;
    _weightKg = profile.weightKg;
    _ageController.text = '$_age';
    _calorieGoalController.text = profile.customCalorieTarget?.toString() ?? '';
    _proteinGoalController.text = _goalText(profile.proteinGoal);
    _carbGoalController.text = _goalText(profile.carbohydrateGoal);
    _fatGoalController.text = _goalText(profile.fatGoal);
    _waterGoalController.text = profile.waterGoal?.toString() ?? '';
    _syncHeightWeightControllers();
    setState(() {
      _isLoading = false;
      _error = null;
    });
  }

  void _syncHeightWeightControllers() {
    if (_useMetric) {
      _heightController.text = _heightCm.round().toString();
      _weightController.text = _weightKg.round().toString();
    } else {
      final feet = (_heightCm / 30.48).floor();
      final inches = ((_heightCm / 2.54).round()) % 12;
      _heightFeetController.text = feet.toString();
      _heightInchesController.text = inches.toString();
      _weightController.text = (_weightKg * 2.20462).round().toString();
    }
  }

  void _updateAgeFromText() {
    final value = int.tryParse(_ageController.text);
    if (value == null || value == _age) return;
    setState(() => _age = value);
  }

  void _updateHeightFromText() {
    if (_useMetric) {
      final value = int.tryParse(_heightController.text);
      if (value == null) return;
      final next = value.toDouble().clamp(0.0, 250.0);
      if (next == _heightCm) return;
      setState(() => _heightCm = next);
      return;
    }

    final feet = int.tryParse(_heightFeetController.text) ?? 0;
    final inches = int.tryParse(_heightInchesController.text) ?? 0;
    final next = ((feet * 12 + inches).clamp(0, 96) * 2.54).clamp(0.0, 243.84);
    if (next == _heightCm) return;
    setState(() => _heightCm = next);
  }

  void _updateWeightFromText() {
    final value = double.tryParse(_weightController.text);
    if (value == null) return;
    final next = (_useMetric ? value : value * 0.453592).clamp(
      0.0,
      _useMetric ? 250.0 : 226.796,
    );
    if (next == _weightKg) return;
    setState(() => _weightKg = next);
  }

  User? get _previewUser {
    final profile = _profile;
    if (profile == null) return null;
    return User(
      userId: profile.userId,
      username: _usernameController.text.trim(),
      age: _age,
      biologicalSex: _selectedSex,
      heightCm: _heightCm,
      weightKg: _weightKg,
      activityLevel: _selectedActivityLevel,
      useMetric: _useMetric,
      createdAt: profile.createdAt,
      customCalorieTarget: _parseOptionalInt(_calorieGoalController.text),
      proteinGoal: _parseOptionalDouble(_proteinGoalController.text),
      carbohydrateGoal: _parseOptionalDouble(_carbGoalController.text),
      fatGoal: _parseOptionalDouble(_fatGoalController.text),
      waterGoal: _parseOptionalInt(_waterGoalController.text),
    );
  }

  String _goalText(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  int? _parseOptionalInt(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  double? _parseOptionalDouble(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _cancel() {
    if (_isSaving) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || _isSaving) return;

    _updateAgeFromText();
    _updateHeightFromText();
    _updateWeightFromText();

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showError('Please enter a username.');
      return;
    }
    if (_age < 13) {
      _showError('You must be at least 13 years old.');
      return;
    }
    if (_heightCm <= 0 || _weightKg <= 0) {
      _showError('Please enter your height and weight.');
      return;
    }
    if (_calorieGoalController.text.trim().isNotEmpty) {
      final calories = _parseOptionalInt(_calorieGoalController.text);
      if (calories == null || calories <= 0) {
        _showError('Enter a valid calorie target or leave it blank.');
        return;
      }
    }
    if (_proteinGoalController.text.trim().isNotEmpty) {
      final protein = _parseOptionalDouble(_proteinGoalController.text);
      if (protein == null || protein < 0) {
        _showError('Enter a valid protein goal or leave it blank.');
        return;
      }
    }
    if (_carbGoalController.text.trim().isNotEmpty) {
      final carbs = _parseOptionalDouble(_carbGoalController.text);
      if (carbs == null || carbs < 0) {
        _showError('Enter a valid carb goal or leave it blank.');
        return;
      }
    }
    if (_fatGoalController.text.trim().isNotEmpty) {
      final fat = _parseOptionalDouble(_fatGoalController.text);
      if (fat == null || fat < 0) {
        _showError('Enter a valid fat goal or leave it blank.');
        return;
      }
    }
    if (_waterGoalController.text.trim().isNotEmpty) {
      final waterGoal = _parseOptionalInt(_waterGoalController.text);
      if (waterGoal == null || waterGoal <= 0) {
        _showError('Enter a valid water goal or leave it blank.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final saver = widget.profileSaver ?? _firebase().updateUserProfile;
      await saver(
        userId: profile.userId,
        username: username,
        age: _age,
        biologicalSex: _selectedSex,
        heightCm: _heightCm,
        weightKg: _weightKg,
        activityLevel: _selectedActivityLevel,
        useMetric: _useMetric,
        customCalorieTarget: _parseOptionalInt(_calorieGoalController.text),
        proteinGoal: _parseOptionalDouble(_proteinGoalController.text),
        carbohydrateGoal: _parseOptionalDouble(_carbGoalController.text),
        fatGoal: _parseOptionalDouble(_fatGoalController.text),
        waterGoal: _parseOptionalInt(_waterGoalController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Couldn\'t save your profile. Try again.');
    }
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _profile != null && !_isLoading && !_isSaving;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.chrome,
        automaticallyImplyLeading: false,
        border: AppStyle.navBorder,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _cancel,
          child: const Text(
            'Cancel',
            style: AppStyle.navAction,
          ),
        ),
        middle: const Text(
          'Profile',
          style: AppStyle.navTitle,
        ),
        trailing: _isSaving
            ? const Padding(
                padding: EdgeInsets.only(right: 8),
                child: CupertinoActivityIndicator(),
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: canEdit ? _save : null,
                child: const Text(
                  'Save',
                  style: AppStyle.navActionAccent,
                ),
              ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 12),
            Text(
              'Loading profile...',
              style: AppStyle.bodySecondary,
            ),
          ],
        ),
      );
    }

    if (_error != null && _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppStyle.bodySecondary,
              ),
              CupertinoButton(
                onPressed: _loadProfile,
                child: const Text(
                  'Retry',
                  style: AppStyle.accentAction,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final preview = _previewUser;
    final mifflin = preview?.dailyCalorieTarget;
    final target = preview?.calorieTarget;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + bottomInset),
      children: [
        if (target != null) ...[
          _sectionCard(
            children: [
              const Text(
                'Daily target',
                style: AppStyle.fieldLabel,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$target',
                  maxLines: 1,
                  style: AppStyle.heroValue,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'kcal',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (mifflin != null) ...[
                const SizedBox(height: 10),
                Text(
                  preview?.customCalorieTarget == null
                      ? 'From Mifflin-St Jeor'
                      : 'Mifflin-St Jeor estimate  $mifflin kcal',
                  style: AppStyle.meta,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
        ],
        _sectionCard(
          title: 'About you',
          children: [
            _fieldLabel('Username'),
            _textField(
              controller: _usernameController,
              placeholder: 'Username',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Age'),
            _textField(
              controller: _ageController,
              placeholder: 'Age',
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateAgeFromText(),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Biological sex'),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _selectedSex,
              children: const {
                'male': Text('Male'),
                'female': Text('Female'),
              },
              onValueChanged: (value) {
                if (value == null) return;
                setState(() => _selectedSex = value);
              },
            ),
            const SizedBox(height: 14),
            _fieldLabel('Units'),
            CupertinoSlidingSegmentedControl<bool>(
              groupValue: _useMetric,
              children: const {
                true: Text('Metric'),
                false: Text('Imperial'),
              },
              onValueChanged: (value) {
                if (value == null) return;
                setState(() {
                  _useMetric = value;
                  _syncHeightWeightControllers();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Body',
          children: [
            _fieldLabel(_useMetric ? 'Height (cm)' : 'Height (ft / in)'),
            if (_useMetric)
              _textField(
                controller: _heightController,
                placeholder: 'Height in cm',
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateHeightFromText(),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _heightFeetController,
                      placeholder: 'ft',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateHeightFromText(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _textField(
                      controller: _heightInchesController,
                      placeholder: 'in',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updateHeightFromText(),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            _fieldLabel(_useMetric ? 'Weight (kg)' : 'Weight (lbs)'),
            _textField(
              controller: _weightController,
              placeholder: _useMetric ? 'Weight in kg' : 'Weight in lbs',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _updateWeightFromText(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Activity level',
          children: [
            for (var i = 0; i < _activityLevels.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildActivityOption(_activityLevels[i]),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Nutrition goals',
          children: [
            const Text(
              'Leave a field blank to use the calculated calorie target or hide that macro goal.',
              style: AppStyle.meta,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Custom calorie target'),
            _textField(
              controller: _calorieGoalController,
              placeholder:
                  mifflin == null ? 'Optional' : 'Optional · $mifflin kcal',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Protein goal'),
            _textField(
              controller: _proteinGoalController,
              placeholder: 'Optional · g',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Carb goal'),
            _textField(
              controller: _carbGoalController,
              placeholder: 'Optional · g',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Fat goal'),
            _textField(
              controller: _fatGoalController,
              placeholder: 'Optional · g',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Water',
          children: [
            const Text(
              'Leave blank to keep the default of 8 glasses a day.',
              style: AppStyle.meta,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Daily water goal'),
            _textField(
              controller: _waterGoalController,
              placeholder: 'Optional · ${User.defaultWaterGoal} glasses',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard({String? title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _profileCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: AppStyle.sectionTitle,
            ),
            const SizedBox(height: 14),
          ],
          ...children,
        ],
      ),
    );
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

  Widget _textField({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      onChanged: onChanged,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppStyle.field,
    );
  }

  Widget _buildActivityOption(String value) {
    final selected = _selectedActivityLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedActivityLevel = value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.10)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.toolbarDivider,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                User.getActivityLevelDisplay(value),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 22,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

const _profileCardDecoration = AppStyle.card;
