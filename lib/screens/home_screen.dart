import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../services/notification_service.dart';
import '../services/gemini_service.dart';
import '../widgets/common_widgets.dart';
import 'add_food_fab_sheet.dart';
import 'suggestion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  double _calorieTarget = 2000;
  double _carbsTarget = 250;
  double _proteinTarget = 150;
  double _fatTarget = 65;

  double _consumed = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;

  List<Map<String, dynamic>> _todayMeals = [];
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoadingRecs = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = await SessionManager.getUserId();
    final userName = await SessionManager.getUserName();

    if (userId == null) return;

    _userId = userId;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final user = await DatabaseHelper.instance.getUserById(userId);
    final meals = await DatabaseHelper.instance.getMealLogs(userId, today);
    final summary = await DatabaseHelper.instance.getDailyNutrition(userId, today);

    // Check notifications for inventory
    await NotificationService.checkAndNotify(userId);

    if (!mounted) return;
    setState(() {
      _userName = userName ?? 'User';
      _calorieTarget = (user?['daily_calorie_target'] as num?)?.toDouble() ?? 2000;
      _carbsTarget = (user?['carbs_target'] as num?)?.toDouble() ?? 250;
      _proteinTarget = (user?['protein_target'] as num?)?.toDouble() ?? 150;
      _fatTarget = (user?['fat_target'] as num?)?.toDouble() ?? 65;

      _consumed = summary['calories'] ?? 0;
      _protein = summary['protein'] ?? 0;
      _carbs = summary['carbs'] ?? 0;
      _fats = summary['fats'] ?? 0;
      _todayMeals = meals;
    });

    _loadRecommendations(userId);
  }

  Future<void> _loadRecommendations(String userId) async {
    setState(() => _isLoadingRecs = true);
    final inventory = await DatabaseHelper.instance.getInventory(userId);
    final validInventory = inventory.where((i) => (i['quantity'] as num? ?? 0) > 0).toList();
    final items = validInventory.map((i) => i['name'] as String).toList();
    
    if (items.isEmpty) {
      if (!mounted) return;
      setState(() {
        _recommendations = [];
        _isLoadingRecs = false;
      });
      return;
    }

    // Panggil Gemini AI untuk rekomendasi
    final recs = await GeminiService.getSuggestionsFromInventory(items);
    
    if (!mounted) return;
    setState(() {
      _recommendations = recs.take(3).toList();
      _isLoadingRecs = false;
    });
  }

  Future<void> _deleteMeal(int mealId) async {
    await DatabaseHelper.instance.deleteMealLog(mealId);
    await _loadData();
  }

  void _showAddFoodSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddFoodFabSheet(),
    );

    if (result == true) {
      _loadData();
    }
  }

  Color _matchColor(int pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _calorieTarget - _consumed;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFoodSheet,
        backgroundColor: AppTheme.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            // AppBar Custom
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              snap: true,
              backgroundColor: AppTheme.bgColor,
              elevation: 0,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('NutriWise', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppTheme.textSecondary),
                  onPressed: () {
                    if (_userId != null) {
                      NotificationService.checkAndNotify(_userId!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mengecek notifikasi inventori...'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Halo, ${_userName.split(' ').first}! 👋',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text('Pantau nutrisi harianmu', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),

                    // Kalori Ring Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          CalorieRingWidget(consumed: _consumed, target: _calorieTarget),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(label: 'Target Harian', value: _calorieTarget.toStringAsFixed(0), unit: 'kcal', color: AppTheme.textPrimary),
                              Container(width: 1, height: 40, color: Colors.grey.shade200),
                              _StatItem(label: 'Sisa', value: remaining.toStringAsFixed(0), unit: 'kcal', color: remaining >= 0 ? AppTheme.primary : Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nutrisi Progress
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Progres Nutrisi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          const SizedBox(height: 16),
                          NutrientProgressBar(label: 'Protein', current: _protein, goal: _proteinTarget, color: AppTheme.primary, icon: Icons.fitness_center),
                          const SizedBox(height: 14),
                          NutrientProgressBar(label: 'Karbohidrat', current: _carbs, goal: _carbsTarget, color: AppTheme.carbsColor, icon: Icons.grain),
                          const SizedBox(height: 14),
                          NutrientProgressBar(label: 'Lemak', current: _fats, goal: _fatTarget, color: AppTheme.tertiary, icon: Icons.water_drop_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rekomendasi Makanan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Saran Resep AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            SizedBox(height: 4),
                            Text('Berdasarkan bahan di inventorimu', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestionScreen()));
                          },
                          child: const Text('Lihat Semua →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoadingRecs)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
                      )
                    else if (_recommendations.isNotEmpty)
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            final rec = _recommendations[index];
                            final matchPct = rec['match_percentage'] as int? ?? 0;
                            final color = _matchColor(matchPct);

                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestionScreen())),
                              child: Container(
                                width: 170,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade100),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(rec['emoji'] as String? ?? '🍽️', style: const TextStyle(fontSize: 24)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text('$matchPct% Match', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      rec['name'] as String,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        const Icon(Icons.local_fire_department, size: 12, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text('${rec['calories']} kcal', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (rec['missing_ingredients'] as List).isEmpty 
                                        ? 'Semua bahan tersedia!' 
                                        : 'Kurang: ${(rec['missing_ingredients'] as List).take(2).join(', ')}',
                                      style: TextStyle(
                                        fontSize: 10, 
                                        color: (rec['missing_ingredients'] as List).isEmpty ? Colors.green : Colors.red,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                        child: const Text(
                          'Tambahkan bahan ke inventori untuk mendapatkan saran resep dari AI.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    const SizedBox(height: 24),

                    // Makanan Hari Ini
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Makanan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('${_todayMeals.length} item', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_todayMeals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                        child: const Column(
                          children: [
                            Text('🍽️', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 10),
                            Text('Belum ada makanan tercatat', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text('Tap tombol + di bawah untuk menambahkan', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ..._todayMeals.map((meal) => Dismissible(
                            key: Key('meal_${meal['id']}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteMeal(meal['id'] as int),
                            child: MealLogTile(
                              emoji: meal['emoji'] as String? ?? '🍽️',
                              foodName: meal['food_name'] as String,
                              mealType: meal['meal_type'] as String,
                              time: meal['time'] as String? ?? '--:--',
                              calories: (meal['calories'] as num).toDouble(),
                            ),
                          )),

                    const SizedBox(height: 80), // Padding for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, fontFamily: 'Manrope')),
              TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Manrope')),
            ],
          ),
        ),
      ],
    );
  }
}
