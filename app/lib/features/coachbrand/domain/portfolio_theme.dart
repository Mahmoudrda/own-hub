/// Seed, type, corners. Nothing else, and an invalid one is unrepresentable.
///
/// G13 §1.4: *"`theme = { seed, type, corners }`. Nothing else. The rendered
/// scheme is derived, never stored."* And: *"no widget may construct a
/// `PortfolioTheme` except through `PortfolioTheme.validated()`, whose
/// constructor is private."*
///
/// That second sentence is the design. A validated flag on a mutable object is
/// a thing that drifts; a private constructor means the only `PortfolioTheme`
/// that exists anywhere in the program is one that has already passed, and it
/// carries the [ThemeValidation] that proves it.
///
/// ## Type is three Rubik pairings, not three typefaces
///
/// `calm` / `strong` / `soft` change weight, size, tracking and line height —
/// all within Rubik. G13 §10 Q6 records why: a Latin-only display face would
/// silently break Arabic, and genuinely different typefaces need three
/// Arabic-capable pairs (Cairo, Tajawal, Almarai) and a licence decision the
/// owner has not taken. Until then, differentiation that survives a language
/// switch beats differentiation that does not.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'contrast.dart';
import 'theme_validator.dart';

/// The three type pairings. Rubik throughout.
enum PortfolioType {
  calm,
  strong,
  soft;

