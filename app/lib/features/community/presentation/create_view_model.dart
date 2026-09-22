/// What M03, M09, M11, M12 and M16 draw — and what they do **not** offer while
/// the launch scope defers it.
///
/// ## Deferred is a flag, not a deletion
///
/// The owner's launch scope is photos and text. Video, reels and voice notes are
/// deferred. Every one of those capabilities is therefore **absent behind a
/// flag** rather than absent from the code: [CreateOptionsModel] asks
/// `FeatureFlags` whether to offer the Reel tile and the voice-note row, and
/// [ReelsScreenModel] and [RecordScreenModel] ask before offering a video mode.
///
/// That distinction matters at the moment the flag flips. A hard-coded absence
/// means switching `communityVideo` on does nothing and somebody has to find
/// every place the capability was quietly removed. A flag-gated absence means
/// the surface appears.
///
/// What is genuinely **not built** is the machinery behind video: there is no
/// capture, no frame sampling, no blur export and no transcode anywhere in this
/// feature. Turning the flag on would reveal the surfaces and reach a publish
/// path that refuses a reel — which is the honest state, and is why
/// `PostPublishService.allows` is the single place that decides.
///
/// ## The follow-up is the new idea, and it is the one with rules
///
/// M11 attaches a picture to a post she **already made**, so the pair is always
/// her own two moments. [FollowUpComposerModel] offers only her own parent
/// posts, because [FollowUpPolicy] is what decides and it refuses everything
/// else. M12 renders a [FollowUpChain], which cannot hold two authors.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../domain/community_models.dart';
import '../domain/follow_up_policy.dart';

/// The ways into creating something, in M03's order.
enum CreateOption {
  /// The big tile. Deferred — `communityVideo`.
  reel,

  /// The other big tile, and the new idea.
  followUp,

  /// The launch scope: a photo, or a caption on its own.
  photoOrPost,

  /// Numbers she lifted, never a scale weight.
  personalBest,

  /// Deferred — `communityVoiceNotes`.
  voiceNote,
}

/// M03 — Create.
@immutable
class CreateOptionsModel {
  const CreateOptionsModel({
    required this.options,
    required this.blurOn,
    this.hasParentPost = false,
  });

  factory CreateOptionsModel.from({
    FeatureFlags flags = FeatureFlags.shipped,
    bool hasParentPost = false,
    bool blurFacesDefault = true,
  }) => CreateOptionsModel(
    options: <CreateOption>[
      if (flags.isOn(Feature.communityVideo)) CreateOption.reel,
      // A follow-up needs something to follow up on. Offering it with no
      // parent post would be an action that cannot succeed.
      if (flags.isOn(Feature.communityPosts) && hasParentPost)
        CreateOption.followUp,
      if (flags.isOn(Feature.communityPosts)) CreateOption.photoOrPost,
      if (flags.isOn(Feature.communityPosts)) CreateOption.personalBest,
      if (flags.isOn(Feature.communityVoiceNotes)) CreateOption.voiceNote,
    ],
    blurOn: blurFacesDefault,
    hasParentPost: hasParentPost,
  );

  final List<CreateOption> options;

  /// The switch is visible before anything is chosen, and it is **on**.
  final bool blurOn;

  final bool hasParentPost;

  bool offers(CreateOption option) => options.contains(option);

  /// "Once you have a post to follow up on" — the state M03 explains rather
  /// than a tile that would fail.
  bool get explainsFollowUpLater =>
      !hasParentPost && !offers(CreateOption.followUp);

  /// The personal-best card is the way to share a win **without a body photo**,
  /// and it carries numbers she lifted — never a weight from the scale.
  bool get bestCarriesScaleWeight => false;
}

/// M09 — Reels. Deferred at launch.
@immutable
class ReelsScreenModel {
  const ReelsScreenModel({required this.available, this.reels = const []});

  factory ReelsScreenModel.from({
    FeatureFlags flags = FeatureFlags.shipped,
    List<CommunityPost> reels = const <CommunityPost>[],
  }) {
    if (!flags.isOn(Feature.communityVideo)) {
      return const ReelsScreenModel(available: false);
    }
    return ReelsScreenModel(
      available: true,
      reels: <String>[for (final r in reels) r.postId],
    );
  }

  /// False while `communityVideo` is off. The screen renders its unavailable
  /// state rather than an empty player.
  final bool available;

  final List<String> reels;

  /// "No reels yet", once video exists and she has none.
  bool get isEmpty => available && reels.isEmpty;
}

/// A mode on M16's camera rail.
enum RecordMode { reel, story, post }

/// M16 — Record.
@immutable
class RecordScreenModel {
  const RecordScreenModel({
    required this.modes,
    required this.blurOn,
    required this.available,
    this.offersVoiceNote = false,
  });

  factory RecordScreenModel.from({
    FeatureFlags flags = FeatureFlags.shipped,
    bool blurFacesDefault = true,
  }) {
    final video = flags.isOn(Feature.communityVideo);
    final posts = flags.isOn(Feature.communityPosts);
    return RecordScreenModel(
      available: posts || video,
      modes: <RecordMode>[
        if (video) RecordMode.reel,
        if (posts) RecordMode.story,
        if (posts) RecordMode.post,
      ],
      blurOn: blurFacesDefault,
      // The rail's Voice control. Asked rather than deleted, for the same
      // reason the Reel tile is: when `communityVoiceNotes` is switched on the
      // control returns with no code change on the screen.
      offersVoiceNote: flags.isOn(Feature.communityVoiceNotes),
    );
  }

