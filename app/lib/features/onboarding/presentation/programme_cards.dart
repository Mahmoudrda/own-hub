/// The coach's splits as cards she can choose between: the same three on O05
/// and in R02's "Change program" sheet, in the order of their days, with a
/// fourth card for building her own workout.
///
/// The card that suits her days says so. Choosing is a tap on a card or its
/// Choose button; nothing is saved until the screen that holds the cards says
/// so. Customize hands the split to the editor and Build my own workout starts
/// from nothing; both are callbacks, so a screen without them draws neither.
library;

import 'package:flutter/material.dart';

import '../../../app_state/chosen_programme.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart' show kStackGap;
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import '../../train/domain/programme_week.dart';
import '../../train/domain/workout_library.dart' show suits;
import '../domain/starting_program.dart';

/// The copy for one programme. Held together so a programme can never render a
/// title from one entry and a description from another.
typedef ProgramCopy = ({String title, String days, String minutes});

/// Copy for a programme id, or null when none has been written.
///
/// A programme with no copy renders no card, which is visibly incomplete: the
/// deliberate alternative to showing her an English id or an invented name.
/// Every programme in the bundled file has copy, and a test holds that: the
/// title is its days a week, the line under it names its days from the file,
/// and the minutes are what a day takes.
ProgramCopy? programCopyFor(
  AppL10n l10n,
  String programId,
  Intake intake, {
  StartingProgram? programme,
}) {
  if (programId == beginnerFoundations.programId) {
    return (
      title: l10n.beginnerFoundations,
      // "Quiet, no equipment" is a promise about training at home. A
      // woman who said she trains at a gym is not told it.
      days: intake.place == TrainingPlace.home
          ? l10n.n8WeeksQuietNoEquipment
          : l10n.n8WeeksForBeginners,
      minutes: l10n.week1StartsWithFourMovesOn_9iwwr,
    );
  }
  final known =
      programme ??
      [
        for (final p in kStartingProgramCatalogue)
          if (p.programId == programId) p,
      ].firstOrNull;
  if (known == null || !isCoachSplit(programId)) return null;
  final language = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
  final days = StartingProgrammes.dayNames(programId, language);
  if (days.isEmpty) return null;
  return (
    title: l10n.nDaySplit('${known.daysPerWeek}'),
    days: days,
    minutes: l10n.minutesMinASession(
      '${_minutesAtHers(programId, intake.minutes) ?? known.sessionLength}',
    ),
  );
}

/// What a day of the programme takes at the length she chose: the average of
/// its ordinary days cut the way Train cuts them, to the nearest five. Null when
/// no content is loaded under [programId].
int? _minutesAtHers(String programId, int minutes) {
  final programme = StartingProgrammes.programme(programId);
  if (programme == null) return null;
  final days = [
    for (final s in programme.sessions)
      if (suits(s, LifeStage.none)) estimatedMinutes(scaleSession(s, minutes)),
  ];
  if (days.isEmpty) return null;
  final mean = days.reduce((a, b) => a + b) / days.length;
  final rounded = (mean / 5).round() * 5;
  return rounded < 5 ? 5 : rounded;
}

/// Her days a week become the split's: it is what she will train. Her weekday
/// picks go only when their count no longer matches. Nothing happens for a
/// programme that is not one of the splits, such as the placeholder a build
/// holds before the content loads.
void alignDaysToSplit(IntakeRepository repository, StartingProgram chosen) {
  if (!isCoachSplit(chosen.programId)) return;
  ChosenProgramme.alignDays(repository, chosen.daysPerWeek);
}

class ProgrammeChoiceList extends StatelessWidget {
  const ProgrammeChoiceList({
    super.key,
    required this.programs,
    required this.intake,
    required this.selected,
    required this.onSelect,
    this.onCustomize,
    this.onBuildOwn,
    this.placeAnswered = true,
  });

  /// Best fit first. The cards are drawn in the order of their days, and the
  /// first of these is the one tagged as recommended. A programme with no copy
  /// is left out.
  final List<StartingProgram> programs;
  final Intake intake;
  final StartingProgram selected;
  final ValueChanged<StartingProgram> onSelect;

  /// Customize on a card. Null draws no Customize button.
  final ValueChanged<StartingProgram>? onCustomize;

  /// The Build my own workout card. Null draws no card.
  final VoidCallback? onBuildOwn;

