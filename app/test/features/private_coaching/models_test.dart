import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/payments.dart';
import 'package:own_hub/features/private_coaching/domain/session_link.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/coach_plan_logic.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';

import 'support/fixtures.dart';

void main() {
  group('CoachApplication', () {
    test('a complete application has nothing missing', () {
      expect(completeApplication().missingSections(now: kNow), isEmpty);
      expect(completeApplication().canSubmit(now: kNow), isTrue);
    });

    test('an empty one is missing every section, in step order', () {
      expect(
        CoachApplication().missingSections(now: kNow),
        CoachingEnums.applicationSections,
      );
    });

    test('toMap then fromMap gives the same application', () {
      final app = completeApplication();
      final again = CoachApplication.fromMap(app.toMap());
      expect(again.toMap(), app.toMap());
      expect(again.missingSections(now: kNow), isEmpty);
    });

    test('toRequest adds the locale', () {
      expect(completeApplication().toRequest(locale: 'ar')['locale'], 'ar');
    });

    test('a degree proof file is optional, a certificate file is not', () {
      var app = completeApplication();
      expect(app.education.single.path, isEmpty);
      expect(app.missingSections(now: kNow), isEmpty);
      app = app.copyWith(
        certificates: const <CoachCertificate>[
          CoachCertificate(
            id: 'cert-1',
            title: 'Level 3',
            issuer: 'REPs',
            year: 2019,
            mime: 'application/pdf',
          ),
        ],
      );
      expect(app.missingSections(now: kNow), <String>['certificates']);
    });

    test('each section reports itself when it breaks the server check', () {
      final base = completeApplication();
      final cases = <String, CoachApplication>{
        'personal': base.copyWith(
          personal: base.personal.copyWith(headline: 'too short'),
        ),
        'education': base.copyWith(qualifications: 'short'),
        'certificates': base.copyWith(
          certificates: <CoachCertificate>[
            base.certificates.first,
            base.certificates.first,
          ],
        ),
        'specialties': base.copyWith(specialties: const <String>[]),
        'feedback': base.copyWith(
          testimonials: <CoachTestimonial>[base.testimonials.first],
        ),
        'transformations': base.copyWith(
          transformations: const <CoachTransformation>[
            CoachTransformation(
              beforePath: 'a',
              afterPath: 'b',
              weeks: 4,
              clientConsent: false,
            ),
          ],
        ),
        'approach': base.copyWith(
          approach: base.approach.copyWith(replyHours: 7),
        ),
        'payout': base.copyWith(
          payout: base.payout.copyWith(account: 'not an account'),
        ),
        'terms': base.copyWith(rules: const <String>['accurateInfo']),
      };
      for (final entry in cases.entries) {
        expect(entry.value.missingSections(now: kNow), <String>[
          entry.key,
        ], reason: entry.key);
      }
      expect(
        base.copyWith(termsVersion: 2).missingSections(now: kNow),
        <String>['terms'],
      );
    });

    test('a certificate year in the future is not accepted', () {
      final base = completeApplication();
      final future = base.copyWith(
        certificates: const <CoachCertificate>[
          CoachCertificate(
            id: 'c',
            title: 'Level 3',
            issuer: 'REPs',
            year: 2027,
            path: 'coach-docs/u1/certificates/x.pdf',
            mime: 'application/pdf',
          ),
        ],
      );
      expect(future.missingSections(now: kNow), <String>['certificates']);
    });

    test('a vodafone cash account must be a mobile number', () {
      final base = completeApplication();
      final wallet = base.copyWith(
        payout: const CoachPayoutAccount(
          rail: 'vodafoneCash',
          account: '01012345678',
          holderName: 'Sara Hassan Ali',
        ),
      );
      expect(wallet.missingSections(now: kNow), isEmpty);
      expect(
        wallet
            .copyWith(payout: wallet.payout.copyWith(account: '1012345678'))
            .missingSections(now: kNow),
        <String>['payout'],
      );
    });

    test('bad documents never throw', () {
      for (final raw in <Object?>[
        null,
        42,
        'text',
        <String, Object?>{'education': 'nope', 'personal': 5, 'rules': 3},
        <String, Object?>{
          'certificates': <Object?>[1, null, 'x', <String, Object?>{}],
          'status': 'a_status_from_the_future',
          'reasons': <String, Object?>{'personal': 'missing', 'x': 4},
        },
      ]) {
        final app = CoachApplication.fromMap(raw);
        expect(app.missingSections(now: kNow), isNotEmpty);
      }
      final withReasons = CoachApplication.fromMap(<String, Object?>{
        'status': 'needs_changes',
        'reasons': <String, Object?>{'personal': 'missing', 'x': 4},
      });
      expect(withReasons.status, ApplicationStatus.needsChanges);
      expect(withReasons.reasons, <String, String>{'personal': 'missing'});
      expect(withReasons.sectionsNeedingChanges, <String>['personal']);
    });

    test('unknown specialties and languages are dropped', () {
      final app = CoachApplication.fromMap(<String, Object?>{
        'specialties': <Object?>['strength', 'magic', 3],
        'personal': <String, Object?>{
          'languages': <Object?>['ar', 'fr'],
        },
      });
      expect(app.specialties, <String>['strength']);
      expect(app.personal.languages, <String>['ar']);
    });
  });

  group('CoachProfile and packages', () {
    test('reads the public coach document', () {
      final profile = CoachProfile.fromMap('c1', <String, Object?>{
        'displayName': 'Sara',
        'approach': <String, Object?>{'text': 'Slow and steady'},
        'specialties': <Object?>['strength', 'nope'],
        'badges': <Object?>['verifiedCoach', 'madeUp'],
        'stats': <String, Object?>{'clientsCoached': 12},
        'fromPriceEgp': 1150,
        'published': true,
        'acceptingClients': true,
        'maxActiveClients': 10,
        'activeClients': 10,
        'certificates': <Object?>[
          <String, Object?>{'title': 'L3', 'issuer': 'REPs', 'year': 2019},
          <String, Object?>{'issuer': 'no title'},
        ],
      })!;
      expect(profile.approach, 'Slow and steady');
      expect(profile.specialties, <String>['strength']);
      expect(profile.badges, <String>['verifiedCoach']);
      expect(profile.stats.clientsCoached, 12);
      expect(profile.certificates, hasLength(1));
      expect(profile.hasRoom, isFalse);
    });

    test('an approach may be plain text', () {
      expect(
        CoachProfile.fromMap('c', <String, Object?>{
          'approach': 'Hi',
        })!.approach,
        'Hi',
      );
    });

    test('empty and wrongly typed documents are not coaches', () {
      expect(CoachProfile.fromMap('c', null), isNull);
      expect(CoachProfile.fromMap('c', 3), isNull);
      expect(CoachProfile.fromMap('c', <String, Object?>{}), isNull);
      expect(CoachProfile.fromMap('', <String, Object?>{'a': 1}), isNull);
    });

    test('a package needs a title and a price to show', () {
      final p = CoachPackage.fromMap('p1', <String, Object?>{
        'title': 'Starter',
        'priceFinalEgp': 2312,
        'durationDays': 56,
        'liveSessionsPerMonth': 3,
        'active': true,
        'includes': <Object?>['Chat', 4],
      })!;
      expect(p.includes, <String>['Chat']);
      expect(p.sessionsIncluded, 6);
      expect(p.monthlyEquivalent, 1156);
      expect(
        CoachPackage.fromMap('p', <String, Object?>{'title': 'x'}),
        isNull,
      );
      expect(
        CoachPackage.fromMap('p', <String, Object?>{'priceFinalEgp': 5}),
        isNull,
      );
    });

    test('a package draft prices, shows the coach share and validates', () {
      const draft = PackageDraft(
        title: 'Starter',
        includes: <String>['Weekly plan'],
        coachPriceEgp: 1000,
      );
      expect(draft.priceFinalEgp, 1150);
      expect(draft.youReceiveEgp, 1000);
      expect(draft.problems(), isEmpty);
      expect(draft.toRequest()['coachPriceEgp'], 1000);
      expect(
        const PackageDraft(title: '', coachPriceEgp: 100).problems(),
        <String>['title', 'coachPriceEgp'],
      );
      expect(
        const PackageDraft(
          title: 't',
          coachPriceEgp: 500,
          durationDays: 30,
          liveSessionsPerMonth: 1,
          sessionMinutes: 20,
          checkInsPerWeek: 9,
          order: 6,
          includes: <String>['', 'x'],
        ).problems(),
        unorderedEquals(<String>[
          'durationDays',
          'includes',
          'liveSessionsPerMonth',
          'sessionMinutes',
          'checkInsPerWeek',
          'order',
        ]),
      );
    });
  });

  group('Intake', () {
    test('a valid intake sends all seven health answers', () {
      final request = validIntake().toRequest();
      expect((request['health'] as Map).length, 7);
      expect(request.containsKey('lifeStage'), isFalse);
      expect(validIntake().problems(), isEmpty);
    });

    test('any yes needs the doctor tick', () {
      final yes = validIntake().copyWith(
        health: {...validIntake().health, 'heart': true},
      );
      expect(yes.needsDoctorAck, isTrue);
      expect(yes.problems(), <String>['doctorAck']);
      expect(yes.copyWith(doctorAck: true).problems(), isEmpty);
      expect(validIntake().needsDoctorAck, isFalse);
    });

    test('every field has its own check', () {
      final bad = Intake(
        goal: 'x',
        level: 'y',
        daysPerWeek: 9,
        place: 'z',
        allergies: <String>['', 'a' * 31],
        note: 'n',
      );
      expect(
        bad.problems(),
        containsAll(<String>[
          'goal',
          'level',
          'daysPerWeek',
          'place',
          'allergies',
          'health',
        ]),
      );
      expect(validIntake().copyWith(note: 'a' * 501).problems(), <String>[
        'note',
      ]);
      expect(
        validIntake().copyWith(allergies: List.filled(17, 'egg')).problems(),
        <String>['allergies'],
      );
    });

    test('reads health as a map or as a list of seven', () {
      final asList = Intake.fromMap(<String, Object?>{
        'health': <Object?>[false, true, false, false, false, false, false],
      });
      expect(asList.health['chestPain'], isTrue);
      expect(asList.health['heart'], isFalse);
      final asMap = Intake.fromMap(<String, Object?>{
        'health': <String, Object?>{
          'heart': true,
          'nope': true,
          'chestPain': 3,
        },
      });
      expect(asMap.health, <String, bool>{'heart': true});
      expect(asMap.answeredAllHealth, isFalse);
    });

    test('round trip', () {
      final intake = validIntake().copyWith(
        allergies: const <String>['egg'],
        lifeStage: 'postpartum',
        note: 'knees',
      );
      final again = Intake.fromMap(intake.toRequest());
      expect(again.toRequest(), intake.toRequest());
    });

    test('Intake flags', () {
      expect(const Intake(lifeStage: 'postpartum').anyFlag, isTrue);
      expect(const Intake(eatingHistory: true).anyFlag, isTrue);
      expect(const Intake(health: {'heart': true}).anyFlag, isTrue);
      expect(const Intake().anyFlag, isFalse);
      expect(Intake.fromMap({'eatingHistory': true}).eatingHistory, isTrue);
      expect(
        const Intake(eatingHistory: true).toRequest()['eatingHistory'],
        isTrue,
      );
    });

    test('Intake.eatingHistoryFlag', () {
      expect(const Intake(eatingHistory: true).eatingHistoryFlag, isTrue);
      expect(const Intake().eatingHistoryFlag, isFalse);
      expect(Intake.fromMap({'eatingHistory': true}).eatingHistoryFlag, isTrue);
      expect(
        Intake.fromMap({
          'health': {'eatingHistory': true},
        }).eatingHistoryFlag,
        isTrue,
      );
    });
  });

  group('Subscription', () {
    final start = DateTime.utc(2026, 10, 1);

    test('reads a document and survives missing and unknown fields', () {
      expect(Subscription.fromMap('s', null), isNull);
      expect(
        Subscription.fromMap('s', <String, Object?>{
          'coachUid': 'c',
          'clientUid': 'u',
          'status': 'from_the_future',
        }),
        isNull,
      );
      expect(
        Subscription.fromMap('s', <String, Object?>{'status': 'active'}),
        isNull,
      );
      final sub = Subscription.fromMap('s', <String, Object?>{
        'coachUid': 'c',
        'clientUid': 'u',
        'status': 'awaiting_payment',
        'payBy': '2026-10-27T12:00:00Z',
        'paymentCode': 'OH123456',
        'payment': <String, Object?>{
          'state': 'rejected',
          'attempts': 1,
          'lastReason': 'amount_wrong',
        },
        'payTo': <String, Object?>{
          'instapay': <String, Object?>{
            'address': 'ownhub@instapay',
            'holderName': 'Own Hub',
            'enabled': true,
          },
          'version': 3,
        },
        'cancellation': <String, Object?>{'state': 'nonsense'},
      })!;
      expect(sub.status, SubscriptionStatus.awaitingPayment);
      expect(sub.payment.stage, PaymentStage.rejected);
      expect(sub.payment.lastReason, ProofRejectReason.amountWrong);
      expect(sub.payTo!.usableRails, <String>['instapay']);
      expect(sub.cancellation, isNull);
      expect(sub.payBy, DateTime.utc(2026, 10, 27, 12));
    });

    test('isOpen and canCancelRequest by status', () {
      for (final status in SubscriptionStatus.values) {
        final s = sub('s', status);
        expect(
          s.isOpen,
          const {
            SubscriptionStatus.requested,
            SubscriptionStatus.awaitingPayment,
            SubscriptionStatus.paymentReview,
            SubscriptionStatus.active,
          }.contains(status),
        );
        expect(
          s.canCancelRequest,
          status == SubscriptionStatus.requested ||
              status == SubscriptionStatus.awaitingPayment,
        );
      }
    });

    test('payBy and sending a proof', () {
      final s = sub(
        's',
        SubscriptionStatus.awaitingPayment,
        payBy: kNow.add(const Duration(hours: 2)),
      );
      expect(s.payByPassed(kNow), isFalse);
      expect(s.canSendProof(kNow), isTrue);
      expect(s.payByPassed(kNow.add(const Duration(hours: 3))), isTrue);
      expect(s.canSendProof(kNow.add(const Duration(hours: 3))), isFalse);
      expect(
        sub(
          's',
          SubscriptionStatus.awaitingPayment,
          payBy: kNow.add(const Duration(hours: 2)),
          attempts: CoachingLimits.proofAttempts,
        ).canSendProof(kNow),
        isFalse,
      );
      expect(
        sub('s', SubscriptionStatus.awaitingPayment).canSendProof(kNow),
        isFalse,
        reason: 'no deadline means nothing to pay yet',
      );
      expect(
        sub(
          's',
          SubscriptionStatus.paymentReview,
          payBy: kNow.add(const Duration(hours: 2)),
        ).canSendProof(kNow),
        isFalse,
      );
      expect(
        sub(
          's',
          SubscriptionStatus.awaitingPayment,
          attempts: 2,
        ).proofAttemptsLeft,
        1,
      );
    });

    test('cancel window is 14 days from the start and only while active', () {
      final active = sub('s', SubscriptionStatus.active, startsAt: start);
      expect(
        active.inCancelWindow(start.add(const Duration(days: 13))),
        isTrue,
      );
      expect(
        active.inCancelWindow(start.add(const Duration(days: 14))),
        isTrue,
      );
      expect(
        active.inCancelWindow(start.add(const Duration(days: 14, minutes: 1))),
        isFalse,
      );
      expect(
        sub(
          's',
          SubscriptionStatus.ended,
          startsAt: start,
        ).inCancelWindow(start),
        isFalse,
      );
      expect(
        sub('s', SubscriptionStatus.active).inCancelWindow(start),
        isFalse,
      );
    });

    test('she may ask to cancel once', () {
      final at = start.add(const Duration(days: 2));
      expect(
        sub(
          's',
          SubscriptionStatus.active,
          startsAt: start,
        ).canRequestCancellation(at),
        isTrue,
      );
      expect(
        sub(
          's',
          SubscriptionStatus.active,
          startsAt: start,
          cancellation: const CancellationInfo(
            state: CancellationState.requested,
          ),
        ).canRequestCancellation(at),
        isFalse,
      );
    });

    test('days left counts a part day as a day, never below zero', () {
      final s = sub(
        's',
        SubscriptionStatus.active,
        endsAt: kNow.add(const Duration(days: 2, hours: 1)),
      );
      expect(s.daysLeft(kNow), 3);
      expect(s.daysLeft(kNow.add(const Duration(days: 2, hours: 1))), 0);
      expect(s.daysLeft(kNow.add(const Duration(days: 9))), 0);
      expect(
        sub('s', SubscriptionStatus.ended, endsAt: kNow).daysLeft(kNow),
        isNull,
      );
      expect(s.endsSoon(kNow), isTrue);
      expect(s.endsSoon(kNow.subtract(const Duration(days: 2))), isFalse);
    });

    test('refund if cancelled follows the contract formula', () {
      expect(
        sub(
          's',
          SubscriptionStatus.active,
          sessionsUsed: 1,
        ).refundIfCancelled(),
        1150 - 287,
      );
      expect(
        sub(
          's',
          SubscriptionStatus.active,
          sessionsIncluded: 0,
        ).refundIfCancelled(),
        0,
      );
    });
  });

  group('LiveSession and Relationship', () {
    test('a session is waiting on the other party after one mark', () {
      final s = LiveSession.fromMap('x', <String, Object?>{
        'status': 'confirmed',
        'doneBy': <String>['me'],
      })!;
      expect(s.doneByMe('me'), isTrue);
      expect(s.doneByMe('her'), isFalse);
      expect(s.waitingForOther('me'), isTrue);
      expect(s.waitingForOther('her'), isFalse);
      final both = LiveSession.fromMap('x', <String, Object?>{
        'status': 'done',
        'doneBy': <String>['me', 'her'],
      })!;
      expect(both.waitingForOther('me'), isFalse);
      expect(both.doneByMe('her'), isTrue);
    });

    test('reads a session and rejects an unknown status', () {
      final s = LiveSession.fromMap('x', <String, Object?>{
        'status': 'confirmed',
        'startsAt': DateTime.utc(2026, 10, 25, 18),
        'minutes': 30,
        'doneBy': 'u1',
      })!;
      expect(s.doneBy, <String>['u1']);
      expect(s.isUpcoming, isTrue);
      expect(s.canMarkDone(DateTime.utc(2026, 10, 25, 17)), isFalse);
      expect(s.canMarkDone(DateTime.utc(2026, 10, 25, 18)), isTrue);
      expect(
        LiveSession.fromMap('x', <String, Object?>{'status': 'zzz'}),
        isNull,
      );
      expect(
        LiveSession.fromMap('x', <String, Object?>{
          'status': 'proposed',
        })!.canMarkDone(kNow),
        isFalse,
      );
    });

    test('a relationship needs both parties', () {
      final r = Relationship.fromMap('c__u', <String, Object?>{
        'coachUid': 'c',
        'clientUid': 'u',
        'status': 'active',
        'chatOpen': true,
      })!;
      expect(r.otherParty('c'), 'u');
      expect(r.otherParty('u'), 'c');
      expect(
        Relationship.fromMap('x', <String, Object?>{'status': 'active'}),
        isNull,
      );
    });
  });

  group('payments', () {
    PaymentProofForm form({
      String rail = 'instapay',
      String reference = 'ABC123456',
      int amount = 1150,
      DateTime? paidAt,
      String sender = 'Mona Adel',
      Uint8List? image,
    }) => PaymentProofForm(
      rail: rail,
      reference: reference,
      amountEgp: amount,
      paidAt: paidAt ?? kNow.subtract(const Duration(hours: 1)),
      senderName: sender,
      imageJpeg: image ?? Uint8List.fromList(<int>[1, 2, 3]),
    );

    test('a good form has no problems', () {
      expect(form().problems(kNow), isEmpty);
      expect(form().isValid(kNow), isTrue);
    });

    test('each field fails on its own', () {
      expect(
        form(rail: 'card').problems(kNow),
        contains(PaymentProofProblem.rail),
      );
      expect(form(reference: '12').problems(kNow), <PaymentProofProblem>[
        PaymentProofProblem.reference,
      ]);
      expect(
        form(reference: 'has space 123').problems(kNow),
        <PaymentProofProblem>[PaymentProofProblem.reference],
      );
      expect(form(amount: 0).problems(kNow), <PaymentProofProblem>[
        PaymentProofProblem.amount,
      ]);
      expect(form(amount: 34501).problems(kNow), <PaymentProofProblem>[
        PaymentProofProblem.amount,
      ]);
      expect(form(amount: 34500).problems(kNow), isEmpty);
      expect(form(sender: 'M').problems(kNow), <PaymentProofProblem>[
        PaymentProofProblem.senderName,
      ]);
      expect(form(image: Uint8List(0)).problems(kNow), <PaymentProofProblem>[
        PaymentProofProblem.image,
      ]);
      expect(
        form(image: Uint8List(CoachingLimits.proofMaxBytes + 1)).problems(kNow),
        <PaymentProofProblem>[PaymentProofProblem.image],
      );
    });

    test('the payment time may not be in the future or a week old', () {
      expect(
        form(paidAt: kNow.add(const Duration(minutes: 4))).problems(kNow),
        isEmpty,
      );
      expect(
        form(paidAt: kNow.add(const Duration(minutes: 6))).problems(kNow),
        <PaymentProofProblem>[PaymentProofProblem.paidAt],
      );
      expect(
        form(paidAt: kNow.subtract(const Duration(days: 8))).problems(kNow),
        <PaymentProofProblem>[PaymentProofProblem.paidAt],
      );
      expect(
        const PaymentProofForm(
          rail: 'instapay',
          reference: 'ABC123456',
          amountEgp: 5,
          senderName: 'Mona',
        ).problems(kNow),
        containsAll(<PaymentProofProblem>[
          PaymentProofProblem.paidAt,
          PaymentProofProblem.image,
        ]),
      );
    });

    test(
      'the request carries the picture as base64 and the time with an offset',
      () {
        final request = form(paidAt: DateTime.utc(2026, 10, 24, 9, 5, 7, 123))
            .toRequest(subId: 's1', locale: 'ar');
        expect(request['imageJpeg'], 'AQID');
        expect(request['paidAt'], '2026-10-24T09:05:07+00:00');
        expect(request['subId'], 's1');
      },
    );

    test('receiving accounts list only rails that are on', () {
      final accounts = ReceivingAccounts.fromMap(<String, Object?>{
        'instapay': <String, Object?>{
          'address': 'a@instapay',
          'enabled': false,
        },
        'vodafoneCash': <String, Object?>{
          'address': '01012345678',
          'enabled': true,
        },
        'version': 4,
      });
      expect(accounts.usableRails, <String>['vodafoneCash']);
      expect(accounts.forRail('card'), isNull);
      expect(ReceivingAccounts.fromMap(null).isEmpty, isTrue);
      expect(accounts.version, 4);
    });

    test('seller details pick the language and say when complete', () {
      const seller = SellerDetails(
        companyNameEn: 'Own Hub LLC',
        companyNameAr: 'أون هب',
        addressEn: 'Cairo',
        commercialRegistration: '123',
        taxCard: '456',
      );
      expect(seller.companyName(arabic: true), 'أون هب');
      expect(seller.address(arabic: true), 'Cairo');
      expect(seller.complete, isTrue);
      expect(const SellerDetails().complete, isFalse);
    });

    test('a receipt needs a number and keeps the refund', () {
      expect(Receipt.fromMap('s', <String, Object?>{'number': ''}), isNull);
      final receipt = Receipt.fromMap('s', <String, Object?>{
        'number': 'OH-2026-000001',
        'line': <String, Object?>{'en': 'Coaching', 'ar': 'تدريب'},
        'priceFinalEgp': 1150,
        'refund': <String, Object?>{'amountEgp': 500, 'rail': 'instapay'},
      })!;
      expect(receipt.lineFor(arabic: true), 'تدريب');
      expect(receipt.refund!.amountEgp, 500);
      expect(
        Receipt.fromMap('s', <String, Object?>{
          'number': 'x',
          'line': 'Plain',
        })!.lineFor(arabic: true),
        'Plain',
      );
    });
  });

  group('plans', () {
    test('a meal plan round trips and drops what it cannot read', () {
      const body = MealPlanBody(
        days: <MealDay>[
          MealDay(
            label: 'Day 1',
            slots: <String, List<MealItem>>{
              'breakfast': <MealItem>[
                MealItem.recipe('r1', 1.5, note: 'warm'),
                MealItem.food('f1', 120),
              ],
              'dinner': <MealItem>[MealItem.free('Her choice')],
            },
          ),
        ],
      );
      expect(body.isValid, isTrue);
      final json = body.toJson();
      final again = MealPlanBody.tryParse(json)!;
      expect(again.toJson(), json);
      final slots = (json['days'] as List).first['slots'] as Map;
      expect(slots.keys, CoachingEnums.mealSlots);

      final dirty = MealPlanBody.tryParse(<String, Object?>{
        'days': <Object?>[
          5,
          <String, Object?>{'label': ''},
          <String, Object?>{
            'label': 'Day',
            'slots': <String, Object?>{
              'lunch': <Object?>[
                <String, Object?>{'kind': 'recipe'},
                <String, Object?>{'kind': 'free', 'text': 'Salad'},
                <String, Object?>{'kind': 'alien'},
              ],
              'brunch': <Object?>[],
            },
          },
        ],
      })!;
      expect(dirty.days, hasLength(1));
      expect(dirty.days.single.itemsIn('lunch'), hasLength(1));
      expect(MealPlanBody.tryParse('x'), isNull);
    });

    test('meal limits match the server', () {
      expect(const MealItem.recipe('r', 0.2).isValid, isFalse);
      expect(const MealItem.recipe('r', 6).isValid, isTrue);
      expect(const MealItem.recipe('r', 6.5).isValid, isFalse);
      expect(const MealItem.food('f', 0).isValid, isFalse);
      expect(const MealItem.food('f', 2000).isValid, isTrue);
      expect(MealItem.free('x' * 81).isValid, isFalse);
      expect(const MealItem.free('  ').isValid, isFalse);
      expect(MealItem.free('ok', note: 'n' * 121).isValid, isFalse);
      expect(const MealPlanBody().isValid, isFalse);
      expect(MealDay(label: 'x' * 41).isValid, isFalse);
      expect(
        MealDay(
          label: 'd',
          slots: {'lunch': List.filled(13, const MealItem.free('x'))},
        ).isValid,
        isFalse,
      );
      expect(
        MealPlanBody(days: List.filled(8, const MealDay(label: 'd'))).isValid,
        isFalse,
      );
    });

    test('MealGoal and swaps round trip', () {
      final input = <String, Object?>{
        'days': <Object?>[
          <String, Object?>{
            'label': 'Day 1',
            'slots': <String, Object?>{
              for (final s in CoachingEnums.mealSlots) s: <Object?>[],
              'breakfast': <Object?>[
                <String, Object?>{
                  'kind': 'recipe',
                  'recipeId': 'r1',
                  'servings': 1.0,
                  'swaps': <String>['r2', 'r3'],
                },
              ],
            },
          },
        ],
        'goal': <String, Object?>{'kcalPerDay': 1600, 'proteinGPerDay': 110},
      };
      final body = MealPlanBody.tryParse(input)!;
      expect(body.goal, isNotNull);
      expect(body.goal!.kcalPerDay, 1600);
      expect(body.goal!.proteinGPerDay, 110);
      expect(body.days.first.itemsIn('breakfast').first.swaps, ['r2', 'r3']);
      expect(body.toJson(), input);

      final badGoal = MealPlanBody.tryParse(<String, Object?>{
        'days': input['days'],
        'goal': <String, Object?>{'kcalPerDay': 100, 'proteinGPerDay': 110},
      })!;
      expect(badGoal.goal, isNull);
    });

    test('mealPlanWithDays keeps the goal', () {
      const goal = MealGoal(kcalPerDay: 1800, proteinGPerDay: 120);
      const body = MealPlanBody(
        days: <MealDay>[MealDay(label: 'Day 1')],
        goal: goal,
      );
      final grown = mealPlanWithDays(body, 3, (n) => 'Day $n');
      expect(grown.goal, goal);
      expect(grown.days.length, 3);

      final withItem = mealPlanWithItem(
        body,
        0,
        'lunch',
        const MealItem.free('Soup'),
      );
      expect(withItem.goal, goal);

      final withGoal = mealPlanWithGoal(grown, null);
      expect(withGoal.goal, isNull);

      final withSwaps = mealPlanWithSwaps(
        const MealPlanBody(
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'breakfast': [MealItem.recipe('r1', 1.0)],
              },
            ),
          ],
          goal: goal,
        ),
        0,
        'breakfast',
        0,
        ['r2', 'r3', 'r1', 'r4'],
      );
      expect(withSwaps.goal, goal);
      expect(withSwaps.days.first.itemsIn('breakfast').first.swaps, [
        'r2',
        'r3',
        'r4',
      ]);
    });

    test('a coach plan reads by kind and skips a body of the wrong shape', () {
      final workout = CoachPlan.fromMap('p1', <String, Object?>{
        'kind': 'workout',
        'coachUid': 'c',
        'name': 'Week 1',
        'revision': 2,
        'body': const MyPlan.blank().toJson(),
      });
      expect(workout?.workout?.isBlank, isTrue);
      expect(workout?.meal, isNull);
      final meal = CoachPlan.fromMap('p2', <String, Object?>{
        'kind': 'meal',
        'name': 'Meals',
        'body': <String, Object?>{'days': <Object?>[]},
        'publishedAt': DateTime.utc(2026, 10, 24),
      })!;
      expect(meal.kind, PlanKind.meal);
      expect(meal.meal, isNotNull);
      expect(meal.workout, isNull);
      expect(
        CoachPlan.fromMap('p', <String, Object?>{'kind': 'x', 'body': {}}),
        isNull,
      );
      expect(CoachPlan.fromMap('p', <String, Object?>{'kind': 'meal'}), isNull);
    });

    test('a workout plan is read with the MyPlan parser', () {
      final plan = CoachPlan.fromMap('p1', <String, Object?>{
        'kind': 'workout',
        'name': 'Week 1',
        'body': <String, Object?>{
          'revision': 1,
          'days': <Object?>[
            <String, Object?>{
              'session': <String, Object?>{
                'sessionId': 'mine_1',
                'titleEn': 'Legs',
                'titleAr': 'رجل',
                'minutes': 30,
                'moves': <Object?>[
                  <String, Object?>{
                    'exerciseId': 'squat',
                    'nameEn': 'Squat',
                    'nameAr': 'سكوات',
                    'sets': 3,
                    'reps': 10,
                  },
                ],
              },
            },
          ],
        },
      });
      expect(plan?.workout?.days, hasLength(1));
    });

    test('CoachPlan reads startsOn', () {
      final body = <String, Object?>{
        'revision': 1,
        'days': <Object?>[
          <String, Object?>{
            'session': <String, Object?>{
              'sessionId': 'mine_1',
              'titleEn': 'Legs',
              'titleAr': 'رجل',
              'minutes': 30,
              'moves': <Object?>[
                <String, Object?>{
                  'exerciseId': 'squat',
                  'nameEn': 'Squat',
                  'nameAr': 'سكوات',
                  'sets': 3,
                  'reps': 10,
                },
              ],
            },
          },
        ],
      };
      expect(
        CoachPlan.fromMap('p', <String, Object?>{
          'kind': 'workout',
          'body': body,
          'startsOn': '2026-11-07',
        })!.startsOn,
        DateTime(2026, 11, 7, 12),
      );
      expect(
        CoachPlan.fromMap('p', <String, Object?>{
          'kind': 'workout',
          'body': body,
          'startsOn': 'bad',
        })!.startsOn,
        isNull,
      );
    });

    test('publish request holds exactly one body', () {
      final request = publishPlanRequest(
        subId: 's',
        name: '  Week 1  ',
        meal: const MealPlanBody(),
      );
      expect(request['kind'], 'meal');
      expect(request['name'], 'Week 1');
      expect(request.containsKey('planId'), isFalse);
    });

    test('drafts keep their body and drop unknown kinds', () {
      expect(
        CoachDraft.fromMap('d', <String, Object?>{
          'kind': 'meal',
          'name': 'Template',
          'body': <String, Object?>{'days': <Object?>[]},
        })!.name,
        'Template',
      );
      expect(CoachDraft.fromMap('d', <String, Object?>{'kind': 'x'}), isNull);
      expect(
        CoachDraft.fromMap('d', <String, Object?>{'kind': 'meal'}),
        isNull,
      );
    });
  });

  group('ChatMessage', () {
    test('reads each type and skips a type from the future', () {
      final text = ChatMessage.fromMap('m1', <String, Object?>{
        'senderUid': 'me',
        'type': 'text',
        'text': 'Hi',
        'createdAt': DateTime.utc(2026, 10, 24),
      })!;
      expect(text.isMine('me'), isTrue);
      expect(text.showsText, isTrue);
      final plan = ChatMessage.fromMap('m2', <String, Object?>{
        'senderUid': 'c',
        'type': 'workoutPlan',
        'planId': 'p1',
        'planKind': 'workout',
        'planName': 'Week 1',
      })!;
      expect(plan.planKind, PlanKind.workout);
      expect(plan.createdAt, isNull);
      final hidden = ChatMessage.fromMap('m3', <String, Object?>{
        'type': 'system',
        'systemKind': 'hidden',
      })!;
      expect(hidden.hidden, isTrue);
      expect(
        ChatMessage.fromMap('m4', <String, Object?>{'type': 'voice'}),
        isNull,
      );
      expect(ChatMessage.fromMap('m5', 'x'), isNull);
      expect(
        ChatMessage.fromMap('m6', <String, Object?>{
          'type': 'text',
          'text': 'secret',
          'hidden': true,
        })!.showsText,
        isFalse,
      );
    });

    test('empty and over-long texts are refused before sending', () {
      expect(ChatMessage.problemWith('   '), MessageProblem.empty);
      expect(ChatMessage.problemWith('a' * 2001), MessageProblem.tooLong);
      expect(ChatMessage.problemWith('a' * 2000), isNull);
    });
  });

  group('coach money', () {
    test('ledger lines turn owed when their time has come', () {
      final pending = LedgerEntry.fromMap('s', <String, Object?>{
        'status': 'pending',
        'coachAmountEgp': 1000,
        'eligibleAt': kNow,
      })!;
      expect(pending.isOwed(kNow.subtract(const Duration(days: 1))), isFalse);
      expect(pending.isOwed(kNow), isTrue);
      expect(
        LedgerEntry.fromMap('s', <String, Object?>{
          'status': 'eligible',
        })!.isOwed(kNow),
        isTrue,
      );
      expect(
        LedgerEntry.fromMap('s', <String, Object?>{
          'status': 'paid',
        })!.isOwed(kNow),
        isFalse,
      );
      expect(
        LedgerEntry.fromMap('s', <String, Object?>{'status': 'zz'}),
        isNull,
      );
    });

    test('summary reads the payout and a pending change', () {
      final summary = CoachPrivateSummary.fromMap(<String, Object?>{
        'fullName': 'Sara',
        'payout': <String, Object?>{
          'rail': 'instapay',
          'account': 'sara@instapay',
          'holderName': 'Sara',
        },
        'payoutState': 'pending',
        'pendingPayout': <String, Object?>{
          'rail': 'vodafoneCash',
          'account': '010',
        },
        'owedEgp': 2000,
      })!;
      expect(summary.payoutState, PayoutAccountState.pending);
      expect(summary.hasPendingChange, isTrue);
      expect(summary.owedEgp, 2000);
      expect(CoachPrivateSummary.fromMap(<String, Object?>{}), isNull);
      expect(CoachPrivateSummary.fromMap(null), isNull);
    });

    test('summary reads the check, the suspension and the pending claim', () {
      final s = CoachPrivateSummary.fromMap(<String, Object?>{
        'fullName': 'Sara',
        'payoutNameMatches': false,
        'suspended': true,
        'suspendReason': 'report',
        'suspendedAt': kNow,
        'claimPending': true,
      })!;
      expect(s.payoutNameMatches, isFalse);
      expect(s.suspended, isTrue);
      expect(s.suspendReason, 'report');
      expect(s.suspendedAt, kNow);
      expect(s.claimPending, isTrue);
      final plain = CoachPrivateSummary.fromMap(<String, Object?>{
        'fullName': 'Sara',
      })!;
      expect(plain.payoutNameMatches, isNull);
      expect(plain.suspended, isFalse);
      expect(plain.claimPending, isFalse);
    });

    test('the ledger names a client by her short code', () {
      LedgerEntry entry(String label) =>
          LedgerEntry.fromMap('s', {'status': 'paid', 'clientLabel': label})!;
      expect(entry('#A1B2').clientTag, '#A1B2');
      expect(entry('A1B2').clientTag, '#A1B2');
      expect(entry('').clientTag, '');
    });

    test('a payout reads its lines', () {
      final payout = Payout.fromMap('p', <String, Object?>{
        'amountEgp': 3000,
        'entryIds': <Object?>['a', 2, 'b'],
      })!;
      expect(payout.entryIds, <String>['a', 'b']);
    });
  });

  group('session links and times', () {
    test('only https links to meeting hosts', () {
      for (final ok in <String>[
        'https://meet.google.com/abc-defg-hij',
        'https://zoom.us/j/123',
        'https://us02web.zoom.us/j/123',
        'https://teams.microsoft.com/l/meetup',
      ]) {
        expect(sessionLinkAllowed(ok), isTrue, reason: ok);
      }
      for (final bad in <String>[
        '',
        'http://meet.google.com/a',
        'https://zoom.us.evil.com/j/1',
        'https://evil.com/zoom.us',
        'https://meet.google.com:8080/a',
        'https://user@meet.google.com/a',
        'https://meet.google.com/a b',
        'https://zoom.us/ا',
        'https://zoom.us/${'a' * 300}',
        'meet.google.com/a',
        'https://.zoom.us/a',
      ]) {
        expect(sessionLinkAllowed(bad), isFalse, reason: bad);
      }
    });

    test('wire time is UTC with an offset and no fraction', () {
      expect(
        wireTime(DateTime.utc(2026, 1, 2, 3, 4, 5, 678)),
        '2026-01-02T03:04:05+00:00',
      );
      expect(
        wireTime(DateTime.parse('2026-10-24T20:30:00+02:00')),
        '2026-10-24T18:30:00+00:00',
      );
    });
  });
}
