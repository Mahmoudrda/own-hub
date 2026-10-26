# WO-10e1: PAY1, who to pay, how much, the reference
Depends on: WO-10d0, WO-10d-app (host helper, `InstapayHub`, `payment_text.dart`)
Size: M
Reads first: `app/lib/features/private_coaching/presentation/client/my_coach_view.dart` lines 65-100 and 276-290; `app/lib/routing/app_router.dart` lines 5195-5225 (the `'H05'` builder); `app/lib/ui/app_card.dart` lines 215-240; `app/lib/ui/app_sage_note.dart`; `app/test/helpers/control_counter.dart` lines 160-200; spec sections 4.4, 4.7, 13.2

## Why
The client must send the exact unique amount to the right account, and must be able to copy both without typing. This screen is the whole payment instruction: amount, name, address, reference, three steps, a countdown. It is the only screen where she leaves Own Hub (to her bank app), so it must be calm and complete.

## Final result
On H05 ("My coach") when the coach accepted her and the payment is waiting (subscription status `awaiting_payment`) and the flag is on, a tonal card shows "Your coach accepted you. Pay to start." with one primary "Pay now". That tap opens PAY1.
PAY1 top to bottom (chrome not counted):
1. Top bar: "Pay your coach", back arrow.
2. Card "Pay exactly": the amount large, for example `500.37 EGP`, and a text button "Copy" (copies `500.37`).
3. Card "Pay to": line `Rahma M. (name as shown by your bank)`, under it the address in left-to-right, and a text button "Copy" (copies the address).
4. Line "Reference" `OH-4821` and a text button "Copy"; under it "Put the reference in the transfer note if your bank has one."
5. Three numbered lines: "1. Open your bank app and choose InstaPay." / "2. Send the exact amount to the address above." / "3. Come back here and tap I have paid."
6. "Time left 23:41" (or, when past, "This request has expired. If you already paid, you can still send your proof for 7 days.")
7. Sage note: "Own Hub cannot undo an InstaPay transfer. Before you send, check that the name on your bank's confirmation screen matches the name above."
8. Footer, the one primary: "I have paid".
Controls above the fold at 390x844: back arrow, three "Copy" buttons = 4 others, plus 1 primary. On 375x667 the body scrolls; the primary stays pinned.
Tap count from H05: "Pay now" (1), Copy amount (2), Copy address (3), "I have paid" (4) = 4 taps (spec 7.5 limit 4).
When the coach has no confirmed address, the server refuses `create_payment` with reason `coach_not_ready`; the screen then shows only the text "Your coach has not set up payments yet. Message her." and no primary.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/presentation/payment_view.dart | create | PAY1 |
| app/lib/features/instapay/presentation/pay_card.dart | create | the card shown on H05 |
| app/lib/features/private_coaching/presentation/client/my_coach_view.dart | edit | `onPay` parameter and the card |
| app/lib/routing/app_router.dart | edit | pass `onPay` in the `'H05'` builder |
| app/test/features/instapay/payment_view_test.dart | create | PAY1 tests |
| app/test/features/private_coaching/client/my_coach_pay_card_test.dart | create | the H05 card test |

