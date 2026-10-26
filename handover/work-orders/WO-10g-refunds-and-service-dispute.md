# WO-10g: PAY8, refund request, service problem, and the coach's refund record
Depends on: WO-10e5, WO-10f1
Size: L
Reads first: `app/lib/features/instapay/presentation/status_view.dart`; `app/lib/features/instapay/presentation/coach_payments_view.dart`; `app/lib/features/instapay/presentation/client_paid_sheet.dart` (the sheet pattern); `app/lib/ui/app_overflow_menu.dart` lines 1-70; `docs/plan/RELEASE-2-PLAN.md` section 3.10 (14 day window); spec 4.8, 4.9, 4.10

## Why
A woman who paid must have a calm way out: ask for a refund inside the 14 day window, or report that the service was not delivered. The coach refunds by sending money back by InstaPay and records it; Own Hub never moves the money. Silence goes to staff after 3 days. A transfer to a wrong person cannot be undone by the app (4.10); the pay screen already warns her.

## Final result
Client, PAY3 for a confirmed payment gets a "..." menu with:
- "Ask for a refund" / "اطلبي استرداد" (only while the payment was confirmed less than 14 days ago and no refund was asked; the server enforces it too)
- "I have a problem with the service" / "عندي مشكلة في الخدمة" (any time while the payment is confirmed or resolved paid)
PAY8 for the client (both modes), top to bottom:
1. Top bar "Ask for a refund" or "Service problem", back arrow.
2. Calm line: refund "You can ask once in the first 14 days. Your coach has 3 days to answer, then Own Hub steps in." / "تقدري تطلبي مرة واحدة في أول 14 يوم. مدرّبتك عندها 3 أيام تردّ، وبعدها Own Hub بتتدخل." Service: "Tell us what went wrong. Own Hub looks at your sessions and messages and decides." / "احكيلنا إيه اللي حصل. Own Hub بتبص على جلساتك ورسايلك وتقرر."
3. Reason rows (one control group): refund: "I changed my mind" / "غيّرت رأيي"; "It is not what I expected" / "مش زي ما توقعت"; "I could not train" / "ماقدرتش أتمرّن"; "Another reason" / "سبب تاني". Service: "My coach is not answering" / "مدرّبتي مابتردش"; "I did not get my plan" / "ماجاليش خطتي"; "The sessions did not happen" / "الجلسات ماحصلتش"; "Another reason".
4. Field "Tell us more" / "احكيلنا أكتر" (5 to 300 characters).
5. Footer primary "Send" / "ابعتي".
Controls: back, reason group, note = 3 others + 1 primary.
After sending: PAY3 shows the new status ("Refund asked" or "Problem reported").
Coach, PAY4: a section "Refund requests" / "طلبات الاسترداد" above "Earlier" lists payments in `refund_requested`; tapping one opens the sheet "Record refund" / "سجّلي الاسترداد": lines "Send it back by InstaPay to your client, then record it here. Own Hub does not move money." / "ابعتي الفلوس لعميلتك بإنستا باي، وبعدين سجّليها هنا. Own Hub مابتحركش فلوس."; field "Amount sent back (EGP)" prefilled with the full amount (she may enter less for a partial refund after delivered sessions); field "Transaction number"; primary "Record refund" / "سجّلي الاسترداد". Controls in the sheet: 2 fields + 1 primary. She has no "deny" button in this release (the server lets 3 days pass, then staff decide); the sheet says nothing about denying.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/presentation/refund_request_view.dart | create | PAY8 client |
| app/lib/features/instapay/presentation/record_refund_sheet.dart | create | PAY8 coach |
| app/lib/features/instapay/domain/instapay_models.dart | edit | `confirmedAt`, `refundWindowOpen` |
| app/lib/features/instapay/presentation/status_view.dart | edit | the "..." menu |
| app/lib/features/instapay/presentation/coach_payments_view.dart | edit | the refund section |
| app/lib/routing/app_router.dart | edit | the menu callbacks |
| app/test/features/instapay/refund_request_view_test.dart | create | tests |
| app/test/features/instapay/record_refund_sheet_test.dart | create | tests |

## Steps
1. File `instapay_models.dart`. In `Payment` add `final DateTime? confirmedAt;` (constructor `this.confirmedAt,`; `fromMap`: `confirmedAt: readTime(dec['confirmedAt']),`) and this method:
```dart
  /// The first 14 days after confirmation (RELEASE-2-PLAN section 3.10).
  bool refundWindowOpen(DateTime now) {
    final at = confirmedAt;
    return status.activatesPackage && at != null && now.difference(at) < const Duration(days: 14);
  }
```
2. File `refund_request_view.dart` (create). Full content:
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/coach_rules.dart' show noteOk;
import '../domain/instapay_models.dart';
import 'payment_text.dart';

enum ProblemKind { refund, service }

const Map<ProblemKind, List<String>> kProblemReasons = {
  ProblemKind.refund: ['changed_mind', 'not_expected', 'could_not_train', 'other'],
  ProblemKind.service: ['no_answer', 'no_plan', 'no_sessions', 'other'],
};

