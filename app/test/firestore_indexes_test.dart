// Implements the deployment half of P1-RULE-11, and the PDPL half of P1-CYC-05.
//
// Rule 11 — "nothing is ranked by weight, weight lost, or followers" — cannot be
// enforced in application code alone. Firestore indexes every field by default,
// including array elements and map subfields, so a forbidden ordering is a
// working query unless the field is explicitly exempted. That makes
// firestore.indexes.json a *product rule artifact*, not configuration, and it
// deserves a test that fails when someone removes a line from it.
//
// This test reads the file rather than the database, so it runs with no emulator
// and no project. It cannot prove the file was deployed — a post-deploy check
// that the forbidden query FAILS is still required, and is listed in the runbook.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> config;
  late List<Map<String, dynamic>> overrides;

  setUpAll(() {
    final file = File('../firebase/firestore.indexes.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'firestore.indexes.json is a deployment artifact and must exist',
    );
    config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    overrides = (config['fieldOverrides'] as List).cast<Map<String, dynamic>>();
  });

  bool isExempt(String collectionGroup, String fieldPath) => overrides.any(
    (o) =>
        o['collectionGroup'] == collectionGroup &&
        o['fieldPath'] == fieldPath &&
        (o['indexes'] as List).isEmpty,
  );

  group('P1-RULE-11 — the forbidden orderings are unexecutable', () {
    test('nothing about her weight is indexed', () {
      // Embedded set outcomes, her measurements, and her personal bests.
      expect(
        isExempt('sessions', 'sets'),
        isTrue,
        reason: 'sets are embedded, so sets.actualWeight is indexed unless exempted',
      );
      expect(isExempt('measurements', 'weightKg'), isTrue);
      expect(isExempt('measurements', 'body'), isTrue);
      expect(isExempt('bests', 'loadKg'), isTrue);
    });

    test('nothing social is rankable', () {
      expect(
        isExempt('publicProfiles', 'followerCount'),
        isTrue,
        reason: 'follower counts are displayed, never ranked',
      );
      expect(isExempt('posts', 'counts'), isTrue);
      expect(isExempt('posts', 'cost'), isTrue);
      expect(isExempt('groups', 'memberCount'), isTrue);
    });

    test('a client result cannot be sorted by its numbers', () {
      // The sharpest case: indexed, "rank coaches by client weight lost" works.
      expect(isExempt('results', 'numbers'), isTrue);
    });

    test('no composite index reintroduces a forbidden ordering', () {
      const forbidden = {
        'weightKg',
        'loadKg',
        'followerCount',
        'memberCount',
        'counts',
        'cost',
        'numbers',
        'body',
        'sets',
      };
      for (final index
          in (config['indexes'] as List).cast<Map<String, dynamic>>()) {
        for (final field
            in (index['fields'] as List).cast<Map<String, dynamic>>()) {
          expect(
            forbidden.contains(field['fieldPath']),
            isFalse,
            reason:
                'composite index on ${index['collectionGroup']} orders by '
                '${field['fieldPath']}, which rule 11 forbids — an exemption '
                'does not help if a composite index names the field',
          );
        }
      }
    });
  });

  group('PDPL — cycle and check-in data is not queryable across women', () {
    test('cycle context and period dates are exempt', () {
      expect(
        isExempt('cycle', 'contextFlags'),
        isTrue,
        reason: '"find every pregnant woman" must be unexecutable, not merely denied',
      );
      expect(isExempt('periods', 'start'), isTrue);
    });

    test('symptom fields on the daily check-in are exempt', () {
      for (final field in ['cramps', 'bleeding', 'energy']) {
        expect(isExempt('checkins', field), isTrue, reason: 'checkins.$field');
      }
    });
  });

  group('the file itself stays reviewable', () {
    test('every index and exemption records why it exists', () {
      // An index nobody can justify is an index nobody can safely delete.
      for (final index
          in (config['indexes'] as List).cast<Map<String, dynamic>>()) {
        expect(
          index['_why'],
          isNotNull,
          reason: 'index on ${index['collectionGroup']} has no stated reason',
        );
      }
      for (final o in overrides) {
        expect(
          o['_why'],
          isNotNull,
          reason:
              'exemption on ${o['collectionGroup']}.${o['fieldPath']} '
              'has no stated reason',
        );
      }
    });

    test('every exemption actually disables indexing', () {
      // A fieldOverride with a non-empty indexes array exempts nothing.
      // The one exception is the payout run's collection-group index on
      // ledger.status, which switches an index ON for a query.
      for (final o in overrides) {
        if (o['collectionGroup'] == 'ledger' && o['fieldPath'] == 'status') {
          continue;
        }
        expect(
          (o['indexes'] as List),
          isEmpty,
          reason:
              '${o['collectionGroup']}.${o['fieldPath']} claims to be '
              'exempt but still declares indexes',
        );
      }
    });
  });
}
