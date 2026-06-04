import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  static final _supabase = Supabase.instance.client;

  static void initFfi() {}

  Future<String> daftarkanPengguna({
    required String nama,
    required String email,
    required String password,
  }) async {
    final AuthResponse res = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (res.user != null) {
      await _supabase.from('profiles').insert({
        'id': res.user!.id,
        'name': nama,
        'daily_calorie_target': 2000,
        'activity_level': 'Sedentary',
        'carbs_target': 250,
        'protein_target': 150,
        'fat_target': 65,
        'use_formula': true,
        'profile_completed': false,
      });
      return res.user!.id;
    }
    throw Exception('Gagal membuat akun');
  }

  Future<String> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    return daftarkanPengguna(nama: name, email: email, password: password);
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final AuthResponse res = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user != null) {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', res.user!.id)
          .single();
      return data;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('profiles').update(data).eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCalorieTarget(String userId, double target) async {
    await _supabase
        .from('profiles')
        .update({'daily_calorie_target': target.toInt()}).eq('id', userId);
  }

  Future<int> addMealLog({
    required String userId,
    required String foodName,
    required String mealType,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    String? emoji,
    required String time,
    required String date,
  }) async {
    final response = await _supabase.from('meal_logs').insert({
      'user_id': userId,
      'food_name': foodName,
      'meal_type': mealType,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'emoji': emoji ?? '🍽️',
      'time': time,
      'date': date,
    }).select('id').single();

    return response['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getMealLogs(
      String userId, String date) async {
    return await _supabase
        .from('meal_logs')
        .select()
        .eq('user_id', userId)
        .eq('date', date)
        .order('created_at', ascending: false);
  }

  Future<Map<String, double>> getDailyNutrition(
      String userId, String date) async {
    final logs = await getMealLogs(userId, date);
    double calories = 0, protein = 0, carbs = 0, fat = 0;

    for (var log in logs) {
      calories += (log['calories'] as num).toDouble();
      protein += (log['protein'] as num).toDouble();
      carbs += (log['carbs'] as num).toDouble();
      fat += (log['fat'] as num).toDouble();
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  Future<void> deleteMealLog(int id) async {
    await _supabase.from('meal_logs').delete().eq('id', id);
  }

  Future<int> addInventoryItem({
    required String userId,
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required String emoji,
    String? expiryDate,
    required double lowThreshold,
  }) async {
    final response = await _supabase.from('inventory').insert({
      'user_id': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'emoji': emoji,
      'expiry_date': expiryDate,
      'low_threshold': lowThreshold,
    }).select('id').single();

    return response['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getInventory(String userId) async {
    return await _supabase
        .from('inventory')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> updateInventoryQuantity(int id, double quantity) async {
    await _supabase
        .from('inventory')
        .update({'quantity': quantity}).eq('id', id);
  }

  Future<void> deleteInventoryItem(int id) async {
    await _supabase.from('inventory').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getLowStockItems(String userId) async {
    final items = await getInventory(userId);
    return items
        .where((item) =>
            (item['quantity'] as num) <= (item['low_threshold'] as num))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getExpiringItems(
      String userId, int hariKedepan) async {
    final items = await getInventory(userId);
    final hariIni = DateTime.now();
    final tanggalBatas = hariIni.add(Duration(days: hariKedepan));

    return items.where((item) {
      if (item['expiry_date'] == null ||
          item['expiry_date'].toString().isEmpty) { return false; }
      try {
        final tanggalKadaluarsa = DateTime.parse(item['expiry_date']);
        return tanggalKadaluarsa
                .isAfter(hariIni.subtract(const Duration(days: 1))) &&
            tanggalKadaluarsa
                .isBefore(tanggalBatas.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }
}
