import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/app_logo_widget.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  double _progress = 0.0;
  bool _navigated = false;
  static const int _totalDurationMs = 2000; // Exactly 2.0 seconds

  @override
  void initState() {
    super.initState();

    // Start wall-clock driven loop after first paint
    // This is 100% immune to device animator_duration_scale: 0.0 (animation off)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWallClockAnimation();
    });
  }

  void _startWallClockAnimation() {
    final startTime = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final currentProgress = (elapsed / _totalDurationMs).clamp(0.0, 1.0);

      setState(() {
        _progress = currentProgress;
      });

      if (currentProgress >= 1.0 && !_navigated) {
        _navigated = true;
        timer.cancel();
        _navigateToHome();
      }
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Instant full visibility: zero black delay, subtle spring scale from 0.92 to 1.0
    const fadeInProgress = 1.0;
    final springT = (_progress / 0.25).clamp(0.0, 1.0);
    final logoScale = 0.92 + 0.08 * Curves.easeOutBack.transform(springT);

    // 2. Loading bar fill immediately (0.0 to 0.68)
    final barProgress = (_progress / 0.68).clamp(0.0, 1.0);
    final loadingBarValue = Curves.easeInOut.transform(barProgress);

    // 3. Rocket fly-away ("uree jaabe") (0.68 to 1.0)
    double logoOffsetY = 0.0;
    double launchScale = 1.0;
    double contentOpacity = 1.0;

    if (_progress >= 0.68) {
      final launchT = ((_progress - 0.68) / 0.32).clamp(0.0, 1.0);
      contentOpacity = (1.0 - (launchT * 2.0)).clamp(0.0, 1.0);

      if (launchT < 0.15) {
        // Small anticipation crouch down
        logoOffsetY = 12.0 * (launchT / 0.15);
        launchScale = 1.05;
      } else {
        // Blast off straight UP off the screen into space!
        final blastT = ((launchT - 0.15) / 0.85).clamp(0.0, 1.0);
        final acceleratedT = Curves.easeInCubic.transform(blastT);
        logoOffsetY = 12.0 - (acceleratedT * 700.0); // Shoots -700px upwards
        launchScale = 1.05 - (acceleratedT * 0.4);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF161936),
              Color(0xFF0E1022),
              Color(0xFF090A14),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Center Ambient Radial Glow
            Center(
              child: Opacity(
                opacity: contentOpacity,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.purpleAccent.withValues(alpha: 0.35),
                        AppColors.cyanAccent.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Center Content: Flying Logo + Title + Loading Bar
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated flying logo ("uree jaabe")
                  Transform.translate(
                    offset: Offset(0, logoOffsetY),
                    child: Transform.scale(
                      scale: logoScale * launchScale,
                      child: Opacity(
                        opacity: fadeInProgress,
                        child: const AppLogoWidget(
                          size: 104,
                          borderRadius: 26,
                          hasGlow: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title & Tagline & Loading Indicator
                  Opacity(
                    opacity: contentOpacity,
                    child: Column(
                      children: [
                        const Text(
                          'QuickSave',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Universal Media Downloader',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tiny sleek neon loading progress bar
                        SizedBox(
                          width: 140,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: loadingBarValue,
                                  minHeight: 3.5,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColors.cyanAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Starting engine...',
                                style: TextStyle(
                                  color: AppColors.textMuted.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Creator Credit Badge at bottom ("Ranit Jana")
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: contentOpacity,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E213D).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cyanAccent.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyanAccent.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.cyanAccent,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                            children: [
                              TextSpan(
                                text: 'Created by ',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: 'Ranit Jana',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
