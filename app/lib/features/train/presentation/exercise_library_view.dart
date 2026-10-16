/// R14 — Exercise library.
///
/// Every move the owner has filmed, under the part of the body it works, in
/// words she would use: Glutes, Front of thighs, Shoulders. Three rows of
/// chips narrow it (strength or stretches, where she can do it, what she
/// has), and a search box finds a move by name in either language.
///
/// A lazy list rather than [AppScaffold]'s column: the column builds every
/// row at once, and every row asks for its poster, so opening the library
/// would start eighty downloads on a phone that will only ever show eight of
/// them. The page around the list is drawn exactly as [AppScaffold] draws one.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/screen_art.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_scaffold.dart' show kBodyPadding, kStackGap;
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';
import '../../../ui/screen_scope.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import 'exercise_labels.dart';
import 'train_widgets.dart';

/// What the equipment chips can ask for, in the order they are offered.
enum _Kit { nothing, mat, dumbbells, bands, gymMachines }

bool _uses(LibraryExercise e, _Kit kit) => switch (kit) {
  _Kit.nothing => e.needsNothing,
  _Kit.mat => e.equipment.contains(LibraryEquipment.mat),
  _Kit.dumbbells => e.equipment.contains(LibraryEquipment.dumbbells),
  _Kit.bands => e.equipment.contains(LibraryEquipment.bands),
  _Kit.gymMachines => e.usesGymMachine,
};

class ExerciseLibraryView extends StatefulWidget {
  const ExerciseLibraryView({
    super.key,
    this.exercises = const <LibraryExercise>[],
    this.hiddenFor,
    this.media = const NoExerciseMedia(),
    this.onBack,
    this.onOpenExercise,
    this.onSelectTab,
  });

  /// The moves she may be shown, already screened for her life stage.
  final List<LibraryExercise> exercises;

  /// Her stage, when screening it held moves back. Null when nothing was.
  final LifeStage? hiddenFor;

  final ExerciseMediaStore media;
  final VoidCallback? onBack;
  final ValueChanged<LibraryExercise>? onOpenExercise;
  final ValueChanged<String>? onSelectTab;

  @override
  State<ExerciseLibraryView> createState() => _ExerciseLibraryViewState();
}

class _ExerciseLibraryViewState extends State<ExerciseLibraryView> {
  int _kind = 0;
  ExercisePlace? _place;
  _Kit? _kit;
  String _query = '';

  /// Kept here, not in the field: the list is lazy, and a field scrolled out
  /// of view is rebuilt empty while its search would still be filtering.
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _keep(LibraryExercise e) {
    if (_kind == 1 && e.kind != ExerciseKind.strength) return false;
    if (_kind == 2 && e.kind != ExerciseKind.stretch) return false;
    if (_place != null && e.place != _place) return false;
    if (_kit != null && !_uses(e, _kit!)) return false;
    return e.matches(_query);
  }

  String _kitLabel(AppL10n l10n, _Kit kit) => switch (kit) {
    _Kit.nothing => l10n.noEquipment,
    _Kit.mat => l10n.mat,
    _Kit.dumbbells => l10n.dumbbells,
    _Kit.bands => l10n.bands,
    _Kit.gymMachines => l10n.gymMachines,
  };

