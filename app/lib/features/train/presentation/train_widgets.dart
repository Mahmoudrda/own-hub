/// The two local helpers at the top of `6-v2/src/screens-train.mjs`, translated.
///
/// The design file defines `moveRow()` and `setRow()` inline because they appear
/// on six screens between them and must stay identical across all six. They are
/// feature-local rather than `lib/ui/` primitives for the same reason they are
/// local in the prototype: a move row and a set row are Train's vocabulary, not
/// the product's.
///
/// Both carry the same idea — a hollow ring is something not done yet, a filled
/// tick is something done. Shape, not colour alone.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart'
    show handCardLook, handLooseRadius, handTightRadius;
// AppCardVariant comes through app_list_item.dart, which re-exports it.
import '../../../ui/app_chevron.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/hand/hand.dart';

/// A move in the day's list. `moveRow()`.
class MoveRow extends StatelessWidget {
  const MoveRow({
    super.key,
    required this.name,
    required this.detail,
    this.done = false,
    this.current = false,
    this.onTap,
  });

  final String name;
  final String detail;

  /// Logged. Struck off the list, and it stays struck off.
  final bool done;

  /// The move she is on now.
  final bool current;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: name,
      subtitle: detail,
      variant: current ? AppCardVariant.selected : AppCardVariant.outlined,
      onTap: onTap,
      // The done icon is ringed in pencil by the row; the open loop sits in a
      // box the same width, so every move name starts on the same line.
      leading: done
          ? const Icon(Icons.check_circle, size: 26, color: AppColors.tertiary)
          : SizedBox.square(
              dimension: 40,
              child: Center(
                child: _Ring(
                  size: 26,
                  active: current,
                  seed: handSeed(['move', name]),
                ),
              ),
            ),
      // Forward, which is leftward in Arabic. [AppChevron] resolves that from
      // the ambient Directionality rather than leaving it to a flag on a
      // Material constant that no test here asserts.
      trailing: const AppChevron(),
    );
  }
}

/// One set within the move she is on. `setRow()`.
///
/// The value it shows is the **prescription** — what she was asked to lift —
/// until she logs, at which point it shows what she did. The two are never the
/// same field: see `domain/training/prescribed_set.dart`.
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.label,
    required this.value,
    this.done = false,
    this.current = false,
  });

  final String label;
  final String value;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    // The same families the cards use, so a set reads like the rest of the
    // page: a logged set is a slip of sage, the set she is on is ringed in
    // ink, and the ones still to come are framed in pencil.
    final look = handCardLook(
      done
          ? AppCardVariant.sage
          : current
          ? AppCardVariant.selected
          : AppCardVariant.outlined,
    );

    return HandSurface(
      seed: handSeed(['set', label]),
      fill: look.fill,
      frame: look.frame,
      frameWidth: look.frameWidth,
      level: look.level,
      radius: handTightRadius(AppRadius.md),
      looseCorner: handLooseRadius(AppRadius.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ConstrainedBox(
        // 52 overall, as before, less the vertical padding.
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            done
                ? const Icon(
                    Icons.check_circle,
                    size: 22,
                    color: AppColors.tertiary,
                  )
                : _Ring(
                    size: 22,
                    active: current,
                    seed: handSeed(['set-ring', label]),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppText.label.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Her figures shrink to fit rather than overflow at the largest
            // text size; they are never wrapped across two lines.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppText.label.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: done
                        ? AppColors.onTertiaryContainer
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A top bar that can close rather than go back.
///
/// R04, R07, R08 and R09 all lead with a **close** cross, not a back arrow, and
/// the difference is meaningful: those screens sit *over* the workout rather than
/// after it, so closing returns her to the list she came from.
///
/// Shared [AppTopBar] offers only the arrow today. This is a feature-local bar
/// rather than a parameter on that one because four groups are building on
/// `app_scaffold.dart` at once, and a shared widget is the worst place for two of
/// them to meet — the same reasoning `app_white_button.dart` records. **Fold the
/// `leading` choice into [AppTopBar] once that work has landed.**
class TrainTopBar extends StatelessWidget implements PreferredSizeWidget {
  const TrainTopBar({
    super.key,
    this.title = '',
    this.onClose,
    this.closeIcon = Icons.close,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onClose;

  /// [Icons.close] for a screen drawn over the workout, [Icons.arrow_back] for
  /// one that genuinely has a previous page.
  final IconData closeIcon;

  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 4,
      leading: onClose == null
          ? const SizedBox(width: 8)
          : IconButton(
              onPressed: onClose,
              iconSize: 24,
              color: AppColors.onSurface,
              // Named for a screen reader, in her language, by the platform's
              // own words for it — the same treatment `AppTopBar` gives its
              // back arrow. This one announced nothing at all, and on R07 it
              // is the only way out of a live session.
              tooltip: closeIcon == Icons.close
                  ? MaterialLocalizations.of(context).closeButtonTooltip
                  : MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(closeIcon),
            ),
      title: title.isEmpty
          ? null
          : Text(
              title,
              style: AppText.titleM.copyWith(color: AppColors.onSurface),
            ),
      actions: actions,
    );
  }
}

/// The hollow ring that means "not done yet".
///
/// Drawn rather than stroked: a pencil loop waiting for its tick, or a loop in
/// rose ink round the one she is on — the same marks the week is kept in.
class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.active, this.seed = 0});

  final double size;
  final bool active;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: LoopPainter(
          seed: seed,
          color: active
              ? HandInk.ink
              : AppColors.outline.withValues(alpha: 0.8),
          width: active ? HandStroke.pen : 1.2,
          level: HandLevel.crafted,
          inflate: const EdgeInsets.all(-2),
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}
