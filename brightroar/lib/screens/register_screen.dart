import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/auth_provider.dart';
import '../screens/main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _companyController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.negative, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submit() async {
    if (_passwordController.text.isEmpty) { _showSnack('Please enter a password'); return; }
    if (_passwordController.text.length < 8) { _showSnack('Password must be at least 8 characters'); return; }
    if (_passwordController.text != _confirmController.text) { _showSnack('Passwords do not match'); return; }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      companyName: _companyController.text.trim(),
      email: _emailController.text.trim(),
      contactPerson: _contactController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else {
      _showSnack(auth.error ?? 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.5), radius: 1.0, colors: [Color(0xFF161616), Color(0xFF080808)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 16),
              Row(children: [
                GestureDetector(
                  onTap: () { if (_step > 1) setState(() => _step--); else Navigator.pop(context); },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textSecondary),
                  ),
                ),
                const Spacer(),
                Row(children: List.generate(3, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i + 1 == _step ? 24 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: i + 1 <= _step ? AppTheme.primary : AppTheme.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ))),
                const Spacer(),
                Text('Step $_step of 3', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 36),
              const Align(alignment: Alignment.centerLeft,
                child: Text('CREATE CORPORATE\nACCOUNT', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1, height: 1.3))),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft,
                child: Text('Step $_step of 3', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13))),
              const SizedBox(height: 32),
              Expanded(child: _buildStep()),
              Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : () {
                      if (_step == 1) {
                        if (_companyController.text.isEmpty || _emailController.text.isEmpty || _contactController.text.isEmpty) {
                          _showSnack('Please fill in all fields'); return;
                        }
                        setState(() => _step++);
                      } else if (_step == 2) {
                        setState(() => _step++);
                      } else {
                        _submit();
                      }
                    },
                    child: auth.isLoading && _step == 3
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.background, strokeWidth: 2))
                        : Text(_step < 3 ? 'CONTINUE' : 'CREATE ACCOUNT',
                            style: const TextStyle(color: Color(0xFF0A0A0A), fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('BACK TO SIGN IN', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1, fontSize: 14)),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 1) {
      return GlassCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl('Company Name'), const SizedBox(height: 8),
        _fld(_companyController, 'Company Name', Icons.business_outlined),
        const SizedBox(height: 20),
        _lbl('Corporate Email'), const SizedBox(height: 8),
        _fld(_emailController, 'Corporate Email', Icons.email_outlined, type: TextInputType.emailAddress),
        const SizedBox(height: 20),
        _lbl('Contact Person'), const SizedBox(height: 8),
        _fld(_contactController, 'Contact Person', Icons.person_outline),
      ]));
    }
    if (_step == 2) {
      return GlassCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl('Business Registration Number'), const SizedBox(height: 8),
        _fld(TextEditingController(), 'Registration Number', Icons.numbers_outlined),
        const SizedBox(height: 20),
        _lbl('Country of Incorporation'), const SizedBox(height: 8),
        _fld(TextEditingController(), 'Select Country', Icons.public_outlined),
        const SizedBox(height: 20),
        _lbl('Industry Type'), const SizedBox(height: 8),
        _fld(TextEditingController(), 'Select Industry', Icons.category_outlined),
      ]));
    }
    return GlassCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('Set Corporate Password'), const SizedBox(height: 8),
      TextField(
        controller: _passwordController, obscureText: _obscurePassword,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Corporate Password',
          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textTertiary),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textTertiary, size: 18),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _lbl('Confirm Password'), const SizedBox(height: 8),
      TextField(
        controller: _confirmController, obscureText: _obscureConfirm,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Confirm Password',
          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textTertiary),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textTertiary, size: 18),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: const Row(children: [
          Icon(Icons.security, color: AppTheme.primary, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Your account will be created and you will be logged in automatically',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4))),
        ]),
      ),
    ]));
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500));
  Widget _fld(TextEditingController c, String hint, IconData icon, {bool obscure = false, TextInputType? type}) {
    return TextField(
      controller: c, obscureText: obscure, keyboardType: type,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary)),
    );
  }
}
