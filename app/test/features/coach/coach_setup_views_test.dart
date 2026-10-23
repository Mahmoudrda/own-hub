// The coach's setup, one thing a screen, against the prototype.
//
// The steps that carry rules rather than layout are `K01` (rule 6 — blur
// defaults on, and showing her face is a named action with its consequence
// stated), `K02` (a certificate is picked from a verified list, never typed),
// `K11` and `K12` (a coach cannot author a client's result or words, so the
// steps show the shape with nothing invented in it) and `K13` (the three rules,
// agreed with one tick).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_credentials.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/payments.dart';
import 'package:own_hub/features/coach/presentation/coach_basics_view.dart';
import 'package:own_hub/features/coach/presentation/coach_being_checked_view.dart';
import 'package:own_hub/features/coach/presentation/coach_certificates_view.dart';
import 'package:own_hub/features/coach/presentation/coach_packages_view.dart';
import 'package:own_hub/features/coach/presentation/coach_how_you_coach_view.dart';
import 'package:own_hub/features/coach/presentation/coach_payout_view.dart';
import 'package:own_hub/features/coach/presentation/coach_photo_view.dart';
import 'package:own_hub/features/coach/presentation/coach_results_step_view.dart';
import 'package:own_hub/features/coach/presentation/coach_reviews_step_view.dart';
import 'package:own_hub/features/coach/presentation/coach_rules_view.dart';
import 'package:own_hub/features/coach/presentation/coach_specialties_view.dart';
import 'package:own_hub/features/coach/presentation/coach_view_models.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_step_bar.dart';
import 'package:own_hub/ui/app_toggle.dart';

final _issued = DateTime(2025, 11, 4);
final _now = DateTime(2026, 5, 20);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
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
    // A real generator, so a tap that navigates does not blow up the test with
    // an error that has nothing to do with what is being asserted.
    onGenerateRoute: AppRouter.onGenerateRoute,
    onUnknownRoute: AppRouter.onUnknownRoute,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

CoachSetupViewModel _model({
  CoachProfile profile = const CoachProfile(),
  CredentialCatalogue catalogue = CredentialCatalogue.unauthored,
  List<Certificate> certificates = const <Certificate>[],
  PayoutMethodState payout = const PayoutMethodState.unavailable(
    PaymentUnavailableReason.notImplemented,
  ),
}) => CoachSetupViewModel(
  profile: profile,
  catalogue: catalogue,
  certificates: certificates,
  payout: payout,
);

CertificateDraft _draft() => CertificateDraft.validate(
  catalogue: CredentialCatalogue.dictionaryBacked,
  credentialId: 'nasm_cpt',
  coachUid: 'coach-42',
  mediaRef: 'coach-docs/coach-42/a1',
  issuedAt: _issued,
)!;

