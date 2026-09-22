/// Z08 — Bulk import, the first half of `Z08 → Z09 → commit`.
///
/// Matches `screens-admin.mjs` → `Z08`. Choose a collection, choose a file, and
/// check it. **Nothing on this screen writes anything**; the check is a dry run
/// and Z09 shows its result.
///
/// ## Choosing a file is the host's job
///
/// There is no file-picker package in `pubspec.yaml`, and adding one is not this
/// feature's to do. So [onChooseFile] is a callback: this screen asks for a
/// file, and whatever wires it supplies the CSV text. That keeps the decision —
/// and the platform permissions that come with it — with the owner.
///
/// [source] is that arrangement written down. `domain/text_source.dart` is the
/// seam, [UnavailableTextSource] is the only implementation there is, and when
/// it says so this screen draws [AdminUnavailableAction] rather than a "Choose a
/// file" button that opens nothing. The screen still does not *call* the source:
/// it reports whether one is available and asks through [onChooseFile], so
/// parsing and validating stay with the caller that already owns the plan.
///
/// The sentence explaining *why* it is unavailable has no string in either
/// dictionary. It is withheld and reported, like everything else this feature
/// cannot say.
///
/// ## The contract, on screen before the file is chosen
///
/// The design's point: the expected columns are shown "before the file is
/// chosen, so a mismatch is caught by reading rather than by failing". The table
/// was withheld for a release for want of four strings; they exist now.
///
/// Every cell is read from [ContentSchema] — the same object the importer
/// validates against and the exporter writes from — so the contract staff are
/// shown cannot drift from the contract enforced. A column added to a CSV
/// appears here without anyone editing this file.
///
/// Two deliberate departures from the design's sketch:
///
///   * It lists **every** column, not the five the mock draws. The mock is a
///     picture; this is the contract, and a column left off it is the one
///     somebody forgets.
///   * A column that is not required has an **empty** cell rather than "no".
///     There is no "no" in the dictionary, and an empty cell under "Required"
///     already reads as one.
///
/// The note beneath ("Unknown column headers are refused rather than ignored")
/// still has no string, and is still withheld. Reported.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../domain/content_schema.dart';
import '../domain/text_source.dart';
import 'admin_widgets.dart';

class BulkImportView extends StatelessWidget {
  const BulkImportView({
    super.key,
    this.collection = ContentCollection.foods,
    this.chosenFileName,
    this.source,
    this.onCollectionChanged,
    this.onChooseFile,
    this.onCheckFile,
    this.onBack,
  });

  final ContentCollection collection;

  /// Null until a file has been chosen, which is what gates the check.
  final String? chosenFileName;

  /// What would open the device's files, and whether anything can.
  ///
  /// Null means the caller is driving [onChooseFile] itself and has not said.
  /// An [UnavailableTextSource] is a caller saying plainly that no file can be
  /// chosen, and the screen draws that instead of a live-looking control.
  final TextSource? source;

  /// Whether a file can actually be chosen.
  bool get canChooseFile => source?.isAvailable ?? true;

  final ValueChanged<ContentCollection>? onCollectionChanged;
  final VoidCallback? onChooseFile;
  final VoidCallback? onCheckFile;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final chosen = chosenFileName;

    return AppScaffold(
      appBar: AppTopBar(title: l10n.bulkImport, onBack: onBack),
      footer: [
        AppButton(
          l10n.checkTheFile,
          // Offering this with no file is a button that can only disappoint.
          onPressed: chosen == null ? null : onCheckFile,
        ),
      ],
      children: [
        AppSegmented(
          items: [l10n.exercises, l10n.foods, l10n.recipes, l10n.programmes],
          selectedIndex: ContentCollection.values.indexOf(collection),
          onChanged: (index) =>
              onCollectionChanged?.call(ContentCollection.values[index]),
        ),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          onTap: canChooseFile ? onChooseFile : null,
          children: [
            const Icon(
              Icons.upload_file,
              size: 32,
              color: AppColors.primaryDim,
            ),
            Text(l10n.chooseACsvFile, style: AppText.titleM),
            // The file name is data, not copy — it is what she picked. Shown
            // only once there is one.
            if (chosen != null)
              Text(
                chosen,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),

        // The action in a word, beside the drop area the design draws — and
        // plainly not live when there is nothing behind it.
        if (canChooseFile)
          AppButton(
            l10n.chooseAFile,
            variant: AppButtonVariant.tonal,
            onPressed: onChooseFile,
          )
        else
          AdminUnavailableAction(l10n.chooseAFile),

        AdminSectionHead(l10n.columnsItExpects),
        AdminTable(
          startHeader: l10n.column,
          endHeader: l10n.requiredLabel,
          rows: _expectedColumns(l10n),
        ),
      ],
    );
  }

  /// The contract, read off [ContentSchema].
  List<(String, String)> _expectedColumns(AppL10n l10n) {
    final rows = <(String, String)>[];

    for (final column in ContentSchema.of(collection).columns) {
      // §3.3: the bilingual pair is one decision, not two. The design states it
      // as a single row — "name_en / name_ar … yes, both" — because a file
      // carrying only one of them is not half-translated, it is a browse list
      // with nothing to draw for half the product's readers.
      if (column.name == 'name_ar') continue;
      if (column.name == 'name_en') {
        rows.add(('name_en / name_ar', l10n.yesBoth));
        continue;
      }

      rows.add((column.name, column.required ? l10n.yes : ''));
    }

    return rows;
  }
}
