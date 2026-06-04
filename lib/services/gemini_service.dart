import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service untuk Google AI Studio (Gemini 2.5 Flash).
/// Persona: Ahli Gizi profesional Indonesia.
/// Digunakan untuk:
/// 1. Mendapatkan info nutrisi dari nama makanan
/// 2. Mendapatkan saran resep dari bahan inventori
/// 3. Search makanan via AI
class GeminiService {
  static String get _apiKey => AppConfig.geminiApiKey;
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // Persona sistem sebagai ahli gizi
  static const String _systemInstruction = '''
Kamu adalah NutriBot, asisten ahli gizi dan dietisien bersertifikat yang berpengalaman lebih dari 10 tahun.
Keahlianmu meliputi:
- Komposisi nutrisi makanan Indonesia dan internasional
- Perencanaan diet sehat dan seimbang berdasarkan kebutuhan individu
- Estimasi nilai gizi yang akurat berdasarkan berat porsi standar
- Saran resep bergizi yang mempertimbangkan kandungan makro dan mikro nutrisi

Kamu selalu memberikan estimasi nutrisi yang akurat, realistis, dan berdasarkan data ilmiah.
Untuk makanan Indonesia, gunakan standar porsi umum yang berlaku di Indonesia.
Semua nilai nutrisi HARUS dalam format angka (bukan string), dan WAJIB merespons HANYA dengan JSON valid tanpa teks tambahan apapun.
''';

