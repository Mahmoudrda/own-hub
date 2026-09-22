/// B07 — her method, in her own steps.
///
/// *"Coaches sell a method, and every good one already has names for its
/// phases. The builder asks for those names instead of imposing 'Assessment,
/// Programming, Delivery'."* So the two fields on a step carry **no label**:
/// the dictionary has none for them, and a label invented in English would be
/// the product naming her phases after all. Reported rather than filled in.
///
/// The step badge draws Western digits inside Arabic text (P0-A11Y-01), from
/// the array index — there is no `order` field on a step for the number to
/// drift from.
///
/// [MarketingClaimPolicy] runs over both fields. G13 §5 named cover, ad,
/// numbers and testimonial; the owner extended it to `method`, because the
/// sentence that will not fit in a headline fits in step two.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/marketing_claim_policy.dart';
import '../domain/portfolio_block.dart';

/// 1–8 steps (G13 §1.3). The floor is `BlockValidator`'s `tooFew`; the ceiling
/// is here, so the ninth tap does nothing rather than building a block that
/// cannot be published.
const int kMaxMethodSteps = 8;

class MethodEditorView extends StatefulWidget {
  const MethodEditorView({
    super.key,
    required this.payload,
    this.claims = const MarketingClaimPolicy(),
    this.onChanged,
    this.onDone,
    this.onClose,
  });

  final MethodPayload payload;
  final MarketingClaimPolicy claims;

  final ValueChanged<MethodPayload>? onChanged;
  final VoidCallback? onDone;
  final VoidCallback? onClose;

  @override
  State<MethodEditorView> createState() => _MethodEditorViewState();
}

class _MethodEditorViewState extends State<MethodEditorView> {
  late List<MethodStep> _steps;
  final List<TextEditingController> _titles = [];
  final List<TextEditingController> _bodies = [];

  @override
  void initState() {
    super.initState();
    _steps = [...widget.payload.steps];
    for (final step in _steps) {
      _titles.add(TextEditingController(text: step.title));
      _bodies.add(TextEditingController(text: step.body));
    }
  }

  @override
  void dispose() {
    for (final c in _titles) {
      c.dispose();
    }
    for (final c in _bodies) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    setState(() {});
    widget.onChanged?.call(
      MethodPayload(steps: [..._steps], numbered: widget.payload.numbered),
    );
  }

  void _setStep(int i, {String? title, String? body}) {
    _steps[i] = MethodStep(
      title: title ?? _steps[i].title,
      body: body ?? _steps[i].body,
    );
    _emit();
  }

  void _add() {
    if (_steps.length >= kMaxMethodSteps) return;
    _steps.add(const MethodStep(title: '', body: ''));
    _titles.add(TextEditingController());
    _bodies.add(TextEditingController());
    _emit();
  }

  void _remove(int i) {
    _steps.removeAt(i);
    _titles.removeAt(i).dispose();
    _bodies.removeAt(i).dispose();
    _emit();
  }

  String _spans(String text) =>
      widget.claims.check(text).violations.map((v) => v.span).join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.howIWork,
        onBack: widget.onClose,
        leadingIcon: Icons.close,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.done_54ca1,
              height: 38,
              fontSize: 15,
              onPressed: widget.onDone,
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          Text(
            l10n.yourMethodInYourOwnStepsName,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          for (var i = 0; i < _steps.length; i++)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gap: 8,
              children: [
                Row(
                  children: [
                    if (widget.payload.numbered) ...[
                      // Ringed by hand, as the page itself numbers her steps.
                      SizedBox.square(
                        dimension: 30,
                        child: CustomPaint(
                          painter: LoopPainter(
                            seed: handSeed(['method-step', i]),
                            color: AppColors.primary,
                            width: HandStroke.fine,
                            level: HandLevel.crafted,
                            inflate: EdgeInsets.zero,
                            textDirection: Directionality.of(context),
                          ),
                          child: Center(
                            child: Text(
                              // Western digits inside Arabic text, from the
                              // index.
                              '${i + 1}',
                              style: AppText.titleS.copyWith(
                                color: AppColors.primaryDim,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: AppField(
                        controller: _titles[i],
                        errorText: _spans(_steps[i].title),
                        onChanged: (value) => _setStep(i, title: value),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _remove(i),
                      iconSize: 21,
                      color: AppColors.onSurfaceVariant,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                AppField(
                  controller: _bodies[i],
                  errorText: _spans(_steps[i].body),
                  onChanged: (value) => _setStep(i, body: value),
                ),
              ],
            ),
          if (_steps.length < kMaxMethodSteps)
            AppCard(
              variant: AppCardVariant.filled,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              onTap: _add,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.add,
                      size: 22,
                      color: AppColors.primaryDim,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.addAStep,
                        style: AppText.titleS.copyWith(
                          color: AppColors.primaryDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
