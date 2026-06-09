import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../services/gemini_service.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _caloriesController =
      TextEditingController(text: '0');
  final TextEditingController _portionController =
      TextEditingController(text: '100');
  final TextEditingController _searchController = TextEditingController();

  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;
  String _portionUnit = 'gram';
  String _mealType = 'Makan Siang';

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;

  final List<String> _mealTypes = [
    'Sarapan',
    'Makan Siang',
    'Makan Malam',
    'Snack'
  ];

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _portionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchFood(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await GeminiService.searchFoods(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _selectFood(Map<String, dynamic> food) {
    setState(() {
      _foodNameController.text = food['name'] as String;
      _caloriesController.text =
          (food['calories'] as num).toStringAsFixed(0);
      _protein = (food['protein'] as num).toDouble();
      _carbs = (food['carbs'] as num).toDouble();
      _fats = (food['fat'] as num).toDouble();
      _searchResults = [];
      _searchController.clear();
    });
  }

  String _getEmojiForMealType(String mealType) {
    switch (mealType) {
      case 'Sarapan':
        return '🌅';
      case 'Makan Siang':
        return '☀️';
      case 'Makan Malam':
        return '🌙';
      case 'Snack':
        return '🍪';
      default:
        return '🍽️';
    }
  }

  Future<void> _saveMeal() async {
    if (_foodNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Masukkan nama makanan terlebih dahulu'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? userId = await SessionManager.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        return;
      }

      final now = DateTime.now();
      final loggedDate = DateFormat('yyyy-MM-dd').format(now);
      final loggedTime = DateFormat('HH:mm').format(now);

      await DatabaseHelper.instance.addMealLog(
        userId: userId,
        foodName: _foodNameController.text.trim(),
        mealType: _mealType,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        protein: _protein,
        carbs: _carbs,
        fat: _fats,
        emoji: _getEmojiForMealType(_mealType),
        date: loggedDate,
        time: loggedTime,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('${_foodNameController.text} berhasil dicatat!'),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Reset form
      _foodNameController.clear();
      _caloriesController.text = '0';
      _portionController.text = '100';
      setState(() {
        _protein = 0;
        _carbs = 0;
        _fats = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              child:
                  const Icon(Icons.person, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('NutriWise'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar makanan dari FatSecret API
            TextField(
              controller: _searchController,
              onChanged: (val) {
                if (val.length >= 2) {
                  _searchFood(val);
                } else {
                  setState(() => _searchResults = []);
                }
              },
              decoration: InputDecoration(
                hintText: 'Cari makanan via AI...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            // Search Results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final food = _searchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        food['name'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${(food['calories'] as num).toStringAsFixed(0)} kcal  •  P: ${(food['protein'] as num).toStringAsFixed(1)}g  •  K: ${(food['carbs'] as num).toStringAsFixed(1)}g  •  L: ${(food['fat'] as num).toStringAsFixed(1)}g',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: AppTheme.primary, size: 18),
                      ),
                      onTap: () => _selectFood(food),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Tipe Makanan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waktu Makan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _mealTypes.map((type) {
                      final isSelected = _mealType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _mealType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.bgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_getEmojiForMealType(type)} $type',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Form Input Manual
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LOG MANUAL',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.tertiary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Detail Nutrisi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 14),

            // Nama Makanan
            const Text(
              'Nama Makanan',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _foodNameController,
              decoration: InputDecoration(
                hintText: 'mis. Alpukat Organik',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                // Ukuran Porsi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ukuran Porsi',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 50,
                              child: TextField(
                                controller: _portionController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _portionUnit,
                                items: ['gram', 'ml', 'sajian']
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _portionUnit = v!),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Est. Kalori
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Est. Kalori',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _caloriesController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Text(
                                'kcal',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Nutrisi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NutrientInput(
                    label: 'PROTEIN',
                    value: _protein,
                    color: AppTheme.primary,
                    onChanged: (v) => setState(() => _protein = v),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _NutrientInput(
                    label: 'KARBO',
                    value: _carbs,
                    color: AppTheme.carbsColor,
                    onChanged: (v) => setState(() => _carbs = v),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _NutrientInput(
                    label: 'LEMAK',
                    value: _fats,
                    color: AppTheme.tertiary,
                    onChanged: (v) => setState(() => _fats = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMeal,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan ke Diary',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        // Quick add with minimal data
                        if (_foodNameController.text.trim().isNotEmpty) {
                          _saveMeal();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Masukkan nama makanan'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.bolt, color: AppTheme.primary),
                label: const Text(
                  'Tambah Cepat',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pro Tip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Manrope',
                        ),
                        children: [
                          TextSpan(
                            text: 'Pro Tip: ',
                            style: TextStyle(
                                color: AppTheme.tertiary,
                                fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text:
                                'Gunakan pencarian untuk menemukan makanan dari AI Gemini. Data nutrisi akan terisi otomatis!',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _NutrientInput extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _NutrientInput({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showEditDialog(context);
      },
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'tap to edit',
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: 'gram',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newVal = double.tryParse(controller.text) ?? value;
              onChanged(newVal);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
