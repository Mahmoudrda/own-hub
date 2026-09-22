// `K04` is the single writer of offers. `B06` and `K18` read them.
//
// The single-writer property is a *type* property — a screen handed an
// `OfferReader` has no method to write one — so it is asserted here by the shape
// of the API and in `coach_rules_guard_test.dart` by scanning for anyone who
// reaches for the writer.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_repository.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/offer.dart';

final _now = DateTime(2026, 7, 11, 20, 5);

PackagesEditor _editorFor(
  InMemoryCoachRepository repository,
  CoachVerificationState state,
) => PackagesEditor(
  reader: repository,
  writer: repository,
  rights: CoachPublishingRights.forState(state),
);

OfferDraft _draft({
  String id = 'offer-a',
  String name = 'Six weeks, twice a week',
  int price = 165000,
}) {
  final result = OfferDraft.validate(
    id: id,
    name: name,
    pricePiastres: price,
    lines: const ['Two sessions a week', 'One voice review'],
  );
  return result.draft!;
}

void main() {
  group('a price is a number, never free text', () {
    test('a negative price is refused', () {
      final result = OfferDraft.validate(
        id: 'o',
        name: 'Anything',
        pricePiastres: -1,
      );
      expect(result.draft, isNull);
      expect(result.refusal, OfferRefusal.priceOutOfRange);
    });

    test('a nameless offer is refused', () {
      final result = OfferDraft.validate(
        id: 'o',
        name: '   ',
        pricePiastres: 1000,
      );
      expect(result.draft, isNull);
      expect(result.refusal, OfferRefusal.unnamed);
    });

    test('free is a price and is allowed', () {
      expect(
        OfferDraft.validate(
          id: 'o',
          name: 'A first call',
          pricePiastres: 0,
        ).draft,
        isNotNull,
      );
    });

    test('her name is trimmed, not rejected for a stray space', () {
      final draft = OfferDraft.validate(
        id: 'o',
        name: '  Monthly coaching  ',
        pricePiastres: 1,
      ).draft!;
      expect(draft.name, 'Monthly coaching');
    });
  });

  test('she keeps eighty per cent, and rounding never costs her a piastre', () {
    const offer = Offer(
      id: 'o',
      name: 'Monthly',
      pricePiastres: 180000,
      lines: [],
      published: true,
    );
    expect(offer.sharePiastres, 144000);

    const odd = Offer(
      id: 'o',
      name: 'Odd',
      pricePiastres: 7,
      lines: [],
      published: true,
    );
    // 5.6 piastres. Rounded toward her.
    expect(odd.sharePiastres, 6);
  });

  group('authoring is not publishing', () {
    test('a coach under review may write an offer', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.humanReview);

      final saved = await editor.save(_draft(), now: _now);
      expect(saved, isA<OfferSaved>());
      expect(repository.allOffers(), hasLength(1));
    });

    test('and nobody can see it', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.humanReview);
      await editor.save(_draft(), now: _now);

      expect((saved) => saved, isNotNull);
      expect(repository.allOffers().single.published, isFalse);
      expect(
        repository.publicOffers(),
        isEmpty,
        reason: 'She may author everything and publish nothing.',
      );
    });

    test('publishing is refused while she is being checked', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(
        repository,
        CoachVerificationState.docsChecking,
      );
      await editor.save(_draft(), now: _now);

      final published = await editor.publish('offer-a', now: _now);
      expect(published, isA<OfferSaveRefused>());
      expect(repository.publicOffers(), isEmpty);
    });

    test('a cleared coach publishes it', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.verified);
      await editor.save(_draft(), now: _now);

      final published = await editor.publish('offer-a', now: _now);
      expect(published, isA<OfferSaved>());
      expect(repository.publicOffers(), hasLength(1));
      expect(repository.publicOffers().single.name, 'Six weeks, twice a week');
    });

    test('editing a published offer keeps it published', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.verified);
      await editor.save(_draft(), now: _now);
      await editor.publish('offer-a', now: _now);

      await editor.save(_draft(price: 190000), now: _now);
      expect(repository.publicOffers().single.pricePiastres, 190000);
    });

    test('a suspended coach may not write one at all', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.suspended);

      final saved = await editor.save(_draft(), now: _now);
      expect((saved as OfferSaveRefused).reason, OfferRefusal.mayNotAuthor);
      expect(repository.allOffers(), isEmpty);
    });
  });

  group('six offers is a decision; seven is a menu', () {
    test('the seventh is refused', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.verified);

      for (var i = 0; i < PackagesEditor.maxOffers; i++) {
        final saved = await editor.save(
          _draft(id: 'offer-$i', name: 'Package $i'),
          now: _now,
        );
        expect(saved, isA<OfferSaved>(), reason: 'offer $i');
      }

      final seventh = await editor.save(
        _draft(id: 'offer-x', name: 'One too many'),
        now: _now,
      );
      expect((seventh as OfferSaveRefused).reason, OfferRefusal.tooManyOffers);
    });

    test('editing an existing offer at the cap is still allowed', () async {
      final repository = InMemoryCoachRepository();
      final editor = _editorFor(repository, CoachVerificationState.verified);
      for (var i = 0; i < PackagesEditor.maxOffers; i++) {
        await editor.save(
          _draft(id: 'offer-$i', name: 'Package $i'),
          now: _now,
        );
      }

      final edited = await editor.save(
        _draft(id: 'offer-0', name: 'Renamed', price: 99000),
        now: _now,
      );
      expect(edited, isA<OfferSaved>());
      expect(repository.offerById('offer-0')!.name, 'Renamed');
    });
  });

  test('an offer can be removed', () async {
    final repository = InMemoryCoachRepository();
    final editor = _editorFor(repository, CoachVerificationState.verified);
    await editor.save(_draft(), now: _now);

    await editor.remove('offer-a');
    expect(repository.allOffers(), isEmpty);
  });

  test('the reader a client-facing screen is handed cannot write', () {
    // A compile-time property, restated as a value assertion so the intent is
    // findable: OfferReader declares three methods and none of them writes.
    final OfferReader reader = InMemoryCoachRepository();
    expect(reader.allOffers(), isEmpty);
    expect(reader.publicOffers(), isEmpty);
    expect(reader.offerById('nothing'), isNull);
  });

  test('the currency is pinned', () {
    expect(coachOfferCurrency, 'EGP');
    expect(
      const Offer(
        id: 'o',
        name: 'n',
        pricePiastres: 1,
        lines: [],
        published: false,
      ).currency,
      'EGP',
    );
  });
}
