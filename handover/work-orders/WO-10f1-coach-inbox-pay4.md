# WO-10f1: PAY4, the coach's payment inbox and "I received it"
Depends on: WO-10d0, WO-10d-app, WO-10e1 (copy-button pattern only)
Size: L
Reads first: `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart` lines 25-60 and 186-210; `app/lib/ui/app_list_item.dart` lines 30-60; `app/lib/ui/app_sheet.dart`; `app/lib/features/private_coaching/presentation/end_coaching_sheet.dart` (a sheet with two actions); `app/lib/app_state/private_coaching_state.dart` lines 205-240; spec 4.1, 4.5, 13.4, 13.8, 13.12 item 8

## Why
The coach is the real check: she sees her own bank. The inbox must make the honest case take two taps from the notification: the push opens this screen, the screen opens the one waiting payment by itself, and "I received it" confirms. The screen shows what she needs to look up in her bank: the exact unique amount and the transaction number read from the client's screenshot.

## Final result
K18 (coach space) gets a row "Payments" (visible when `instapayOn`). It opens PAY4, top to bottom:
1. Top bar "Payments" with a "..." menu: "My InstaPay address" (opens PAY7), "A client paid me" (opens the sheet below).
2. If she has no confirmed address: a tonal card "Add your InstaPay address so clients can pay you." / "ضيفي عنوان إنستا باي بتاعك عشان العميلات يعرفوا يدفعولك." with a button "Add address" / "ضيفي العنوان".
3. Section title "Waiting for you" / "مستنية ردّك" and a list of rows. Each row: title = the reference, subtitle = `500.37 EGP, proof sent 14:32` / `500.37 جنيه، الإثبات اتبعت 14:32`, a small pill: "Matches" (green) or "Check your bank" (amber).
4. Section title "Earlier" / "قبل كده" with the last 10 other payments (status word as subtitle).
5. Empty: "Nothing is waiting for you." / "مفيش حاجة مستنياكي." in a sage note.
Tapping a row, or the screen opening with exactly one waiting payment, opens the decision sheet:
- Title "Payment {reference}" / "الدفع {reference}"
- Lines: "Look for exactly {amount}" / "دوّري على {amount} بالظبط"; "Transaction number {txn}" / "رقم العملية {txn}" (hidden if not read); "Paid at {time}" (Cairo).
- Green: tonal card "Paid, matches your records." / "اتدفع، ومطابق لسجلاتك." Amber: "Please check your bank." / "من فضلك اتشيكي على البنك."
- Buttons: "I received it" (the one filled primary) / "وصلتني"; "Not received" (outlined) / "ماوصلتش"; "Different amount" (text) / "مبلغ مختلف". The last two open PAY5 (WO-10f2).
Controls above the fold, list screen: back, menu, address card button, one row run = 4 others, 0 primary (no filled primary on the list). Sheet: 2 others + 1 primary.
Tap count: notification (1), screen opens the sheet by itself, "I received it" (2).
"A client paid me" sheet (spec 4.5): title "A client paid me" / "عميلة دفعتلي"; her active clients as rows (tap selects); a field "Transaction number"; primary "Send" / "ابعتي". The client gets a notice and confirms; staff see it after 72 hours of silence.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/presentation/coach_payments_view.dart | create | PAY4 |
| app/lib/features/instapay/presentation/decision_sheet.dart | create | the sheet and "I received it" |
| app/lib/features/instapay/presentation/client_paid_sheet.dart | create | spec 4.5 |
| app/lib/features/private_coaching/presentation/coach/coach_space_view.dart | edit | the "Payments" row |
| app/lib/routing/app_router.dart | edit | pass `instapayClients` for the sheet |
| app/test/features/instapay/coach_payments_view_test.dart | create | tests |

## Steps
1. File `app/lib/features/instapay/presentation/decision_sheet.dart` (create). It returns when she confirms, or reports which other action she chose. Full content:
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sheet.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/instapay_models.dart';
import 'payment_text.dart';

