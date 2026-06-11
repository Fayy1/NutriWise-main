import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../services/gemini_service.dart';

/// FAB bottom sheet untuk quick-add makanan dari Home screen.
/// Input nama makanan → Gemini auto-fill nutrisi → simpan ke diary.
class AddFoodFabSheet extends StatefulWidget {
  const AddFoodFabSheet({super.key});

  @override
  State<AddFoodFabSheet> createState() => _AddFoodFabSheetState();
}

class _AddFoodFabSheetState extends State<AddFoodFabSheet> {
  final _nameController = TextEditingController();
  bool _isLoadingNutrition = false;
  bool _isSaving = false;
  bool _nutritionLoaded = false;

  double _calories = 0;
  double _carbs = 0;
  double _protein = 0;
  double _fat = 0;
  String _mealType = 'Makan Siang';

  final List<String> _mealTypes = ['Sarapan', 'Makan Siang', 'Makan Malam', 'Snack'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getEmoji(String mealType) {
    switch (mealType) {
      case 'Sarapan': return '🌅';
      case 'Makan Siang': return '☀️';
      case 'Makan Malam': return '🌙';
      case 'Snack': return '🍪';
      default: return '🍽️';
    }
  }

  Future<void> _fetchNutrition() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoadingNutrition = true;
      _nutritionLoaded = false;
    });

    final result = await GeminiService.getNutritionInfo(name);
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _calories = (result['calories'] as num?)?.toDouble() ?? 0;
        _carbs = (result['carbs'] as num?)?.toDouble() ?? 0;
        _protein = (result['protein'] as num?)?.toDouble() ?? 0;
        _fat = (result['fat'] as num?)?.toDouble() ?? 0;
        _nutritionLoaded = true;
        _isLoadingNutrition = false;
      });
    } else {
      setState(() => _isLoadingNutrition = false);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) return;

      final now = DateTime.now();
      await DatabaseHelper.instance.addMealLog(
        userId: userId,
        foodName: _nameController.text.trim(),
        mealType: _mealType,
        calories: _calories,
        protein: _protein,
        carbs: _carbs,
        fat: _fat,
        emoji: _getEmoji(_mealType),
        date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );

      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text('Tambah Makanan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const Text('Ketik nama makanan, AI akan isi nutrisinya', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),

            // Food name input + fetch button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'mis. Nasi Goreng, Ayam Bakar...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.fastfood_outlined, color: AppTheme.textMuted, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onSubmitted: (_) => _fetchNutrition(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isLoadingNutrition ? null : _fetchNutrition,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isLoadingNutrition
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),

            // Nutrition result (animated)
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: _nutritionLoaded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
                                const SizedBox(width: 6),
                                const Text('Estimasi Nutrisi (AI)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _fetchNutrition,
                                  child: const Text('Muat ulang', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _NutriItem(label: 'Kalori', value: _calories.toStringAsFixed(0), unit: 'kcal', color: Colors.orange),
                                  _NutriDivider(),
                                  _NutriItem(label: 'Karbo', value: _carbs.toStringAsFixed(1), unit: 'g', color: AppTheme.carbsColor),
                                  _NutriDivider(),
                                  _NutriItem(label: 'Protein', value: _protein.toStringAsFixed(1), unit: 'g', color: AppTheme.primary),
                                  _NutriDivider(),
                                  _NutriItem(label: 'Lemak', value: _fat.toStringAsFixed(1), unit: 'g', color: AppTheme.tertiary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Meal type selector
            const Text('WAKTU MAKAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              children: _mealTypes.map((type) {
                final isSelected = _mealType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: type != _mealTypes.last ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(children: [
                        Text(_getEmoji(type), style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          type.split(' ').last,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppTheme.textSecondary),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSaving || _nameController.text.trim().isEmpty) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Simpan ke Diary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutriItem extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _NutriItem({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      Text(unit, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _NutriDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Colors.grey.shade200);
  }
}
