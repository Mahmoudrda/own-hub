/// Explore, the browse half of Train (`R01`).
///
/// What the workout library and the exercise library used to be, as one
/// section of the Train page: a search box, one row of chips (all, strength,
/// stretches, then the part of the body), a Filters sheet for where she
/// trains and what she has, and the results in two groups, workouts that open
/// `R03` and moves that open `R15`.
///
/// Nothing here issues a query. The libraries are on the phone, so filtering
/// is a list operation. A move appears only with its clip on the phone's
/// library and a workout only when every move in it has one.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import '../domain/train_repository.dart';
import 'exercise_labels.dart';

/// What a door into Train asks Explore to show: a search, a part of the body
/// or a kind of move. Carried as the route's argument so Train opens
/// scrolled to Explore with the filter already on.
@immutable
class ExploreFocus {
  const ExploreFocus({this.query, this.section, this.kind});

  final String? query;
  final MuscleSection? section;
  final ExerciseKind? kind;
}

/// What the equipment chips can ask for, in the order they are offered.
enum ExploreKit { nothing, mat, dumbbells, bands, gymMachines }

bool _uses(LibraryExercise e, ExploreKit kit) => switch (kit) {
  ExploreKit.nothing => e.needsNothing,
  ExploreKit.mat => e.equipment.contains(LibraryEquipment.mat),
  ExploreKit.dumbbells => e.equipment.contains(LibraryEquipment.dumbbells),
  ExploreKit.bands => e.equipment.contains(LibraryEquipment.bands),
  ExploreKit.gymMachines => e.usesGymMachine,
};

String _kitLabel(AppL10n l10n, ExploreKit kit) => switch (kit) {
  ExploreKit.nothing => l10n.noEquipment,
  ExploreKit.mat => l10n.mat,
  ExploreKit.dumbbells => l10n.dumbbells,
  ExploreKit.bands => l10n.bands,
  ExploreKit.gymMachines => l10n.gymMachines,
};

/// Everything Explore is filtered by. The chip row is one choice: all, a
/// kind, or a part of the body.
class ExploreFilter {
  ExploreFilter([ExploreFocus? focus])
    : query = focus?.query ?? '',
      section = focus?.section,
      kind = focus?.section == null ? focus?.kind : null;

  String query;
  ExerciseKind? kind;
  MuscleSection? section;
  ExercisePlace? place;
  ExploreKit? kit;

  /// Only the quiet ones: the gentler way into a day she is not feeling.
  bool gentler = false;

  /// The chip that is lit: 0 all, 1 strength, 2 stretches, then the sections.
  int get chip {
    if (section != null) return 3 + MuscleSection.values.indexOf(section!);
    return switch (kind) {
      ExerciseKind.strength => 1,
      ExerciseKind.stretch => 2,
      null => 0,
    };
  }

  void setChip(int index) {
    kind = null;
    section = null;
    if (index == 1) kind = ExerciseKind.strength;
    if (index == 2) kind = ExerciseKind.stretch;
    if (index >= 3) section = MuscleSection.values[index - 3];
  }

  /// Anything the Filters sheet holds is on: the kind or part of the body,
  /// where, with what, or gentler.
  bool get narrowsBySheet =>
      chip != 0 || place != null || kit != null || gentler;

  bool get isActive => query.trim().isNotEmpty || narrowsBySheet;

  bool keepMove(LibraryExercise e) {
    if (kind != null && e.kind != kind) return false;
    if (section != null && e.section != section) return false;
    if (place != null && e.place != place) return false;
    if (kit != null && !_uses(e, kit!)) return false;
    if (gentler && !e.quiet) return false;
    return e.matches(query);
  }

  /// Workouts carry no body-part data, so a part of the body or a stretch
  /// leaves them out, and "no equipment" holds them to the ones that need none.
  bool keepWorkout(LibraryWorkout w) {
    if (section != null || kind == ExerciseKind.stretch) return false;
    if (kit == ExploreKit.nothing && w.needsEquipment) return false;
    if (gentler && !w.quiet) return false;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return w.title.toLowerCase().contains(needle) ||
        w.detail.toLowerCase().contains(needle);
  }
}

