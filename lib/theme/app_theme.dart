import 'package:flutter/material.dart';

class AppColors {
  static const pro = Color(0xFF3F37C9);
  static const buy = Color(0xFFFF7A00);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.pro,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.pro,
      secondary: AppColors.buy,
      tertiary: AppColors.buy,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F6FD),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pro,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.buy.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.buy
                : Colors.grey.shade600,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.pro
                : Colors.grey.shade600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.buy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.buy,
        textColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.pro, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// "Pro" in the primary color and "Buy" in the accent color.
class BrandName extends StatelessWidget {
  final double fontSize;
  final Color proColor;
  final Color buyColor;

  const BrandName({
    super.key,
    this.fontSize = 28,
    this.proColor = AppColors.pro,
    this.buyColor = AppColors.buy,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        children: [
          TextSpan(text: 'Pro', style: TextStyle(color: proColor)),
          TextSpan(text: 'Buy', style: TextStyle(color: buyColor)),
        ],
      ),
    );
  }
}
