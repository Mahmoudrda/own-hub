// P05, her progress card: what she did, on one card she can share.
//
// The card says only what is true and only what she chose: a figure of zero is
// left off rather than shown as a row of nothing, a body figure is never on it
// unless she switches it on that visit, and calories are never on it at all.
// Sharing hands the phone's share sheet a real PNG of the card, anchored at the
// button so an iPad can place the sheet.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/progress/presentation/share_progress_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_toggle.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

const _story = ProgressStory(
  sessions: 12,
  countedWeeks: 4,
  bestRun: 3,
  mealsAdded: 27,
  bests: 5,
  milestones: 2,
);

List<({DateTime at, num kg})> _weighIns(List<num> kgs) => [
  for (var i = 0; i < kgs.length; i++)
    (at: DateTime(2026, 9, 1).add(Duration(days: 7 * i)), kg: kgs[i]),
];

AppButton _shareButton(WidgetTester tester) => tester.widget<AppButton>(
  find.ancestor(
    of: find.text('Share my card'),
    matching: find.byType(AppButton),
  ),
);

void main() {
  group('the card says what she did, and only that', () {
    testWidgets('her workouts, weeks, run, meals, bests and milestones', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(const ShareProgressView(story: _story)));
      await tester.pumpAndSettle();

      expect(find.text('Your progress card'), findsOneWidget);
      expect(find.text('My progress on Own Hub'), findsOneWidget);
      expect(find.text('Workouts done'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      for (final (label, value) in [
        ('Weeks trained', '4'),
        ('Best run, in weeks', '3'),
        ('Meals added', '27'),
        ('Personal bests', '5'),
        ('Milestones', '2'),
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(find.text(value), findsOneWidget, reason: '$label $value');
      }
      expect(find.text('own-hub.app · Women only.'), findsOneWidget);
    });

    testWidgets('a figure of zero is left off the card', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const ShareProgressView(
            story: ProgressStory(
              sessions: 1,
              countedWeeks: 0,
              bestRun: 0,
              mealsAdded: 2,
              bests: 0,
              milestones: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Meals added'), findsOneWidget);
      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('Weeks trained'), findsNothing);
      expect(find.text('Best run, in weeks'), findsNothing);
      expect(find.text('Personal bests'), findsNothing);
    });

    testWidgets('nothing done yet: nothing to share, and it says when', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ShareProgressView(
            story: const ProgressStory(
              sessions: 0,
              countedWeeks: 0,
              bestRun: 0,
              mealsAdded: 0,
              bests: 0,
              milestones: 0,
            ),
            onShare: (png, origin) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Your card fills in after your first workout.'),
        findsOneWidget,
      );
      expect(_shareButton(tester).onPressed, isNull);
    });

    test('no calories anywhere on the card', () {
      final source = File(
        'lib/features/progress/presentation/share_progress_view.dart',
      ).readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.toLowerCase(), isNot(contains('kcal')));
      expect(code.toLowerCase(), isNot(contains('calorie')));
    });
  });

  group('her weight is hers to put on it', () {
    testWidgets('not offered with fewer than two weigh-ins', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ShareProgressView(
            story: _story,
            loadWeighIns: () async => _weighIns([70]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show my weight change'), findsNothing);
      expect(find.text('Weight since my first weigh-in'), findsNothing);
    });

    testWidgets('offered, off when the screen opens, on only when she says', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ShareProgressView(
            story: _story,
            loadWeighIns: () async => _weighIns([72, 71.2, 69.5]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show my weight change'), findsOneWidget);
      expect(tester.widget<AppToggle>(find.byType(AppToggle)).value, isFalse);
      expect(find.text('Weight since my first weigh-in'), findsNothing);

      // Below the card she is about to change, so she sees the card first.
      await tester.ensureVisible(find.byType(AppToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();

      expect(find.text('Weight since my first weigh-in'), findsOneWidget);
      expect(find.text('−2.5 kg'), findsOneWidget);
    });

    testWidgets('a weigh-in that fails to load leaves the switch away', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ShareProgressView(
            story: _story,
            loadWeighIns: () => Future.error(StateError('offline')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Show my weight change'), findsNothing);
    });

    test('the change runs from her first weigh-in to her latest', () {
      expect(weightChangeKg(_weighIns([70])), isNull);
      expect(weightChangeKg(const []), isNull);
      expect(weightChangeKg(_weighIns([72, 70.04])), -2.0);
      expect(weightChangeKg(_weighIns([60, 61.26])), 1.3);
      // Order does not come from the list: an older entry read last is
      // still her first.
      final shuffled = _weighIns([80, 78, 75]).reversed.toList();
      expect(weightChangeKg(shuffled), -5.0);
    });

    test('it is written with a true minus, Western digits and kg', () {
      final en = lookupAppL10n(const Locale('en'));
      final ar = lookupAppL10n(const Locale('ar'));
      expect(weightChangeLabel(en, -2.5), '−2.5 kg');
      expect(weightChangeLabel(en, 1), '+1 kg');
      expect(weightChangeLabel(en, 0), '0 kg');
      expect(weightChangeLabel(ar, -2.5), '−2.5 كجم');
    });
  });

  group('sharing', () {
    testWidgets('hands the share sheet a PNG of the card, at the button', (
      tester,
    ) async {
      _phone(tester);
      Uint8List? sent;
      Rect? anchor;
      var shared = 0;
      await tester.pumpWidget(
        _host(
          ShareProgressView(
            story: _story,
            onShare: (png, origin) async {
              sent = png;
              anchor = origin;
            },
            onShared: () => shared++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Share my card'));
        await tester.pump();
        for (var i = 0; i < 50 && sent == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      // The PNG signature: \x89 P N G.
      expect(sent!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(sent!.length, greaterThan(1000));
      expect(anchor, isNotNull);
      expect(anchor!.width, greaterThan(0));
      expect(anchor!.height, greaterThan(0));
      expect(shared, 1);
    });

    testWidgets('a share sheet that fails costs her nothing she can see', (
      tester,
    ) async {
      _phone(tester);
      var shared = 0;
      await tester.pumpWidget(
        _host(
          ShareProgressView(
            story: _story,
            onShare: (png, origin) async => throw StateError('no sheet'),
            onShared: () => shared++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Share my card'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(shared, 0);
      expect(_shareButton(tester).onPressed, isNotNull);
    });
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(const ShareProgressView(story: _story), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('كارت تقدّمك'), findsOneWidget);
    expect(find.text('تقدّمي على Own Hub'), findsOneWidget);
    expect(find.text('تمارين اتعملت'), findsOneWidget);
    expect(find.text('شاركي كارتي'), findsOneWidget);
    expect(find.text('own-hub.app · للستات بس.'), findsOneWidget);
  });
}
