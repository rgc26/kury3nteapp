import 'package:flutter/material.dart';

class AppColors {
  // Primary palette - "Philippine Sunrise"
  static const primary = Color(0xFFF59E0B);
  static const primaryDark = Color(0xFFD97706);
  static const primaryLight = Color(0xFFFBBF24);

  // Accent
  static const accent = Color(0xFF3B82F6);
  static const accentLight = Color(0xFF60A5FA);

  // Status colors
  static const danger = Color(0xFFEF4444);
  static const dangerDark = Color(0xFFDC2626);
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF059669);
  static const warning = Color(0xFFFBBF24);
  static const warningDark = Color(0xFFF59E0B);

  // Backgrounds
  static const background = Color(0xFF0A0E1A);
  static const backgroundLight = Color(0xFF0F1629);
  static const surface = Color(0xFF111827);
  static const surfaceLight = Color(0xFF1F2937);
  static const surfaceLighter = Color(0xFF374151);

  // Text
  static const textPrimary = Color(0xFFF9FAFB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  // Borders
  static const border = Color(0xFF1F2937);
  static const borderLight = Color(0xFF374151);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
