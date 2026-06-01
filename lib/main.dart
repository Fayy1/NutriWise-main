import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/profile_setup_screen.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_helper.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  DatabaseHelper.initFfi();

  await NotificationService.initialize();

  final sudahLogin = await SessionManager.isLoggedIn();
  bool profilSelesai = true;
  String? userId;
  String? userName;

  if (sudahLogin) {
    userId = await SessionManager.getUserId();
    userName = await SessionManager.getUserName() ?? 'User';
    if (userId != null) {
      final user = await DatabaseHelper.instance.getUserById(userId);
      profilSelesai = user?['profile_completed'] as bool? ?? false;
    }
  }

  runApp(AppNutriWise(
    isLoggedIn: sudahLogin,
    profileCompleted: profilSelesai,
    userId: userId,
    userName: userName,
  ));
}

class AppNutriWise extends StatelessWidget {
  final bool isLoggedIn;
  final bool profileCompleted;
  final String? userId;
  final String? userName;

  const AppNutriWise({
    super.key,
    required this.isLoggedIn,
    required this.profileCompleted,
    this.userId,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    Widget halamanAwal;
    if (!isLoggedIn) {
      halamanAwal = const LoginScreen();
    } else if (!profileCompleted && userId != null) {
      halamanAwal =
          ProfileSetupScreen(userId: userId!, userName: userName ?? 'User');
    } else {
      halamanAwal = const MainNavigation();
    }

    return MaterialApp(
      title: 'NutriWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: halamanAwal,
    );
  }
}
