// G02 — the sharing step, as a screen.
//
// P0-SHARE-01 ("all switches start off") and P0-SHARE-03 ("the copy does NOT
// say immediately") are both assertions about what a woman actually reads, so
// they are tested here as well as in the domain.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/sharing.dart';
import 'package:own_hub/features/coached/presentation/coaching_support_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_toggle.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: child,
  ),
);

void main() {
  testWidgets('P0-SHARE-01 — the three switches render off', (tester) async {
    await tester.pumpWidget(_host(const CoachingSupportView()));
    await tester.pumpAndSettle();

    expect(find.text('Energy and appetite'), findsOneWidget);
    expect(find.text('Cycle symptoms'), findsOneWidget);
    expect(find.text('Period dates and patterns'), findsOneWidget);

    // Every sharing toggle is off. The daily check-in toggle is a different
    // thing and is allowed to default on, so the assertion names the three.
    final toggles = tester
        .widgetList<AppToggle>(find.byType(AppToggle))
        .toList();
    final sharing = toggles
        .where(
          (t) => const {
            'Energy and appetite',
            'Cycle symptoms',
            'Period dates and patterns',
          }.contains(t.semanticLabel),
        )
        .toList();
    expect(sharing, hasLength(3));
    expect(sharing.every((t) => t.value == false), isTrue);
  });

  testWidgets('there is no "share everything" control on the screen', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const CoachingSupportView()));
    await tester.pumpAndSettle();

    for (final banned in [
      'Share everything',
      'Share all',
      'Turn on all',
      'Select all',
    ]) {
      expect(find.text(banned), findsNothing);
    }
    // Three sharing switches and the check-in, and nothing else that toggles.
    expect(find.byType(AppToggle), findsNWidgets(4));
  });

  testWidgets('it states that sharing is off unless she turns it on', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const CoachingSupportView()));
    await tester.pumpAndSettle();

    expect(
      find.text('Off unless you turn it on. Coaching never requires it.'),
      findsOneWidget,
    );
    expect(find.text('See exactly what she would see'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flipping one switch reports only that switch', (tester) async {
    final moved = <SharingKey, bool>{};
    await tester.pumpWidget(
      _host(
        CoachingSupportView(
          onToggleSharing: (key, value) => moved[key] = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppToggle && w.semanticLabel == 'Cycle symptoms',
      ),
    );
    await tester.pumpAndSettle();

    expect(moved, {SharingKey.symptoms: true});
  });

  group('P0-SHARE-03 — the offline wording is honest', () {
    testWidgets('a pending flip says it applies when she has signal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CoachingSupportView(syncState: SharingSyncState.savedOnDevice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved here until you have signal'), findsOneWidget);
    });

    testWidgets('nothing on this screen claims "immediately"', (tester) async {
      await tester.pumpWidget(
        _host(
          const CoachingSupportView(syncState: SharingSyncState.savedOnDevice),
        ),
      );
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(
        texts.contains('immediately'),
        isFalse,
        reason:
            'A server cannot deny a read it has not been told about. Saying '
            '"immediately" would be a promise the system cannot keep.',
      );
      expect(texts.contains('at once'), isFalse);
    });

    testWidgets('applied state shows no pending notice at all', (tester) async {
      await tester.pumpWidget(
        _host(const CoachingSupportView(syncState: SharingSyncState.applied)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved here until you have signal'), findsNothing);
    });
  });

  testWidgets('it survives the largest system text size', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const CoachingSupportView(), textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('it renders in Arabic without overflowing', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const CoachingSupportView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppToggle), findsNWidgets(4));
  });
}
