// GENERATED from 6-v2/src/tokens.mjs — do not edit by hand.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const primary = Color(0xFFA24661);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFFFD9E3);
  static const onPrimaryContainer = Color(0xFF4A1C2E);
  static const primaryDim = Color(0xFF9A3F57);
  static const primarySoft = Color(0xFFF8E1E7);
  static const secondary = Color(0xFF75565E);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFF5E3E8);
  static const onSecondaryContainer = Color(0xFF412B32);
  static const tertiary = Color(0xFF4C6E55);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFDDEDE1);
  static const onTertiaryContainer = Color(0xFF1E3826);
  static const tertiarySoft = Color(0xFF65896F);
  static const error = Color(0xFFA34848);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFBE0E0);
  static const onErrorContainer = Color(0xFF4E1C1C);
  static const amber = Color(0xFF8A5A17);
  static const amberContainer = Color(0xFFFBEBD6);
  static const surface = Color(0xFFFFF8F9);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFFFF1F4);
  static const surfaceContainer = Color(0xFFFBEAEF);
  static const surfaceHigh = Color(0xFFF6E3E9);
  static const surfaceHighest = Color(0xFFF0DBE2);
  static const onSurface = Color(0xFF241A1E);
  static const onSurfaceVariant = Color(0xFF6B5C61);
  static const outline = Color(0xFF977C84);
  static const outlineVariant = Color(0xFFB47B87);
  static const inverseSurface = Color(0xFF37292E);
  static const inverseOnSurface = Color(0xFFFFECF0);
  static const canvas = Color(0xFFF2E8EB);
  static const ink = Color(0xFF241A1E);
}

class AppText {
  static const _family = 'Rubik';
  static const display = TextStyle(fontFamily: _family, fontSize: 32, height: 1.250, fontWeight: FontWeight.w600);
  static const headline = TextStyle(fontFamily: _family, fontSize: 26, height: 1.269, fontWeight: FontWeight.w600);
  static const titleL = TextStyle(fontFamily: _family, fontSize: 20, height: 1.300, fontWeight: FontWeight.w600);
  static const titleM = TextStyle(fontFamily: _family, fontSize: 17, height: 1.353, fontWeight: FontWeight.w600);
  static const titleS = TextStyle(fontFamily: _family, fontSize: 15, height: 1.333, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: _family, fontSize: 16, height: 1.500, fontWeight: FontWeight.w400);
  static const bodyM = TextStyle(fontFamily: _family, fontSize: 15, height: 1.467, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontFamily: _family, fontSize: 15, height: 1.333, fontWeight: FontWeight.w500);
  static const nav = TextStyle(fontFamily: _family, fontSize: 12, height: 1.333, fontWeight: FontWeight.w500);
}

class AppRadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const full = 999.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const short = Duration(milliseconds: 220);
  static const med = Duration(milliseconds: 320);
  static const long = Duration(milliseconds: 460);
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const accelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const spring = Cubic(0.34, 1.56, 0.64, 1.0);
}

ThemeData buildTheme(Locale locale) => ThemeData(
      useMaterial3: true,
      fontFamily: 'Rubik',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        outlineVariant: AppColors.outlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      // Dark status-bar content, always.
      //
      // Nothing set this, and AppBar derives the status-bar style from its own
      // background colour when none is given. Both of this product's top bars
      // are deliberately transparent, so most screens asked iOS for LIGHT
      // status-bar content and drew a near-white clock, wifi and battery on the
      // pale surface colour. Unreadable, on most screens in the app, and
      // invisible to every widget test — a screenshot caught it.
      //
      // statusBarBrightness describes the BACKGROUND (light, so iOS draws dark
      // text); statusBarIconBrightness describes the ICONS (dark, for Android).
      // They read as contradictory and are not.
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    );
