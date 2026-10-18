/// P06 "Your muscles": her body from the front and the back, each muscle
/// coloured by the sets where it did the work, and what that says in plain
/// words.
///
/// From the top: the window (7 or 30 days), the figure and its legend, the
/// card for the muscle or group she chose, up to three insights, and every
/// muscle group as a list. Every colour on the figure is said again in
/// numbers somewhere on the page, so nothing rests on colour alone. No
/// kitten: the mascot is never on Progress.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/screen_art_strip.dart';
import '../../onboarding/domain/intake.dart'
    show Equipment, LifeStage, TrainingPlace;
import '../../today/presentation/today_cards.dart'
    show openScreen, weekdayLabel;
import '../../train/domain/exercise_library.dart';
import '../../train/presentation/exercise_labels.dart'
    show muscleLabel, sectionLabel;
import '../domain/muscle_insights.dart';
import '../domain/muscle_map.dart';
import '../domain/muscle_report.dart';
import 'muscle_figure.dart';
import 'muscle_map_art.dart' show MuscleHeat;

class MusclesView extends StatefulWidget {
  const MusclesView({
    super.key,
    required this.report,
    this.library = const <LibraryExercise>[],
    this.lifeStage,
    this.place = TrainingPlace.home,
    this.equipment = const {Equipment.none},
    this.onOpenMove,
    this.onOpenLibrary,
    this.onBack,
    this.onSelectTab,
  });

  /// Her training, read from her log.
  final MuscleReport report;

  /// The exercise library, unscreened. Screened here for her life stage
  /// before a move is suggested.
  final List<LibraryExercise> library;
  final LifeStage? lifeStage;
  final TrainingPlace place;
  final Set<Equipment> equipment;

  /// One move's demo, R15. Null while R15 is off: the moves are then named
  /// without a link.
  final ValueChanged<LibraryExercise>? onOpenMove;

  /// Explore on Train. Null while the library is empty.
  final VoidCallback? onOpenLibrary;

  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectTab;

  @override
  State<MusclesView> createState() => _MusclesViewState();
}

class _MusclesViewState extends State<MusclesView> {
  MuscleWindow _window = MuscleWindow.week;

  /// A group she opened from the list, or a muscle she tapped on the
  /// figure. Never both.
  MuscleSection? _selected;
  Muscle? _muscle;
  final GlobalKey _figureKey = GlobalKey();

  MuscleReport get _report => widget.report;

