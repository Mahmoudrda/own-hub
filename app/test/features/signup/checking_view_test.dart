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
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';

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
    expect(find.text('Both sides of your card taken'), findsOneWidget);
    expect(find.text('Selfie taken'), findsOneWidget);
    expect(find.text('Matching your selfie to your card'), findsOneWidget);
  });

  // The judge's first blocker: a live Continue on this screen opened "You're
  // in" before any verdict existed.
  testWidgets('there is no button while the check runs', (tester) async {
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

    expect(find.byType(AppButton), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('after 20 seconds it says the check is slow, and waits', (
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
    await tester.pump();
    expect(find.byKey(const ValueKey('checking-slow')), findsNothing);

    await tester.pump(const Duration(seconds: 19));
    expect(find.byKey(const ValueKey('checking-slow')), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text(
        'Taking longer than usual. Your connection may be slow. '
        'You can keep waiting here.',
      ),
      findsOneWidget,
    );
    // Nothing wired, so still no way forward but the verdict.
    expect(find.byType(AppButton), findsNothing);
  });

  // The judge's 'Ask a woman reviewer' and 'Try again', once the check is
  // slow and never before: neither claims a verdict.
  testWidgets('after 20 seconds she may ask a woman reviewer or try again', (
    tester,
  ) async {
    var asked = 0;
    var askedWhileChecking = 0;
    var retried = 0;
    var retaken = 0;
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
          onAskForReviewer: () => asked++,
          onAskForReviewerWhileChecking: () => askedWhileChecking++,
          onTryAgain: () => retried++,
          onRetake: () => retaken++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(find.byKey(const ValueKey('checking-ask-reviewer')), findsNothing);
    expect(find.byKey(const ValueKey('checking-try-again')), findsNothing);
    expect(find.byType(AppButton), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ask for a woman reviewer'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('checking-ask-reviewer')));
    await tester.tap(find.byKey(const ValueKey('checking-try-again')));
    expect(askedWhileChecking, 1);
    expect(retried, 1);
    expect(asked, 0, reason: 'the slow button is told apart from a stop');
    expect(retaken, 0, reason: 'trying again is her choice, not a verdict');
  });

  testWidgets('the slow buttons fall back to the plain callbacks', (
    tester,
  ) async {
    var asked = 0;
    var retaken = 0;
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
          onAskForReviewer: () => asked++,
          onRetake: () => retaken++,
        ),
      ),
    );
    await tester.pump(CheckingView.slowAfter);
    await tester.tap(find.byKey(const ValueKey('checking-ask-reviewer')));
    await tester.tap(find.byKey(const ValueKey('checking-try-again')));
    expect((asked, retaken), (1, 1));
  });

  testWidgets('the slow buttons in Arabic', (tester) async {
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
          onAskForReviewer: () {},
          onRetake: () {},
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump(CheckingView.slowAfter);
    expect(find.text('اطلبي مراجِعة'), findsOneWidget);
    expect(find.text('جرّبي تاني'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a verdict after the slow line still routes', (tester) async {
    final repository = FakeVerificationRepository(
      const VerificationState.checking(),
    );
    var verified = 0;
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: repository,
          onVerified: (_) => verified++,
          onAskForReviewer: () {},
        ),
      ),
    );
    await tester.pump(CheckingView.slowAfter);
    repository.decide(_verified());
    await tester.pumpAndSettle();
    expect(verified, 1);
  });

  testWidgets('the back gesture cannot leave a running check', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(body: Text('camera')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CheckingView(
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final popped = await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(popped, isTrue, reason: 'the pop was asked for and refused');
    expect(find.text('Checking your card'), findsWidgets);
    expect(find.text('camera'), findsNothing);
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

    expect(find.text('بنراجع بطاقتك'), findsWidgets);
    expect(find.text('اتصوّرت بطاقتك من الناحيتين'), findsOneWidget);
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

  group('stops told on this screen, never a review', () {
    Future<FakeVerificationRepository> showStop(
      WidgetTester tester,
      VerificationState stop, {
      VoidCallback? onAwaitingReviewer,
      VoidCallback? onRetake,
      VoidCallback? onAskForReviewer,
      VoidCallback? onClose,
    }) async {
      final repository = FakeVerificationRepository();
      await tester.pumpWidget(
        _host(
          CheckingView(
            repository: repository,
            onAwaitingReviewer: onAwaitingReviewer,
            onRetake: onRetake,
            onAskForReviewer: onAskForReviewer,
            onClose: onClose,
          ),
        ),
      );
      repository.decide(stop);
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('a connection too slow says so, asks nobody, and offers the '
        'retake as her own choice', (tester) async {
      var reviews = 0;
      var retakes = 0;
      var tryAgains = 0;
      final repository = FakeVerificationRepository();
      await tester.pumpWidget(
        _host(
          CheckingView(
            repository: repository,
            onAwaitingReviewer: () => reviews++,
            onRetake: () => retakes++,
            onTryAgain: () => tryAgains++,
          ),
        ),
      );
      repository.decide(const VerificationState.tooSlow());
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(tester.element(find.byType(CheckingView)));
      expect(find.text(l10n.yourConnectionIsTooSlow), findsOneWidget);
      expect(find.text(l10n.weCouldNotFinishTheCheckIn), findsOneWidget);
      expect(reviews, 0);
      expect(
        retakes,
        0,
        reason: 'a stop is not a verdict, so nothing recorded',
      );

      await tester.tap(find.text('Try again'));
      expect(tryAgains, 1);
      expect(retakes, 0);
    });

    testWidgets('a daily limit says try again tomorrow', (tester) async {
      var reviews = 0;
      var closes = 0;
      await showStop(
        tester,
        const VerificationState.tryTomorrow(),
        onAwaitingReviewer: () => reviews++,
        onClose: () => closes++,
      );
      expect(find.text('Try again tomorrow'), findsOneWidget);
      expect(reviews, 0);
      await tester.tap(find.text('Close'));
      expect(closes, 1);
    });

    testWidgets('used-up checks offer a reviewer only if she asks', (
      tester,
    ) async {
      var reviews = 0;
      var asked = 0;
      await showStop(
        tester,
        const VerificationState.checksUsedUp(),
        onAwaitingReviewer: () => reviews++,
        onAskForReviewer: () => asked++,
      );
      expect(find.text('No automatic checks left'), findsOneWidget);
      expect(reviews, 0);
      await tester.tap(find.text('Ask for a woman reviewer'));
      expect(asked, 1);
    });

    testWidgets('unreachable says nothing was decided, and retries', (
      tester,
    ) async {
      var retries = 0;
      await showStop(
        tester,
        const VerificationState.unreachable(),
        onRetake: () => retries++,
      );
      expect(find.text('We could not reach Own Hub'), findsOneWidget);
      expect(find.textContaining('Nothing was decided'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('a refused copy of the app is told to update', (tester) async {
      var reviews = 0;
      await showStop(
        tester,
        const VerificationState.appCannotReach(),
        onAwaitingReviewer: () => reviews++,
        onClose: () {},
      );
      expect(
        find.text('This copy of the app cannot reach Own Hub'),
        findsOneWidget,
      );
      expect(reviews, 0);
    });

    testWidgets('a refusal goes to the screen that says so', (tester) async {
      var rejected = 0;
      final repository = FakeVerificationRepository();
      await tester.pumpWidget(
        _host(
          CheckingView(repository: repository, onRejected: () => rejected++),
        ),
      );
      repository.decide(const VerificationState.rejected());
      await tester.pumpAndSettle();
      expect(rejected, 1);
    });
  });

  testWidgets('G16: the done steps tick, and matching never does', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CheckingView(
          reassuringSteps: true,
          repository: FakeVerificationRepository(
            const VerificationState.checking(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('checking-steps')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    // Two ticks for the two steps that happened on the screens before; the
    // match stays waiting in pencil.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('checking-steps')),
        matching: find.byIcon(Icons.autorenew),
      ),
      findsOneWidget,
    );
    expect(find.text('Matching your selfie to your card'), findsOneWidget);
  });

  testWidgets('G16: the verdict is never held back by the steps', (
    tester,
  ) async {
    var approved = 0;
    final repository = FakeVerificationRepository(
      const VerificationState.checking(),
    );
    await tester.pumpWidget(
      _host(
        CheckingView(
          reassuringSteps: true,
          repository: repository,
          onVerified: (_) => approved++,
        ),
      ),
    );
    // Decided while the steps are still ticking: it still routes at once.
    await tester.pump(const Duration(milliseconds: 100));
    repository.decide(_verified());
    await tester.pumpAndSettle();
    expect(approved, 1);
  });

  group('the kitten', () {
    setUp(Kitten.resetPlayed);

    KittenPose pose(WidgetTester tester) =>
        tester.widget<Kitten>(find.byType(Kitten)).pose;

    testWidgets('thinks while the card is read, points while it is matched', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CheckingView(
            repository: FakeVerificationRepository(
              const VerificationState.checking(),
            ),
            reassuringSteps: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Kitten), findsOneWidget);
      expect(pose(tester), KittenPose.think);
      await tester.pumpAndSettle();
      expect(find.byType(Kitten), findsOneWidget);
      expect(pose(tester), KittenPose.point);
    });

    testWidgets('gives a light cheer when the check is done', (tester) async {
      final repository = FakeVerificationRepository(
        const VerificationState.checking(),
      );
      await tester.pumpWidget(
        _host(
          CheckingView(
            repository: repository,
            reassuringSteps: true,
            onVerified: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.decide(_verified());
      await tester.pump();
      await tester.pump();
      expect(find.byType(Kitten), findsOneWidget);
      expect(pose(tester), KittenPose.cheer);
      await tester.pumpAndSettle();
    });

    testWidgets('is not there on the stops that say it could not finish', (
      tester,
    ) async {
      for (final stop in const [
        VerificationState.tryTomorrow(),
        VerificationState.checksUsedUp(),
        VerificationState.tooSlow(),
        VerificationState.unreachable(),
      ]) {
        await tester.pumpWidget(
          _host(
            CheckingView(
              key: UniqueKey(),
              repository: FakeVerificationRepository(stop),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Kitten), findsNothing, reason: '$stop');
      }
    });
  });
}
