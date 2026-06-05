import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the current logged-in user session via Supabase Auth.
class SessionManager {
  static final _supabase = Supabase.instance.client;

  // We still use SharedPreferences just to cache the name/email for quick UI access if needed,
  // but the real source of truth for auth is Supabase.
  static const _keyUserName = 'current_user_name';

  static Future<void> saveSession({
    required String userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, userName);
  }

  static Future<String?> getUserId() async {
    return _supabase.auth.currentUser?.id;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    return _supabase.auth.currentUser?.email;
  }

  static Future<bool> isLoggedIn() async {
    return _supabase.auth.currentSession != null;
  }

  static Future<void> clearSession() async {
    await _supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
