// R2-41. The app's own palette, run through the app's own WCAG implementation.
//
// `lib/features/coachbrand/domain/contrast.dart` is a complete WCAG 2.1
// implementation and it is applied ONLY to coach-authored portfolio themes.
// `AppColors` — the palette every shipping screen is drawn from — has never
// been run through it. This measures it.
//
// This file reports; it does not fix. It prints every pair with its ratio to
// two decimals and its threshold, and fails on any pair under threshold so the
// failure is the evidence artefact.
//
// Pairs are not invented. Backgrounds are the seven `AppCardVariant`
// backgrounds in `lib/ui/app_card.dart:62-94` plus the page background
// (`AppColors.surface`, `buildTheme` scaffoldBackgroundColor) and
// `AppColors.inverseSurface` (the undo bar / snackbar). Foregrounds are the
// text colours the shipping code actually pairs with them, counted from
//   grep -rho 'AppText\.[a-z]*\.copyWith(\s*color: AppColors\.[a-zA-Z]*' lib/
// which is 115 x bodyM-on-onSurfaceVariant at the top and falls away from
// there.
//
// The style -> threshold mapping is `ContrastThresholds.forTextStyle`, which
// holds titleL (20/w600) and titleM (17/w600) to 4.5:1 rather than 3.0:1
// because w600 is not bold under WCAG.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/coachbrand/domain/contrast.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// `AppText` style -> the `PortfolioTextStyle` with the same size and weight.
const Map<String, PortfolioTextStyle> _styles = {
  'display 32/600': PortfolioTextStyle.display,
  'headline 26/600': PortfolioTextStyle.headline,
  'titleL 20/600': PortfolioTextStyle.titleL,
  'titleM 17/600': PortfolioTextStyle.titleM,
  'titleS 15/600': PortfolioTextStyle.titleS,
  'body 16/400': PortfolioTextStyle.body,
  'bodyM 15/400': PortfolioTextStyle.bodyM,
  'label 15/500': PortfolioTextStyle.label,
  'nav 12/500': PortfolioTextStyle.nav,
};

const Map<String, Color> _backgrounds = {
  'surface (page)': AppColors.surface,
  'surfaceLowest (outlined/selected card)': AppColors.surfaceLowest,
  'surfaceLow': AppColors.surfaceLow,
  'surfaceContainer (filled card)': AppColors.surfaceContainer,
  'surfaceHigh': AppColors.surfaceHigh,
  'surfaceHighest': AppColors.surfaceHighest,
  'primaryContainer (tonal card)': AppColors.primaryContainer,
  'tertiaryContainer (sage card)': AppColors.tertiaryContainer,
  'amberContainer (amber card)': AppColors.amberContainer,
  'errorContainer (error card)': AppColors.errorContainer,
  'primarySoft': AppColors.primarySoft,
  'canvas': AppColors.canvas,
  'inverseSurface (undo bar)': AppColors.inverseSurface,
  'primary (filled button)': AppColors.primary,
  'tertiary': AppColors.tertiary,
  'error': AppColors.error,
};

/// Foreground -> the backgrounds the shipping code actually draws it on.
const Map<String, (Color, List<String>)> _foregrounds = {
  'onSurface': (
    AppColors.onSurface,
    [
      'surface (page)',
      'surfaceLowest (outlined/selected card)',
      'surfaceLow',
      'surfaceContainer (filled card)',
      'surfaceHigh',
      'surfaceHighest',
      'primarySoft',
      'canvas',
    ],
  ),
  'onSurfaceVariant': (
    AppColors.onSurfaceVariant,
    [
      'surface (page)',
      'surfaceLowest (outlined/selected card)',
      'surfaceLow',
      'surfaceContainer (filled card)',
      'surfaceHigh',
      'surfaceHighest',
      'primarySoft',
      'canvas',
    ],
  ),
  'primary': (
    AppColors.primary,
    [
      'surface (page)',
      'surfaceLowest (outlined/selected card)',
      'surfaceContainer (filled card)',
      'surfaceHigh',
      'canvas',
    ],
  ),
  'primaryDim': (
    AppColors.primaryDim,
    ['surface (page)', 'surfaceLowest (outlined/selected card)', 'canvas'],
  ),
  'tertiary': (
    AppColors.tertiary,
    [
      'surface (page)',
      'surfaceLowest (outlined/selected card)',
      'tertiaryContainer (sage card)',
      'surfaceContainer (filled card)',
    ],
  ),
  'error': (
    AppColors.error,
    [
      'surface (page)',
      'surfaceLowest (outlined/selected card)',
      'errorContainer (error card)',
    ],
  ),
  'amber': (
    AppColors.amber,
    ['surface (page)', 'amberContainer (amber card)'],
  ),
  // `outline` and `tertiarySoft` are NOT text colours. Every call site is a
  // stroke, a rule, a progress fill or a week segment:
  //   app_field.dart:245, app_week_segments.dart:143/218 (pencil rules),
  //   grocery_list_view.dart:207 (the tick box),
  //   app_progress.dart:28, app_ring_stat.dart:27 (fills).
  // They are therefore measured against WCAG 1.4.11 non-text (3.0:1) in
  // `_nonText` below rather than against a text threshold here.
  'onPrimaryContainer': (
    AppColors.onPrimaryContainer,
    ['primaryContainer (tonal card)'],
  ),
  'onSecondaryContainer': (
    AppColors.onSecondaryContainer,
    ['secondaryContainer'],
  ),
  'onTertiaryContainer': (
    AppColors.onTertiaryContainer,
    ['tertiaryContainer (sage card)'],
  ),
  'onErrorContainer': (AppColors.onErrorContainer, ['errorContainer (error card)']),
  'inverseOnSurface': (AppColors.inverseOnSurface, ['inverseSurface (undo bar)']),
  'onPrimary': (AppColors.onPrimary, ['primary (filled button)']),
  'onTertiary': (AppColors.onTertiary, ['tertiary']),
  'onError': (AppColors.onError, ['error']),
};

