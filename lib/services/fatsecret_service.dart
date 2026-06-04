import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service for FatSecret Platform API (OAuth 2.0 Client Credentials).
/// Uses the public REST API v2 to search foods.
class FatSecretService {
  // FatSecret API credentials — replace with your own from
  // https://platform.fatsecret.com/api/
  static String get _clientId => AppConfig.fatSecretClientId;
  static String get _clientSecret => AppConfig.fatSecretClientSecret;
  static const String _tokenUrl = 'https://oauth.fatsecret.com/connect/token';
  static const String _apiUrl =
      'https://platform.fatsecret.com/rest/server.api';

  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Obtain an OAuth 2.0 access token using client credentials.
  static Future<String?> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $credentials',
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'basic',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now()
            .add(Duration(seconds: (data['expires_in'] as int) - 60));
        return _accessToken;
      } else {
        print('FatSecret Token Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('FatSecret Token Exception: $e');
    }
    return null;
  }

  /// Search for foods by name. Returns a list of food maps.
  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final token = await _getAccessToken();
    if (token == null) return _getMockData(query);

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'method': 'foods.search',
        'search_expression': query,
        'format': 'json',
        'max_results': '20',
        'region': 'ID',
        'language': 'id',
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['foods'] != null && data['foods']['food'] != null) {
          final foods = data['foods']['food'];
          if (foods is List) {
            return foods
                .map<Map<String, dynamic>>((f) => _parseFood(f))
                .toList();
          } else if (foods is Map) {
            return [_parseFood(foods)];
          }
        } else {
          print('FatSecret Search: No food found or error in format: ${response.body}');
          return _getMockData(query); // Fallback ke mock data
        }
      } else {
        print('FatSecret Search Error: ${response.statusCode} - ${response.body}');
        return _getMockData(query); // Fallback ke mock data
      }
    } catch (e) {
      print('FatSecret Search Exception: $e');
      return _getMockData(query); // Fallback ke mock data
    }
    return _getMockData(query);
  }

  /// Data cadangan sementara jika API FatSecret menolak IP (Masa tunggu 24 jam)
  static List<Map<String, dynamic>> _getMockData(String query) {
    print('Menggunakan data cadangan (Mock) untuk pencarian: $query');
    final queryLower = query.toLowerCase();
    
    final allMockData = [
      {'food_id': 'm1', 'name': 'Nasi Goreng', 'brand': 'Umum', 'calories': 300.0, 'carbs': 45.0, 'protein': 8.0, 'fat': 12.0},
      {'food_id': 'm2', 'name': 'Telur Ceplok', 'brand': 'Umum', 'calories': 92.0, 'carbs': 0.4, 'protein': 7.0, 'fat': 6.8},
      {'food_id': 'm3', 'name': 'Ayam Bakar', 'brand': 'Umum', 'calories': 220.0, 'carbs': 10.0, 'protein': 25.0, 'fat': 11.0},
      {'food_id': 'm4', 'name': 'Indomie Goreng', 'brand': 'Indofood', 'calories': 380.0, 'carbs': 54.0, 'protein': 8.0, 'fat': 14.0},
      {'food_id': 'm5', 'name': 'Susu UHT Full Cream', 'brand': 'Ultra Milk', 'calories': 150.0, 'carbs': 11.0, 'protein': 8.0, 'fat': 8.0},
      {'food_id': 'm6', 'name': 'Roti Gandum', 'brand': 'Sari Roti', 'calories': 130.0, 'carbs': 24.0, 'protein': 5.0, 'fat': 2.0},
    ];

    // Jika kata kunci kosong, kembalikan semua
    if (queryLower.isEmpty) return allMockData;

    // Filter berdasarkan kata kunci
    final filtered = allMockData.where((food) {
      return (food['name'] as String).toLowerCase().contains(queryLower) ||
             (food['brand'] as String).toLowerCase().contains(queryLower);
    }).toList();

    // Jika hasil filter kosong, tampilkan contoh dummy agar tidak kosong melompong
    if (filtered.isEmpty) {
      return [
        {'food_id': 'dummy', 'name': 'Hasil Dummy: $query', 'brand': 'Sistem Mock', 'calories': 100.0, 'carbs': 10.0, 'protein': 5.0, 'fat': 2.0}
      ];
    }
    
    return filtered;
  }

  /// Get detailed food info by food_id.
  static Future<Map<String, dynamic>?> getFoodDetail(String foodId) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'method': 'food.get.v4',
        'food_id': foodId,
        'format': 'json',
        'region': 'ID',
        'language': 'id',
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['food'] != null) {
          return _parseFoodDetail(data['food']);
        }
      }
    } catch (e) {
      // Detail fetch failed
    }
    return null;
  }

  /// Parse a food search result into a simplified map.
  static Map<String, dynamic> _parseFood(dynamic food) {
    final desc = food['food_description']?.toString() ?? '';
    final nutrients = _parseDescription(desc);

    return {
      'food_id': food['food_id']?.toString() ?? '',
      'name': food['food_name']?.toString() ?? 'Unknown',
      'brand': food['brand_name']?.toString() ?? '',
      'description': desc,
      'calories': nutrients['calories'] ?? 0.0,
      'fat': nutrients['fat'] ?? 0.0,
      'carbs': nutrients['carbs'] ?? 0.0,
      'protein': nutrients['protein'] ?? 0.0,
    };
  }

  /// Parse food detail into a simplified map.
  static Map<String, dynamic> _parseFoodDetail(dynamic food) {
    double calories = 0, fat = 0, carbs = 0, protein = 0;

    if (food['servings'] != null && food['servings']['serving'] != null) {
      var servings = food['servings']['serving'];
      Map<String, dynamic> serving;
      if (servings is List) {
        serving = servings.first;
      } else {
        serving = servings;
      }

      calories = double.tryParse(serving['calories']?.toString() ?? '0') ?? 0;
      fat = double.tryParse(serving['fat']?.toString() ?? '0') ?? 0;
      carbs = double.tryParse(serving['carbohydrate']?.toString() ?? '0') ?? 0;
      protein = double.tryParse(serving['protein']?.toString() ?? '0') ?? 0;
    }

    return {
      'food_id': food['food_id']?.toString() ?? '',
      'name': food['food_name']?.toString() ?? 'Unknown',
      'brand': food['brand_name']?.toString() ?? '',
      'calories': calories,
      'fat': fat,
      'carbs': carbs,
      'protein': protein,
    };
  }

  /// Parse the FatSecret description string to extract nutrients.
  /// Format: "Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g"
  static Map<String, double> _parseDescription(String desc) {
    final result = <String, double>{};

    final calMatch = RegExp(r'Calories:\s*([\d.]+)').firstMatch(desc);
    if (calMatch != null) {
      result['calories'] = double.tryParse(calMatch.group(1)!) ?? 0;
    }

    final fatMatch = RegExp(r'Fat:\s*([\d.]+)').firstMatch(desc);
    if (fatMatch != null) {
      result['fat'] = double.tryParse(fatMatch.group(1)!) ?? 0;
    }

    final carbsMatch = RegExp(r'Carbs:\s*([\d.]+)').firstMatch(desc);
    if (carbsMatch != null) {
      result['carbs'] = double.tryParse(carbsMatch.group(1)!) ?? 0;
    }

    final proteinMatch = RegExp(r'Protein:\s*([\d.]+)').firstMatch(desc);
    if (proteinMatch != null) {
      result['protein'] = double.tryParse(proteinMatch.group(1)!) ?? 0;
    }

    return result;
  }
}
