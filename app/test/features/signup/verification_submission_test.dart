// What happens between "the challenge finished" and "C13, C14 or back to C10".
//
// The assertions that matter here are the negative ones. Nothing on the phone
// may grant verification, nothing on the phone may send a verdict, no outcome
// may be an accusation, no reason code may reach a screen, and the frames must
// be gone whichever way the call went.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/data/callable_verification_provider.dart';
import 'package:own_hub/features/signup/data/provider_verification_repository.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/liveness_challenge.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/domain/verification_evidence.dart';
import 'package:own_hub/features/signup/domain/verification_provider.dart';

class _ScriptedProvider implements VerificationProvider {
  _ScriptedProvider(this._answers);

  /// Either a decision to return or an error to throw, per call.
  final List<Object> _answers;

  final List<String> sawSessionId = <String>[];
  final List<int> sawByteCount = <int>[];
  final List<String?> sawOperationId = <String?>[];
  final List<String?> sawInstallId = <String?>[];

  @override
  Future<LivenessChallenge> startSession() async =>
      _challenge(DateTime.now().add(const Duration(minutes: 2)));

  @override
  Future<VerificationDecision> submit(
    VerificationEvidence evidence,
    String sessionId, {
    String? operationId,
    String? installId,
  }) async {
    sawSessionId.add(sessionId);
    sawOperationId.add(operationId);
    sawInstallId.add(installId);
    sawByteCount.add(evidence.byteCount);
    final next = _answers.removeAt(0);
    if (next is VerificationDecision) return next;
    throw next;
  }
}

/// `request_review`, scripted. Answers pending unless told otherwise.
class _Reviews implements ReviewRequester {
  _Reviews([List<Object>? answers]) : _answers = answers;

  final List<Object>? _answers;
  final List<ReviewPath> asked = <ReviewPath>[];

  @override
  Future<ReviewRequestState> request(ReviewPath path) async {
    asked.add(path);
    final answers = _answers;
    if (answers == null || answers.isEmpty) return ReviewRequestState.pending;
    final next = answers.removeAt(0);
    if (next is ReviewRequestState) return next;
    throw next;
  }
}

LivenessChallenge _challenge(DateTime expiresAt) => LivenessChallenge(
  sessionId: 's-1',
  steps: const <LivenessStep>[LivenessStep.faceCentre, LivenessStep.blink],
  expiresAt: expiresAt,
);

VerificationEvidence _filled() => VerificationEvidence()
  ..holdCardSide(CaptureTarget.idFront, Uint8List.fromList(<int>[1, 2, 3, 4]))
  ..holdCardSide(CaptureTarget.idBack, Uint8List.fromList(<int>[5, 6, 7, 8]))
  ..addFrame(Uint8List.fromList(<int>[9, 10]))
  ..addFrame(Uint8List.fromList(<int>[11, 12]));

ProviderVerificationRepository _repository(
  _ScriptedProvider provider, {
  VerificationEvidence? evidence,
  DateTime? expiresAt,
  Future<void> Function()? refreshClaims,
  List<String>? refreshes,
  ReviewRequester? reviews,
  Future<String?> Function()? installId,
}) {
  var op = 0;
  return ProviderVerificationRepository(
    provider: provider,
    reviews: reviews ?? _Reviews(),
    installId: installId,
    operationIds: () => 'op-${++op}',
    evidence: evidence ?? _filled(),
    refreshClaims:
        refreshClaims ??
        () async {
          refreshes?.add('refreshed');
        },
    challenge: _challenge(
      expiresAt ?? DateTime.now().add(const Duration(minutes: 2)),
    ),
  );
}

Future<VerificationState> _settle(
  ProviderVerificationRepository repository,
) async {
  // The call runs unawaited so C12 can paint; a handful of microtask turns is
  // all it takes for a synchronous fake to land.
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return repository.current;
}