enum DecisionResult { confirmed, notReceived, differentAmount }

/// Opens the decision sheet for one waiting payment.
Future<DecisionResult?> showDecisionSheet({
  required BuildContext context,
  required InstapayRepository repository,
  required Payment payment,
}) {
  final key = InstapayLocalStore.newKey();
  return showAppSheet<DecisionResult>(
    context: context,
    children: [_DecisionBody(repository: repository, payment: payment, keyValue: key)],
  );
}

class _DecisionBody extends StatefulWidget {
  const _DecisionBody({required this.repository, required this.payment, required this.keyValue});
  final InstapayRepository repository;
  final Payment payment;
  final String keyValue;

  @override
  State<_DecisionBody> createState() => _DecisionBodyState();
}

class _DecisionBodyState extends State<_DecisionBody> {
  bool _busy = false;
  String _error = '';

  Future<void> _confirm() async {
    final l10n = AppL10n.of(context);
    setState(() { _busy = true; _error = ''; });
    try {
      await widget.repository.coachConfirm(widget.payment.id, widget.keyValue);
      if (mounted) Navigator.of(context).pop(DecisionResult.confirmed);
    } on PaymentFailure catch (f) {
      if (mounted) setState(() { _busy = false; _error = paymentFailureText(l10n, f); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = widget.payment;
    final paidAt = p.submittedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.paymentReference(p.reference), style: AppText.titleL),
        Text(l10n.lookForExactlyAmount(egpText(p.amountPiasters, arabic: arabic)), key: const ValueKey('look-for'), style: AppText.titleM),
        if (p.txnNumber.isNotEmpty)
          Text(l10n.transactionNumberValue(p.txnNumber), key: const ValueKey('sheet-txn'), textDirection: TextDirection.ltr, style: AppText.bodyM),
        if (paidAt != null)
          Text(l10n.paidAtTime('${two(cairoTime(paidAt).hour)}:${two(cairoTime(paidAt).minute)}'), style: AppText.bodyM),
        const SizedBox(height: 8),
        if (p.riskOutcome == RiskOutcome.green)
          AppCard(variant: AppCardVariant.tonal, children: [Text(l10n.paidMatchesYourRecords, key: const ValueKey('sheet-green'), style: AppText.bodyM)])
        else
          AppPill(l10n.pleaseCheckYourBank, background: AppColors.amberContainer, foreground: AppColors.amber),
        if (_error.isNotEmpty) Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
        const SizedBox(height: 12),
        AppButton(l10n.iReceivedIt, key: const ValueKey('received'), onPressed: _busy ? null : () => unawaited(_confirm())),
        const SizedBox(height: 8),
        AppButton(l10n.notReceived, key: const ValueKey('not-received'), variant: AppButtonVariant.outlined, height: 48,
            onPressed: _busy ? null : () => Navigator.of(context).pop(DecisionResult.notReceived)),
        AppButton(l10n.differentAmount, key: const ValueKey('different-amount'), variant: AppButtonVariant.text, height: 44, fontSize: 15,
            onPressed: _busy ? null : () => Navigator.of(context).pop(DecisionResult.differentAmount)),
        const SizedBox(height: 12),
      ],
    );
  }
}
```
UNVERIFIED: `AppPill(String, {background, foreground})` (used in `coach_space_view.dart`), `AppColors.amberContainer` and `AppColors.amber` (used there too). Placeholder getter names as before.
2. File `app/lib/features/instapay/presentation/client_paid_sheet.dart` (create):
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sheet.dart';
import '../../private_coaching/domain/subscription.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import 'payment_text.dart';

/// Spec 4.5: the coach starts a payment record for a client who paid.
Future<bool?> showClientPaidSheet({
  required BuildContext context,
  required InstapayRepository repository,
  required List<Subscription> clients,
}) => showAppSheet<bool>(
  context: context,
  children: [_ClientPaidBody(repository: repository, clients: clients)],
);

class _ClientPaidBody extends StatefulWidget {
  const _ClientPaidBody({required this.repository, required this.clients});
  final InstapayRepository repository;
  final List<Subscription> clients;

  @override
  State<_ClientPaidBody> createState() => _ClientPaidBodyState();
}

class _ClientPaidBodyState extends State<_ClientPaidBody> {
  final _txn = TextEditingController();
  final String _key = InstapayLocalStore.newKey();
  String? _subId;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _txn.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    setState(() { _busy = true; _error = ''; });
    try {
      await widget.repository.coachReport(subId: _subId!, txnNumber: _txn.text.trim(), key: _key);
      if (mounted) Navigator.of(context).pop(true);
    } on PaymentFailure catch (f) {
      if (mounted) setState(() { _busy = false; _error = paymentFailureText(l10n, f); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ready = _subId != null && _txn.text.trim().length >= 6 && !_busy;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.aClientPaidMe, style: AppText.titleL),
      for (final c in widget.clients)
        AppListItem(
          key: ValueKey('client-${c.id}'),
          title: c.clientName,
          variant: _subId == c.id ? AppCardVariant.selected : AppCardVariant.outlined,
          onTap: () => setState(() => _subId = c.id),
        ),
      AppField(controller: _txn, label: l10n.transactionNumber, keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr, onChanged: (_) => setState(() {})),
      if (_error.isNotEmpty) Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
      const SizedBox(height: 8),
      AppButton(l10n.send, key: const ValueKey('client-paid-send'), onPressed: ready ? () => unawaited(_send()) : null),
      const SizedBox(height: 12),
    ]);
  }
}
```
3. File `app/lib/features/instapay/presentation/coach_payments_view.dart` (create). Full content:
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_overflow_menu.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../private_coaching/domain/subscription.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_repository.dart';
import '../domain/instapay_models.dart';
import 'client_paid_sheet.dart';
import 'decision_sheet.dart';
import 'instapay_address_view.dart';
import 'status_text.dart';

