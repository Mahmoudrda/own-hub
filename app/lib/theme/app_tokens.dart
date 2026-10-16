// GENERATED from 6-v2/src/tokens.mjs — do not edit by hand.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const primary = Color(0xFF1A5D74);
  static const onPrimary = Color(0xFFFCF8F2);
  static const primaryContainer = Color(0xFFF4BEBB);
  static const onPrimaryContainer = Color(0xFF123F50);
  static const primaryDim = Color(0xFF123F50);
  static const primarySoft = Color(0xFFF9DEDC);
  static const secondary = Color(0xFF4E6E79);
  static const onSecondary = Color(0xFFFCF8F2);
  static const secondaryContainer = Color(0xFFF9DEDC);
  static const onSecondaryContainer = Color(0xFF123F50);
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
  static const surface = Color(0xFFFCF8F2);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF8F2EA);
  static const surfaceContainer = Color(0xFFF4EDE3);
  static const surfaceHigh = Color(0xFFEFE7DB);
  static const surfaceHighest = Color(0xFFE8DED3);
  static const onSurface = Color(0xFF123F50);
  static const onSurfaceVariant = Color(0xFF4E6068);
  static const outline = Color(0xFF60858F);
  static const outlineVariant = Color(0xFFE8DED3);
  static const inverseSurface = Color(0xFF123F50);
  static const inverseOnSurface = Color(0xFFFCF8F2);
  static const canvas = Color(0xFFF4EDE3);
  static const ink = Color(0xFF123F50);

  static const brandLinen = Color(0xFFFCF8F2);
  static const brandPetrol = Color(0xFF1A5D74);
  static const brandPink = Color(0xFFF4BEBB);
  static const white = Color(0xFFFFFFFF);
  static const petrolDark = Color(0xFF123F50);
  static const petrolMuted = Color(0xFF668B96);
  static const pinkSoft = Color(0xFFF9DEDC);
  static const pinkShade = Color(0xFFE8A5A2);
  static const pinkDeep = Color(0xFFD98A87);
  static const borderWarm = Color(0xFFE8DED3);

  static const textPrimary = onSurface;
  static const textSecondary = onSurfaceVariant;
  static const actionPrimary = brandPink;
  static const onActionPrimary = petrolDark;
  static const actionPressed = pinkShade;
  static const progressPrimary = primary;
  static const progressAccent = brandPink;
  static const statusSuccess = tertiary;
  static const statusWarning = amber;
  static const statusError = error;
  static const chartPrimary = primary;
  static const chartSecondary = brandPink;
  static const chartMuted = petrolMuted;
  static const illustrationBg = surfaceLow;
}

class AppSpace {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
}

class AppIconSize {
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
}

class AppShadow {
  static const List<BoxShadow> none = <BoxShadow>[];
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0F123F50), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x14123F50), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

class AppText {
  static const _family = 'Rubik';
  static const display = TextStyle(fontFamily: _family, fontSize: 32, height: 1.250, fontWeight: FontWeight.w700);
  static const headline = TextStyle(fontFamily: _family, fontSize: 26, height: 1.269, fontWeight: FontWeight.w700);
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
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        surfaceContainerLowest: AppColors.surfaceLowest,
        surfaceContainerLow: AppColors.surfaceLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.surfaceHighest,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
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
