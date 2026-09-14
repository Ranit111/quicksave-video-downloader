import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AppLogoWidget extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool hasGlow;

  const AppLogoWidget({
    super.key,
    this.size = 40,
    this.borderRadius = 12,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.purpleAccent.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.purpleAccent.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/logo/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Secondary attempt with jpg
            return Image.asset(
              'assets/logo/app_logo.jpg',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error2, stackTrace2) {
                // Built-in fallback gradient vector logo
                return _buildFallbackLogo();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.buttonGradient,
      ),
      child: Icon(
        Icons.file_download_outlined,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
