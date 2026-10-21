/// R02 — Program.
///
/// Matches `6-v2/src/screens-train.mjs` → `R02`. The programme page carries a
/// programme's promise and its week. Three levels deep, never four.
///
/// **Everything on it is her programme's, or it is not drawn.** The prototype's
/// body was one particular programme written into the screen: a postpartum
/// promise (pelvic floor first, cleared from week six with a doctor), an "8
/// weeks" badge, "3 days a week · At home · Quiet", and Day 1 / Day 2 / Day 3.
/// Its title had already been taken off — the bar read "Postpartum rebuild" to
/// every woman — but the body went on saying the same thing three more times,
/// to a woman nobody had asked whether she had ever been pregnant.
///
/// A plan that supplies a [promise], a [week] and [days] renders all of it.
/// With nothing supplied the screen says so, in the one form this product uses
/// for a surface that is honestly empty (`app_empty_state.dart`, HANDOFF rule
/// 17). It does **not** invent a curriculum: the build ships one authored
/// session (`sampleWorkoutDay`), the footer starts it, and the empty state says
/// that is what there is.
///
/// **This is the download surface**, and that is a deliberate placement rather
/// than a spare slot in the app bar. Saving a week costs her roughly 120 MB at
/// the low-data profile, which at Egyptian prepaid rates is real money — so the
/// offer belongs where she is already deciding how much of this programme she
/// wants, not buried in settings.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_empty_state.dart';
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
    this.promise,
    this.week,
    this.totalWeeks,
    this.sessionsDone,
    this.sessionsTarget,
    this.tierTabs,
  });

  /// The Beginner / Intermediate / Advanced tabs, under the promise.
  final Widget? tierTabs;

  final VoidCallback? onBack;

  /// Fetches this week's videos for offline use.
  final VoidCallback? onDownloadWeek;

  final VoidCallback? onChangeProgram;
  final VoidCallback? onStart;
  final ValueChanged<ProgramDay>? onOpenDay;

  /// The programme's own days. Empty or null renders the empty state.
  ///
  /// This used to fall back to `Day 1 · Full body`, `Day 2 · Legs and glutes`,
  /// `Day 3 · Upper body`. They are one real programme's days, and the router
  /// builds `R02` with no days at all, so they were three days of somebody
  /// else's week shown to everyone. A title is bundled content when it belongs
  /// to a plan she is on; with no plan it is an invention.
  final List<ProgramDay>? days;

  final String? title;

  /// What the programme promises, in the programme's own words.
  ///
  /// This was the fixed "Rebuilt around the pelvic floor first. Cleared for
  /// postpartum from week six, with your doctor's go-ahead." — a medical claim
  /// about a programme nobody had chosen, addressed to every woman who opened
  /// the screen. The promise is the reason a programme page exists rather than
  /// a list, so it stays; it now belongs to a programme instead of to the
  /// screen. Null renders nothing.
  final String? promise;

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

    // The programme's days, and nothing about how she has got on with them.
    //
    // Two rounds of withdrawal ended here. First the second lines went:
    // `n15MinDoneMonday` marked day one DONE and said she had done it on a
    // Monday, `n15MinToday` said today was day two, `n20MinThursday` put day
    // three on a Thursday — three claims about a week this screen is handed
    // nothing about. The titles were kept on the argument that they are the
    // programme's own shape, which is true of a programme she is on and of no
    // programme at all: the router builds `R02` with no days, so "Day 1 · Full
    // body" was one particular plan's first day presented as hers. Empty is
    // the honest reading, and the empty state below says what is there.
    final days = this.days ?? const <ProgramDay>[];
    final hasProgram = days.isNotEmpty;

    return AppScaffold(
      appBar: AppTopBar(
        // The programme's name when there is one, and the section's own name
        // when there is not.
        //
        // This read `title ?? postpartumRebuild`, and the `R02` builder passes
        // no title, so every woman's programme page was headed "Postpartum
        // rebuild" — a second name for the same thing one tap from R01's, and
        // neither of them hers. "Your training" names the page rather than
        // inventing a programme she never chose.
        title: title ?? l10n.yourTraining,
        onBack: onBack,
        actions: [
          // The download surface, when there is a week to download. With no
          // programme there is nothing to fetch, and an offer to spend roughly
          // 120 MB of her data on it would be the worst kind of empty control.
          // The same when nothing is wired to fetch it: a disabled icon reads
          // as a broken one.
          if (hasProgram && onDownloadWeek != null)
            IconButton(
              onPressed: onDownloadWeek,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              tooltip: l10n.downloadThisWeek,
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
        // The three chips — "3 days a week", "At home", "Quiet" — are gone
        // rather than parameterised. Each is a property of one programme, this
        // screen is handed none of them, and a chip is read as a fact about
        // what she is doing. A plan that wants to state its shape has the
        // promise below and the week line under that.
        if (promise != null)
          Text(
            promise!,
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
        ?tierTabs,
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
        // Her programme's days, or what there is instead.
        //
        // The empty state says the two true things: no programme has been
        // written for her, and one session is ready now. It names the footer
        // button rather than offering a second way in, because rule 17 asks
        // for the single smallest action and the footer already is it.
        if (!hasProgram) ...[
          AppEmptyState(
            icon: Icons.checklist,
            title: l10n.noProgramYet,
            body: l10n.aProgramSetsOutYourWeeksAnd,
          ),
          // First view with no plan only: it waves once.
          const Kitten(
            pose: KittenPose.wave,
            size: 56,
            moment: 'R02',
            sessionBudget: true,
          ),
        ] else
          for (final day in days)
            MoveRow(
              name: day.title,
              detail: day.detail,
              done: day.done,
              current: day.today,
              tag: day.done
                  ? l10n.completed
                  : day.today
                  ? l10n.upNext
                  : null,
              onTap: day.onTap ?? () => onOpenDay?.call(day),
            ),
        // "Change program" with no programme to change is an instruction she
        // cannot follow. The same door, named for what is behind it: the
        // library, which is where a programme would be chosen.
        if (AppRouter.screenIsOn('R01'))
          AppButton(
            hasProgram ? l10n.changeProgram : l10n.allWorkouts,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: onChangeProgram,
          ),
      ],
    );
  }
}