  static PortfolioType? tryParse(String value) {
    for (final v in PortfolioType.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// The three corner scales.
enum PortfolioCorners {
  /// ×0.5
  sharp(0.5),

  /// ×1.0
  soft(1.0),

  /// ×1.6
  round(1.6);

  const PortfolioCorners(this.scale);

  /// What [AppRadius] is multiplied by.
  final double scale;

  static PortfolioCorners? tryParse(String value) {
    for (final v in PortfolioCorners.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// The radius scale a theme produces.
///
/// `full` never scales — a pill stays a pill. Scaling it would turn every
/// rounded chip into a lozenge at `round` and a rectangle at `sharp`, which is
/// not a corner style, it is a different component.
@immutable
class PortfolioRadii {
  const PortfolioRadii(this.corners);

  final PortfolioCorners corners;

  double get xs => AppRadius.xs * corners.scale;
  double get sm => AppRadius.sm * corners.scale;
  double get md => AppRadius.md * corners.scale;
  double get lg => AppRadius.lg * corners.scale;
  double get xl => AppRadius.xl * corners.scale;

  /// Unscaled, always.
  double get full => AppRadius.full;
}

/// Why a theme was refused, for B05's copy.
enum ThemeRefusal {
  /// Not `#RRGGBB`.
  malformedSeed,

  /// Failed at least one pair at `contrastLevel` 1.0.
  unreadable,
}

/// The result of asking for a theme.
///
/// A sealed pair rather than a nullable return, so a caller that forgets the
/// refusal branch does not compile.
sealed class ThemeChoice {
  const ThemeChoice();
}

/// She may have it. [theme] is the only way a `PortfolioTheme` comes into being.
final class ThemeAccepted extends ThemeChoice {
  const ThemeAccepted(this.theme);
  final PortfolioTheme theme;
}

/// She may not, and this is what to offer instead.
final class ThemeRefused extends ThemeChoice {
  const ThemeRefused({
    required this.reason,
    required this.validation,
    this.nearestPassingSeed,
  });

  final ThemeRefusal reason;
  final ThemeValidation validation;

  /// A curated seed close to what she asked for, or null if even those fail —
  /// which would be a palette bug, not a coach's mistake.
  final String? nearestPassingSeed;
}

/// A theme that has passed. There is no other kind.
@immutable
class PortfolioTheme {
  const PortfolioTheme._({
    required this.seed,
    required this.type,
    required this.corners,
    required this.validation,
  });

  /// The only constructor reachable from outside this file.
  ///
  /// Returns [ThemeAccepted] with a theme that is validated by construction, or
  /// [ThemeRefused] with the nearest colour that would work.
  static ThemeChoice validated({
    required String seed,
    required PortfolioType type,
    required PortfolioCorners corners,
    ThemeValidator validator = const ThemeValidator(),
    DateTime? now,
  }) {
    final validation = validator.validate(seed, now: now);

    if (validation.passed) {
      return ThemeAccepted(
        PortfolioTheme._(
          seed: validation.seed,
          type: type,
          corners: corners,
          validation: validation,
        ),
      );
    }

    return ThemeRefused(
      reason: parseSeed(seed) == null
          ? ThemeRefusal.malformedSeed
          : ThemeRefusal.unreadable,
      validation: validation,
      nearestPassingSeed: validator.nearestPassingSeed(seed, now: now),
    );
  }

  /// The starter theme, from the product's own primary.
  ///
  /// `#B4526E` is `AppColors.primary` and the first curated swatch, so a coach
  /// who never opens B05 still has a validated theme.
  static PortfolioTheme starter({DateTime? now}) {
    final choice = validated(
      seed: kCuratedSeeds.first,
      type: PortfolioType.calm,
      corners: PortfolioCorners.soft,
      now: now,
    );
    return switch (choice) {
      ThemeAccepted(:final theme) => theme,
      // Unreachable while the golden test holds, and loud if it ever is not.
      ThemeRefused() => throw StateError(
        'The starter seed ${kCuratedSeeds.first} no longer passes contrast '
        'validation. A palette edit has broken B05; see the curated-seed '
        'golden in theme_validator_test.dart.',
      ),
    };
  }

  final String seed;
  final PortfolioType type;
  final PortfolioCorners corners;

  /// The proof. Always present, because there is no way to build one without.
  final ThemeValidation validation;

  PortfolioRadii get radii => PortfolioRadii(corners);

  /// The scheme, derived on demand and never stored.
  ColorScheme scheme({Brightness brightness = Brightness.light}) =>
      ColorScheme.fromSeed(
        seedColor: parseSeed(seed)!,
        brightness: brightness,
        contrastLevel: validation.contrastLevel,
      );

  /// The type pairing, as a lookup a block widget can read.
  ///
  /// Rubik in all three. `calm` is `app_tokens.dart` unchanged; `strong` is
  /// heavier and tighter; `soft` is lighter, looser and more generously led.
  TextStyle styleFor(PortfolioTextStyle style) {
    final base = switch (style) {
      PortfolioTextStyle.display => AppText.display,
      PortfolioTextStyle.headline => AppText.headline,
      PortfolioTextStyle.titleL => AppText.titleL,
      PortfolioTextStyle.titleM => AppText.titleM,
      PortfolioTextStyle.titleS => AppText.titleS,
      PortfolioTextStyle.body => AppText.body,
      PortfolioTextStyle.bodyM => AppText.bodyM,
      PortfolioTextStyle.label => AppText.label,
      PortfolioTextStyle.nav => AppText.nav,
    };

    return switch (type) {
      PortfolioType.calm => base,
      PortfolioType.strong => base.copyWith(
        fontWeight: _heavier(base.fontWeight),
        letterSpacing: -0.2,
        height: (base.height ?? 1.3) * 0.96,
      ),
      PortfolioType.soft => base.copyWith(
        fontWeight: _lighter(base.fontWeight),
        letterSpacing: 0.2,
        height: (base.height ?? 1.3) * 1.06,
      ),
    };
  }

  /// The theme map as it is stored. Three keys, matching the security rule's
  /// `hasOnly(['seed','type','corners'])` exactly.
  Map<String, Object?> toJson() => <String, Object?>{
    'seed': seed,
    'type': type.name,
    'corners': corners.name,
  };

  static FontWeight _heavier(FontWeight? w) => switch (w) {
    FontWeight.w400 => FontWeight.w500,
    FontWeight.w500 => FontWeight.w600,
    FontWeight.w600 => FontWeight.w700,
    _ => FontWeight.w600,
  };

  static FontWeight _lighter(FontWeight? w) => switch (w) {
    FontWeight.w700 => FontWeight.w600,
    FontWeight.w600 => FontWeight.w500,
    FontWeight.w500 => FontWeight.w400,
    _ => FontWeight.w400,
  };

  @override
  String toString() =>
      'PortfolioTheme($seed, ${type.name}, ${corners.name} @ '
      '${validation.contrastLevel})';
}
