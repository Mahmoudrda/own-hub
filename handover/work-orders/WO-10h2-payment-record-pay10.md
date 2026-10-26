# WO-10h2: PAY10, save or share the payment record
Depends on: WO-10e5, WO-10g (the menu helper `_payMenu`)
Size: M
Reads first: `app/lib/features/progress/presentation/share_progress_view.dart` lines 93-175 (RepaintBoundary to PNG to share); `app/lib/routing/app_router.dart` lines 6458-6475 (`shareProgressCard`); `app/lib/features/instapay/presentation/status_view.dart`; spec 4.16

## Why
She may need a record of what she paid: amount, date, coach, reference, status. It is drawn on the phone as a picture and saved or shared through the phone's own share sheet. Nothing is uploaded. It says plainly that it is not a tax invoice; the coach issues her own invoice if one is needed.

## Final result
PAY3's "..." menu gets "Save payment record" / "احفظي سجل الدفع" (for any payment that is not `awaiting_payment`, `expired` or `cancelled`). It opens PAY10, top to bottom:
1. Top bar "Payment record", back arrow.
2. The record card (this exact picture is what is saved), inside a `RepaintBoundary`: title "Own Hub payment record" / "سجل دفع Own Hub"; rows "Amount  500.37 EGP"; "Date  27/10/2026 14:32 (Cairo time)" / "(بتوقيت القاهرة)"; "Coach  Rahma M."; "Reference  OH-4821"; "Status  Confirmed"; footnote "This is a record of your payment. It is not a tax invoice." / "ده سجل لدفعك. مش فاتورة ضريبية." Western digits in both languages.
3. Footer, the one primary: "Save" / "احفظي". It opens the phone's share sheet with the PNG named `own-hub-payment-OH-4821.png`.
Controls above the fold: back arrow = 1 other + 1 primary.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/presentation/payment_record_view.dart | create | PAY10 |
| app/lib/routing/app_router.dart | edit | menu item in `_payMenu` and the sharer |
| app/test/features/instapay/payment_record_view_test.dart | create | tests |

## Steps
1. File `payment_record_view.dart` (create). The coach's name comes from the address snapshot (`address.accountName`, which is how her bank shows her). Full content:
```dart
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/instapay_models.dart';
import 'status_text.dart';

typedef RecordSharer = Future<void> Function(Uint8List png, Rect origin, String fileName);

class PaymentRecordView extends StatefulWidget {
  const PaymentRecordView({super.key, required this.payment, required this.onShare, this.onBack});
  final Payment payment;
  final RecordSharer onShare;
  final VoidCallback? onBack;

  @override
  State<PaymentRecordView> createState() => _PaymentRecordViewState();
}

class _PaymentRecordViewState extends State<PaymentRecordView> {
  final GlobalKey _card = GlobalKey();
  final GlobalKey _button = GlobalKey();
  bool _busy = false;

  Future<void> _save() async {
    final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _busy) return;
    setState(() => _busy = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null || !mounted) return;
      final box = _button.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null || !box.hasSize ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
      await widget.onShare(data.buffer.asUint8List(), origin, 'own-hub-payment-${widget.payment.reference}.png');
    } catch (_) {
      // A share sheet that could not open costs her nothing she can see.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = widget.payment;
    final when = p.submittedAt ?? p.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    String date() {
      if (when == null) return '';
      final c = cairoTime(when);
      return '${two(c.day)}/${two(c.month)}/${c.year} ${two(c.hour)}:${two(c.minute)}';
    }

    Widget row(String k, String v, {Key? key}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: Text(k, style: AppText.bodyM)),
        Expanded(child: Text(v, key: key, style: AppText.titleM)),
      ],
    );

    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(title: l10n.paymentRecord, onBack: widget.onBack ?? () => Navigator.of(context).maybePop()),
      children: [
        RepaintBoundary(
          key: _card,
          child: AppCard(variant: AppCardVariant.filled, children: [
            Text(l10n.ownHubPaymentRecord, style: AppText.titleL),
            row(l10n.amount, egpText(p.amountPiasters, arabic: arabic), key: const ValueKey('rec-amount')),
            row(l10n.date, '${date()} ${l10n.cairoTimeNote}', key: const ValueKey('rec-date')),
            row(l10n.coach, p.address.accountName),
            row(l10n.reference, p.reference, key: const ValueKey('rec-ref')),
            row(l10n.status, statusWord(l10n, p.status)),
            Text(l10n.thisIsARecordOfYourPaymentItIsNotATaxInvoice, style: AppText.bodyM),
          ]),
        ),
      ],
      footer: [
        KeyedSubtree(
          key: _button,
          child: AppButton(l10n.save, key: const ValueKey('save-record'), onPressed: _busy ? null : () => unawaited(_save())),
        ),
      ],
    );
  }
}
```
2. File `app_router.dart`. Add a static sharer beside `shareProgressCard`:
```dart
  /// The payment record picture (PAY10) to the phone's share sheet. Nothing is uploaded.
  static Future<void> sharePaymentRecord(Uint8List png, Rect origin, String fileName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin == Rect.zero ? null : origin,
      ),
    );
  }
```
In `_payMenu` (WO-10g step 6) add as the last item:
```dart
      if (p.status != PaymentStatus.awaitingPayment && p.status != PaymentStatus.expired && p.status != PaymentStatus.cancelled)
        AppOverflowItem(
          icon: Icons.download_outlined,
          label: l10n.savePaymentRecord,
          onTap: () => unawaited(Navigator.of(context).push<void>(MaterialPageRoute<void>(
            builder: (_) => PaymentRecordView(payment: p, onShare: sharePaymentRecord)))),
        ),
```
and the import of `payment_record_view.dart`.

