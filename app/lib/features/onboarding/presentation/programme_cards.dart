/// The programmes that fit her, as cards she can choose between: the same
/// three on O05 and in R02's "Change program" sheet.
///
/// The first card is the best fit and says why, in her own answers. Choosing
/// is a tap on a card; nothing is saved until the screen that holds the cards
/// says so.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart' show kStackGap;
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../domain/intake.dart';
import '../domain/starting_program.dart';

/// The copy for one programme. Held together so a programme can never render a
/// title from one entry and a description from another.
typedef ProgramCopy = ({String title, String detail, String firstWeek});

/// Dictionary copy for a programme id, or null when none has been written.
///
/// A programme with no copy renders no card, which is visibly incomplete: the
/// deliberate alternative to showing her an English id or an invented name.
/// Every programme in the bundled file has an entry, and a test holds that.
ProgramCopy? programCopyFor(AppL10n l10n, String programId, Intake intake) {
  // The plan's name and its first week, then where it is done: the file's ids
  // are `<plan>_<variant>`.
  ProgramCopy plan(String title, String firstWeek, String detail) =>
      (title: title, detail: detail, firstWeek: firstWeek);
  final stronger = l10n.eachSessionIsAFullBodyWith;
  final feelGood = l10n.eachSessionIsAGentleFullBody;
  final steady = l10n.eachSessionIsASteadyCircuitWith;
  final atHome = l10n.atHomeQuietNothingToBuy;
  final withDumbbells = l10n.atHomeQuietWithYourDumbbells;
  final atGym = l10n.atTheGymWeightsAndMachines;
  switch (programmeFamily(programId)) {
    case 'stronger_home':
      return plan(l10n.getStronger, stronger, atHome);
    case 'stronger_weights':
      return plan(l10n.getStronger, stronger, withDumbbells);
    case 'stronger_gym':
      return plan(l10n.getStronger, stronger, atGym);
    case 'feel_better_home':
      return plan(l10n.feelGoodAndMove, feelGood, atHome);
    case 'feel_better_weights':
      return plan(l10n.feelGoodAndMove, feelGood, withDumbbells);
    case 'feel_better_gym':
      return plan(l10n.feelGoodAndMove, feelGood, atGym);
    case 'lose_steadily_home':
      return plan(l10n.loseSteadily, steady, atHome);
    case 'lose_steadily_weights':
      return plan(l10n.loseSteadily, steady, withDumbbells);
    case 'lose_steadily_gym':
      return plan(l10n.loseSteadily, steady, atGym);
    case 'beginner_foundations':
      return (
        title: l10n.beginnerFoundations,
        // "Quiet, no equipment" is a promise about training at home. A
        // woman who said she trains at a gym is not told it.
        detail: intake.place == TrainingPlace.home
            ? l10n.n8WeeksQuietNoEquipment
            : l10n.n8WeeksForBeginners,
        firstWeek: l10n.week1StartsWithFourMovesOn_9iwwr,
      );
  }
  return null;
}

String _goalLabel(AppL10n l10n, TrainingGoal goal) => switch (goal) {
  TrainingGoal.stronger => l10n.getStronger,
  TrainingGoal.feelBetter => l10n.feelGoodAndMove,
  TrainingGoal.loseSteadily => l10n.loseSteadily,
  TrainingGoal.backIntoIt => l10n.getBackIntoIt,
};

/// The answers that chose the best fit, as short chips: her goal, where she
/// trains and how long a session is. Where she trains is left out when she was
/// never asked.
List<String> whyChips(
  AppL10n l10n,
  Intake intake, {
  required bool placeAnswered,
}) => [
  _goalLabel(l10n, intake.goal),
  if (placeAnswered)
    switch (intake.place) {
      TrainingPlace.home => l10n.atHome,
      TrainingPlace.ladiesGym => l10n.atALadiesOnlyGym,
      TrainingPlace.both => l10n.atHomeAndTheGym,
    },
  l10n.minutesMinASession('${intake.minutes}'),
];

class ProgrammeChoiceList extends StatelessWidget {
  const ProgrammeChoiceList({
    super.key,
    required this.programs,
    required this.intake,
    required this.selected,
    required this.onSelect,
    this.placeAnswered = true,
  });

  /// Best fit first. A programme with no copy is left out.
  final List<StartingProgram> programs;
  final Intake intake;
  final StartingProgram selected;
  final ValueChanged<StartingProgram> onSelect;
  final bool placeAnswered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cards = <Widget>[];
    for (final program in programs) {
      final copy = programCopyFor(l10n, program.programId, intake);
      if (copy == null) continue;
      cards.add(
        _ProgrammeCard(
          key: ValueKey('program-card-${program.programId}'),
          copy: copy,
          chosen: program == selected,
          recommended: cards.isEmpty,
          why: cards.isEmpty
              ? whyChips(l10n, intake, placeAnswered: placeAnswered)
              : const [],
          onTap: () => onSelect(program),
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
    required this.why,
    required this.onTap,
  });

  final ProgramCopy copy;
  final bool chosen;
  final bool recommended;
  final List<String> why;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      button: true,
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      child: AppCard(
        variant: chosen ? AppCardVariant.selected : AppCardVariant.outlined,
        onTap: onTap,
        children: [
          if (recommended)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppPill(l10n.recommendedForYou),
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
                      copy.detail,
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
            copy.firstWeek,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (why.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final chip in why) AppChip(chip)],
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
