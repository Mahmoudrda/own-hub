/// Rule 6 — **faces blurred by default, on device, before upload** — enforced by
/// making the unblurred draft unconstructible.
///
/// `G10-community.md` §5 names this file's job exactly:
///
/// > the constructor is private; the only factory calls `MediaBlurPolicy.resolve()`
/// > for the default … **A draft with `blurApplied == false` cannot be
/// > constructed** without a `BlurDecision.explicitOptOut(mediaId, at)` token,
/// > which is minted only by the per-image switch and is written into
/// > `blurOptOut`.
///
/// ## The three properties, and the mechanism for each
///
/// | Property | Mechanism |
/// |---|---|
/// | Blur is on unless she turns it off | [BlurComposition.start] mints a [BlurDecision.blurred] for every image, whatever happened last time |
/// | Turning it off is explicit and **per image** | [BlurDecision.explicitOptOut] needs a `mediaId`; there is no call that opts out of a whole post |
/// | The opt-out is **recorded** | an opted-out decision carries a [BlurOptOut], and [CommunityMediaDraft.blurOptOut] is non-null exactly when `blurApplied` is false |
///
/// `P0-COM-09` is the executable form: *"The opt-out applies to that image only.
/// `blurOptOut` records who and when. The next composition starts with blur on
/// again."*
///
/// ## Why a token and not a boolean
///
/// A `bool blurApplied` parameter can be typed `false` by anyone, anywhere,
/// including by a widget passing a variable it did not check. A [BlurDecision]
/// can only become an opt-out through a named factory that demands the image's
/// id and the moment — the two things the audit field needs. So the *evidence*
/// and the *permission* are the same object, and a draft cannot exist with one
/// but not the other.
///
/// ## The honest limit, stated rather than implied
///
/// `G10` `OQ-6`: a server cannot look at an image and know a face was blurred.
/// Enforcement is this constructor, plus the upload gateway, plus an attested
/// ticket, plus App Check, plus moderation. This file is the first of those and
/// claims to be no more than that.
///
/// ## What is NOT here
///
/// No face *classification* of any kind. Rule 8 permits detection for blur and
/// forbids inferring anything about a face. The pixel work belongs to G8's
/// platform channel, whose only exposed symbol is a blur call; this file decides
/// *whether* blur applies and records the decision, and never looks at an image.
library;

import 'package:meta/meta.dart';

/// Thrown when something tries to upload media that is neither blurred nor
/// carrying a recorded opt-out.
///
/// The second gate named in `G10` §5. The draft type below makes this state hard
/// to reach; this makes it impossible to *ship* if it ever is reached.
class BlurNotAppliedError extends Error {
  BlurNotAppliedError(this.mediaId);

  final String mediaId;

  @override
  String toString() =>
      'BlurNotAppliedError($mediaId): media reached the upload gateway with '
      'neither blur applied nor a recorded per-image opt-out. Rule 6 and spine '
      'C11 — no unblurred image reaches storage.';
}

/// Who turned blur off, and when. Written to `posts.blurOptOut`.
///
/// `by` is always the author: there is no other actor who could turn a woman's
/// blur off, and modelling it as an open string would invite one.
@immutable
class BlurOptOut {
  const BlurOptOut({required this.mediaId, required this.at});

  /// The one image this applies to. Per-image is the rule, not a nicety.
  final String mediaId;

  final DateTime at;

  /// The wire value for `blurOptOut.by`. A constant, because the author is the
  /// only actor rule 6 permits here.
  String get by => 'author';

  @override
  String toString() => 'BlurOptOut($mediaId by $by at $at)';
}

/// Blur on, or an explicit recorded opt-out. There is no third value.
@immutable
class BlurDecision {
  const BlurDecision._({required this.applied, this.optOut})
    : assert(
        applied || optOut != null,
        'blur is either applied, or turned off with a recorded opt-out. There '
        'is no third state: an unblurred image with no opt-out is exactly what '
        'rule 6 exists to prevent.',
      );

  /// The default, and what every composition starts with.
  const BlurDecision.blurred() : this._(applied: true);

  /// She turned it off for **this image**, and that is now on the record.
  ///
  /// The only route to `blurApplied == false`. It is deliberately verbose to
  /// call: an opt-out should look like a decision in the diff, not like a flag.
  factory BlurDecision.explicitOptOut({
    required String mediaId,
    required DateTime at,
  }) {
    if (mediaId.isEmpty) {
      throw ArgumentError.value(
        mediaId,
        'mediaId',
        'an opt-out is per image, so it must name one',
      );
    }
    return BlurDecision._(
      applied: false,
      optOut: BlurOptOut(mediaId: mediaId, at: at),
    );
  }

  /// Whether the pixels are blurred.
  final bool applied;

  /// Non-null exactly when [applied] is false.
  final BlurOptOut? optOut;

  @override
  String toString() =>
      applied ? 'BlurDecision(blurred)' : 'BlurDecision(optOut: $optOut)';
}

