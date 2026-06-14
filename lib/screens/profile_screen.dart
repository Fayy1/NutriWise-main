import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import '../services/session_manager.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'nutrition_targets_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _sedangEditProfil = false;
  String _aktivitasDipilih = 'Sedentary';
  bool _pengingatHidrasi = true;
  bool _pencatatanMakan = false;
  bool _jendelaPuasa = true;
  double _targetKalori = 2000;

  String _nama = 'User';
  int _usia = 25;
  String _jenisKelamin = 'Laki-laki';
  double _beratBadan = 70;
  double _tinggiBadan = 170;
  double _targetBerat = 65;
  int _targetKarbo = 250;
  int _targetProtein = 150;
  int _targetLemak = 65;
  bool _pakaiRumus = true;
  String? _userId;

  final List<Map<String, String>> _pilihanAktivitas = [
    {'value': 'Sedentary', 'label': 'Jarang', 'desc': 'Olahraga 0-30 menit/hari'},
    {'value': 'Moderately Active', 'label': 'Cukup Aktif', 'desc': 'Olahraga 30-60 menit/hari'},
    {'value': 'Very Active', 'label': 'Sangat Aktif', 'desc': 'Olahraga 60-120 menit/hari'},
  ];

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  Future<void> _muatProfil() async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;
    _userId = userId;
    final user = await DatabaseHelper.instance.getUserById(userId);
    if (user == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nama = user['name'] as String? ?? 'User';
      _usia = user['age'] as int? ?? 25;
      _jenisKelamin = user['gender'] as String? ?? 'Laki-laki';
      _beratBadan = (user['weight'] as num?)?.toDouble() ?? 70;
      _tinggiBadan = (user['height'] as num?)?.toDouble() ?? 170;
      _aktivitasDipilih = user['activity_level'] as String? ?? 'Sedentary';
      _targetKalori = (user['daily_calorie_target'] as num?)?.toDouble() ?? 2000;
      _targetBerat = (user['target_weight'] as num?)?.toDouble() ?? 65;
      _targetKarbo = user['carbs_target'] as int? ?? 250;
      _targetProtein = user['protein_target'] as int? ?? 150;
      _targetLemak = user['fat_target'] as int? ?? 65;
      _pakaiRumus = user['use_formula'] as bool? ?? true;

      _pengingatHidrasi = prefs.getBool('toggle_hidrasi_$userId') ?? true;
      _pencatatanMakan = prefs.getBool('toggle_makan_$userId') ?? false;
      _jendelaPuasa = prefs.getBool('toggle_puasa_$userId') ?? true;
    });
  }

  Future<void> _simpanToggle(String kunci, bool nilai, String namaPreferensi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('toggle_${kunci}_$_userId', nilai);
    await NotificationService.tampilkanNotifikasiPreferensi(namaPreferensi, nilai);
  }

  Future<void> _simpanProfil() async {
    if (_userId == null) return;
    await DatabaseHelper.instance.updateUserProfile(_userId!, {
      'age': _usia,
      'gender': _jenisKelamin,
      'weight': _beratBadan,
      'height': _tinggiBadan,
      'activity_level': _aktivitasDipilih,
      'daily_calorie_target': _targetKalori.toInt(),
      'target_weight': _targetBerat,
    });
    if (!mounted) return;
    setState(() => _sedangEditProfil = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profil berhasil disimpan!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _perbaruiTargetKalori(double nilai) async {
    setState(() => _targetKalori = nilai);
    if (_userId != null) {
      await DatabaseHelper.instance.updateCalorieTarget(_userId!, nilai);
    }
  }

  Future<void> _keluar() async {
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _editAngka(String judul, double nilaiSekarang, ValueChanged<double> simpan) {
    final controller = TextEditingController(
        text: nilaiSekarang.toStringAsFixed(
            nilaiSekarang == nilaiSekarang.roundToDouble() ? 0 : 1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $judul',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              simpan(double.tryParse(controller.text) ?? nilaiSekarang);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _pilihJenisKelamin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pilih Gender',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Laki-laki', 'Perempuan']
              .map((g) => ListTile(
                    leading: Text(g == 'Laki-laki' ? '👨' : '👩',
                        style: const TextStyle(fontSize: 20)),
                    title: Text(g),
                    onTap: () {
                      setState(() => _jenisKelamin = g);
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _sedangEditProfil ? _tampilkanFormEditProfil() : _tampilkanDashboardProfil();
  }

  Widget _tampilkanFormEditProfil() {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => setState(() => _sedangEditProfil = false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('EDIT PROFIL',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 8),
          const Text('Lengkapi Profilmu',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _KartuTerEdit(
                    label: 'USIA',
                    value: '$_usia',
                    unit: 'tahun',
                    onTap: () => _editAngka('Usia', _usia.toDouble(),
                        (v) => setState(() => _usia = v.toInt())))),
            const SizedBox(width: 12),
            Expanded(
                child: _KartuInfo(
                    label: 'GENDER',
                    value: _jenisKelamin,
                    isDropdown: true,
                    onTap: _pilihJenisKelamin)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _KartuTerEdit(
                    label: 'BERAT BADAN',
                    value: _beratBadan.toStringAsFixed(1),
                    unit: 'kg',
                    onTap: () => _editAngka('Berat Badan', _beratBadan,
                        (v) => setState(() => _beratBadan = v)))),
            const SizedBox(width: 12),
            Expanded(
                child: _KartuTerEdit(
                    label: 'TINGGI BADAN',
                    value: _tinggiBadan.toStringAsFixed(0),
                    unit: 'cm',
                    onTap: () => _editAngka('Tinggi Badan', _tinggiBadan,
                        (v) => setState(() => _tinggiBadan = v)))),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('TINGKAT AKTIVITAS HARIAN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1)),
              const SizedBox(height: 12),
              ..._pilihanAktivitas.map((opsi) {
                final dipilih = _aktivitasDipilih == opsi['value'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _aktivitasDipilih = opsi['value']!),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dipilih
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: dipilih
                          ? Border.all(color: AppTheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Row(children: [
                      Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: dipilih
                                      ? AppTheme.primary
                                      : Colors.grey.shade400,
                                  width: 2)),
                          child: dipilih
                              ? const Center(
                                  child: CircleAvatar(
                                      radius: 5,
                                      backgroundColor: AppTheme.primary))
                              : null),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(opsi['label']!,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: dipilih
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary)),
                        Text(opsi['desc']!,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ]),
                    ]),
                  ),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                  onPressed: _simpanProfil,
                  child: const Text('SIMPAN PROFIL',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 1)))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _tampilkanDashboardProfil() {
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
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () async {
                await NotificationService.tampilkanNotifikasi(
                  id: 9001,
                  judul: '🔔 NutriWise',
                  isi: 'Selamat datang kembali! Yuk catat nutrisimu hari ini.',
                );
              })
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Text(_nama,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  Text('$_jenisKelamin • $_usia tahun',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                ])),
                GestureDetector(
                  onTap: () => setState(() => _sedangEditProfil = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _StatProfil(label: 'Berat', value: '${_beratBadan.toStringAsFixed(1)} kg'),
                const SizedBox(width: 1, height: 30),
                _StatProfil(label: 'Tinggi', value: '${_tinggiBadan.toStringAsFixed(0)} cm'),
                const SizedBox(width: 1, height: 30),
                _StatProfil(label: 'Target', value: '${_targetBerat.toStringAsFixed(1)} kg'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('ANGGARAN ENERGI HARIAN',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('SLIDER',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                Text(_targetKalori.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary)),
                const SizedBox(width: 6),
                const Text('kcal',
                    style: TextStyle(
                        fontSize: 16, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                    thumbColor: AppTheme.primary,
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 4,
                    overlayShape: SliderComponentShape.noOverlay),
                child: Slider(
                    value: _targetKalori,
                    min: 1200,
                    max: 4000,
                    divisions: 56,
                    onChanged: (v) => _perbaruiTargetKalori(v)),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('1200 KCAL',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                Text('4000 KCAL',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TARGET NUTRISI',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            NutritionTargetsScreen(userId: _userId ?? '')),
                  ).then((_) => _muatProfil()),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Setting →',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _ChipNutrisi(
                        emoji: '🌾',
                        label: 'Karbo',
                        value: '${_targetKarbo}g',
                        color: AppTheme.carbsColor)),
                const SizedBox(width: 8),
                Expanded(
                    child: _ChipNutrisi(
                        emoji: '💪',
                        label: 'Protein',
                        value: '${_targetProtein}g',
                        color: AppTheme.primary)),
                const SizedBox(width: 8),
                Expanded(
                    child: _ChipNutrisi(
                        emoji: '🥑',
                        label: 'Lemak',
                        value: '${_targetLemak}g',
                        color: AppTheme.tertiary)),
              ]),
              if (!_pakaiRumus) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppTheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.tertiary),
                    SizedBox(width: 6),
                    Text('Target diatur manual',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.tertiary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
                child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BERAT SEKARANG',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${_beratBadan.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
              ]),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TARGET BERAT',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${_targetBerat.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.carbsColor)),
              ]),
            )),
          ]),
          const SizedBox(height: 16),

          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Mindful Toggles',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary))),
          const SizedBox(height: 10),
          _TileToggle(
              icon: '💧',
              title: 'Pengingat Hidrasi',
              subtitle: 'Pengingat lembut setiap 2 jam',
              value: _pengingatHidrasi,
              onChanged: (v) {
                setState(() => _pengingatHidrasi = v);
                _simpanToggle('hidrasi', v, 'Pengingat Hidrasi');
              }),
          _TileToggle(
              icon: '🍽️',
              title: 'Pencatatan Makanan',
              subtitle: 'Ringkasan harian jam 20:00',
              value: _pencatatanMakan,
              onChanged: (v) {
                setState(() => _pencatatanMakan = v);
                _simpanToggle('makan', v, 'Pencatatan Makanan');
              }),
          _TileToggle(
              icon: '🌙',
              title: 'Jendela Puasa',
              subtitle: 'Notif saat jendela buka/tutup',
              value: _jendelaPuasa,
              onChanged: (v) {
                setState(() => _jendelaPuasa = v);
                _simpanToggle('puasa', v, 'Jendela Puasa');
              }),
          const SizedBox(height: 16),

          Center(
              child: TextButton.icon(
                  onPressed: _keluar,
                  icon: const Icon(Icons.logout, size: 14, color: Colors.red),
                  label: const Text('KELUAR DARI AKUN',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _StatProfil extends StatelessWidget {
  final String label, value;
  const _StatProfil({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white60)),
    ]));
  }
}

class _ChipNutrisi extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _ChipNutrisi(
      {required this.emoji,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

class _KartuTerEdit extends StatelessWidget {
  final String label, value;
  final String? unit;
  final VoidCallback onTap;
  const _KartuTerEdit(
      {required this.label,
      required this.value,
      this.unit,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary))
                ],
                const Spacer(),
                const Icon(Icons.edit, size: 14, color: AppTheme.textMuted),
              ]),
            ])));
  }
}

class _KartuInfo extends StatelessWidget {
  final String label, value;
  final bool isDropdown;
  final VoidCallback? onTap;
  const _KartuInfo(
      {required this.label,
      required this.value,
      this.isDropdown = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary)),
              if (isDropdown)
                const Icon(Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary),
            ]),
          ])),
    );
  }
}

class _TileToggle extends StatelessWidget {
  final String icon, title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TileToggle(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ])),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppTheme.primary),
        ]));
  }
}
