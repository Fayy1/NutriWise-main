import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_helper.dart';
import 'profile_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  // Password strength
  int _passwordStrength = 0; // 0-4
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    final hasMin = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasNum = RegExp(r'[0-9]').hasMatch(password);
    final hasSym = RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~/]''').hasMatch(password);

    int strength = 0;
    if (hasMin) strength++;
    if (hasUpper) strength++;
    if (hasNum) strength++;
    if (hasSym) strength++;

    setState(() {
      _hasMinLength = hasMin;
      _hasUppercase = hasUpper;
      _hasNumber = hasNum;
      _hasSymbol = hasSym;
      _passwordStrength = strength;
    });
  }

  String _strengthLabel() {
    switch (_passwordStrength) {
      case 1: return 'Lemah';
      case 2: return 'Sedang';
      case 3: return 'Kuat';
      case 4: return 'Sangat Kuat';
      default: return '';
    }
  }

  Color _strengthColor() {
    switch (_passwordStrength) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.blue;
      case 4: return AppTheme.primary;
      default: return Colors.grey.shade300;
    }
  }

  Future<void> handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kamu harus menyetujui syarat & ketentuan'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_passwordStrength < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.security, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Password harus lebih kuat (min. Kuat)'),
          ]),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = emailController.text.trim();
      final name = nameController.text.trim();

      final userId = await DatabaseHelper.instance.registerUser(
        name: name,
        email: email,
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navigate to profile setup (not login!)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(userId: userId, userName: name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendaftar: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: AppTheme.bgColor,
      prefixIcon: Icon(prefixIcon, color: AppTheme.textMuted, size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Back button + header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text('Buat Akun', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 54),
                  child: Text('Mulai perjalanan nutrisimu hari ini 🌿', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 28),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama
                      const _FieldLabel(text: 'Nama Lengkap'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        decoration: _inputDecoration(hint: 'nama lengkap kamu', prefixIcon: Icons.person_outline_rounded),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Nama tidak boleh kosong';
                          if (val.trim().length < 3) return 'Nama minimal 3 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      const _FieldLabel(text: 'Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        decoration: _inputDecoration(hint: 'contoh@email.com', prefixIcon: Icons.email_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email tidak boleh kosong';
                          if (!val.contains('@') || !val.contains('.')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      const _FieldLabel(text: 'Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        onChanged: _checkPasswordStrength,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        decoration: _inputDecoration(
                          hint: 'min. 8 karakter, huruf besar, angka, simbol',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textMuted, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Password tidak boleh kosong';
                          if (val.length < 8) return 'Password minimal 8 karakter';
                          if (!RegExp(r'[A-Z]').hasMatch(val)) return 'Password harus ada huruf kapital';
                          if (!RegExp(r'[0-9]').hasMatch(val)) return 'Password harus ada angka';
                          if (!RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~/]''').hasMatch(val)) return 'Password harus ada simbol (!, @, #, dll)';
                          return null;
                        },
                      ),

                      // Password strength indicator
                      if (passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ...List.generate(4, (i) => Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 4,
                                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: i < _passwordStrength ? _strengthColor() : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            )),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _strengthLabel(),
                                key: ValueKey(_passwordStrength),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _strengthColor()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Requirements checklist
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _RequirementChip(label: '8+ karakter', met: _hasMinLength),
                            _RequirementChip(label: 'Huruf kapital', met: _hasUppercase),
                            _RequirementChip(label: 'Angka', met: _hasNumber),
                            _RequirementChip(label: 'Simbol (!@#)', met: _hasSymbol),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Konfirmasi Password
                      const _FieldLabel(text: 'Konfirmasi Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => handleRegister(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        decoration: _inputDecoration(
                          hint: 'ulangi password kamu',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textMuted, size: 20),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Konfirmasi password tidak boleh kosong';
                          if (val != passwordController.text) return 'Password tidak cocok';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Checkbox Terms
                      GestureDetector(
                        onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20, height: 20,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: _agreeToTerms ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: _agreeToTerms ? AppTheme.primary : Colors.grey.shade400, width: 1.5),
                              ),
                              child: _agreeToTerms ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Manrope'),
                                  children: [
                                    TextSpan(text: 'Saya menyetujui '),
                                    TextSpan(text: 'Syarat & Ketentuan', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                                    TextSpan(text: ' dan '),
                                    TextSpan(text: 'Kebijakan Privasi', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                                    TextSpan(text: ' NutriWise'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tombol Daftar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Buat Akun', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Sudah punya akun? ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('Masuk', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 0.5),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final String label;
  final bool met;
  const _RequirementChip({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: met ? AppTheme.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: met ? AppTheme.primary.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 12, color: met ? AppTheme.primary : Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: met ? AppTheme.primary : Colors.grey.shade400)),
      ]),
    );
  }
}
