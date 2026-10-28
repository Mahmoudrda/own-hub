library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../private_coaching/presentation/desk/desk_model.dart' show tagOf;
import '../domain/payment_models.dart';
import 'payment_text.dart';
import 'status_text.dart';

/// Hands the record's PNG to the phone's share sheet, anchored at [origin],
/// under [fileName].
typedef PaymentRecordSharer = Future<void> Function(
  Uint8List png,
  Rect origin,
  String fileName,
);

/// PAY10: a simple card of a confirmed payment, drawn on the phone and saved
/// or shared through the phone's own share sheet. Nothing is uploaded. Both
/// parties may open it; neither is named, each is a short tag. It is a record,
/// not a tax invoice.
class PaymentRecordView extends StatefulWidget {
  const PaymentRecordView({
    super.key,
    required this.payment,
    this.onShare,
    this.onBack,
  });

  final Payment payment;
  final PaymentRecordSharer? onShare;
  final VoidCallback? onBack;

  @override
  State<PaymentRecordView> createState() => _PaymentRecordViewState();
}

class _PaymentRecordViewState extends State<PaymentRecordView> {
  final GlobalKey _card = GlobalKey();
  final GlobalKey _button = GlobalKey();
  bool _busy = false;

  Future<void> _save() async {
    final share = widget.onShare ?? AppRouter.sharePaymentRecord;
    final boundary =
        _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _busy) return;
    setState(() => _busy = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null || !mounted) return;
      final box = _button.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null || !box.hasSize
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size;
      await share(
        bytes.buffer.asUint8List(),
        origin,
        'own-hub-payment-${widget.payment.reference}.png',
      );
    } catch (_) {
      // A share sheet that could not open costs her nothing she can see.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value, Key key, {bool ltr = true}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Expanded(flex: 2, child: Text(label, style: AppText.bodyM)),
      Expanded(
        flex: 3,
        child: Text(
          value,
          key: key,
          textDirection: ltr ? TextDirection.ltr : null,
          textAlign: TextAlign.start,
          style: AppText.titleM,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final p = widget.payment;
    final when = p.accessStartedAt ?? p.submittedAt ?? p.createdAt;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.paymentRecord,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      footer: [
        KeyedSubtree(
          key: _button,
          child: AppButton(
            l10n.saveOrShare,
            key: const ValueKey('save-record'),
            onPressed: _busy ? null : () => unawaited(_save()),
          ),
        ),
      ],
      children: [
        RepaintBoundary(
          key: _card,
          child: ColoredBox(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppCard(
                children: [
                  Text(l10n.ownHubPaymentRecord, style: AppText.titleL),
                  _row(
                    l10n.amount,
                    egpText(l10n, p.amountPiasters),
                    const ValueKey('rec-amount'),
                  ),
                  _row(
                    l10n.date,
                    when == null
                        ? ''
                        : '${cairoDateTime(when)} ${l10n.cairoTime}',
                    const ValueKey('rec-date'),
                  ),
                  _row(l10n.reference, p.reference, const ValueKey('rec-ref')),
                  _row(
                    l10n.status,
                    statusWord(l10n, p),
                    const ValueKey('rec-status'),
                    ltr: false,
                  ),
                  _row(
                    l10n.client,
                    tagOf(p.clientUid),
                    const ValueKey('rec-client'),
                  ),
                  _row(
                    l10n.coach,
                    tagOf(p.coachUid),
                    const ValueKey('rec-coach'),
                  ),
                  Text(l10n.thisIsAPaymentRecordItIs, style: AppText.bodyM),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
