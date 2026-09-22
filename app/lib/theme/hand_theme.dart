/// The hand layer's reach into Flutter's own widgets.
///
/// `buildTheme` in `app_tokens.dart` is generated and sets the brand colours.
/// This wraps it for the few places the app still uses a stock widget — a
/// dialog, a snack bar, an icon button, a slider — so they belong to the same
/// printed page instead of announcing the toolkit they came from. Mostly that
/// means taking the ripple away: nothing on paper ripples.
library;

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'hand_tokens.dart';

ThemeData handTheme(ThemeData base) {
  final pressed = WidgetStateProperty.resolveWith<Color?>(
    (s) => s.contains(WidgetState.pressed) || s.contains(WidgetState.focused)
        ? HandInk.marker.withValues(alpha: 0.55)
        : null,
  );
  const tight = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    highlightColor: HandInk.print.withValues(alpha: 0.04),
    hoverColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primaryContainer,
      selectionHandleColor: AppColors.primary,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        splashFactory: NoSplash.splashFactory,
        overlayColor: pressed,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        splashFactory: NoSplash.splashFactory,
        overlayColor: pressed,
        foregroundColor: const WidgetStatePropertyAll(AppColors.primaryDim),
        shape: const WidgetStatePropertyAll(tight),
        textStyle: WidgetStatePropertyAll(
          AppText.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        splashFactory: NoSplash.splashFactory,
        overlayColor: pressed,
        foregroundColor: const WidgetStatePropertyAll(AppColors.onSurface),
        shape: const WidgetStatePropertyAll(tight),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.outline, width: 1.2),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AppColors.outline, width: 1),
      ),
      titleTextStyle: AppText.titleL.copyWith(color: AppColors.onSurface),
      contentTextStyle: AppText.body.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.inverseSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.outlineVariant,
      thumbColor: AppColors.primary,
      overlayColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outlineVariant),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surfaceLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
  );
}
