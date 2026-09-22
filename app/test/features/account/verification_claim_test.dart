// Rule 7's claim on A03, derived from evidence rather than written down.
//
// This is the third time this defect class appears in this codebase.
// PHASE1-FIXES.md §3: C13 told every woman "Verified in 74 seconds" because 74
// was the prototype's sample and nothing measured the real duration. The fix was
// to make the number nullable and say less when it was not measured.
//
// Rule 7's promise is the same shape and higher stakes, because A03 restates it
// at the moment she is most likely to believe it.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/verification_claim.dart';

void main() {
  // Deliberately not the prototype's date. A test built on the mockup's own
  // sample passes for a constant as happily as for a computation.
  final deletedAt = DateTime(2026, 7, 3, 14, 27);
  final decidedAt = DateTime(2026, 7, 3, 14, 25);

  group('the statement is derived from verification.imagesDeletedAt', () {
    test('a recorded deletion may be stated, and carries its timestamp', () {
      final record = VerificationRecord(
        decidedAt: decidedAt,
        imagesDeletedAt: deletedAt,
      );

      final statement = VerificationClaim.imagesDeletedStatement(record);

      expect(statement, isA<ImagesDeleted>());
      expect((statement as ImagesDeleted).at, deletedAt);
      expect(statement.mayClaimDeletion, isTrue);
    });

    test('a null timestamp renders "deletion pending", never the claim', () {
      // G1's plan: null is an ALARM, not a state. PurgeReconciler.sweep() pages
      // on any job decided over an hour ago with a null value. A03 must not
      // paper over that with the reassuring sentence.
      final record = VerificationRecord(decidedAt: decidedAt);

      final statement = VerificationClaim.imagesDeletedStatement(record);

      expect(statement, isA<ImagesDeletionPending>());
      expect(
        statement.mayClaimDeletion,
        isFalse,
        reason:
            'the screen cannot claim a deletion that has not happened — '
            'G7 §5',
      );
    });

    test('a woman who has never been verified gets the pending state too', () {
      final statement = VerificationClaim.imagesDeletedStatement(
        VerificationRecord.none,
      );

      expect(statement, isA<ImagesDeletionPending>());
      expect(statement.mayClaimDeletion, isFalse);
    });
  });

  group('the pending state has nothing to render as a claim', () {
    test('ImagesDeletionPending carries no timestamp and no sentence', () {
      // The structural half. A careless widget cannot pull a date out of the
      // pending state because there is no field on it — the same technique
      // DayTotals uses against a calorie countdown.
      const pending = ImagesDeletionPending();

      expect(pending, isA<ImagesDeletedStatement>());
      expect(pending.mayClaimDeletion, isFalse);

      // And the two states are not interchangeable.
      expect(pending == ImagesDeleted(deletedAt), isFalse);
    });

    test('the sealed type forces both branches to be handled', () {
      // A switch over a sealed type is exhaustive, so a widget that renders the
      // deleted sentence must say what it renders when nothing was deleted.
      String render(ImagesDeletedStatement statement) => switch (statement) {
        ImagesDeleted() => 'deleted',
        ImagesDeletionPending() => 'pending',
      };

      expect(render(ImagesDeleted(deletedAt)), 'deleted');
      expect(render(const ImagesDeletionPending()), 'pending');
    });
  });

  group('rule 7 — there is nowhere to keep the images', () {
    test('VerificationRecord holds timestamps and nothing else', () {
      // The record is two DateTime? fields. There is deliberately no field an
      // image, a document number, a date of birth or a legal name could live
      // in. product_rules_test.dart scans lib/ for exactly those identifier
      // shapes, and its positive control whitelists `final DateTime?
      // imagesDeletedAt;` — the evidence field is allowed; somewhere to keep
      // the evidence is not.
      final record = VerificationRecord(
        decidedAt: decidedAt,
        imagesDeletedAt: deletedAt,
      );

      expect(record.decidedAt, decidedAt);
      expect(record.imagesDeletedAt, deletedAt);
      expect(record.isDecided, isTrue);
      expect(VerificationRecord.none.isDecided, isFalse);
    });
  });
}
