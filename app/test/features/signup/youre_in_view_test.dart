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
import 'package:own_hub/ui/app_button.dart';

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
    expect(find.text('Set up my coach profile'), findsOneWidget);
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
    // R2-G5: what the server keeps, said whole. Never "nothing else".
    expect(
      find.textContaining(
        'We keep the result, its reasons and a keyed code of your ID number.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('nothing else'), findsNothing);
  });

  testWidgets('R2-G5: the timed line and the Arabic say the same', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const YoureInView(verifiedInSeconds: 31)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Verified in 31 seconds.'),
      findsOneWidget,
    );
    expect(find.textContaining('a keyed code of your ID number'), findsOneWidget);

    await tester.pumpWidget(
      _host(const YoureInView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ونحتفظ بالنتيجة وأسبابها وبرمز مشفّر من رقمكِ القومي'),
      findsOneWidget,
    );
    expect(find.textContaining('لا غير'), findsNothing);
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
    await tester.tap(find.text('Set up my coach profile'));
    await tester.pumpAndSettle();

    expect(rules, 1);
    expect(coach, 1);
  });

  group('R1-P16: her role decides the primary', () {
    AppButton buttonFor(WidgetTester tester, String label) => tester
        .widget<AppButton>(find.ancestor(
          of: find.text(label),
          matching: find.byType(AppButton),
        ));

    testWidgets('a coach: her profile is the primary, and day one is not '
        'offered', (tester) async {
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.community: false,
      });
      await tester.pumpWidget(_host(const YoureInView(alsoTrains: false)));
      await tester.pumpAndSettle();

      expect(
        buttonFor(tester, 'Set up my coach profile').variant,
        AppButtonVariant.filled,
      );
      expect(find.text('Start day 1'), findsNothing);
      expect(find.text('Go to Home'), findsNothing);
    });

    testWidgets('both: her profile first, the trainee way on second', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.community: false,
      });
      await tester.pumpWidget(_host(const YoureInView()));
      await tester.pumpAndSettle();

      expect(
        buttonFor(tester, 'Set up my coach profile').variant,
        AppButtonVariant.filled,
      );
      expect(
        buttonFor(tester, 'Start day 1').variant,
        AppButtonVariant.outlined,
      );
      final coachY = tester.getTopLeft(find.text('Set up my coach profile')).dy;
      final dayOneY = tester.getTopLeft(find.text('Start day 1')).dy;
      expect(coachY, lessThan(dayOneY));
    });

    testWidgets('a trainee: day one stays the primary, no coach button', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.community: false,
      });
      await tester.pumpWidget(_host(const YoureInView(isCoach: false)));
      await tester.pumpAndSettle();

      expect(buttonFor(tester, 'Start day 1').variant, AppButtonVariant.filled);
      expect(find.text('Set up my coach profile'), findsNothing);
    });

    testWidgets('coach app off: a coach is offered the trainee way on', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.community: false,
        Feature.coachApp: false,
      });
      await tester.pumpWidget(_host(const YoureInView(alsoTrains: false)));
      await tester.pumpAndSettle();

      expect(find.text('Set up my coach profile'), findsNothing);
      expect(buttonFor(tester, 'Start day 1').variant, AppButtonVariant.filled);
    });

    testWidgets('the Arabic label', (tester) async {
      await tester.pumpWidget(
        _host(const YoureInView(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('جهّزي ملفكِ كمدرِّبة'), findsOneWidget);
    });
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
      find.textContaining('حُذفت صورة بطاقتكِ وصورتكِ الذاتية'),
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

  // B7. With the community off, the peak moment leads to the first workout,
  // not to a pledge about a room that does not exist yet.
  group('with the community off', () {
    setUp(() {
      AppRouter.featureFlags = FeatureFlags.allOff;
    });

    testWidgets('"Start day 1" leads, "Go to Home" follows, no pledge', (
      tester,
    ) async {
      var day1 = 0;
      var home = 0;
      await tester.pumpWidget(
        _host(
          YoureInView(
            isCoach: false,
            onStartDay1: () => day1++,
            onGoHome: () => home++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read the three rules'), findsNothing);
      await tester.tap(find.text('Start day 1'));
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(day1, 1);
      expect(home, 1);
      // The deletion promise stays.
      expect(
        find.textContaining('Your ID photo and selfie have been deleted'),
        findsOneWidget,
      );
    });

    testWidgets('reads in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(const YoureInView(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ابدئي اليوم 1'), findsOneWidget);
      expect(find.text('الانتقال إلى الرئيسية'), findsOneWidget);
    });
  });

  testWidgets('the coach link is for a coach only', (tester) async {
    await tester.pumpWidget(_host(const YoureInView(isCoach: false)));
    await tester.pumpAndSettle();
    expect(find.text("I'm a coach, set up my profile"), findsNothing);
  });
}
