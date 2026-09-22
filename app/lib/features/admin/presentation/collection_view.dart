/// Z02, Z04, Z06 and Z07 — the four browse lists, as one screen.
///
/// The design draws four. They differ only in their title, their filter chips
/// and which safety column they are anxious about, so four widgets would be four
/// places to change the next time the safety rule moves — on the feature whose
/// entire purpose is that rule. [ContentSchema] already knows which column each
/// collection must carry, so the difference is read from there rather than
/// retyped here.
///
/// ## The names on these rows come from the CSV, not the dictionary
///
/// §3.3: the library "carries its own display text because it is **content from
/// a build-time bundle, not copy from the dictionary**. So every CSV carries
/// `name_en` and `name_ar`, and none of this passes through `6-v2/i18n/` or the
/// ARB."
///
/// So a row renders `name_ar` under Arabic and `name_en` under English, read
/// from the imported row. That is why the importer refuses a row carrying only
/// one of the two: the missing half is not a translation that can be supplied
/// later, it is the screen having nothing to draw.
///
/// ## The empty states, and the third chip
///
/// Both were withheld for a release for want of strings. `noExercisesYet` and
/// its three siblings exist now, so a collection with nothing in it says so
/// instead of showing a bare filter row; and `noVideo` and `noMacros` complete
/// the third chip on Z02 and Z04.
///
/// The **paragraph** under each empty state ("Import exercises.csv, or add one
/// at a time. Every row needs contraindication tags — write 'none' when there
/// are none.") is still missing, and so is the `"Search 0 exercises"`
/// placeholder. Both are reported. The card says the true short thing rather
/// than an approximation of the long one.
///
/// ## What the third chip means is not the same in each collection
///
/// "No video", "No macros" and "No photo" are three different absences, and each
/// is read off [ContentSchema] rather than from a column name typed here: the
/// video chip asks the schema which of its media columns is a clip, the photo
/// chip asks which are media at all, and the macros chip asks which are numeric.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/content_schema.dart';
import '../domain/import_validator.dart';
import 'admin_nav.dart';

class CollectionView extends StatefulWidget {
  const CollectionView({
    super.key,
    required this.collection,
    this.rows = const [],
    this.onBack,
    this.onImport,
    this.onAdd,
    this.onOpenRow,
    this.onSelectTab,
  });

  final ContentCollection collection;

  /// The library's current contents. Empty is the honest default: nothing is
  /// authored yet, which is the reason this console was commissioned.
  final List<ImportRow> rows;

  final VoidCallback? onBack;
  final VoidCallback? onImport;

  /// Opens the add form — Z02 → Z03, Z04 → Z05.
  ///
  /// The design puts an `add` action in this screen's app bar, and D12 asked
  /// for content to be addable "from within the app" rather than only through a
  /// CSV. The action is drawn **only when this is wired**: an add button that
  /// opens nothing is worse than no button, and two of the four collections
  /// have no form to open yet.
  final VoidCallback? onAdd;

  /// Carries the row's id, never its position — a list that reorders would
  /// otherwise open the wrong row.
  final ValueChanged<String>? onOpenRow;

