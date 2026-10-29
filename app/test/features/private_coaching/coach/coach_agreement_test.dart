import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_agreement.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_photo.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_agreement_card.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import 'coach_fake.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

CoachProfile _me() => const CoachProfile(
  uid: 'me',
  displayName: 'Coach Sara',
  headline: 'Strength coach for busy women',
  approach: 'I build a simple plan around your week.',
  published: true,
  acceptingClients: true,
);

CoachRepo _repo(CoachAgreement? agreement) => CoachRepo()
  ..coaches.value = [_me()]
  ..coachPrivate.value = CoachPrivateSummary(agreement: agreement);

Future<List<String>> _open(
  WidgetTester tester,
  CoachRepo repo, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(
    _host(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 3600))
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: CoachSpaceView(
          repository: repo,
          onOpenLink: opened.add,
          imageChooser: (_) async => CoachImage(Uint8List.fromList([1, 2, 3])),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

AppL10n _l10n(WidgetTester tester) =>
    AppL10n.of(tester.element(find.byType(CoachSpaceView)));

const _accepted = CoachAgreement(version: 2, status: AgreementStatus.accepted);

void main() {
  testWidgets('version one or no record: read and accept first', (
    tester,
  ) async {
    for (final agreement in <CoachAgreement?>[
      null,
      const CoachAgreement(version: 1, status: AgreementStatus.verified),
    ]) {
      final repo = _repo(agreement);
      await _open(tester, repo);
      final l10n = _l10n(tester);
      expect(find.text(l10n.yourSignedAgreement), findsOneWidget);
      expect(find.text(l10n.readTheNewCoachAgreementAndAccept), findsOneWidget);
      expect(find.byKey(const ValueKey('agreement-accept')), findsOneWidget);
      expect(find.byKey(const ValueKey('agreement-upload')), findsNothing);
    }
  });

  testWidgets('the gate sheet needs the tick, then accepts in her language', (
    tester,
  ) async {
    final repo = _repo(null);
    final opened = await _open(tester, repo, locale: const Locale('ar'));
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const ValueKey('agreement-accept')));
    await tester.pumpAndSettle();

    // The points are the agreement's, with the numbers filled in.
    expect(
      find.text(
        l10n.payOwnHubItsShareWithinDays(
          '${CoachAgreementFacts.payWithinDays}',
          '${CoachAgreementFacts.holdAfterDays}',
        ),
      ),
      findsOneWidget,
    );
    final accept = find.byKey(const ValueKey('agreement-sheet-accept'));
    await tester.tap(accept, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.callNames, isNot(contains('acceptCoachTerms')));

    await tester.tap(find.text(l10n.iHaveReadTheCoachAgreementAnd_egtgj));
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'acceptCoachTerms').single.$2, {
      'locale': 'ar',
    });
    expect(opened, isEmpty);
  });

  testWidgets(
    'accepted: download, print and upload a photo of the signed page',
    (tester) async {
      final repo = _repo(_accepted);
      final opened = await _open(tester, repo);
      final l10n = _l10n(tester);
      expect(find.text(l10n.printTheAgreementAndSignItBy), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agreement-read')));
      await tester.tap(find.byKey(const ValueKey('agreement-pdf')));
      expect(opened, [
        'https://own-hub.app/coach-agreement',
        'https://own-hub.app/coach-agreement.pdf',
      ]);

      await tester.tap(find.byKey(const ValueKey('agreement-upload')));
      await tester.pumpAndSettle();
      expect(repo.uploads, ['agreement:image/jpeg']);
      final sent = repo.calls.where((c) => c.$1 == 'submitCoachAgreement');
      expect(sent.single.$2, {'path': 'coach-docs/me/agreement/f1.jpg'});
      expect(find.text(l10n.yourSignedCopyWasSentOwnHub), findsOneWidget);
    },
  );

  testWidgets('the Arabic page links are the Arabic ones', (tester) async {
    final repo = _repo(_accepted);
    final opened = await _open(tester, repo, locale: const Locale('ar'));
    await tester.tap(find.byKey(const ValueKey('agreement-read')));
    await tester.tap(find.byKey(const ValueKey('agreement-pdf')));
    expect(opened, [
      'https://own-hub.app/ar/coach-agreement',
      'https://own-hub.app/ar/coach-agreement.pdf',
    ]);
  });

  testWidgets('waiting: no upload button, just the status', (tester) async {
    final repo = _repo(
      const CoachAgreement(version: 2, status: AgreementStatus.uploaded),
    );
    await _open(tester, repo);
    final l10n = _l10n(tester);
    expect(find.text(l10n.ownHubIsCheckingYourSignedCopy), findsOneWidget);
    expect(find.byKey(const ValueKey('agreement-upload')), findsNothing);
    expect(find.byKey(const ValueKey('agreement-accept')), findsNothing);
  });

  testWidgets('needs a new copy: the reason, and a way to upload again', (
    tester,
  ) async {
    final repo = _repo(
      const CoachAgreement(
        version: 2,
        status: AgreementStatus.rejected,
        reason: 'The signature is cut off.',
      ),
    );
    await _open(tester, repo);
    final l10n = _l10n(tester);
    expect(
      find.text(l10n.ownHubNeedsANewSignedCopy('The signature is cut off.')),
      findsOneWidget,
    );
    expect(find.text(l10n.uploadANewCopy), findsOneWidget);
  });

  testWidgets('verified: done, nothing left to press', (tester) async {
    final repo = _repo(
      const CoachAgreement(version: 2, status: AgreementStatus.verified),
    );
    await _open(tester, repo);
    final l10n = _l10n(tester);
    expect(find.text(l10n.yourSignedAgreementIsVerifiedYouCan), findsOneWidget);
    expect(find.byKey(const ValueKey('agreement-upload')), findsNothing);
    expect(find.byKey(const ValueKey('agreement-accept')), findsNothing);
  });

  testWidgets('the agreement button is tonal while something more urgent is filled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<AppButtonVariant> variantOf({required bool urgent}) async {
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: SingleChildScrollView(
              child: CoachAgreementCard(
                key: UniqueKey(),
                repository: _repo(_accepted),
                agreement: _accepted,
                imageChooser: (_) async => null,
                urgent: urgent,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<AppButton>(find.byKey(const ValueKey('agreement-upload')))
          .variant;
    }

    expect(await variantOf(urgent: true), AppButtonVariant.filled);
    expect(await variantOf(urgent: false), AppButtonVariant.tonal);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'every state fits at text scale 2.0 in ${locale.languageCode}',
      (tester) async {
        for (final agreement in <CoachAgreement?>[
          null,
          _accepted,
          const CoachAgreement(version: 2, status: AgreementStatus.uploaded),
          const CoachAgreement(
            version: 2,
            status: AgreementStatus.rejected,
            reason: 'The signature is cut off.',
          ),
        ]) {
          await _open(tester, _repo(agreement), locale: locale, scale: 2);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
