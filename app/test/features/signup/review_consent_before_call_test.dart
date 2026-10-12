// R4, client: nobody is put in the review queue without reading what it
// means and asking for it herself.
//
//  * An unclassified failure of the automatic check used to call
//    `request_review(error)` on her behalf. Now C12 offers a reviewer and
//    sends her to C15, where the wording is and the button is hers to tap.
//  * A flag the automatic check raised itself (PENDING_REVIEW) lands on C14.
//    Until she taps "Ask a woman to contact me", C14 says plainly that a woman
//    from Own Hub can only contact her after she asks.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/features/signup/presentation/checking_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

class _Requester implements ReviewRequester {
  _Requester([this.fail]);
  final Object? fail;
  final asked = <ReviewPath>[];

  @override
  Future<ReviewRequestState> request(ReviewPath path) async {
    asked.add(path);
    if (fail != null) throw fail!;
    return ReviewRequestState.pending;
  }
}

class _Repository implements VerificationRepository {
  final _states = StreamController<VerificationState>.broadcast();

  void emit(VerificationState state) => _states.add(state);

  @override
  Stream<VerificationState> watch() => _states.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: child,
);

void main() {
  group('C14 after a flag the automatic check raised', () {
    testWidgets('says a reviewer calls only after she asks', (tester) async {
      final requester = _Requester();
      var asked = 0;
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.pending),
            reviewAsked: false,
            requester: requester,
            onAskedForCall: () => asked++,
          ),
        ),
      );
      await tester.pump();
      final l10n = AppL10n.of(tester.element(find.byType(BeingCheckedView)));

      expect(find.text(l10n.aWomanFromOwnHubCanContact), findsOneWidget);
      expect(find.text(l10n.yourPhoneNumberIsUsedOnlyTo_thda4), findsOneWidget);
      expect(find.text(l10n.aWomanFromOwnHubReviewsYour), findsNothing);
      expect(requester.asked, isEmpty, reason: 'nothing is sent on arrival');

      await tester.ensureVisible(
        find.byKey(const ValueKey('c14-ask-for-the-call')),
      );
      await tester.tap(find.byKey(const ValueKey('c14-ask-for-the-call')));
      await tester.pumpAndSettle();

      expect(requester.asked, [ReviewPath.error]);
      expect(asked, 1);
      expect(find.text(l10n.aWomanFromOwnHubReviewsYour), findsOneWidget);
      expect(find.byKey(const ValueKey('c14-ask-for-the-call')), findsNothing);
    });

    testWidgets('a failed ask says so and keeps the button', (tester) async {
      final requester = _Requester(
        const VerificationCallFailure('unavailable'),
      );
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.pending),
            reviewAsked: false,
            requester: requester,
          ),
        ),
      );
      await tester.pump();
      final l10n = AppL10n.of(tester.element(find.byType(BeingCheckedView)));
      await tester.ensureVisible(
        find.byKey(const ValueKey('c14-ask-for-the-call')),
      );
      await tester.tap(find.byKey(const ValueKey('c14-ask-for-the-call')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.weCouldNotReachOwnHubSo_3usbb), findsOneWidget);
      expect(
        find.byKey(const ValueKey('c14-ask-for-the-call')),
        findsOneWidget,
      );
    });

    testWidgets('once she has asked, no button and no caveat', (tester) async {
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.pending),
            requester: _Requester(),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppL10n.of(tester.element(find.byType(BeingCheckedView)));
      expect(find.text(l10n.aWomanFromOwnHubReviewsYour), findsOneWidget);
      expect(find.byKey(const ValueKey('c14-ask-for-the-call')), findsNothing);
    });
  });

  testWidgets('C12: an unclassified failure offers C15, it does not queue', (
    tester,
  ) async {
    final repository = _Repository();
    var offered = 0;
    var queued = 0;
    await tester.pumpWidget(
      _host(
        CheckingView(
          repository: repository,
          onAskForReviewer: () => offered++,
          onAwaitingReviewer: () => queued++,
        ),
      ),
    );
    repository.emit(const VerificationState.reviewOffered());
    await tester.pumpAndSettle();
    final l10n = AppL10n.of(tester.element(find.byType(CheckingView)));

    expect(offered, 1, reason: 'on to C15, path error, once');
    expect(queued, 0);
    expect(find.text(l10n.theCheckDidNotFinish), findsOneWidget);

    // Back from C15 she finds the offer, and it opens C15 again on a tap.
    await tester.tap(find.text(l10n.askForAWomanReviewer));
    expect(offered, 2);
  });
}