void main() {
  test('an approval is the only path to verified, and it comes from the '
      'server', () async {
    final evidence = _filled();
    final refreshes = <String>[];
    final provider = _ScriptedProvider(<Object>[
      const VerificationDecision(
        outcome: VerificationOutcome.approved,
        refreshToken: true,
      ),
    ]);
    final repository = _repository(
      provider,
      evidence: evidence,
      refreshes: refreshes,
    );

    final immediate = await repository.submit(
      method: VerificationMethod.automatic,
    );
    // What C12 shows while it runs, with a real start time so C13 can state a
    // measured duration instead of the prototype's invented 74 seconds.
    expect(immediate, isA<VerificationChecking>());
    expect((immediate as VerificationChecking).startedAt, isNotNull);

    final settled = await _settle(repository);
    expect(settled, isA<VerificationVerified>());
    final result = (settled as VerificationVerified).result;
    expect(result.method, VerificationMethod.automatic);
    expect(result.took, isNotNull);
    expect(result.imagesConfirmedDeleted, isTrue);

    // The claim has to be on the token before she is told she is in. Without
    // this she meets an app that still thinks she is unverified, which since
    // the gate is the whole app is a locked door rather than a cosmetic bug.
    expect(refreshes, <String>['refreshed']);
    expect(evidence.isEmpty, isTrue, reason: 'rule 7, on the success path');
    await repository.dispose();
  });

  test('a token refresh that keeps failing still admits her', () async {
    // She is verified. The claim is written. Firebase refreshes the token on
    // its own within the hour, so the choice is between a woman who is locked
    // out for a while and a woman who is told she was not verified when she
    // was. The first is bad; the second is wrong.
    final provider = _ScriptedProvider(<Object>[
      const VerificationDecision(
        outcome: VerificationOutcome.approved,
        refreshToken: true,
      ),
    ]);
    var attempts = 0;
    final repository = _repository(
      provider,
      refreshClaims: () async {
        attempts++;
        throw const SocketException('offline');
      },
    );

    await repository.submit(method: VerificationMethod.automatic);
    // Three attempts with a 400ms backoff between them.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    expect(repository.current, isA<VerificationVerified>());
    expect(attempts, 3);
    await repository.dispose();
  });

  test('a refresh is not forced when the server did not ask for one', () async {
    final refreshes = <String>[];
    final provider = _ScriptedProvider(<Object>[
      const VerificationDecision(outcome: VerificationOutcome.approved),
    ]);
    final repository = _repository(provider, refreshes: refreshes);

    await repository.submit(method: VerificationMethod.automatic);
    await _settle(repository);
    expect(refreshes, isEmpty);
    await repository.dispose();
  });

  test(
    'all three rejections land in the same place, saying the same thing',
    () async {
      // Separating them on screen would be the oracle the reason vocabulary was
      // narrowed to remove. "Not eligible", "failed" and "duplicate" are very
      // different internally and identical to her.
      for (final outcome in <VerificationOutcome>[
        VerificationOutcome.rejectedNotEligible,
        VerificationOutcome.rejectedFailed,
        VerificationOutcome.rejectedDuplicate,
      ]) {
        final provider = _ScriptedProvider(<Object>[
          VerificationDecision(
            outcome: outcome,
            reasons: const <VerificationReason>{
              VerificationReason.contactSupport,
            },
          ),
        ]);
        final repository = _repository(provider);
        await repository.submit(method: VerificationMethod.automatic);
        final settled = await _settle(repository);

        // The server has recorded a final refusal for every one of these that
        // reaches the client, so she is told so plainly (S8), in one sentence.
        expect(
          settled,
          isA<VerificationRejected>(),
          reason: '$outcome must not be told apart from the others on screen',
        );
        expect(settled.isPending, isFalse);
        await repository.dispose();
      }
    },
  );

  test('a retake is her move, not a reviewer\'s', () async {
    // Collapsing this into "a woman will call you" would spend a video call on
    // a glare patch she could have fixed in ten seconds.
    for (final outcome in <VerificationOutcome>[
      VerificationOutcome.retryCapture,
      VerificationOutcome.retryRequired,
    ]) {
      final provider = _ScriptedProvider(<Object>[
        VerificationDecision(outcome: outcome),
      ]);
      final repository = _repository(provider);
      await repository.submit(method: VerificationMethod.automatic);
      final settled = await _settle(repository);

      expect(settled, isA<VerificationRetakeNeeded>());
      expect(
        settled.isPending,
        isFalse,
        reason: 'she is not waiting on anybody, so no "sit tight" copy',
      );
      await repository.dispose();
    }
  });

  test('an expired liveness session is a retake, not a failure', () async {
    // She put the phone down halfway through. Submitting against a dead session
    // fails server side with nothing on screen to explain it.
    final provider = _ScriptedProvider(<Object>[]);
    final repository = _repository(
      provider,
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );

    await repository.submit(method: VerificationMethod.automatic);
    expect(await _settle(repository), isA<VerificationRetakeNeeded>());
    expect(
      provider.sawSessionId,
      isEmpty,
      reason: 'nothing is sent against a session the server has dropped',
    );
    await repository.dispose();
  });

  test(
    'an unreachable server offers a reviewer, asks nobody, and shreds',
    () async {
      final evidence = _filled();
      final provider = _ScriptedProvider(<Object>[
        const SocketException('no route to host'),
      ]);
      final reviews = _Reviews();
      final repository = _repository(
        provider,
        evidence: evidence,
        reviews: reviews,
      );

      await repository.submit(method: VerificationMethod.automatic);
      final settled = await _settle(repository);

      // R4: no `request_review` until she has read the C15 wording and tapped.
      expect(settled, isA<VerificationReviewOffered>());
      expect(settled.isPending, isFalse);
      expect(
        reviews.asked,
        isEmpty,
        reason: 'she is offered a reviewer, never queued without asking',
      );
      expect(
        evidence.isEmpty,
        isTrue,
        reason: 'rule 7 runs in a finally, so it survives the failure path too',
      );
      await repository.dispose();
    },
  );

  test('a connection that never opened is retried exactly once', () async {
    // "unavailable" is the one code that means nothing was charged, so the
    // retry cannot produce a duplicate billable check.
    final provider = _ScriptedProvider(<Object>[
      Exception('[firebase_functions/unavailable] could not connect'),
      const VerificationDecision(outcome: VerificationOutcome.approved),
    ]);
    final repository = _repository(provider);

    await repository.submit(method: VerificationMethod.automatic);
    expect(await _settle(repository), isA<VerificationVerified>());
    expect(provider.sawByteCount, hasLength(2));
    await repository.dispose();
  });

  test('a timeout is not retried', () async {
    // A timeout may well have been a success we did not hear about.
    final provider = _ScriptedProvider(<Object>[
      Exception('[firebase_functions/deadline-exceeded] timed out'),
      const VerificationDecision(outcome: VerificationOutcome.approved),
    ]);
    final repository = _repository(provider);

    await repository.submit(method: VerificationMethod.automatic);
    // R4: a reviewer is offered, not requested on her behalf.
    expect(await _settle(repository), isA<VerificationReviewOffered>());
    expect(provider.sawByteCount, hasLength(1));
    await repository.dispose();
  });

  test('the session id travels and is spent once', () async {
    final provider = _ScriptedProvider(<Object>[
      const VerificationDecision(outcome: VerificationOutcome.approved),
    ]);
    final repository = _repository(provider);

    await repository.submit(method: VerificationMethod.automatic);
    await _settle(repository);

    expect(provider.sawSessionId, <String>['s-1']);
    // Single use. Keeping it would let a second submit run against a challenge
    // whose frames have already been spent.
    expect(repository.challenge, isNull);
    await repository.dispose();
  });

  test('the niqab path never sends anything', () async {
    final evidence = VerificationEvidence();
    final provider = _ScriptedProvider(<Object>[]);
    final reviews = _Reviews();
    final repository = _repository(
      provider,
      evidence: evidence,
      reviews: reviews,
    );

    final state = await repository.submit(
      method: VerificationMethod.niqabFriendly,
    );

    expect(state, isA<VerificationAwaitingReviewer>());
    expect(reviews.asked, [ReviewPath.niqab]);
    expect(
      provider.sawByteCount,
      isEmpty,
      reason: 'no camera opened on this path, so there is nothing to submit',
    );
    await repository.dispose();
  });

  group('the client is never the source of truth', () {
    test('an unrecognised outcome is a review, never an approval', () {
      // The two failure modes are "a woman who should have been let in waits
      // for a video call" and "a man is let in because the app could not parse
      // the word rejected". Those are not comparable.
      expect(
        verificationOutcomeFrom('SOMETHING_NEW'),
        VerificationOutcome.pendingReview,
      );
      expect(verificationOutcomeFrom(null), VerificationOutcome.pendingReview);
      expect(verificationOutcomeFrom(42), VerificationOutcome.pendingReview);
      expect(verificationOutcomeFrom('APPROVED'), VerificationOutcome.approved);
    });

    test('an unrecognised reason code does not crash a sign-up', () {
      expect(verificationReasonFrom('brand_new'), VerificationReason.unknown);
      expect(
        verificationReasonFrom('retake_front'),
        VerificationReason.retakeFront,
      );
    });

    test('an unrecognised challenge step makes the challenge unrunnable', () {
      // Prompting a guess would produce a frame the server scores against a
      // step she was never asked to perform: a woman refused for our being out
      // of date.
      expect(livenessStepFrom('somersault'), LivenessStep.unsupported);
      final challenge = LivenessChallenge(
        sessionId: 's',
        steps: const <LivenessStep>[
          LivenessStep.faceCentre,
          LivenessStep.unsupported,
        ],
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      expect(challenge.isRunnable, isFalse);
    });

    test('an empty challenge is not a challenge', () {
      final challenge = LivenessChallenge(
        sessionId: 's',
        steps: const <LivenessStep>[],
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      expect(challenge.isRunnable, isFalse);
    });

    test('no liveness verdict exists anywhere in the app to be sent', () {
      // The strongest form of the rule of engagement: the client cannot
      // transmit a verification result because it has no type that holds one.
      // An earlier build sent `liveness: {outcome, sessionId}`, which a patched
      // APK sets to "pass" on its way into a women-only community. This guard
      // is what stops that being reintroduced by someone who thinks it would
      // help the server.
      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (RegExp(
          r'\bLivenessOutcome\b|livenessOutcome|'
          r"'outcome'\s*:\s*_wireLiveness",
        ).hasMatch(source)) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'The phone reports a session id, never a verdict.',
      );
    });

    test('the liveness payload carries a session id and nothing else', () {
      // Read off the source, because the shape of this map is the contract and
      // a second key added here would be a second thing the server has to
      // decide whether to trust.
      final source = File(
        'lib/features/signup/data/callable_verification_provider.dart',
      ).readAsStringSync();
      final payload = RegExp(r"'liveness':\s*<String, Object\?>\{([^}]*)\}")
          .firstMatch(source);
      expect(payload, isNotNull, reason: 'the liveness payload moved');
      expect(
        RegExp(r"'(\w+)'\s*:")
            .allMatches(payload!.group(1)!)
            .map((m) => m.group(1)),
        <String>['sessionId'],
      );
    });
  });

  group('S3, S6, S12: what a failed call means', () {
    Future<(VerificationState, _Reviews)> failWith(Object error) async {
      final reviews = _Reviews();
      final repository = _repository(
        _ScriptedProvider(<Object>[error]),
        reviews: reviews,
      );
      await repository.submit(method: VerificationMethod.automatic);
      final settled = await _settle(repository);
      await repository.dispose();
      return (settled, reviews);
    }

    test('a daily limit is try-tomorrow, never a review', () async {
      for (final reason in <String>[
        'per_uid_daily_limit',
        'daily_limit_reached',
      ]) {
        final (state, reviews) = await failWith(
          VerificationCallFailure('resource-exhausted', reason),
        );
        expect(state, isA<VerificationTryTomorrow>(), reason: reason);
        expect(reviews.asked, isEmpty, reason: reason);
      }
    });

    test('the cost cap is told, and never queues a review by itself', () async {
      final (state, reviews) = await failWith(
        const VerificationCallFailure('resource-exhausted', 'cost_cap_reached'),
      );
      expect(state, isA<VerificationChecksUsedUp>());
      expect(reviews.asked, isEmpty);
    });

    test('a missing consent goes back to the consent screen', () async {
      final (state, reviews) = await failWith(
        const VerificationCallFailure('failed-precondition', 'consent_missing'),
      );
      expect(state, isA<VerificationConsentNeeded>());
      expect(reviews.asked, isEmpty);
    });

    test('a closed account is told so', () async {
      final (state, _) = await failWith(
        const VerificationCallFailure(
          'failed-precondition',
          'verification_closed',
        ),
      );
      expect(state, isA<VerificationRejected>());
    });

    test(
      'an open review is the waiting screen, with no second request',
      () async {
        final (state, reviews) = await failWith(
          const VerificationCallFailure(
            'failed-precondition',
            'review_already_open',
          ),
        );
        expect(state, isA<VerificationAwaitingReviewer>());
        expect(reviews.asked, isEmpty);
      },
    );

    test(
      'photographs the server could not use are a retake, not a review',
      () async {
        for (final reason in <String>[
          'image_undecodable',
          'image_too_large',
          'session_missing',
          'liveness_failed',
          'internal_error',
        ]) {
          final (state, reviews) = await failWith(
            VerificationCallFailure('invalid-argument', reason),
          );
          expect(state, isA<VerificationRetakeNeeded>(), reason: reason);
          expect(reviews.asked, isEmpty, reason: reason);
        }
      },
    );

    test(
      'a copy of the app App Check refuses is told to update, never queued',
      () async {
        final (state, reviews) = await failWith(
          const VerificationCallFailure(
            'failed-precondition',
            'app_check_missing',
          ),
        );
        expect(state, isA<VerificationAppCannotReach>());
        expect(reviews.asked, isEmpty);
      },
    );

    test('a call that runs out of time says the connection is too slow, '
        'asks nobody, and keeps nothing', () async {
      final evidence = _filled();
      final reviews = _Reviews(<Object>[
        const VerificationCallFailure('unavailable'),
      ]);
      final repository = _repository(
        _ScriptedProvider(<Object>[
          const VerificationCallFailure('deadline-exceeded'),
        ]),
        evidence: evidence,
        reviews: reviews,
      );
      await repository.submit(method: VerificationMethod.automatic);
      final settled = await _settle(repository);
      expect(settled, isA<VerificationTooSlow>());
      expect(settled.isPending, isFalse);
      expect(reviews.asked, isEmpty);
      // The privacy rule: the photographs are gone whichever way it ended.
      expect(evidence.byteCount, 0);
      await repository.dispose();
    });

    test('the retry after "too slow" carries the same operation id, and a '
        'decision that follows clears it', () async {
      final provider = _ScriptedProvider(<Object>[
        const VerificationCallFailure('deadline-exceeded'),
        const VerificationCallFailure('deadline-exceeded'),
        const VerificationDecision(outcome: VerificationOutcome.approved),
        const VerificationDecision(outcome: VerificationOutcome.approved),
      ]);
      final repository = _repository(provider);
      Future<void> attempt() async {
        repository.challenge = _challenge(
          DateTime.now().add(const Duration(minutes: 2)),
        );
        repository.evidence
          ..holdCardSide(CaptureTarget.idFront, Uint8List.fromList(<int>[1, 2]))
          ..holdCardSide(CaptureTarget.idBack, Uint8List.fromList(<int>[3, 4]));
        await repository.submit(method: VerificationMethod.automatic);
        await _settle(repository);
      }

      await attempt();
      expect(repository.current, isA<VerificationTooSlow>());
      await attempt();
      await attempt();
      expect(repository.current, isA<VerificationVerified>());
      await attempt();
      expect(provider.sawOperationId, ['op-1', 'op-1', 'op-1', 'op-2']);
      await repository.dispose();
    });

    test('the callable waits as long as the server does', () {
      expect(
        CallableVerificationProvider.submitTimeout,
        const Duration(seconds: 120),
      );
    });

    test('the niqab path that cannot reach the server says so', () async {
      final repository = _repository(
        _ScriptedProvider(<Object>[]),
        reviews: _Reviews(<Object>[StateError('offline')]),
      );
      final state = await repository.submit(
        method: VerificationMethod.niqabFriendly,
      );
      expect(state, isA<VerificationUnreachable>());
      await repository.dispose();
    });

    test('one operation id per attempt, reused on the single retry', () async {
      final provider = _ScriptedProvider(<Object>[
        const VerificationCallFailure('unavailable'),
        const VerificationDecision(outcome: VerificationOutcome.approved),
      ]);
      final repository = _repository(
        provider,
        installId: () async => 'install-abc',
      );
      await repository.submit(method: VerificationMethod.automatic);
      expect(await _settle(repository), isA<VerificationVerified>());
      expect(provider.sawOperationId, <String?>['op-1', 'op-1']);
      expect(provider.sawInstallId, <String?>['install-abc', 'install-abc']);
      await repository.dispose();
    });

    test('an install id that cannot be read never stops a check', () async {
      final provider = _ScriptedProvider(<Object>[
        const VerificationDecision(outcome: VerificationOutcome.approved),
      ]);
      final repository = _repository(
        provider,
        installId: () async => throw StateError('no preferences'),
      );
      await repository.submit(method: VerificationMethod.automatic);
      expect(await _settle(repository), isA<VerificationVerified>());
      expect(provider.sawInstallId, <String?>[null]);
      await repository.dispose();
    });

    test('settle can never verify her', () {
      final repository = _repository(_ScriptedProvider(<Object>[]));
      expect(
        () => repository.settle(
          VerificationState.verified(
            VerificationResult(
              method: VerificationMethod.automatic,
              decidedAt: DateTime(2026),
              imagesDeletedAt: DateTime(2026),
            ),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  test('no screen can reach a reason code', () {
    // The reasons are user-safe now, and they still stop at the repository,
    // because the rule is "branch on the outcome and on nothing else". A
    // screen that switched on `retake_front` would be one deploy away from
    // switching on something that is not user-safe.
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => f.path.contains('/presentation/'))) {
      final source = file.readAsStringSync();
      if (source.contains('verification_provider.dart') ||
          RegExp(r'\bVerificationReason\b').hasMatch(source)) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Reason codes stop at the repository. A screen branches on the '
          'outcome and never on why.',
    );
  });
}