void main() {
  group('the walk — one thing a screen, counted', () {
    final saved = AppRouter.featureFlags;
    tearDown(() => AppRouter.featureFlags = saved);

    test('eleven steps when her page is on, in her order', () {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.coachApp: true,
        Feature.coachPortfolio: true,
        Feature.coachResults: true,
        Feature.coachReviews: true,
        Feature.marketplace: true,
        Feature.payments: true,
      });
      expect(coachSetupWalk().map((s) => s.screenId), [
        'K01',
        'K08',
        'K03',
        'K10',
        'K04',
        'K11',
        'K12',
        'K02',
        'K13',
        'K05',
        'K06',
      ]);
      expect(CoachSetupStep.packages.next, CoachSetupStep.results);
    });

    test('results and reviews are skipped, and not counted, while her page '
        'is off', () {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.coachApp: true,
      });
      expect(coachSetupWalk(), isNot(contains(CoachSetupStep.results)));
      expect(coachSetupWalk(), isNot(contains(CoachSetupStep.reviews)));
      // Getting paid waits for payments, so K05 is not counted either.
      expect(coachSetupWalk(), isNot(contains(CoachSetupStep.payout)));
      expect(CoachSetupStep.total, 8);
      expect(CoachSetupStep.packages.next, CoachSetupStep.certificates);
    });
  });

  group('K01 — rule 6 is a named action with its consequence stated', () {
    testWidgets(
      'blur is on when she arrives, and the line says what that means',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_host(CoachPhotoView(model: _model())));
        await tester.pumpAndSettle();

        // The bar counts the walk, so it cannot disagree with the flow it is
        // counting, and the line under it fills to the same step.
        expect(find.text('1 of ${CoachSetupStep.total}'), findsOneWidget);
        expect(find.byType(AppStepBar), findsOneWidget);
        expect(find.text('Add a photo of you'), findsOneWidget);
        expect(find.text('Blur faces in my photos'), findsOneWidget);
        expect(find.text('Faces blurred before it uploads'), findsOneWidget);
        expect(
          find.text('Face visible. Clients pick a person, not a logo.'),
          findsNothing,
          reason:
              'The mockup writes this as an instruction under her photo. It is '
              'a consequence, and it belongs to the OFF position of the switch.',
        );
      },
    );

    testWidgets(
      'turning it off states the consequence rather than flipping quietly',
      (tester) async {
        _phone(tester);
        final model = _model();
        await tester.pumpWidget(_host(CoachPhotoView(model: model)));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(AppToggle));
        await tester.pumpAndSettle();

        expect(model.photoBlurred, isFalse);
        expect(
          find.text('Face visible. Clients pick a person, not a logo.'),
          findsOneWidget,
        );
        expect(find.text('Faces blurred before it uploads'), findsNothing);
      },
    );

    testWidgets('a photo is asked for, never demanded', (tester) async {
      _phone(tester);
      var continued = 0;
      await tester.pumpWidget(
        _host(CoachPhotoView(model: _model(), onContinue: () => continued++)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, 1);
    });

    testWidgets('the camera is offered only when there is one to open', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachPhotoView(model: _model())));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo'), findsNothing);

      final model = _model();
      await tester.pumpWidget(
        _host(CoachPhotoView(model: model, onTakePhoto: () async => null)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Take a photo'), findsOneWidget);
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      // She closed the camera: nothing is kept.
      expect(model.photo, isNull);
    });

    testWidgets('it renders in Arabic without English leaking through', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachPhotoView(model: _model()), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a photo of you'), findsNothing);
      expect(find.text('Blur faces in my photos'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('K08 — her name, her city and one line', () {
    testWidgets('Continue waits for a name and a city', (tester) async {
      _phone(tester);
      final model = _model();
      await tester.pumpWidget(_host(CoachBasicsView(model: model)));
      await tester.pumpAndSettle();

      expect(find.text('Tell clients who you are'), findsOneWidget);
      expect(model.canAdvanceFrom(CoachSetupStep.about), isFalse);

      await tester.enterText(find.byType(TextField).at(0), 'Hala Mansour');
      await tester.enterText(find.byType(TextField).at(1), 'Tanta');
      await tester.pumpAndSettle();

      expect(model.canAdvanceFrom(CoachSetupStep.about), isTrue);
      expect(model.displayName, 'Hala Mansour');
      expect(model.city, 'Tanta');
    });

    testWidgets('it asks nothing else: no photo, no switch, no rules', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachBasicsView(model: _model())));
      await tester.pumpAndSettle();
      expect(find.byType(AppToggle), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('and does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachBasicsView(model: _model()),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('K10 — languages and where her clients train, and nothing else', () {
    testWidgets('both chip groups, each tap kept', (tester) async {
      _phone(tester);
      final model = _model();
      await tester.pumpWidget(_host(CoachHowYouCoachView(model: model)));
      await tester.pumpAndSettle();
      expect(find.text('How you coach'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.tap(find.text('At home'));
      await tester.pumpAndSettle();
      expect(model.languages, contains(CoachLanguage.english));
      expect(model.clientPlaces, contains(ClientPlace.atHome));
    });
  });

  group(
    'K11 and K12 — the shape of what her clients give, nothing invented',
    () {
      testWidgets('K11 shows a before and an after with no figures and no '
          'upload', (tester) async {
        _phone(tester);
        await tester.pumpWidget(_host(const CoachResultsStepView()));
        await tester.pumpAndSettle();
        expect(find.text("Your clients' results"), findsOneWidget);
        expect(find.text('Before'), findsOneWidget);
        expect(find.text('After'), findsOneWidget);
        expect(
          find.textContaining(RegExp(r'\d')),
          findsNWidgets(1),
          reason: 'only the bar title carries a number',
        );
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('K12 shows the label and no words she did not write', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(_host(const CoachReviewsStepView()));
        await tester.pumpAndSettle();
        expect(find.text('What your clients say'), findsOneWidget);
        expect(find.text('Coached here'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      });
    },
  );

  group('K13 — the three rules, agreed with one tick', () {
    testWidgets('Continue waits for her agreement', (tester) async {
      _phone(tester);
      final model = _model();
      var continued = 0;
      await tester.pumpWidget(
        _host(CoachRulesView(model: model, onContinue: () => continued++)),
      );
      await tester.pumpAndSettle();
      expect(model.canAdvanceFrom(CoachSetupStep.rules), isFalse);
      await tester.tap(find.text('I agree to these three rules'));
      await tester.pumpAndSettle();
      expect(model.rulesAgreed, isTrue);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, 1);
    });
  });

  group('K02 — she picks from a verified list, and never types one', () {
    testWidgets('there is no text field on this screen at all', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachCertificatesView(
            model: _model(catalogue: CredentialCatalogue.dictionaryBacked),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'A coach cannot type a certificate she does not hold.',
      );
    });

    testWidgets('an unauthored list offers nothing, and says so', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachCertificatesView(model: _model(), now: _now)),
      );
      await tester.pumpAndSettle();

      expect(find.text('NASM CPT'), findsNothing);
      expect(find.text('Certificates'), findsOneWidget);
      // Once in the empty state, once in the sage note.
      expect(
        find.textContaining('unverified coaches cannot take clients'),
        findsNWidgets(2),
      );
    });

    testWidgets('the one credential the dictionary can name is offered', (
      tester,
    ) async {
      _phone(tester);
      var picked = '';
      await tester.pumpWidget(
        _host(
          CoachCertificatesView(
            model: _model(catalogue: CredentialCatalogue.dictionaryBacked),
            now: _now,
            onAddCertificate: (id) => picked = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NASM CPT'), findsOneWidget);
      expect(find.text('Add another certificate'), findsOneWidget);

      await tester.tap(find.text('NASM CPT'));
      await tester.pumpAndSettle();
      expect(picked, 'nasm_cpt');
    });

    testWidgets(
      'P0-CVER-05 — a queued certificate is never shown as uploaded',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            CoachCertificatesView(
              model: _model(
                catalogue: CredentialCatalogue.dictionaryBacked,
                certificates: [
                  Certificate.fromDraft(_draft(), id: 'c1', online: false),
                ],
              ),
              now: _now,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Waiting for signal'), findsOneWidget);
        expect(find.text('Checking'), findsNothing);
        expect(find.text('Uploaded · checking'), findsNothing);
      },
    );

    testWidgets('an uploaded one is being checked, and says that instead', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CoachCertificatesView(
            model: _model(
              catalogue: CredentialCatalogue.dictionaryBacked,
              certificates: [
                Certificate.fromDraft(_draft(), id: 'c1', online: true),
              ],
            ),
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checking'), findsOneWidget);
      expect(find.text('Uploaded · checking'), findsOneWidget);
      expect(find.text('Waiting for signal'), findsNothing);
    });
  });

  group('K03 — three specialties, no more', () {
    testWidgets('every option is visible at once', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachSpecialtiesView(model: _model())));
      await tester.pumpAndSettle();

      expect(find.text('What do you coach?'), findsOneWidget);
      for (final label in [
        'Postpartum',
        'Beginners',
        'Strength',
        'Weight loss',
        'Pregnancy',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // One question: where her clients train is the next screen (K10).
      expect(find.text('Where your clients train'), findsNothing);
    });

    testWidgets('the fourth tap does nothing', (tester) async {
      _phone(tester);
      final model = _model();
      await tester.pumpWidget(_host(CoachSpecialtiesView(model: model)));
      await tester.pumpAndSettle();

      for (final label in ['Postpartum', 'Beginners', 'Strength']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(model.specialties, hasLength(3));

      await tester.tap(find.text('Pregnancy'));
      await tester.pumpAndSettle();

      expect(model.specialties, hasLength(3));
      expect(model.specialties.contains(Specialty.pregnancy), isFalse);
    });
  });

  group('K04 — her capacity, and no offers without a rail', () {
    testWidgets('it asks, and nothing answers for her', (tester) async {
      _phone(tester);
      final model = _model();
      await tester.pumpWidget(_host(CoachPackagesView(model: model)));
      await tester.pumpAndSettle();

      expect(find.text('How many clients can you take?'), findsOneWidget);
      expect(find.text('Clients at once'), findsOneWidget);
      expect(find.text('You keep 80%'), findsOneWidget);
      expect(
        find.text('20'),
        findsNothing,
        reason: "Twenty is the prototype's sample, not her answer.",
      );
      expect(model.capacityMax, isNull);
    });

    testWidgets('a number inside the range is taken; one above it is not', (
      tester,
    ) async {
      _phone(tester);
      final model = _model();
      await tester.pumpWidget(_host(CoachPackagesView(model: model)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '14');
      await tester.pumpAndSettle();
      expect(model.capacityMax, 14);

      await tester.enterText(find.byType(TextField), '90');
      await tester.pumpAndSettle();
      expect(model.capacityMax, isNull);
      expect(find.text('1 to 60'), findsOneWidget);
    });

    testWidgets('with payments dark there is no offers section', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachPackagesView(model: _model())));
      await tester.pumpAndSettle();

      expect(find.text('Add another offer'), findsNothing);
      expect(find.text('Packages'), findsNothing);
      expect(find.textContaining('You will write your offers'), findsOneWidget);
    });
  });

  group('K05 — it cannot be completed, and does not pretend to be', () {
    testWidgets('with no rail it shows what stays true instead', (
      tester,
    ) async {
      _phone(tester);
      final model = _model();
      await tester.pumpWidget(_host(CoachPayoutView(model: model)));
      await tester.pumpAndSettle();

      expect(find.text('Where should we send your money?'), findsOneWidget);
      expect(find.text('Payout method'), findsOneWidget);
      expect(
        find.textContaining('The first payout lands on the 1st'),
        findsOneWidget,
      );
      expect(
        find.text('Mobile wallet'),
        findsNothing,
        reason:
            'Offering a choice the rail cannot store would be a screen '
            'claiming to have saved her wallet.',
      );
      expect(model.canAdvanceFrom(CoachSetupStep.payout), isFalse);
    });

    testWidgets("and never shows the prototype's sample wallet number", (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(CoachPayoutView(model: _model())));
      await tester.pumpAndSettle();

      expect(find.textContaining('010 xxx xx32'), findsNothing);
      expect(
        find.textContaining('never show your wallet number'),
        findsOneWidget,
      );
    });
  });

  group('K06 — waiting is not a dead end', () {
    testWidgets('it states the check and offers real work', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CoachBeingCheckedView(
            verification: CoachVerificationState.docsChecking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The last step of the walk, whatever the walk's length.
      expect(
        find.text('${CoachSetupStep.total} of ${CoachSetupStep.total}'),
        findsOneWidget,
      );
      expect(find.text("We're checking your certificates"), findsOneWidget);
      expect(find.text('You can start now'), findsOneWidget);
      expect(
        find.textContaining('so your first client gets it on day one'),
        findsOneWidget,
      );
      expect(find.text('Build my first plan'), findsOneWidget);
      expect(find.text('See my Today'), findsOneWidget);
    });

    testWidgets('a cleared coach is told her page is live', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CoachBeingCheckedView(
            verification: CoachVerificationState.verified,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Certificates checked'), findsOneWidget);
      expect(
        find.text('Your page is visible and you can take clients.'),
        findsOneWidget,
      );
      expect(
        find.text('You can start now'),
        findsNothing,
        reason: 'She has started. The waiting card belongs to the wait.',
      );
    });

    testWidgets(
      'a refused certificate offers the replace path, not an accusation',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            const CoachBeingCheckedView(
              verification: CoachVerificationState.rejected,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add another certificate'), findsOneWidget);
        expect(find.text('Build my first plan'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('it holds together at the largest text size', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CoachBeingCheckedView(
            verification: CoachVerificationState.submitted,
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
