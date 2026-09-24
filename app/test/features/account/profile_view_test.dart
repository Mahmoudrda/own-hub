// A02 — Profile and settings, and the allergy capture surface D3 requires.
//
// The capture surface is the point: until it exists, AppRouter.eatConstraints is
// DietaryConstraints.none — a claim that every woman was asked and named nothing
// — and P0-EAT-01 cannot pass. These tests drive the real editor and assert the
// value that reaches the Eat guard.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/account/domain/verification_claim.dart';
import 'package:own_hub/features/account/presentation/profile_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

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
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

void main() {
  // The "My coach" row opens the directory, and two subtitles describe a
  // community. Both named rather than borrowed from the defaults.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.community: true,
      Feature.marketplace: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('the allergy row exists at all', () {
    testWidgets('A02 carries the row D3 requires', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(dietaryRepository: InMemoryDietaryProfileRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allergies and dietary preferences'), findsOneWidget);
      expect(find.text('Anything you cannot eat'), findsOneWidget);
    });

    testWidgets('tapping it opens the editor with the authored vocabulary', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(dietaryRepository: InMemoryDietaryProfileRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allergies and dietary preferences'));
      await tester.pumpAndSettle();

      // Exactly G17's four allergens. Nothing invented.
      expect(find.text('No nuts'), findsOneWidget);
      expect(find.text('No dairy'), findsOneWidget);
      expect(find.text('No gluten'), findsOneWidget);
      expect(find.text('No shellfish'), findsOneWidget);
      expect(find.text('How you usually eat'), findsOneWidget);

      // A branch of A02, not a route (HANDOFF rule 16), and not a dialog.
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('what she names reaches the Eat guard', () {
    testWidgets('naming an allergy writes profile.allergies and nothing else', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryDietaryProfileRepository();

      await tester.pumpWidget(
        _host(ProfileView(dietaryRepository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allergies and dietary preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No nuts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.read().allergies, {AllergenTag.nuts});
      expect(repository.writes, [
        {'profile.allergies', 'profile.dietary'},
      ], reason: 'G7 hosts the row; G2 writes the field, by field path');

      // The value the Eat feature consumes.
      expect(repository.read().toConstraints().allergies, {'nuts'});
    });

    testWidgets('saving with nothing selected is a real answer, not a no-op', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryDietaryProfileRepository();

      // Before: nobody has asked her, so the guard must fail closed.
      expect(repository.read().asked, isFalse);
      expect(repository.read().toConstraints().allergies, isNull);

      await tester.pumpWidget(
        _host(ProfileView(dietaryRepository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allergies and dietary preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // After: she was asked and named nothing. This is the ONLY way `none`
      // becomes true of somebody, and it is what the router currently asserts
      // about every woman in the product.
      expect(repository.read().asked, isTrue);
      expect(repository.read().allergies, isEmpty);
      expect(repository.read().toConstraints().allergies, isEmpty);
    });

    testWidgets('an existing answer is shown back and is editable', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryDietaryProfileRepository(
        const DietaryProfile(
          allergies: {AllergenTag.dairy},
          dietary: {DietaryTag.vegetarianWeekdays},
        ),
      );

      await tester.pumpWidget(
        _host(ProfileView(dietaryRepository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allergies and dietary preferences'));
      await tester.pumpAndSettle();

      // D3 — editable forever. She adds gluten to the dairy already there.
      await tester.tap(find.text('No gluten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.read().allergies, {
        AllergenTag.dairy,
        AllergenTag.gluten,
      });
      expect(repository.read().dietary, {DietaryTag.vegetarianWeekdays});
    });
  });

  group('numbers this screen must not state', () {
    testWidgets('no tier and no level anywhere', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(
            dietaryRepository: InMemoryDietaryProfileRepository(),
            firstName: 'Nadia',
            verification: VerificationRecord(decidedAt: DateTime(2026, 7, 3)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // DECISIONS.md D6: "Until written here, no tier number is authoritative."
      // PHASE1-FIXES.md §13 records T05 shipping exactly these.
      expect(find.textContaining('level 7'), findsNothing);
      expect(find.textContaining('Regular'), findsNothing);
      expect(find.text('Verified woman · Regular · level 7'), findsNothing);
    });

    testWidgets('her own name is rendered; the mockup\'s is not', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(
            dietaryRepository: InMemoryDietaryProfileRepository(),
            firstName: 'Nadia',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nadia'), findsOneWidget);
      expect(find.text('Mai Farouk'), findsNothing);
    });

    testWidgets('no coach or cycle detail is invented for a woman with none', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(dietaryRepository: InMemoryDietaryProfileRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My coach'), findsOneWidget);
      expect(find.text('Sara Hany · day 9 of 30'), findsNothing);
      expect(find.text('Period day 2 · symptom tracking'), findsNothing);
    });
  });

  group('P2-RTL-A02 and P2-TXT-A02', () {
    testWidgets('Arabic renders right-to-left', (tester) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(
            dietaryRepository: InMemoryDietaryProfileRepository(),
            firstName: 'نادية',
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('نادية'))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the editor holds up in Arabic at the largest text size', (
      tester,
    ) async {
      _phone(tester);

      await tester.pumpWidget(
        _host(
          ProfileView(dietaryRepository: InMemoryDietaryProfileRepository()),
          locale: const Locale('ar'),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
