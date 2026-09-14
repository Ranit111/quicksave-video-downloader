import 'package:flutter/material.dart';

class AppColors {
  // Option 2: Vibrant Indigo Glass Palette
  static const Color background = Color(0xFF0D0E1C);
  static const Color backgroundSecondary = Color(0xFF14162B);
  
  // Glassmorphism card surfaces
  static const Color glassSurface = Color(0x1F2B3258);
  static const Color glassBorder = Color(0x3D4E5B8E);
  static const Color glassBorderActive = Color(0xFF8B5CF6);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x336366F1), Color(0x1114162B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accents & Indicators
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color greenSuccess = Color(0xFF10B981);
  static const Color redError = Color(0xFFEF4444);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}
