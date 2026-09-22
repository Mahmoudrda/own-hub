/// `H04` — message her before you decide.
///
/// This is now the first thing every woman does with every coach, because
/// buy-direct is removed. The prototype put a payment form here; the payment
/// form has moved to `H03`, behind an acceptance, and this screen took its
/// place in the order a woman actually moves through.
///
/// ## What it promises, and why the promise is true
///
/// "She pays only once you accept" is on this screen, and nothing on this
/// screen can take money. [EnquiryViewModel.moneyMoved] is a constant `false`
/// that a test asserts, and the repository method this screen calls
/// (`sendEnquiry`) has no price parameter and no payment return type. The
/// sentence is a description of the code rather than a claim about it.
///
/// ## Offline
///
/// An enquiry **queues**, and that is the opposite of a purchase queueing. It
/// is a message with a deterministic id — `{coachUid}__{clientUid}` — so a send
/// retried after a dropped connection lands on the same thread instead of
/// forking it. The bubble is drawn at full opacity with a sync glyph; never
/// greyed out, and never "failed to save" for something that will sync.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/checkout_gate.dart';
import 'coaching_view_models.dart';
import 'coaching_widgets.dart';

class EnquiryView extends StatefulWidget {
  const EnquiryView({
    super.key,
    required this.model,
    this.onBack,
    this.onSend,
    this.onOpenCoaching,
  });

  final EnquiryViewModel model;
  final VoidCallback? onBack;

  /// Called with the text she typed. The caller writes it through the
  /// repository; this screen never touches one.
  final ValueChanged<String>? onSend;

  final VoidCallback? onOpenCoaching;

  @override
  State<EnquiryView> createState() => _EnquiryViewState();
}

class _EnquiryViewState extends State<EnquiryView> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.model.text,
  );
  late EnquiryViewModel _model = widget.model;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EnquiryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) _model = widget.model;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sent = _model.phase != EnquiryPhase.composing;

    return AppScaffold(
      appBar: AppTopBar(
        title: _model.coachName,
        onBack: () => goToScreen(context, 'H02', widget.onBack),
      ),
      footer: [
        if (!sent)
          AppButton(
            l10n.send,
            height: 56,
            onPressed: _model.maySend
                ? () {
                    widget.onSend?.call(_controller.text);
                    setState(() {});
                  }
                : null,
          ),
        if (_model.phase == EnquiryPhase.rejected)
          AppButton(
            l10n.tryAgain,
            variant: AppButtonVariant.outlined,
            height: 46,
            fontSize: 15,
            onPressed: () {
              widget.onSend?.call(_controller.text);
              setState(() {});
            },
          ),
        if (_model.phase == EnquiryPhase.sent ||
            _model.phase == EnquiryPhase.queued)
          AppButton(
            l10n.coaching,
            variant: AppButtonVariant.outlined,
            height: 46,
            fontSize: 15,
            onPressed: () => goToScreen(context, 'H05', widget.onOpenCoaching),
          ),
      ],
      children: [
        // The promise, above the box she types in rather than after she has
        // committed to anything.
        AppCard(
          variant: AppCardVariant.sage,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_open,
                  size: 20,
                  color: AppColors.tertiary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shePaysOnlyOnceYouAccept,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      CoachingNote(l10n.twentyMinutesNoChargeBeforeYouPay),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        if (!sent)
          AppField(
            controller: _controller,
            label: l10n.message,
            hint: l10n.anythingSaraShouldKnowOptional,
            autofocus: false,
            onChanged: (value) =>
                setState(() => _model = _model.withText(value)),
          ),

        switch (_model.phase) {
          // Full opacity, sync glyph, and a sentence that says it will arrive.
          // Never a failure treatment for something that will sync.
          EnquiryPhase.queued => CoachingNotice(
            icon: Icons.cloud_queue,
            text: l10n.savedItWillSyncWhenYouHave,
          ),
          EnquiryPhase.sent => CoachingNotice(
            icon: Icons.check_circle_outline,
            text: l10n.awaitingReply,
          ),
          EnquiryPhase.rejected => CoachingNotice(
            icon: Icons.error_outline,
            text: l10n.thatDidNotSaveTapToTry,
          ),
          EnquiryPhase.composing => _RefusalLine(reason: _model.refusal),
        },

        // Her words, echoed back once sent, so the thread reads as a thread:
        // a sent message on blush, at her side of the page, with its loose
        // corner where the thread's tail would be.
        if (sent && _controller.text.trim().isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: HandSurface(
                seed: handSeed(['sent', _model.coachName]),
                // The tail: the bottom corner on her side of the page.
                looseAt: HandCorner.bottomEnd,
                fill: AppColors.primaryContainer,
                radius: 6,
                looseCorner: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  _controller.text.trim(),
                  style: AppText.body.copyWith(color: AppColors.onSurface),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RefusalLine extends StatelessWidget {
  const _RefusalLine({required this.reason});

  final EnquiryRefusal? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = switch (reason) {
      EnquiryRefusal.notVerified => l10n.browseMessageWhenYouAreVerified,
      EnquiryRefusal.alreadyInTouch => l10n.awaitingReply,
      // Nothing typed yet is not a refusal worth a sentence; the button is
      // simply not active.
      EnquiryRefusal.empty => null,
      EnquiryRefusal.coachNotAccepting => null,
      EnquiryRefusal.marketplaceOff => null,
      null => null,
    };
    if (text == null) return const SizedBox.shrink();
    return CoachingNotice(icon: Icons.info_outline, text: text);
  }
}
