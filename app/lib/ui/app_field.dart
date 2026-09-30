/// A text field, matching `field()` in `6-v2/src/kit.mjs`.
///
/// 60 high on a faint tint, with a pencil line under it. Focus draws that
/// line again in rose ink, the pen coming down where she is writing; an error
/// makes it a straight 2px error line — a problem is stated plainly, not
/// sketched. The optional label sits *inside* the field above the
/// value, which is the prototype's shape rather than Material's floating label.
///
/// The one departure from the prototype's fixed 60px: the height is a
/// **minimum**, not a fixed value. At the largest system text size a 17px value
/// over a 12px label does not fit in 60 points, and a fixed height would clip
/// her own phone number rather than grow.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';
import 'hand/hand_geometry.dart' show wobblyLine;
import 'hand/hand_painters.dart' show paintInk, paintPencil, strokePrefix;

class AppField extends StatefulWidget {
  const AppField({
    super.key,
    this.controller,
    this.focusNode,
    this.label = '',
    this.hint = '',
    this.helper = '',
    this.errorText = '',
    this.keyboardType,
    this.textInputAction,
    this.textDirection,
    this.autofillHints,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Sits inside the field, above the value.
  final String label;
  final String hint;

  /// A line below the field. Replaced by [errorText] when that is set.
  final String helper;

  /// Non-empty means the field is in its error state.
  final String errorText;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Forced for content that is always one direction regardless of the app's
  /// language — a phone number stays left-to-right in Arabic.
  final TextDirection? textDirection;

  /// Passed straight through to the platform. `C07` depends on this: iOS offers
  /// the SMS code above the keyboard from `AutofillHints.oneTimeCode`, and the
  /// app must never ask for permission to read SMS on either platform.
  final Iterable<String>? autofillHints;

  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  FocusNode? _ownedNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChanged);
    _ownedNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText.isNotEmpty;
    final labelColour = hasError
        ? AppColors.error
        : _focused
        ? AppColors.primaryDim
        : AppColors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: DrawOn(
            replayKey: _focused,
            duration: HandMotion.settle,
            builder: (context, progress) => CustomPaint(
              foregroundPainter: _FieldLinePainter(
                focused: _focused,
                error: hasError,
                progress: progress,
                textDirection: Directionality.of(context),
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.label.isNotEmpty)
                              Text(
                                widget.label,
                                style: AppText.label.copyWith(
                                  fontSize: 12,
                                  color: labelColour,
                                ),
                              ),
                            // NAMED EVEN AFTER SHE HAS TYPED IN IT.
                            //
                            // `InputDecoration.collapsed` gives the field its
                            // hint and nothing else, and Flutter drops the
                            // hint's semantics the moment there is a value. So
                            // every field in this app announced itself as an
                            // empty tappable as soon as a woman used it: R3-02
                            // caught it on E02, where the sweep types before it
                            // sweeps, and the same thing was true of the phone
                            // number, the code, the search and the note.
                            //
                            // `MergeSemantics` folds the annotation into the
                            // field's own node, so it keeps its value, its
                            // actions and its text-field flag and gains a name.
                            // `trailing` is a sibling of this Column, not a
                            // child, so the mic and the clear button keep their
                            // own nodes.
                            MergeSemantics(
                              child: Semantics(
                                label: widget.label.isNotEmpty
                                    ? widget.label
                                    : widget.hint,
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: _node,
                                  autofocus: widget.autofocus,
                                  keyboardType: widget.keyboardType,
                                  // Declared since this widget was written and never
                                  // passed on, so it was inert for EVERY caller.
                                  //
                                  // Its own doc comment names the case it was failing:
                                  // "a phone number stays left-to-right in Arabic".
                                  // C06 asks for exactly that and did not get it, and
                                  // Z05 needs the same for an English name beside an
                                  // Arabic one.
                                  textDirection: widget.textDirection,
                                  textInputAction: widget.textInputAction,
                                  autofillHints: widget.autofillHints,
                                  onChanged: widget.onChanged,
                                  onSubmitted: widget.onSubmitted,
                                  style: AppText.body.copyWith(
                                    fontSize: 17,
                                    color: AppColors.onSurface,
                                  ),
                                  cursorColor: AppColors.primary,
                                  decoration: InputDecoration.collapsed(
                                    hintText: widget.hint,
                                    hintStyle: AppText.body.copyWith(
                                      fontSize: 17,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 10),
                        widget.trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError || widget.helper.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              hasError ? widget.errorText : widget.helper,
              style: AppText.bodyM.copyWith(
                color: hasError ? AppColors.error : AppColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The line under a field: pencil at rest, rose ink drawn on at focus, and a
/// plain error line when something is wrong.
class _FieldLinePainter extends CustomPainter {
  _FieldLinePainter({
    required this.focused,
    required this.error,
    required this.progress,
    required this.textDirection,
  });

  final bool focused;
  final bool error;
  final double progress;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 1;
    if (error) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = AppColors.error
          ..strokeWidth = 2,
      );
      return;
    }
    final rtl = textDirection == TextDirection.rtl;
    final a = Offset(rtl ? size.width : 0, y);
    final b = Offset(rtl ? 0 : size.width, y);
    final steps = (size.width / 12).round().clamp(8, 60);
    paintPencil(
      canvas,
      wobblyLine(a, b, seed: 41, wobble: 0.35, steps: steps),
      color: AppColors.outline,
      width: 1,
      seed: 41,
    );
    if (!focused) return;
    paintInk(
      canvas,
      strokePrefix(
        wobblyLine(a, b, seed: 42, wobble: 0.7, overshootEnd: 3, steps: steps),
        progress,
      ),
      color: AppColors.primary,
      width: HandStroke.pen + 0.3,
      taper: 0.3,
      seed: 42,
    );
  }

  @override
  bool shouldRepaint(_FieldLinePainter old) =>
      old.focused != focused ||
      old.error != error ||
      old.progress != progress ||
      old.textDirection != textDirection;
}
