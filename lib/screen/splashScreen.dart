import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'authScreen.dart';
import 'mainScreen.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FirebaseAuth.instance.currentUser == null
              ? const AuthScreen()
              : const MainScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pro,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag, size: 96, color: AppColors.buy),
            const SizedBox(height: 16),
            const BrandName(fontSize: 40, proColor: Colors.white),
            const SizedBox(height: 8),
            const Text(
              'Teknolojiyi akıllıca al',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.buy),
          ],
        ),
      ),
    );
  }
}