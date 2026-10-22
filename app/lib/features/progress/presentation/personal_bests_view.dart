/// P03 — Personal bests.
///
/// Matches `6-v2/src/screens-progress.mjs` → `P03`. The design note carries the
/// rule: *"Bests are self-relative by design: more reps, more weight, longer
/// holds, harder variations. That is what makes the ladder identical for a
/// first-timer and a fifteen-year lifter — and why recalled sessions are
/// excluded."*
///
/// Rule 11 is safe on this screen for a structural reason worth stating: a best
/// is a comparison with her own past, so there is no other woman in the
/// comparison and nothing to rank her against. The screen shows four kinds of
/// best and no position in any list.
///
/// ## Three of the four kinds can be detected. One cannot.
///
/// `actualHoldSec` is absent from G4's `measuredSets` payload, so "Plank hold ·
/// 45 seconds" cannot be produced from a real session today. G6 §7.3 calls it
/// *"the one request that blocks shipped behaviour."* The detector implements
/// the branch and this screen renders it, so the day the field lands nothing
/// here changes — but nothing populates it yet, and the build report says so.
///
/// ## Every move the product knows has a name
///
/// The four prototype moves keep their dictionary titles. Any other move is
/// named by `ExerciseTraits.nameOf` (the synced library, then the bundled
/// table). A best on a move neither knows has no name to show, so
/// [personalBestRow] returns null and the row is left out. Names are English
/// in both languages.
///
/// ## The delta is computed; the detail line still is not
///
/// "+2 kg", "+3 reps" and "+15 s" used to be three fixed strings holding the
/// mockup's three gains, so a woman who added four kilos saw no delta at all.
/// `nKg`, `nReps` and `nS` are parameterised now, so [_delta] subtracts her
/// previous best from her new one and the trailing figure is always hers.
///
/// The detail line — "12 kg × 10 · 16 September · was 10 kg" — is still a single
/// fixed string carrying four of the mockup's figures, including a date this
/// product has no month vocabulary to build. It stays behind `statedLine`, shown
/// only to the woman all four numbers describe, and it is a reported gap.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/personal_best_detector.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../../train/domain/exercise_traits.dart';
import '../../train/domain/weight_label.dart';
import '../../train/presentation/exercise_labels.dart'
    show MoveName, englishMoveNames;
import '../../train/presentation/set_labels.dart' show measuredLabel;

/// One row of P03, already resolved against the dictionary.
@immutable
class PersonalBestRow {
  const PersonalBestRow({
    required this.title,
    this.detail,
    this.delta,
    this.exerciseId,
  });

  /// The move the best is on, so a row can open that move's history.
  final String? exerciseId;

  /// The exercise's name.
  final String title;

  /// "12 kg × 10 · 16 September · was 10 kg". Null when the dictionary's only
  /// form of this line states numbers that are not hers.
  final String? detail;

  /// "+2 kg". Same rule.
  final String? delta;
}

/// Resolves one best into a row, or null when its move cannot be named.
///
/// The four moves the mockup draws keep their stated detail line, which only
/// reads when every figure on it is hers. Every other move is named from
/// `exercise_traits.dart` (the synced library first, then the bundled table)
/// and its detail line is the figure it was measured on: kilos, reps or
/// seconds. English move names are shown in both languages, fenced left to
/// right by [MoveName].
PersonalBestRow? personalBestRow(AppL10n l10n, PersonalBest best) {
  final delta = _delta(l10n, best);
  final value = _value(l10n, best);

  PersonalBestRow stated(String title, bool applies, String Function() line) =>
      PersonalBestRow(
        title: title,
        detail: applies ? line() : value,
        delta: delta,
        exerciseId: best.exerciseId,
      );

  switch (best.exerciseId) {
    case 'goblet_squat':
      return stated(
        englishMoveNames.gobletSquat,
        _is(best.loadKg, 12) &&
            _is(best.reps, 10) &&
            best.dateKey == '2026-09-16' &&
            _is(best.previous?.loadKg, 10),
        () => l10n.n12Kg1016SeptemberWas10,
      );
    case 'glute_bridge':
      return stated(
        englishMoveNames.gluteBridge,
        _is(best.reps, 15) &&
            best.dateKey == '2026-09-09' &&
            _is(best.previous?.reps, 12),
        () => l10n.n3159SeptemberWas312,
      );
    case 'plank_hold':
      return stated(
        englishMoveNames.plankHold,
        _is(best.holdSec, 45) &&
            best.dateKey == '2026-09-02' &&
            _is(best.previous?.holdSec, 30),
        () => l10n.n45Seconds2SeptemberWas30,
      );
    case 'step_back_lunge':
      return stated(
        englishMoveNames.stepBackLunge,
        best.metric == BestMetric.variation && best.dateKey == '2026-08-26',
        () => l10n.movedToTheHarderVersion26August,
      );
  }

  if (ExerciseTraits.of(best.exerciseId) == null) return null;
  return PersonalBestRow(
    title: ExerciseTraits.nameOf(best.exerciseId),
    detail: value,
    delta: delta,
    exerciseId: best.exerciseId,
  );
}

