// C13 — You're in.
//
// The payoff screen, and the one that restates rule 7 at the moment she is most
// likely to believe it. Two guards here are worth more than the rest:
//
//   * the deletion sentence is on screen, in both languages;
//   * the greeting never renders a placeholder for a name we do not have.
//
// That second one needs saying. `profile.firstName` is collected in setup, which
// runs *after* verification, so at this moment the product genuinely does not
// know her name. The greeting is two separate dictionary entries rather than one
// with an optional name — Arabic greets with a vocative, and a dangling يا with
// nothing after it reads as broken — so "You're in, null" is unreachable rather
// than merely unlikely. The test below pins that.
//
// The verification time is the same shape of problem, caught later. It used to
// default to the prototype's 74, so a screen reached without a measurement told
// every woman a specific invented fact about her own check. It is nullable now,
// and null states rule 7's promise without claiming a duration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/presentation/youre_in_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  // These cases describe the screen with every feature it can mention switched
  // on. The release shape, where copy about dark features is replaced or
  // hidden, is proved in flag_aware_promises_test.dart.
  late FeatureFlags saved;
  setUp(() {
    saved = AppRouter.featureFlags;
    AppRouter.featureFlags = FeatureFlags.everything;
  });
  tearDown(() => AppRouter.featureFlags = saved);

  group('it greets her by name when it knows one', () {
    testWidgets('her name appears in the greeting, in English', (tester) async {
      await tester.pumpWidget(_host(const YoureInView(firstName: 'Nour')));
      await tester.pumpAndSettle();

      expect(find.text("You're in, Nour"), findsOneWidget);
      expect(find.text("You're in"), findsNothing);
    });

    testWidgets('and in Arabic, after the vocative', (tester) async {
      await tester.pumpWidget(
        _host(const YoureInView(firstName: 'نور'), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('أهلًا بك يا نور'), findsOneWidget);
    });

    testWidgets('a blank name is treated as no name', (tester) async {
      // Guards the gap between "not given" and "given as empty" — both must
      // produce a whole sentence, never a trailing comma or a stray يا.
      await tester.pumpWidget(_host(const YoureInView(firstName: '   ')));
      await tester.pumpAndSettle();

      expect(find.text("You're in"), findsOneWidget);
    });

    testWidgets('it reports her real verification time, not the mockup 74', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const YoureInView(verifiedInSeconds: 31)));
      await tester.pumpAndSettle();

      expect(find.textContaining('31 seconds'), findsOneWidget);
      expect(find.textContaining('74 seconds'), findsNothing);
    });

    testWidgets('an untimed check states no duration at all', (tester) async {
      // The parameter defaulted to 74 — the prototype's sample — and nothing
      // anywhere recorded a start time, so every woman was told the same
      // invented number about her own verification. Saying less is better than
      // saying something untrue, especially on the screen where she is most
      // likely to believe it.
      await tester.pumpWidget(_host(const YoureInView()));
      await tester.pumpAndSettle();

      expect(find.textContaining('seconds'), findsNothing);
      expect(
        find.textContaining('Your ID photo and selfie have been deleted'),
        findsOneWidget,
        reason: 'rule 7 is still stated, just without a number',
      );
    });
  });

  testWidgets('tells her she is in, and what she has joined', (tester) async {
    await tester.pumpWidget(_host(const YoureInView()));
    await tester.pumpAndSettle();

    // No name passed, so she gets the complete nameless sentence rather than a
    // greeting with an empty gap where a name should be. Setup runs after this
    // screen, so on a first run this is the usual case.
    expect(find.text("You're in"), findsOneWidget);
    expect(
      find.text('Every woman here went through the same check.'),
      findsOneWidget,
    );
    expect(find.textContaining('never shown to members'), findsOneWidget);
    expect(find.text('Read the three rules'), findsOneWidget);
    expect(find.text("I'm a coach, set up my profile"), findsOneWidget);
  });

  testWidgets('RULE 7 — the deletion promise is restated here', (tester) async {
    // The moment it is most likely to be believed, and the moment it matters
    // most that it is true.
    await tester.pumpWidget(_host(const YoureInView()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your ID photo and selfie have been deleted'),
      findsOneWidget,
    );
    expect(
      find.textContaining('We kept the result and nothing else'),
      findsOneWidget,
    );
  });

  testWidgets('never renders a placeholder where a name should be', (
    tester,
  ) async {
    // She has no name in the product yet. Nothing on this screen may read as a
    // missing value.
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      await tester.pumpWidget(_host(const YoureInView(), locale: locale));
      await tester.pumpAndSettle();

      expect(find.textContaining('null'), findsNothing, reason: '$locale');
      expect(find.textContaining('{name}'), findsNothing, reason: '$locale');
    }
  });

  testWidgets('both ways forward work', (tester) async {
    var rules = 0;
    var coach = 0;
    await tester.pumpWidget(
      _host(
        YoureInView(onReadTheRules: () => rules++, onCoachSetup: () => coach++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read the three rules'));
    await tester.tap(find.text("I'm a coach, set up my profile"));
    await tester.pumpAndSettle();

    expect(rules, 1);
    expect(coach, 1);
  });

  testWidgets('reads in Arabic, including the deletion promise', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const YoureInView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    // The nameless Arabic greeting — no dangling vocative يا with nothing
    // after it, which is why this is a separate string rather than an empty
    // substitution.
    expect(find.text('أهلًا بك'), findsOneWidget);
    // Without the leading connective و: it belongs mid-sentence, after the
    // duration clause, and a standalone sentence must not open with it. Dropping
    // it here matches both the timed and untimed wording.
    expect(
      find.textContaining('حُذفت صورة بطاقتك وصورتك الذاتية'),
      findsOneWidget,
    );
    expect(find.text("You're in, Mai"), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    // Long copy, no scroll by default, and Arabic runs longer — G1 flagged this
    // screen as the one carrying long deletion copy at large text.
    await tester.pumpWidget(
      _host(const YoureInView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