  final ValueChanged<String>? onSelectTab;

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  /// Selection is this screen's, never a chip's — a chip that remembered its
  /// own state would be a second source of truth beside the filter.
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final filters = _filters(l10n);
    final rows = _visibleRows();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: _title(l10n),
        onBack: widget.onBack,
        actions: [
          if (widget.onAdd != null)
            IconButton(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add),
              iconSize: 24,
              color: AppColors.onSurface,
              // An icon on its own is unreadable to a screen reader, and `Add`
              // is a string this product already has.
              tooltip: l10n.add,
            ),
        ],
      ),
      bottomNavigationBar: AdminNavBar(
        activeScreenId: 'Z01',
        onSelect: widget.onSelectTab,
      ),
      body: AppScaffold(
        children: [
          AppField(
            hint: l10n.search,
            trailing: const Icon(
              Icons.search,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (filters.isNotEmpty)
            AppChipRow(
              grow: false,
              items: filters,
              selected: {_filter},
              onTap: (index) => setState(() => _filter = index),
            ),
          // Said when the collection is empty, which is the state of all four
          // today. Not said when a filter merely narrowed to nothing — "no
          // foods yet" would be false there, and the chip above already
          // explains the emptiness.
          if (widget.rows.isEmpty)
            AppListItem(
              title: _nothingYet(l10n),
              variant: AppCardVariant.filled,
            ),

          for (final row in rows)
            AppListItem(
              title: _name(context, row),
              subtitle: _isUntagged(row) ? l10n.missingASafetyTag : '',
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () => widget.onOpenRow?.call(row.id),
            ),
          AppButton(
            l10n.bulkImport,
            variant: AppButtonVariant.tonal,
            onPressed: widget.onImport,
          ),
        ],
      ),
    );
  }

  String _title(AppL10n l10n) => switch (widget.collection) {
    ContentCollection.exercises => l10n.exercises,
    ContentCollection.foods => l10n.foods,
    ContentCollection.recipes => l10n.recipes,
    ContentCollection.programmes => l10n.programmes,
  };

  /// The chips the design names, minus the ones with no string.
  ///
  /// Programmes get none: they carry no safety column, because a programme holds
  /// no ingredient and no movement of its own.
  List<String> _filters(AppL10n l10n) => switch (widget.collection) {
    ContentCollection.exercises => [
      l10n.all,
      l10n.missingContraindications,
      l10n.noVideo,
    ],
    ContentCollection.foods => [l10n.all, l10n.missingAllergens, l10n.noMacros],
    ContentCollection.recipes => [
      l10n.all,
      l10n.missingAllergens,
      l10n.noPhoto,
    ],
    ContentCollection.programmes => const [],
  };

  String _nothingYet(AppL10n l10n) => switch (widget.collection) {
    ContentCollection.exercises => l10n.noExercisesYet,
    ContentCollection.foods => l10n.noFoodsYet,
    ContentCollection.recipes => l10n.noRecipesYet,
    ContentCollection.programmes => l10n.noProgrammesYet,
  };

  List<ImportRow> _visibleRows() {
    // Chip 0 is always "All". Anything else narrows to the rows that are
    // missing something, which is what the chips exist to find.
    if (_filter == 0) return widget.rows;
    if (_filter == 1) {
      return [
        for (final r in widget.rows)
          if (_isUntagged(r)) r,
      ];
    }
    return [
      for (final r in widget.rows)
        if (_missingTheThirdThing(r)) r,
    ];
  }

  bool _isUntagged(ImportRow row) =>
      ContentSchema.of(widget.collection).safetyTagColumns
          .any((column) => row.value(column).isEmpty);

  /// The third chip, which names a different absence in each collection.
  bool _missingTheThirdThing(ImportRow row) {
    final schema = ContentSchema.of(widget.collection);

    return switch (widget.collection) {
      // "No video" is about the clip, not the still frame beside it — a row
      // with a thumbnail and no video is exactly the row this chip is for.
      ContentCollection.exercises => schema.videoColumns.every(
        (column) => row.value(column).isEmpty,
      ),
      // "No macros" means the library knows nothing about the food
      // nutritionally, not that it happens to be zero-calorie. Every macro
      // absent or zero is the only reading that finds the unauthored rows.
      ContentCollection.foods => schema.numericColumns.every(
        (column) => (row.number(column) ?? 0) == 0,
      ),
      ContentCollection.recipes => schema.mediaColumns.every(
        (column) => row.value(column).isEmpty,
      ),
      // Programmes offer no third chip, so nothing can select this.
      ContentCollection.programmes => false,
    };
  }

  /// Content, chosen by the reader's language — see the file note.
  String _name(BuildContext context, ImportRow row) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? row.value('name_ar') : row.value('name_en');
  }
}
