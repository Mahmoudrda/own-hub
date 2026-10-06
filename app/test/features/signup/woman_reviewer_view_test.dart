// C15 — Checked by a woman, no photo kept.
//
// The niqab path, and P0-VER-05: **no selfie is requested at any point.** The
// view does not import the capture layer at all, so there is no code path from
// here to C11. What it does now is call `request_review` with the path she came
// by, and move on only when the server has queued her: a failed call says so
// and leaves the button live as a retry (S3).
//
// The rest is ordinary but load-bearing copy: only women review these checks,
// nothing is recorded, and the ID card does the same work it does everywhere
// else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/presentation/woman_reviewer_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

class _Requester implements ReviewRequester {
  _Requester(this._answers);

  /// A state to return or an error to throw, per call.
  final List<Object> _answers;
  final List<ReviewPath> asked = <ReviewPath>[];

  @override
  Future<ReviewRequestState> request(ReviewPath path) async {
    asked.add(path);
    final next = _answers.removeAt(0);
    if (next is ReviewRequestState) return next;
    throw next;
  }
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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets(
    'offers a check with a woman, no video call, and no partner gyms that do not exist',
    (tester) async {
      await tester.pumpWidget(
        _host(WomanReviewerView(requester: _Requester(<Object>[]))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checked by a woman, no photo kept'), findsOneWidget);
      expect(find.text('A check with a woman'), findsOneWidget);
      expect(find.text('In person at a ladies-only gym'), findsNothing);
      expect(find.textContaining('partner gyms'), findsNothing);
      expect(find.text('Ask a woman to check me'), findsOneWidget);
    },
  );

  testWidgets(
    'says plainly that no camera is asked for, and who contacts her',
    (tester) async {
      await tester.pumpWidget(
        _host(WomanReviewerView(requester: _Requester(<Object>[]))),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'If you do not show your face to a camera, nothing here asks you to',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'A woman from Own Hub reviews your case and contacts you by phone within 72 hours',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('text you'), findsNothing);
      expect(find.textContaining('video'), findsNothing);
      // Before request_review records the review route, she is told what her
      // number is for (pending counsel).
      expect(
        find.text('Your phone number is used only to arrange your check.'),
        findsOneWidget,
      );
      expect(find.textContaining('Nothing is recorded.'), findsOneWidget);
      expect(
        find.textContaining('She keeps only her decision and the date'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Only women review these checks'),
        findsOneWidget,
      );
    },
  );

  testWidgets('P0-VER-05: she is queued through request_review, no selfie', (
    tester,
  ) async {
    final requester = _Requester(<Object>[ReviewRequestState.pending]);
    final booked = <ReviewerPath>[];
    await tester.pumpWidget(
      _host(WomanReviewerView(requester: requester, onBooked: booked.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();

    expect(requester.asked, [ReviewPath.niqab]);
    expect(booked, [ReviewerPath.video]);
  });

  testWidgets('the path she came by is the path that is sent', (tester) async {
    for (final path in ReviewPath.values) {
      final requester = _Requester(<Object>[ReviewRequestState.pending]);
      await tester.pumpWidget(
        _host(
          WomanReviewerView(
            key: ValueKey(path),
            requester: requester,
            path: path,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask a woman to check me'));
      await tester.pumpAndSettle();
      expect(requester.asked, [path]);
    }
  });

  testWidgets('a failed call never claims a place in the queue, and retries', (
    tester,
  ) async {
    final requester = _Requester(<Object>[
      const VerificationCallFailure('unavailable'),
      ReviewRequestState.pending,
    ]);
    final booked = <ReviewerPath>[];
    await tester.pumpWidget(
      _host(WomanReviewerView(requester: requester, onBooked: booked.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();

    expect(booked, isEmpty, reason: 'she is not in the queue');
    expect(find.textContaining('you are not in the queue yet'), findsOneWidget);

    // The same button is the retry.
    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();
    expect(requester.asked, hasLength(2));
    expect(booked, [ReviewerPath.video]);
  });

  testWidgets('a daily limit says try tomorrow, and does not queue her', (
    tester,
  ) async {
    final requester = _Requester(<Object>[
      const VerificationCallFailure(
        'resource-exhausted',
        'per_uid_daily_limit',
      ),
    ]);
    final booked = <ReviewerPath>[];
    await tester.pumpWidget(
      _host(WomanReviewerView(requester: requester, onBooked: booked.add)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();

    expect(booked, isEmpty);
    expect(find.textContaining('try again tomorrow'), findsOneWidget);
  });

  testWidgets('a copy of the app App Check refuses is told to update', (
    tester,
  ) async {
    final booked = <ReviewerPath>[];
    await tester.pumpWidget(
      _host(
        WomanReviewerView(
          requester: _Requester(<Object>[
            const VerificationCallFailure(
              'failed-precondition',
              'app_check_missing',
            ),
          ]),
          onBooked: booked.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();
    expect(booked, isEmpty);
    expect(
      find.textContaining('This copy of the app cannot reach Own Hub'),
      findsOneWidget,
    );
  });

  testWidgets('a closed account goes to the screen that says so', (
    tester,
  ) async {
    var rejected = 0;
    await tester.pumpWidget(
      _host(
        WomanReviewerView(
          requester: _Requester(<Object>[
            const VerificationCallFailure(
              'failed-precondition',
              'verification_closed',
            ),
          ]),
          onRejected: () => rejected++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();
    expect(rejected, 1);
  });

  testWidgets('after an error she is told why she is here', (tester) async {
    await tester.pumpWidget(
      _host(
        WomanReviewerView(
          requester: _Requester(<Object>[]),
          path: ReviewPath.error,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The automatic check could not start just now'),
      findsOneWidget,
    );
  });

  // From a slow C12: the server refuses while her check is still running.
  // That is not "could not reach Own Hub", and nothing claims a queue.
  testWidgets('asked while the check still runs, she is told to wait', (
    tester,
  ) async {
    var booked = 0;
    final requester = _Requester(<Object>[
      const VerificationCallFailure(
        'failed-precondition',
        ServerReason.verificationInProgress,
      ),
      ReviewRequestState.pending,
    ]);
    await tester.pumpWidget(
      _host(
        WomanReviewerView(
          requester: requester,
          path: ReviewPath.error,
          checkStillRunning: true,
          onBooked: (_) => booked++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not start'),
      findsNothing,
      reason: 'the check started; it is slow',
    );

    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your automatic check is still running'),
      findsOneWidget,
    );
    expect(find.textContaining('We could not reach Own Hub'), findsNothing);
    expect(booked, 0);

    await tester.tap(find.text('Ask a woman to check me'));
    await tester.pumpAndSettle();
    expect(booked, 1);
    expect(requester.asked, [ReviewPath.error, ReviewPath.error]);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        WomanReviewerView(requester: _Requester(<Object>[])),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تراجعها امرأة، ولا تُحفظ أي صورة'), findsOneWidget);
    expect(find.text('اطلبي أن تتحقق منكِ امرأة'), findsOneWidget);
    expect(find.text('Checked by a woman, no photo kept'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        WomanReviewerView(
          requester: _Requester(<Object>[]),
          path: ReviewPath.error,
        ),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
