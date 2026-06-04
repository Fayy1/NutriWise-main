import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin pluginNotifikasi =
      FlutterLocalNotificationsPlugin();
  static bool sudahDiinisialisasi = false;

  static Future<void> initialize() async {
    if (sudahDiinisialisasi) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await pluginNotifikasi.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    sudahDiinisialisasi = true;
  }

  static Future<void> tampilkanNotifikasi({
    required int id,
    required String judul,
    required String isi,
  }) async {
    if (!sudahDiinisialisasi) {
      await initialize();
    }

    await pluginNotifikasi.show(
      id: id,
      title: judul,
      body: isi,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutriwise_notif',
          'NutriWise Notifikasi',
          channelDescription: 'Notifikasi umum dari aplikasi NutriWise',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> tampilkanNotifikasiPreferensi(
      String namaPreferensi, bool statusBaru) async {
    final statusTeks = statusBaru ? 'diaktifkan' : 'dinonaktifkan';
    await tampilkanNotifikasi(
      id: 2001,
      judul: '⚙️ Preferensi Diubah',
      isi: '$namaPreferensi telah $statusTeks.',
    );
  }

  static Future<void> periksaInventoriDanNotifikasi(String userId) async {
    final dbHelper = DatabaseHelper.instance;

    final barangHampirHabis = await dbHelper.getLowStockItems(userId);
    if (barangHampirHabis.isNotEmpty) {
      final namaBarang =
          barangHampirHabis.map((item) => item['name'] as String).take(3).toList();
      final pesanBarang = namaBarang.join(', ');
      final sisaBarang = barangHampirHabis.length > 3
          ? ' dan ${barangHampirHabis.length - 3} lainnya'
          : '';

      await tampilkanNotifikasi(
        id: 1001,
        judul: '⚠️ Bahan Makanan Hampir Habis!',
        isi: '$pesanBarang$sisaBarang perlu diisi ulang.',
      );
    }

    final barangHampirKadaluarsa =
        await dbHelper.getExpiringItems(userId, 3);
    if (barangHampirKadaluarsa.isNotEmpty) {
      final namaBarang = barangHampirKadaluarsa
          .map((item) => item['name'] as String)
          .take(3)
          .toList();
      final pesanBarang = namaBarang.join(', ');
      final sisaBarang = barangHampirKadaluarsa.length > 3
          ? ' dan ${barangHampirKadaluarsa.length - 3} lainnya'
          : '';

      await tampilkanNotifikasi(
        id: 1002,
        judul: '🕐 Bahan Makanan Segera Kedaluwarsa!',
        isi: '$pesanBarang$sisaBarang akan kedaluwarsa dalam 3 hari.',
      );
    }
  }

  static Future<void> checkAndNotify(String userId) async {
    await periksaInventoriDanNotifikasi(userId);
  }
}