class RefundRequestView extends StatefulWidget {
  const RefundRequestView({super.key, required this.payment, required this.kind, this.repository, this.onSent});
  final Payment payment;
  final ProblemKind kind;
  final InstapayRepository? repository;
  final VoidCallback? onSent;

  @override
  State<RefundRequestView> createState() => _RefundRequestViewState();
}

class _RefundRequestViewState extends State<RefundRequestView> {
  final _note = TextEditingController();
  final String _key = InstapayLocalStore.newKey();
  String? _reason;
  bool _busy = false;
  String _error = '';

  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _text(AppL10n l, String code) => switch (code) {
    'changed_mind' => l.iChangedMyMind,
    'not_expected' => l.itIsNotWhatIExpected,
    'could_not_train' => l.iCouldNotTrain,
    'no_answer' => l.myCoachIsNotAnswering,
    'no_plan' => l.iDidNotGetMyPlan,
    'no_sessions' => l.theSessionsDidNotHappen,
    _ => l.anotherReason,
  };

  Future<void> _send() async {
    final repo = _repo;
    if (repo == null) return;
    final l10n = AppL10n.of(context);
    setState(() { _busy = true; _error = ''; });
    try {
      if (widget.kind == ProblemKind.refund) {
        await repo.requestRefund(paymentId: widget.payment.id, key: _key, reasonCode: _reason!, note: _note.text.trim());
      } else {
        await repo.openServiceDispute(paymentId: widget.payment.id, key: _key, reasonCode: _reason!, note: _note.text.trim());
      }
      if (!mounted) return;
      (widget.onSent ?? () => Navigator.of(context).maybePop())();
    } on PaymentFailure catch (f) {
      if (mounted) setState(() { _busy = false; _error = paymentFailureText(l10n, f); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final refund = widget.kind == ProblemKind.refund;
    final ready = _reason != null && noteOk(_note.text) && !_busy;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(title: refund ? l10n.askForARefund : l10n.serviceProblem, onBack: () => Navigator.of(context).maybePop()),
      children: [
        Text(refund ? l10n.youCanAskOnceInTheFirst14DaysYourCoachHas3Days : l10n.tellUsWhatWentWrongOwnHubLooksAtYourSessions, style: AppText.bodyM),
        for (final code in kProblemReasons[widget.kind]!)
          AppListItem(
            key: ValueKey('why-$code'),
            title: _text(l10n, code),
            variant: _reason == code ? AppCardVariant.selected : AppCardVariant.outlined,
            onTap: () => setState(() => _reason = code),
          ),
        AppField(controller: _note, label: l10n.tellUsMore, maxLines: 3, onChanged: (_) => setState(() {})),
        if (_error.isNotEmpty) Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
      ],
      footer: [AppButton(l10n.send, key: const ValueKey('problem-send'), onPressed: ready ? () => unawaited(_send()) : null)],
    );
  }
}
```
3. File `record_refund_sheet.dart` (create):
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/coach_rules.dart';
import '../domain/instapay_models.dart';
import 'payment_text.dart';

Future<bool?> showRecordRefundSheet({required BuildContext context, required InstapayRepository repository, required Payment payment}) =>
    showAppSheet<bool>(context: context, children: [_Body(repository: repository, payment: payment)]);

class _Body extends StatefulWidget {
  const _Body({required this.repository, required this.payment});
  final InstapayRepository repository;
  final Payment payment;
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final TextEditingController _amount = TextEditingController(text: _plain(widget.payment.amountPiasters));
  final _txn = TextEditingController();
  final String _key = InstapayLocalStore.newKey();
  bool _busy = false;
  String _error = '';

  static String _plain(int p) => p % 100 == 0 ? '${p ~/ 100}' : '${p ~/ 100}.${(p % 100).toString().padLeft(2, '0')}';

  int get _max => widget.payment.amountPiasters > widget.payment.differentAmountPiasters
      ? widget.payment.amountPiasters
      : widget.payment.differentAmountPiasters;

  bool get _ok {
    final a = parseAmountPiasters(_amount.text);
    return a != null && a >= 100 && a <= _max && _txn.text.trim().length >= 6 && !_busy;
  }

  @override
  void dispose() {
    _amount.dispose();
    _txn.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    setState(() { _busy = true; _error = ''; });
    try {
      await widget.repository.recordRefund(
        paymentId: widget.payment.id, key: _key,
        amountPiasters: parseAmountPiasters(_amount.text)!, txnNumber: _txn.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on PaymentFailure catch (f) {
      if (mounted) setState(() { _busy = false; _error = paymentFailureText(l10n, f); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.recordTheRefund, style: AppText.titleL),
      Text(l10n.sendItBackByInstapayToYourClientThenRecordItHere, style: AppText.bodyM),
      AppField(controller: _amount, label: l10n.amountSentBackEgp, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr, onChanged: (_) => setState(() {})),
      AppField(controller: _txn, label: l10n.transactionNumber, keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr, onChanged: (_) => setState(() {})),
      if (_error.isNotEmpty) Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
      const SizedBox(height: 8),
      AppButton(l10n.recordTheRefund, key: const ValueKey('record-refund'), onPressed: _ok ? () => unawaited(_send()) : null),
      const SizedBox(height: 12),
    ]);
  }
}
```
(The title and the primary share the text "Record refund"; this is fine.)
4. File `status_view.dart`. Add to `PaymentStatusView` a field `final List<AppOverflowItem> Function(Payment payment)? menuFor;` (constructor `this.menuFor,`), import `../../../ui/app_overflow_menu.dart`, and change the `appBar:` to:
```dart
          appBar: AppTopBar(
            title: l10n.yourPayment,
            onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
            actions: [
              if (p != null && (widget.menuFor?.call(p).isNotEmpty ?? false))
                AppOverflowMenu(items: widget.menuFor!(p)),
            ],
          ),
```
5. File `coach_payments_view.dart`. Add `import 'record_refund_sheet.dart';`. In the payments `StreamBuilder` builder add `final refunds = all.where((p) => p.status == PaymentStatus.refundRequested).toList();` and change `earlier` to exclude them (`!waitingForCoach(p) && p.status != PaymentStatus.refundRequested`). Add above the "Earlier" block:
```dart
                if (refunds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Semantics(header: true, child: Text(l10n.refundRequests, style: AppText.titleL)),
                  for (final p in refunds)
                    AppListItem(
                      key: ValueKey('refund-${p.id}'),
                      title: p.reference,
                      subtitle: egpText(p.amountPiasters, arabic: arabic),
                      onTap: () => unawaited(showRecordRefundSheet(context: context, repository: repo, payment: p)),
                    ),
                ],
```
6. File `app_router.dart`. Where WO-10e5 builds `PaymentStatusView`, pass `menuFor` (a static helper `_payMenu(BuildContext, Payment, {DateTime? now})`):
```dart
  static List<AppOverflowItem> _payMenu(BuildContext context, Payment p) {
    final l10n = AppL10n.of(context);
    void open(ProblemKind k) => unawaited(Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => RefundRequestView(payment: p, kind: k))));
    return <AppOverflowItem>[
      if (p.refundWindowOpen(DateTime.now()))
        AppOverflowItem(icon: Icons.undo, label: l10n.askForARefund, onTap: () => open(ProblemKind.refund)),
      if (p.status.activatesPackage)
        AppOverflowItem(icon: Icons.flag_outlined, label: l10n.iHaveAProblemWithTheService, onTap: () => open(ProblemKind.service)),
    ];
  }
```
and `menuFor: (p) => _payMenu(inner, p),` at both `PaymentStatusView` constructions (the `H05` push and `onSeePayment`). (WO-10h2 adds one more item to this list.)

## Strings to add
File `app/tool/_wo10g_strings.json`; drop existing keys. Use every English and Arabic pair in "Final result" above, and: `Ask for a refund` / `اطلبي استرداد`; `Service problem` / `مشكلة في الخدمة`; `Tell us more` / `احكيلنا أكتر`; `Refund requests` / `طلبات الاسترداد`; `Record refund` / `سجّلي الاسترداد`; `Amount sent back (EGP)` / `المبلغ اللي رجّعتيه (جنيه)`; `Tell us what went wrong. Own Hub looks at your sessions and messages and decides.` (see above).

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| refund_request_view_test.dart | `send needs a reason and a note` | step through; `fake.calls.last.$1 == 'requestRefund'` with the reason code |
| same | `service mode calls openServiceDispute` | |
| same | `a refusal such as wrong_status shows the calm sentence` | |
| same | `budget at both sizes, EN and AR, 200 percent` | `<= 5` others, 1 primary |
| same | `refundWindowOpen is true on day 13 and false on day 14` | `Payment(status: confirmed, confirmedAt: now - 13 days)` true; 14 days false; status `proof_submitted` false |
| same | `the menu shows Ask for a refund only inside the window` | pump PAY3 with `menuFor: AppRouter-like function`; open menu; texts |
| record_refund_sheet_test.dart | `the amount is prefilled with the full amount` | field text `500.37` |
| same | `partial amounts are accepted, zero and more than the max are refused` | `250` ok; `0` off; `600` off for max 50037 |
| same | `record sends amount and txn once` | `fake.calls.last` `recordRefund` with 25000 and the txn |
| coach_payments_view_test.dart (add) | `refund requests have their own section` | a `refund_requested` payment appears under `refund-p1`, not under earlier |
Run: `cd app && flutter test test/features/instapay`

## Verify
- `cd app && dart analyze lib/features/instapay lib/routing/app_router.dart` ends `No issues found!`
- `cd app && flutter test test/features/instapay` ends `All tests passed!`

## Do not
- Do not move money, and do not write "refunded" before the coach recorded it.
- Do not offer the refund menu after day 14 or twice.
- Do not use guilt wording ("your fault", "lost", "failed").

## Done checklist
- [ ] PAY8 both sides, menu, coach section, router
- [ ] strings; tests

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10h2).

UNVERIFIED in this order: 1 (the server's field `coachDecision.confirmedAt` is the confirmation time; `refundWindowOpen` uses 14 days from it, confirm with WO-10b).
