/// R02 — Program.
///
/// Matches `6-v2/src/screens-train.mjs` → `R02`. The programme page carries the
/// promise (pelvic floor first, cleared from week six with a doctor) and the
/// week. Three levels deep, never four.
///
/// **This is the download surface**, and that is a deliberate placement rather
/// than a spare slot in the app bar. Saving a week costs her roughly 120 MB at
/// the low-data profile, which at Egyptian prepaid rates is real money — so the
/// offer belongs where she is already deciding how much of this programme she
/// wants, not buried in settings.
///
/// The header still is an [AppMedia] placeholder. The prototype labels it "coach
/// demo still" in a monospace face; that is a designer's annotation marking where
/// footage goes, not copy, so it is not rendered. See the report note on
/// `coachDemoStill`.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'train_widgets.dart';

/// One day of the programme's week, as R02 lists it.
class ProgramDay {
  const ProgramDay({
    required this.title,
    this.detail = '',
    this.done = false,
    this.today = false,
    this.onTap,
  });

  final String title;

  /// "15 min · done Monday" — her progress through the day, when it is known.
  ///
  /// Empty renders no second line, which is the honest state for a plan this
  /// screen has not been given. It is her history, not the programme's shape.
  final String detail;
  final bool done;
  final bool today;
  final VoidCallback? onTap;
}

class ProgramView extends StatelessWidget {
  const ProgramView({
    super.key,
    this.onBack,
    this.onDownloadWeek,
    this.onChangeProgram,
    this.onStart,
    this.onOpenDay,
    this.days,
    this.title,
    this.week,
    this.totalWeeks,
    this.sessionsDone,
    this.sessionsTarget,
  });

  final VoidCallback? onBack;

  /// Fetches this week's videos for offline use.
  final VoidCallback? onDownloadWeek;

  final VoidCallback? onChangeProgram;
  final VoidCallback? onStart;
  final ValueChanged<ProgramDay>? onOpenDay;

  /// Injectable, so the real plan can supply the week.
  final List<ProgramDay>? days;

  final String? title;

  /// Where she is in the programme, and how far it runs. Null renders no week
  /// line at all — see [build]. Never defaulted: a default here would be the
  /// prototype's week wearing a different coat.
  final int? week;
  final int? totalWeeks;

  /// This week's sessions against this week's goal. Rendered together or not at
  /// all, so the two halves of "2 of 3" cannot come from different places.
  final int? sessionsDone;
  final int? sessionsTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // The programme's three days, and nothing about how she has got on with
    // them.
    //
    // The titles are the programme's own shape — day one of Postpartum rebuild
    // really is full body — and belong with the bundled content, exactly as
    // `LibraryWorkout.title` does. What was withdrawn is the second line:
    // `n15MinDoneMonday` marked day one DONE and said she had done it on a
    // Monday, `n15MinToday` said today was day two, `n20MinThursday` put day
    // three on a Thursday. All three are claims about her week, and R02 is
    // handed no week — `app_router.dart` builds it with no `days` at all. A
    // plan that supplies them renders them; nothing invents them.
    final days =
        this.days ??
        [
          ProgramDay(title: l10n.day1FullBody),
          ProgramDay(title: l10n.day2LegsAndGlutes),
          ProgramDay(title: l10n.day3UpperBody),
        ];

    return AppScaffold(
      appBar: AppTopBar(
        title: title ?? l10n.postpartumRebuild,
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: onDownloadWeek,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      footer: [
        // `startDay2` — "Start day 2" — named the prototype's day to whoever
        // opened this screen, on whatever day of whatever week. The session it
        // starts is today's either way.
        AppButton(
          l10n.startTodaysSession,
          icon: Icons.play_arrow,
          onPressed: onStart,
        ),
      ],
      children: [
        AppMedia(height: 150, badge: l10n.n8Weeks),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(l10n.n3DaysAWeek),
            AppChip(l10n.atHome),
            AppChip(l10n.quiet),
          ],
        ),
        Text(
          l10n.rebuiltAroundThePelvicFloorFirstCleared,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // Her week and her count, or neither.
        //
        // This was two fixed strings, `week3` and `n2Of3Done`, so every woman
        // who opened her programme was told she was in week 3 and had done two
        // of three sessions. R02 is given a week or it says nothing about one —
        // the same rule R01's badge already follows.
        //
        // When it is known, her week is circled the way she would mark her
        // place in a printed plan, under a rule that closes the promise above.
        if (week != null || sessionsDone != null) ...[
          const HandRule(seed: 17, height: 10),
          Row(
            children: [
              Expanded(
                child: week == null
                    ? const Text('', style: AppText.titleM)
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: HandCircled(
                            level: HandLevel.crafted,
                            width: 1.2,
                            color: AppColors.primaryDim,
                            child: Text(
                              l10n.weekWeekOfTotal(
                                countLabel(week!),
                                countLabel(totalWeeks ?? week!),
                              ),
                              style: AppText.titleM,
                            ),
                          ),
                        ),
                      ),
              ),
              if (sessionsDone != null && sessionsTarget != null)
                Text(
                  l10n.countOfTotal(
                    countLabel(sessionsDone!),
                    countLabel(sessionsTarget!),
                  ),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
        for (final day in days)
          MoveRow(
            name: day.title,
            detail: day.detail,
            done: day.done,
            current: day.today,
            onTap: day.onTap ?? () => onOpenDay?.call(day),
          ),
        AppButton(
          l10n.changeProgram,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: onChangeProgram,
        ),
      ],
    );
  }
}
