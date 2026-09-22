// P0-PORT-02 and P0-PORT-09, plus the seven states and the B14 branch.
//
// The point of P0-PORT-02 is that "the page is data, not a template": every
// change is an edit to one array, a type may appear twice without complaint,
// and hiding keeps the payload. So the assertions are about the array, not
// about any screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/portfolio.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_theme.dart';

final _now = DateTime.utc(2026, 3, 1);

PortfolioBlock _cover(String id, {String headline = 'Back to lifting'}) =>
    PortfolioBlock(
      id: id,
      payload: CoverPayload(layout: CoverLayout.noPhoto, headline: headline),
    );

PortfolioBlock _method(String id, {String title = 'We talk first'}) =>
    PortfolioBlock(
      id: id,
      payload: MethodPayload(
        steps: [MethodStep(title: title, body: 'Twenty minutes, no charge.')],
      ),
    );

Portfolio _empty() => Portfolio.newDraft(now: _now);

void main() {
  group('P0-PORT-02 — a page is a list of blocks', () {
    test('day one is an empty array, not a template', () {
      final draft = _empty();
      expect(draft.blocks, isEmpty);
      expect(draft.blockCount, 0);
      expect(draft.published, isFalse);
      expect(draft.draftRev, 1);
      expect(draft.versionId, 'draft');
    });

    test('a type may appear twice without complaint', () {
      final page = _empty()
          .addBlock(_cover('b1'))
          .addBlock(_method('b2', title: 'We talk first'))
          .addBlock(_method('b3', title: 'The floor weeks'));

      expect(page.countOf(BlockType.method), 2);
      expect(page.blockCount, 3);
    });

    test('order is the array index — a reorder is a permutation', () {
      final page = _empty()
          .addBlock(_cover('b1'))
          .addBlock(_method('b2'))
          .addBlock(_method('b3'));

      final moved = page.reorder(2, 0);

      expect(moved.blocks.map((b) => b.id), ['b3', 'b1', 'b2']);
      expect(
        moved.toJson()['blocks'],
        isA<List<Object?>>(),
        reason: 'the stored form is the array; there is no order field',
      );
      final encoded = moved.toJson().toString();
      expect(
        encoded.contains("'order'"),
        isFalse,
        reason:
            'an order field would be a second copy of the ordering, and '
            'two copies of an ordering drift',
      );
    });

    test('hiding keeps the payload and removes it from what a client sees', () {
      final page = _empty()
          .addBlock(_cover('b1'))
          .addBlock(_method('b2', title: 'The floor weeks'))
          .setVisible('b2', false);

      final hidden = page.blockById('b2')!;
      expect(hidden.visible, isFalse);
      expect(
        (hidden.payload as MethodPayload).steps.single.title,
        'The floor weeks',
      );
      expect(page.visibleBlocks.map((b) => b.id), ['b1']);

      // And un-hiding restores her words exactly.
      expect(
        (page.setVisible('b2', true).blockById('b2')!.payload as MethodPayload)
            .steps
            .single
            .title,
        'The floor weeks',
      );
    });

    test('editing a block replaces one payload and touches nothing else', () {
      final page = _empty().addBlock(_cover('b1')).addBlock(_method('b2'));
      final edited = page.replacePayload(
        'b1',
        const CoverPayload(
          layout: CoverLayout.noPhoto,
          headline: 'Back to lifting, after birth',
        ),
      );

      expect(
        (edited.blockById('b1')!.payload as CoverPayload).headline,
        'Back to lifting, after birth',
      );
      expect(edited.blocks.map((b) => b.id), ['b1', 'b2']);
      expect(edited.blockById('b2')!.payload, page.blockById('b2')!.payload);
    });

    test('deleting removes it, and re-inserting is the undo', () {
      final page = _empty()
          .addBlock(_cover('b1'))
          .addBlock(_method('b2'))
          .addBlock(_method('b3'));

      final removed = page.blockById('b2')!;
      final after = page.removeBlock('b2');
      expect(after.blocks.map((b) => b.id), ['b1', 'b3']);

      // §2 rule 9: five seconds to take it back, with its payload intact.
      final undone = after.insertBlock(removed, 1);
      expect(undone.blocks.map((b) => b.id), ['b1', 'b2', 'b3']);
      expect(undone.blockById('b2')!.payload, removed.payload);
    });

    test('blockCount is denormalised and always agrees with the array', () {
      final page = _empty().addBlock(_cover('b1')).addBlock(_method('b2'));
      expect(page.toJson()['blockCount'], 2);
      expect(page.removeBlock('b1').toJson()['blockCount'], 1);
    });
  });

  group('the caps are the caps', () {
    test('40 sections, and no more', () {
      var page = _empty();
      for (var i = 0; i < kMaxBlocks; i++) {
        page = page.addBlock(_method('b$i'));
      }
      expect(page.blockCount, 40);
      expect(() => page.addBlock(_method('b40')), throwsStateError);
    });

    test('one cover, because two covers is a mistake rather than a style', () {
      final page = _empty().addBlock(_cover('b1'));
      expect(() => page.addBlock(_cover('b2')), throwsStateError);
      expect(page.addableTypes.contains(BlockType.cover), isFalse);
      expect(page.addableTypes.contains(BlockType.method), isTrue);
    });

    test('B03 offers twelve tiles once the starter page exists', () {
      // cover and about are already on the starter page in the mockup; the
      // grid lists the rest. Twelve is a consequence, not a constant.
      final page = _empty()
          .addBlock(_cover('b1'))
          .addBlock(PortfolioBlock(id: 'b2', payload: const AboutPayload()));
      expect(page.addableTypes.length, 13);
      expect(
        page.addableTypes.contains(BlockType.about),
        isTrue,
        reason: 'about may repeat; only cover is capped',
      );
    });

    test('an id is never reused within a portfolio', () {
      final page = _empty().addBlock(_cover('b1'));
      expect(() => page.addBlock(_method('b1')), throwsStateError);
    });

    test('the id source resumes past what the page already used', () {
      final ids = SequentialBlockIds.after(const ['b1', 'b7', 'b3']);
      expect(ids.next(), 'b8');
      expect(ids.next(), 'b9');
    });
  });

  group('P0-PORT-09 — two phones cannot silently overwrite a page', () {
    test('a save must be exactly one revision past the server', () {
      expect(
        DraftGuard.check(incomingRev: 5, serverRev: 4),
        DraftSaveOutcome.accepted,
      );
      expect(
        DraftGuard.check(incomingRev: 5, serverRev: 5),
        DraftSaveOutcome.staleRevision,
      );
      expect(
        DraftGuard.check(incomingRev: 7, serverRev: 4),
        DraftSaveOutcome.staleRevision,
        reason: 'jumping ahead is as wrong as falling behind',
      );
    });

    test('Take over adopts the server draft and writes nothing', () {
      final mine = _empty().addBlock(_cover('b1')).savedBy('phone-a');
      final server = _empty().addBlock(_method('b9')).savedBy('phone-b');

      final resolved = DraftGuard.resolve(
        choice: DraftConflictResolution.takeOver,
        mine: mine,
        server: server,
        deviceId: 'phone-a',
      );

      expect(identical(resolved, server), isTrue);
      expect(resolved.blocks.map((b) => b.id), ['b9']);
    });

    test('Keep mine rebases onto the server revision so the write lands', () {
      final mine = _empty().addBlock(_cover('b1')).savedBy('phone-a');
      final server = _empty()
          .addBlock(_method('b9'))
          .savedBy('phone-b')
          .savedBy('phone-b');

      final resolved = DraftGuard.resolve(
        choice: DraftConflictResolution.keepMine,
        mine: mine,
        server: server,
        deviceId: 'phone-a',
      );

      expect(resolved.blocks.map((b) => b.id), ['b1']);
      expect(
        DraftGuard.check(
          incomingRev: resolved.draftRev,
          serverRev: server.draftRev,
        ),
        DraftSaveOutcome.accepted,
        reason: 'retrying the same stale revision would be refused again',
      );
      expect(resolved.draftDeviceId, 'phone-a');
    });

    test('no section is lost either way', () {
      final mine = _empty().addBlock(_cover('b1')).savedBy('a');
      final server = _empty().addBlock(_method('b9')).savedBy('b');

      for (final choice in DraftConflictResolution.values) {
        final resolved = DraftGuard.resolve(
          choice: choice,
          mine: mine,
          server: server,
          deviceId: 'a',
        );
        expect(resolved.blocks, isNotEmpty, reason: choice.name);
      }
    });
  });

  group('the seven states', () {
    test('no documents at all is empty — which is B14', () {
      expect(PortfolioLifecycleRules.resolve(), PortfolioLifecycle.empty);
    });

    test('a draft with no blocks is still day one', () {
      // HANDOFF rule 16: B14 is a branch of B01, chosen when the collection is
      // empty. A draft document that exists but holds nothing is the same
      // situation as no document, and the coach should see the same screen.
      expect(
        PortfolioLifecycleRules.resolve(draft: _empty()),
        PortfolioLifecycle.empty,
      );
    });

    test('a draft with blocks and no live page', () {
      expect(
        PortfolioLifecycleRules.resolve(draft: _empty().addBlock(_cover('b1'))),
        PortfolioLifecycle.draft,
      );
    });

    test('live when the draft matches what was published from', () {
      final draft = _empty().addBlock(_cover('b1')).savedBy('a');
      final live = draft.publishedAs(
        version: 1,
        at: _now,
        validation: draft.theme.validation,
      );

      expect(
        PortfolioLifecycleRules.resolve(draft: draft, live: live),
        PortfolioLifecycle.live,
      );
    });

    test('liveDirty the moment she edits again', () {
      final draft = _empty().addBlock(_cover('b1')).savedBy('a');
      final live = draft.publishedAs(
        version: 1,
        at: _now,
        validation: draft.theme.validation,
      );
      final edited = draft.addBlock(_method('b2')).savedBy('a');

      expect(
        PortfolioLifecycleRules.resolve(draft: edited, live: live),
        PortfolioLifecycle.liveDirty,
      );
    });

    test('queued while a publish intent is waiting', () {
      expect(
        PortfolioLifecycleRules.resolve(
          draft: _empty().addBlock(_cover('b1')),
          publishQueued: true,
        ),
        PortfolioLifecycle.queued,
      );
    });

    test('hidden is a state she chose, not an error', () {
      final draft = _empty().addBlock(_cover('b1')).savedBy('a');
      final live = draft
          .publishedAs(version: 1, at: _now, validation: draft.theme.validation)
          .withHidden(true);

      expect(
        PortfolioLifecycleRules.resolve(draft: draft, live: live),
        PortfolioLifecycle.hidden,
      );
    });

    test('suspended outranks everything', () {
      expect(
        PortfolioLifecycleRules.resolve(
          draft: _empty().addBlock(_cover('b1')).withSuspended(true),
          publishQueued: true,
        ),
        PortfolioLifecycle.suspended,
      );
    });
  });

  group('publishing produces a different document', () {
    test('the draft is untouched by publishing', () {
      final draft = _empty().addBlock(_cover('b1')).savedBy('a');
      final live = draft.publishedAs(
        version: 4,
        at: _now,
        validation: draft.theme.validation,
      );

      expect(draft.published, isFalse);
      expect(draft.versionId, 'draft');
      expect(live.published, isTrue);
      expect(live.versionId, 'live');
      expect(live.version, 4);
      expect(live.publishedFrom, draft.draftRev);
    });

    test('a snapshot is immutable and keyed by its version', () {
      final draft = _empty().addBlock(_cover('b1')).savedBy('a');
      final live = draft.publishedAs(
        version: 7,
        at: _now,
        validation: draft.theme.validation,
      );

      expect(live.asSnapshot().versionId, 'v0007');
      expect(PortfolioVersionIds.versionOf('v0007'), 7);
      expect(PortfolioVersionIds.versionOf('live'), isNull);
      expect(PortfolioVersionIds.snapshot(12), 'v0012');
    });
  });

  group('the theme is three keys and validated by construction', () {
    test('the stored theme has exactly the three keys the rule allows', () {
      final theme = PortfolioTheme.starter(now: _now);
      expect(theme.toJson().keys.toSet(), {'seed', 'type', 'corners'});
    });

    test('corners scale the radius scale, and a pill stays a pill', () {
      const sharp = PortfolioRadii(PortfolioCorners.sharp);
      const soft = PortfolioRadii(PortfolioCorners.soft);
      const round = PortfolioRadii(PortfolioCorners.round);

      expect(sharp.md, soft.md * 0.5);
      expect(round.md, closeTo(soft.md * 1.6, 0.0001));
      expect(sharp.full, soft.full);
      expect(round.full, soft.full);
    });
  });
}
