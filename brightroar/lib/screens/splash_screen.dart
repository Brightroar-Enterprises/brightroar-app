import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/lion_logo.dart';
import 'signin_screen.dart';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A), Color(0xFF050505)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnim.value),
                      child: child,
                    ),
                  ),
                  child: Column(children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFF2A2A2A), Color(0xFF111111)]),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.15), blurRadius: 40, spreadRadius: 5)],
                      ),
                      child: const Center(child: LionLogo(size: 64)),
                    ),
                    const SizedBox(height: 28),
                    const Text('BRIGHTROAR CORP.', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
                    const SizedBox(height: 6),
                    const Text('ASSET MANAGER', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 4)),
                    const SizedBox(height: 20),
                    Container(width: 60, height: 1,
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppTheme.primary, Colors.transparent]))),
                    const SizedBox(height: 20),
                    const Text('The Secure Institutional\nCrypto Solution.', textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.6, letterSpacing: 0.2)),
                  ]),
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(opacity: _fadeAnim.value, child: child),
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // Use Navigator.push so AppRouter stays underneath
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignInScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SIGN IN', style: TextStyle(color: Color(0xFF0A0A0A), fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        // Use Navigator.push so AppRouter stays underneath
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('CREATE ACCOUNT', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text('Secured by FIDO2 Hardware Key', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 20),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
