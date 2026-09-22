/// Z11 — Export. **Content only. Never her.**
///
/// Its design note is the strongest sentence in the admin design file:
///
/// > "One CSV per collection in exactly the import schema, plus the media those
/// > rows reference. No `users/**` path is reachable from here — not logs, not
/// > photos, not cycle. The app tells her that her ID photo is deleted and her
/// > logs are never shown to members; an admin bulk-export of user media would
/// > make both statements false, and under PDPL it is the line between a content
/// > catalogue and regulated personal data."
///
/// ## Where that is actually enforced
///
/// Not here. This screen only ever offers [ContentCollection], an enum with four
/// members, none of which is a person — so there is no selection a woman's data
/// could be reached through. The manifest built from that selection refuses any
/// path outside `content/`, and `export_manifest_test.dart` proves it.
///
/// A screen is the wrong place for that guarantee, because a screen can be
/// edited. This one is narrow because the type it is built on is narrow.
///
/// ## What each row says it contains
///
/// The heading and the three subtitles were withheld for a release for want of
/// strings. They exist now, and the subtitle is **read off [ContentSchema]**
/// rather than typed per collection: a collection with no media columns exports
/// a CSV, one whose media are stills exports CSV + photos, and one that names a
/// clip exports CSV + videos. The contract decides what the row claims, so the
/// claim cannot drift from what the bundle actually holds.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
// AppCardVariant arrives with AppListItem, which re-exports it.
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/content_schema.dart';
import 'admin_widgets.dart';

class ExportView extends StatefulWidget {
  const ExportView({super.key, this.selected, this.onExport, this.onBack});

  /// Null means "everything", which is what the design shows: all four ticked.
  final Set<ContentCollection>? selected;

  /// Carries the chosen collections. Never anything else — see the file note.
  final ValueChanged<Set<ContentCollection>>? onExport;

  final VoidCallback? onBack;

  @override
  State<ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends State<ExportView> {
  // The set is mutated in place and never reassigned, so it is final.
  late final Set<ContentCollection> _selected =
      widget.selected ?? ContentCollection.values.toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: l10n.exportLabel, onBack: widget.onBack),
      footer: [
        AppButton(
          l10n.exportTheContentLibrary,
          // Exporting nothing is not an action.
          onPressed: _selected.isEmpty
              ? null
              : () => widget.onExport?.call(Set.unmodifiable(_selected)),
        ),
      ],
      children: [
        // The promise this screen has to make on its face rather than only in
        // its implementation.
        AppSageNote(l10n.noMemberDataIsEverIncludedNo),

        AdminSectionHead(l10n.whatToExport),

        for (final collection in ContentCollection.values)
          AppListItem(
            leading: Icon(
              _icon(collection),
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: _title(l10n, collection),
            subtitle: _contents(l10n, collection),
            trailing: Icon(
              _selected.contains(collection)
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              size: 22,
              color: _selected.contains(collection)
                  ? AppColors.primary
                  : AppColors.outline,
            ),
            variant: _selected.contains(collection)
                ? AppCardVariant.selected
                : AppCardVariant.outlined,
            onTap: () => setState(() {
              if (!_selected.remove(collection)) _selected.add(collection);
            }),
          ),

        // §5's round trip, said on the screen because it is the reason the
        // export is shaped the way it is.
        AppSageNote(l10n.csvsAndMediaInTheSameShape),
      ],
    );
  }

  /// What a bundle for this collection would actually hold, per §5: "one CSV per
  /// collection, in exactly the import schema … plus the media those rows
  /// reference."
  String _contents(AppL10n l10n, ContentCollection collection) {
    final schema = ContentSchema.of(collection);
    if (schema.mediaColumns.isEmpty) return l10n.csv;
    return schema.videoColumns.isEmpty ? l10n.csvPhotos : l10n.csvVideos;
  }

  String _title(AppL10n l10n, ContentCollection collection) =>
      switch (collection) {
        ContentCollection.exercises => l10n.exercises,
        ContentCollection.foods => l10n.foods,
        ContentCollection.recipes => l10n.recipes,
        ContentCollection.programmes => l10n.programmes,
      };

  IconData _icon(ContentCollection collection) => switch (collection) {
    ContentCollection.exercises => Icons.fitness_center,
    ContentCollection.foods => Icons.restaurant,
    ContentCollection.recipes => Icons.menu_book,
    ContentCollection.programmes => Icons.calendar_month,
  };
}
