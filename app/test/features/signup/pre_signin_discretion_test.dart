// Before sign-in the menstrual cycle is referred to only indirectly; after
// sign-in, directly (owner decision, 15 Oct 2026). This renders every screen
// shown before the phone code completes and fails if any visible text, tooltip
// or screen-reader label carries a cycle word.
//
// English is matched as whole words, case-insensitive. Arabic has no spaces
// around its prefixes ("ودورتك", "الدورة"), so its stems are matched anywhere
// in the text.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/cycle/presentation/cycle_hub_view.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/signup/demo/demo_sample.dart';
import 'package:own_hub/features/signup/domain/locale_preference.dart';
import 'package:own_hub/features/signup/presentation/language_view.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/features/signup/presentation/whats_inside_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart' show LocaleScope;
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

final RegExp _bannedEnglish = RegExp(
  r'\b(cycles?|periods?|menstrual|menstruation|ovulation|pms)\b',
  caseSensitive: false,
);
final RegExp _bannedArabic = RegExp(
  'دورة|دورت|دورات'
  '|بريود|تبويض|الطمث',
);

bool _banned(String text) =>
    _bannedEnglish.hasMatch(text) || _bannedArabic.hasMatch(text);

/// Everything a woman can read or hear on the current screen.
List<String> _visibleText(WidgetTester tester) {
  final out = <String>[];
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final value = text.data ?? text.textSpan?.toPlainText();
    if (value != null) out.add(value);
  }
  for (final tip in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    if (tip.message != null) out.add(tip.message!);
  }
  for (final s in tester.widgetList<Semantics>(find.byType(Semantics))) {
    final label = s.properties.label;
    if (label != null) out.add(label);
  }
  for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
    if (icon.semanticLabel != null) out.add(icon.semanticLabel!);
  }
  return out;
}

void _expectDiscreet(WidgetTester tester, String where) {
  final text = _visibleText(tester);
  expect(text, isNotEmpty, reason: '$where drew nothing');
  expect(
    text.where(_banned).toList(),
    isEmpty,
    reason: '$where names the cycle before sign-in',
  );
}

Widget _host(Widget child, Locale locale) {
  return LocaleScope(
    notifier: ValueNotifier<Locale>(locale),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: child,
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late FeatureFlags saved;
  late DemoSample Function() buildSample;

  setUpAll(() async {
    final book = await SeededRecipeLibrary(
      readAsset: (path) async => File(path).readAsString(),
    ).load();
    buildSample = () =>
        DemoSample.build(now: DateTime(2026, 10, 6, 10), book: book);
  });

  setUp(() => saved = AppRouter.featureFlags);
  tearDown(() => AppRouter.featureFlags = saved);

  // The cycle row on, the community on and off: every line that can be drawn.
  final flagSets = <String, FeatureFlags>{
    'everything on': FeatureFlags.everything,
    'community off': FeatureFlags.everything.with_(<Feature, bool>{
      Feature.community: false,
    }),
  };

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final flags in flagSets.entries) {
      final tag = '${locale.languageCode}, ${flags.key}';

      group('before sign-in ($tag)', () {
        setUp(() => AppRouter.featureFlags = flags.value);

        testWidgets('C01 Welcome', (tester) async {
          _phone(tester);
          await tester.pumpWidget(
            _host(WelcomeView(preference: InMemoryLocalePreference()), locale),
          );
          await tester.pumpAndSettle();
          _expectDiscreet(tester, 'C01');
        });

        testWidgets('C01 More sheet and its delete dialog', (tester) async {
          _phone(tester);
          await tester.pumpWidget(
            _host(
              WelcomeView(
                preference: InMemoryLocalePreference(),
                onWhatsInside: () {},
                onInviteCode: () {},
                onCoachInterest: () {},
                onDeleteSaved: () async {},
              ),
              locale,
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppL10n.of(tester.element(find.byType(WelcomeView)));

          await _tap(tester, find.text(l10n.more));
          expect(find.text(l10n.deleteWhatISavedOnThisPhone), findsOneWidget);
          _expectDiscreet(tester, 'C01 More sheet');

          await _tap(tester, find.text(l10n.deleteWhatISavedOnThisPhone));
          expect(find.text(l10n.deleteIt), findsOneWidget);
          _expectDiscreet(tester, 'C01 delete dialog');
        });

        testWidgets('C02 Language', (tester) async {
          _phone(tester);
          await tester.pumpWidget(
            _host(LanguageView(preference: InMemoryLocalePreference()), locale),
          );
          await tester.pumpAndSettle();
          _expectDiscreet(tester, 'C02');
        });

        testWidgets('C03 What is inside', (tester) async {
          _phone(tester);
          await tester.pumpWidget(_host(const WhatsInsideView(), locale));
          await tester.pumpAndSettle();
          _expectDiscreet(tester, 'C03');
        });

        testWidgets('C04 every tour stop, the end card and C05', (
          tester,
        ) async {
          _phone(tester);
          final sample = buildSample();
          addTearDown(sample.dispose);
          await tester.pumpWidget(
            _host(
              LookAroundView(sample: sample, onLeave: () {}, onJoin: () {}),
              locale,
            ),
          );
          await tester.pumpAndSettle();

          final l10n = AppL10n.of(tester.element(find.byType(LookAroundView)));
          for (var stop = 0; stop < 7; stop++) {
            _expectDiscreet(tester, 'C04 stop ${stop + 1}');
            if (stop == 5) {
              // C05, the join sheet, raised by the check-in button.
              await _tap(tester, find.text(l10n.howAreYouFeeling));
              _expectDiscreet(tester, 'C05');
              await _tap(tester, find.text(l10n.keepLooking));
            }
            await _tap(tester, find.text(l10n.next));
          }
          _expectDiscreet(tester, 'C04 end card');
        });
      });
    }
  }

  // The control: the detector does catch the wording, and Y03 after sign-in
  // still says it. If this fails the test above is blind.
  group('after sign-in', () {
    setUp(() => AppRouter.featureFlags = FeatureFlags.everything);

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('Y03 keeps the cycle wording (${locale.languageCode})', (
        tester,
      ) async {
        _phone(tester);
        final sample = buildSample();
        addTearDown(sample.dispose);
        await tester.pumpWidget(
          _host(
            CycleHubView(
              cycle: sample.cycle,
              periods: sample.periods,
              now: sample.now,
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(_visibleText(tester).where(_banned), isNotEmpty);
      });
    }

    test('the detector matches whole words only', () {
      expect(_banned('Your cycle, on this phone'), isTrue);
      expect(_banned('Period day 2'), isTrue);
      expect(_banned('دورتك'), isTrue);
      expect(_banned('Your month, your rhythm'), isFalse);
      expect(_banned('Cycling and periodic checks'), isFalse);
    });
  });
}
