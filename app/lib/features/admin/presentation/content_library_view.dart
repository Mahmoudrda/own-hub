/// Z01 — Content library. The landing tab of the admin console.
///
/// Matches `6-v2/src/screens-admin.mjs` → `Z01`. Its design note is the whole
/// argument for the screen:
///
/// > "The landing tab leads with how many rows lack a mandatory safety tag
/// > rather than how many rows exist. An incomplete library is the failure mode
/// > that matters, and a total hides it — a food with no allergens value is not
/// > a smaller library, it is a guard that fails closed on every woman."
///
/// So a collection with untagged rows says so and carries the count; a
/// collection that is fully tagged says nothing at all, because there is nothing
/// to report.
///
/// ## What this screen does not say
///
/// The `"{n} rows"` subtitle was withheld for a release because no such string
/// existed. `nRows` exists now, so each collection states its size and — when
/// there is one — the number of rows missing a mandatory safety tag beside it,
/// which is the line the design draws.
///
/// Two pieces of prose are **still withheld**: the banner ("Nothing here is a
/// member's data. This console manages the library only.") and the sage note
/// about an empty library having nothing to filter on. Neither exists in the
/// dictionary and this feature may not add one, so they are left out rather than
/// approximated. Both are reported to the owner.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
// AppCardVariant arrives with AppListItem, which re-exports it so a row and a
// card can never drift to different colours.
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/content_repository.dart';
import '../domain/content_schema.dart';
import 'admin_nav.dart';

/// [CollectionStatus] moved to `domain/content_repository.dart` when the store
/// arrived, because the repository is what counts it — a screen is not the only
/// thing entitled to say how incomplete the library is, and the count has to be
/// available to anything reading the library rather than only to the widget that
/// draws it.
///
/// Re-exported here so Z01, the router and every test that constructs one are
/// unaffected by the move.
export '../domain/content_repository.dart' show CollectionStatus;

class ContentLibraryView extends StatelessWidget {
  const ContentLibraryView({
    super.key,
    this.status = const {},
    this.onOpenCollection,
    this.onImport,
    this.onOpenFlags,
    this.onSelectTab,
  });

  /// Absent means "nothing is known about this collection", which is the state
  /// of every one of them today.
  final Map<ContentCollection, CollectionStatus> status;

  final ValueChanged<ContentCollection>? onOpenCollection;
  final VoidCallback? onImport;

  /// `Z14`, the switchboard. It is the only place in the product where a
  /// feature is turned on or off, and the console is where staff are — without
  /// this the screen was built, routable and opened by nobody.
  final VoidCallback? onOpenFlags;

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.contentLibrary,
        actions: [
          // The switchboard. An app-bar action rather than a row among the
          // collections: the flags are not content, and putting them in that
          // list would make them read as a fifth thing to import.
          IconButton(
            tooltip: l10n.featureFlags,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.tune),
            onPressed: onOpenFlags,
          ),
        ],
      ),
      bottomNavigationBar: AdminNavBar(
        activeScreenId: 'Z01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          // D12 on the face of the landing tab: "**An admin is staff, not a
          // member.** The console manages the *content library*. It is not a
          // window into anyone's account." Withheld for a release for want of
          // the string; it exists now, and this is the screen that should carry
          // it, because Z01 is where a console like this one would start
          // growing a "look up a member" box.
          AppSageNote(l10n.nothingHereIsAMembersDataThis),

          for (final collection in ContentCollection.values)
            _CollectionRow(
              collection: collection,
              status: status[collection],
              onTap: () => onOpenCollection?.call(collection),
            ),
          // The primary action, and the reason the console exists: 124 exercise
          // videos and an Egyptian food library do not arrive one form at a
          // time.
          AppButton(
            l10n.bulkImport,
            icon: Icons.upload_file,
            onPressed: onImport,
          ),
        ],
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.collection,
    required this.status,
    this.onTap,
  });

  final ContentCollection collection;
  final CollectionStatus? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final missing = status?.missingASafetyTag ?? 0;
    final isAlarming = missing > 0;

    return AppListItem(
      leading: Icon(_icon, size: 24, color: AppColors.primaryDim),
      title: _title(l10n),
      subtitle: _subtitle(l10n),
      trailing: isAlarming
          // countLabel, never NumberFormat — under `ar` intl would render
          // Eastern digits and P0-A11Y-01 fails.
          ? AppPill(
              countLabel(missing),
              background: AppColors.errorContainer,
              foreground: AppColors.onErrorContainer,
            )
          : const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
      variant: isAlarming ? AppCardVariant.error : AppCardVariant.outlined,
      onTap: onTap,
    );
  }

  /// "124 rows", and beside it the alarm when there is one.
  ///
  /// Nothing at all when the collection is unknown — which is every collection
  /// today. An absent count and a count of zero are different claims, and this
  /// screen may only make the one it can support.
  ///
  /// The two halves are joined with a middle dot. That is punctuation, not copy:
  /// both dictionaries already use it inside their own values ("Uploaded ·
  /// checking", "رُفعت · قيد المراجعة"), and it is bidirectionally neutral, so
  /// the line reads correctly under `ar` without a third string to own the join.
  String _subtitle(AppL10n l10n) {
    final known = status;
    if (known == null) return '';

    final rows = l10n.nRows(countLabel(known.rows));
    return known.missingASafetyTag > 0
        ? '$rows · ${l10n.missingASafetyTag}'
        : rows;
  }

  String _title(AppL10n l10n) => switch (collection) {
    ContentCollection.exercises => l10n.exercises,
    ContentCollection.foods => l10n.foods,
    ContentCollection.recipes => l10n.recipes,
    ContentCollection.programmes => l10n.programmes,
  };

  IconData get _icon => switch (collection) {
    ContentCollection.exercises => Icons.fitness_center,
    ContentCollection.foods => Icons.restaurant,
    ContentCollection.recipes => Icons.menu_book,
    ContentCollection.programmes => Icons.calendar_month,
  };
}
