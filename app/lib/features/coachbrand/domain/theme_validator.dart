/// "We will not let you pick text a client cannot read" — the implementation.
///
/// B05 hands a coach six curated seeds and lets her choose her own. G13 §1.4.1
/// describes the mechanism as **nudge, not block**: a seed is built at
/// `contrastLevel` 0.0, then 0.5, then 1.0, **in that order**, and the first
/// level that passes *both* brightnesses is recorded. Her colour is raised to
/// legibility before it is ever refused, and only a seed that fails at 1.0 in
/// either brightness is refused at all.
///
/// Both brightnesses, not one. G13 §10 Q12 asks whether a published page
/// renders in the viewer's brightness or always in its own; this validator
/// takes the stricter side of that open question, so whichever way the owner
/// answers it, no already-accepted theme becomes unreadable.
library;

import 'package:flutter/material.dart';

import 'contrast.dart';

/// The three levels, tried in this order. The order is the mechanism.
const List<double> kContrastLevels = <double>[0.0, 0.5, 1.0];

/// B05's six curated seeds.
///
/// A golden test asserts all six pass at `contrastLevel` 0.0 in both
/// brightnesses, so a palette edit that breaks one fails the build rather than
/// shipping a swatch that silently needs boosting.
const List<String> kCuratedSeeds = <String>[
  '#B4526E',
  '#4F7359',
  '#8A5A17',
  '#4A5B8C',
  '#7A4A7E',
  '#2F6E6A',
];

/// `#RRGGBB`, and nothing else. Mirrors the security rule's regex exactly.
final RegExp kSeedPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Parses `#RRGGBB` into an opaque colour, or null.
Color? parseSeed(String seed) {
  if (!kSeedPattern.hasMatch(seed)) return null;
  return Color(0xFF000000 | int.parse(seed.substring(1), radix: 16));
}

/// The proof a theme passed, and the level it needed.
///
/// Written onto `portfolio.validator` by the Function, which re-runs this
/// identical algorithm and is authoritative. [PortfolioPublisher] refuses to
/// queue an intent whose theme carries no current validation, so an unvalidated
/// theme cannot reach `live` even from a tampered client.
@immutable
class ThemeValidation {
  const ThemeValidation._({
    required this.seed,
    required this.passed,
    required this.contrastLevel,
    required this.failures,
    required this.at,
  });

  /// The seed that was checked, normalised to upper case.
  final String seed;

  final bool passed;

  /// The first level at which both brightnesses passed, or 1.0 on a refusal.
  final double contrastLevel;

  /// Everything still failing at [contrastLevel]. Empty when [passed].
  final List<ContrastFailure> failures;

  final DateTime at;

  /// The algorithm version, carried so a stamp from an older pattern set is
  /// detectable rather than trusted.
  static const int version = 1;

  Map<String, Object?> toJson() => <String, Object?>{
    'v': version,
    'at': at.toIso8601String(),
    'contrastLevel': contrastLevel,
  };

  @override
  String toString() => passed
      ? 'ThemeValidation($seed passed @ $contrastLevel)'
      : 'ThemeValidation($seed REFUSED, ${failures.length} failures)';
}

/// Runs the 14 pairs against a seed, at up to three contrast levels.
@immutable
class ThemeValidator {
  const ThemeValidator({this.pairs = kPortfolioContrastPairs});

  final List<ContrastPair> pairs;

  /// Validates [seed], nudging the contrast level up before refusing.
  ///
  /// [now] is injected so a validation stamp is deterministic in a test rather
  /// than a wall clock the assertion has to work around.
  ThemeValidation validate(String seed, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final colour = parseSeed(seed);

    if (colour == null) {
      return ThemeValidation._(
        seed: seed,
        passed: false,
        contrastLevel: kContrastLevels.last,
        failures: const <ContrastFailure>[],
        at: at,
      );
    }

    final normalised = '#${seed.substring(1).toUpperCase()}';
    var lastFailures = const <ContrastFailure>[];

    for (final level in kContrastLevels) {
      final failures = <ContrastFailure>[];
      for (final brightness in Brightness.values) {
        failures.addAll(
          contrastFailures(
            ColorScheme.fromSeed(
              seedColor: colour,
              brightness: brightness,
              contrastLevel: level,
            ),
            pairs: pairs,
          ),
        );
      }

      if (failures.isEmpty) {
        return ThemeValidation._(
          seed: normalised,
          passed: true,
          contrastLevel: level,
          failures: const <ContrastFailure>[],
          at: at,
        );
      }
      lastFailures = List.unmodifiable(failures);
    }

    return ThemeValidation._(
      seed: normalised,
      passed: false,
      contrastLevel: kContrastLevels.last,
      failures: lastFailures,
      at: at,
    );
  }

  /// The curated seed closest to [seed] that passes.
  ///
  /// B05 offers this when a custom colour is refused, so the answer to "you
  /// cannot have that" is a colour rather than a dead end. Distance is plain
  /// RGB, which is enough to pick a neighbour from a six-swatch row.
  String? nearestPassingSeed(String seed, {DateTime? now}) {
    final wanted = parseSeed(seed);
    if (wanted == null) return kCuratedSeeds.first;

    String? best;
    var bestDistance = double.infinity;

    for (final candidate in kCuratedSeeds) {
      if (!validate(candidate, now: now).passed) continue;
      final colour = parseSeed(candidate)!;
      final dr = (colour.r - wanted.r) * 255;
      final dg = (colour.g - wanted.g) * 255;
      final db = (colour.b - wanted.b) * 255;
      final distance = dr * dr + dg * dg + db * db;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    return best;
  }
}
