/// Ending a workout from inside it.
///
/// One control, the same words on every live screen: "End workout". It opens a
/// sheet with the three things she may mean. Finish and save puts away what
/// she has logged and goes to the finish screen; Discard puts the workout away
/// uncounted; Keep going closes the sheet. With nothing logged there is
/// nothing to save, so only Discard and Keep going are offered.
///
/// The back and close buttons of a workout screen come here too once she has
/// logged a set, so leaving by the side door never drops a set she did.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';

enum EndWorkoutChoice { finish, discard, keepGoing }

/// Asks how she wants to end the workout, or null when the sheet was
/// dismissed. [setsLogged] is how many sets are already saved.
Future<EndWorkoutChoice?> showEndWorkoutSheet(
  BuildContext context, {
  required int setsLogged,
}) {
  final l10n = AppL10n.of(context);
  return showAppSheet<EndWorkoutChoice>(
    context: context,
    gap: 12,
    children: [
      Text(l10n.endThisWorkout, style: AppText.titleL),
      Text(
        setsLogged > 0
            ? l10n.setsSavedSoFarCount(countLabel(setsLogged))
            : l10n.nothingIsLoggedYetSoThisWorkout,
        key: const ValueKey('end-sets-line'),
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
      Builder(
        builder: (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (setsLogged > 0) ...[
              AppButton(
                l10n.finishAndSave,
                key: const ValueKey('end-finish'),
                onPressed: () =>
                    Navigator.of(sheet).pop(EndWorkoutChoice.finish),
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              l10n.discardThisWorkout,
              key: const ValueKey('end-discard'),
              variant: AppButtonVariant.outlined,
              onPressed: () =>
                  Navigator.of(sheet).pop(EndWorkoutChoice.discard),
            ),
            const SizedBox(height: 4),
            AppButton(
              l10n.keepGoing,
              key: const ValueKey('end-keep'),
              variant: AppButtonVariant.text,
              height: 48,
              onPressed: () =>
                  Navigator.of(sheet).pop(EndWorkoutChoice.keepGoing),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ],
  );
}

/// What a live workout screen needs to offer the control: how many sets are
/// saved, and what finishing and discarding do. Null on a screen with no live
/// workout behind it, which draws no control.
class SessionEnd {
  const SessionEnd({
    required this.setsLogged,
    required this.onFinish,
    required this.onDiscard,
  });

  final int setsLogged;

  /// Finish and save: only ever called with at least one set logged.
  final VoidCallback onFinish;

  /// Discard: the workout is put away and not counted.
  final VoidCallback onDiscard;

  /// Opens the sheet and carries out her choice.
  Future<void> ask(BuildContext context) async {
    final choice = await showEndWorkoutSheet(context, setsLogged: setsLogged);
    switch (choice) {
      case EndWorkoutChoice.finish when setsLogged > 0:
        onFinish();
      case EndWorkoutChoice.discard:
        onDiscard();
      case _:
        break;
    }
  }
}

/// "End workout", in the top bar of a live workout screen.
class SessionEndButton extends StatelessWidget {
  const SessionEndButton({super.key, required this.end, this.color});

  final SessionEnd end;

  /// The label's colour, for a screen with a dark ground.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return TextButton(
      key: const ValueKey('session-end'),
      onPressed: () => unawaited(end.ask(context)),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Text(
        l10n.endWorkout,
        // A bar has a fixed height and room for one more word at the largest
        // text size, so this label grows only so far.
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
        maxLines: 1,
        style: AppText.label.copyWith(
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A live workout screen's way out. Back and close come to the sheet once she
/// has logged a set, instead of leaving with it unsaved; with [overlay] the
/// control is also drawn at the top end of a screen whose own bar has no room
/// for it.
class SessionEndFrame extends StatelessWidget {
  const SessionEndFrame({
    super.key,
    required this.end,
    required this.child,
    this.overlay = false,
    this.endInset = 8,
    this.guardPop = true,
  });

  final SessionEnd? end;
  final Widget child;

  /// Draws [SessionEndButton] over the top end of [child], in the height of a
  /// workout bar.
  final bool overlay;

  /// Space left at the top end for the screen's own action.
  final double endInset;

  /// Whether Back asks before leaving once a set is logged. A screen that is a
  /// side trip off the set (swap a move, correct a set) leaves freely; the
  /// control it carries still ends the workout.
  final bool guardPop;

  @override
  Widget build(BuildContext context) {
    final end = this.end;
    Widget body = child;
    if (end != null && overlay) {
      body = Stack(
        children: [
          child,
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top,
            end: endInset,
            height: 64,
            child: Center(widthFactor: 1, child: SessionEndButton(end: end)),
          ),
        ],
      );
    }
    final holding = guardPop && end != null && end.setsLogged > 0;
    return SessionEndGuard(
      holding: holding,
      child: PopScope(
        canPop: !holding,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && end != null) unawaited(end.ask(context));
        },
        child: body,
      ),
    );
  }
}

/// Tells the screen inside a [SessionEndFrame] that the frame is already
/// asking how to end the workout when Back is pressed. A screen with a Back
/// question of its own steps aside while this holds, so she is asked one
/// thing at a time.
class SessionEndGuard extends InheritedWidget {
  const SessionEndGuard({
    super.key,
    required this.holding,
    required super.child,
  });

  final bool holding;

  /// True when the nearest frame above [context] holds Back for itself. Safe
  /// to call from a pop callback.
  static bool holdingBack(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionEndGuard>()?.holding ??
      false;

  @override
  bool updateShouldNotify(SessionEndGuard old) => old.holding != holding;
}