## Steps
1. File `app/lib/features/instapay/presentation/pay_card.dart` (create):
```dart
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';

/// Shown on H05 while the coach waits for her payment.
class PayCard extends StatelessWidget {
  const PayCard({super.key, required this.onPay});
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      variant: AppCardVariant.tonal,
      children: [
        Text(l10n.yourCoachAcceptedYouPayToStart, style: AppText.titleM),
        AppButton(l10n.payNow, key: const ValueKey('pay-now'), onPressed: onPay),
      ],
    );
  }
}
```
2. File `app/lib/features/private_coaching/presentation/client/my_coach_view.dart`. In the `MyCoachView` constructor (about line 66-80) add `this.onPay,` after `this.onFind,`; in the field list (about line 100) add:
```dart
  /// Opens PAY1. Null hides the pay card (the flag is off).
  final VoidCallback? onPay;
```
Add the import `import '../../../instapay/presentation/pay_card.dart';`. Add a getter beside `_requested` (about line 116):
```dart
  bool get _awaitingPayment =>
      widget.subscription.status == SubscriptionStatus.awaitingPayment;
```
Anchor: the chain `else if (_requested)\n                  ..._waiting(l10n, name)` (about line 283). Replace:
```dart
                else if (_requested)
                  ..._waiting(l10n, name)
                else if (_closed)
```
with:
```dart
                else if (_requested)
                  ..._waiting(l10n, name)
                else if (_awaitingPayment && widget.onPay != null)
                  PayCard(onPay: widget.onPay!)
                else if (_closed)
```
UNVERIFIED: `requestClosed(sub)` (the `_closed` test) may be true for `awaitingPayment`; check `grep -n "bool requestClosed" -A8 app/lib/features/private_coaching/presentation/client/my_coach_view.dart`. If it is true for that status the new branch above never runs because it sits before `_closed`; good either way.
3. File `app/lib/routing/app_router.dart`. Anchor: in the `'H05'` builder, the line `onMessage: sub.relId.isEmpty` (about line 5208). Add directly above it:
```dart
        onPay: featureFlags.isOn(Feature.instapayPayments)
            ? () => unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PaymentView(
                      subId: sub.id,
                      packageId: sub.packageId,
                      onIHavePaid: (payment) {}, // WO-10e4 replaces this line
                    ),
                  ),
                ),
              )
            : null,
```
Add the import `import '../features/instapay/presentation/payment_view.dart';` (keep imports sorted as the file does). `Feature` is already imported in this file (used by `screenFeatures`); UNVERIFIED, check `grep -n "feature_flags.dart" app/lib/routing/app_router.dart`.
4. File `app/lib/features/instapay/presentation/payment_view.dart` (create). Full content:
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/instapay_models.dart';
import 'payment_text.dart';

/// PAY1: what to pay, to whom, with which reference.
class PaymentView extends StatefulWidget {
  const PaymentView({
    super.key,
    required this.subId,
    required this.packageId,
    required this.onIHavePaid,
    this.repository,
    this.now,
    this.onBack,
  });

