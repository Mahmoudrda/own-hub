/// An in-memory [VerificationRepository], for tests and for building screens
/// before there is a Cloud Function to decide anything.
///
/// It lives beside the interface for the same reason `FakeAuthRepository` does:
/// the screens in this flow cannot be built or reviewed without *some*
/// implementation, and one that is written down and strict is better than one
/// improvised per test.
///
/// **It cannot grant verification to itself.** [submit] moves to
/// [VerificationChecking] and stops; reaching [VerificationVerified] takes an
/// explicit [decide] call from the test. That mirrors spine C5 — the decision is
/// server-written, and a client that could verify itself would make the
/// women-only gate one line to bypass — so a screen that assumed it could
/// self-verify would fail here rather than in production.
library;

import 'dart:async';

import 'verification.dart';

class FakeVerificationRepository implements VerificationRepository {
  FakeVerificationRepository([
    this._state = const VerificationState.notStarted(),
    DateTime Function()? now,
  ]) : _now = now ?? DateTime.now;

  /// Injectable so a test can assert a *specific* elapsed time rather than
  /// whatever the wall clock happened to do between two statements.
  final DateTime Function() _now;

  VerificationState _state;
  final _controller = StreamController<VerificationState>.broadcast();

  /// Every method a check was started with, so a test can assert that the niqab
  /// path never asked for a selfie.
  final List<VerificationMethod> submitted = [];

  VerificationState get current => _state;

  @override
  Stream<VerificationState> watch() async* {
    yield _state;
    yield* _controller.stream;
  }

  @override
  Future<VerificationState> submit({required VerificationMethod method}) async {
    submitted.add(method);
    // An automatic check runs; a human path waits for a reviewer. Neither is
    // decided here.
    final next = method == VerificationMethod.automatic
        ? VerificationState.checking(startedAt: _now())
        : VerificationState.awaitingReviewer(submittedAt: _now());
    _emit(next);
    return next;
  }

  /// Stands in for the listener push that carries a server decision.
  void decide(VerificationState next) => _emit(next);

  void _emit(VerificationState next) {
    _state = next;
    _controller.add(next);
  }

  Future<void> dispose() => _controller.close();
}
