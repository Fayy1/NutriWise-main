import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../services/notification_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _items = [];
  String? _userId;
  bool _isLoading = true;

  final _categoryEmojis = {
    'Sayuran': '🥬', 'Buah': '🍎', 'Daging': '🥩', 'Ikan': '🐟',
    'Dairy': '🥛', 'Bumbu': '🧂', 'Biji-bijian': '🌾', 'Lainnya': '🥫',
  };

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;
    _userId = userId;
    final items = await DatabaseHelper.instance.getInventory(userId);
    if (!mounted) return;
    setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _addItem() async {
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddItemSheet(userId: _userId!, categoryEmojis: _categoryEmojis),
    );
    if (result == true) _loadInventory();
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _EditItemSheet(item: item, categoryEmojis: _categoryEmojis),
    );
    if (result == true) _loadInventory();
  }

  Future<void> _deleteItem(int id) async {
    await DatabaseHelper.instance.deleteInventoryItem(id);
    _loadInventory();
  }

  @override
  Widget build(BuildContext context) {
    final lowItems = _items.where((i) => (i['quantity'] as num) <= (i['low_threshold'] as num)).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 18)),
          const SizedBox(width: 8), const Text('NutriWise'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {
            if (_userId != null) NotificationService.checkAndNotify(_userId!);
          }),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : RefreshIndicator(
            onRefresh: _loadInventory, color: AppTheme.primary,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.tertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('INVENTORI', style: TextStyle(fontSize: 10, color: AppTheme.tertiary, fontWeight: FontWeight.w800, letterSpacing: 1))),
                  const SizedBox(height: 8),
                  const Text('Bahan Makananmu', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${_items.length} bahan tersimpan', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),

                  if (lowItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('⚠️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${lowItems.length} bahan hampir habis!',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                          const SizedBox(height: 2),
                          Text(lowItems.map((i) => i['name']).take(3).join(', '),
                            style: TextStyle(fontSize: 12, color: Colors.red.shade500)),
                        ])),
                      ])),
                  ],
                ]),
              )),

              if (_items.isEmpty)
                SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📦', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  const Text('Inventori kosong', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Tambahkan bahan makananmu', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Tambah Bahan'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary)),
                ])))
              else
                SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _items[index];
                  final isLow = (item['quantity'] as num) <= (item['low_threshold'] as num);
                  final emoji = item['emoji'] as String? ?? '🥫';
                  final expiryStr = item['expiry_date'] as String?;
                  String? expiryLabel;
                  bool isExpiringSoon = false;
                  if (expiryStr != null && expiryStr.isNotEmpty) {
                    try {
                      final expiry = DateTime.parse(expiryStr);
                      final daysLeft = expiry.difference(DateTime.now()).inDays;
                      if (daysLeft < 0) { expiryLabel = 'Kedaluwarsa!'; isExpiringSoon = true; }
                      else if (daysLeft <= 3) { expiryLabel = '$daysLeft hari lagi'; isExpiringSoon = true; }
                      else { expiryLabel = DateFormat('dd MMM yyyy').format(expiry); }
                    } catch (_) {}
                  }

                  return Dismissible(
                    key: Key('inv_${item['id']}'),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.delete_outline, color: Colors.white)),
                    onDismissed: (_) => _deleteItem(item['id'] as int),
                    child: GestureDetector(
                      onTap: () => _editItem(item),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor, borderRadius: BorderRadius.circular(14),
                          border: isLow ? Border.all(color: Colors.red.shade300, width: 1.5) : null),
                        child: Row(children: [
                          Container(width: 48, height: 48,
                            decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text('${(item['quantity'] as num).toStringAsFixed(0)} ${item['unit']}',
                                style: TextStyle(fontSize: 12, color: isLow ? Colors.red : AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                              if (expiryLabel != null) ...[
                                const Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                                Text(expiryLabel, style: TextStyle(fontSize: 11, color: isExpiringSoon ? Colors.red : AppTheme.textMuted)),
                              ],
                            ]),
                          ])),
                          if (isLow) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text('LOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red.shade600))),
                        ]),
                      ),
                    ),
                  );
                }, childCount: _items.length)),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ]),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem, backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final String userId;
  final Map<String, String> categoryEmojis;
  const _AddItemSheet({required this.userId, required this.categoryEmojis});
  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '100');
  String _unit = 'gram';
  String _category = 'Lainnya';
  DateTime? _expiryDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Tambah Bahan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Nama bahan', filled: true, fillColor: AppTheme.bgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Jumlah', filled: true, fillColor: AppTheme.bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _unit,
              items: ['gram', 'kg', 'ml', 'liter', 'buah', 'bungkus'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => setState(() => _unit = v!)))),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _category, isExpanded: true,
            items: widget.categoryEmojis.keys.map((c) => DropdownMenuItem(value: c,
              child: Text('${widget.categoryEmojis[c]} $c'))).toList(),
            onChanged: (v) => setState(() => _category = v!)))),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (picked != null) setState(() => _expiryDate = picked);
          },
          child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Text(_expiryDate != null ? DateFormat('dd MMM yyyy').format(_expiryDate!) : 'Tanggal kedaluwarsa (opsional)',
                style: TextStyle(color: _expiryDate != null ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 14)),
            ]))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            
            final qty = double.tryParse(_qtyCtrl.text) ?? 100;
            // Admin automation: auto set low threshold to 20% of initial input
            final autoLowThreshold = qty * 0.2;

            await DatabaseHelper.instance.addInventoryItem(
              userId: widget.userId, name: _nameCtrl.text.trim(),
              quantity: qty, unit: _unit,
              category: _category, emoji: widget.categoryEmojis[_category] ?? '🥫',
              expiryDate: _expiryDate?.toIso8601String().substring(0, 10),
              lowThreshold: autoLowThreshold,
            );
            if (!mounted) return;
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)))),
        const SizedBox(height: 20),
      ])),
    );
  }
}

class _EditItemSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final Map<String, String> categoryEmojis;
  const _EditItemSheet({required this.item, required this.categoryEmojis});
  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: (widget.item['quantity'] as num).toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Edit ${widget.item['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, autofocus: true,
          decoration: InputDecoration(hintText: 'Jumlah baru', suffixText: widget.item['unit'] as String, filled: true, fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: () async {
            await DatabaseHelper.instance.updateInventoryQuantity(widget.item['id'] as int,
              double.tryParse(_qtyCtrl.text) ?? 0);
            if (!mounted) return;
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800)))),
        const SizedBox(height: 20),
      ]),
    );
  }
}