/// What she wants, where she can do it, what she has and how gentle, in one
/// sheet. It narrows the list behind it as she taps, so the sheet keeps its
/// own rebuild.
Future<void> showExploreFilters(
  BuildContext context, {
  required ExploreFilter filter,
  required List<LibraryExercise> exercises,
  required VoidCallback onChanged,
  int Function()? matchCount,
  List<LibraryWorkout>? workouts,
}) {
  final l10n = AppL10n.of(context);
  final kits = [
    for (final kit in ExploreKit.values)
      if (exercises.any((e) => _uses(e, kit))) kit,
  ];
  final places = [
    for (final place in ExercisePlace.values)
      if (exercises.any((e) => e.place == place)) place,
  ];
  return showAppSheet<void>(
    context: context,
    children: [
      StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.filters, style: AppText.titleL),
            const SizedBox(height: 14),
            // One choice: everything, a kind of move, or a part of the body.
            AppChipRow(
              key: const ValueKey('r01-focus'),
              grow: false,
              items: [
                l10n.all,
                l10n.strength,
                l10n.stretchesAndWarmUps,
                for (final s in MuscleSection.values) sectionLabel(l10n, s),
              ],
              selected: {filter.chip},
              onTap: (i) {
                filter.setChip(i);
                onChanged();
                setSheet(() {});
              },
            ),
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
                key: const ValueKey('r01-place'),
                grow: false,
                items: [for (final p in places) placeLabel(l10n, p)],
                selected: {
                  if (filter.place != null && places.contains(filter.place))
                    places.indexOf(filter.place!),
                },
                // Tapping the lit chip again clears it.
                onTap: (i) {
                  filter.place = filter.place == places[i] ? null : places[i];
                  onChanged();
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
                key: const ValueKey('r01-kit'),
                grow: false,
                items: [for (final k in kits) _kitLabel(l10n, k)],
                selected: {
                  if (filter.kit != null && kits.contains(filter.kit))
                    kits.indexOf(filter.kit!),
                },
                onTap: (i) {
                  filter.kit = filter.kit == kits[i] ? null : kits[i];
                  onChanged();
                  setSheet(() {});
                },
              ),
            ],
            const SizedBox(height: 14),
            AppChipRow(
              key: const ValueKey('r01-gentler'),
              grow: false,
              items: [l10n.gentler],
              selected: {if (filter.gentler) 0},
              onTap: (_) {
                filter.gentler = !filter.gentler;
                onChanged();
                setSheet(() {});
              },
            ),
            const SizedBox(height: 16),
            // The button says how many results the filters leave, and the
            // number moves as she taps. With none, it is drawn as unavailable
            // and says so kindly rather than leading to an empty page.
            Builder(
              builder: (_) {
                final n =
                    matchCount?.call() ??
                    exercises.where(filter.keepMove).length +
                        (workouts?.where(filter.keepWorkout).length ?? 0);
                final label = workouts != null
                    ? l10n.countPluralOneShow1ResultOther(n)
                    : l10n.countPluralOneShow1MoveOther(n);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: AppButton(
                        label,
                        key: const ValueKey('r01-filters-apply'),
                        onPressed: n == 0
                            ? null
                            : () => Navigator.of(sheet).pop(),
                      ),
                    ),
                    if (n == 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.nothingMatchesYetTryTakingOneFilter,
                        key: const ValueKey('r01-filters-empty'),
                        textAlign: TextAlign.center,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ],
  );
}