  /// Not read any more: where she trains no longer decides which split she is
  /// shown. Kept so existing callers keep compiling.
  final bool placeAnswered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final best = programs.isEmpty ? null : programs.first;
    final byDays = [...programs]
      ..sort((a, b) => a.daysPerWeek.compareTo(b.daysPerWeek));
    final cards = <Widget>[];
    for (final program in byDays) {
      final copy = programCopyFor(
        l10n,
        program.programId,
        intake,
        programme: program,
      );
      if (copy == null) continue;
      cards.add(
        _ProgrammeCard(
          key: ValueKey('program-card-${program.programId}'),
          copy: copy,
          chosen: program == selected,
          recommended: program == best,
          onTap: () => onSelect(program),
          onCustomize: onCustomize == null ? null : () => onCustomize!(program),
        ),
      );
    }
    if (onBuildOwn != null) {
      cards.add(
        _BuildOwnCard(
          key: const ValueKey('program-card-build-own'),
          onTap: onBuildOwn!,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: kStackGap,
      children: StaggerIn.all(cards, group: 'o05-plans'),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({
    super.key,
    required this.copy,
    required this.chosen,
    required this.recommended,
    required this.onTap,
    required this.onCustomize,
  });

  final ProgramCopy copy;
  final bool chosen;
  final bool recommended;
  final VoidCallback onTap;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      container: true,
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      child: AppCard(
        variant: chosen ? AppCardVariant.selected : AppCardVariant.outlined,
        onTap: onTap,
        children: [
          if (recommended)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppPill(l10n.recommendedForYourDays),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The programme she is going with is the one thing marked.
                    if (chosen)
                      MarkerHighlight(
                        drawOn: true,
                        delay: HandTiming.medium,
                        child: Text(
                          copy.title,
                          textWidthBasis: TextWidthBasis.longestLine,
                          style: AppText.titleL,
                        ),
                      )
                    else
                      Text(
                        copy.title,
                        textWidthBasis: TextWidthBasis.longestLine,
                        style: AppText.titleL,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      copy.days,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                chosen ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 26,
                color: chosen
                    ? AppColors.primaryDim
                    : AppColors.onSurfaceVariant,
              ),
            ],
          ),
          Text(
            copy.minutes,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.choose,
                  key: const ValueKey('program-choose'),
                  // Never filled: the screen's own button is the one action.
                  variant: AppButtonVariant.tonal,
                  height: 48,
                  fontSize: 15,
                  onPressed: onTap,
                ),
              ),
              if (onCustomize != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    l10n.customize,
                    key: const ValueKey('program-customize'),
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    fontSize: 15,
                    onPressed: onCustomize,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The fourth card: a way not to follow a split at all. Large on purpose, so
/// nobody hunts for it.
class _BuildOwnCard extends StatelessWidget {
  const _BuildOwnCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      button: true,
      child: AppCard(
        variant: AppCardVariant.tonal,
        padding: const EdgeInsets.all(20),
        onTap: onTap,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: 40,
                color: AppColors.primaryDim,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.buildMyOwnWorkout, style: AppText.titleL),
                    const SizedBox(height: 3),
                    Text(
                      l10n.startFromScratchOrEditOneOf,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// R02's "Change program": the same cards in a sheet, and the way to every
/// programme beneath them. Choosing a card closes the sheet.
Future<void> showProgrammeChooser(
  BuildContext context, {
  required List<StartingProgram> programs,
  required Intake intake,
  required StartingProgram current,
  required ValueChanged<StartingProgram> onChoose,
  required VoidCallback onSeeAll,
  bool placeAnswered = true,
  ValueChanged<StartingProgram>? onCustomize,
  VoidCallback? onBuildOwn,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: AppColors.ink.withValues(alpha: 0.45),
  builder: (sheet) {
    final l10n = AppL10n.of(sheet);
    return AppSheet(
      children: [
        Text(l10n.chooseYourProgram, style: AppText.titleL),
        ProgrammeChoiceList(
          programs: programs,
          intake: intake,
          selected: current,
          placeAnswered: placeAnswered,
          onSelect: (program) {
            Navigator.of(sheet).pop();
            onChoose(program);
          },
          onCustomize: onCustomize == null
              ? null
              : (program) {
                  Navigator.of(sheet).pop();
                  onCustomize(program);
                },
          onBuildOwn: onBuildOwn == null
              ? null
              : () {
                  Navigator.of(sheet).pop();
                  onBuildOwn();
                },
        ),
        AppButton(
          l10n.seeAllPrograms,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: () {
            Navigator.of(sheet).pop();
            onSeeAll();
          },
        ),
      ],
    );
  },
);
