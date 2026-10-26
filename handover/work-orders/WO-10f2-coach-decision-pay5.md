# WO-10f2: PAY5, "Not received" with her own statement, "Different amount", auto-confirm
Depends on: WO-10f1, WO-10e3 (redaction pipeline), WO-10e2 (`normalizeDigits`)
Size: L
Reads first: `app/lib/features/instapay/presentation/coach_payments_view.dart`; `app/lib/features/instapay/presentation/proof_flow.dart`; `app/lib/features/private_coaching/presentation/coach/coach_widgets.dart` (find `CoachSwitchRow`, `CoachFieldError`); `app/lib/ui/app_list_item.dart`; spec 4.1, 4.3, 13.4, 13.5

## Why
A false "not received" is the coach's way to dodge the fee or the service (spec 13.1). So the sheet asks her to search her own bank and attach her bank's list for that day. If that list shows the payment, the claim is refused at once and calmly. If she cannot read the list, it goes to staff with both images. "Different amount" lets her state what arrived and, in writing, accept a lower amount. Trusted coaches may turn on auto-confirm of matching payments.

## Final result
Screen "Not received" (PAY5, mode 1), top to bottom:
1. Top bar "Not received", back arrow.
2. Title "What do you see in your bank?" / "إيه اللي شايفاه في البنك؟" and five rows (adjacent rows, one control group): "I do not see it in my account" / "مش لاقياه في حسابي"; "The amount is different" / "المبلغ مختلف"; "The name is different" / "الاسم مختلف"; "Someone else paid" / "حد تاني دفع"; "Another reason" / "سبب تاني". Tapping selects one (selected variant).
3. A tick: "I searched my bank for {amount} and transaction number {txn}." / "دوّرت في البنك على {amount} ورقم العملية {txn}." (the txn part is dropped when none was read).
4. Field "Tell us what you saw" / "احكيلنا شُفتي إيه" (required, 5 to 300 characters).
5. Outlined button "Add my bank's list for that day" / "ضيفي كشف البنك لليوم ده". It runs the same pick, hide, read steps as the client (WO-10e3). Under it: "1 picture added" once added.
6. Footer, the one primary "Send" / "ابعتي". Enabled when a reason is selected, the tick is on, the note is valid and a picture is added.
If the phone reads her picture and it contains the unique amount or the transaction number, the line "This payment appears in your statement. Please check again." / "الدفع ده ظاهر في كشفك. راجعي تاني." replaces the picture, Send stays off, and nothing is sent. The server re-checks (spec 13.5).
Controls above the fold: back, the reason group (1), tick (1), note field (1), screenshot button (1) = 5 others + 1 primary.
Success: calm line "Sent. Own Hub will look at it." and back to PAY4. The client is told "Your coach says it has not arrived".
Screen "Different amount" (PAY5, mode 2): top bar "Different amount"; title "How much did you receive?"; field "Amount received (EGP)" (digits, up to 2 decimals); when the amount is less than the expected one a switch "Accept this lower amount and start the coaching" / "أقبل المبلغ الأقل وأبدأ التدريب" with the helper "If you accept, your client's package starts. Otherwise she can pay the rest." / "لو قبلتي، باقة العميلة بتبدأ. غير كده هي تقدر تدفع الباقي."; footer "Send". Controls: back, field, switch = 3 others + 1 primary. The amount must differ from the expected amount and be at least 1 EGP.
Auto-confirm card on PAY4 (shown when she has 3 or more confirmed payments, or it is already on): a `CoachSwitchRow` "Confirm matching payments for me" / "أكدي الدفعات المطابقة بدالي", subtitle "Only payments that match your records. You can still flag one within 48 hours." / "الدفعات المطابقة لسجلاتك بس. وتقدري تبلّغي عن أي واحدة خلال 48 ساعة."

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/domain/coach_rules.dart | create | `statementShowsPayment`, `parseAmountPiasters`, reason codes |
| app/lib/features/instapay/presentation/coach_decision_view.dart | create | PAY5 both modes |
| app/lib/features/instapay/domain/instapay_models.dart | edit | `autoConfirm` on `CoachAddress` |
| app/lib/features/instapay/data/firestore_instapay_repository.dart | edit | read `autoConfirm` |
| app/lib/features/instapay/presentation/coach_payments_view.dart | edit | auto-confirm card |
| app/lib/routing/app_router.dart | edit | `onPaymentDecision` for K18 |
| app/test/features/instapay/coach_rules_test.dart | create | rule tests |
| app/test/features/instapay/coach_decision_view_test.dart | create | screen tests |