/// Her figure on the move's own metric: "40 kg × 8", "15 reps", "45 s".
/// Null for a harder-version best, which names no figure.
String? _value(AppL10n l10n, PersonalBest best) => switch (best.metric) {
  BestMetric.load when best.loadKg != null => measuredLabel(
    l10n,
    weightKg: best.loadKg,
    reps: best.reps,
  ),
  BestMetric.reps when best.reps != null => measuredLabel(
    l10n,
    reps: best.reps,
  ),
  BestMetric.hold when best.holdSec != null => measuredLabel(
    l10n,
    holdSeconds: best.holdSec,
  ),
  _ => null,
};

/// Her bests, newest first, at most [limit] of them (all when null). A stable
/// sort on the date, so two bests of one day keep the order they came in. The
/// rows are sorted before they are made, so only the ones shown are resolved.
List<PersonalBestRow> personalBestRows(
  AppL10n l10n,
  Iterable<PersonalBest> bests, {
  int? limit,
}) {
  final all = bests.toList();
  // List.sort is not stable, so the position breaks a tie on the date.
  final order = [for (var i = 0; i < all.length; i++) i]
    ..sort((a, b) {
      final byDate = all[b].dateKey.compareTo(all[a].dateKey);
      return byDate != 0 ? byDate : a.compareTo(b);
    });
  final rows = <PersonalBestRow>[];
  for (final i in order) {
    if (rows.length == limit) break;
    final row = personalBestRow(l10n, all[i]);
    if (row != null) rows.add(row);
  }
  return rows;
}

bool _is(num? value, num expected) => value != null && value == expected;

/// What she gained over her own last best — "+2 kg", "+3 reps", "+15 s".
///
/// Computed, not recited. The dictionary used to offer only `n2Kg`, `n3Reps`
/// and `n15S` — the mockup's three gains — so a woman who added four kilos was
/// shown nothing rather than "+2 kg". `nKg`, `nReps` and `nS` are parameterised,
/// so the line is now hers whatever the gain was.
///
/// Null when there is no previous best to have improved on, or when the figure
/// did not rise: a best that is not an improvement has no delta to name, and
/// "+0 kg" or a negative gain would be a worse answer than silence.
String? _delta(AppL10n l10n, PersonalBest best) {
  // A harder variation names no figure at all, so it is true of any variation
  // best and needs no previous to subtract from.
  if (best.metric == BestMetric.variation) return l10n.levelUp;

  final previous = best.previous;
  if (previous == null) return null;

  return switch (best.metric) {
    BestMetric.load => switch (_gain(best.loadKg, previous.loadKg)) {
      // weightLabel, never NumberFormat: P0-A11Y-01 requires Western digits in
      // Arabic, and it drops the trailing ".0" so a two-kilo gain reads "+2 kg".
      final num kg => l10n.nKg(weightLabel(kg)),
      _ => null,
    },
    BestMetric.reps => switch (_gain(best.reps, previous.reps)) {
      final num reps => l10n.nReps(countLabel(reps.toInt())),
      _ => null,
    },
    BestMetric.hold => switch (_gain(best.holdSec, previous.holdSec)) {
      final num seconds => l10n.nS(countLabel(seconds.toInt())),
      _ => null,
    },
    // Handled above, before the previous best is required.
    BestMetric.variation => null,
  };
}

/// The rise from [before] to [now], or null if it is not a rise.
num? _gain(num? now, num? before) {
  if (now == null || before == null) return null;
  final gain = now - before;
  return gain > 0 ? gain : null;
}

class PersonalBestsView extends StatelessWidget {
  const PersonalBestsView({
    super.key,
    required this.bests,
    this.onBack,
    this.onSelectTab,
    this.onOpenHistory,
  });

  /// Opens the history of one move, given its id. Null draws no button.
  final ValueChanged<String>? onOpenHistory;

  /// Her bests, newest first. Read through `BestsRepository`, which offers no
  /// ordering but by date and no way to ask for anybody else's.
  final List<PersonalBest> bests;

  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // A best on a move the dictionary cannot name resolves to null and drops
    // out here, rather than appearing as a row with an exercise id in it.
    final rows = personalBestRows(l10n, bests);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.personalBests, onBack: onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'P03',
        onSelect: (id) {
          final onTab = onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: rows.isEmpty
            ? [
                AppEmptyState(
                  icon: Icons.emoji_events,
                  art: AppArt.strongArms,
                  title: l10n.nothingSavedYet,
                  body: l10n.measuredAgainstYourOwnHistoryOnlyMore,
                ),
              ]
            : [
                AppSageNote(l10n.measuredAgainstYourOwnHistoryOnlyMore),
                for (final row in rows)
                  AppListItem(
                    leading: const Icon(
                      Icons.emoji_events,
                      size: 24,
                      color: AppColors.amber,
                    ),
                    title: row.title,
                    titleWidget: MoveName(row.title, style: AppText.titleM),
                    subtitle: row.detail ?? '',
                    trailing: row.delta == null
                        ? null
                        : Text(
                            row.delta!,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                    onTap: onOpenHistory == null || row.exerciseId == null
                        ? null
                        : () => onOpenHistory!(row.exerciseId!),
                  ),
                // The rule that keeps a best meaningful, said on the screen
                // where she would otherwise wonder why a session is missing.
                Text(
                  l10n.sessionsYouAddedWithIAlreadyDid,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
      ),
    );
  }
}
