// C12 — Checking your card.
//
// Progress named step by step, so a slow network reads as slow rather than as a
// refusal. The assertions that matter are about where the three outcomes go:
// verified moves her on, and **both** of the other two land on a woman reviewer.
//
// That second one is DECISIONS.md D8 expressed as routing. A check that could
// not be decided and a check that failed are the same destination and the same
// tone — we are reviewing your application to keep this community safe and
// private. Neither is an accusation and neither is a dead end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/domain/verification_fake.dart';
import 'package:own_hub/features/signup/presentation/checking_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
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

/// A pass that took a measurable 31 seconds.
///
/// Timed deliberately: C13 states the duration, and it can only do that if the
/// result carries one all the way from the check that produced it.
VerificationState _verified() => VerificationState.verified(
  VerificationResult(
    method: VerificationMethod.automatic,
    startedAt: DateTime(2026, 9, 18, 12, 0, 0),
    decidedAt: DateTime(2026, 9, 18, 12, 0, 31),
    imagesDeletedAt: DateTime(2026, 9, 18),
  ),
);

void main() {
  testWidgets('names each step instead of showing a bare spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checking your card'), findsWidgets);
    expect(find.text('Card read'), findsOneWidget);
    expect(find.text('Selfie matched to the card'), findsOneWidget);
    expect(find.text('Final check'), findsOneWidget);
  });

  testWidgets('promises the woman reviewer before it is needed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('a woman reviewer takes it from here'),
      findsOneWidget,
    );
  });

  testWidgets('a pass moves her on', (tester) async {
    final repository = FakeVerificationRepository(
      const VerificationState.checking(),
    );
    var verified = 0;
    await tester.pumpWidget(
      _host(
        CheckingView(repository: repository, onVerified: (_) => verified++),
      ),
    );
    await tester.pumpAndSettle();

    repository.decide(_verified());
    await tester.pumpAndSettle();

    expect(verified, 1);
  });

  testWidgets('an undecided check goes to a reviewer, not to a rejection', (
    tester,
  ) async {
    final repository = FakeVerificationRepository(
      const VerificationState.checking(),
    );
    var reviewer = 0;
    var verified = 0;
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: repository,
          onVerified: (_) => verified++,
          onAwaitingReviewer: () => reviewer++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.decide(const VerificationState.awaitingReviewer());
    await tester.pumpAndSettle();

    expect(reviewer, 1);
    expect(verified, 0);
  });

  testWidgets(
    'D8 — "needs another look" lands in the same place, not a refusal',
    (tester) async {
      // The state the owner named: she is told we are reviewing her application,
      // and she is routed to a person. If this ever gained a destination of its
      // own, the screen would have become a rejection notice.
      final repository = FakeVerificationRepository(
        const VerificationState.checking(),
      );
      var reviewer = 0;
      await tester.pumpWidget(
        _host(
          CheckingView(
            repository: repository,
            onAwaitingReviewer: () => reviewer++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      repository.decide(const VerificationState.needsAnotherLook());
      await tester.pumpAndSettle();

      expect(reviewer, 1);
    },
  );

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('نراجع بطاقتك'), findsWidgets);
    expect(find.text('قُرئت البطاقة'), findsOneWidget);
    expect(find.text('Checking your card'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
        ),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