## Steps
1. File `app/lib/features/instapay/domain/coach_rules.dart` (create):
```dart
library;

import 'instapay_models.dart';
import 'receipt_reader.dart';

/// Spec 4.1 reason codes, in the order shown.
const List<String> kNotReceivedReasons = <String>[
  'not_seen', 'wrong_amount', 'wrong_name', 'other_payer', 'other',
];

/// True when the text of her statement contains this payment's unique amount
/// or its transaction number (spec 13.5): the claim is then refused.
bool statementShowsPayment(String text, Payment p) {
  final t = normalizeDigits(text);
  final whole = p.amountPiasters ~/ 100;
  final rest = (p.amountPiasters % 100).toString().padLeft(2, '0');
  final amounts = <String>['$whole.$rest', '$whole,$rest'];
  if (amounts.any(t.contains)) return true;
  final txn = p.txnNumber.trim();
  return txn.length >= 6 && t.contains(txn);
}

/// "300", "300.5", "300.50", "٣٠٠" to piasters; null when not an amount.
int? parseAmountPiasters(String raw) {
  final t = normalizeDigits(raw).trim().replaceAll(',', '.');
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final cents = m.group(2) == null ? 0 : int.parse(m.group(2)!.padRight(2, '0'));
  return int.parse(m.group(1)!) * 100 + cents;
}

bool noteOk(String raw) {
  final n = raw.trim().length;
  return n >= 5 && n <= 300;
}
```
2. File `app/lib/features/instapay/presentation/coach_decision_view.dart` (create). Full content:
```dart
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../data/proof_images.dart';
import '../domain/coach_rules.dart';
import '../domain/instapay_models.dart';
import '../domain/receipt_reader.dart';
import 'payment_text.dart';
import 'proof_flow.dart';

enum DecisionMode { notReceived, differentAmount }

class CoachDecisionView extends StatefulWidget {
  const CoachDecisionView({
    super.key,
    required this.payment,
    required this.mode,
    this.repository,
    this.picker = pickProofImages,
    this.prepare = prepareProofImage,
    this.onDone,
    this.now,
  });

  final Payment payment;
  final DecisionMode mode;
  final InstapayRepository? repository;
  final Future<List<Uint8List>> Function() picker;
  final PrepareImage prepare;
  final VoidCallback? onDone;
  final DateTime Function()? now;

  @override
  State<CoachDecisionView> createState() => _CoachDecisionViewState();
}

class _CoachDecisionViewState extends State<CoachDecisionView> {
  final _note = TextEditingController();
  final _amount = TextEditingController();
  final String _key = InstapayLocalStore.newKey();
  String? _reason;
  bool _ticked = false;
  bool _acceptLower = false;
  PreparedImage? _statement;
  bool _appears = false;
  bool _busy = false;
  String _error = '';

  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  ExpectedPayment get _expected => ExpectedPayment(
    amountPiasters: widget.payment.amountPiasters,
    coachAddress: widget.payment.address.address,
    coachAccountName: widget.payment.address.accountName,
    createdAt: widget.payment.createdAt ?? (widget.now ?? DateTime.now)(),
  );

  Future<void> _addStatement() async {
    final l10n = AppL10n.of(context);
    final raw = await widget.picker();
    if (!mounted || raw.isEmpty) return;
    final p = await widget.prepare(context, raw.first, _expected);
    if (!mounted) return;
    if (p == null) {
      setState(() => _error = l10n.thisPictureIsTooBigOrCouldNotBeReadPickAnother);
      return;
    }
    final appears = statementShowsPayment(p.text, widget.payment);
    setState(() {
      _error = '';
      _appears = appears;
      _statement = appears ? null : p;
    });
  }

  bool get _notReceivedReady =>
      _reason != null && _ticked && noteOk(_note.text) && _statement != null && !_busy;

  int? get _entered => parseAmountPiasters(_amount.text);
  bool get _amountOk {
    final a = _entered;
    return a != null && a >= 100 && a != widget.payment.amountPiasters;
  }

  Future<void> _send() async {
    final repo = _repo;
    if (repo == null) return;
    final l10n = AppL10n.of(context);
    setState(() { _busy = true; _error = ''; });
    try {
      if (widget.mode == DecisionMode.notReceived) {
        await repo.coachNotReceived(
          paymentId: widget.payment.id, key: _key, reasonCode: _reason!,
          note: _note.text.trim(), statement: _statement!.png,
        );
      } else {
        final lower = _entered! < widget.payment.amountPiasters;
        await repo.coachDifferentAmount(
          paymentId: widget.payment.id, key: _key, amountPiasters: _entered!,
          acceptLower: lower && _acceptLower,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.sentOwnHubWillLookAtIt)));
      (widget.onDone ?? () => Navigator.of(context).maybePop())();
    } on PaymentFailure catch (f) {
      if (mounted) setState(() { _busy = false; _error = paymentFailureText(l10n, f); });
    }
  }

  String _reasonText(AppL10n l, String code) => switch (code) {
    'not_seen' => l.iDoNotSeeItInMyAccount,
    'wrong_amount' => l.theAmountIsDifferent,
    'wrong_name' => l.theNameIsDifferent,
    'other_payer' => l.someoneElsePaid,
    _ => l.anotherReason,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = widget.payment;
    final amountText = egpText(p.amountPiasters, arabic: arabic);
    final notReceived = widget.mode == DecisionMode.notReceived;
    final lower = _entered != null && _entered! < p.amountPiasters;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: notReceived ? l10n.notReceived : l10n.differentAmount,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        if (notReceived) ...[
          Text(l10n.whatDoYouSeeInYourBank, style: AppText.titleM),
          for (final code in kNotReceivedReasons)
            AppListItem(
              key: ValueKey('reason-$code'),
              title: _reasonText(l10n, code),
              variant: _reason == code ? AppCardVariant.selected : AppCardVariant.outlined,
              onTap: () => setState(() => _reason = code),
            ),
          CheckboxListTile(
            key: const ValueKey('searched'),
            value: _ticked,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(p.txnNumber.isEmpty
                ? l10n.iSearchedMyBankForAmount(amountText)
                : l10n.iSearchedMyBankForAmountAndTransactionNumber(amountText, p.txnNumber)),
            onChanged: (v) => setState(() => _ticked = v ?? false),
          ),
          AppField(controller: _note, label: l10n.tellUsWhatYouSaw, maxLines: 3, onChanged: (_) => setState(() {})),
          AppButton(l10n.addMyBankSListForThatDay, key: const ValueKey('add-statement'), variant: AppButtonVariant.outlined,
              onPressed: _busy ? null : () => unawaited(_addStatement())),
          if (_statement != null) Text(l10n.countPicturesAdded(1), style: AppText.bodyM),
          if (_appears)
            Semantics(liveRegion: true, child: Text(l10n.thisPaymentAppearsInYourStatementPleaseCheckAgain, key: const ValueKey('appears'), style: AppText.bodyM.copyWith(color: AppColors.error))),
        ] else ...[
          Text(l10n.howMuchDidYouReceive, style: AppText.titleM),
          AppField(controller: _amount, label: l10n.amountReceivedEgp, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr, onChanged: (_) => setState(() {})),
          if (lower)
            AppToggle(
              key: const ValueKey('accept-lower'),
              value: _acceptLower,
              onChanged: (v) => setState(() => _acceptLower = v),
              label: l10n.acceptThisLowerAmountAndStartTheCoaching,
            ),
          if (lower) Text(l10n.ifYouAcceptYourClientSPackageStartsOtherwiseSheCanPayTheRest, style: AppText.bodyM),
        ],
        if (_error.isNotEmpty) Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
      ],
      footer: [
        AppButton(l10n.send, key: const ValueKey('decision-send'),
            onPressed: (notReceived ? _notReceivedReady : (_amountOk && !_busy)) ? () => unawaited(_send()) : null),
      ],
    );
  }
}
```
UNVERIFIED: `AppToggle` constructor (`value`, `onChanged`, `label`) — read `app/lib/ui/app_toggle.dart` lines 1-40 and adapt; if it has no `label`, wrap it in a `Row` with a `Text`. `CheckboxListTile` is a Material widget counted by the control counter? It is not in `_isLeaf` (only `Switch`, buttons, text fields, chips...); but it contains an `InkWell` with `onTap`, which `_isTapSurface` counts as a control, so it counts as one. Good, same as the budget in "Final result".
3. File `app/lib/features/instapay/domain/instapay_models.dart`: in `CoachAddress` add `this.autoConfirm = false,` and `final bool autoConfirm;`. File `firestore_instapay_repository.dart` in `watchMyAddress` add `autoConfirm: readBool(m['autoConfirm']),` to the `CoachAddress(...)`.
4. File `app/lib/features/instapay/presentation/coach_payments_view.dart`. In the `Column(children: [...])` of the payments `StreamBuilder`, directly under the `Semantics(header...)` of "Waiting for you" is wrong place; add instead at the top of the outer `children:` list, after the address `StreamBuilder`, this block:
```dart
          StreamBuilder<CoachAddress?>(
            stream: repo.watchMyAddress(),
            builder: (context, a) => StreamBuilder<List<Payment>>(
              stream: repo.watchMyPaymentsAsCoach(),
              builder: (context, ps) {
                final done = (ps.data ?? const <Payment>[]).where((p) => p.status.activatesPackage).length;
                final on = a.data?.autoConfirm ?? false;
                if (done < 3 && !on) return const SizedBox.shrink();
                return CoachSwitchRow(
                  title: l10n.confirmMatchingPaymentsForMe,
                  subtitle: l10n.onlyPaymentsThatMatchYourRecordsYouCanStillFlagOne,
                  value: on,
                  onChanged: (v) => unawaited(repo.setAutoConfirm(v)),
                );
              },
            ),
          ),
```
with the import of `CoachSwitchRow` from `../../private_coaching/presentation/coach/coach_widgets.dart` (UNVERIFIED: file that defines it: `grep -rn "class CoachSwitchRow" app/lib`). Spec 13.4: "offered after 3 clean payments"; "clean" is the server's word, here it is "3 confirmed"; ask the server agent in QUESTIONS.md whether it exposes a clean count.
5. File `app/lib/routing/app_router.dart`. In the `'K18'` builder add:
```dart
        onPaymentDecision: (payment, result) => unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CoachDecisionView(
                payment: payment,
                mode: result == DecisionResult.notReceived ? DecisionMode.notReceived : DecisionMode.differentAmount,
              ),
            ),
          ),
        ),
```
Imports: `coach_decision_view.dart`, `decision_sheet.dart`.

