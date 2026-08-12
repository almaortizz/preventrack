import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkSession();

    if (!mounted) return;

    if (auth.isLoggedIn) {
      final terminos = auth.usuario?['terminos_aceptados'] ?? false;
      if (terminos == true || terminos == 1) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/legal');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(height: 16),
              // Nombre
              const Text(
                'Preventrack',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(flex: 2),
              // Spinner
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.secondary,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
