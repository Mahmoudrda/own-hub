// C08 — Which one are you?
//
// Three answers since D11: train, coach, or both. The assertions that matter
// are that training is the default — most women here are here to train, and
// coach onboarding is a longer path that should not be the one you fall into —
// that the choice actually travels with Continue, because the answers lead to
// different products, and that the screen no longer tells her the decision is
// permanent.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/features/signup/presentation/role_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

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

AppCard _cardBehind(WidgetTester tester, String label) =>
    tester.widget<AppCard>(
      find.ancestor(of: find.text(label), matching: find.byType(AppCard)).first,
    );

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

  testWidgets('offers all three, and says what each one is', (tester) async {
    await tester.pumpWidget(_host(const RoleView()));
    await tester.pumpAndSettle();

    expect(find.text('Which one are you?'), findsOneWidget);
    expect(find.text("I'm here to train"), findsOneWidget);
    expect(
      find.text('Workouts, recipes and the community. Free.'),
      findsOneWidget,
    );
    expect(find.text('I coach women'), findsOneWidget);
    expect(find.textContaining('keep 80%'), findsOneWidget);
    expect(find.text('I train and I coach'), findsOneWidget);
    expect(find.textContaining('Switch between them'), findsOneWidget);
  });

  testWidgets('the choice is no longer presented as permanent', (tester) async {
    await tester.pumpWidget(_host(const RoleView()));
    await tester.pumpAndSettle();

    // D11: this is hers to change, so the copy must stop sending her to
    // support for it. Asserted because it is the kind of sentence that
    // survives a design change by nobody noticing it.
    expect(
      find.text('You can change this later in your profile.'),
      findsOneWidget,
    );
    expect(find.textContaining('messaging us'), findsNothing);
  });

  testWidgets('training is preselected', (tester) async {
    await tester.pumpWidget(_host(const RoleView()));
    await tester.pumpAndSettle();

    expect(
      _cardBehind(tester, "I'm here to train").variant,
      AppCardVariant.selected,
    );
    expect(
      _cardBehind(tester, 'I coach women').variant,
      AppCardVariant.outlined,
    );
    expect(
      _cardBehind(tester, 'I train and I coach').variant,
      AppCardVariant.outlined,
    );
  });

  testWidgets('choosing another option moves the selection', (tester) async {
    await tester.pumpWidget(_host(const RoleView()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I train and I coach'));
    await tester.pumpAndSettle();

    expect(
      _cardBehind(tester, 'I train and I coach').variant,
      AppCardVariant.selected,
    );
    expect(
      _cardBehind(tester, "I'm here to train").variant,
      AppCardVariant.outlined,
    );
    expect(
      _cardBehind(tester, 'I coach women').variant,
      AppCardVariant.outlined,
    );
  });

  testWidgets('Continue carries the answer, because the paths differ', (
    tester,
  ) async {
    final chosen = <SignupRole>[];
    await tester.pumpWidget(_host(RoleView(onContinue: chosen.add)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(chosen, [SignupRole.trainee]);

    await tester.tap(find.text('I coach women'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(chosen, [SignupRole.trainee, SignupRole.coach]);

    await tester.tap(find.text('I train and I coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(chosen, [SignupRole.trainee, SignupRole.coach, SignupRole.both]);
  });

  group('the choice maps onto the roles the app runs on', () {
    test('each answer produces the roles it promises', () {
      expect(SignupRole.trainee.toRoles(), UserRoles.trainee);
      expect(SignupRole.coach.toRoles(), UserRoles.coach);
      expect(SignupRole.both.toRoles(), UserRoles.both);
    });

    test('only "both" can switch', () {
      expect(SignupRole.trainee.toRoles().canSwitch, isFalse);
      expect(SignupRole.coach.toRoles().canSwitch, isFalse);
      expect(SignupRole.both.toRoles().canSwitch, isTrue);
    });

    test('"both" opens on the trainee side', () {
      // Coaching is work. She should choose to open it rather than land in it.
      expect(SignupRole.both.toRoles().active, AppRole.trainee);
    });

    test('anything involving coaching needs the application', () {
      expect(SignupRole.trainee.needsCoachApplication, isFalse);
      expect(SignupRole.coach.needsCoachApplication, isTrue);
      expect(SignupRole.both.needsCoachApplication, isTrue);
    });
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const RoleView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('أيّهما أنتِ؟'), findsOneWidget);
    expect(find.text('أنا هنا لأتدرّب'), findsOneWidget);
    expect(find.text('أنا أدرّب النساء'), findsOneWidget);
    expect(find.text('أتدرّب وأدرّب'), findsOneWidget);
    expect(find.text('Which one are you?'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    // Three cards now, not two, and Arabic runs longer than English.
    await tester.pumpWidget(
      _host(const RoleView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('while the coach app is off', () {
    testWidgets('only the trainee answer is offered', (tester) async {
      await tester.pumpWidget(_host(const RoleView(offerCoach: false)));
      await tester.pumpAndSettle();

      expect(find.text("I'm here to train"), findsOneWidget);
      expect(find.text('I coach women'), findsNothing);
      expect(find.text('I train and I coach'), findsNothing);
    });

    testWidgets('Continue sends trainee, whatever was preselected', (
      tester,
    ) async {
      final chosen = <SignupRole>[];
      await tester.pumpWidget(
        _host(
          RoleView(
            offerCoach: false,
            initialRole: SignupRole.both,
            onContinue: chosen.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(chosen, <SignupRole>[SignupRole.trainee]);
    });
  });

  test('the router offers the coach answers only when the coach app is on', () {
    final router = File('lib/routing/app_router.dart').readAsStringSync();
    final c08 = router.substring(
      router.indexOf("'C08': (context) => RoleView("),
    );
    expect(
      c08.substring(0, c08.indexOf('onContinue')),
      contains('offerCoach: featureFlags.isOn(Feature.coachApp)'),
    );
  });
}
