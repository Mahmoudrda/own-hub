// G7 §7.3 — the manifest, and check (e) made executable.
//
// §7.3 is explicit that the table IS the implementation, and that its integrity
// held only because "one agent re-read six plans by eye, and it missed rows on
// the first pass. Nothing about that repeats itself for free."
//
// So check (e) is a test rather than a promise: any `users/{uid}/*`
// subcollection declared in the deployed security rules without a manifest row
// is a collection P0-DEL-01 would leave behind.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/deletion_manifest.dart';

/// Every `users/{uid}/<name>` subcollection the deployed rules declare.
///
/// Read from the rules rather than from a list in a test, because the rules are
/// what actually exists in the project — a hand-maintained list would drift and
/// would drift *silently*, which is the whole failure mode being guarded.
Set<String> _subcollectionsInRules() {
  final file = File('../firebase/firestore.rules');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'firestore.rules is a deployment artifact and must exist',
  );
  final rules = file.readAsStringSync();

  // Slice the single users/{uid} block: from the end of its own match line to
  // the start of the next top-level block. Starting after the line matters —
  // otherwise the block header itself matches as a subcollection called
  // "users".
  const header = 'match /users/{uid} {';
  final start = rules.indexOf(header);
  expect(start, greaterThan(-1), reason: 'the users/{uid} block must exist');

  final end = rules.indexOf('match /coaches/{coachUid} {');
  expect(end, greaterThan(start), reason: 'the coaches block follows it');

  final block = rules.substring(start + header.length, end);

  return RegExp(r'match /(\w+)/\{')
      .allMatches(block)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  group('the manifest is intact', () {
    test('62 rows, numbered 1 to 62 with no gaps and no duplicates', () {
      // 34 until check (e) below ran for the first time and found three
      // collections nobody had enumerated in three passes by eye.
      //
      // 38 with `users/{uid}/private/**`, which arrived with the recipe
      // entitlement. Check (e) found that one too, on the same day the rule was
      // written, which is the guard doing exactly its job: a subcollection
      // added ahead of the feature that reads it is the kind most likely to be
      // left on the server after she deletes her account.
      //
      // 41 with the server's verification records for her (flags, ledger,
      // sessions), added with the real `delete_account` callable and held to
      // contracts/deletion_manifest.json by the parity test.
      //
      // 44 with the hash-keyed fraud signals and the reviewer access log,
      // which deletion cannot find and a TTL policy sweeps instead.
      //
      // 49 with the community and coach data named row by row (posts, her
      // comments, coach pages, relationships, invite codes), all run by row
      // 26's server purge.
      //
      // 53 with her event seats, returned to the event by the server's purge.
      //
      // 54 with her confirmation marker on shared foods, removed by the
      // server's purge; the count on the food stays.
      //
      // 59 with private coaching: her application, coachPrivate, packages and
      // drafts, subscriptions, and the pseudonymised payment records.
      //
      // 61 with the copy of a reported message or plan (row 60) and a coach's
      // release evidence (row 61).
      //
      // 62 with her weekly check-in answers (row 62), deleted with the
      // coaching they belong to.
      expect(kDeletionManifest, hasLength(62));

      final numbers = kDeletionManifest.map((r) => r.number).toList()..sort();
      expect(numbers, [for (var i = 1; i <= 62; i++) i]);
    });

    test('every row names a path and an owner', () {
      for (final row in kDeletionManifest) {
        expect(row.path, isNotEmpty, reason: 'row ${row.number} needs a path');
        expect(
          row.owner,
          isNotEmpty,
          reason: 'row ${row.number} needs an owner',
        );
      }
    });
  });

  test('the community and coach data is named row by row', () {
    // Dormant at launch, and erasable before it is switched on (APL-16).
    for (final number in [45, 46, 47, 48, 49, 55, 56, 57, 58]) {
      final row = kDeletionManifest.firstWhere((r) => r.number == number);
      expect(row.method, DeletionMethod.groupHook);
      expect(row.method.removesData, isTrue);
    }
    expect(
      kDeletionManifest.map((r) => r.path),
      containsAll(<String>[
        'coachInvites where coachUid == uid',
        'posts/*/comments where authorUid == uid',
      ]),
    );
  });

  group('eight rows survive on purpose, and A02 must say so', () {
    test('exactly eight rows do not remove data', () {
      expect(kRowsThatSurvive.map((r) => r.number).toList()..sort(), [
        23,
        30,
        31,
        42,
        43,
        44,
        59,
        60,
      ]);
    });

    test('the fraud signals and the access log expire on their own', () {
      for (final number in [42, 43, 44]) {
        final row = kDeletionManifest.firstWhere((r) => r.number == number);
        expect(row.method, DeletionMethod.ttl);
        expect(row.method.removesData, isFalse);
        expect(row.note, contains('deleted'));
      }
    });

    test('nidRegistry is closed, not deleted', () {
      final row = kDeletionManifest.firstWhere((r) => r.number == 23);

      expect(row.path, 'nidRegistry/{nidHash}');
      expect(row.method, DeletionMethod.closed);
      expect(row.method.removesData, isFalse);
      expect(
        row.note,
        contains('cannot re-register'),
        reason:
            'the hash stays so a removed woman cannot re-register, while no '
            'personal data stays linked',
      );
    });

    test('reports are pseudonymised, not deleted', () {
      final row = kDeletionManifest.firstWhere((r) => r.number == 30);

      expect(row.method, DeletionMethod.pseudonymised);
      expect(row.method.removesData, isFalse);
      expect(row.note, contains('salted token'));
    });

    test('the deletion request itself is retained as proof of erasure', () {
      final row = kDeletionManifest.firstWhere((r) => r.number == 31);

      expect(row.path, 'deletionRequests/{uid}');
      expect(row.method, DeletionMethod.retained);
      expect(row.method.removesData, isFalse);
    });
  });

  group('the rows only this handset can run', () {
    test(
      'the local rows are the sync queue and the photo store with its key',
      () {
        expect(kHandsetOnlyRows.map((r) => r.number).toList()..sort(), [
          9,
          33,
          34,
        ]);
      },
    );

    test('the progress photos have no server copy, which is why 33 exists', () {
      final row = kDeletionManifest.firstWhere((r) => r.number == 33);

      expect(row.note, contains('no Storage object'));
      expect(
        row.note,
        contains('NO server-side delete can reach'),
        reason:
            'a server-only purge leaves the most intimate data in the product '
            'sitting on the phone',
      );
    });

    test('destroying the key is a separate row from wiping the ciphertext', () {
      final key = kDeletionManifest.firstWhere((r) => r.number == 34);

      expect(key.note, contains('wiping ciphertext while leaving the key'));
    });
  });

  group('Auth is locked first and deleted last', () {
    test('the Auth row states both halves of the ordering', () {
      final row = kDeletionManifest.firstWhere((r) => r.number == 29);

      expect(row.method, DeletionMethod.authRecord);
      expect(row.note, contains('FIRST'));
      expect(row.note, contains('LAST'));
    });
  });

  group('check (e) — a subcollection with no manifest row', () {
    test('the parser actually finds the rules\' subcollections', () {
      // A positive control. A parser that silently matched nothing would report
      // a perfectly complete manifest over zero collections — the same vacuous
      // pass PHASE1-FIXES.md §14 records for the rule-7 guard.
      final declared = _subcollectionsInRules();

      expect(declared, contains('meals'));
      expect(declared, contains('sessions'));
      expect(declared, contains('measurements'));
      expect(
        declared.length,
        greaterThan(8),
        reason: 'the users/{uid} block declares many subcollections',
      );
      expect(
        declared,
        isNot(contains('users')),
        reason: 'the block header itself is not a subcollection',
      );
    });

    test('every subcollection the rules declare has a manifest row', () {
      // This test was born failing, on purpose, and reported the truth: cycle,
      // periods and splits were declared in firestore.rules and enumerated
      // nowhere in §7.3. Three passes by eye had each concluded the manifest
      // "closes clean". The first run of this check found all three.
      //
      // They are now rows 35, 36 and 37, so the gap is empty — and asserting
      // emptiness rather than a known-gap set means a FOURTH collection added
      // without a row goes red on the day it lands, not on the day someone
      // next re-reads seven plans.
      final gaps = manifestGapsAgainstRules(_subcollectionsInRules());

      expect(
        gaps,
        isEmpty,
        reason:
            'users/{uid}/${gaps.join(", users/{uid}/")} is declared in '
            'firestore.rules with no row in G7 §7.3. Firestore does not '
            'cascade-delete subcollections, so P0-DEL-01 would leave it '
            'behind while A02 tells her nothing survives. Add the row to '
            'kDeletionManifest and to §7.3 — do not edit this test.',
      );

      expect(
        kKnownManifestGaps,
        isEmpty,
        reason:
            'A name here is a subcollection knowingly excluded from deletion. '
            'That is a DECISIONS.md-level choice about a woman\'s data, not a '
            'way to make this test pass.',
      );
    });

    test('every manifest row has somewhere to live in the rules', () {
      // **The other direction, which check (e) cannot see.**
      //
      // (e) asks: is every subcollection the rules declare enumerated in the
      // manifest? That catches a collection shipping without a deletion row.
      // It is blind to the reverse — a row whose path has NO rules block at
      // all, which falls through to the catch-all `allow read, write: if false`
      // and is denied in both directions.
      //
      // That is not harmlessly conservative. It was true of `consents`, and
      // PDPL gives her a right of access to her own consent trail; deny-all
      // blocked her from reading it. It was true of `notices` and `firstWeek`,
      // both of which have live domain models in this app today.
      //
      // `syncQueue` is exempt on principle rather than by name: its method is
      // `localOnly`, so it is a local sqflite table and not a Firestore path.
      // Anything else absent from the rules is a collection the product
      // believes it can delete and cannot even read.
      final declared = _subcollectionsInRules();

      final handsetOnly = kDeletionManifest
          .where((r) => r.method == DeletionMethod.localOnly)
          .map((r) => r.userSubcollection)
          .whereType<String>()
          .toSet();

      final undeclared = kManifestUserSubcollections
          .difference(declared)
          .difference(handsetOnly);

      expect(
        undeclared,
        isEmpty,
        reason:
            'These have a deletion row but no rules block, so every read and '
            'write of them is denied: '
            '${undeclared.map((s) => 'users/{uid}/$s').join(', ')}. Either '
            'declare them in firestore.rules, or — if the path is not '
            'Firestore at all — give the row a localOnly method, which is how '
            'syncQueue is excused.',
      );
    });

    test('everything else the rules declare IS enumerated', () {
      final declared = _subcollectionsInRules();
      final covered = declared.difference(kKnownManifestGaps);

      for (final name in covered) {
        expect(
          kManifestUserSubcollections,
          contains(name),
          reason:
              'users/{uid}/$name is declared in the rules and must have a '
              'manifest row — Firestore does not cascade-delete subcollections',
        );
      }
    });
  });
}
