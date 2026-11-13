import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'authScreen.dart';
import 'homeRouter.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _fall = CurvedAnimation(
    parent: _controller,
    curve: Curves.bounceOut,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.2, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2800), () async {
      final Widget next = FirebaseAuth.instance.currentUser == null
          ? const AuthScreen()
          : await resolveHome();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fontSize = 40.0;
    const style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    );
    return Scaffold(
      backgroundColor: AppColors.pro,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag, size: 96, color: AppColors.buy),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pro', style: style.copyWith(color: Colors.white)),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: _fade.value,
                    child: Transform.translate(
                      offset: Offset(0, -260 * (1 - _fall.value)),
                      child: child,
                    ),
                  ),
                  child: Text(
                    'Buy',
                    style: style.copyWith(color: AppColors.buy),
                  ),
                ),
              ],
            ),
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