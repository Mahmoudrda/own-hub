// P0-PORT-06 — "a coach cannot choose unreadable text".
//
// The threshold table is the whole of this file's value, and it is asserted
// against `test/fixtures/contrast_vectors.json` rather than against itself.
// G13 §1.4.6 requires that fixture because the publish Function re-runs this
// algorithm in another language and is authoritative: if the two drift, a
// coach's colour passes on her phone and is refused by the server, or worse,
// the other way round.
//
// The trap this file exists to hold shut is `titleL`. It is 20 px at weight
// 600, which looks like WCAG "large text" and is not — the carve-out needs
// ≥18.66 px **bold**, and 600 is semi-bold. Letting titleL through at 3.0:1
// would be the single most plausible mistake a second implementer makes.
//
// Two measured findings are recorded here as tests rather than as comments,
// because both are the kind of thing a later change would quietly undo.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/contrast.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_theme.dart';
import 'package:own_hub/features/coachbrand/domain/theme_validator.dart';

final _at = DateTime.utc(2026, 3, 10);

/// A pair no scheme can satisfy: `surface` on `surface` is 1.0:1 at every
/// brightness and every contrast level.
///
/// Injected to exercise the refusal path, which — see the findings group — no
/// real seed reaches. A synthetic probe is the honest way to test a branch the
/// production pair set cannot produce; the alternative is an untested refusal
/// that nobody notices is broken until a coach meets it.
const ContrastPair _alwaysFails = ContrastPair(
  name: 'surface/surface',
  foreground: SchemeRole.surface,
  background: SchemeRole.surface,
  styles: {PortfolioTextStyle.body},
);

Map<String, Object?> _fixture() =>
    jsonDecode(File('test/fixtures/contrast_vectors.json').readAsStringSync())
        as Map<String, Object?>;

Color _hex(String value) =>
    Color(0xFF000000 | int.parse(value.substring(1), radix: 16));

