/// Invite codes: the one a coach shares, and the one a woman carries through
/// sign-up. See `features/coach/domain/coach_invite.dart`.
///
/// The code she typed on `C01` is kept on her phone (snapshot section
/// `invite`) until she has passed the check, then redeemed once. Nothing about
/// her goes to the server before that, and nothing about her is ever written
/// onto the code.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../features/coach/domain/coach_invite.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';

class CoachInviteState {
  CoachInviteState._();

  static final CoachInviteState instance = CoachInviteState._();

  /// The code she typed on `C01`, waiting for her check to finish.
  String? pendingCode;

  /// The coach a redeemed code named, until her page has been opened. The
  /// code is kept until then, so a page that could not open yet is not lost.
  String? pendingCoach;

  void keepPending(String code) {
    pendingCode = code;
    AppChanges.bump();
  }

  void clearPending() {
    if (pendingCode == null && pendingCoach == null) return;
    pendingCode = null;
    pendingCoach = null;
    AppChanges.bump();
  }

  /// Account deletion and sign-out.
  void reset() {
    pendingCode = null;
    pendingCoach = null;
    _redeeming = false;
  }

  bool _redeeming = false;

  /// Redeems the code she kept, when [allowed] (she has passed the check, with
  /// an account, while the coach app is on). Null when there was nothing to
  /// do. A failure to reach the server keeps the code for the next try; a code
  /// that will never work is dropped, so she is told once. A code that named
  /// a coach is kept, with [pendingCoach], until her page is open
  /// ([clearPending]); naming her again is harmless.
  Future<InviteResult?> redeem(
    CoachInviteStore store, {
    required bool allowed,
  }) async {
    final code = pendingCode;
    if (code == null || !allowed || _redeeming) return null;
    _redeeming = true;
    try {
      final result = await store.accept(code);
      switch (result.outcome) {
        case InviteRedemption.refused:
          clearPending();
        case InviteRedemption.linked:
          pendingCoach = result.coachUid;
        case InviteRedemption.unreachable:
          break;
      }
      return result;
    } finally {
      _redeeming = false;
    }
  }
}

/// Thrown when a coach's code could not be made.
class InviteUnavailable implements Exception {
  const InviteUnavailable();
}

abstract class CoachInviteStore {
  /// Her code, new or the one still live. Throws [InviteUnavailable].
  Future<String> create();

  Future<InviteResult> accept(String code);
}

/// The reasons that mean the code itself will never work for her. Anything
/// else (no network, the coach side closed, not verified yet) leaves the code
/// on her phone to be tried again.
const Set<String> _codeIsDead = {
  'invite_invalid',
  'invite_expired',
  'invite_own',
};

class CallableCoachInviteStore implements CoachInviteStore {
  CallableCoachInviteStore({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  HttpsCallable _callable(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
  );

  @override
  Future<String> create() async {
    try {
      final result = await _callable(kCreateCoachInviteCallable)
          .call<Object?>(<String, Object>{});
      final data = result.data;
      final code = data is Map ? data['code'] : null;
      if (code is String && normaliseInviteCode(code) == code) return code;
    } catch (_) {
      // Reported below as one answer: there is no code to share.
    }
    throw const InviteUnavailable();
  }

  @override
  Future<InviteResult> accept(String code) async {
    try {
      final result = await _callable(kAcceptCoachInviteCallable)
          .call<Object?>(<String, Object>{'code': code});
      final data = result.data;
      final coach = data is Map ? data['coachUid'] : null;
      // No coach in the answer is not a link: the code stays to be tried again.
      return coach is String && coach.isNotEmpty
          ? InviteResult(InviteRedemption.linked, coach)
          : const InviteResult(InviteRedemption.unreachable);
    } on FirebaseFunctionsException catch (error) {
      return InviteResult(
        _codeIsDead.contains(error.message)
            ? InviteRedemption.refused
            : InviteRedemption.unreachable,
      );
    } catch (_) {
      return const InviteResult(InviteRedemption.unreachable);
    }
  }
}

/// A build with no back end, and tests. Codes live in memory; a code it never
/// made is refused, as the server would refuse it.
class InMemoryCoachInviteStore implements CoachInviteStore {
  InMemoryCoachInviteStore({this.code = 'TEST2345', this.coachUid = 'coach1'});

  final String code;
  final String coachUid;
  final List<String> accepted = <String>[];

  @override
  Future<String> create() async => code;

  @override
  Future<InviteResult> accept(String code) async {
    if (code != this.code) {
      return const InviteResult(InviteRedemption.refused);
    }
    accepted.add(code);
    return InviteResult(InviteRedemption.linked, coachUid);
  }
}