## Strings to add
File `app/tool/_wo10h2_strings.json`; drop existing keys (`Amount`, `Reference`, `Save`, `Date`, `Coach`, `Status` likely exist).
| English (key) | Egyptian Arabic |
|---|---|
| Save payment record | احفظي سجل الدفع |
| Payment record | سجل الدفع |
| Own Hub payment record | سجل دفع Own Hub |
| (Cairo time) | (بتوقيت القاهرة) |
| This is a record of your payment. It is not a tax invoice. | ده سجل لدفعك. مش فاتورة ضريبية. |
| Date | التاريخ |
| Coach | المدرّبة |
| Status | الحالة |

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| payment_record_view_test.dart | `the record shows amount, date, coach, reference and status` | payment fixture; keys `rec-amount`, `rec-date`, `rec-ref`; the not-an-invoice sentence |
| same | `Save renders a PNG and hands it to the sharer with the file name` | `tester.runAsync`; fake `onShare` records bytes (first 4 bytes `89 50 4E 47`) and the name `own-hub-payment-OH-4821.png` |
| same | `Arabic shows جنيه and Western digits` | `500.37 جنيه` present; no Arabic-Indic digit anywhere (`RegExp(r'[٠-٩]')` finds none in all `Text` data) |
| same | `no phone number or client name is drawn` | the text of the tree has none of the client uid or `+20` |
| same | `the menu hides the record for awaiting_payment, expired, cancelled` | via `AppRouter`-like `menuFor` test helper from WO-10g |
| same | `budget` | `<= 5` others, one primary, both sizes, EN and AR, 200 percent |
Run: `cd app && flutter test test/features/instapay/payment_record_view_test.dart`

## Verify
- `cd app && dart analyze lib/features/instapay lib/routing/app_router.dart` ends `No issues found!`; the test ends `All tests passed!`
- Android emulator: open a confirmed payment, Save, the share sheet shows a PNG that reads correctly in Arabic.

## Do not
- Do not call this an invoice or a receipt for tax. Do not upload the picture. Do not add the client's phone, uid or the coach's phone.
- No em dashes.

## Done checklist
- [ ] PAY10, sharer, menu item, strings, tests

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10i1).

UNVERIFIED in this order: 0.