## Strings to add
File `app/tool/_wo10f2_strings.json`; drop existing keys. Parameterised: `I searched my bank for {amount}.` (amount); `I searched my bank for {amount} and transaction number {txn}.` (amount, txn).
Use every English and Arabic pair in "Final result" above, and also: `Sent. Own Hub will look at it.` / `اتبعت. Own Hub هتبص عليه.`; `1 picture added` uses the plural string of WO-10e4. Arabic for the first parameterised string: `دوّرت في البنك على {amount}.`

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| coach_rules_test.dart | `statementShowsPayment finds the amount in both separators and the txn` | text `... 500,37 ...` true; `500.37` true; `٥٠٠٫٣٧` true; txn present true; unrelated false; txn shorter than 6 digits is ignored |
| same | `parseAmountPiasters` | `'300'`=30000, `'300.5'`=30050, `'300,50'`=30050, `'٣٠٠'`=30000, `'abc'` null, `'1.234'` null |
| same | `noteOk bounds` | 4 chars false, 5 true, 300 true, 301 false |
| coach_decision_view_test.dart | `send is off until reason, tick, note and picture are all there` | step through; enabled only at the end; `fake.calls.last.$1 == 'coachNotReceived'` with the reason code |
| same | `a statement that shows the payment is refused and nothing is sent` | fake `prepare` returns text containing `500.37`; `appears` found; send disabled; `fake.calls` empty |
| same | `a failed prepare shows the picture message` | prepare returns null |
| same | `different amount: same amount and under 1 pound are refused` | `500.37` entered for expected 50037 keeps send off; `0.5` off; `300` on |
| same | `the accept-lower switch only shows for a lower amount and is sent` | `300` shows `accept-lower`; switch on; send; `acceptLower: true` in the call; `600` hides the switch and sends false |
| same | `a refusal shows a calm sentence` | `failNext = PaymentFailure('wrong_status')` |
| same | `budget: not received at 390x844 and 375x667, EN and AR, 200 percent` | `<= 5` others, one filled primary |
| coach_payments_view_test.dart (add) | `auto-confirm card shows after 3 confirmed and calls setAutoConfirm` | 3 confirmed payments; card found; flip; `fake.calls.last.$1 == 'setAutoConfirm'`; with 2 confirmed and autoConfirm off: absent |
Run: `cd app && flutter test test/features/instapay`

## Verify
- `cd app && dart analyze lib/features/instapay lib/routing/app_router.dart` ends `No issues found!`
- `cd app && flutter test test/features/instapay` ends `All tests passed!`

## Do not
- Do not let "Not received" be sent without the tick and the picture.
- Do not call the coach a liar or use "false", "fraud" or "cheat" in any text.
- Do not edit an amount of the payment: the coach only states what arrived.
- No em dashes.

## Done checklist
- [ ] rules, PAY5 both modes, auto-confirm card, router
- [ ] strings; tests EN and AR at both sizes

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10h2).

UNVERIFIED in this order: 3 (`AppToggle` signature, `CoachSwitchRow` location, server meaning of "clean").
