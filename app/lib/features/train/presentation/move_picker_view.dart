/// Picking moves from the catalogue, for R03's "+ Add a move" and the builder.
///
/// The same search, the same chips and the same Filters sheet as Explore, over
/// the moves she may be shown (screened for her life stage, with a clip). Each
/// row carries the move's poster and its English name. She ticks as many as she
/// likes and adds them together; the Filters button says how many moves it
/// leaves.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import 'exercise_clip_player.dart';
import 'exercise_labels.dart';
import 'move_preview_sheet.dart';
import 'train_explore.dart';

/// Opens the picker over [context] and answers the moves she added, in the
/// order she ticked them, or null when she backed out. Tapping a move opens
/// its video; the circle beside it ticks it without.
Future<List<LibraryExercise>?> pickMoves(
  BuildContext context, {
  required List<LibraryExercise> exercises,
  required ExerciseMediaStore media,
  ExerciseClipPlayerFactory? players,
}) => Navigator.of(context).push<List<LibraryExercise>>(
  MaterialPageRoute<List<LibraryExercise>>(
    builder: (_) =>
        MovePickerView(exercises: exercises, media: media, players: players),
  ),
);

class MovePickerView extends StatefulWidget {
  const MovePickerView({
    super.key,
    required this.exercises,
    this.media = const NoExerciseMedia(),
    this.players,
  });

  final List<LibraryExercise> exercises;
  final ExerciseMediaStore media;

  /// Makes the player for the preview's clip. Null shows the poster alone.
  final ExerciseClipPlayerFactory? players;

  @override
  State<MovePickerView> createState() => _MovePickerViewState();
}

class _MovePickerViewState extends State<MovePickerView> {
  final ExploreFilter _filter = ExploreFilter();
  final List<LibraryExercise> _picked = <LibraryExercise>[];
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _toggle(LibraryExercise exercise) {
    setState(() {
      if (!_picked.remove(exercise)) _picked.add(exercise);
    });
  }

  Future<void> _preview(LibraryExercise exercise) async {
    final use = await showMovePreview(
      context,
      exercise: exercise,
      media: widget.media,
      players: widget.players,
    );
    if (!mounted || !use || _picked.contains(exercise)) return;
    setState(() => _picked.add(exercise));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final shown = [
      for (final e in widget.exercises)
        if (_filter.keepMove(e)) e,
    ]..sort((a, b) => a.name(language).compareTo(b.name(language)));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.pickYourMoves,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Padding(
          padding: kBodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppField(
                controller: _search,
                hint: l10n.searchMoves,
                onChanged: (value) {
                  _filter.query = value;
                  _changed();
                },
                trailing: const Icon(
                  Icons.search,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: kStackGap),
              ExploreChips(
                filter: _filter,
                onChanged: _changed,
                showFilters: exploreHasSheet(widget.exercises),
                onOpenFilters: () => showExploreFilters(
                  context,
                  filter: _filter,
                  exercises: widget.exercises,
                  onChanged: _changed,
                  matchCount: () => [
                    for (final e in widget.exercises)
                      if (_filter.keepMove(e)) e,
                  ].length,
                ),
              ),
              const SizedBox(height: kStackGap),
              Expanded(
                child: shown.isEmpty
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: AppEmptyState(
                          icon: Icons.search_off,
                          title: l10n.nothingMatchesThoseFilters,
                          body: l10n.tryAnotherFilterOrClearTheSearch,
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('picker-list'),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: kStackGap),
                        itemBuilder: (_, i) {
                          final exercise = shown[i];
                          final on = _picked.contains(exercise);
                          return Semantics(
                            selected: on,
                            checked: on,
                            child: AppListItem(
                              key: ValueKey('picker-${exercise.id}'),
                              title: exercise.name(language),
                              titleWidget: MoveName(
                                exercise.name(language),
                                style: AppText.titleM,
                              ),
                              subtitle: [
                                for (final s in exercise.sections)
                                  sectionLabel(l10n, s),
                              ].join(' · '),
                              variant: on
                                  ? AppCardVariant.selected
                                  : AppCardVariant.outlined,
                              leading: SizedBox(
                                width: 56,
                                height: 56,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  child: ColoredBox(
                                    color: AppColors.surfaceContainer,
                                    child: MovePoster(
                                      media: widget.media,
                                      poster: exercise.poster,
                                    ),
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                key: ValueKey('picker-toggle-${exercise.id}'),
                                tooltip: on
                                    ? l10n.removeName(exercise.name(language))
                                    : l10n.addName(exercise.name(language)),
                                onPressed: () => _toggle(exercise),
                                icon: Icon(
                                  on
                                      ? Icons.check_circle
                                      : Icons.add_circle_outline,
                                  color: on
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                              onTap: () => unawaited(_preview(exercise)),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AppButton(
                  l10n.addSelectedN(countLabel(_picked.length)),
                  key: const ValueKey('picker-add'),
                  icon: Icons.add,
                  onPressed: _picked.isEmpty
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop(<LibraryExercise>[..._picked]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