  final String subId;
  final String packageId;
  final ValueChanged<Payment> onIHavePaid;
  final InstapayRepository? repository;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  Payment? _payment;
  String _error = '';
  bool _notReady = false;
  Timer? _tick;
  late final String _key = InstapayLocalStore.newKey();

  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Reuses her open payment for this package (one open payment per package,
  /// spec 4.6); otherwise creates one. The key makes a retry safe.
  Future<void> _open() async {
    final repo = _repo;
    if (repo == null) return;
    final locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    try {
      final mine = await repo.watchMyPaymentsAsClient().first;
      final open = mine.where((p) => p.packageId == widget.packageId &&
          (p.status == PaymentStatus.awaitingPayment || p.status == PaymentStatus.expired)).firstOrNull;
      if (open != null && open.address.address.isNotEmpty) {
        if (mounted) setState(() => _payment = open);
        return;
      }
      final created = await repo.createPayment(
        subId: widget.subId,
        packageId: widget.packageId,
        idempotencyKey: _key,
        locale: locale,
      );
      // The server document has the address snapshot; wait for it.
      final full = await repo.watchPayment(created.id).firstWhere((p) => p != null && p.address.address.isNotEmpty);
      if (mounted) setState(() => _payment = full);
    } on PaymentFailure catch (f) {
      if (!mounted) return;
      final l10n = AppL10n.of(context);
      setState(() {
        _notReady = f.reason == 'coach_not_ready';
        _error = _notReady ? '' : paymentFailureText(l10n, f);
      });
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppL10n.of(context).copied)));
  }

  String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  Widget _copyButton(String label, String value, Key key) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: AppButton(label, key: key, variant: AppButtonVariant.text, height: 44, fontSize: 15,
        icon: Icons.copy_outlined, onPressed: () => unawaited(_copy(value))),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = _payment;
    final left = p?.timeLeft(_now) ?? Duration.zero;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.payYourCoach,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      children: [
        if (_notReady) Text(l10n.yourCoachHasNotSetUpPaymentsYetMessageHer, style: AppText.titleM),
        if (_error.isNotEmpty)
          Semantics(liveRegion: true, child: Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error))),
        if (p == null && !_notReady && _error.isEmpty) const Center(child: CircularProgressIndicator()),
        if (p != null) ...[
          AppCard(children: [
            Text(l10n.payExactly, style: AppText.bodyM),
            Semantics(
              label: p.amountText(arabic: arabic),
              child: Text(p.amountText(arabic: arabic), key: const ValueKey('pay-amount'), style: AppText.titleL),
            ),
            _copyButton(l10n.copy, egpPlain(p.amountPiasters), const ValueKey('copy-amount')),
          ]),
          AppCard(children: [
            Text(l10n.payTo, style: AppText.bodyM),
            Text(l10n.nameNameAsShownByYourBank(p.address.accountName), style: AppText.titleM),
            Text(p.address.address, key: const ValueKey('pay-address'), textDirection: TextDirection.ltr, style: AppText.titleM),
            _copyButton(l10n.copy, p.address.address, const ValueKey('copy-address')),
          ]),
          AppCard(children: [
            Text('${l10n.reference}  ${p.reference}', key: const ValueKey('pay-reference'), textDirection: TextDirection.ltr, style: AppText.titleM),
            Text(l10n.putTheReferenceInTheTransferNoteIfYourBankHasOne, style: AppText.bodyM),
            _copyButton(l10n.copy, p.reference, const ValueKey('copy-reference')),
          ]),
          Text(l10n.step1OpenYourBankAppAndChooseInstapay, style: AppText.bodyM),
          Text(l10n.step2SendTheExactAmountToTheAddressAbove, style: AppText.bodyM),
          Text(l10n.step3ComeBackHereAndTapIHavePaid, style: AppText.bodyM),
          left > Duration.zero
              ? Text(l10n.timeLeftTime(_clock(left)), key: const ValueKey('pay-left'), style: AppText.bodyM)
              : Text(l10n.thisRequestHasExpiredIfYouAlreadyPaid, key: const ValueKey('pay-expired'), style: AppText.bodyM),
          AppSageNote(l10n.ownHubCannotUndoAnInstapayTransfer),
        ],
      ],
      footer: [
        if (p != null)
          AppButton(l10n.iHavePaid, key: const ValueKey('i-have-paid'), onPressed: () => widget.onIHavePaid(p)),
      ],
    );
  }
}

