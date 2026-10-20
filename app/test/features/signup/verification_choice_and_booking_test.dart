// C09b routes, C15 known reviewer, C14 booking and approval, and the rule that
// no capture screen ever photographs on its own.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/data/review_scheduling_repository.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/features/signup/presentation/consent_view.dart';
import 'package:own_hub/features/signup/presentation/id_capture_view.dart';
import 'package:own_hub/features/signup/presentation/selfie_capture_view.dart';
import 'package:own_hub/features/signup/presentation/woman_reviewer_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child) {
  const locale = Locale('en');
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

class _FakeScheduling implements ReviewSchedulingRepository {
  _FakeScheduling({
    this.reviewers = const [],
    this.slots = const [],
    this.failBooking = false,
  });

  final List<ListedReviewer> reviewers;
  final List<ReviewSlot> slots;
  final bool failBooking;
  final List<ReviewSlot> booked = [];

  @override
  Future<List<ListedReviewer>> listReviewers() async => reviewers;

  @override
  Future<List<ReviewSlot>> listSlots({int days = 7}) async => slots;

  @override
  Future<DateTime> book(ReviewSlot slot) async {
    if (failBooking) throw const ReviewSchedulingFailure();
    booked.add(slot);
    return slot.start;
  }
}

class _Requester implements ReviewRequester {
  _Requester(this.answer);

  final ReviewRequestState answer;
  final List<String?> known = [];

  @override
  Future<ReviewRequestState> request(
    ReviewPath path, {
    String? knownReviewerId,
  }) async {
    known.add(knownReviewerId);
    return answer;
  }
}

/// A camera that reports a perfect, steady frame forever and counts shutters.
class _SteadySession implements CaptureSession {
  final _states = StreamController<CaptureState>.broadcast();
  int captures = 0;
  CaptureState _state = const CaptureState.framing(sharp: true);

  void steady() {
    _state = const CaptureState.framing(sharp: true);
    _states.add(_state);
  }

  @override
  CaptureState get current => _state;

  @override
  Stream<CaptureState> watch() async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Future<void> capture() async => captures++;

  @override
  Future<void> close() async => _states.close();
}

class _SteadyService implements CaptureService {
  final List<_SteadySession> opened = [];

  @override
  Future<CaptureSession> open(CaptureTarget target) async {
    final session = _SteadySession();
    opened.add(session);
    return session;
  }
}

Future<void> _holdSteady(WidgetTester tester, _SteadyService service) async {
  for (var i = 0; i < 40; i++) {
    for (final s in service.opened) {
      s.steady();
    }
    await tester.pump(const Duration(milliseconds: 125));
  }
}

DateTime _at(int day, int hour) => DateTime.utc(2026, 10, day, hour);

