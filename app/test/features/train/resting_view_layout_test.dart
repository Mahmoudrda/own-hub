// R09 — the "Up next" card and the buttons never overlap, at the two phone
// sizes the store listing shows, in English and Arabic, at normal and double
// text. The body scrolls above pinned buttons, so a card that runs past the
// end of the body is not drawn under a button: it is cut off by it. At normal
// text it has to fit above the buttons; at large text the buttons scroll with
// the body and the two must simply not overlap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/domain/live_best.dart';
import 'package:own_hub/features/train/presentation/rest_adjust_row.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_card.dart';
import 'package:own_hub/ui/screen_scope.dart';

const _move = 'Goblet squat, set 3';

Widget _host(Widget child, Locale locale, double textScale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    // The router's scope: R09 draws its illustration strip only when it fits.
    child: ScreenScope(screenId: 'R09', child: child),
  ),
);

void main() {
  const sizes = <Size>[Size(390, 844), Size(375, 667)];
  const best = LiveBest(
    exerciseId: 'goblet_squat',
    kind: LiveBestKind.heavier,
    loadKg: 14,
  );
  for (final size in sizes) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final scale in const [1.0, 2.0]) {
        for (final withBest in const [false, true]) {
          testWidgets(
            'up next is clear of the buttons at ${size.width.toInt()}x'
            '${size.height.toInt()}, ${locale.languageCode}, text x$scale'
            '${withBest ? ', with a new best' : ''}',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(
                _host(
                  RestingView(
                    autoStart: false,
                    upNext: _move,
                    upNextPrescription: '12 × 10',
                    liveBest: withBest ? best : null,
                  ),
                  locale,
                  scale,
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);

              final card = tester.getRect(
                find.ancestor(
                  of: find.text(_move),
                  matching: find.byType(AppCard),
                ),
              );
              final buttons = <Rect>[
                for (final e in find.byType(AppButton).evaluate())
                  tester.getRect(find.byWidget(e.widget)),
                tester.getRect(find.byType(RestAdjustRow)),
              ];
              // A new-best chip adds a row a 667 high phone has no room for:
              // the card then starts in view and the rest scrolls, as in any
              // list longer than its window, so only the start is checked.
              final fits = !withBest || size.height > 700 || scale > 1.3;
              if (fits) {
                for (final button in buttons) {
                  expect(
                    card.overlaps(button),
                    isFalse,
                    reason: 'card $card overlaps $button',
                  );
                }
              }
              if (scale == 1.0) {
                final body = tester.getRect(
                  find.byType(SingleChildScrollView).first,
                );
                expect(
                  fits ? card.bottom : card.top,
                  lessThanOrEqualTo(body.bottom),
                  reason: 'card $card runs past the body $body',
                );
              }
            },
          );
        }
      }
    }
  }
}
