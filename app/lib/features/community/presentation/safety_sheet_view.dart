/// **M08 — report, block, mute.** Two taps to safety, from every post, profile
/// and reel.
///
/// ## Why blocking takes a second step and not a dialog
///
/// Rule 9 is *undo, not confirmation*, and G7 grants a documented exemption for
/// **destructive non-logging** actions: deleting a post and blocking may
/// confirm. `G10` §5 restates it so QA does not read a confirm as a violation.
///
/// But `product_rules_test.dart` forbids `showDialog` and `AlertDialog`
/// anywhere under `lib/features/`, and that guard is right — a dialog is the
/// shape rule 9 is about. So the confirmation is a **second step inside this
/// sheet**: the same deliberateness, none of the banned widget. Like, save,
/// follow and publish raise nothing at all.
///
/// ## The one thing this sheet must never say
///
/// A queued report is **not** a filed report. `P0-COM-14`: it must never render
/// as "a moderator is reading it". The sheet asks
/// [SafetySheetModel.mayPromiseAnHour], which is false until the report has a
/// server stamp — and the reassuring line is simply absent until then.
///
/// The sentence the queued state wants — *"Not sent yet. It will send when you
/// have signal, and the hour starts then."* — is **absent from the dictionary**
/// and is reported with the build rather than invented here.
library;

import '../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sheet.dart';
import '../../account/domain/safety.dart';
import 'feed_view_model.dart';

class SafetySheetView extends StatefulWidget {
  const SafetySheetView({
    super.key,
    required this.model,
    this.onReport,
    this.onReportReason,
    this.onBlock,
    this.onMute,
    this.onUnmute,
    this.onLeaveGroup,
    this.onDelete,
    this.onCancel,
  });

  final SafetySheetModel model;
  final VoidCallback? onReport;

  /// Files the report, with the reason she picked.
  ///
  /// When this is given, "report" opens a second step inside the sheet — the
  /// reasons — instead of filing something with no reason on it. The list is
  /// `ReportReason`, the same seven G7 files against a woman.
  final ValueChanged<ReportReason>? onReportReason;

  final VoidCallback? onBlock;
  final VoidCallback? onMute;

  /// Offered instead of mute once the group is already quiet.
  final VoidCallback? onUnmute;

  /// Leaving the room. One tap, and Join brings her straight back.
  final VoidCallback? onLeaveGroup;

  /// Deleting her own post. The documented exemption to rule 9, as a second
  /// step in this sheet rather than a dialog.
  final VoidCallback? onDelete;

  final VoidCallback? onCancel;

  @override
  State<SafetySheetView> createState() => _SafetySheetViewState();
}

class _SafetySheetViewState extends State<SafetySheetView> {
  /// The second step for blocking. Not a dialog — see the library comment.
  bool _confirmingBlock = false;

  /// The same shape for deleting her own post, which G10 §5 exempts for the
  /// same reason: it cannot be undone.
  bool _confirmingDelete = false;

  /// The reasons step. Reporting without one files an empty report.
  bool _pickingReason = false;

  /// The seven reasons, in the order G7 lists them.
  static const List<ReportReason> _reasons = ReportReason.values;

