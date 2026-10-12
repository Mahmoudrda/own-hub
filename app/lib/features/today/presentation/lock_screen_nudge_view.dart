/// T03 — From the lock screen.
///
/// Matches `6-v2/src/screens-today.mjs` → `T03`. One nudge a day at most, at the
/// hour she usually logs, and only for a meal she has had three times or more.
/// The button logs it without opening the app.
///
/// What this widget is: the **in-app rendering** of that notification, which is
/// what the design draws and what QA reviews. The real surface is a
/// `NotificationCompat.Action` on Android and a Notification Content Extension
/// on iOS, and neither of those is a Flutter widget. The platform work is
/// specified in plan G3 §4.2 — including that the iOS extension must never write
/// Firestore directly, because it is a separate sandbox and would fork the local
/// cache.
///
/// Logging from here obeys §2 rule 9 like everywhere else: it saves, then offers
/// undo. It does not ask her to confirm a meal she has eaten three times.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/today_day.dart';
import '../domain/today_repository.dart';
import 'today_cards.dart';

class LockScreenNudgeView extends StatefulWidget {
  const LockScreenNudgeView({
    super.key,
    this.repository,
    this.bus,
    this.at,
    this.mealLine,
    this.onLogged,
    this.onSomethingElse,
  });

  /// The brand tile C01 shows, bundled at 1x, 2x and 3x.
  static const String appIconAsset = 'assets/brand/logo/ownhub-tile.png';

  final TodayRepository? repository;
  final LogCommandBus? bus;

  /// The moment on the clock face. Injectable so the screen can be reviewed at a
  /// fixed time rather than at whatever time the reviewer opens it.
  final DateTime? at;

  /// The meal the nudge is about, already written — "Ful and baladi · 410 kcal
  /// · 22 g protein" for the woman whose usual breakfast that is.
  ///
  /// Null renders no line. Built by the caller through
  /// `kcalKcalProteinGProtein` from her own rollup; there is nothing this
  /// screen could compute it from.
  final String? mealLine;

  final VoidCallback? onLogged;
  final VoidCallback? onSomethingElse;

  @override
  State<LockScreenNudgeView> createState() => _LockScreenNudgeViewState();
}

class _LockScreenNudgeViewState extends State<LockScreenNudgeView> {
  late final TodayRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryTodayRepository();
    _ownsBus = widget.bus == null;
    _bus = widget.bus ?? LogCommandBus();
  }

  @override
  void dispose() {
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  void _log() {
    final l10n = AppL10n.of(context);
    final handle = _bus.submit(
      UndoableLog(
        // Names the meal when the caller has said what it is, and otherwise
        // says only that food was logged. It used to name the prototype's
        // breakfast and its macros whatever the nudge had actually offered.
        describe: widget.mealLine ?? l10n.mealAdded,
        // The meal itself belongs to the Eat group; T03 owns the tap, not the
        // collection. Until that command exists this marks the arc step, which is
        // G3's own document.
        commit: () => _repo.completeStep(FirstWeekStep.logMeal),
      ),
    );
    showUndoSnackBar(context, handle: handle, undoLabel: l10n.undo);
    openScreen(context, 'T01', widget.onLogged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Now, not the mockup's 15 September 2026 at 08:42. A lock screen that
    // states a date is stating the date it is being read on, or it is stating
    // nothing.
    final at = widget.at ?? AppClock.now();
    final white = AppColors.onPrimary;

    return AppScaffold(
      backgroundColor: AppColors.ink,
      scrollable: false,
      children: [
        Text(
          // The day from the clock this screen is already reading, not a date
          // from the mockup.
          //
          // This was `tuesday16September`, a fixed string, so the lock screen
          // showed 16 September for ever while the time beside it — which comes
          // off `at` — moved. There is no month vocabulary in this dictionary
          // (see `personal_bests_view.dart`), so the day name is said and the
          // date is not.
          weekdayLabel(l10n, at),
          textAlign: TextAlign.center,
          style: AppText.titleM.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: white.withValues(alpha: 0.85),
          ),
        ),
        Text(
          timeLabel(context, at),
          textAlign: TextAlign.center,
          style: AppText.display.copyWith(
            fontSize: 82,
            height: 92 / 82,
            letterSpacing: -1.6,
            color: white,
          ),
        ),
        const AppSpacer(),
        AppCard(
          gap: 8,
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              children: [
                // Where a notification draws the app's icon: the same brand
                // tile C01 shows, at 28 px with the tile's own corner ratio
                // (28 on 88). Decorative, because the name is beside it.
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    LockScreenNudgeView.appIconAsset,
                    width: 28,
                    height: 28,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 8),
                // The application's name, a proper noun and not translated,
                // as on C01.
                Expanded(
                  child: Text(
                    'Own Hub',
                    style: AppText.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  l10n.now,
                  style: AppText.nav.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // The meal the hour actually is, not a fixed breakfast.
            //
            // This was `breakfastYourUsual_1lb0u` for every nudge at every
            // hour, so a woman whose usual log is at seven in the evening was
            // asked "Breakfast, your usual?" over her dinner. Same defect as
            // Home's meal card, fixed on T01, T02 and E04 and missed here.
            // The hour goes through `EatDayViewModel.slotAt` like everywhere
            // else, so this screen and Eat can never disagree about which meal
            // five in the afternoon is.
            //
            // "Your usual" is earned, not assumed: it is a claim about a habit,
            // and `mealLine` is the caller saying which habit. Null means
            // nobody named one, and then the heading names the meal and stops.
            Text(
              mealNudgeHeading(
                l10n,
                now: at,
                hasUsual: widget.mealLine != null,
              ),
              style: AppText.titleM,
            ),
            // The meal's own figures, when a caller supplies them.
            //
            // This was `fulAndBaladi410Kcal22G` — "Ful and baladi · 410 kcal ·
            // 22 g protein" — and the nudge only fires "for a meal she has had
            // three times or more", so the one line that had to be hers was the
            // prototype's. The same string was handed to the undo bar, which
            // then confirmed a meal she had not logged.
            if (widget.mealLine != null)
              Text(
                widget.mealLine!,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    l10n.addIt,
                    height: 48,
                    fontSize: 15,
                    onPressed: _log,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    l10n.somethingElse,
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    fontSize: 15,
                    onPressed: () =>
                        openScreen(context, 'E02', widget.onSomethingElse),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
