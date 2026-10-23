/// The confirmation that is not a confirmation — `snackbar()` in
/// `6-v2/src/kit.mjs`.
///
/// §2 rule 9: logging saves immediately and offers five seconds to take it back.
/// This bar is the visible half of that rule; [LogCommandBus] is the half that
/// makes it true. Note what is absent — there is no "are you sure", no Cancel,
/// and no way to pass this widget a dialog.
///
/// It is drawn **in the page**, not raised as a Material `SnackBar`, because the
/// prototype places it inline above the content and because a floating snackbar
/// would sit over the rest timer it is announcing.
///
/// The text must name the same numbers the button named. If the button said
/// "12 kg × 10", this says "12 kg × 10" — a woman should never have to wonder
/// what she just agreed to.
///
/// A tick is drawn on beside the words (D48): every completed action gets a
/// response she can see.
library;

import 'package:flutter/material.dart';

import '../domain/logging/log_command_bus.dart';
import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppUndoBar extends StatelessWidget {
  const AppUndoBar({
    super.key,
    required this.message,
    required this.undoLabel,
    this.onUndo,
  });

  /// What was saved, in her numbers.
  final String message;

  final String undoLabel;

  /// Null once the five-second window has closed. The bar then reads as a plain
  /// statement of what was saved, which is honest: there is no longer anything
  /// to undo, and offering a button that does nothing is worse than offering none.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return HandSurface(
      seed: handSeed(['undo', message]),
      fill: AppColors.inverseSurface,
      radius: 5,
      looseCorner: 14,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 8, 8),
      child: Row(
        children: [
          // The hand draws the tick as the bar arrives: the save is seen as
          // well as read. Instant under reduced motion.
          const HandTick(
            size: 18,
            color: AppColors.primaryContainer,
            drawOn: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyM.copyWith(color: AppColors.inverseOnSurface),
            ),
          ),
          if (onUndo != null) ...[
            const SizedBox(width: 12),
            // The way back, underlined by hand in blush on the dark bar.
            HandPressable(
              onTap: onUndo,
              scale: 0.95,
              borderRadius: BorderRadius.circular(6),
              builder: (context, _) => Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: HandUnderline(
                  color: AppColors.primaryContainer,
                  level: HandLevel.crafted,
                  width: 1.3,
                  gap: 1,
                  child: Text(
                    undoLabel,
                    style: AppText.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inverseOnSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// [AppUndoBar] for a log whose window is still open, and only while it is.
///
/// The in-page bar on R09 and R13 used to keep Undo drawn for the whole rest,
/// and on R13 for as long as she stayed, while `handle.undo()` had been
/// returning false since the fifth second. Tapping it did nothing at all. The
/// snackbar was fixed for exactly this; this is the same fix for the bar: the
/// handle says when the window shut, and the button goes with it, leaving the
/// statement of what was saved.
///
/// [onUndo] runs only when the undo actually landed.
class AppLiveUndoBar extends StatefulWidget {
  const AppLiveUndoBar({
    super.key,
    required this.handle,
    required this.message,
    required this.undoLabel,
    this.onUndo,
  });

  /// Null draws the plain statement, as a preview with nothing logged does.
  final LogHandle? handle;

  final String message;
  final String undoLabel;
  final VoidCallback? onUndo;

  @override
  State<AppLiveUndoBar> createState() => _AppLiveUndoBarState();
}

class _AppLiveUndoBarState extends State<AppLiveUndoBar> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _watch(widget.handle);
  }

  @override
  void didUpdateWidget(AppLiveUndoBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handle, widget.handle)) _watch(widget.handle);
  }

  void _watch(LogHandle? handle) {
    if (handle == null) {
      _open = false;
      return;
    }
    // Open until told otherwise. `whenClosed` runs at once when the window has
    // already shut, so the flag is set before the first frame in that case.
    _open = true;
    var registering = true;
    handle.whenClosed(() {
      if (!identical(handle, widget.handle)) return;
      if (registering || !mounted) {
        _open = false;
        return;
      }
      setState(() => _open = false);
    });
    registering = false;
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    return AppUndoBar(
      message: widget.message,
      undoLabel: widget.undoLabel,
      onUndo: handle == null || !_open
          ? null
          : () {
              // False when she was a moment late: nothing is rolled back,
              // because by then the write has already been made.
              if (handle.undo()) widget.onUndo?.call();
            },
    );
  }
}
