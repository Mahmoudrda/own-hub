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
/// # It says what deleting does, and what it did
///
/// With an account, deleting removes it from the server and clears this
/// phone, and the sheet names the three things kept on purpose. With no
/// account, this phone is the whole of it. The download is still said rather
/// than offered: there is no export yet, and a button that produced nothing
/// is the failure mode 2.1 is about.
///
/// While the server works she is told so. If there is no connection she is
/// told nothing was deleted and the sheet stays open; the router tells her
/// the rest (done, or "it will finish within the hour").
///
/// The deletion itself is not here: `lib/features/**` describes what a woman
/// sees. The router hands in [onDelete], which runs `deleteAccount()` in
/// `lib/app_state/account_data.dart`.
library;

import 'package:flutter/material.dart';

import '../../../config/legal_links.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../domain/account_deletion_service.dart';

/// Shows the sheet. Returns what the deletion came to, or null when she
/// cancelled. Never [AccountDeletionResult.offline] or
/// [AccountDeletionResult.appCannotReach]: those keep the sheet open.
///
/// [onDelete] is awaited **before** the sheet closes, so nothing can be tapped
/// against a half-cleared store.
Future<AccountDeletionResult?> showYourDataSheet(
  BuildContext context, {
  required Future<AccountDeletionResult> Function() onDelete,
  bool hasAccount = false,
}) {
  return showAppSheet<AccountDeletionResult>(
    context: context,
    children: [YourDataSheet(onDelete: onDelete, hasAccount: hasAccount)],
  );
}

class YourDataSheet extends StatefulWidget {
  const YourDataSheet({
    super.key,
    required this.onDelete,
    this.hasAccount = false,
    this.webDeletionUrl = LegalLinks.deleteAccount,
  });

  /// The public delete-account page. Named when this copy of the app is
  /// refused (R3), so she still has a way to delete that needs no update.
  /// Empty until the site is published, and then nothing is shown.
  final String webDeletionUrl;

  final Future<AccountDeletionResult> Function() onDelete;

  /// Whether there is an account on the server to delete as well.
  final bool hasAccount;

  @override
  State<YourDataSheet> createState() => _YourDataSheetState();
}

class _YourDataSheetState extends State<YourDataSheet> {
  /// True while the wipe is running. It is instant in this build, and the flag
  /// exists so a second tap cannot start a second deletion, not so a progress
  /// bar can be drawn for work nobody acknowledged.
  bool _deleting = false;

  /// Why nothing was deleted, when nothing was.
  AccountDeletionResult? _refused;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _refused = null;
    });
    final result = await widget.onDelete();
    if (!mounted) return;
    switch (result) {
      case AccountDeletionResult.offline:
      case AccountDeletionResult.appCannotReach:
        setState(() {
          _deleting = false;
          _refused = result;
        });
      case AccountDeletionResult.done:
      case AccountDeletionResult.unfinished:
        Navigator.of(context).pop(result);
    }
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
        Text(
          widget.hasAccount
              ? l10n.deletingYourAccountRemovesItFromOur
              : l10n.youHaveNoAccountOnThisPhone,
          style: quiet,
        ),
        const SizedBox(height: 10),

        // The download. Said, not offered: a button here would be the dead
        // control this sheet exists to remove.
        Text(l10n.downloadingACopyOfYourDataIs, style: quiet),

        if (_deleting && widget.hasAccount) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(l10n.deletingYourAccountThisCanTakeA, style: quiet),
          ),
        ],
        if (_refused != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _refused == AccountDeletionResult.appCannotReach
                  ? l10n.thisCopyOfTheAppCannotReach_qzcpf
                  : l10n.weCouldNotReachOwnHubSo_yfi5n,
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
          if (_refused == AccountDeletionResult.appCannotReach &&
              widget.webDeletionUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              l10n.youCanAlsoDeleteYourAccountOn(widget.webDeletionUrl),
              key: const ValueKey('your-data-web-deletion'),
              style: quiet,
            ),
          ],
        ],

        const SizedBox(height: 16),
        AppButton(l10n.deleteEverything, onPressed: _deleting ? null : _delete),
        const SizedBox(height: 8),
        AppButton(
          l10n.cancel,
          variant: AppButtonVariant.outlined,
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