/// Graphical objects, held to WCAG 1.4.11's 3.0:1 rather than to a text floor.
///
/// `tertiarySoft` is the default fill of `AppProgressBar` (app_progress.dart:28),
/// `AppWeekSegments` (app_week_segments.dart:40) and `AppRingStat`
/// (app_ring_stat.dart:27). `outline` is the pencil rule in `AppField`
/// (app_field.dart:245), the waiting week segment (app_week_segments.dart:218)
/// and the unticked grocery box (grocery_list_view.dart:207).
const List<(String, Color, String)> _nonText = [
  ('tertiarySoft fill', AppColors.tertiarySoft, 'surface (page)'),
  ('tertiarySoft fill', AppColors.tertiarySoft, 'surfaceLowest (outlined/selected card)'),
  // R12 draws AppProgressBar inside AppCard(variant: sage) —
  // logged_from_memory_view.dart:99 and :117.
  ('tertiarySoft fill', AppColors.tertiarySoft, 'tertiaryContainer (sage card)'),
  ('outline stroke', AppColors.outline, 'surface (page)'),
  ('outline stroke', AppColors.outline, 'surfaceLowest (outlined/selected card)'),
  ('outline stroke', AppColors.outline, 'surfaceContainer (filled card)'),
  ('outlineVariant stroke', AppColors.outlineVariant, 'surface (page)'),
  ('outlineVariant stroke', AppColors.outlineVariant, 'surfaceLowest (outlined/selected card)'),
];

String _f(double v) => v.toStringAsFixed(2);

void main() {
  test('every shipping text-on-background pair, measured', () {
    final failures = <String>[];
    final fragile = <String>[];
    final lines = <String>[];
    var measured = 0;

    for (final fg in _foregrounds.entries) {
      final (colour, backgrounds) = fg.value;
      for (final bgName in backgrounds) {
        final bg = _backgrounds[bgName];
        if (bg == null) continue;
        final ratio = contrastRatio(colour, bg);
        for (final style in _styles.entries) {
          final needed = ContrastThresholds.forTextStyle(style.value);
          measured++;
          final verdict = ratio >= needed ? 'ok  ' : 'FAIL';
          lines.add(
            '$verdict ${_f(ratio)}:1  needs ${_f(needed)}  '
            '${fg.key} on $bgName  [${style.key}]',
          );
          if (ratio < needed) {
            failures.add(
              '${fg.key} on $bgName at ${style.key}: '
              '${_f(ratio)}:1, needs ${_f(needed)}:1',
            );
          } else if (ratio - needed < 0.2) {
            fragile.add(
              '${fg.key} on $bgName at ${style.key}: '
              '${_f(ratio)}:1, only ${_f(ratio - needed)} above the floor',
            );
          }
        }
      }
    }

    // ignore: avoid_print
    print('--- R2-41: $measured pairs measured ---');
    for (final line in lines) {
      // ignore: avoid_print
      print(line);
    }
    // ignore: avoid_print
    print('--- fragile (within 0.2 of the floor): ${fragile.length} ---');
    for (final line in fragile.toSet()) {
      // ignore: avoid_print
      print('  $line');
    }
    // ignore: avoid_print
    print('--- failures: ${failures.length} ---');
    for (final line in failures) {
      // ignore: avoid_print
      print('  $line');
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every graphical object against WCAG 1.4.11 non-text, 3.0:1', () {
    final failures = <String>[];
    for (final (name, colour, bgName) in _nonText) {
      final bg = _backgrounds[bgName]!;
      final ratio = contrastRatio(colour, bg);
      final verdict = ratio >= ContrastThresholds.nonText ? 'ok  ' : 'FAIL';
      // ignore: avoid_print
      print('$verdict ${_f(ratio)}:1  needs 3.00  $name on $bgName');
      if (ratio < ContrastThresholds.nonText) {
        failures.add('$name on $bgName: ${_f(ratio)}:1, needs 3.00:1');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the figure recorded in recipe_book_tokens.dart is right', () {
    // Was '4.58'. That was the rose before this file's own two cases were made
    // to pass: `primary` failed AA on surfaceHigh, canvas and surfaceContainer,
    // so it was darkened (hue and saturation held) and every pair it is drawn
    // in moved with it. The comparison the comment is making — her ink is far
    // more readable than ours — is unchanged and is still the point; only the
    // number it quotes moved, and this case exists so the comment cannot drift
    // away from the palette a second time.
    expect(
      _f(contrastRatio(AppColors.primary, AppColors.surface)),
      '5.59',
    );
  });
}
