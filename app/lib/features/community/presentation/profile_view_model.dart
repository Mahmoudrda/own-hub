/// What M07, M10, M14 and M15 draw.
///
/// ## The profile's restraint is in what is missing
///
/// M07's design note: *"The restraint is in what is still missing: no logs, no
/// weight, no photos she did not choose, and nothing that ranks one woman
/// against another."* There is no field on [ProfileScreenModel] for any of
/// those, so the screen cannot draw one.
///
/// ## Follower counts are off
///
/// `Feature.communityFollowerCounts` is false, so [ProfileScreenModel.followerLabel]
/// and [ProfileScreenModel.followingLabel] are **null** and the two stat columns
/// do not render. The flag is consulted rather than the absence hard-coded, so
/// switching it on is one change in one place — and even then the figure is a
/// `FollowerCount`, which cannot be ranked.
///
/// ## Not available means not available
///
/// A woman who turned her profile off and a woman who blocked her produce the
/// same [SurfaceAvailability.notAvailable]. M07 renders one state for both, by
/// design — G10 §5.1 says the two are *"identical, by design"*.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../domain/community_models.dart';
import '../domain/follow_state.dart';

/// A tab on M07's grid.
enum ProfileTab { photos, reels, followUps }

/// M07 — a member profile.
@immutable
class ProfileScreenModel {
  const ProfileScreenModel({
    required this.availability,
    required this.followState,
    required this.tabs,
    required this.tiles,
    this.name = '',
    this.bio = '',
    this.joinedMonth,
    this.verified = true,
    this.postCount = 0,
    this.followerLabel,
    this.followingLabel,
    this.isSelf = false,
  });

  factory ProfileScreenModel.from({
    required PublicProfile? profile,
    required String viewerUid,
    required String subjectUid,
    List<CommunityPost> posts = const <CommunityPost>[],
    bool isFollowing = false,
    bool hiddenEitherWay = false,
    bool pendingLocal = false,
    FeatureFlags flags = FeatureFlags.shipped,
    FollowStateResolver resolver = const FollowStateResolver(),
  }) {
    final availability = resolver.surfaceFor(
      profileExists: profile != null,
      hiddenEitherWay: hiddenEitherWay,
    );
    final followState = resolver.resolve(
      viewerUid: viewerUid,
      otherUid: subjectUid,
      isFollowing: isFollowing,
      hiddenEitherWay: hiddenEitherWay,
      profileDiscoverable: profile != null,
      pendingLocal: pendingLocal,
    );

    if (!availability.isAvailable || profile == null) {
      return ProfileScreenModel(
        availability: SurfaceAvailability.notAvailable,
        followState: followState,
        tabs: const <ProfileTab>[],
        tiles: const <ProfileTileModel>[],
      );
    }

    final showCounts = flags.isOn(Feature.communityFollowerCounts);

    return ProfileScreenModel(
      availability: availability,
      followState: followState,
      name: profile.name,
      bio: profile.bio,
      joinedMonth: profile.joinedMonth,
      verified: profile.verified,
      postCount: profile.postCount,
      followerLabel: showCounts ? profile.followerCount?.label : null,
      followingLabel: showCounts ? profile.followingCount?.label : null,
      isSelf: viewerUid == subjectUid,
      tabs: <ProfileTab>[
        ProfileTab.photos,
        // The reels tab exists only when video does. Consulted, not hard-coded.
        if (flags.isOn(Feature.communityVideo)) ProfileTab.reels,
        ProfileTab.followUps,
      ],
      tiles: <ProfileTileModel>[
        for (final p in posts)
          ProfileTileModel(
            postId: p.postId,
            blurred: p.blurApplied,
            hasMedia: p.media.isNotEmpty,
            caption: p.caption,
          ),
      ],
    );
  }

  final SurfaceAvailability availability;
  final FollowState followState;
  final String name;
  final String bio;
  final String? joinedMonth;
  final bool verified;
  final int postCount;

  /// Null while follower counts are off — which is always, at launch.
  final String? followerLabel;
  final String? followingLabel;

  final bool isSelf;
  final List<ProfileTab> tabs;
  final List<ProfileTileModel> tiles;

  bool get isAvailable => availability.isAvailable;

  String get postLabel => countLabel(postCount);

  /// Her own profile gets no follow button at all — not a disabled one.
  bool get showsFollowButton => followState != FollowState.self;

  bool get showsMessageButton =>
      followState != FollowState.self && followState != FollowState.unavailable;

  /// "Nothing here yet — what you post shows here", on her own empty profile.
  ///
  /// Only when her page really is empty: a tab with nothing in it (no
  /// follow-ups yet) on a page that has posts is not an empty page.
  bool get showsOwnEmptyState => isSelf && tiles.isEmpty && postCount == 0;

