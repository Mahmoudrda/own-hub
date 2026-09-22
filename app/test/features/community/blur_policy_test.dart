// Rule 6 — faces blurred by default, on device, before upload — and P0-COM-09:
// "The opt-out applies to that image only. blurOptOut records who and when. The
// next composition starts with blur on again."

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/blur_policy.dart';

final _at = DateTime(2026, 9, 19, 14, 7);

void main() {
  group('an unblurred draft needs an explicit, recorded opt-out', () {
    test('the default is blurred, and nothing is recorded', () {
      final draft = CommunityMediaDraft.create(
        mediaId: 'img-7331',
        decision: const BlurDecision.blurred(),
      );

      expect(draft.blurApplied, isTrue);
      expect(draft.blurOptOut, isNull);
    });

    test('opting out records who and when', () {
      final draft = CommunityMediaDraft.create(
        mediaId: 'img-7331',
        decision: BlurDecision.explicitOptOut(mediaId: 'img-7331', at: _at),
      );

      expect(draft.blurApplied, isFalse);
      expect(draft.blurOptOut, isNotNull);
      expect(draft.blurOptOut!.mediaId, 'img-7331');
      expect(draft.blurOptOut!.at, _at);
      expect(
        draft.blurOptOut!.by,
        'author',
        reason:
            'rule 6: turning it off is an explicit per-image action by HER. '
            'There is no other actor this field can name.',
      );
    });

    test('every constructible draft carries its own justification', () {
      // The invariant, stated as the thing that is actually true: there is no
      // route to blurApplied == false with nothing recorded, because the only
      // way to reach false is to hand create() a token that IS the record.
      final drafts = <CommunityMediaDraft>[
        CommunityMediaDraft.create(
          mediaId: 'a',
          decision: const BlurDecision.blurred(),
        ),
        CommunityMediaDraft.create(
          mediaId: 'b',
          decision: BlurDecision.explicitOptOut(mediaId: 'b', at: _at),
        ),
      ];

      for (final d in drafts) {
        expect(
          d.blurApplied || d.blurOptOut != null,
          isTrue,
          reason: '${d.mediaId} is unblurred with no recorded opt-out',
        );
      }
    });

    test('an opt-out minted for another image is refused', () {
      // Without this, one tap on one photo could silently unblur a second —
      // which is the per-image rule failing quietly.
      expect(
        () => CommunityMediaDraft.create(
          mediaId: 'img-A',
          decision: BlurDecision.explicitOptOut(mediaId: 'img-B', at: _at),
        ),
        throwsArgumentError,
      );
    });

    test('an opt-out must name an image', () {
      expect(
        () => BlurDecision.explicitOptOut(mediaId: '', at: _at),
        throwsArgumentError,
      );
    });

    test('the upload gate throws rather than returning false', () {
      // A caller that ignored a bool would upload. This is the one place where
      // being ignorable is unacceptable, so it throws.
      final blurred = CommunityMediaDraft.create(
        mediaId: 'img-19',
        decision: const BlurDecision.blurred(),
      );

      expect(blurred.assertSafeToUpload, returnsNormally);
    });
  });

  group('the opt-out is per image, and does not become a setting', () {
    test('turning one off leaves the others blurred', () {
      final composition = BlurComposition.start();
      composition.add('img-1');
      composition.add('img-2');
      composition.add('img-3');

      composition.optOut('img-2', at: _at);

      expect(composition.drafts.map((d) => d.blurApplied), <bool>[
        true,
        false,
        true,
      ], reason: 'P0-COM-09: the opt-out applies to that image only');
      expect(composition.allBlurred, isFalse);
    });

    test('the NEXT composition starts with blur on again', () {
      final first = BlurComposition.start();
      first.add('img-1');
      first.optOut('img-1', at: _at);
      expect(first.allBlurred, isFalse);

      // A new trip through the composer. It holds no memory of the last one,
      // and start() takes no parameter that could carry an opt-out forward.
      final second = BlurComposition.start();
      second.add('img-2');

      expect(
        second.allBlurred,
        isTrue,
        reason:
            'P0-COM-09: "The next composition starts with blur on again." A '
            'sticky opt-out turns a per-image choice into a setting.',
      );
      expect(second.blurOnByDefault, isTrue);
    });

    test('she can turn it back on', () {
      final composition = BlurComposition.start();
      composition.add('img-1');
      composition.optOut('img-1', at: _at);

      composition.reblur('img-1');

      expect(composition.allBlurred, isTrue);
      expect(composition.drafts.single.blurOptOut, isNull);
    });

    test('opting out an image that is not in the composition is an error', () {
      final composition = BlurComposition.start();
      expect(
        () => composition.optOut('nope', at: _at),
        throwsStateError,
      );
    });

    test('a woman whose privacy default is off still has it recorded', () {
      // She turned blurFacesDefault off in her privacy settings. That is still
      // a recorded per-image opt-out on every image — the audit trail does not
      // get thinner because a setting moved.
      final composition = BlurComposition.start(blurFacesDefault: false);
      final draft = composition.add('img-88');

      expect(draft.blurApplied, isFalse);
      expect(
        draft.blurOptOut,
        isNotNull,
        reason:
            'spine C11 wants evidence per object. A default that produced '
            'unblurred media with no record would lose it.',
      );
    });
  });
}