  /// The place and kit chips, in one sheet. They change the list behind it as
  /// she taps, so the sheet keeps its own rebuild.
  Future<void> _openFilters(
    AppL10n l10n,
    List<ExercisePlace> places,
    List<_Kit> kits,
  ) {
    return showAppSheet<void>(
      context: context,
      children: [
        StatefulBuilder(
          builder: (sheet, setSheet) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.filters, style: AppText.titleL),
              if (places.length > 1) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.where,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                AppChipRow(
                  key: const ValueKey('r14-place'),
                  grow: false,
                  items: [for (final p in places) placeLabel(l10n, p)],
                  selected: {
                    if (_place != null && places.contains(_place))
                      places.indexOf(_place!),
                  },
                  // Tapping the lit chip again clears it.
                  onTap: (i) {
                    setState(
                      () => _place = _place == places[i] ? null : places[i],
                    );
                    setSheet(() {});
                  },
                ),
              ],
              if (kits.length > 1) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.equipment,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                AppChipRow(
                  key: const ValueKey('r14-kit'),
                  grow: false,
                  items: [for (final k in kits) _kitLabel(l10n, k)],
                  selected: {
                    if (_kit != null && kits.contains(_kit))
                      kits.indexOf(_kit!),
                  },
                  onTap: (i) {
                    setState(() => _kit = _kit == kits[i] ? null : kits[i]);
                    setSheet(() {});
                  },
                ),
              ],
              const SizedBox(height: 16),
              AppButton(
                l10n.done_54ca1,
                onPressed: () => Navigator.of(sheet).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final all = widget.exercises;
    final art = ScreenArt.headerFor(ScreenScope.of(context));

    // A chip that would match nothing in her library is not offered.
    final kits = [
      for (final kit in _Kit.values)
        if (all.any((e) => _uses(e, kit))) kit,
    ];
    final places = [
      for (final place in ExercisePlace.values)
        if (all.any((e) => e.place == place)) place,
    ];

    final visible = all.where(_keep).toList();
    final bySection = <MuscleSection, List<LibraryExercise>>{};
    for (final e in visible) {
      bySection.putIfAbsent(e.section, () => <LibraryExercise>[]).add(e);
    }
    for (final list in bySection.values) {
      list.sort((a, b) => a.name(language).compareTo(b.name(language)));
    }

    final items = <Widget>[
      if (art.isNotEmpty) const ScreenArtStrip(),
      if (all.isEmpty && widget.hiddenFor != null)
        // Every move was held back for her stage: say why, not "on its way".
        AppSageNote(
          widget.hiddenFor == LifeStage.pregnant
              ? l10n.someMovesAreHiddenWhileYouAre
              : l10n.someMovesAreHiddenInTheWeeks,
        )
      else if (all.isEmpty) ...[
        AppEmptyState(
          icon: Icons.play_circle_outline,
          title: l10n.theExerciseLibraryIsOnItsWay,
          body: l10n.itArrivesTheNextTimeYouOpen,
        ),
        // First view of an empty library only: it peeks in once.
        const Kitten(
          pose: KittenPose.peek,
          size: 56,
          moment: 'R14',
          sessionBudget: true,
        ),
      ] else ...[
        AppField(
          controller: _search,
          hint: l10n.searchMoves,
          onChanged: (value) => setState(() => _query = value),
          trailing: const Icon(
            Icons.search,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChipRow(
              key: const ValueKey('r14-kind'),
              grow: false,
              items: [l10n.all, l10n.strength, l10n.stretchesAndWarmUps],
              selected: {_kind},
              onTap: (i) => setState(() => _kind = i),
            ),
            // Where she can do it and what she has, behind one chip.
            if (places.length > 1 || kits.length > 1)
              AppChip(
                l10n.filters,
                key: const ValueKey('r14-filters'),
                icon: Icons.tune,
                selected: _place != null || _kit != null,
                onTap: () => _openFilters(l10n, places, kits),
              ),
          ],
        ),
        if (widget.hiddenFor != null)
          AppSageNote(
            widget.hiddenFor == LifeStage.pregnant
                ? l10n.someMovesAreHiddenWhileYouAre
                : l10n.someMovesAreHiddenInTheWeeks,
          ),
        if (visible.isEmpty)
          AppEmptyState(
            icon: Icons.search_off,
            title: l10n.nothingMatchesThoseFilters,
            body: l10n.tryAnotherFilterOrClearTheSearch,
          ),
        for (final section in MuscleSection.values)
          if (bySection[section] case final moves?) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                header: true,
                child: Text(sectionLabel(l10n, section), style: AppText.titleM),
              ),
            ),
            for (final e in moves)
              AppListItem(
                key: ValueKey('r14-${e.id}'),
                title: e.name(language),
                subtitle: [
                  for (final section in e.sections) sectionLabel(l10n, section),
                  equipmentLine(l10n, e.equipment),
                ].join(' · '),
                leading: _Poster(media: widget.media, poster: e.poster),
                trailing: const AppChevron(),
                onTap: () => widget.onOpenExercise?.call(e),
              ),
          ],
        const SizedBox(height: 6),
      ],
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        // R14 is not a tab: it claims its own id, so no tab is lit as if she
        // were on it.
        activeScreenId: 'R14',
        onSelect: widget.onSelectTab,
      ),
      body: PaperPage(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: TrainTopBar(
            onClose: widget.onBack,
            closeIcon: Icons.arrow_back,
          ),
          body: SafeArea(
            child: Padding(
              padding: kBodyPadding,
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: kStackGap),
                // The first rows ease in once per visit; the rest are there.
                itemBuilder: (_, i) =>
                    StaggerIn(index: i, group: 'r14', child: items[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A move's poster in its row: the file on the phone, or fetched the first
/// time the row is built. Until then, the frame alone.
class _Poster extends StatefulWidget {
  const _Poster({required this.media, required this.poster});

  final ExerciseMediaStore media;
  final ExerciseMedia poster;

  @override
  State<_Poster> createState() => _PosterState();
}

class _PosterState extends State<_Poster> {
  File? _file;

  /// True until the file is on the phone or the fetch has given up. The
  /// shimmer lives only this long.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_Poster old) {
    super.didUpdateWidget(old);
    if (old.poster != widget.poster) {
      _file = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final poster = widget.poster;
    final file =
        await widget.media.local(poster) ?? await widget.media.fetch(poster);
    if (!mounted || widget.poster != poster) return;
    setState(() {
      _file = file;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return AppMedia(
      width: 56,
      height: 72,
      borderRadius: AppRadius.sm,
      showPlayButton: false,
      child: file == null
          ? (_loading ? const Skeleton(radius: 0) : null)
          : ExcludeSemantics(
              child: Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: (56 * dpr).round(),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
    );
  }
}
