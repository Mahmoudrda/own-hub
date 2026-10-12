/// The two prototype primitives this console needs and `lib/ui/` does not have:
/// `sectionHead()` and `table()`.
///
/// Both are in `6-v2/src/kit.mjs` and neither has a Flutter widget, because no
/// member-facing screen draws a table — staff screens do. Z08 shows the columns
/// a CSV must carry, Z09 lists each failing row against its column, and Z10
/// lists a file against its size. Three tables of two columns each, so they are
/// written once here rather than three times.
///
/// ## Everything in them is data, not copy
///
/// A cell is a column name from [ContentSchema], a file name from an upload, or
/// a line number. `import_check_view.dart` already settled the principle for
/// this feature: "Her own CSV header, echoed back. Data, not copy." The
/// **headers** are the only text here that is copy, and they are passed in from
/// the dictionary by the caller.
///
/// ## Why the grid is a Row of Expanded and not a [Table]
///
/// Flutter's [Table] takes fixed or fractional column widths and does not wrap a
/// cell that outgrows them. At textScale 1.6 under Arabic — which every screen
/// in this product is tested at — a two-word header becomes three lines, and a
/// [Table] row would clip it. `Expanded` with a flex factor reproduces
/// `grid-template-columns: 1.6fr 1fr` and still lets a cell grow taller.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/hand/hand.dart';

/// An action that cannot run, drawn so that it plainly cannot.
///
/// Z08's "Choose a file" and Z10's "Upload" both need a file picker and there is
/// none in `pubspec.yaml`. The house convention for a disabled control is
/// `onPressed: null` — [AppButton] takes it and stops responding — and that is
/// right for "Check the file" before a file is chosen: she can see why, and it
/// will work in a moment. It is wrong here. This control will never work in this
/// build, and one that looks ready and answers nothing is exactly what
/// `id_capture.dart` refuses to ship: "no fake that *works* exists to be
/// mistaken" for the real thing.
///
/// So the state is carried **without copy**: the same word the live control
/// uses, dimmed to Material's disabled opacity, and announced to a screen reader
/// as a disabled button rather than one she can press. There is no "not
/// available yet" string in either dictionary and this feature may not invent
/// one — **the sentence saying why is withheld and reported**, and this is the
/// most the screen can honestly say with the words it has.
class AdminUnavailableAction extends StatelessWidget {
  const AdminUnavailableAction(
    this.label, {
    super.key,
    this.variant = AppButtonVariant.tonal,
  });

  final String label;
  final AppButtonVariant variant;

  /// Material's disabled opacity: legible, and plainly not live.
  static const double disabledOpacity = 0.38;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      // The button underneath announces itself as tappable, and it is not.
      excludeSemantics: true,
      child: Opacity(
        opacity: disabledOpacity,
        // No `onPressed`, so a tap lands on nothing. The dimming is what says
        // so before the tap.
        child: AppButton(label, variant: variant),
      ),
    );
  }
}

/// `sectionHead(title, action)` — 15px semibold, with an optional trailing note.
class AdminSectionHead extends StatelessWidget {
  const AdminSectionHead(this.title, {super.key, this.trailing = ''});

  final String title;

  /// The prototype's `action`. Said only when there is something to say.
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.label.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
        if (trailing.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(
            trailing,
            style: AppText.label.copyWith(
              fontSize: 14,
              color: AppColors.primaryDim,
            ),
          ),
        ],
      ],
    );
  }
}

/// `table(headers, rows, {widths})` — two columns, zebra striped.
///
/// [rows] are records rather than a list of lists so a row with the wrong number
/// of cells cannot be constructed at all.
class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.startHeader,
    required this.endHeader,
    required this.rows,
    this.startFlex = 8,
    this.endFlex = 5,
  });

  final String startHeader;
  final String endHeader;

  /// `(start, end)` per row, in the order they should read.
  final List<(String, String)> rows;

  /// The prototype's `widths`, as flex factors. Directional: `start` is the left
  /// column in English and the right one in Arabic, because the whole row is
  /// laid out by the ambient [Directionality].
  final int startFlex;
  final int endFlex;

  @override
  Widget build(BuildContext context) {
    // A staff table, so printed clean: a structural frame with no hand in it,
    // and the rows inset from it so the zebra never runs past a corner.
    return HandSurface(
      seed: handSeed(['admin-table', startHeader, endHeader]),
      fill: AppColors.surfaceLowest,
      frame: AppColors.outline.withValues(alpha: 0.55),
      frameWidth: 1,
      level: HandLevel.structural,
      radius: 5,
      looseCorner: 12,
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Row(
              start: startHeader,
              end: endHeader,
              startFlex: startFlex,
              endFlex: endFlex,
              background: AppColors.surfaceHigh,
              style: AppText.label.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimaryContainer,
              ),
            ),
            for (var i = 0; i < rows.length; i++)
              _Row(
                start: rows[i].$1,
                end: rows[i].$2,
                startFlex: startFlex,
                endFlex: endFlex,
                // The prototype's zebra, which is what keeps a long list of
                // columns readable across the row.
                background: i.isOdd
                    ? AppColors.surfaceLow
                    : AppColors.surfaceLowest,
                topBorder: true,
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.start,
    required this.end,
    required this.startFlex,
    required this.endFlex,
    required this.background,
    required this.style,
    this.topBorder = false,
  });

  final String start;
  final String end;
  final int startFlex;
  final int endFlex;
  final Color background;
  final TextStyle style;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final row = ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: startFlex,
              child: Text(start, style: style),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: endFlex,
              child: Text(end, style: style),
            ),
          ],
        ),
      ),
    );
    if (!topBorder) return row;

    // An exact hairline between rows, not a pencil rule: this is a ledger,
    // and a drifting line would make two rows look like one.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A row separator, so `outlineVariant` — the decorative hairline —
        // is the right role. Nothing is lost by not seeing it; it is here so
        // two ledger rows do not read as one.
        const ColoredBox(
          color: AppColors.outlineVariant,
          child: SizedBox(height: 1),
        ),
        row,
      ],
    );
  }
}