bool waitingForCoach(Payment p) => p.status == PaymentStatus.proofSubmitted && !p.reportedByCoach;

/// PAY4: waiting payments first.
class CoachPaymentsView extends StatefulWidget {
  const CoachPaymentsView({
    super.key,
    this.repository,
    this.clients = const <Subscription>[],
    this.onDecision,
    this.onBack,
    this.extraMenu = const <AppOverflowItem>[],
  });

  final InstapayRepository? repository;
  final List<Subscription> clients;

  /// Called when she picks Not received or Different amount (PAY5, WO-10f2).
  final void Function(Payment payment, DecisionResult result)? onDecision;
  final VoidCallback? onBack;

  /// WO-10h1 adds "Monthly statement" here through the router.
  final List<AppOverflowItem> extraMenu;

  @override
  State<CoachPaymentsView> createState() => _CoachPaymentsViewState();
}

class _CoachPaymentsViewState extends State<CoachPaymentsView> {
  bool _autoOpened = false;
  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;

  Future<void> _open(Payment p) async {
    final repo = _repo;
    if (repo == null) return;
    final r = await showDecisionSheet(context: context, repository: repo, payment: p);
    if (!mounted || r == null) return;
    if (r == DecisionResult.confirmed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(AppL10n.of(context).confirmedYourClientCanStart)));
    } else {
      widget.onDecision?.call(p, r);
    }
  }

  String _hhmm(DateTime? t) {
    if (t == null) return '';
    final c = cairoTime(t);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(c.hour)}:${two(c.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final repo = _repo;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.payments,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
        actions: [
          AppOverflowMenu(items: [
            AppOverflowItem(
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.myInstapayAddress,
              onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const InstapayAddressView())),
            ),
            AppOverflowItem(
              icon: Icons.payments_outlined,
              label: l10n.aClientPaidMe,
              onTap: () {
                if (repo != null) unawaited(showClientPaidSheet(context: context, repository: repo, clients: widget.clients));
              },
            ),
            ...widget.extraMenu,
          ]),
        ],
      ),
      children: [
        if (repo == null)
          const SizedBox.shrink()
        else ...[
          StreamBuilder<CoachAddress?>(
            stream: repo.watchMyAddress(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting || !(snap.data?.isEmpty ?? true)) return const SizedBox.shrink();
              return AppCard(variant: AppCardVariant.tonal, children: [
                Text(l10n.addYourInstapayAddressSoClientsCanPayYou, style: AppText.bodyM),
                AppButton(l10n.addAddress, key: const ValueKey('add-address'), variant: AppButtonVariant.outlined, height: 48,
                    onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const InstapayAddressView()))),
              ]);
            },
          ),
          StreamBuilder<List<Payment>>(
            stream: repo.watchMyPaymentsAsCoach(),
            builder: (context, snap) {
              final all = snap.data ?? const <Payment>[];
              final waiting = all.where(waitingForCoach).toList();
              final earlier = all.where((p) => !waitingForCoach(p)).take(10).toList();
              if (!_autoOpened && waiting.length == 1) {
                _autoOpened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) unawaited(_open(waiting.single));
                });
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text(l10n.waitingForYou, style: AppText.titleL)),
                if (waiting.isEmpty) AppSageNote(l10n.nothingIsWaitingForYou),
                for (final p in waiting)
                  AppListItem(
                    key: ValueKey('waiting-${p.id}'),
                    title: p.reference,
                    subtitle: l10n.amountProofSentTime(egpText(p.amountPiasters, arabic: arabic), _hhmm(p.submittedAt)),
                    trailing: p.riskOutcome == RiskOutcome.green
                        ? AppPill(l10n.matches)
                        : AppPill(l10n.checkYourBank, background: AppColors.amberContainer, foreground: AppColors.amber),
                    onTap: () => unawaited(_open(p)),
                  ),
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Semantics(header: true, child: Text(l10n.earlier, style: AppText.titleL)),
                  for (final p in earlier)
                    AppListItem(
                      key: ValueKey('earlier-${p.id}'),
                      title: p.reference,
                      subtitle: '${egpText(p.amountPiasters, arabic: arabic)}, ${statusWord(l10n, p.status)}',
                    ),
                ],
              ]);
            },
          ),
        ],
      ],
    );
  }
}
```
4. File `coach_space_view.dart`. Directly after the "My InstaPay address" `_nav` of WO-10d-app step 6 add:
```dart
              if (widget.instapayOn)
                _nav(
                  title: l10n.payments,
                  subtitle: l10n.paymentsClientsSentYou,
                  icon: Icons.payments_outlined,
                  onTap: () => _push(CoachPaymentsView(clients: widget.instapayClients, onDecision: widget.onPaymentDecision)),
                ),