void main() {
  final fixture = _fixture();
  final thresholds = fixture['thresholds']! as Map<String, Object?>;

  group('the thresholds, exactly as G13 §1.4.3 states them', () {
    test('every text style matches the shared fixture', () {
      for (final style in PortfolioTextStyle.values) {
        expect(
          ContrastThresholds.forTextStyle(style),
          thresholds[style.name],
          reason: '${style.name} disagrees with the fixture the server reads',
        );
      }
    });

    test('3.0:1 applies to display and headline, and to nothing else', () {
      expect(ContrastThresholds.forTextStyle(PortfolioTextStyle.display), 3.0);
      expect(ContrastThresholds.forTextStyle(PortfolioTextStyle.headline), 3.0);

      for (final style in PortfolioTextStyle.values) {
        if (ContrastThresholds.largeTextStyles.contains(style)) continue;
        expect(
          ContrastThresholds.forTextStyle(style),
          4.5,
          reason: '${style.name} is not WCAG large text',
        );
      }
    });

    test('titleL and titleM are 4.5:1 — 600 is not bold', () {
      // 20/600 and 17/600. The large-text carve-out needs ≥24 px, or
      // ≥18.66 px BOLD. Neither qualifies, and G13 calls this out as
      // "deliberately stricter than implementers usually assume".
      expect(ContrastThresholds.forTextStyle(PortfolioTextStyle.titleL), 4.5);
      expect(ContrastThresholds.forTextStyle(PortfolioTextStyle.titleM), 4.5);
    });

    test('non-text is 3.0:1, per WCAG 1.4.11', () {
      expect(ContrastThresholds.nonText, 3.0);
      expect(ContrastThresholds.nonText, thresholds['nonText']);
    });

    test('the large-text set has exactly two members, forever', () {
      expect(ContrastThresholds.largeTextStyles, {
        PortfolioTextStyle.display,
        PortfolioTextStyle.headline,
      });
      expect((thresholds['largeTextStyles']! as List<Object?>).cast<String>(), [
        'display',
        'headline',
      ]);
    });
  });

  group('WCAG 2.1 arithmetic, against the fixture', () {
    test('relative luminance', () {
      for (final vector in (fixture['luminance']! as List<Object?>)) {
        final v = vector! as Map<String, Object?>;
        expect(
          relativeLuminance(_hex(v['hex']! as String)),
          closeTo((v['l']! as num).toDouble(), 1e-9),
          reason: v['hex'] as String,
        );
      }
    });

    test('contrast ratio', () {
      for (final vector in (fixture['ratios']! as List<Object?>)) {
        final v = vector! as Map<String, Object?>;
        expect(
          contrastRatio(_hex(v['a']! as String), _hex(v['b']! as String)),
          closeTo((v['ratio']! as num).toDouble(), 1e-9),
          reason: '${v['a']} vs ${v['b']}',
        );
      }
    });

    test('the extremes are 21:1 and 1:1', () {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21.0, 1e-9),
      );
      expect(
        contrastRatio(const Color(0xFF808080), const Color(0xFF808080)),
        closeTo(1.0, 1e-9),
      );
    });

    test('it is symmetric — order of the pair does not change the answer', () {
      const a = Color(0xFFB4526E);
      const b = Color(0xFFFFF8F9);
      expect(contrastRatio(a, b), contrastRatio(b, a));
    });

    test('the luminance-only form agrees with the colour form', () {
      const a = Color(0xFF4F7359);
      const b = Color(0xFFFFFFFF);
      expect(
        ratioForLuminances(relativeLuminance(a), relativeLuminance(b)),
        contrastRatio(a, b),
      );
    });
  });

  group('the fourteen pairs', () {
    test('there are fourteen, and their names are unique', () {
      expect(kPortfolioContrastPairs.length, 14);
      expect(kPortfolioContrastPairs.map((p) => p.name).toSet().length, 14);
    });

    test(
      'a text pair names the styles drawn on it; a non-text pair does not',
      () {
        for (final pair in kPortfolioContrastPairs) {
          if (pair.isText) {
            expect(pair.styles, isNotEmpty, reason: pair.name);
          } else {
            expect(pair.styles, isEmpty, reason: pair.name);
          }
        }
        expect(
          kPortfolioContrastPairs.where((p) => !p.isText).length,
          2,
          reason: 'the two boundary pairs, checked at 1.4.11',
        );
      },
    );

    test('each style on a pair is checked at its own threshold', () {
      // The cover in no-photo draws `display` on `onSurface/surface`, and the
      // body text under it draws `body` on the same pair. They are different
      // requirements on one ratio, and the failure report says which.
      final surfacePair = kPortfolioContrastPairs.firstWhere(
        (p) => p.name == 'onSurface/surface',
      );
      expect(surfacePair.styles, contains(PortfolioTextStyle.display));
      expect(surfacePair.styles, contains(PortfolioTextStyle.body));
    });

    test('every failure is reported, not just the first', () {
      // B05 offers "the nearest passing seed", which needs to know how far off
      // a seed is rather than that it is off.
      const impossible = ColorScheme.light(
        primary: Color(0xFFFEFEFE),
        onPrimary: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFFFEFEFE),
      );
      final failures = contrastFailures(impossible);

      expect(failures.length, greaterThan(1));
      expect(failures.map((f) => f.pair).toSet().length, greaterThan(1));
      expect(failures.first.toString(), contains(':1'));
    });
  });

  group('the golden — the six curated seeds', () {
    const validator = ThemeValidator();

    test('the fixture and the code agree on which seeds those are', () {
      expect(
        (fixture['curatedSeeds']! as List<Object?>).cast<String>(),
        kCuratedSeeds,
      );
      expect(kCuratedSeeds.length, 6);
    });

    for (final seed in kCuratedSeeds) {
      test('$seed passes at contrastLevel 0.0 in both brightnesses', () {
        final validation = validator.validate(seed, now: _at);

        expect(validation.passed, isTrue, reason: '${validation.failures}');
        expect(
          validation.contrastLevel,
          0.0,
          reason:
              'a swatch that needs boosting is a swatch that should be '
              'replaced, not shipped',
        );
        expect(validation.failures, isEmpty);
      });
    }

    test('a palette edit that breaks one fails the build', () {
      // Which is what the six cases above are. Stated once more as the reason
      // they exist, so nobody deletes them as duplication.
      for (final seed in kCuratedSeeds) {
        for (final brightness in Brightness.values) {
          expect(
            contrastFailures(
              ColorScheme.fromSeed(
                seedColor: parseSeed(seed)!,
                brightness: brightness,
                contrastLevel: 0.0,
              ),
            ),
            isEmpty,
            reason: '$seed in ${brightness.name}',
          );
        }
      }
    });

    test(
      'the levels are tried in order, and the first passing one is kept',
      () {
        expect(kContrastLevels, const [0.0, 0.5, 1.0]);
        expect(
          (fixture['contrastLevels']! as List<Object?>).cast<num>(),
          const [0, 0.5, 1],
        );
        expect(
          validator.validate(kCuratedSeeds.first, now: _at).contrastLevel,
          kContrastLevels.first,
        );
      },
    );
  });

  group('a theme cannot exist unless it passed', () {
    test('validated() hands back a theme carrying its own proof', () {
      final choice = PortfolioTheme.validated(
        seed: '#4F7359',
        type: PortfolioType.strong,
        corners: PortfolioCorners.round,
        now: _at,
      );

      expect(choice, isA<ThemeAccepted>());
      final theme = (choice as ThemeAccepted).theme;
      expect(theme.validation.passed, isTrue);
      expect(theme.seed, '#4F7359');
      expect(theme.type, PortfolioType.strong);
      expect(theme.corners, PortfolioCorners.round);
    });

    test('a lowercase seed is normalised so two spellings are one theme', () {
      final choice = PortfolioTheme.validated(
        seed: '#4f7359',
        type: PortfolioType.calm,
        corners: PortfolioCorners.soft,
        now: _at,
      ) as ThemeAccepted;
      expect(choice.theme.seed, '#4F7359');
    });

    test('a malformed seed is refused and named as malformed', () {
      for (final bad in const ['4F7359', '#4F73', 'rebeccapurple', '#GGGGGG']) {
        final choice = PortfolioTheme.validated(
          seed: bad,
          type: PortfolioType.calm,
          corners: PortfolioCorners.soft,
          now: _at,
        );
        expect(choice, isA<ThemeRefused>(), reason: bad);
        expect((choice as ThemeRefused).reason, ThemeRefusal.malformedSeed);
        expect(choice.nearestPassingSeed, isNotNull);
      }
    });

    test('the starter theme exists and is validated', () {
      final theme = PortfolioTheme.starter(now: _at);
      expect(theme.seed, kCuratedSeeds.first);
      expect(theme.validation.passed, isTrue);
    });

    test('a refused seed is offered the nearest curated colour', () {
      // Exercised through an injected pair set, because — see the findings
      // group below — no real seed fails the shipped one. `surface/surface` is
      // 1.0:1 at every contrast level and every brightness, which makes it a
      // deterministic probe for the refusal path rather than a colour anybody
      // would compose.
      const impossible = ThemeValidator(pairs: [_alwaysFails]);

      final validation = impossible.validate('#B4526E', now: _at);
      expect(validation.passed, isFalse);
      expect(
        validation.contrastLevel,
        1.0,
        reason: 'it tried 0.0, then 0.5, then 1.0 before refusing',
      );
      expect(validation.failures, isNotEmpty);

      expect(
        impossible.nearestPassingSeed('#B4526E', now: _at),
        isNull,
        reason: 'when nothing passes, there is nothing honest to offer',
      );
      expect(
        const ThemeValidator().nearestPassingSeed('#B0506C', now: _at),
        '#B4526E',
        reason: 'the nearest curated swatch, not the first one',
      );
    });

    test('the refusal branch reaches PortfolioTheme too', () {
      final choice = PortfolioTheme.validated(
        seed: '#B4526E',
        type: PortfolioType.calm,
        corners: PortfolioCorners.soft,
        now: _at,
        validator: const ThemeValidator(pairs: [_alwaysFails]),
      );

      expect(choice, isA<ThemeRefused>());
      expect((choice as ThemeRefused).reason, ThemeRefusal.unreadable);
    });
  });

  group('measured findings — recorded so a later change cannot undo them', () {
    test(
      'G13\'s literal pair list is unsatisfiable: its two ungaranteed pairs '
      'need opposite contrast levels, so NO seed would pass at ANY level',
      () {
        // This is the finding that forced the one substitution in
        // `kPortfolioContrastPairs`, and it is measured rather than argued.
        //
        //   * `outlineVariant/surfaceContainer` needs a contrast level of at
        //     least 0.5. At 0.0 it reads 1.46–1.76 against a 3.0:1 threshold,
        //     for EVERY seed — M3 fixes those two tones by palette position,
        //     not by the colour a coach chose.
        //   * `onSurface/primaryContainer` needs level 0.0. At 0.5 it reads
        //     ~3.2:1 and at 1.0 ~1.8:1, against 4.5:1.
        //
        // One needs the level raised, the other needs it left alone, and the
        // scheme has a single level. So the two requirements cannot both hold,
        // and a validator carrying both refuses every theme this product can
        // generate — including the six swatches the design ships.
        for (final seed in kCuratedSeeds) {
          for (final brightness in Brightness.values) {
            ColorScheme scheme(double level) => ColorScheme.fromSeed(
              seedColor: parseSeed(seed)!,
              brightness: brightness,
              contrastLevel: level,
            );

            expect(
              contrastRatio(
                scheme(0.0).outlineVariant,
                scheme(0.0).surfaceContainer,
              ),
              lessThan(ContrastThresholds.nonText),
              reason: '$seed ${brightness.name} — outlineVariant at level 0.0',
            );

            for (final level in const [0.5, 1.0]) {
              expect(
                contrastRatio(
                  scheme(level).onSurface,
                  scheme(level).primaryContainer,
                ),
                lessThan(ContrastThresholds.normal),
                reason:
                    '$seed ${brightness.name} — the B07 step badge at '
                    'level $level',
              );
            }
          }
        }
      },
    );

    test(
      'the substitution resolves it: outline clears 3.0:1 at every level, so '
      'level 0.0 satisfies all fourteen pairs',
      () {
        // 3.0:1 is WCAG 1.4.11 and does not move. What moves is the ROLE.
        // `outlineVariant` is M3's decorative hairline — the line between two
        // rows, which conveys nothing a reader would lose. A boundary that
        // carries meaning uses `outline` (tone 50), and that clears 3.0:1 with
        // room to spare everywhere.
        for (final seed in kCuratedSeeds) {
          for (final brightness in Brightness.values) {
            for (final level in kContrastLevels) {
              final scheme = ColorScheme.fromSeed(
                seedColor: parseSeed(seed)!,
                brightness: brightness,
                contrastLevel: level,
              );
              expect(
                contrastRatio(scheme.outline, scheme.surfaceContainer),
                greaterThanOrEqualTo(ContrastThresholds.nonText),
                reason: '$seed ${brightness.name} L$level',
              );
            }
          }
        }

        expect(
          kPortfolioContrastPairs.any((p) => p.name.contains('outlineVariant')),
          isFalse,
          reason:
              'the shipped set uses outline; outlineVariant is for '
              'decoration and must not carry meaning in a block widget',
        );
      },
    );

    test(
      'because the B07 step badge pins the level to 0.0, the nudge ladder can '
      'only ever return 0.0 or refuse',
      () {
        // G13 §1.4.1 describes a nudge: try 0.0, then 0.5, then 1.0. With
        // `onSurface/primaryContainer` in the set — and it stays, because it is
        // a real requirement that fromSeed does not guarantee — rungs 0.5 and
        // 1.0 are unreachable. Recorded rather than hidden: the ladder is not
        // load-bearing today, since nothing fails at 0.0 (next test).
        for (final seed in kCuratedSeeds) {
          expect(
            const ThemeValidator().validate(seed, now: _at).contrastLevel,
            0.0,
            reason: seed,
          );
        }
      },
    );

    test(
      'fromSeed normalises tone, so even a near-white seed produces a readable '
      'scheme — P0-PORT-06\'s refusal branch is unreachable from a real seed',
      () {
        // P0-PORT-06 says "then attempt a custom near-white seed". With
        // `ColorScheme.fromSeed` the seed sets hue and chroma; the TONES are
        // fixed by the scheme variant. A near-white seed therefore yields the
        // same tonal distances as any other, and passes.
        //
        // That is worth knowing rather than worth hiding: the validator's real
        // protection is the four pairs fromSeed does not guarantee, not the
        // lightness of what she picked. The refusal path is tested above with
        // an injected pair set, which is the honest way to exercise it.
        const validator = ThemeValidator();

        for (final seed in const ['#FFFEF8', '#FFFFFF', '#FFFF00', '#000000']) {
          final validation = validator.validate(seed, now: _at);
          expect(
            validation.passed,
            isTrue,
            reason: '$seed — ${validation.failures}',
          );
        }
      },
    );
  });

  group('the validation stamp', () {
    test('it carries the version, the moment and the level', () {
      final validation = const ThemeValidator().validate('#4F7359', now: _at);
      final json = validation.toJson();

      expect(json['v'], ThemeValidation.version);
      expect(json['at'], _at.toIso8601String());
      expect(json['contrastLevel'], 0.0);
    });

    test('it holds no colour values a renderer could read instead', () {
      // The rendered scheme is derived, never stored. A stamp carrying the
      // resolved colours would be a second source of truth for the palette.
      final json = const ThemeValidator()
          .validate('#4F7359', now: _at)
          .toJson();
      expect(json.keys.toSet(), {'v', 'at', 'contrastLevel'});
    });
  });
}