/// One image in a draft post, carrying its own blur decision.
///
/// The generative constructor is private and there is no `copyWith` that takes
/// a bool, so `blurApplied == false` is reachable only by handing [create] an
/// opt-out token.
@immutable
class CommunityMediaDraft {
  const CommunityMediaDraft._({
    required this.mediaId,
    required this.blurApplied,
    required this.blurOptOut,
  });

  /// The only way to make one.
  ///
  /// Takes a [BlurDecision] rather than a bool precisely so that the false case
  /// cannot be expressed without the evidence that justifies it.
  factory CommunityMediaDraft.create({
    required String mediaId,
    required BlurDecision decision,
  }) {
    if (mediaId.isEmpty) {
      throw ArgumentError.value(mediaId, 'mediaId', 'must not be empty');
    }
    final optOut = decision.optOut;
    if (optOut != null && optOut.mediaId != mediaId) {
      // An opt-out minted for another image is not consent for this one. Without
      // this check, one tap on one photo could silently unblur a second.
      throw ArgumentError.value(
        optOut.mediaId,
        'decision',
        'the opt-out was minted for a different image ($mediaId). Rule 6 makes '
            'turning blur off an explicit PER-IMAGE action.',
      );
    }
    return CommunityMediaDraft._(
      mediaId: mediaId,
      blurApplied: decision.applied,
      blurOptOut: optOut,
    );
  }

  final String mediaId;

  /// Written to `posts.blurApplied`. True unless she explicitly opted out.
  final bool blurApplied;

  /// Written to `posts.blurOptOut`. Non-null exactly when [blurApplied] is
  /// false — asserted by `P0-COM-09` rather than promised here.
  final BlurOptOut? blurOptOut;

  /// The gate `MediaUploadGateway` applies before any byte leaves the device.
  ///
  /// Throws rather than returning false: a caller that ignored a bool would
  /// upload, and this is the one place where being ignorable is unacceptable.
  void assertSafeToUpload() {
    if (!blurApplied && blurOptOut == null) throw BlurNotAppliedError(mediaId);
  }

  @override
  String toString() =>
      'CommunityMediaDraft($mediaId, blurApplied: $blurApplied)';
}

/// A single composition — one trip through the composer, however many images.
///
/// This type exists for one sentence in `P0-COM-09`: *"The next composition
/// starts with blur on again."* It holds no memory of a previous opt-out, and
/// [start] takes no parameter that could carry one forward. Blur-off is
/// therefore incapable of becoming sticky, which is the failure mode that turns
/// a per-image choice into a setting.
class BlurComposition {
  BlurComposition._(this._defaultOn);

  /// Begins a composition.
  ///
  /// [blurFacesDefault] is G7's `privacy.blurFacesDefault`, which ships **on**
  /// (`PrivacySettings.initial`). It is read here rather than in a widget so a
  /// screen cannot decide the default for itself.
  factory BlurComposition.start({bool blurFacesDefault = true}) =>
      BlurComposition._(blurFacesDefault);

  final bool _defaultOn;

  /// Every image she has decided about so far, in order.
  final List<CommunityMediaDraft> _drafts = <CommunityMediaDraft>[];

  List<CommunityMediaDraft> get drafts => List.unmodifiable(_drafts);

  /// Whether a freshly added image arrives blurred. Constant for the whole
  /// composition: opting one image out does not move it.
  bool get blurOnByDefault => _defaultOn;

  /// Adds an image, blurred.
  CommunityMediaDraft add(String mediaId) {
    final draft = CommunityMediaDraft.create(
      mediaId: mediaId,
      decision: _defaultOn
          ? const BlurDecision.blurred()
          // She has turned the default off in her privacy settings. That is
          // still a recorded per-image opt-out on every image, never a silent
          // unblurred upload — the audit trail does not get thinner because a
          // setting moved.
          : BlurDecision.explicitOptOut(mediaId: mediaId, at: DateTime.now()),
    );
    _drafts.add(draft);
    return draft;
  }

  /// She tapped the switch on one image.
  ///
  /// Replaces that image's draft and leaves every other image untouched, which
  /// is the per-image half of `P0-COM-09`.
  CommunityMediaDraft optOut(String mediaId, {required DateTime at}) {
    final index = _drafts.indexWhere((d) => d.mediaId == mediaId);
    if (index < 0) {
      throw StateError('no image $mediaId in this composition');
    }
    final replaced = CommunityMediaDraft.create(
      mediaId: mediaId,
      decision: BlurDecision.explicitOptOut(mediaId: mediaId, at: at),
    );
    _drafts[index] = replaced;
    return replaced;
  }

  /// She changed her mind and turned blur back on for one image.
  CommunityMediaDraft reblur(String mediaId) {
    final index = _drafts.indexWhere((d) => d.mediaId == mediaId);
    if (index < 0) {
      throw StateError('no image $mediaId in this composition');
    }
    final replaced = CommunityMediaDraft.create(
      mediaId: mediaId,
      decision: const BlurDecision.blurred(),
    );
    _drafts[index] = replaced;
    return replaced;
  }

  /// True when every image in the composition is blurred.
  bool get allBlurred => _drafts.every((d) => d.blurApplied);
}
