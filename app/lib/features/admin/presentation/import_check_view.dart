/// Z09 — Import check. The dry run, and the most consequential screen here.
///
/// Its design note: "The whole file is validated before anything is written, and
/// every bad row is named with its reason. If one row fails, nothing is written
/// — a half-imported library is worse than none, because the gaps are invisible
/// and the safety guards read a missing tag as unsafe."
///
/// ## The confirmation is a state, not a dialog
///
/// `product_rules_test.dart` fails the build on any `showDialog` or
/// `AlertDialog` under `lib/features/`. §3.1 makes this action destructive
/// enough to deserve a question, which is the exemption `cycle_deletion_machine`
/// records. So the footer **changes in place**: the offer becomes a confirm and
/// a cancel. [ImportCommit] holds that, and this screen only draws it.
///
/// This is the single most likely place in the product for a dialog to be
/// reintroduced, because "are you sure you want to replace the library?" is what
/// every admin tool anyone has used does. It is written down here so the next
/// person changing this file sees the argument before the code.
///
/// ## Why a failing batch does not offer the button at all
///
/// Not offered-then-refused. A button that is present and rejects the tap
/// invites "let me just import the ones that passed", which is precisely what
/// §3.1 forbids. [ImportPlan.canCommit] gates it, and [ImportPlan.writes] is
/// empty anyway, so there is nothing a caller could write even by mistake.
///
/// ## What a failing row can and cannot say
///
/// The design names each failure in prose — "allergens is blank — write 'none'",
/// "name_ar missing", "photo koshari.jpg was not uploaded". **None of those
/// sentences exists in the dictionary**, and this feature may not add them.
///
/// What is shown instead is the row's line number and the column as the file
/// spells it, under the design's own `Row` and `Problem` headers, which do exist
/// now. Those cells are not copy: the column name is the header from her own
/// CSV, echoed back, and it is the most precise thing this screen can say
/// without inventing language. It is enough to find the cell and much less than
/// the design promises, and the missing sentences are still reported.
///
/// ## The confirmation now asks in words
///
/// The inline confirm was a footer that swapped its buttons and said nothing.
/// `Import everything?` exists now, so the question is asked rather than implied
/// by two buttons appearing. It is still a **state** and still not a dialog —
/// see above; that is the part that matters.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
// AppCardVariant arrives with AppListItem, which re-exports it.
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/import_commit_machine.dart';
import '../domain/import_validator.dart';
import 'admin_widgets.dart';

class ImportCheckView extends StatefulWidget {
  const ImportCheckView({
    super.key,
    required this.plan,
    this.onCommit,
    this.onBack,
  });

  final ImportPlan plan;

  /// Called once, and only after she has confirmed.
  final VoidCallback? onCommit;

  final VoidCallback? onBack;

  @override
  State<ImportCheckView> createState() => _ImportCheckViewState();
}

class _ImportCheckViewState extends State<ImportCheckView> {
  ImportCommit _commit = const ImportCommit();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = widget.plan;

    return AppScaffold(
      appBar: AppTopBar(title: l10n.importCheck, onBack: widget.onBack),
      footer: _footer(l10n),
      children: [
        // The screen's promise, and a real dictionary string.
        AppSageNote(l10n.nothingHasBeenWrittenYet),

        // What the dry run found, when it found nothing wrong.
        //
        // Said only for a batch that can actually commit. `writes` is empty
        // unless every row passed, so "3 rows ready" above a list of failures
        // would put a number on screen that nothing is going to write — and
        // "ready" is the one word §3.1 does not allow this screen to be loose
        // with.
        if (plan.canCommit)
          AppListItem(
            leading: const Icon(
              Icons.check_circle_outline,
              size: 24,
              color: AppColors.tertiary,
            ),
            // countLabel, so the count stays Western under `ar`.
            title: l10n.nRowsReady(countLabel(plan.rowsReady)),
            variant: AppCardVariant.filled,
          ),

        if (plan.problems.isNotEmpty) ...[
          AppListItem(
            leading: const Icon(
              Icons.error_outline,
              size: 24,
              color: AppColors.error,
            ),
            title: l10n.rowsWithProblems,
            trailing: AppPill(
              countLabel(plan.rowsWithProblems),
              background: AppColors.errorContainer,
              foreground: AppColors.onErrorContainer,
            ),
            variant: AppCardVariant.error,
          ),
          AdminTable(
            startHeader: l10n.row,
            endHeader: l10n.problem,
            // Narrow line number, wide reason — the design's 0.5fr / 2fr.
            startFlex: 2,
            endFlex: 8,
            rows: [
              for (final problem in plan.problems)
                (
                  // The line number as the spreadsheet's own gutter shows it.
                  // countLabel, so it stays Western under `ar`.
                  countLabel(problem.row),
                  // Her own CSV header, echoed back, and the offending cell
                  // beneath it when quoting it helps — the name of a media file
                  // that was never uploaded, for instance.
                  problem.value.isEmpty
                      ? problem.column
                      : '${problem.column}\n${problem.value}',
                ),
            ],
          ),
          AppSageNote(l10n.fixTheseRowsAndImportAgainNothing),
        ],
      ],
    );
  }

  /// The inline confirmation. See the file note on why this is not a dialog.
  List<Widget> _footer(AppL10n l10n) {
    if (_commit.canRetry) {
      return [
        AppButton(
          l10n.tryAgain,
          onPressed: () => setState(() => _commit = _commit.retry()),
        ),
      ];
    }

    if (_commit.canCancel) {
      return [
        // The question, asked in words. Everything a dialog would have said,
        // in the place the answer is given.
        Text(
          l10n.importEverything_damon,
          style: AppText.titleM.copyWith(color: AppColors.onSurface),
          textAlign: TextAlign.center,
        ),
        AppButton(l10n.importEverything, onPressed: _confirm),
        AppButton(
          l10n.cancel,
          variant: AppButtonVariant.text,
          onPressed: () => setState(() => _commit = _commit.cancelled()),
        ),
      ];
    }

    return [
      AppButton(
        l10n.importEverything,
        // Disabled while a batch cannot commit, while one is in flight, and
        // once one has been written.
        onPressed:
            (!widget.plan.canCommit || _commit.isRunning || _commit.hasWritten)
            ? null
            : () => setState(() => _commit = _commit.requested()),
      ),
      // The way out for the far more common case: the file was wrong. Offered
      // beside the import rather than only as a back arrow, because a batch
      // that cannot commit leaves the primary button disabled and this is then
      // the only thing on the screen she can do.
      AppButton(
        l10n.backToTheFile,
        variant: AppButtonVariant.text,
        onPressed: widget.onBack,
      ),
    ];
  }

  void _confirm() {
    setState(() => _commit = _commit.confirmed());
    widget.onCommit?.call();
    // Nothing claims a write it has not performed — this is the caller's
    // acknowledgement, and the only route to `done`.
    setState(() => _commit = _commit.markCommitted());
  }
}
