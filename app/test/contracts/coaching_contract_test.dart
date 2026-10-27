// The client half of the private coaching contract.
//
// `contracts/coaching_contract.json` is read here and by the functions'
// `tests/test_coaching_contract.py`. Neither side may edit it alone.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_sheets.dart'
    show chatRulesText;
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/data/firestore_coaching_repository.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/payments.dart';
import 'package:own_hub/features/private_coaching/domain/requests.dart';
import 'package:own_hub/features/private_coaching/domain/session_link.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';

Map<String, dynamic> _contract() =>
    jsonDecode(File('../contracts/coaching_contract.json').readAsStringSync())
        as Map<String, dynamic>;

Matcher _sameKeys(Object? expected) =>
    unorderedEquals((expected as Iterable).map((e) => e.toString()));

void main() {
  _consentTextsMatchTheApp();
  final contract = _contract();
  final limits = contract['limits'] as Map<String, dynamic>;
  final enums = contract['enums'] as Map<String, dynamic>;
  final callables = contract['callables'] as Map<String, dynamic>;
  final documents = contract['documents'] as Map<String, dynamic>;

  test('the server copy of the contract is identical', () {
    final copy = File('../functions/coaching/coaching_contract.json');
    expect(
      copy.readAsStringSync(),
      File('../contracts/coaching_contract.json').readAsStringSync(),
    );
  });

  group('limits', () {
    test('every limit the contract has is defined, with the same value', () {
      expect(CoachingLimits.all.keys, _sameKeys(limits.keys));
      for (final entry in limits.entries) {
        expect(CoachingLimits.all[entry.key], entry.value, reason: entry.key);
      }
    });

    test('the region is the one the app calls', () {
      expect(CoachingIds.region, contract['region']);
    });
  });

  group('enums', () {
    test('every enum the contract has is defined, value for value', () {
      expect(CoachingEnums.all.keys, _sameKeys(enums.keys));
      for (final entry in enums.entries) {
        expect(CoachingEnums.all[entry.key], entry.value, reason: entry.key);
      }
    });

    test('typed enums carry exactly the contract values', () {
      List<String> wires(Iterable<dynamic> values) => <String>[
        for (final v in values) (v as dynamic).wire as String,
      ];
      expect(wires(ApplicationStatus.values), enums['applicationStatus']);
      expect(wires(SubscriptionStatus.values), enums['subscriptionStatus']);
      expect(wires(SessionStatus.values), enums['sessionStatus']);
      expect(wires(ProofStatus.values), enums['proofStatus']);
      expect(wires(PaymentStage.values), enums['paymentState']);
      expect(wires(LedgerStatus.values), enums['ledgerStatus']);
      expect(wires(RelationshipStatus.values), enums['relationshipStatus']);
      expect(wires(PlanKind.values), enums['planKind']);
      expect(wires(PayoutAccountState.values), enums['payoutAccountState']);
      expect(wires(CancellationState.values), enums['cancellationState']);
      expect(wires(SystemMessageKind.values), enums['systemMessageKinds']);
      expect(wires(CoachDeclineReason.values), enums['declineReasons']);
      expect(wires(ProofRejectReason.values), enums['proofRejectReasons']);
      expect(wires(ProofFlag.values), enums['proofFlags']);
      expect(wires(MealItemKind.values), enums['mealItemKind']);
    });

    test('message types are the client types plus the server types', () {
      expect(MessageType.values.map((t) => t.wire), <Object?>[
        ...(enums['messageTypeClient'] as List),
        ...(enums['messageTypeServer'] as List),
      ]);
      expect(
        MessageType.values.where((t) => t.writtenByApp).map((t) => t.wire),
        enums['messageTypeClient'],
      );
    });

    test('subscriptionOpen is what isOpen means', () {
      for (final status in SubscriptionStatus.values) {
        final sub = Subscription(
          id: 's',
          coachUid: 'c',
          clientUid: 'u',
          status: status,
        );
        expect(
          sub.isOpen,
          (enums['subscriptionOpen'] as List).contains(status.wire),
          reason: status.wire,
        );
      }
    });

    test('the badges the profile reads are the contract badges', () {
      final badges = (documents['coach'] as Map)['badges'] as List;
      final profile = CoachProfile.fromMap('c', {'badges': badges, 'x': 1});
      expect(profile!.badges, badges);
    });
  });

  group('reasons', () {
    test('every contract reason has a refusal with the same code', () {
      final reasons = (contract['reasons'] as List).cast<String>();
      for (final reason in reasons) {
        expect(CoachingRefusal.fromCode(reason).code, reason, reason: reason);
      }
    });

    test('the refusals the app adds are exactly the local ones', () {
      final reasons = (contract['reasons'] as List).cast<String>().toSet();
      final extra = <String>{
        for (final r in CoachingRefusal.values)
          if (!reasons.contains(r.code)) r.code,
      };
      expect(extra, <String>{
        for (final r in CoachingRefusal.localOnly) r.code,
      });
      expect(extra, isNot(containsAll(reasons)));
    });

    test('staff_is_subject is a known refusal', () {
      expect(
        CoachingRefusal.fromCode('staff_is_subject'),
        CoachingRefusal.staffIsSubject,
      );
    });

    test('codes are unique', () {
      final codes = CoachingRefusal.values.map((r) => r.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  group('rails, ids and callables', () {
    test('rail patterns', () {
      final rails = contract['rails'] as Map<String, dynamic>;
      expect(CoachingRails.names, rails.keys);
      for (final rail in rails.entries) {
        final spec = rail.value as Map<String, dynamic>;
        expect(CoachingRails.accountPattern[rail.key], spec['accountPattern']);
        expect(
          CoachingRails.referencePattern[rail.key],
          spec['referencePattern'],
        );
      }
    });

    test('ids and session link hosts', () {
      final ids = contract['ids'] as Map<String, dynamic>;
      expect(CoachingIds.paymentCodePattern, ids['paymentCode']);
      expect(CoachingIds.paymentCodeAlphabet, ids['paymentCodeAlphabet']);
      expect(CoachingIds.sessionLinkHosts, contract['sessionLinkHosts']);
      expect(CoachingIds.relationshipId('c1', 'u1'), 'c1__u1');
    });

    test('callable names', () {
      expect(CoachingCallables.all, callables.keys);
    });
  });

  group('request bodies carry exactly the contract request keys', () {
    List<dynamic> keysOf(String callable) =>
        callables[callable]['requestKeys'] as List<dynamic>;

    test('submit_coach_application', () {
      expect(
        CoachApplication().toRequest(locale: 'en').keys,
        _sameKeys(keysOf('submit_coach_application')),
      );
    });

    test('save_coach_package: packageId only when the package exists', () {
      final keys = keysOf('save_coach_package').cast<String>();
      expect(
        const PackageDraft(packageId: 'p1').toRequest().keys,
        _sameKeys(keys),
      );
      expect(
        const PackageDraft().toRequest().keys,
        _sameKeys(keys.where((k) => k != 'packageId')),
      );
    });

    test('request_coaching', () {
      expect(
        CoachingRequests.requestCoaching(
          coachUid: 'c',
          packageId: 'p',
          intake: const Intake(),
          consent: const <String, Object?>{},
          locale: 'en',
        ).keys,
        _sameKeys(keysOf('request_coaching')),
      );
    });

    test('respond_coaching_request', () {
      final keys = keysOf('respond_coaching_request').cast<String>();
      expect(
        CoachingRequests.respond(
          subId: 's',
          accept: false,
          declineReason: CoachDeclineReason.full,
        ).keys,
        _sameKeys(keys),
      );
      expect(
        CoachingRequests.respond(subId: 's', accept: true).keys,
        _sameKeys(keys.where((k) => k != 'reason')),
      );
    });

    test('cancel_coaching_request and request_cancellation', () {
      expect(
        CoachingRequests.cancelRequest('s').keys,
        _sameKeys(keysOf('cancel_coaching_request')),
      );
      expect(
        CoachingRequests.cancellation('s', 'why').keys,
        _sameKeys(keysOf('request_cancellation')),
      );
    });

    test('submit_payment_proof', () {
      expect(
        PaymentProofForm(
          imageJpeg: Uint8List(1),
          paidAt: DateTime.utc(2026),
        ).toRequest(subId: 's', locale: 'en').keys,
        _sameKeys(keysOf('submit_payment_proof')),
      );
    });

    test('publish_coach_plan', () {
      final keys = keysOf('publish_coach_plan').cast<String>();
      // A new plan carries every key: its start date, the key that makes a
      // second send of it one plan, and the mark of a build that reviews health.
      expect(
        publishPlanRequest(
          subId: 's',
          name: 'n',
          workout: const MyPlan.blank(),
          startsOn: '2026-11-07',
        ).keys,
        _sameKeys(keys.where((k) => k != 'planId')),
      );
      // A new version of a plan names the plan instead of keying the send.
      expect(
        publishPlanRequest(
          subId: 's',
          name: 'n',
          meal: const MealPlanBody(),
          planId: 'p',
          startsOn: '2026-11-07',
        ).keys,
        _sameKeys(keys.where((k) => k != 'requestKey')),
      );
      // Without a date the key is simply left out.
      expect(
        publishPlanRequest(
          subId: 's',
          name: 'n',
          workout: const MyPlan.blank(),
        ).keys,
        _sameKeys(keys.where((k) => k != 'planId' && k != 'startsOn')),
      );
    });

    test(
      'a plan sent twice has one request key; a different one has another',
      () {
        Object? key({String sub = 's', String name = 'n', String? start}) =>
            publishPlanRequest(
              subId: sub,
              name: name,
              meal: const MealPlanBody(),
              startsOn: start,
            )['requestKey'];
        expect(key(), key());
        expect(key(name: ' n '), key(), reason: 'the name is trimmed first');
        expect(key(sub: 't'), isNot(key()));
        expect(key(name: 'm'), isNot(key()));
        expect(key(start: '2026-11-07'), isNot(key()));
        expect((key() as String).length, inInclusiveRange(8, 64));
      },
    );

    test('live session calls', () {
      expect(
        CoachingRequests.scheduleSession(
          subId: 's',
          startsAt: DateTime.utc(2026),
          minutes: 30,
          link: 'https://meet.google.com/x',
        ).keys,
        _sameKeys(keysOf('schedule_live_session')),
      );
      expect(
        CoachingRequests.respondSession(
          subId: 's',
          sessionId: 'x',
          confirm: true,
        ).keys,
        _sameKeys(keysOf('respond_live_session')),
      );
      expect(
        CoachingRequests.markDone('s', 'x').keys,
        _sameKeys(keysOf('mark_session_done')),
      );
    });

    test('update_coach_profile and record_signup_role', () {
      expect(
        CoachingRequests.updateProfile(
          headline: 'h',
          approachText: 'a',
          photoPath: 'p',
          acceptingClients: true,
          autoAccept: true,
          maxActiveClients: 3,
        ).keys,
        _sameKeys(keysOf('update_coach_profile')),
      );
      expect(
        CoachingRequests.signupRole('coach').keys,
        _sameKeys(keysOf('record_signup_role')),
      );
      expect(
        CoachPayoutAccount().toMap().keys,
        _sameKeys(keysOf('request_payout_account_change')),
      );
    });
  });

  group('documents the app writes or reads', () {
    test('the application sections', () {
      final doc = documents['coachApplication'] as Map<String, dynamic>;
      expect(const CoachPersonal().toMap().keys, _sameKeys(doc['personal']));
      expect(const CoachEducation().toMap().keys, _sameKeys(doc['education']));
      expect(
        const CoachCertificate().toMap().keys,
        _sameKeys(doc['certificate']),
      );
      expect(
        const CoachTestimonial(imagePath: 'x').toMap().keys,
        _sameKeys(doc['testimonial']),
      );
      expect(
        const CoachTransformation().toMap().keys,
        _sameKeys(doc['transformation']),
      );
      expect(const CoachApproach().toMap().keys, _sameKeys(doc['approach']));
      expect(const CoachPayoutAccount().toMap().keys, _sameKeys(doc['payout']));
    });

    test('the intake the client sends', () {
      final doc = documents['subscription'] as Map<String, dynamic>;
      expect(
        const Intake(lifeStage: 'none').toRequest().keys,
        _sameKeys(doc['intake']),
      );
      expect(
        const Intake().toRequest()['health'],
        isA<Map<String, bool>>().having(
          (m) => m.keys,
          'questions',
          _sameKeys(enums['healthQuestions']),
        ),
      );
    });

    test('chat lines the app writes use only client keys', () {
      final doc = documents['message'] as Map<String, dynamic>;
      final allowed = <String>{...(doc['clientKeys'] as List).cast<String>()};
      expect(<String>{
        ...ChatMessage.textFields('u', 't').keys,
        'createdAt',
      }, allowed.difference({'recipeId'}));
      expect(<String>{
        ...ChatMessage.recipeFields('u', 'r').keys,
        'createdAt',
      }, allowed.difference({'text'}));
    });

    test('drafts are written with the draft keys', () {
      final doc = documents['draft'] as Map<String, dynamic>;
      final write = CoachDraft(id: 'd', kind: PlanKind.workout).toWrite();
      expect(<String>{
        ...write.keys,
        'updatedAt',
      }, (doc['keys'] as List).cast<String>().toSet());
    });

    test('a subscription with every contract key reads', () {
      final doc = documents['subscription'] as Map<String, dynamic>;
      final sub = Subscription.fromMap('s1', {
        'coachUid': 'c',
        'clientUid': 'u',
        'status': 'active',
        'priceFinalEgp': 1150,
        'sessionsIncluded': 8,
        'sessionsUsed': 2,
        'package': {for (final k in doc['packageSnapshot'] as List) k: 1},
      });
      expect(sub, isNotNull);
      expect(sub!.relId, 'c__u');
      expect(sub.sessionsLeft, 6);
    });

    test('coach doc keys the profile reads exist in the contract', () {
      final keys = (documents['coach'] as Map)['keys'] as List;
      for (final k in <String>[
        'displayName',
        'headline',
        'photoUrl',
        'governorate',
        'languages',
        'specialties',
        'approach',
        'yearsExperience',
        'certificates',
        'testimonials',
        'badges',
        'stats',
        'fromPriceEgp',
        'fromMonthlyEgp',
        'acceptingClients',
        'autoAccept',
        'maxActiveClients',
        'activeClients',
        'published',
        'replyHours',
        'trainsWhere',
      ]) {
        expect(keys, contains(k));
      }
    });
  });

  group('behaviour the contract fixes', () {
    test('storage folders are the ones the application names', () {
      final names = CoachDocFolder.values.map((f) => f.name).toSet();
      expect(names, <String>{
        'photo',
        'education',
        'certificates',
        'testimonials',
        'transformations',
        'gallery',
      });
      expect(
        coachDocPath(
          uid: 'u1',
          folder: CoachDocFolder.certificates,
          token: 'abc',
          extension: 'pdf',
        ),
        'coach-docs/u1/certificates/abc.pdf',
      );
    });

    test('plan limits', () {
      expect(CoachingLimits.planMaxDays, kMaxPlanDays);
      expect(CoachingLimits.planNameMax, 60);
    });

    test('session links follow the allow-list', () {
      for (final host in contract['sessionLinkHosts'] as List) {
        final h = (host as String).replaceFirst('*.', 'room.');
        expect(sessionLinkAllowed('https://$h/abc'), isTrue, reason: h);
      }
      expect(sessionLinkAllowed('http://meet.google.com/abc'), isFalse);
      expect(sessionLinkAllowed('https://example.com/abc'), isFalse);
    });
  });
}

void _consentTextsMatchTheApp() {
  group('the consent texts the app shows are the ones the server accepts', () {
    final texts = _contract()['consentTexts'] as Map<String, dynamic>;
    String hash(String text) => sha256.convert(utf8.encode(text)).toString();
    Set<String> hashes(Object list, {String name = ''}) => {
      for (final t in (list as List<dynamic>).cast<String>())
        hash(t.replaceAll('{name}', name)),
    };

    for (final entry in <String, AppL10n>{
      'en': AppL10nEn(),
      'ar': AppL10nAr(),
    }.entries) {
      final lang = entry.key;
      final l10n = entry.value;
      final request =
          (texts['coachingRequest2'] as Map<String, dynamic>)[lang]
              as Map<String, dynamic>;
      test('$lang share text', () {
        expect(
          hashes(request['share'] as Object, name: 'Rahma'),
          contains(hash(l10n.iShareTheseAnswersWithNameMy('Rahma'))),
        );
      });
      test('$lang transfer text', () {
        expect(
          hashes(request['transfer'] as Object),
          contains(hash(l10n.iAgreeThatMyAnswersAreSent)),
        );
      });
      test('$lang chat rules', () {
        final rules = (texts['chatRules1'] as Map<String, dynamic>)[lang];
        expect(hashes(rules as Object), contains(hash(chatRulesText(l10n))));
      });
    }
  });
}
