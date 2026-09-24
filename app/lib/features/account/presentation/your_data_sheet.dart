/// A02's "Your data" row, opened.
///
/// # What it is for
///
/// Apple 5.1.1(v) requires an account that can be created in the app to be
/// deletable in the app, and 2.1 refuses a control that does nothing. The row
/// existed, its callback was never passed, and the tap did nothing at all:
/// exactly both rejections in one line of a settings list.
///
/// # A sheet, not a screen
///
/// There is no screen id for account deletion among the 161, and HANDOFF rule
/// 16 forbids inventing one for a state. It is also the shape the product
/// already uses for this: `privacy_settings.dart` records account deletion and
/// blocking as the two documented exemptions from rule 9's "undo, not
/// confirmation", and says both confirm **in a sheet, never a dialog**.
///
/// The sheet is one step, not two. It explains, and the button under the
/// explanation does the thing. Asking again afterwards would be a second
/// confirmation of a decision she has already read the consequences of.
///
/// # It says what this build can and cannot do
///
/// There is no server in this build, so there is nothing to download and
/// nothing held anywhere but the handset. The sheet says both plainly instead
/// of offering an export button that would spin and produce nothing, which is
/// the failure mode 2.1 is actually about.
///
/// The deletion itself is not here: `lib/features/**` describes what a woman
/// sees. The router hands in [onDelete], which runs
/// `deleteEverythingOnThisPhone()` in `lib/app_state/account_data.dart`.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';

/// Shows the sheet. Returns true once she has asked for the deletion.
///
/// [onDelete] is awaited **before** the sheet closes, so nothing can be tapped
/// against a half-cleared store.
Future<bool> showYourDataSheet(
  BuildContext context, {
  required Future<void> Function() onDelete,
}) async {
  final asked = await showAppSheet<bool>(
    context: context,
    children: [YourDataSheet(onDelete: onDelete)],
  );
  return asked ?? false;
}

class YourDataSheet extends StatefulWidget {
  const YourDataSheet({super.key, required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<YourDataSheet> createState() => _YourDataSheetState();
}

class _YourDataSheetState extends State<YourDataSheet> {
  /// True while the wipe is running. It is instant in this build, and the flag
  /// exists so a second tap cannot start a second deletion, not so a progress
  /// bar can be drawn for work nobody acknowledged.
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    await widget.onDelete();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.yourData, style: AppText.titleL),
        const SizedBox(height: 14),

        // The list names what goes. "your posts" belongs to a feature the
        // first release ships without, and a sentence about deleting
        // something she was never able to make is the same invention as a
        // control that leads nowhere. Same sentence, only what exists.
        Text(
          AppRouter.featureFlags.isOn(Feature.community)
              ? l10n.deletingTakesAwayEverythingYouHavePut
              : l10n.deletingTakesAwayEverythingYouHavePut_g3hy0,
          style: AppText.bodyM,
        ),
        const SizedBox(height: 10),
        Text(l10n.thisBuildKeepsEverythingOnThisPhone, style: quiet),
        const SizedBox(height: 10),

        // The download. Said, not offered: a button here would be the dead
        // control this sheet exists to remove.
        Text(l10n.downloadingACopyOfYourDataIs, style: quiet),

        const SizedBox(height: 16),
        AppButton(l10n.deleteEverything, onPressed: _deleting ? null : _delete),
        const SizedBox(height: 8),
        AppButton(
          l10n.cancel,
          variant: AppButtonVariant.outlined,
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
