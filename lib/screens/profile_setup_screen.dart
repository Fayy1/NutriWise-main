import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import 'main_navigation.dart';

/// Screen setup profil setelah registrasi pertama kali.
/// 3 langkah: Data Dasar → Level Aktivitas → Target
class ProfileSetupScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const ProfileSetupScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Data dasar
  int _age = 22;
  String _gender = 'Laki-laki';
  double _weight = 65;
  double _height = 165;

  // Step 2: Aktivitas
  String _activityLevel = 'Sedentary';

  // Step 3: Target
  double _targetWeight = 60;
  double _calorieTarget = 2000;
  bool _useFormula = true;

  final List<Map<String, dynamic>> _activityOptions = [
    {
      'value': 'Sedentary',
      'label': 'Jarang Gerak',
      'desc': 'Kerja kantoran, olahraga minim',
      'emoji': '🪑',
      'multiplier': 1.2,
    },
    {
      'value': 'Lightly Active',
      'label': 'Agak Aktif',
      'desc': 'Olahraga ringan 1-3x seminggu',
      'emoji': '🚶',
      'multiplier': 1.375,
    },
    {
      'value': 'Moderately Active',
      'label': 'Cukup Aktif',
      'desc': 'Olahraga sedang 3-5x seminggu',
      'emoji': '🏃',
      'multiplier': 1.55,
    },
    {
      'value': 'Very Active',
      'label': 'Sangat Aktif',
      'desc': 'Olahraga berat 6-7x seminggu',
      'emoji': '💪',
      'multiplier': 1.725,
    },
  ];

  double _calculateCalories() {
    // Harris-Benedict
    double bmr;
    if (_gender == 'Laki-laki') {
      bmr = 88.362 + (13.397 * _weight) + (4.799 * _height) - (5.677 * _age);
    } else {
      bmr = 447.593 + (9.247 * _weight) + (3.098 * _height) - (4.330 * _age);
    }
    final activity = _activityOptions.firstWhere(
      (a) => a['value'] == _activityLevel,
      orElse: () => _activityOptions[0],
    );
    
    final tdee = bmr * (activity['multiplier'] as double);

    // Penyesuaian berdasarkan perbedaan target berat badan dan berat saat ini:
    // - +/- 50 kkal per 1 kg perbedaan berat badan
    // - Batas maksimum penyesuaian (defisit/surplus) adalah +/- 500 kkal
    final weightDiff = _targetWeight - _weight;
    final adjustment = (weightDiff * 50).clamp(-500.0, 500.0);
    
    final targetCal = tdee + adjustment;
    
    // Batas aman konsumsi kalori harian antara 1200 kkal hingga 4000 kkal
    return targetCal.roundToDouble().clamp(1200.0, 4000.0);
  }

  Future<void> _saveAndContinue() async {
    if (_currentStep < 2) {
      setState(() {
        if (_currentStep == 1) {
          _calorieTarget = _calculateCalories();
        }
        _currentStep++;
      });
      return;
    }

    // Save step 3 (final)
    setState(() => _isLoading = true);

    try {
      final cal = _useFormula ? _calculateCalories() : _calorieTarget;
      final proteinTarget = (cal * 0.25 / 4).round();
      final carbsTarget = (cal * 0.50 / 4).round();
      final fatTarget = (cal * 0.25 / 9).round();

      await DatabaseHelper.instance.updateUserProfile(widget.userId, {
        'name': widget.userName,
        'age': _age,
        'gender': _gender,
        'weight': _weight,
        'height': _height,
        'activity_level': _activityLevel,
        'target_weight': _targetWeight,
        'daily_calorie_target': cal.toInt(),
        'carbs_target': carbsTarget,
        'protein_target': proteinTarget,
        'fat_target': fatTarget,
        'use_formula': _useFormula,
        'profile_completed': true,
      });

      await SessionManager.saveSession(userName: widget.userName);

      if (!mounted) return;
      // Navigasi ke onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            userId: widget.userId,
            calorieTarget: cal,
            carbsTarget: carbsTarget.toDouble(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator
                  Row(
                    children: List.generate(3, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i <= _currentStep ? AppTheme.primary : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Langkah ${_currentStep + 1} dari 3',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getStepTitle(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStepSubtitle(),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCurrentStep(),
              ),
            ),
            // Bottom navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  // Tombol Kembali (hanya muncul jika bukan langkah pertama)
                  if (_currentStep > 0) ...[
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _currentStep--),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        label: const Text(
                          'Kembali',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Tombol Lanjut / Selesai
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentStep == 2 ? 'Selesai & Mulai' : 'Lanjut',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (_currentStep < 2) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                  ] else ...[
                                    const SizedBox(width: 6),
                                    const Text('🚀', style: TextStyle(fontSize: 16)),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Data Dirimu 📋';
      case 1: return 'Gaya Hidupmu 🏃';
      case 2: return 'Targetmu 🎯';
      default: return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0: return 'Kami butuh ini untuk kalkulasi nutrisi personalmu';
      case 1: return 'Seberapa aktif kamu sehari-hari?';
      case 2: return 'Apa yang ingin kamu capai?';
      default: return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gender
        const Text('GENDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(
          children: ['Laki-laki', 'Perempuan'].map((g) {
            final isSelected = _gender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: g == 'Laki-laki' ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(g == 'Laki-laki' ? '👨' : '👩', style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        g,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Age
        _buildSliderCard(
          label: 'USIA',
          value: _age.toDouble(),
          min: 10,
          max: 80,
          unit: 'tahun',
          onChanged: (v) => setState(() => _age = v.toInt()),
          color: AppTheme.primary,
        ),
        const SizedBox(height: 14),

        // Weight
        _buildSliderCard(
          label: 'BERAT BADAN',
          value: _weight,
          min: 30,
          max: 150,
          unit: 'kg',
          decimals: 1,
          onChanged: (v) => setState(() => _weight = (v * 2).roundToDouble() / 2),
          color: AppTheme.carbsColor,
        ),
        const SizedBox(height: 14),

        // Height
        _buildSliderCard(
          label: 'TINGGI BADAN',
          value: _height,
          min: 100,
          max: 220,
          unit: 'cm',
          onChanged: (v) => setState(() => _height = v.roundToDouble()),
          color: AppTheme.tertiary,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: _activityOptions.map((opt) {
        final isSelected = _activityLevel == opt['value'];
        return GestureDetector(
          onTap: () => setState(() => _activityLevel = opt['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(opt['emoji'] as String, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt['desc'] as String,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep3() {
    final calculatedCal = _calculateCalories();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target weight
        _buildSliderCard(
          label: 'TARGET BERAT BADAN',
          value: _targetWeight,
          min: 30,
          max: 150,
          unit: 'kg',
          decimals: 1,
          onChanged: (v) => setState(() {
            _targetWeight = (v * 2).roundToDouble() / 2;
            if (_useFormula) {
              _calorieTarget = _calculateCalories();
            }
          }),
          color: AppTheme.tertiary,
        ),
        const SizedBox(height: 20),

        // Kalori target
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TARGET KALORI HARIAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 12),

              // Toggle formula vs manual
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _useFormula = true;
                        _calorieTarget = calculatedCal;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _useFormula ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🧮 Pakai Rumus',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _useFormula ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useFormula = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_useFormula ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '✏️ Manual',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !_useFormula ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_useFormula) ...[
                Center(
                  child: Column(
                    children: [
                      Text(
                        calculatedCal.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Text('kcal / hari', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        'Berdasarkan data & aktivitasmu',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  '${_calorieTarget.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppTheme.primary),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbColor: AppTheme.primary,
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 4,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _calorieTarget.clamp(1200, 4000),
                    min: 1200,
                    max: 4000,
                    divisions: 56,
                    onChanged: (v) => setState(() => _calorieTarget = v.roundToDouble()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1200 kcal', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    Text('4000 kcal', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
    required Color color,
    int decimals = 0,
  }) {
    final displayValue = decimals > 0 ? value.toStringAsFixed(decimals) : value.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: displayValue,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color, fontFamily: 'Manrope'),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontFamily: 'Manrope'),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: color,
              activeTrackColor: color,
              inactiveTrackColor: Colors.grey.shade200,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ONBOARDING SCREEN
// ══════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final double calorieTarget;
  final double carbsTarget;
  const OnboardingScreen({
    super.key,
    required this.userId,
    required this.calorieTarget,
    required this.carbsTarget,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  late double _carbsTarget;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carbsTarget = widget.carbsTarget;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.updateUserProfile(widget.userId, {
        'carbs_target': _carbsTarget.toInt(),
      });
    } catch (_) {}

    if (!mounted) return;
    // Navigate to main app
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const _MainNavigationPlaceholder()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildCarbsPage(),
                  _buildReadyPage(),
                ],
              ),
            ),
            // Dot indicators + button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _currentPage ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == _currentPage ? AppTheme.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentPage < 2) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                _finish();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              _currentPage == 2 ? '🚀 Mulai Sekarang!' : 'Lanjut →',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🌿', style: TextStyle(fontSize: 60)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Selamat Datang di\nNutriWise! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'Target kalori harianmu sudah dihitung:\n${widget.calorieTarget.toStringAsFixed(0)} kcal/hari',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Text(
              '✅ Lacak makanan harian\n✅ Kelola inventori dapur\n✅ Saran resep dari AI\n✅ Target nutrisi personal',
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbsPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌾', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'Set Target Karbo\nHarianmu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Karbohidrat adalah sumber energi utama tubuhmu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 40),
          Text(
            '${_carbsTarget.toStringAsFixed(0)}g',
            style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: AppTheme.carbsColor),
          ),
          const Text('per hari', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: AppTheme.carbsColor,
              activeTrackColor: AppTheme.carbsColor,
              inactiveTrackColor: Colors.grey.shade200,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 6,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _carbsTarget.clamp(50, 500),
              min: 50,
              max: 500,
              divisions: 90,
              onChanged: (v) => setState(() => _carbsTarget = v.roundToDouble()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('50g (rendah)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              Text('500g (tinggi)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.carbsColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Rekomendasimu: ${widget.carbsTarget.toStringAsFixed(0)}g/hari\n(50% dari total kalorimu)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.carbsColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'Semua Siap!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Targetmu sudah tersimpan.\nMulai perjalanan nutrisimu sekarang!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                _SummaryRow(emoji: '🔥', label: 'Target Kalori', value: '${widget.calorieTarget.toStringAsFixed(0)} kcal'),
                const Divider(height: 20),
                _SummaryRow(emoji: '🌾', label: 'Target Karbo', value: '${_carbsTarget.toStringAsFixed(0)}g'),
                const Divider(height: 20),
                _SummaryRow(emoji: '💪', label: 'Target Protein', value: '${(widget.calorieTarget * 0.25 / 4).toStringAsFixed(0)}g'),
                const Divider(height: 20),
                _SummaryRow(emoji: '🥑', label: 'Target Lemak', value: '${(widget.calorieTarget * 0.25 / 9).toStringAsFixed(0)}g'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String emoji, label, value;
  const _SummaryRow({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }
}

// Menggunakan MainNavigation secara langsung
class _MainNavigationPlaceholder extends StatelessWidget {
  const _MainNavigationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const MainNavigation();
  }
}
