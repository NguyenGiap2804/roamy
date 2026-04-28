import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

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
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 180,
                height: 180,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.place_rounded,
                  size: 100,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'RoaMy Place',
                style: AppTextStyles.headline.copyWith(
                  fontSize: 28,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lưu giữ mọi địa điểm, nhắc nhở từng chuyến đi',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