```
with constructor parameters `this.instapayClients = const <Subscription>[],` and `this.onPaymentDecision,` (type `void Function(Payment, DecisionResult)?`) and the imports for `Subscription` (already imported in this file? UNVERIFIED), `Payment`, `DecisionResult`, `CoachPaymentsView`. In `app_router.dart` `'K18'` builder add `instapayClients: PrivateCoachingState.instance.activeClients,` (UNVERIFIED: whether `activeClients` includes clients whose payment is being sorted; if a client who is `awaiting_payment` is not in it, use `PrivateCoachingState.instance.coachSubs` after `grep -n "List<Subscription> get" app/lib/app_state/private_coaching_state.dart`) and `onPaymentDecision:` set in WO-10f2.
5. Strings (below), tests.

## Strings to add
File `app/tool/_wo10f1_strings.json`; drop existing keys (`Payments`, `Send`, `Earlier`). Parameterised: `Payment {reference}` (reference String `OH-4821`); `Look for exactly {amount}` (amount String `500.37 EGP`); `Transaction number {txn}` (txn String `123456789012`); `Paid at {time}` (time String `14:32`); `{amount}, proof sent {time}` (amount, time Strings).
| English (key) | Egyptian Arabic |
|---|---|
| Payments | المدفوعات |
| Payments clients sent you | اللي العميلات بعتوهولك |
| Add your InstaPay address so clients can pay you. | ضيفي عنوان إنستا باي بتاعك عشان العميلات يعرفوا يدفعولك. |
| Add address | ضيفي العنوان |
| Waiting for you | مستنية ردّك |
| Nothing is waiting for you. | مفيش حاجة مستنياكي. |
| Earlier | قبل كده |
| Matches | مطابق |
| Check your bank | اتشيكي على البنك |
| Payment {reference} | الدفع {reference} |
| Look for exactly {amount} | دوّري على {amount} بالظبط |
| Transaction number {txn} | رقم العملية {txn} |
| Paid at {time} | اتدفع الساعة {time} |
| {amount}, proof sent {time} | {amount}، الإثبات اتبعت {time} |
| Paid, matches your records. | اتدفع، ومطابق لسجلاتك. |
| Please check your bank. | من فضلك اتشيكي على البنك. |
| I received it | وصلتني |
| Not received | ماوصلتش |
| Different amount | مبلغ مختلف |
| Confirmed. Your client can start. | اتأكد. عميلتك تقدر تبدأ. |
| A client paid me | عميلة دفعتلي |

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| coach_payments_view_test.dart | `waiting payments come first with a pill` | fake coach `uid='coach'`; two payments (one proof_submitted green, one confirmed); the waiting row key `waiting-p1` above `earlier-p2`; pill text `Matches` |
| same | `exactly one waiting payment opens the sheet by itself` | one waiting payment; `pumpAndSettle`; `look-for` text found |
| same | `two waiting payments do not open a sheet` | none found |
| same | `I received it confirms once` | tap `received`; `fake.calls` has one `coachConfirm`; sheet closed; snackbar text found |
| same | `Not received and Different amount report the choice` | tap each; `onDecision` called with the right `DecisionResult` |
| same | `amber shows the bank check pill, green shows the records card` | |
| same | `the sheet shows the unique amount and the transaction number` | texts `Look for exactly 500.37 EGP`, txn text found; with empty txn the txn line is absent |
| same | `no address shows the card` | `fake.address = null`: `add-address` found; with an address: absent |
| same | `A client paid me sends the report` | open menu, tap the item, tap `client-s1`, type `123456`, tap `client-paid-send`; `fake.calls.last.$1 == 'coachReport'` |
| same | `no phone number or client contact is on screen` | the widget tree text contains no `+20` and no `010` |
| same | `budget: list state 390x844, 375x667, EN and AR, 200 percent` | `countControlsAboveFold(tester, includeChrome:false) <= 5`; `filledPrimaryActions == 0`; sheet state: `== 1` primary |
Run: `cd app && flutter test test/features/instapay/coach_payments_view_test.dart`

## Verify
- `cd app && dart analyze lib/features/instapay lib/features/private_coaching/presentation/coach lib/routing/app_router.dart` ends `No issues found!`
- the test command ends `All tests passed!`; `cd app && flutter test test/features/private_coaching/coach` still passes.

## Do not
- Do not show a client's phone number or any contact detail (spec 1).
- Do not let a green payment activate by itself unless the coach turned auto-confirm on (WO-10f2).
- Do not put the amount in any notification text.

## Done checklist
- [ ] sheet, PAY4, client-paid sheet, K18 row, router
- [ ] strings; tests EN and AR

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10h2).

UNVERIFIED in this order: 3 (`AppPill` and amber colour names, `activeClients` content, Subscription import in the coach space).