/// "500.37" for the bank's amount box. Western digits, no currency.
String egpPlain(int piasters) {
  final rest = piasters % 100;
  return rest == 0 ? '${piasters ~/ 100}' : '${piasters ~/ 100}.${rest.toString().padLeft(2, '0')}';
}
```
The getters shown are placeholders; use those `add_strings.py` prints (step 5) and fix the file. `l10n.copy` and `l10n.copied` may exist already.
UNVERIFIED: `AppCard(children: [...])` positional-free form is right (signature in the brief: `AppCard({required List<Widget> children, ...})`); `firstOrNull` on `Iterable` is fine in Dart 3.
5. Add the strings (next section), then fix the getter names in `payment_view.dart` and `pay_card.dart`.

## Strings to add
File `app/tool/_wo10e1_strings.json`. Drop any key already present (`grep -n '"KEY"' 6-v2/i18n/ar-extra.json 6-v2/i18n/ar.json`). Parameterised (add a `description` and a `placeholders` entry each): `{name} (name as shown by your bank)` with `name` String example `Rahma M.`; `Time left {time}` with `time` String example `23:41`.
| English (key) | Egyptian Arabic |
|---|---|
| Your coach accepted you. Pay to start. | مدرّبتك قبلتك. ادفعي عشان تبدأي. |
| Pay now | ادفعي دلوقتي |
| Pay your coach | ادفعي لمدرّبتك |
| Pay exactly | ادفعي بالظبط |
| Pay to | ادفعي لـ |
| {name} (name as shown by your bank) | {name} (الاسم زي ما البنك بيعرضه) |
| Reference | الرقم المرجعي |
| Copy | انسخي |
| Copied | اتنسخ |
| Put the reference in the transfer note if your bank has one. | اكتبي الرقم المرجعي في ملاحظة التحويل لو البنك عنده خانة ملاحظة. |
| 1. Open your bank app and choose InstaPay. | 1. افتحي تطبيق البنك واختاري إنستا باي. |
| 2. Send the exact amount to the address above. | 2. ابعتي المبلغ بالظبط على العنوان اللي فوق. |
| 3. Come back here and tap I have paid. | 3. ارجعي هنا واضغطي دفعت. |
| Time left {time} | الوقت المتبقي {time} |
| This request has expired. If you already paid, you can still send your proof for 7 days. | الطلب ده انتهى. لو دفعتي بالفعل، تقدري تبعتي إثبات الدفع خلال 7 أيام. |
| Own Hub cannot undo an InstaPay transfer. Before you send, check that the name on your bank's confirmation screen matches the name above. | Own Hub مابتقدرش ترجّع تحويل إنستا باي. قبل ما تبعتي، اتأكدي إن الاسم في شاشة تأكيد البنك زي الاسم اللي فوق. |
| I have paid | دفعت |
| Your coach has not set up payments yet. Message her. | مدرّبتك لسه ماظبطتش الدفع. ابعتيلها رسالة. |

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| payment_view_test.dart | `shows amount, name, address and reference` | fake repo with no payments; pump `PaymentView(subId:'s', packageId:'pk', onIHavePaid:(_){}, repository: fake)`; `pumpAndSettle`; find `pay-amount` text `500.37 EGP`, `Rahma M.` text, `pay-address` `rahma@instapay`, `pay-reference` contains `OH-4821` |
| same | `copy buttons put the right text on the clipboard` | mock `SystemChannels.platform` `Clipboard.setData`; tap `copy-amount` then `copy-address` then `copy-reference`; recorded texts are `500.37`, `rahma@instapay`, `OH-4821` |
| same | `an open payment for the package is reused` | `fake.setPayments([awaiting payment with packageId pk and address])`; pump; `fake.calls` has no `createPayment` |
| same | `I have paid hands the payment to the callback` | tap `i-have-paid`; callback got id `p1` |
| same | `expired payment shows the 7 day sentence and keeps the primary` | payment `expiresAt` in the past; `pay-expired` found; `i-have-paid` found |
| same | `coach_not_ready shows the message and no primary` | `fake.failNext = const PaymentFailure('coach_not_ready')`; no `i-have-paid` |
| same | `budget and layout, EN and AR, 390x844, 375x667, 200 percent` | `countControlsAboveFold(tester, includeChrome:false) <= 5` at 390x844; `filledPrimaryActions == 1`; no `takeException`; the same in Arabic |
| same | `tap count from H05 is 4` | document in the test name only: count the taps in the widget test of the card: `pay-now`, `copy-amount`, `copy-address`, `i-have-paid`; assert the four finders each exist once |
| my_coach_pay_card_test.dart | `the pay card shows only while awaiting payment and the callback is set` | `MyCoachView` with a subscription in `awaitingPayment` and `onPay` set shows `pay-now`; with `onPay` null shows none; with status `active` shows none (use `fixtures.dart` and `FakeCoachingRepository`; UNVERIFIED subscription fixture name: `grep -n "Subscription " app/test/features/private_coaching/support/fixtures.dart`) |
Run: `cd app && flutter test test/features/instapay/payment_view_test.dart test/features/private_coaching/client`

## Verify
- `cd app && dart analyze lib/features/instapay lib/features/private_coaching/presentation/client lib/routing/app_router.dart` ends `No issues found!`
- the two test commands above end `All tests passed!`
- `cd app && flutter test test/qa` still passes.

## Do not
- Do not let the client type or edit the amount or address (spec section 1).
- Do not show the coach's phone number anywhere.
- Do not write the amount or address to analytics or logs.
- Do not change the "Ask to join" path or the free-coaching text (`freeWhileOwnHubOpensCoaching`) in `join_coach_sheet.dart`: WO-10p decides when it changes.
- No em dashes.

## Done checklist
- [ ] card on H05, PAY1, router wiring
- [ ] strings and getters
- [ ] tests pass EN and AR, both phone sizes, 200 percent

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10e2).

UNVERIFIED in this order: 4 (`requestClosed` for awaitingPayment, Feature import in app_router, subscription fixture name, AppCard children form).
