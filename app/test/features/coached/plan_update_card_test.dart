// P0-REVIEW-03 and P0-ASSIGN-02 — the card that says the plan changed, and the
// session that does not notice.
//
// Fixture numbers are deliberately unlike the mockup's: version `v4` → `v5`,
// published on the 16th, effective from the 21st, over a 30-day plan that
// starts on 12 September.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/g2_contract.dart';
import 'package:own_hub/features/coached/domain/plan_update_card.dart';

PlanVersion _version({
  required String id,
  required DateTime publishedAt,
  required DateTime effectiveFrom,
}) => PlanVersion(
  version: id,
  calendar: List<PlanDayKind>.generate(
    PlanVersion.calendarLength,
    (i) => i % 4 == 3 ? PlanDayKind.rest : PlanDayKind.train,
  ),
  publishedAt: publishedAt,
  effectiveFrom: effectiveFrom,
  startsOn: DateTime(2026, 9, 12),
  authorUid: 'c7k9farida',
);

void main() {
  final v4 = _version(
    id: 'v4',
    publishedAt: DateTime(2026, 9, 11, 7, 15),
    effectiveFrom: DateTime(2026, 9, 12),
  );
  final v5 = _version(
    id: 'v5',
    publishedAt: DateTime(2026, 9, 16, 19, 40),
    effectiveFrom: DateTime(2026, 9, 21),
  );

  group('a card is made of a revision that exists', () {
    test('publishing produces exactly one card, pointing at the version', () {
      final cards = const PlanUpdateCard().resolve(
        versions: [v4, v5],
        since: DateTime(2026, 9, 14),
      );

      expect(cards, hasLength(1));
      expect(cards.single.version, 'v5');
      expect(cards.single.effectiveFrom, DateTime(2026, 9, 21));
    });

    test('the card shows on publish day, and applies from its own date', () {
      // Published Wednesday, effective the following Monday. She must be told
      // on Wednesday — that is the point of telling her — while nothing changes
      // until Monday.
      final cards = const PlanUpdateCard().resolve(
        versions: [v4, v5],
        since: DateTime(2026, 9, 16, 9),
      );
      expect(cards.single.publishedAt.day, 16);
      expect(cards.single.effectiveFrom.day, 21);
    });

    test('cards are ordered oldest first', () {
      final v6 = _version(
        id: 'v6',
        publishedAt: DateTime(2026, 9, 18, 6),
        effectiveFrom: DateTime(2026, 9, 19),
      );
      final cards = const PlanUpdateCard().resolve(
        versions: [v6, v5],
        since: DateTime(2026, 9, 14),
      );
      expect(cards.map((c) => c.version), ['v5', 'v6']);
    });

    test('re-reading with the same cursor shows it once, not twice', () {
      final first = const PlanUpdateCard().resolve(
        versions: [v4, v5],
        since: v4.publishedAt,
      );
      expect(first.map((c) => c.version), ['v5']);

      // Cursor moved to the newest card she saw.
      final second = const PlanUpdateCard().resolve(
        versions: [v4, v5],
        since: v5.publishedAt,
      );
      expect(second, isEmpty, reason: 'strictly after, so no repeat');
    });
  });

  group('negative controls', () {
    test('no publish, no card — the list is the only input', () {
      // The whole of P1-RULE-02B's client half. Whatever was typed into the
      // thread, `resolve` has no parameter for it.
      final cards = const PlanUpdateCard().resolve(
        versions: [v4],
        since: DateTime(2026, 9, 14),
      );
      expect(cards, isEmpty);
    });

    test('an empty version list yields no card rather than throwing', () {
      expect(
        const PlanUpdateCard().resolve(
          versions: const [],
          since: DateTime(2026, 9, 14),
        ),
        isEmpty,
      );
    });

    test('hasChangeSince agrees with resolve', () {
      const card = PlanUpdateCard();
      expect(
        card.hasChangeSince(versions: [v4, v5], since: DateTime(2026, 9, 14)),
        isTrue,
      );
      expect(
        card.hasChangeSince(versions: [v4], since: DateTime(2026, 9, 14)),
        isFalse,
      );
    });
  });

  group('P0-ASSIGN-02 — a revision changes nothing that is running', () {
    test('a pinned version ignores every change', () {
      final pinned = PinnedPlanVersion(
        'v4',
        pinnedAt: DateTime(2026, 9, 16, 19),
      );
      final change = const PlanUpdateCard()
          .resolve(versions: [v4, v5], since: DateTime(2026, 9, 14))
          .single;

      expect(pinned.version, 'v4');
      expect(
        pinned.appliesTo(change),
        isFalse,
        reason: 'a revision applies to future dates, never to a live session',
      );
    });

    test('the pin has no way to refresh itself', () {
      // There is no `refresh`, no `latest` and no setter — so the session
      // cannot acquire the new version even by being asked nicely. Asserted at
      // the source, because "we simply never call it" is not a guarantee.
      // Code only. The file's own doc comment says "there is no refresh()",
      // which is the rule being documented rather than broken — a guard that
      // failed on that would teach people to stop explaining themselves.
      final source = _codeOf(
        'lib/features/coached/domain/plan_update_card.dart',
      );
      expect(source.contains('set version'), isFalse);
      expect(RegExp(r'\brefresh\s*\(').hasMatch(source), isFalse);
      expect(RegExp(r'\blatest\s*\(').hasMatch(source), isFalse);
    });
  });

  test('the calendar is exactly thirty, or the version refuses to exist', () {
    // G05's one-read promise lives on this field. A short calendar that was
    // tolerated here would send the month view back to a read per day.
    expect(
      () => PlanVersion(
        version: 'v7',
        calendar: List<PlanDayKind>.filled(28, PlanDayKind.train),
        publishedAt: DateTime(2026, 9, 18),
        effectiveFrom: DateTime(2026, 9, 19),
        startsOn: DateTime(2026, 9, 12),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

String _readSource(String path) => File(path).readAsStringSync();

/// [path] with every comment-only line removed.
String _codeOf(String path) => _readSource(path)
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !(t.startsWith('//') || t.startsWith('///') || t.startsWith('*'));
    })
    .join('\n');
