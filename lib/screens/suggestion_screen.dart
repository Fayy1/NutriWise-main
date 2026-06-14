import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../services/gemini_service.dart';

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allRecipes = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_isRefreshing) setState(() => _isLoading = true);
    _userId = await SessionManager.getUserId();
    if (_userId == null) return;

    final inventory = await DatabaseHelper.instance.getInventory(_userId!);
    final validInventory = inventory.where((i) => (i['quantity'] as num? ?? 0) > 0).toList();
    final itemNames = validInventory.map((i) => i['name'] as String).toList();

    if (itemNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _inventoryItems = validInventory;
        _allRecipes = [];
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final recipes = await GeminiService.getSuggestionsFromInventory(itemNames);

    if (!mounted) return;
    setState(() {
      _inventoryItems = validInventory;
      _allRecipes = recipes;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadData();
  }

  List<Map<String, dynamic>> get _highMatchRecipes =>
      _allRecipes.where((r) => (r['match_percentage'] as int) >= 70).toList();

  List<Map<String, dynamic>> get _lowCalRecipes {
    final sorted = List<Map<String, dynamic>>.from(_allRecipes);
    sorted.sort((a, b) => (a['calories'] as int).compareTo(b['calories'] as int));
    return sorted;
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
            child: const Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 8),
          const Text('NutriWise'),
        ]),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Manrope'),
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'SEMUA'),
            Tab(text: 'MATCH TINGGI'),
            Tab(text: 'RENDAH KALORI'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Inventory chips
                if (_inventoryItems.isNotEmpty) _buildInventoryChips(),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecipeList(_allRecipes),
                      _buildRecipeList(_highMatchRecipes),
                      _buildRecipeList(_lowCalRecipes),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI sedang meracik saran resep...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Menganalisis bahan di inventorimu',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Bahan di inventorimu:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const Spacer(),
            Text('${_inventoryItems.length} bahan', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _inventoryItems.length,
              itemBuilder: (context, i) {
                final item = _inventoryItems[i];
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Text(item['emoji'] as String? ?? '🥫', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(item['name'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList(List<Map<String, dynamic>> recipes) {
    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Tidak ada resep ditemukan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Tambahkan lebih banyak bahan di Inventori', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recipes.length,
        itemBuilder: (context, index) => _RecipeCard(recipe: recipes[index]),
      ),
    );
  }
}

class _RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const _RecipeCard({required this.recipe});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _isExpanded = false;

  Color _matchColor(int pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  String _matchLabel(int pct) {
    if (pct >= 80) return 'Match Tinggi';
    if (pct >= 50) return 'Match Sedang';
    return 'Banyak Kurang';
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final matchPct = recipe['match_percentage'] as int? ?? 0;
    final matchColor = _matchColor(matchPct);
    final ownedIngredients = List<String>.from(recipe['owned_ingredients'] ?? []);
    final missingIngredients = List<String>.from(recipe['missing_ingredients'] ?? []);
    final requiredIngredients = List<String>.from(recipe['required_ingredients'] ?? []);

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: matchColor.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(recipe['emoji'] as String? ?? '🍽️', style: const TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              recipe['name'] as String? ?? 'Resep',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                          ),
                          Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.textMuted, size: 20),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          recipe['description'] as String? ?? '',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Match progress bar
                        Row(children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: matchPct / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$matchPct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: matchColor)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: matchColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(_matchLabel(matchPct), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: matchColor)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Text('${recipe['calories']} kcal', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expanded details
            if (_isExpanded) ...[
              Divider(height: 1, color: Colors.grey.shade100),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nutrition row
                    Row(children: [
                      _NutriBadge(label: 'Karbo', value: '${(recipe['carbs'] as num?)?.toStringAsFixed(0) ?? '?'}g', color: AppTheme.carbsColor),
                      const SizedBox(width: 8),
                      _NutriBadge(label: 'Protein', value: '${(recipe['protein'] as num?)?.toStringAsFixed(0) ?? '?'}g', color: AppTheme.primary),
                      const SizedBox(width: 8),
                      _NutriBadge(label: 'Lemak', value: '${(recipe['fat'] as num?)?.toStringAsFixed(0) ?? '?'}g', color: AppTheme.tertiary),
                    ]),
                    const SizedBox(height: 14),

                    // Owned ingredients
                    if (ownedIngredients.isNotEmpty) ...[
                      const Text('✅ Bahan yang kamu punya:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ownedIngredients.map((ing) => _IngredientChip(name: ing, isOwned: true)).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Missing ingredients
                    if (missingIngredients.isNotEmpty) ...[
                      const Text('❌ Bahan yang kurang:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: missingIngredients.map((ing) => _IngredientChip(name: ing, isOwned: false)).toList(),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(children: [
                          const Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kamu perlu membeli: ${missingIngredients.take(5).join(', ')}',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                    ] else if (requiredIngredients.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                        child: const Row(children: [
                          Text('🎉', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('Semua bahan tersedia! Bisa langsung masak!', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutriBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NutriBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  final String name;
  final bool isOwned;
  const _IngredientChip({required this.name, required this.isOwned});

  @override
  Widget build(BuildContext context) {
    final color = isOwned ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isOwned ? Icons.check : Icons.close, size: 12, color: color),
        const SizedBox(width: 4),
        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
