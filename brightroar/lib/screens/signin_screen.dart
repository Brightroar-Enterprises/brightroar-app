import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/lion_logo.dart';
import '../widgets/glass_card.dart';
import '../services/auth_provider.dart';
import '../screens/main_shell.dart';
import 'register_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack('Please fill in all fields', AppTheme.negative);
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      // Navigate to MainShell and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else {
      _showSnack(auth.error ?? 'Login failed', AppTheme.negative);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.0,
            colors: [Color(0xFF161616), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceElevated,
                  border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.1), blurRadius: 30)],
                ),
                child: const Center(child: LionLogo(size: 44)),
              ),
              const SizedBox(height: 24),
              const Text('SIGN IN', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w700, letterSpacing: 3,
              )),
              const SizedBox(height: 36),
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Institutional Email', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Institutional Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppTheme.textTertiary),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Corporate Password', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Corporate Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textTertiary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.textTertiary, size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ])),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _signIn,
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: AppTheme.background, strokeWidth: 2),
                        )
                      : const Text('SIGN IN', style: TextStyle(
                          color: Color(0xFF0A0A0A), fontSize: 14,
                          fontWeight: FontWeight.w700, letterSpacing: 1.5,
                        )),
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.security, color: AppTheme.warning, size: 16),
                    SizedBox(width: 8),
                    Text('AUTHENTICATION REQUIRED', style: TextStyle(
                      color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w600,
                    )),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _authBtn(Icons.face_retouching_natural, 'FaceID/TouchID'),
                  Container(width: 1, height: 60, color: AppTheme.border),
                  _authBtn(Icons.key_outlined, 'FIDO Hardware Key'),
                ]),
              ])),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('New to Brightroar? ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('Create an Account', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _authBtn(IconData icon, String label) {
    return GestureDetector(
      onTap: _signIn,
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500,
        )),
      ]),
    );
  }
}