  final List<RecordMode> modes;

  /// Blur sits on the rail beside the timer and the light, so it reads as an
  /// ordinary camera control rather than a privacy setting buried elsewhere.
  final bool blurOn;

  final bool available;

  /// Whether the rail offers the Voice control. False at launch — a whole
  /// content type with no moderation story is a safety gap (`OQ-8`).
  final bool offersVoiceNote;

  bool offers(RecordMode mode) => modes.contains(mode);

  /// No video mode is offered while `communityVideo` is off, and there is no
  /// capture behind it either.
  bool get offersVideo => offers(RecordMode.reel);
}

/// One of her own posts, offered on M11 as something to follow up on.
@immutable
class FollowUpCandidateModel {
  const FollowUpCandidateModel({
    required this.postId,
    required this.caption,
    required this.selected,
  });

  final String postId;
  final String caption;
  final bool selected;
}

/// M11 — Add a follow-up.
@immutable
class FollowUpComposerModel {
  const FollowUpComposerModel({
    required this.candidates,
    required this.blurBothFrames,
    this.selectedPostId,
    this.cost,
  });

  /// Only her own, non-follow-up posts can be candidates.
  ///
  /// Filtered through [FollowUpPolicy] rather than by a `where` written here,
  /// so the UI cannot offer something the rules would refuse — `P0-COM-04`
  /// requires it to be *"not offered in the UI"* as well as server-refused.
  factory FollowUpComposerModel.from({
    required List<CommunityPost> ownPosts,
    required String viewerUid,
    String? selectedPostId,
    FollowUpCost? cost,
    FollowUpPolicy policy = const FollowUpPolicy(),
  }) {
    final offerable = <CommunityPost>[
      for (final p in ownPosts)
        if (policy.canAttach(
          parent: FollowUpParent(
            postId: p.postId,
            authorUid: p.authorUid,
            parentPostId: p.parentPostId,
          ),
          authorUid: viewerUid,
        ))
          p,
    ];

    return FollowUpComposerModel(
      candidates: <FollowUpCandidateModel>[
        for (final p in offerable)
          FollowUpCandidateModel(
            postId: p.postId,
            caption: p.caption,
            selected: p.postId == selectedPostId,
          ),
      ],
      // Blur applies to BOTH frames, and to the old one too.
      blurBothFrames: true,
      selectedPostId: selectedPostId,
      cost: cost,
    );
  }

  final List<FollowUpCandidateModel> candidates;
  final bool blurBothFrames;
  final String? selectedPostId;

  /// Offered, not required. Two integers or nothing.
  final FollowUpCost? cost;

  bool get canPost => selectedPostId != null;

  /// Nothing to follow up on yet.
  bool get isEmpty => candidates.isEmpty;

  String? get sessionsLabel => cost == null ? null : countLabel(cost!.sessions);
  String? get countedWeeksLabel =>
      cost == null ? null : countLabel(cost!.countedWeeks);

  /// There is no field here a scale weight could occupy.
  bool get costCarriesWeight => false;
}

/// One moment in the M12 strip.
@immutable
class FollowUpMomentModel {
  const FollowUpMomentModel({
    required this.postId,
    required this.isNow,
    required this.weeksIn,
  });

  final String postId;

  /// The last frame reads as "Now" rather than a week number.
  final bool isNow;

  /// Whole weeks between the parent and this moment.
  final int weeksIn;

  String get weekLabel => countLabel(weeksIn);
}

/// M12 — the follow-up thread: one woman, over time.
@immutable
class FollowUpThreadModel {
  const FollowUpThreadModel({
    required this.moments,
    required this.authorUid,
    this.cost,
  });

  /// Takes a [FollowUpChain], which **cannot hold two authors**.
  ///
  /// That is the whole of `P0-COM-05`: the widget is given a chain, and a chain
  /// naming two women throws at construction — so there is no surface anywhere
  /// that places two different women side by side.
  factory FollowUpThreadModel.from(FollowUpChain chain) {
    final first = chain.parent.takenAt;
    return FollowUpThreadModel(
      authorUid: chain.authorUid,
      moments: <FollowUpMomentModel>[
        for (var i = 0; i < chain.moments.length; i++)
          FollowUpMomentModel(
            postId: chain.moments[i].postId,
            isNow: i == chain.moments.length - 1 && chain.hasFollowUps,
            weeksIn: chain.moments[i].takenAt.difference(first).inDays ~/ 7,
          ),
      ],
      cost: chain.moments.last.cost,
    );
  }

  final List<FollowUpMomentModel> moments;

  /// One author, always. There is no second.
  final String authorUid;

  final FollowUpCost? cost;

  bool get showsCost => cost != null;

  String? get sessionsLabel => cost == null ? null : countLabel(cost!.sessions);
  String? get countedWeeksLabel =>
      cost == null ? null : countLabel(cost!.countedWeeks);

  /// A thread is one woman over time — never two women side by side.
  bool get hasSingleAuthor => true;
}
