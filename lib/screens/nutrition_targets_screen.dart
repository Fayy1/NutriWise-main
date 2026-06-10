import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';

class NutritionTargetsScreen extends StatefulWidget {
  final String userId;
  const NutritionTargetsScreen({super.key, required this.userId});

  @override
  State<NutritionTargetsScreen> createState() => _NutritionTargetsScreenState();
}

class _NutritionTargetsScreenState extends State<NutritionTargetsScreen> {
  bool _useFormula = true;
  bool _isLoading = true;
  bool _isSaving = false;

  double _calorieTarget = 2000;
  double _carbsTarget = 250;
  double _proteinTarget = 150;
  double _fatTarget = 65;

  // For formula-based
  double _weight = 70;
  double _height = 170;
  int _age = 25;
  String _gender = 'Laki-laki';
  String _activityLevel = 'Sedentary';

  final Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly Active': 1.375,
    'Moderately Active': 1.55,
    'Very Active': 1.725,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await DatabaseHelper.instance.getUserById(widget.userId);
    if (user == null || !mounted) return;
    setState(() {
      _useFormula = user['use_formula'] as bool? ?? true;
      _calorieTarget = (user['daily_calorie_target'] as num?)?.toDouble() ?? 2000;
      _carbsTarget = (user['carbs_target'] as num?)?.toDouble() ?? 250;
      _proteinTarget = (user['protein_target'] as num?)?.toDouble() ?? 150;
      _fatTarget = (user['fat_target'] as num?)?.toDouble() ?? 65;
      _weight = (user['weight'] as num?)?.toDouble() ?? 70;
      _height = (user['height'] as num?)?.toDouble() ?? 170;
      _age = user['age'] as int? ?? 25;
      _gender = user['gender'] as String? ?? 'Laki-laki';
      _activityLevel = user['activity_level'] as String? ?? 'Sedentary';
      _isLoading = false;
    });
  }

  double _calculateCalories() {
    double bmr;
    if (_gender == 'Laki-laki') {
      bmr = 88.362 + (13.397 * _weight) + (4.799 * _height) - (5.677 * _age);
    } else {
      bmr = 447.593 + (9.247 * _weight) + (3.098 * _height) - (4.330 * _age);
    }
    final mult = _activityMultipliers[_activityLevel] ?? 1.2;
    return (bmr * mult).roundToDouble();
  }

  void _applyFormula() {
    final cal = _calculateCalories();
    setState(() {
      _calorieTarget = cal;
      _proteinTarget = (cal * 0.25 / 4).roundToDouble();
      _carbsTarget = (cal * 0.50 / 4).roundToDouble();
      _fatTarget = (cal * 0.25 / 9).roundToDouble();
    });
  }

  // Warning: check if macros are consistent with calories
  bool get _isMacroConsistent {
    final macroCalories = (_carbsTarget * 4) + (_proteinTarget * 4) + (_fatTarget * 9);
    return (macroCalories - _calorieTarget).abs() < 100;
  }

  double get _macroCalories => (_carbsTarget * 4) + (_proteinTarget * 4) + (_fatTarget * 9);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.updateUserProfile(widget.userId, {
        'use_formula': _useFormula,
        'daily_calorie_target': _calorieTarget.toInt(),
        'carbs_target': _carbsTarget.toInt(),
        'protein_target': _proteinTarget.toInt(),
        'fat_target': _fatTarget.toInt(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Target nutrisi berhasil disimpan!'),
          ]),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Target Nutrisi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Text('🎯', style: TextStyle(fontSize: 28)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Kustomisasi Target', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            Text('Atur sendiri target karbo, protein, dan lemak harian', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle mode
                  const Text('MODE PERHITUNGAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _useFormula = true);
                            _applyFormula();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _useFormula ? AppTheme.primary : Colors.white,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              border: Border.all(color: _useFormula ? AppTheme.primary : Colors.grey.shade200),
                            ),
                            child: Column(children: [
                              Text('🧮', style: TextStyle(fontSize: 22, color: _useFormula ? Colors.white : null)),
                              const SizedBox(height: 4),
                              Text('Pakai Rumus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _useFormula ? Colors.white : AppTheme.textSecondary)),
                              Text('Harris-Benedict', style: TextStyle(fontSize: 10, color: _useFormula ? Colors.white70 : AppTheme.textMuted)),
                            ]),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _useFormula = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !_useFormula ? AppTheme.tertiary : Colors.white,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                              border: Border.all(color: !_useFormula ? AppTheme.tertiary : Colors.grey.shade200),
                            ),
                            child: Column(children: [
                              Text('✏️', style: TextStyle(fontSize: 22, color: !_useFormula ? Colors.white : null)),
                              const SizedBox(height: 4),
                              Text('Manual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: !_useFormula ? Colors.white : AppTheme.textSecondary)),
                              Text('Atur sendiri', style: TextStyle(fontSize: 10, color: !_useFormula ? Colors.white70 : AppTheme.textMuted)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_useFormula) ...[
                    // Formula result display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('HASIL PERHITUNGAN RUMUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _MacroFormulaRow(label: '🔥 Kalori', value: '${_calorieTarget.toStringAsFixed(0)} kcal', color: Colors.orange),
                        _MacroFormulaRow(label: '🌾 Karbo (50%)', value: '${_carbsTarget.toStringAsFixed(0)}g', color: AppTheme.carbsColor),
                        _MacroFormulaRow(label: '💪 Protein (25%)', value: '${_proteinTarget.toStringAsFixed(0)}g', color: AppTheme.primary),
                        _MacroFormulaRow(label: '🥑 Lemak (25%)', value: '${_fatTarget.toStringAsFixed(0)}g', color: AppTheme.tertiary),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _applyFormula,
                          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primary),
                          label: const Text('Hitung Ulang', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ] else ...[
                    // Manual sliders
                    // Calories
                    _buildMacroSlider(
                      label: '🔥 Target Kalori',
                      value: _calorieTarget,
                      min: 1200,
                      max: 4000,
                      unit: 'kcal',
                      color: Colors.orange,
                      onChanged: (v) => setState(() => _calorieTarget = v.roundToDouble()),
                    ),
                    const SizedBox(height: 14),
                    // Carbs
                    _buildMacroSlider(
                      label: '🌾 Karbohidrat',
                      value: _carbsTarget,
                      min: 50,
                      max: 600,
                      unit: 'g',
                      color: AppTheme.carbsColor,
                      onChanged: (v) => setState(() => _carbsTarget = v.roundToDouble()),
                    ),
                    const SizedBox(height: 14),
                    // Protein
                    _buildMacroSlider(
                      label: '💪 Protein',
                      value: _proteinTarget,
                      min: 30,
                      max: 300,
                      unit: 'g',
                      color: AppTheme.primary,
                      onChanged: (v) => setState(() => _proteinTarget = v.roundToDouble()),
                    ),
                    const SizedBox(height: 14),
                    // Fat
                    _buildMacroSlider(
                      label: '🥑 Lemak',
                      value: _fatTarget,
                      min: 20,
                      max: 200,
                      unit: 'g',
                      color: AppTheme.tertiary,
                      onChanged: (v) => setState(() => _fatTarget = v.roundToDouble()),
                    ),
                    const SizedBox(height: 16),

                    // Consistency check
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isMacroConsistent ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isMacroConsistent ? Colors.green.shade200 : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _isMacroConsistent ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          color: _isMacroConsistent ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          _isMacroConsistent
                              ? 'Makro sesuai dengan target kalori ✓'
                              : 'Total makro ≈ ${_macroCalories.toStringAsFixed(0)} kcal (selisih ${(_macroCalories - _calorieTarget).abs().toStringAsFixed(0)} kcal dari target)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isMacroConsistent ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Simpan Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildMacroSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${value.toStringAsFixed(0)} $unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: color,
            activeTrackColor: color,
            inactiveTrackColor: Colors.grey.shade200,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            trackHeight: 4,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${min.toStringAsFixed(0)} $unit', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          Text('${max.toStringAsFixed(0)} $unit', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ]),
      ]),
    );
  }
}

class _MacroFormulaRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroFormulaRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}
