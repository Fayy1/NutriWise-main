import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_data.dart';
import '../widgets/common_widgets.dart';
import '../services/fatsecret_service.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import 'package:intl/intl.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});
  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _selectedCategory = 'Semua Makanan';
  List<FoodItem> _filteredLocal = AppData.foodDatabase;
  List<Map<String, dynamic>> _apiResults = [];
  bool _isSearchingApi = false;

  final List<String> _categories = ['Semua Makanan', 'Buah', 'Sayuran'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterLocal);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _filterLocal() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLocal = AppData.foodDatabase.where((food) {
        final matchesSearch = food.name.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'Semua Makanan' ||
            food.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _searchApi() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearchingApi = true);
    final results = await FatSecretService.searchFoods(query);
    if (!mounted) return;
    setState(() {
      _apiResults = results;
      _isSearchingApi = false;
    });
  }

  Future<void> _addToLog(
      String name, double cal, double p, double c, double f) async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;
    final now = DateTime.now();
    await DatabaseHelper.instance.addMealLog(
      userId: userId,
      foodName: name,
      mealType: 'Snack',
      calories: cal,
      protein: p,
      carbs: c,
      fat: f,
      emoji: '🍽️',
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm').format(now),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name ditambahkan ke catatan!'),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              child:
                  const Icon(Icons.person, color: AppTheme.primary, size: 18)),
          const SizedBox(width: 8),
          const Text('NutriWise'),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined), onPressed: () {})
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('PERPUSTAKAAN NUTRISI',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1))),
            const SizedBox(height: 8),
            RichText(
                text: const TextSpan(
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Manrope'),
                    children: [
                  TextSpan(text: 'Penuhi nutrisimu\ndengan '),
                  TextSpan(
                      text: 'presisi.',
                      style: TextStyle(
                          color: AppTheme.secondary,
                          fontStyle: FontStyle.italic))
                ])),
            const SizedBox(height: 14),
            // Search
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                          hintText: 'Cari makanan...',
                          prefixIcon: const Icon(Icons.search,
                              color: AppTheme.textMuted),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14)))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _searchApi();
                  _tabController.animateTo(1);
                },
                child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.cloud_download_outlined,
                        color: Colors.white, size: 22)),
              ),
            ]),
            const SizedBox(height: 10),
            // Tabs
            TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [Tab(text: 'Lokal'), Tab(text: 'FatSecret')]),
          ]),
        ),
        Expanded(
            child: TabBarView(controller: _tabController, children: [
          // Local tab
          _buildLocalList(),
          // API tab
          _buildApiList(),
        ])),
      ]),
    );
  }

  Widget _buildLocalList() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                            _filterLocal();
                          });
                        },
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(color: Colors.grey.shade300)),
                            child: Text(cat.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    letterSpacing: 0.5)))));
              }).toList()))),
      Expanded(
          child: _filteredLocal.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('🔍', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Makanan tidak ditemukan',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _filteredLocal.length,
                  itemBuilder: (context, index) {
                    final food = _filteredLocal[index];
                    return FoodCard(
                        emoji: food.emoji,
                        name: food.name,
                        calories: food.calories,
                        carbs: food.carbs,
                        protein: food.protein,
                        fat: food.fat,
                        onAddToLog: () => _addToLog(food.name, food.calories,
                            food.protein, food.carbs, food.fat));
                  })),
    ]);
  }

  Widget _buildApiList() {
    if (_isSearchingApi) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppTheme.primary),
        SizedBox(height: 16),
        Text('Mencari dari FatSecret...',
            style: TextStyle(color: AppTheme.textSecondary))
      ]));
    }
    if (_apiResults.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌐', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('Cari makanan dari FatSecret',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Ketik nama makanan lalu tap tombol cloud',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ]));
    }
    return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _apiResults.length,
        itemBuilder: (context, index) {
          final food = _apiResults[index];
          return FoodCard(
              emoji: '🌐',
              name: food['name'] as String,
              calories: (food['calories'] as num).toDouble(),
              carbs: (food['carbs'] as num).toDouble(),
              protein: (food['protein'] as num).toDouble(),
              fat: (food['fat'] as num).toDouble(),
              onAddToLog: () => _addToLog(
                  food['name'],
                  (food['calories'] as num).toDouble(),
                  (food['protein'] as num).toDouble(),
                  (food['carbs'] as num).toDouble(),
                  (food['fat'] as num).toDouble()));
        });
  }
}
