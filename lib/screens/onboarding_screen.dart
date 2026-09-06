import 'package:flutter/cupertino.dart';
import 'package:metamorphosis/services/firebase_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingScreen({super.key, required this.onOnboardingComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // Form data
  final _usernameController = TextEditingController();
  final _heightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();

  int _age = 18;
  double _heightCm = 170.0;
  double _weightKg = 70.0;

  String _selectedActivityLevel = 'sedentary';
  String _selectedSex = 'male';
  bool _useMetric = true;
  bool _isLoading = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _syncHeightWeightControllers();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_usernameController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (_age < 13) {
      _showErrorDialog('You must be at least 13 years old');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firebaseService.createUserProfile(
        username: _usernameController.text,
        age: _age,
        biologicalSex: _selectedSex,
        heightCm: _heightCm,
        weightKg: _weightKg,
        activityLevel: _selectedActivityLevel,
        useMetric: _useMetric,
      );

      widget.onOnboardingComplete();
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Step ${_currentPage + 1} of 6'),
        leading: _currentPage > 0
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _previousPage,
                child: const Icon(CupertinoIcons.back),
              )
            : null,
        trailing: _currentPage < 5
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _nextPage,
                child: const Text('Next'),
              )
            : null,
      ),
      child: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (page) => setState(() => _currentPage = page),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildUsernamePage(),
            _buildActivityLevelPage(),
            _buildAgePage(),
            _buildSexPage(),
            _buildHeightWeightPage(),
            _buildReviewPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernamePage() {
    return _buildStepPage(
      title: 'Welcome to Metamorphosis',
      subtitle: 'What\'s your username?',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoTextField(
            controller: _usernameController,
            placeholder: 'Enter username',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelPage() {
    final activities = [
      {
        'value': 'sedentary',
        'label': 'Lazy',
        'description': 'ZERO activity',
      },
      {
        'value': 'low_active',
        'label': 'Normal',
        'description': 'Walks a bit',
      },
      { 
        'value': 'active', 
        'label': 'Works Out', 
        'description': '1-2 hours a day'
      },
      {
        'value': 'very_active',
        'label': 'Cardio King',
        'description': '>2 hours a day',
      },
    ];

    return _buildStepPage(
      title: 'Activity Level',
      subtitle: 'How active are you?',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: activities
            .map((activity) => _buildActivityOption(activity))
            .toList(),
      ),
    );
  }

  Widget _buildActivityOption(Map<String, String> activity) {
    final value = activity['value']!;
    final isSelected = _selectedActivityLevel == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedActivityLevel = value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['label']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  activity['description']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: CupertinoColors.activeBlue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgePage() {
    return _buildStepPage(
      title: 'Your Age',
      subtitle: 'Use the slider to pick your age',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_age',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          CupertinoSlider(
            value: _age.toDouble(),
            min: 13,
            max: 80,
            divisions: 67,
            onChanged: (value) => setState(() => _age = value.round()),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose an age from 13 to 80. You must be at least 13.',
            style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSexPage() {
    return _buildStepPage(
      title: 'Biological Sex',
      subtitle: 'For nutritional calculations',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSexOption('Male', 'male'),
          const SizedBox(height: 16),
          _buildSexOption('Female', 'female'),
        ],
      ),
    );
  }

  Widget _buildSexOption(String label, String value) {
    final isSelected = _selectedSex == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedSex = value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: CupertinoColors.activeBlue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightWeightPage() {
    return _buildStepPage(
      title: 'Height & Weight',
      subtitle: 'Your measurements',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoSegmentedControl<bool>(
                  children: const {
                    true: Text('Metric'),
                    false: Text('Imperial'),
                  },
                  groupValue: _useMetric,
                  onValueChanged: (bool value) => setState(() {
                    _useMetric = value;
                    _syncHeightWeightControllers();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildHeightField(),
          const SizedBox(height: 20),
          _buildWeightField(),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return _buildStepPage(
      title: 'Confirm Details',
      subtitle: 'Review your information',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildReviewItem('Username', _usernameController.text),
          _buildReviewItem('Age', '$_age'),
          _buildReviewItem('Sex', _selectedSex == 'male' ? 'Male' : 'Female'),
          _buildReviewItem('Height', _heightDisplay),
          _buildReviewItem('Weight', _weightDisplay),
          _buildReviewItem(
            'Activity Level',
            _getActivityLevelLabel(_selectedActivityLevel),
          ),
          const SizedBox(height: 30),
          _isLoading
              ? const CupertinoActivityIndicator()
              : CupertinoButton.filled(
                  onPressed: _completeOnboarding,
                  child: const Text('Get Started'),
                ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivityLevelLabel(String level) {
    switch (level) {
      case 'sedentary':
        return 'Sedentary';
      case 'low_active':
        return 'Low Active';
      case 'active':
        return 'Active';
      case 'very_active':
        return 'Very Active';
      default:
        return '';
    }
  }

  String get _heightDisplay {
    if (_useMetric) {
      return '${_heightCm.round()} cm';
    }
    final feet = (_heightCm / 30.48).floor();
    final inches = ((_heightCm / 2.54).round()) % 12;
    return '$feet ft $inches in';
  }

  String get _weightDisplay {
    if (_useMetric) {
      return '${_weightKg.round()} kg';
    }
    return '${(_weightKg * 2.20462).round()} lbs';
  }

  void _incrementHeight() {
    setState(() {
      if (_useMetric) {
        _heightCm = (_heightCm + 1).clamp(0.0, 250.0);
      } else {
        _heightCm = (_heightCm + 2.54).clamp(0.0, 243.84);
      }
      _syncHeightWeightControllers();
    });
  }

  void _decrementHeight() {
    setState(() {
      if (_useMetric) {
        _heightCm = (_heightCm - 1).clamp(0.0, 250.0);
      } else {
        _heightCm = (_heightCm - 2.54).clamp(0.0, 243.84);
      }
      _syncHeightWeightControllers();
    });
  }

  void _incrementWeight() {
    setState(() {
      if (_useMetric) {
        _weightKg = (_weightKg + 1).clamp(0.0, 250.0);
      } else {
        _weightKg = (_weightKg + 0.453592).clamp(0.0, 226.796);
      }
      _syncHeightWeightControllers();
    });
  }

  void _decrementWeight() {
    setState(() {
      if (_useMetric) {
        _weightKg = (_weightKg - 1).clamp(0.0, 250.0);
      } else {
        _weightKg = (_weightKg - 0.453592).clamp(0.0, 226.796);
      }
      _syncHeightWeightControllers();
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

  void _updateHeightFromText() {
    var updated = false;

    if (_useMetric) {
      final value = int.tryParse(_heightController.text);
      if (value != null) {
        final newHeightCm = value.toDouble().clamp(0.0, 250.0);
        if (newHeightCm != _heightCm) {
          _heightCm = newHeightCm;
          updated = true;
        }
      }
    } else {
      final feet = int.tryParse(_heightFeetController.text) ?? 0;
      final inches = int.tryParse(_heightInchesController.text) ?? 0;
      final totalInches = (feet * 12 + inches).clamp(0, 96);
      final newHeightCm = (totalInches * 2.54).clamp(0.0, 243.84);
      if (newHeightCm != _heightCm) {
        _heightCm = newHeightCm;
        updated = true;
      }
    }

    if (updated) {
      setState(() {});
    }
  }

  void _updateWeightFromText() {
    final value = double.tryParse(_weightController.text);
    if (value == null) return;

    final newWeightKg = (_useMetric ? value : value * 0.453592).clamp(
      0.0,
      _useMetric ? 250.0 : 226.796,
    );

    if (newWeightKg != _weightKg) {
      _weightKg = newWeightKg;
      setState(() {});
    }
  }

  Widget _buildHeightField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.separator),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Height',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                _useMetric ? 'cm' : 'ft / in',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(50),
                color: CupertinoColors.systemGrey5,
                onPressed: _decrementHeight,
                child: const Icon(CupertinoIcons.minus),
              ),
              Expanded(
                child: _useMetric
                    ? CupertinoTextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                        placeholder: 'Height in cm',
                        textAlign: TextAlign.center,
                        onChanged: (_) => _updateHeightFromText(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: _heightFeetController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: false,
                                  ),
                              placeholder: 'ft',
                              textAlign: TextAlign.center,
                              onChanged: (_) => _updateHeightFromText(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _heightInchesController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: false,
                                  ),
                              placeholder: 'in',
                              textAlign: TextAlign.center,
                              onChanged: (_) => _updateHeightFromText(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(50),
                color: CupertinoColors.systemGrey5,
                onPressed: _incrementHeight,
                child: const Icon(CupertinoIcons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.separator),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weight',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                _useMetric ? 'kg' : 'lbs',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(50),
                color: CupertinoColors.systemGrey5,
                onPressed: _decrementWeight,
                child: const Icon(CupertinoIcons.minus),
              ),
              Expanded(
                child: CupertinoTextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: _useMetric ? 'Weight in kg' : 'Weight in lbs',
                  textAlign: TextAlign.center,
                  onChanged: (_) => _updateWeightFromText(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(50),
                color: CupertinoColors.systemGrey5,
                onPressed: _incrementWeight,
                child: const Icon(CupertinoIcons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPage({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            child,
          ],
        ),
      ),
    );
  }
}