  void _select(MuscleSection? section, {bool reveal = false}) {
    setState(() {
      _selected = section;
      _muscle = null;
    });
    if (!reveal || section == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _figureKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: Duration.zero,
        alignment: 0.05,
      );
    });
  }

  void _selectMuscle(Muscle? muscle) => setState(() {
    _muscle = muscle;
    _selected = null;
  });

  List<LibraryExercise> _movesFor(MuscleSection section) => movesForSection(
    screenForLifeStage(widget.library, widget.lifeStage).shown,
    section,
    place: widget.place,
    equipment: widget.equipment,
  );

  List<LibraryExercise> _movesForMuscle(Muscle muscle) => movesForMuscle(
    screenForLifeStage(widget.library, widget.lifeStage).shown,
    muscle,
    place: widget.place,
    equipment: widget.equipment,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // The figure is coloured muscle by muscle, by the sets where each did
    // the work: a set where a muscle only helped leaves it grey.
    final scores = {
      for (final m in Muscle.values)
        if (_report.muscleScore(_window, m) > 0)
          m: _report.muscleScore(_window, m),
    };
    final ranked = _report.ranked(_window);
    final worked = _report.rankedMuscles(_window);
    final selected = _selected;
    final muscle = _muscle;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.yourMuscles, onBack: widget.onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'P06',
        onSelect: (id) {
          final onTab = widget.onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: [
          AppSegmented(
            items: [
              for (final w in MuscleWindow.values)
                l10n.daysPluralOne1DayOtherDays(w.days),
            ],
            selectedIndex: _window.index,
            onChanged: (i) => setState(() => _window = MuscleWindow.values[i]),
          ),
          KeyedSubtree(
            key: _figureKey,
            child: MuscleFigure(
              scores: scores,
              selected: {
                ?muscle,
                if (selected != null)
                  for (final m in Muscle.values)
                    if (sectionOf(m) == selected) m,
              },
              onSelect: _selectMuscle,
              semanticsLabel: l10n.bodyMapInSetsList(
                worked.isEmpty
                    ? l10n.notTrainedYet
                    : [
                        for (final w in worked)
                          '${muscleLabel(l10n, w.muscle)} ${setsLabel(w.sets)}',
                      ].join(', '),
              ),
              frontLabel: l10n.frontView,
              backLabel: l10n.backView,
            ),
          ),
          Text(
            l10n.tapAMuscleForItsSets,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (_report.hasSetsIn(_window))
            _Legend(max: _report.muscleMaxIn(_window)),
          if (muscle != null) _muscleCard(context, l10n, muscle),
          if (selected != null) _partCard(context, l10n, selected),
          ..._insights(context, l10n),
          // Every group, with its sets: the same facts as the figure, in a
          // form a screen reader and large text read as easily. Not drawn
          // before her first log, when it would be eleven noughts.
          if (_report.hasAnyLog) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(l10n.allYourMuscles, style: AppText.titleM),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.daysPluralOneSetsIn1Day_1w8hx(_window.days),
                    textAlign: TextAlign.end,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          for (final v in _report.hasAnyLog ? ranked : const <SectionVolume>[])
            _SectionRow(
              key: ValueKey('p06-row-${v.section.name}'),
              label: sectionLabel(l10n, v.section),
              spoken:
                  '${sectionLabel(l10n, v.section)}, ${_setsLine(l10n, v.sets)}',
              volume: v,
              selected: v.section == selected,
              onTap: () => _select(
                v.section == selected ? null : v.section,
                reveal: v.section != selected,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.howWeCountASetCountsIn,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const ScreenArtInline(size: 56),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _setsLine(AppL10n l10n, double sets) =>
      l10n.daysPluralOneSetsIn1Day(_window.days, setsLabel(sets));

  /// The card for the group she opened from the list: its sets, when she
  /// last trained it, and moves for it.
  Widget _partCard(BuildContext context, AppL10n l10n, MuscleSection section) {
    return _card(
      context,
      l10n,
      title: sectionLabel(l10n, section),
      lines: [
        Text(
          _setsLine(l10n, _report.setsIn(_window, section)),
          style: AppText.titleS,
        ),
        Text(
          lastTrainedLine(l10n, _report, section),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
      moves: _movesFor(section),
    );
  }

  /// The card for the muscle she tapped: the sets where it did the work, the
  /// sets where it only helped, when it last did the work, and moves for it.
  Widget _muscleCard(BuildContext context, AppL10n l10n, Muscle muscle) {
    final helped = _report.helpedSets(_window, muscle).round();
    return _card(
      context,
      l10n,
      title: muscleLabel(l10n, muscle),
      lines: [
        Text(
          _setsLine(l10n, _report.workedSets(_window, muscle)),
          style: AppText.titleS,
        ),
        if (helped > 0)
          Text(
            l10n.countPluralOneAlsoWorked1Set(helped),
            key: const ValueKey('p06-also-worked'),
            style: AppText.bodyM,
          ),
        Text(
          lastWorkedLine(l10n, _report, muscle),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
      moves: _movesForMuscle(muscle),
    );
  }

  Widget _card(
    BuildContext context,
    AppL10n l10n, {
    required String title,
    required List<Widget> lines,
    required List<LibraryExercise> moves,
  }) {
    return AppCard(
      key: const ValueKey('p06-part-card'),
      variant: AppCardVariant.selected,
      gap: 6,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppText.titleL)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => _select(null),
              icon: const Icon(Icons.close, size: 20),
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
        ...lines,
        if (moves.isNotEmpty) ...[
          const SizedBox(height: 4),
          _Moves(
            title: l10n.movesYouCouldAdd,
            moves: moves,
            onOpenMove: widget.onOpenMove,
          ),
        ],
        if (widget.onOpenLibrary != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onOpenLibrary,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDim,
                minimumSize: const Size(48, 44),
              ),
              icon: const Icon(Icons.play_circle_outline, size: 20),
              label: Text(l10n.exerciseLibrary, style: AppText.label),
            ),
          ),
      ],
    );
  }

  List<Widget> _insights(BuildContext context, AppL10n l10n) {
    if (!_report.hasAnyLog) {
      return [
        AppCard(
          key: const ValueKey('p06-empty'),
          variant: AppCardVariant.tonal,
          children: [
            Text(l10n.logYourFirstWorkoutAndYourMuscles, style: AppText.titleM),
          ],
        ),
      ];
    }
    final out = <Widget>[];
    if (!_report.hasSetsIn(_window)) {
      out.add(
        AppCard(
          key: const ValueKey('p06-window-empty'),
          variant: AppCardVariant.filled,
          children: [
            Text(
              l10n.daysPluralOneNoSetsLoggedToday(_window.days),
              style: AppText.body,
            ),
          ],
        ),
      );
    }

    final top = mostTrained(_report, _window);
    if (top != null) {
      out.add(
        _Insight(
          key: const ValueKey('p06-most-trained'),
          overline: l10n.mostTrained,
          variant: AppCardVariant.tonal,
          lines: [
            l10n.inSetsList(
              [
                for (final v in top.top)
                  '${sectionLabel(l10n, v.section)} ${setsLabel(v.sets)}',
              ].join(' · '),
            ),
          ],
        ),
      );
    }

    final resting = restingSection(
      _report,
      library: widget.library,
      lifeStage: widget.lifeStage,
      place: widget.place,
      equipment: widget.equipment,
    );
    if (resting != null) {
      out.add(
        _Insight(
          key: const ValueKey('p06-resting'),
          overline: l10n.beenAWhile,
          title: sectionLabel(l10n, resting.section),
          lines: [lastTrainedLine(l10n, _report, resting.section)],
          footer: resting.moves.isEmpty
              ? null
              : _Moves(
                  title: l10n.movesYouCouldAdd,
                  moves: resting.moves,
                  onOpenMove: widget.onOpenMove,
                ),
        ),
      );
    }

    final even = balance(_report, _window);
    if (even != null) {
      out.add(
        _Insight(
          key: const ValueKey('p06-balance'),
          overline: l10n.balance,
          lines: [
            balanceSentence(l10n, even),
            even.axis == BalanceAxis.upperLower
                ? l10n.inSetsUpperBodyUpperLowerBody(
                    setsLabel(even.first),
                    setsLabel(even.second),
                  )
                : l10n.inSetsFrontFrontBackBack(
                    setsLabel(even.first),
                    setsLabel(even.second),
                  ),
            ?balanceNudge(l10n, even),
          ],
        ),
      );
    }
    return out;
  }
}

/// "Last trained: Tuesday", "Last trained: 12 days ago", or "Not trained yet".
String lastTrainedLine(
  AppL10n l10n,
  MuscleReport report,
  MuscleSection section,
) => _lastLine(l10n, report.daysSince(section), report.lastTrained(section));

/// The same for one muscle, counting only the sets where it did the work.
String lastWorkedLine(AppL10n l10n, MuscleReport report, Muscle muscle) =>
    _lastLine(l10n, report.daysSinceWorked(muscle), report.lastWorked(muscle));

String _lastLine(AppL10n l10n, int? days, DateTime? last) {
  if (days == null || last == null) return l10n.notTrainedYet;
  final day = switch (days) {
    0 => l10n.today,
    1 => l10n.yesterday,
    < 7 => weekdayLabel(l10n, last),
    _ => l10n.daysPluralOne1DayAgoOther(days),
  };
  return l10n.lastTrainedDay(day);
}

/// The balance in one plain sentence.
String balanceSentence(AppL10n l10n, Balance b) {
  return switch ((b.axis, b.more)) {
    (BalanceAxis.upperLower, null) => l10n.yourUpperAndLowerBodyGotAbout,
    (BalanceAxis.frontBack, null) => l10n.theFrontAndBackOfYourBody,
    (_, BodyRegion.lower) => l10n.timesPlural0AllOfTheseSets(b.times),
    (_, BodyRegion.upper) => l10n.timesPlural0AllOfTheseSets_izoa9(b.times),
    (_, BodyRegion.front) => l10n.timesPlural0AllOfTheseSets_2tsm2(b.times),
    (_, BodyRegion.back) => l10n.timesPlural0AllOfTheseSets_1ysmj(b.times),
  };
}

/// A gentle way to even it out, only when it is not even. A suggestion, not
/// a correction: a plan built for her glutes is meant to lean that way.
String? balanceNudge(AppL10n l10n, Balance b) => switch (b.more) {
  null => null,
  BodyRegion.lower => l10n.ifYouWouldLikeItMoreEven,
  BodyRegion.upper => l10n.ifYouWouldLikeItMoreEven_fk4be,
  BodyRegion.back => l10n.ifYouWouldLikeItMoreEven_1jmf2,
  BodyRegion.front => l10n.ifYouWouldLikeItMoreEven_v8jiq,
};

class _Insight extends StatelessWidget {
  const _Insight({
    super.key,
    required this.overline,
    required this.lines,
    this.title,
    this.footer,
    this.variant = AppCardVariant.outlined,
  });

  final String overline;
  final String? title;
  final List<String> lines;
  final Widget? footer;
  final AppCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: variant,
      gap: 6,
      children: [
        Text(
          overline,
          style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (title != null) Text(title!, style: AppText.titleM),
        for (var i = 0; i < lines.length; i++)
          Text(
            lines[i],
            style: i == 0 && title == null ? AppText.titleS : AppText.bodyM,
          ),
        ?footer,
      ],
    );
  }
}

class _Moves extends StatelessWidget {
  const _Moves({required this.title, required this.moves, this.onOpenMove});

  final String title;
  final List<LibraryExercise> moves;
  final ValueChanged<LibraryExercise>? onOpenMove;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final open = onOpenMove;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final move in moves)
              AppChip(
                move.name(language),
                icon: open == null ? null : Icons.play_arrow,
                onTap: open == null ? null : () => open(move),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Not yet · 0" to "More training · 9", with the five colours between.
class _Legend extends StatelessWidget {
  const _Legend({required this.max});

  final double max;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final style = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final swatches = [MuscleHeat.untrained, ...MuscleHeat.steps];
    return Column(
      key: const ValueKey('p06-legend'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < swatches.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: swatches[i],
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text('${l10n.notYet} · 0', style: style)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.moreTraining} · ${setsLabel(max)}',
                style: style,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One muscle group in the list: its name, its sets and a bar for them.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.label,
    required this.spoken,
    required this.volume,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// What a screen reader hears: the name and its sets, with the unit.
  final String spoken;
  final SectionVolume volume;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sets = setsLabel(volume.sets);
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: selected ? AppText.titleS : AppText.bodyM,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(sets, style: AppText.titleS),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: AppColors.surfaceHigh),
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: volume.score.clamp(0.0, 1.0),
                          child: ColoredBox(color: MuscleHeat.of(volume.score)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