void main() {
  group('C09b offers two routes', () {
    testWidgets('both cards show, and the woman route leaves for C15', (
      tester,
    ) async {
      var declined = 0;
      var agreed = 0;
      await tester.pumpWidget(
        _host(
          ConsentView(
            uid: 'u1',
            store: InMemoryCaptureConsentStore(),
            onDeclined: () => declined++,
            onAgreed: () => agreed++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ID card and a selfie'), findsOneWidget);
      expect(find.text('About 2 minutes'), findsOneWidget);
      expect(find.text('Talk to a woman reviewer'), findsOneWidget);
      expect(find.text('A short call'), findsOneWidget);
      // The consent wording and its button are untouched.
      expect(find.text('Before the camera opens'), findsOneWidget);
      expect(find.textContaining('Frankfurt, Germany'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('c09b-route-woman')));
      await tester.pumpAndSettle();
      expect(declined, 1);
      expect(
        agreed,
        0,
        reason: 'choosing a woman never records camera consent',
      );
    });
  });

  group('C15 known reviewer', () {
    testWidgets('sends knownReviewerId and an instant approval moves on', (
      tester,
    ) async {
      final requester = _Requester(ReviewRequestState.approved);
      var verified = 0;
      await tester.pumpWidget(
        _host(
          WomanReviewerView(
            requester: requester,
            scheduling: _FakeScheduling(
              reviewers: const [
                ListedReviewer(reviewerId: 'r1', firstName: 'Mona'),
                ListedReviewer(reviewerId: 'r2', firstName: 'Salma'),
              ],
            ),
            onAlreadyVerified: () => verified++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('I know one of the reviewers'), findsOneWidget);

      await tester.ensureVisible(find.text('Salma'));
      await tester.tap(find.text('Salma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask a woman to check me'));
      await tester.pumpAndSettle();

      expect(requester.known, ['r2']);
      expect(verified, 1);
    });

    testWidgets('a failing list hides the picker and asking still works', (
      tester,
    ) async {
      final requester = _Requester(ReviewRequestState.pending);
      var booked = 0;
      await tester.pumpWidget(
        _host(
          WomanReviewerView(
            requester: requester,
            scheduling: const UnavailableReviewScheduling(),
            onBooked: (_) => booked++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('I know one of the reviewers'), findsNothing);

      await tester.tap(find.text('Ask a woman to check me'));
      await tester.pumpAndSettle();
      expect(requester.known, [null]);
      expect(booked, 1);
    });
  });

  group('C14 booking', () {
    final slots = [
      ReviewSlot(reviewerId: 'r1', start: _at(20, 9)),
      ReviewSlot(reviewerId: 'r1', start: _at(20, 10)),
      ReviewSlot(reviewerId: 'r2', start: _at(21, 11)),
    ];

    testWidgets('one tap books, the time shows, and it can be changed', (
      tester,
    ) async {
      final scheduling = _FakeScheduling(slots: slots);
      await tester.pumpWidget(
        _host(BeingCheckedView(scheduling: scheduling, onKeepExploring: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pick a time for your call'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('slot-${_at(20, 10).toIso8601String()}')),
      );
      await tester.pumpAndSettle();

      expect(scheduling.booked.single.start, _at(20, 10));
      expect(
        find.textContaining('A woman from Own Hub will contact you on'),
        findsOneWidget,
      );
      expect(find.text('Pick a time for your call'), findsNothing);

      await tester.tap(find.text('Change the time'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a time for your call'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('slot-${_at(20, 9).toIso8601String()}')),
      );
      await tester.pumpAndSettle();
      expect(scheduling.booked.last.start, _at(20, 9));
    });

    testWidgets('a failed booking says so and books nothing', (tester) async {
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            scheduling: _FakeScheduling(slots: slots, failBooking: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('slot-${_at(20, 9).toIso8601String()}')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('slots-book-failed')), findsOneWidget);
      expect(
        find.textContaining('A woman from Own Hub will contact you on'),
        findsNothing,
      );
    });

    testWidgets('an undeployed callable leaves the wait calm', (tester) async {
      await tester.pumpWidget(
        _host(
          const BeingCheckedView(scheduling: UnavailableReviewScheduling()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('slots-failed')), findsOneWidget);
    });

    testWidgets('Keep exploring is offered while waiting', (tester) async {
      var explored = 0;
      await tester.pumpWidget(
        _host(BeingCheckedView(onKeepExploring: () => explored++)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep exploring'));
      expect(explored, 1);
    });

    testWidgets('an approval while it is open cheers, then moves to C13', (
      tester,
    ) async {
      final updates = StreamController<ServerVerification?>();
      var approved = 0;
      await tester.pumpWidget(
        _host(
          BeingCheckedView(
            updates: updates.stream,
            scheduling: _FakeScheduling(slots: slots),
            onApproved: () => approved++,
            cheerFor: const Duration(milliseconds: 500),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(approved, 0);

      updates.add(const ServerVerification(ServerVerificationState.approved));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(approved, 0, reason: 'the kitten cheers first');
      expect(find.text('Your check is done'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(approved, 1);
      await updates.close();
    });
  });

  group('no capture screen photographs by itself', () {
    testWidgets('C10 front, C10b back and C11 selfie stay un-fired', (
      tester,
    ) async {
      final front = _SteadyService();
      await tester.pumpWidget(
        _host(IdCaptureView(captureService: front, onCaptured: () {})),
      );
      await tester.pump();
      await _holdSteady(tester, front);
      expect(front.opened.single.captures, 0);

      final back = _SteadyService();
      await tester.pumpWidget(
        _host(
          IdCaptureView(
            key: UniqueKey(),
            captureService: back,
            side: CaptureTarget.idBack,
            onCaptured: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Ready'));
      await tester.pump();
      await _holdSteady(tester, back);
      expect(back.opened.single.captures, 0);

      final selfie = _SteadyService();
      await tester.pumpWidget(
        _host(SelfieCaptureView(key: UniqueKey(), captureService: selfie)),
      );
      await tester.pump();
      await _holdSteady(tester, selfie);
      expect(selfie.opened.single.captures, 0);
      expect(find.text('Use this photo'), findsNothing);
    });

    test('the card camera has no steady-frame clock', () {
      final src = File('lib/features/signup/data/camera_capture_service.dart')
          .readAsStringSync();
      expect(src, isNot(contains('_steadyFrames')));
      expect(src, isNot(contains('AutoCapture')));
    });

    test('E12 takes a photo only inside takePhoto, with no frame stream', () {
      final src = File('lib/features/eat/data/meal_camera.dart')
          .readAsStringSync();
      expect(src, isNot(contains('startImageStream')));
      expect('takePicture('.allMatches(src).length, 1);
      final from = src.indexOf('Future<Uint8List?> takePhoto() async {');
      expect(src.indexOf('takePicture('), greaterThan(from));
    });
  });
}
