import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/data/firestore_coaching_repository.dart';
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/data/firestore_plain.dart';
import 'package:own_hub/features/private_coaching/domain/chat_screen.dart';
import 'package:own_hub/features/private_coaching/domain/coach_match.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';

import 'support/fake_coaching_repository.dart';
import 'support/fixtures.dart';

void main() {
  group('coach match', () {
    const answers = MatchAnswers(
      goal: 'buildMuscle',
      place: 'gym',
      budgetBand: 'from1500to3000',
    );

    test('goal, place and budget decide the order', () {
      final coaches = <CoachProfile>[
        coach(
          'a',
          'Amal',
          specialties: ['fatLoss'],
          trainsWhere: ['home'],
          fromMonthlyEgp: 1000,
        ),
        coach(
          'b',
          'Basma',
          specialties: ['muscleGain'],
          trainsWhere: ['gym'],
          fromMonthlyEgp: 2000,
        ),
        coach(
          'c',
          'Chadia',
          specialties: ['strength'],
          trainsWhere: ['gym'],
          fromMonthlyEgp: 2000,
        ),
        coach(
          'd',
          'Dina',
          specialties: ['muscleGain'],
          trainsWhere: ['home'],
          fromMonthlyEgp: 5000,
        ),
      ];
      final ranked = CoachMatch.rank(answers, coaches);
      expect(ranked.map((r) => r.coach.uid), ['b', 'c', 'd', 'a']);
      expect(ranked.first.score, greaterThan(ranked[1].score));
    });

    test('at most five, ties by name A to Z', () {
      final coaches = [
        for (final n in [
          'Zeina',
          'Alia',
          'Mona',
          'Dalia',
          'Cara',
          'Bella',
          'Eve',
        ])
          coach(
            n,
            n,
            specialties: ['muscleGain'],
            trainsWhere: ['gym'],
            fromMonthlyEgp: 2000,
          ),
      ];
      final ranked = CoachMatch.rank(answers, coaches);
      expect(ranked, hasLength(CoachingLimits.matchResultsMax));
      expect(ranked.map((r) => r.coach.displayName), [
        'Alia',
        'Bella',
        'Cara',
        'Dalia',
        'Eve',
      ]);
    });

    test('clients coached and ratings never move a coach up', () {
      final coaches = [
        coach(
          'a',
          'Amal',
          specialties: ['muscleGain'],
          trainsWhere: ['gym'],
          fromMonthlyEgp: 2000,
        ),
        coach(
          'z',
          'Zeina',
          specialties: ['muscleGain'],
          trainsWhere: ['gym'],
          clientsCoached: 5000,
          fromMonthlyEgp: 2000,
        ),
      ];
      expect(CoachMatch.rank(answers, coaches).map((r) => r.coach.uid), [
        'a',
        'z',
      ]);
      expect(CoachMatch.allCoachesAtoZ(coaches).map((c) => c.uid), ['a', 'z']);
    });

    test(
      'closed, full-less and unpublished coaches are left out of a match',
      () {
        final coaches = [
          coach(
            'a',
            'A',
            specialties: ['muscleGain'],
            trainsWhere: ['gym'],
            fromMonthlyEgp: 1150,
          ),
          coach(
            'b',
            'B',
            specialties: ['muscleGain'],
            trainsWhere: ['gym'],
            accepting: false,
            fromMonthlyEgp: 1150,
          ),
          coach(
            'c',
            'C',
            specialties: ['muscleGain'],
            trainsWhere: ['gym'],
            published: false,
            fromMonthlyEgp: 1150,
          ),
          // The server unpublishes a coach with no active package.
          coach(
            'd',
            'D',
            specialties: ['muscleGain'],
            trainsWhere: ['gym'],
            published: false,
          ),
        ];
        expect(CoachMatch.rank(answers, coaches).map((r) => r.coach.uid), [
          'a',
        ]);
      },
    );

    test('budget compares the 28-day price of the cheapest active package', () {
      const under = MatchAnswers(
        goal: 'x',
        place: 'x',
        budgetBand: 'under1500',
      );
      CoachProfile withMonth(int? month) =>
          coach('a', 'A', fromMonthlyEgp: month);
      expect(
        CoachMatch.scoreOf(under, withMonth(1000)),
        CoachMatch.budgetPoints,
        reason: '3000 over 84 days is 1000 a month',
      );
      expect(CoachMatch.scoreOf(under, withMonth(1500)), 0);
      expect(CoachMatch.scoreOf(under, withMonth(null)), 0);
      expect(
        CoachMatch.scoreOf(
          const MatchAnswers(goal: 'x', place: 'x', budgetBand: 'over3000'),
          withMonth(9000),
        ),
        CoachMatch.budgetPoints,
      );
    });

    test(
      'the server-written monthly price ranks the same as the packages did',
      () {
        // Packages of different lengths: the 84-day one is the cheaper month.
        final byCoach = <String, List<CoachPackage>>{
          'a': [package('p', price: 1400), package('q', price: 3000, days: 84)],
          'b': [package('p', price: 1600, days: 56)],
          'c': [
            package('p', price: 1499),
            package('q', price: 900, active: false),
          ],
        };
        int? month(List<CoachPackage> list) {
          final months = [
            for (final p in list)
              if (p.active) p.monthlyEquivalent,
          ];
          return months.isEmpty ? null : months.reduce((a, b) => a < b ? a : b);
        }

        final coaches = [
          for (final e in byCoach.entries)
            coach(
              e.key,
              e.key.toUpperCase(),
              specialties: ['muscleGain'],
              trainsWhere: ['gym'],
              fromMonthlyEgp: month(e.value),
            ),
        ];
        // 1000 a month (a), 800 (b), 1499 (c): all under 1500, all score alike,
        // so the order is A to Z, as when the packages were read per coach.
        const under = MatchAnswers(
          goal: 'buildMuscle',
          place: 'gym',
          budgetBand: 'under1500',
        );
        expect(CoachMatch.rank(under, coaches).map((r) => r.coach.uid), [
          'a',
          'b',
          'c',
        ]);
        // 1500 a month is over the under-1500 ceiling, so she scores lower
        // and comes last wherever she is in the list.
        final dear = coach(
          'd',
          'D',
          specialties: ['muscleGain'],
          trainsWhere: ['gym'],
          fromMonthlyEgp: 1500,
        );
        expect(
          CoachMatch.rank(under, [...coaches, dear]).map((r) => r.coach.uid),
          ['a', 'b', 'c', 'd'],
        );
        expect(CoachMatch.rank(under, [dear, ...coaches]).last.coach.uid, 'd');
      },
    );

    test('online coaches serve any place; both means home or gym', () {
      expect(
        CoachMatch.scoreOf(
          const MatchAnswers(goal: 'x', place: 'home', budgetBand: 'x'),
          coach('a', 'A', trainsWhere: ['online']),
        ),
        CoachMatch.placePoints,
      );
      expect(
        CoachMatch.scoreOf(
          const MatchAnswers(goal: 'x', place: 'both', budgetBand: 'x'),
          coach('a', 'A', trainsWhere: ['gym']),
        ),
        CoachMatch.placePoints,
      );
    });

    test('every goal maps to real specialties', () {
      expect(CoachMatch.goalSpecialties.keys, CoachingEnums.goals);
      for (final list in CoachMatch.goalSpecialties.values) {
        expect(CoachingEnums.specialties, containsAll(list));
      }
      expect(CoachMatch.bandCeilingEgp.keys, CoachingEnums.budgetBands);
    });

    test('everyone A to Z leaves out unpublished coaches', () {
      final list = CoachMatch.allCoachesAtoZ([
        coach('b', 'bella'),
        coach('a', 'Alia'),
        coach('c', 'Cara', published: false),
      ]);
      expect(list.map((c) => c.displayName), ['Alia', 'bella']);
    });
  });

  group('CoachingFailure', () {
    test('a reason in the message wins', () {
      final f = CoachingFailure.fromCallable(
        'failed-precondition',
        'coach_unavailable',
      );
      expect(f.refusal, CoachingRefusal.coachUnavailable);
    });

    test('every contract reason maps back to itself', () {
      for (final reason
          in CoachingEnums.all.isEmpty
              ? <String>[]
              : [
                  for (final r in CoachingRefusal.values)
                    if (!CoachingRefusal.localOnly.contains(r)) r.code,
                ]) {
        expect(
          CoachingFailure.fromCallable('invalid-argument', reason).refusal.code,
          reason,
        );
      }
    });

    test('unknown reasons fall back on the status', () {
      expect(
        CoachingFailure.fromCallable('unavailable', 'x').refusal,
        CoachingRefusal.unreachable,
      );
      expect(
        CoachingFailure.fromCallable('deadline-exceeded', null).refusal,
        CoachingRefusal.unreachable,
      );
      expect(
        CoachingFailure.fromCallable('unauthenticated', '').refusal,
        CoachingRefusal.signedOut,
      );
      expect(
        CoachingFailure.fromCallable('internal', 'brand_new').refusal,
        CoachingRefusal.unknown,
      );
      expect(CoachingRefusal.fromCode(null), CoachingRefusal.unknown);
      expect(CoachingRefusal.fromCode('?'), CoachingRefusal.unknown);
    });

    test('store errors', () {
      expect(
        CoachingFailure.fromStore('unavailable').refusal,
        CoachingRefusal.unreachable,
      );
      expect(
        CoachingFailure.fromStore('permission-denied').refusal,
        CoachingRefusal.unknown,
      );
    });

    test('a screened text carries its reason', () {
      final f = CoachingFailure.screened(ChatScreenReason.payment);
      expect(f.refusal, CoachingRefusal.messageBlocked);
      expect(f.screen, ChatScreenReason.payment);
    });
  });

  group('data layer helpers', () {
    test('timestamps become UTC times, deeply', () {
      final plain = firestorePlain({
        'at': Timestamp.fromDate(DateTime.utc(2026, 10, 24, 9)),
        'list': [Timestamp.fromDate(DateTime.utc(2026))],
        'n': 3,
      }) as Map<String, Object?>;
      expect(plain['at'], DateTime.utc(2026, 10, 24, 9));
      expect((plain['list'] as List).single, DateTime.utc(2026));
      expect(plain['n'], 3);
    });

    test('doc paths sit one level under the folder', () {
      for (final folder in CoachDocFolder.values) {
        final path = coachDocPath(
          uid: 'u',
          folder: folder,
          token: 't',
          extension: 'jpg',
        );
        expect(path, 'coach-docs/u/${folder.name}/t.jpg');
      }
      expect(kCoachDocExtensions['application/pdf'], 'pdf');
    });

    test('the fake repository screens text like the real one', () async {
      final repo = FakeCoachingRepository();
      await repo.sendText('c__me', ' Hello ');
      expect(
        () => repo.sendText('c__me', 'call 01012345678'),
        throwsA(
          isA<CoachingFailure>().having(
            (f) => f.screen,
            'screen',
            ChatScreenReason.contact,
          ),
        ),
      );
    });

    test('no file in the feature names the person-id field the app bans', () {
      final files = Directory('lib/features/private_coaching')
          .listSync(recursive: true)
          .whereType<File>();
      for (final f in files) {
        expect(
          f.readAsStringSync(),
          isNot(
            contains(
              'legal'
              'Name',
            ),
          ),
          reason: f.path,
        );
      }
    });
  });
}
