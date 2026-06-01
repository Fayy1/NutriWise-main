# NutriWise 🌿

Aplikasi mobile pelacak nutrisi dan kalori harian berbasis Flutter.

## Struktur Proyek

```
lib/
├── main.dart                    # Entry point aplikasi
├── theme/
│   └── app_theme.dart           # Konfigurasi warna & tema
├── models/
│   └── app_data.dart            # Model data & data dummy
├── widgets/
│   └── common_widgets.dart      # Widget reusable
└── screens/
    ├── main_navigation.dart     # Bottom navigation utama
    ├── home_screen.dart         # Halaman Home (kalori & nutrisi)
    ├── add_screen.dart          # Halaman Tambah Makanan
    ├── database_screen.dart     # Halaman Database Makanan
    └── profile_screen.dart      # Halaman Profil & Dashboard
```

## Fitur

- **Home**: Lingkaran progres kalori, progres nutrisi (Protein/Karbo/Lemak), log makanan hari ini
- **Tambah (Add)**: Search makanan, scan barcode, form manual, makanan terakhir
- **Database**: Library nutrisi 1000+ makanan, filter kategori, search real-time
- **Profil**: Onboarding BMR, dashboard pribadi, Mindful Toggles

## Design System

| Warna | Hex | Kegunaan |
|-------|-----|----------|
| Primary | #2E7D32 | Hijau gelap - aksi utama |
| Secondary | #66BB6A | Hijau muda - aksen |
| Tertiary | #FF9800 | Oranye - lemak & highlight |
| Neutral | #F8FAF8 | Background |

## Cara Menjalankan

```bash
# 1. Install dependencies
flutter pub get

# 2. Jalankan aplikasi
flutter run

# 3. Build APK (untuk tugas)
flutter build apk --release
```

## Untuk Font Manrope (Opsional)

Tambahkan paket `google_fonts` ke pubspec.yaml:

```yaml
dependencies:
  google_fonts: ^6.2.1
```

Lalu di `app_theme.dart`, ganti `fontFamily: 'Manrope'` dengan:

```dart
import 'package:google_fonts/google_fonts.dart';
// ...
textTheme: GoogleFonts.manropeTextTheme(),
```

## Mata Kuliah

Tugas Aplikasi Perangkat Bergerak - Konversi desain UI ke Flutter