  /// Panggil Gemini API dengan sistem instruksi ahli gizi.
  static Future<Map<String, dynamic>?> _callGemini(
    String prompt, {
    int maxOutputTokens = 8192,
    double temperature = 0.1,
  }) async {
    final url = Uri.parse('$_baseUrl?key=$_apiKey');

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
        'responseMimeType': 'application/json',
        'thinkingConfig': {
          'thinkingBudget': 0
        }
      },
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Cek apakah ada candidates
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          print('[GeminiService] No candidates in response: ${response.body}');
          return null;
        }

        final content = candidates[0]['content'];
        final parts = content?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          print('[GeminiService] No parts in candidate: ${response.body}');
          return null;
        }

        final text = parts[0]['text'] as String?;
        if (text == null || text.trim().isEmpty) {
          print('[GeminiService] Empty text in response');
          return null;
        }

        // Karena kita pakai responseMimeType: application/json,
        // response seharusnya langsung JSON. Coba parse langsung dulu.
        try {
          return jsonDecode(text) as Map<String, dynamic>;
        } catch (_) {
          // Fallback: ekstrak JSON dari teks jika ada markdown code block
          final cleaned = text
              .replaceAll(RegExp(r'```json\s*'), '')
              .replaceAll(RegExp(r'```\s*'), '')
              .trim();
          try {
            return jsonDecode(cleaned) as Map<String, dynamic>;
          } catch (e) {
            // Coba cari objek JSON dalam teks
            final jsonMatch =
                RegExp(r'\{[\s\S]*\}', multiLine: true).firstMatch(cleaned);
            if (jsonMatch != null) {
              try {
                return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
              } catch (e2) {
                print('[GeminiService] JSON parse error: $e2\nText: $cleaned');
              }
            }
          }
        }
        return null;
      } else {
        // Log error detail untuk debugging
        print(
            '[GeminiService] HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[GeminiService] Exception: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // NUTRISI INFO: dapatkan info gizi dari satu makanan
  // ─────────────────────────────────────────────────────────

  /// Dapatkan info nutrisi dari nama makanan.
  /// Return: {food_id, name, brand, calories, carbs, protein, fat}
  static Future<Map<String, dynamic>?> getNutritionInfo(
      String foodName) async {
    final prompt = '''
Sebagai ahli gizi, berikan informasi kandungan nutrisi untuk: "$foodName"

Estimasikan per 1 porsi standar yang umum dikonsumsi di Indonesia.
Respons HANYA dengan JSON valid berikut, tanpa teks atau penjelasan lain:
{
  "name": "nama makanan lengkap",
  "serving_size": "1 porsi (contoh: 100g / 1 mangkuk / 1 piring)",
  "calories": 250,
  "carbs": 30.5,
  "protein": 15.2,
  "fat": 8.3,
  "fiber": 2.1,
  "notes": "catatan singkat ahli gizi tentang makanan ini"
}

Pastikan semua nilai numerik adalah angka (bukan string).
''';

    final result = await _callGemini(prompt);
    if (result != null) {
      return {
        'food_id': 'ai_${DateTime.now().millisecondsSinceEpoch}',
        'name': result['name'] ?? foodName,
        'brand': 'Estimasi Ahli Gizi AI',
        'serving': result['serving_size'] ?? '1 porsi',
        'notes': result['notes'] ?? '',
        'calories': _toDouble(result['calories']),
        'carbs': _toDouble(result['carbs']),
        'protein': _toDouble(result['protein']),
        'fat': _toDouble(result['fat']),
        'fiber': _toDouble(result['fiber']),
      };
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // SEARCH MAKANAN: cari beberapa pilihan makanan
  // ─────────────────────────────────────────────────────────

  /// Search makanan dan return beberapa hasil nutrisi dari AI.
  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final prompt = '''
Sebagai ahli gizi, berikan 5 pilihan makanan yang relevan dengan kata kunci: "$query"

Untuk setiap makanan, berikan estimasi nutrisi per 1 porsi standar Indonesia.
Respons HANYA dengan JSON valid berikut, tanpa teks atau penjelasan lain:
{
  "foods": [
    {
      "name": "Nama Makanan Lengkap",
      "serving": "1 piring / 100g / dll",
      "calories": 250,
      "carbs": 30.5,
      "protein": 15.2,
      "fat": 8.3
    }
  ]
}

Urutkan dari yang paling umum/populer di Indonesia. Pastikan nilai nutrisi akurat dan realistis.
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': _systemInstruction}
                ]
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 8192,
                'responseMimeType': 'application/json',
                'thinkingConfig': {
                  'thinkingBudget': 0
                }
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

        if (text != null && text.isNotEmpty) {
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(text) as Map<String, dynamic>;
          } catch (_) {
            final cleaned = text
                .replaceAll(RegExp(r'```json\s*'), '')
                .replaceAll(RegExp(r'```\s*'), '')
                .trim();
            try {
              parsed = jsonDecode(cleaned) as Map<String, dynamic>;
            } catch (_) {
              final m = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
              if (m != null) {
                try {
                  parsed = jsonDecode(m.group(0)!) as Map<String, dynamic>;
                } catch (_) {}
              }
            }
          }

          if (parsed != null) {
            final foods = parsed['foods'] as List?;
            if (foods != null && foods.isNotEmpty) {
              return foods.asMap().entries.map<Map<String, dynamic>>((e) {
                final f = e.value as Map<String, dynamic>;
                return {
                  'food_id': 'ai_${DateTime.now().millisecondsSinceEpoch}_${e.key}',
                  'name': f['name'] ?? query,
                  'brand': 'Estimasi Ahli Gizi AI',
                  'serving': f['serving'] ?? '1 porsi',
                  'calories': _toDouble(f['calories']),
                  'carbs': _toDouble(f['carbs']),
                  'protein': _toDouble(f['protein']),
                  'fat': _toDouble(f['fat']),
                };
              }).toList();
            }
          }
        }
      } else {
        print('[GeminiService] searchFoods HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[GeminiService] searchFoods Exception: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────
  // SARAN RESEP: dari bahan inventori
  // ─────────────────────────────────────────────────────────

  /// Dapatkan saran resep dari bahan-bahan yang tersedia di inventori.
  static Future<List<Map<String, dynamic>>> getSuggestionsFromInventory(
      List<String> inventoryItems) async {
    if (inventoryItems.isEmpty) return [];

    final itemsStr = inventoryItems.take(20).join(', ');
    final prompt = '''
Sebagai ahli gizi berpengalaman, bantu saya memanfaatkan bahan-bahan dapur ini: $itemsStr

Sarankan 6 resep masakan Indonesia yang sehat dan bergizi. Prioritaskan resep dengan bahan yang paling banyak tersedia.
Respons HANYA dengan JSON valid berikut, tanpa teks atau penjelasan lain:
{
  "recipes": [
    {
      "name": "Nama Resep",
      "emoji": "🍳",
      "calories": 350,
      "carbs": 45.0,
      "protein": 20.0,
      "fat": 10.0,
      "required_ingredients": ["bahan1", "bahan2", "bahan3"],
      "owned_ingredients": ["bahan dari daftar yang dimiliki"],
      "missing_ingredients": ["bahan yang belum ada"],
      "match_percentage": 75,
      "description": "Deskripsi singkat manfaat gizi dari resep ini",
      "health_benefit": "Kaya protein / Rendah lemak / Tinggi serat / dll"
    }
  ]
}

Aturan:
- match_percentage = (jumlah owned_ingredients / jumlah required_ingredients) * 100, dibulatkan
- owned_ingredients HANYA boleh berisi bahan yang ada di daftar bahan user
- Urutkan dari match_percentage tertinggi ke terendah
- Pastikan semua nilai nutrisi adalah angka (bukan string)
- Pilih resep yang sehat dan seimbang secara nutrisi
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': _systemInstruction}
                ]
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.3,
                'maxOutputTokens': 8192,
                'responseMimeType': 'application/json',
                'thinkingConfig': {
                  'thinkingBudget': 0
                }
              },
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

        if (text != null && text.isNotEmpty) {
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(text) as Map<String, dynamic>;
          } catch (_) {
            final cleaned = text
                .replaceAll(RegExp(r'```json\s*'), '')
                .replaceAll(RegExp(r'```\s*'), '')
                .trim();
            try {
              parsed = jsonDecode(cleaned) as Map<String, dynamic>;
            } catch (_) {
              final m = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
              if (m != null) {
                try {
                  parsed = jsonDecode(m.group(0)!) as Map<String, dynamic>;
                } catch (_) {}
              }
            }
          }

          if (parsed != null) {
            final recipes = parsed['recipes'] as List?;
            if (recipes != null && recipes.isNotEmpty) {
              final result = recipes.map<Map<String, dynamic>>((r) {
                final recipe = r as Map<String, dynamic>;
                return {
                  'name': recipe['name'] ?? 'Resep',
                  'emoji': recipe['emoji'] ?? '🍽️',
                  'calories': (_toDouble(recipe['calories'])).toInt(),
                  'carbs': _toDouble(recipe['carbs']),
                  'protein': _toDouble(recipe['protein']),
                  'fat': _toDouble(recipe['fat']),
                  'required_ingredients':
                      List<String>.from(recipe['required_ingredients'] ?? []),
                  'owned_ingredients':
                      List<String>.from(recipe['owned_ingredients'] ?? []),
                  'missing_ingredients':
                      List<String>.from(recipe['missing_ingredients'] ?? []),
                  'match_percentage':
                      (_toDouble(recipe['match_percentage'])).toInt(),
                  'description': recipe['description'] ?? '',
                  'health_benefit': recipe['health_benefit'] ?? '',
                };
              }).toList();

              result.sort((a, b) => (b['match_percentage'] as int)
                  .compareTo(a['match_percentage'] as int));
              return result;
            }
          }
        }
      } else {
        print('[GeminiService] getSuggestions HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[GeminiService] getSuggestions Exception: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