/// The two groups of results as slivers: workouts, then moves two to a row.
/// Moves are built as she scrolls, so opening Explore never starts a download
/// for every poster in the library.
List<Widget> exploreResultSlivers(
  BuildContext context, {
  required List<LibraryWorkout> workouts,
  required List<LibraryExercise> moves,
  required ExerciseMediaStore media,
  required bool filtered,
  ValueChanged<LibraryWorkout>? onOpenWorkout,
  ValueChanged<LibraryExercise>? onOpenMove,
}) {
  final l10n = AppL10n.of(context);
  final language = Localizations.localeOf(context).languageCode;
  final sorted = [...moves]
    ..sort((a, b) => a.name(language).compareTo(b.name(language)));
  final rows = (sorted.length + 1) ~/ 2;

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Semantics(header: true, child: Text(text, style: AppText.titleM)),
  );

  return [
    if (workouts.isNotEmpty) ...[
      SliverToBoxAdapter(child: heading(l10n.workouts)),
      SliverList.separated(
        itemCount: workouts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final workout = workouts[i];
          return AppListItem(
            key: ValueKey('r01-workout-${workout.id}'),
            title: workout.title,
            subtitle: workout.detail,
            leading: const AppMedia(
              width: 72,
              height: 56,
              borderRadius: AppRadius.sm,
              showPlayButton: false,
            ),
            trailing: const AppChevron(),
            onTap: () => onOpenWorkout?.call(workout),
          );
        },
      ),
    ],
    if (sorted.isNotEmpty) ...[
      SliverToBoxAdapter(child: heading(l10n.moves)),
      SliverList.separated(
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, row) {
          final a = sorted[row * 2];
          final b = row * 2 + 1 < sorted.length ? sorted[row * 2 + 1] : null;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MovePosterCard(
                  key: ValueKey('r01-move-${a.id}'),
                  exercise: a,
                  media: media,
                  onTap: () => onOpenMove?.call(a),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: b == null
                    ? const SizedBox.shrink()
                    : MovePosterCard(
                        key: ValueKey('r01-move-${b.id}'),
                        exercise: b,
                        media: media,
                        onTap: () => onOpenMove?.call(b),
                      ),
              ),
            ],
          );
        },
      ),
    ],
    if (workouts.isEmpty && sorted.isEmpty)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppEmptyState(
            icon: filtered ? Icons.search_off : Icons.play_circle_outline,
            title: filtered
                ? l10n.nothingMatchesThoseFilters
                : l10n.theExerciseLibraryIsOnItsWay,
            body: filtered
                ? l10n.tryAnotherFilterOrClearTheSearch
                : l10n.itArrivesTheNextTimeYouOpen,
          ),
        ),
      ),
    const SliverToBoxAdapter(child: SizedBox(height: 16)),
  ];
}

/// A move as a poster with a play badge, its name and the part it works.
class MovePosterCard extends StatelessWidget {
  const MovePosterCard({
    super.key,
    required this.exercise,
    required this.media,
    this.onTap,
  });

  final LibraryExercise exercise;
  final ExerciseMediaStore media;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final name = exercise.name(language);
    return HandPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      builder: (context, pressed) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.surfaceContainer,
                    child: MovePoster(media: media, poster: exercise.poster),
                  ),
                  PositionedDirectional(
                    end: 8,
                    bottom: 8,
                    child: ExcludeSemantics(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.brandPink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 24,
                          color: AppColors.onActionPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          MoveName(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.titleS,
          ),
          const SizedBox(height: 2),
          Text(
            [
              for (final section in exercise.sections)
                sectionLabel(l10n, section),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A move's poster: the file on the phone, or fetched the first time it is
/// built. Until then, a shimmer.
class MovePoster extends StatefulWidget {
  const MovePoster({super.key, required this.media, required this.poster});

  final ExerciseMediaStore media;
  final ExerciseMedia poster;

  @override
  State<MovePoster> createState() => _MovePosterState();
}

class _MovePosterState extends State<MovePoster> {
  File? _file;

  /// True until the file is on the phone or the fetch has given up.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MovePoster old) {
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
    if (file == null) {
      return _loading ? const Skeleton(radius: 0) : const SizedBox.expand();
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: (200 * dpr).round(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
