/// O05 — Your starting programme.
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O05`. The four questions come
/// back as a named programme with her days already set, so the answers visibly
/// paid for something. One primary button — start now — and the alternatives are
/// real choices rather than a dead end.
///
/// # The programme content does not exist yet
///
/// The card describes a programme nobody has authored (G2 §9 Q8). See
/// `../domain/starting_program.dart`: the catalogue is modelled as data with a
/// `TODO(owner)`, holds one entry, and contains no invented exercises, sets or
/// loads. This screen renders the copy the dictionary already has for that one
/// programme and renders **no card at all** for a programme it has no copy for,
/// rather than inventing a name for it.
///
/// # "Pick a different program" goes to the Workout library
///
/// The design routes it to `R11` (`screens-onboarding.mjs:37`), which the screen
/// inventory names **"Workout library"** — 124 videos with filters, not a
/// programme picker. G2 §9 Q4 flags this as an open question: there is no
/// programme-picker screen anywhere in the 161. Implemented as designed, wired
/// by the router, and reported rather than quietly repointed — repointing it at
/// `R02` would mean changing programme requires re-running setup, which is a
/// product decision and not one a screen should take on its own.
///
/// # Two fixed strings that should be about her
///
/// The headline ("Three days a week, 15 minutes, at home") and the week line
/// ("Your week: Monday, Tuesday and Thursday") are single dictionary entries, not
/// templates. A woman who chose four days and twenty minutes at the gym is shown
/// the same sentence. Rendered as the design and the dictionary have them, and
/// reported: making them true needs new parameterised strings in both languages,
/// which is a translation change and not a code change.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import '../domain/starting_program.dart';

/// The copy for one programme. Held together so a programme can never render a
/// title from one entry and a description from another.
typedef _ProgramCopy = ({String title, String detail, String firstWeek});

class StartingProgramView extends StatelessWidget {
  const StartingProgramView({
    super.key,
    required this.repository,
    this.catalogue = kStartingProgramCatalogue,
    this.onStartNow,
    this.onStartTomorrow,
    this.onPickDifferentProgram,
  });

  final IntakeRepository repository;

  /// Injectable, so the real catalogue replaces this one without touching the
  /// screen — and so a test can prove the card comes from data.
  final List<StartingProgram> catalogue;

  /// `R03` — into day one, now.
  final VoidCallback? onStartNow;

  /// `T06` — Home, day one.
  final VoidCallback? onStartTomorrow;

  /// `R11` — the Workout library. See the note at the top of this file.
  final VoidCallback? onPickDifferentProgram;

  /// The line that reads her four answers back to her.
  ///
  /// This was the single dictionary entry "Three days a week, 15 minutes, at
  /// home", printed under the words "Built from your four answers" to every
  /// woman who finished setup. A woman who chose four days and twenty minutes
  /// at a gym was told, on the screen whose entire job is to prove her answers
  /// counted, that she had chosen something else.
  ///
  /// One string per place rather than a place inserted into a sentence: Arabic
  /// puts "في المنزل" and "في نادٍ للسيدات" in a sentence that has to agree with
  /// them, and a template with a noun dropped into it reads as machine
  /// translation. The numbers are placeholders in both languages and stay
  /// Western digits (`P0-A11Y-01`).
  String _herAnswers(AppL10n l10n, Intake intake) {
    final days = '${intake.days}';
    final minutes = '${intake.minutes}';
    return switch (intake.place) {
      TrainingPlace.home => l10n.daysAWeekDaysMinutesASession(days, minutes),
      TrainingPlace.ladiesGym => l10n.daysAWeekDaysMinutesASession_1qm7e(
        days,
        minutes,
      ),
      TrainingPlace.both => l10n.daysAWeekDaysMinutesASession_1cc8s(
        days,
        minutes,
      ),
    };
  }

  /// Dictionary copy for a programme id, or null when none has been written.
  ///
  /// TODO(owner): extend this with the authored catalogue. A programme with no
  /// copy renders no card, which is visibly incomplete — the deliberate
  /// alternative to showing her an English id or an invented name.
  _ProgramCopy? _copyFor(AppL10n l10n, String programId) {
    switch (programId) {
      case 'beginner_foundations':
        return (
          title: l10n.beginnerFoundations,
          detail: l10n.n8WeeksQuietNoEquipment,
          firstWeek: l10n.week1StartsWithFourMovesOn,
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final Intake intake = repository.read();
    final program = selectStartingProgram(intake, catalogue: catalogue);
    final copy = program == null ? null : _copyFor(l10n, program.programId);

    return AppScaffold(
      footer: [
        AppButton(
          l10n.startDay1Now,
          icon: Icons.play_arrow,
          onPressed: onStartNow,
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.iWillStartTomorrow,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: onStartTomorrow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                l10n.pickADifferentProgram,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: onPickDifferentProgram,
              ),
            ),
          ],
        ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.builtFromYourFourAnswers,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            // Her answers read back, at section scale under the small kicker.
            Text(
              _herAnswers(l10n, intake),
              style: EditorialType.section.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
        if (copy != null)
          AppCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The programme is the page's one object, so its
                        // name is the one thing marked.
                        MarkerHighlight(
                          drawOn: true,
                          delay: const Duration(milliseconds: 240),
                          child: Text(
                            copy.title,
                            textWidthBasis: TextWidthBasis.longestLine,
                            style: AppText.titleL,
                          ),
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
                  const Icon(
                    Icons.workspace_premium,
                    size: 28,
                    color: AppColors.primaryDim,
                  ),
                ],
              ),
              // The prototype had a still here, labelled "coach demo still" in
              // a monospace face: a designer's annotation marking what goes in
              // the slot, like "logotype" on C01. There is no still to put in
              // it, and an empty media block with a play button on the last
              // screen of setup is a control that plays nothing, on the screen
              // that hands her into the app. It comes back with the asset.
              Text(
                copy.firstWeek,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        AppCard(
          variant: AppCardVariant.sage,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 24,
                  color: AppColors.tertiary,
                ),
                const SizedBox(width: 10),
                // "Your week: Monday, Tuesday and Thursday. Change any day by
                // tapping it." was false twice over. Nothing in this product
                // schedules a weekday, so there were no days to change and no
                // tap that changed one; and §2 rule 3 is that this app counts
                // weeks and never days, so naming three of them on the last
                // screen of setup taught her the opposite of how her week is
                // scored. What the card says now is the rule that actually
                // governs it.
                Expanded(
                  child: Text(
                    l10n.yourWeekCountsWhenYouFinishYour,
                    style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
