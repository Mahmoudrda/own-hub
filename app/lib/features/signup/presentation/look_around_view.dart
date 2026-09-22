/// C04 — Look around, and C05 — the join prompt over it.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C04`/`C05`. The one screen a woman
/// sees before she has an account: a taste of the library, with the community
/// held back until she is verified.
///
/// C05 is not a separate page. In the prototype it is C04 with a sheet drawn
/// over it, and it is built that way here too — tapping a workout raises the
/// sheet. Duplicating the browse layout to make a second screen would mean two
/// things to keep in step.
///
/// The two workouts shown are **previews of real library content that does not
/// exist yet**. They are modelled as [PreviewWorkout] rather than written into
/// the widget, so pointing this at the real library later is a data change
/// instead of a rewrite.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';

/// A workout as shown in the pre-account preview.
class PreviewWorkout {
  const PreviewWorkout({required this.title, required this.detail});

  final String title;
  final String detail;
}

class LookAroundView extends StatefulWidget {
  const LookAroundView({
    super.key,
    this.onJoin,
    this.workouts,
    this.openJoinPrompt = false,
  });

  /// Raised from the header, the sheet, and the locked-community card. All three
  /// lead to the same place: C06, where she gives her number.
  final VoidCallback? onJoin;

  /// Injectable so a test — and later the real library — can supply its own.
  final List<PreviewWorkout>? workouts;

  /// Raises the join prompt as soon as the screen appears.
  ///
  /// C05 is a *state* of C04 rather than a page of its own — in the prototype it
  /// is this screen with a sheet drawn over it. A woman reaches it by tapping a
  /// workout. This flag exists so the route `C05` can still be opened directly
  /// for screen-by-screen review against the design, which QA has to do.
  final bool openJoinPrompt;

  @override
  State<LookAroundView> createState() => _LookAroundViewState();
}

class _LookAroundViewState extends State<LookAroundView> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openJoinPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptToJoin(context);
      });
    }
  }

  /// C05: "Save this workout?" — asked over the workout she just tapped, so she
  /// can still see what she would be saving.
  Future<void> _promptToJoin(BuildContext context) async {
    final l10n = AppL10n.of(context);
    await showAppSheet<void>(
      context: context,
      children: [
        Text(l10n.saveThisWorkout, style: AppText.titleL),
        Text(
          l10n.weJustNeedYourNumberAndA,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppButton(
          l10n.join,
          onPressed: () {
            Navigator.of(context).pop();
            widget.onJoin?.call();
          },
        ),
        AppButton(
          l10n.notNow,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final workouts =
        widget.workouts ??
        [
          PreviewWorkout(
            title: l10n.quietFullBody,
            detail: l10n.n15MinBeginnerNoEquipment,
          ),
          PreviewWorkout(
            title: l10n.floorLegsNoJumping,
            detail: l10n.n10MinBeginner,
          ),
        ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      // She is browsing as a guest, so the bar shows where she is without
      // pretending the other tabs are open to her yet.
      bottomNavigationBar: const AppNavBar(activeScreenId: 'R01'),
      body: AppScaffold(
        children: [
          Row(
            children: [
              // The guest's masthead, set large and left unmarked: the way in
              // beside it is the thing to notice.
              Expanded(
                child: Text(l10n.lookAround, style: EditorialType.section),
              ),
              AppButton(
                l10n.join,
                height: 40,
                fontSize: 15,
                onPressed: widget.onJoin,
              ),
            ],
          ),
          AppSegmented(
            items: [l10n.workouts, l10n.recipes, l10n.coaches],
            selectedIndex: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          for (final workout in workouts)
            AppListItem(
              title: workout.title,
              subtitle: workout.detail,
              leading: const AppMedia(
                width: 72,
                height: 56,
                borderRadius: AppRadius.sm,
                showPlayButton: false,
              ),
              trailing: const Icon(
                Icons.play_arrow,
                size: 22,
                color: AppColors.primaryDim,
              ),
              onTap: () => _promptToJoin(context),
            ),
          AppCard(
            variant: AppCardVariant.tonal,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield,
                    size: 24,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.membersAndTheirPostsAreBehindThe,
                          style: AppText.titleM,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.weKeepTheCommunityForVerifiedWomen,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppButton(
                l10n.joinAboutTwoMinutes,
                height: 48,
                fontSize: 15,
                onPressed: widget.onJoin,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