  String _reasonLabel(ReportReason reason, AppL10n l10n) => switch (reason) {
    ReportReason.harassment => l10n.harassmentOrBullying,
    ReportReason.manAccount => l10n.thisIsAMansAccount,
    ReportReason.nudity => l10n.nudity,
    ReportReason.spam => l10n.spam,
    ReportReason.impersonation => l10n.pretendingToBeSomeoneElse,
    ReportReason.selfHarm => l10n.selfHarm,
    ReportReason.other => l10n.anotherReason,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    // The reasons, as a second step in the same sheet. Filing a report with no
    // reason on it is not a report a moderator can act on.
    if (_pickingReason) {
      return AppSheet(
        children: [
          const ScreenArtStrip(size: 76),
          Text(l10n.whyAreYouReportingThis, style: AppText.titleL),
          for (final reason in _reasons)
            AppListItem(
              title: _reasonLabel(reason, l10n),
              onTap: () {
                widget.onReportReason?.call(reason);
                setState(() => _pickingReason = false);
              },
            ),
          AppButton(
            l10n.cancel,
            variant: AppButtonVariant.text,
            height: 46,
            fontSize: 15,
            onPressed: () => setState(() => _pickingReason = false),
          ),
        ],
      );
    }

    return AppSheet(
      children: [
        const ScreenArtStrip(size: 76),
        Text(l10n.whatWouldYouLikeToDo, style: AppText.titleL),

        if (model.actions.contains(SafetyAction.report))
          AppListItem(
            leading: const Icon(
              Icons.flag_outlined,
              size: 23,
              color: AppColors.error,
            ),
            title: l10n.reportThisPost,
            // Only says an hour once the report can actually have started one.
            // Offline this line is absent, and nothing replaces it, because the
            // sentence that belongs here does not exist yet.
            subtitle: model.mayPromiseAnHour
                ? l10n.aWomanModeratorReadsItUsuallyWithin
                : '',
            onTap: widget.onReportReason == null
                ? widget.onReport
                : () => setState(() => _pickingReason = true),
          ),

        // Hers to take down. Deleting is not hiding: the document goes and the
        // media with it, which is why it takes a second step.
        if (widget.onDelete != null)
          AppListItem(
            leading: const Icon(
              Icons.delete_outline,
              size: 23,
              color: AppColors.error,
            ),
            title: l10n.deleteThisPost,
            subtitle: _confirmingDelete
                ? l10n.tapAgainToDeleteItEverywhere
                : '',
            trailing: _confirmingDelete
                ? AppButton(
                    l10n.undo,
                    variant: AppButtonVariant.text,
                    height: 38,
                    fontSize: 14,
                    onPressed: () => setState(() => _confirmingDelete = false),
                  )
                : null,
            onTap: () {
              if (_confirmingDelete) {
                widget.onDelete?.call();
              } else {
                setState(() => _confirmingDelete = true);
              }
            },
          ),

        if (model.actions.contains(SafetyAction.block))
          AppListItem(
            leading: const Icon(
              Icons.block,
              size: 23,
              color: AppColors.onSurface,
            ),
            // The dictionary has no generic "Block" or "Block {name}" — only a
            // sample naming one woman, which would be wrong for everyone else.
            // The row is carried by its subtitle, which says exactly what
            // blocking does, and the missing label is reported.
            subtitle: l10n.sheDisappearsFromYourFeedAndCannot,
            trailing: _confirmingBlock
                ? AppButton(
                    l10n.undo,
                    variant: AppButtonVariant.text,
                    height: 38,
                    fontSize: 14,
                    onPressed: () => setState(() => _confirmingBlock = false),
                  )
                : null,
            onTap: () {
              if (!model.blockTakesASecondStep) {
                widget.onBlock?.call();
                return;
              }
              if (_confirmingBlock) {
                widget.onBlock?.call();
              } else {
                setState(() => _confirmingBlock = true);
              }
            },
          ),

        if (model.actions.contains(SafetyAction.muteGroup))
          AppListItem(
            leading: const Icon(
              Icons.do_not_disturb_on_outlined,
              size: 23,
              color: AppColors.onSurface,
            ),
            // Quiet already? Then the action is the other one. A mute she
            // cannot lift is a mute she has to leave the group to escape.
            title: widget.onUnmute != null
                ? l10n.unmuteThisGroup
                : l10n.muteThisGroupForAWeek,
            // Mute exists because leaving a group should not be the only way
            // to get quiet.
            subtitle: widget.onUnmute != null ? '' : l10n.stillAMemberJustQuiet,
            onTap: widget.onUnmute ?? widget.onMute,
          ),

        if (widget.onLeaveGroup != null)
          AppListItem(
            leading: const Icon(
              Icons.logout,
              size: 23,
              color: AppColors.onSurface,
            ),
            // Reversible in one tap from M04, so it asks nothing.
            title: l10n.leaveGroup,
            onTap: widget.onLeaveGroup,
          ),

        AppButton(
          l10n.cancel,
          variant: AppButtonVariant.text,
          height: 46,
          fontSize: 15,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}
