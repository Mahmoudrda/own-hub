/// Z14 — the switchboard. D25.
///
/// Every feature in the product with a switch beside it, so a flow can be
/// finished, merged and left unreachable until it is actually ready, rather
/// than becoming reachable the moment its code lands.
///
/// ## Why the rows are labelled with the enum identifier
///
/// `community`, `coachApp`, `payments` — not "Community", "Her coaching app".
/// This screen is operated by staff, the identifiers are exactly what appears
/// in `feature_flags.dart` and in a release note, and there is no ambiguity
/// about which switch you are throwing. Inventing display copy for twenty-one
/// features would put twenty-one untranslated English strings on a screen in a
/// bilingual product. The headings and the explanation are real dictionary
/// strings; the switch names are identifiers, and are meant to read as such.
///
/// ## Why a child can be "on" and still unreachable
///
/// Flags have parents. [FeatureFlags.isOn] walks the chain, so `communityPosts`
/// set on under a `community` that is off is genuinely unreachable — and the
/// row says so rather than showing a switch that appears to do nothing. That is
/// why the row reads [FeatureFlags.isSetOn] for the switch position and
/// [FeatureFlags.isOn] for whether it is live: collapsing the two would make
/// turning the parent on look like it had silently changed its children.
library;

import '../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/hand/hand.dart';

class FeatureFlagsView extends StatefulWidget {
  const FeatureFlagsView({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<FeatureFlagsView> createState() => _FeatureFlagsViewState();
}

class _FeatureFlagsViewState extends State<FeatureFlagsView> {
  /// The order features are listed in. Grouping is by what each switch is
  /// actually set to, not by phase -- a heading that reads "not switched on
  /// yet" above a switch that IS on is a screen telling its operator something
  /// untrue, which is the one thing this screen cannot afford to do.
  static const List<Feature> _order = [
    Feature.accountRequired,
    Feature.signUp,
    Feature.verification,
    Feature.today,
    Feature.train,
    Feature.eat,
    Feature.progress,
    Feature.cycle,
    Feature.privacyCentre,
    Feature.adminConsole,
  ];

  /// Listed after the above, newer and less proven, but grouped at render
  /// time by state like everything else.
  static const List<Feature> _later = [
    Feature.community,
    Feature.communityPosts,
    Feature.communityVideo,
    Feature.communityVoiceNotes,
    Feature.communityFollowerCounts,
    Feature.coachApp,
    Feature.coachPlanning,
    Feature.coachPortfolio,
    Feature.coachedLife,
    Feature.marketplace,
    Feature.payments,
    Feature.assistant,
  ];

  void _toggle(Feature f, bool on) {
    setState(() {
      AppRouter.featureFlags = AppRouter.featureFlags.with_({f: on});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final flags = AppRouter.featureFlags;
    const all = [..._order, ..._later];
    final on = [
      for (final f in all)
        if (flags.isSetOn(f)) f,
    ];
    final off = [
      for (final f in all)
        if (!flags.isSetOn(f)) f,
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceLow,
      appBar: AppBar(
        title: Text(l10n.featureFlags, style: AppText.titleM),
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const ScreenArtStrip(size: 84),
          const SizedBox(height: 12),
          // Structural: a staff console, so the note is a flat slip with an
          // exact edge and no hand in it.
          HandSurface(
            seed: handSeed(['feature-flags-note']),
            fill: AppColors.tertiarySoft,
            level: HandLevel.structural,
            radius: 5,
            looseCorner: 12,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.turningAFeatureOffHidesItEverywhere,
                    style: AppText.bodyM,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Grouped by what the switches are set to right now. With every
          // feature on, the second section is empty and is not drawn at all --
          // an empty heading is worse than no heading.
          if (on.isNotEmpty) ...[
            Text(l10n.builtAndLive, style: AppText.titleM),
            const SizedBox(height: 6),
            for (final f in on) _row(f, flags),
          ],
          if (off.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(l10n.notSwitchedOnYet, style: AppText.titleM),
            const SizedBox(height: 6),
            for (final f in off) _row(f, flags),
          ],
        ],
      ),
    );
  }

  Widget _row(Feature f, FeatureFlags flags) {
    final isChild = f.parent != null;
    final set = flags.isSetOn(f);
    final live = flags.isOn(f);

    // Set on, but an ancestor is off. Say so, rather than showing a switch
    // that looks like it did nothing.
    final blockedByParent = set && !live;

    return Padding(
      // Directional, not left: a child row indents from the start of the line,
      // which is the right-hand side under `ar`. `EdgeInsets.only(left:)` would
      // indent the wrong way in Arabic and put the nesting on the outside.
      padding: EdgeInsetsDirectional.only(
        start: isChild ? 20 : 0,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, style: AppText.bodyM),
                if (blockedByParent)
                  Text(
                    '${f.parent!.name} is off',
                    style: AppText.label.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: set, onChanged: (v) => _toggle(f, v)),
        ],
      ),
    );
  }
}