  /// Neither count renders while the flag is off.
  bool get showsFollowerCounts =>
      followerLabel != null || followingLabel != null;
}

/// One tile in a grid — M07, M10 and M15 all draw these.
@immutable
class ProfileTileModel {
  const ProfileTileModel({
    required this.postId,
    this.blurred = true,
    this.hasMedia = true,
    this.available = true,
    this.caption = '',
  });

  final String postId;
  final bool blurred;
  final bool hasMedia;

  /// What a text-only post says. A text post has no picture, so its tile shows
  /// the words rather than a photo placeholder that would imply one.
  final String caption;

  /// False once the post is gone — M15 shows the not-available tile rather
  /// than a broken image.
  final bool available;
}

/// M10 — Explore.
@immutable
class ExploreScreenModel {
  const ExploreScreenModel({
    required this.chips,
    required this.selectedChip,
    required this.tiles,
    this.profileResults = const <String>[],
    this.groupResults = const <String>[],
  });

  factory ExploreScreenModel.from({
    required List<CommunityPost> posts,
    CommunityTopic? selected,
    List<PublicProfile> profileResults = const <PublicProfile>[],
    List<CommunityGroup> groupResults = const <CommunityGroup>[],
  }) => ExploreScreenModel(
    // The chips that actually narrow it here. An enum, never free tags.
    chips: CommunityTopic.values,
    selectedChip: selected,
    tiles: <ProfileTileModel>[
      for (final p in posts)
        ProfileTileModel(
          postId: p.postId,
          blurred: p.blurApplied,
          hasMedia: p.media.isNotEmpty,
          caption: p.caption,
        ),
    ],
    profileResults: <String>[for (final p in profileResults) p.name],
    groupResults: <String>[for (final g in groupResults) g.name],
  );

  final List<CommunityTopic> chips;
  final CommunityTopic? selectedChip;
  final List<ProfileTileModel> tiles;
  final List<String> profileResults;
  final List<String> groupResults;

  /// "Nothing matches that" — and the smallest action is to clear the chip.
  bool get isEmpty =>
      tiles.isEmpty && profileResults.isEmpty && groupResults.isEmpty;

  bool get canClearChip => selectedChip != null;
}

/// M14 — Activity. People, not counters.
@immutable
class ActivityScreenModel {
  const ActivityScreenModel({required this.rows, this.followUpPrompt});

  factory ActivityScreenModel.from(List<ActivityItem> items) {
    final prompt = items
        .where((i) => i.kind == ActivityKind.followUpPrompt)
        .toList();
    return ActivityScreenModel(
      rows: <ActivityRowModel>[
        for (final i in items)
          if (i.kind != ActivityKind.followUpPrompt)
            ActivityRowModel(
              id: i.id,
              kind: i.kind,
              actorName: i.actor?.name ?? '',
              postId: i.postId,
              followsMe: i.followsMe,
            ),
      ],
      followUpPrompt: prompt.isEmpty ? null : prompt.first.postId,
    );
  }

  final List<ActivityRowModel> rows;

  /// The one nudge on the screen: her first post is eight weeks old. It is the
  /// engine of the whole follow-up feature, and it is the only prompt here.
  final String? followUpPrompt;

  /// "Nothing yet. This fills with women, not numbers."
  bool get isEmpty => rows.isEmpty && followUpPrompt == null;

  /// Nothing on this screen is a number going up.
  bool get showsCounters => false;
}

@immutable
class ActivityRowModel {
  const ActivityRowModel({
    required this.id,
    required this.kind,
    required this.actorName,
    this.postId,
    this.followsMe = false,
  });

  final String id;
  final ActivityKind kind;
  final String actorName;
  final String? postId;
  final bool followsMe;

  /// A follow row offers "Follow back"; nothing else does.
  bool get offersFollowBack => kind == ActivityKind.followed && !followsMe;
}

/// M15 — Saved. Private by construction.
@immutable
class SavedScreenModel {
  const SavedScreenModel({required this.tiles});

  factory SavedScreenModel.from(List<SavedPost> saved) => SavedScreenModel(
    tiles: <ProfileTileModel>[
      for (final s in saved)
        ProfileTileModel(
          postId: s.postId,
          available: s.isStillAvailable,
          hasMedia: s.isStillAvailable,
        ),
    ],
  );

  final List<ProfileTileModel> tiles;

  /// "Only you can see what you save" — and how to save.
  bool get isEmpty => tiles.isEmpty;

  /// Saved posts are a private library, never a public signal. Nothing here is
  /// visible to anyone else, and there is no sharing affordance.
  bool get isPrivate => true;
}
