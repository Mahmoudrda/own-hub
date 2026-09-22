/// The row of digit boxes on `C07`, matching the local `digitBox()` helper in
/// `6-v2/src/screens-signup.mjs`.
///
/// **The number of boxes is a parameter, never a literal.** `DECISIONS.md` D2a
/// settled the code at six because that is what Firebase phone auth sends and
/// the length is not configurable; the screen passes
/// `kVerificationCodeLength`, so the boxes on screen cannot disagree with the
/// digits the provider sent. That mismatch is what test `P0-VER-08` exists to
/// catch, and a hardcoded `6` here would defeat it just as the old hardcoded `4`
/// did.
///
/// One invisible [TextField] sits over the whole row rather than one field per
/// box. That is not a shortcut — it is the only arrangement that lets the
/// platform fill the code in:
///
///  * iOS offers the code above the keyboard from `AutofillHints.oneTimeCode`
///    and hands over all six digits at once (`P0-VER-03`).
///  * Android's SMS Retriever delivers the whole message, and the last digit
///    self-submits (`P0-VER-02`).
///
/// Neither works against six separate one-character fields, and **neither
/// requires permission to read SMS**. The app must never ask for `READ_SMS` on
/// either platform.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppCodeField extends StatefulWidget {
  const AppCodeField({
    super.key,
    required this.length,
    this.controller,
    this.focusNode,
    this.autofocus = true,
    this.enabled = true,
    this.errorText = '',
    this.onChanged,
    this.onCompleted,
  });

  /// How many digits. Comes from the auth layer, not from the design.
  final int length;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  /// Non-empty puts every box into the error state.
  final String errorText;

  final ValueChanged<String>? onChanged;

  /// Fires the moment the last digit lands — the design's "it checks itself".
  /// She never taps Continue on a successful code.
  final ValueChanged<String>? onCompleted;

  @override
  State<AppCodeField> createState() => _AppCodeFieldState();
}

class _AppCodeFieldState extends State<AppCodeField> {
  TextEditingController? _owned;
  FocusNode? _ownedNode;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  String get _code => _controller.text;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _owned?.dispose();
    _ownedNode?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call(_code);
    if (_code.length == widget.length) widget.onCompleted?.call(_code);
  }

  @override
  Widget build(BuildContext context) {
    final boxes = Row(
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _DigitBox(
              digit: i < _code.length ? _code[i] : '',
              // The next empty box is the one she is filling.
              focused: widget.enabled && i == _code.length,
              error: widget.errorText.isNotEmpty,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            boxes,
            // Transparent rather than zero-opacity: it must still take focus,
            // take input and offer autofill. It carries the caret, which is why
            // the cursor is hidden — the focused box is the caret.
            Positioned.fill(
              child: TextField(
                controller: _controller,
                focusNode: _node,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.transparent, fontSize: 30),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        if (widget.errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              widget.errorText,
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.digit,
    required this.focused,
    required this.error,
  });

  final String digit;
  final bool focused;
  final bool error;

  @override
  Widget build(BuildContext context) {
    // A slot on the page: a faint tint with a line to write on. The slot she
    // is filling is ringed in rose ink; an error rings them all, plainly.
    final frame = error
        ? AppColors.error
        : focused
        ? AppColors.primary
        : null;

    return ConstrainedBox(
      // 68 in the prototype, and a floor rather than a fixed height so a 30px
      // digit at the largest system text size grows the box instead of
      // overflowing it.
      constraints: const BoxConstraints(minHeight: 68),
      child: HandSurface(
        seed: 500 + digit.hashCode + (focused ? 1 : 0),
        fill: AppColors.surfaceLow,
        frame: frame,
        frameWidth: 2,
        level: error ? HandLevel.structural : HandLevel.crafted,
        radius: 5,
        looseCorner: 12,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              digit,
              // Digits stay left-to-right: a code is read in the order it was
              // sent, in either language.
              textDirection: TextDirection.ltr,
              style: AppText.display.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
