import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/responsive_size_utils.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Helper method to get responsive font size
  static double _getResponsiveFontSize(double fontSize) {
    try {
      return ResponsiveSizeUtils.getFontSize(fontSize);
    } catch (e) {
      // Fallback if ResponsiveSizeUtils is not initialized
      return fontSize;
    }
  }

  // Display styles
  static TextStyle get displayLarge => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(32),
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get displayMedium => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(28),
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get displaySmall => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(24),
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // Headline styles
  static TextStyle get headlineLarge => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(22),
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(20),
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineSmall => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(18),
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Title styles
  static TextStyle get titleLarge => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(18),
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(16),
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleSmall => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(14),
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // Body styles
  static TextStyle get bodyLarge => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(16),
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(14),
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(12),
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Label styles
  static TextStyle get labelLarge => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(14),
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelMedium => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(12),
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelSmall => GoogleFonts.roboto(
    fontSize: _getResponsiveFontSize(11),
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
