# WO-10e5: PAY3 (status) and PAY6 (add proof after a dispute)
Depends on: WO-10e4
Size: L
Reads first: `app/lib/features/instapay/presentation/proof_view.dart`; `app/lib/features/instapay/presentation/pay_card.dart`; `app/lib/features/private_coaching/presentation/client/my_coach_view.dart` lines 276-290; `app/lib/routing/app_router.dart` the `'H05'` builder; spec sections 3, 4.1, 4.3, 4.5, 4.7, 13.4

## Why
After she sends proof she needs to know, in plain words, where her payment is, what happens next, and the one thing she can do. The same screen carries the calm messages for every outcome (green, amber, red, not received, in review, decided). PAY6 is the proof screen again, used after the coach says she did not receive it.

## Final result
PAY3 top to bottom:
1. Top bar "Your payment", back arrow.
2. A summary card: the amount (`500.37 EGP`), the reference, and the status in words (see table).
3. One "what happens next" line (table).
4. When green and access is open (status `proof_submitted`, `riskOutcome` green, `accessUntil` in the future): a tonal line "You can start now. This stays open until {date} while your coach confirms." / "تقدري تبدأي دلوقتي. ده مفتوح لحد {date} لحد ما مدرّبتك تأكد."
5. Amber (status `proof_submitted`, `riskOutcome` amber): "Your coach is checking her bank. This can take up to a day." / "مدرّبتك بتتشيك على البنك. ممكن ده ياخد لحد يوم."
6. Red: "We could not match this payment. Add your bank's transaction history and Own Hub will look at it." / "ماقدرناش نطابق الدفع ده. ضيفي كشف المعاملات من البنك وOwn Hub هتبص عليه." and the primary is "Add proof".
7. A timeline: one row per event, newest last: time in Cairo time, then the sentence (table). Rows are plain text, not controls.
8. When the coach reported the payment herself (`reportedByCoach` true, status `proof_submitted`, no proof from her): a card "Your coach says you paid {reference}. Is that right?" / "مدرّبتك بتقول إنك دفعتي {reference}. ده صح؟" with two buttons: "Yes, I paid" (filled, the one primary of the screen, the footer one is then hidden) and "No" (text). They call `clientConfirmReport(accept: true/false)`.
9. Footer: the one primary, by state:
| status | primary label (EN / AR) | does |
|---|---|---|
| awaiting_payment | Pay now / ادفعي دلوقتي | opens PAY1 for the same package |
| expired | Send my proof / ابعتي إثبات الدفع | opens PAY2 (proof within 7 days of `createdAt`; after 7 days no primary) |
| different_amount | Pay the rest / ادفعي الباقي | opens PAY1 with a new request |
| coach_not_received, or red | Add proof / ضيفي إثبات | opens PAY6 (PAY2 with `addEvidence: true`) |
| confirmed, resolved_paid | Open my coaching / افتحي التدريب بتاعي | pops back to H05 |
| every other status | none | |
Controls above the fold: back arrow + at most 1 text button (the coach-report "No") = 2 others + 1 primary. The timeline never counts.
Status words and next lines:
| status | status word | next line |
|---|---|---|
| awaiting_payment | Waiting for your payment / مستنيين دفعك | Pay with your bank app, then tap I have paid. / ادفعي من تطبيق البنك وبعدين اضغطي دفعت. |
| proof_submitted | Proof sent / الإثبات اتبعت | Your coach will confirm. If she does not answer in 3 days, Own Hub reviews it. / مدرّبتك هتأكد. لو ماردتش خلال 3 أيام، Own Hub بتراجعه. |
| confirmed | Confirmed / اتأكد | All set. Your coaching is active. / تمام. التدريب بتاعك شغال. |
| resolved_paid | Confirmed after review / اتأكد بعد المراجعة | All set. Your coaching is active. |
| coach_not_received | Your coach says it has not arrived / مدرّبتك بتقول إن الفلوس ماوصلتش | Add your bank's transaction screenshot and Own Hub will look at it. / ضيفي لقطة معاملة من البنك وOwn Hub هتبص عليها. |
| in_review | Under review / تحت المراجعة | Own Hub is looking at both sides. This usually takes up to two working days. / Own Hub بتبص على الطرفين. ده عادةً بيخد لحد يومين شغل. |
| resolved_unpaid | Review done / المراجعة خلصت | We could not find the payment. If you think this is wrong, write to support. / ماقدرناش نلاقي الدفع. لو شايفة إن ده غلط، اكتبي للدعم. |
| different_amount | Different amount / مبلغ مختلف | Your coach received {amount}. Pay the rest to start. / مدرّبتك استلمت {amount}. ادفعي الباقي عشان تبدأي. |
| expired | Expired / انتهى | If you already paid, you can send your proof for 7 days. / لو دفعتي بالفعل، تقدري تبعتي إثبات الدفع خلال 7 أيام. |
| cancelled | Cancelled / اتلغى | Nothing was paid. / ماتدفعش حاجة. |
| refund_requested | Refund asked / طلبتي استرداد | Your coach has 3 days to answer. Then Own Hub steps in. / مدرّبتك عندها 3 أيام تردّ. وبعدها Own Hub بتتدخل. |
| refunded | Refunded / اتسجّل الاسترداد | Your coach recorded the refund. / مدرّبتك سجّلت الاسترداد. |
| refund_denied | Refund not agreed / الاسترداد ماتوافقش عليه | Own Hub will look at it. / Own Hub هتبص عليه. |
| service_dispute | Problem reported / المشكلة اتبلّغ عنها | Own Hub is looking into it. / Own Hub بتبص في الموضوع. |
Timeline sentences by the event's `to`: awaiting_payment "Payment request created" / "اتعمل طلب الدفع"; proof_submitted "You sent your proof" / "بعتي إثبات الدفع"; confirmed "Your coach confirmed it" / "مدرّبتك أكدت الدفع"; coach_not_received "Your coach says it has not arrived" / "مدرّبتك بتقول إن الفلوس ماوصلتش"; in_review "Own Hub started a review" / "Own Hub بدأت المراجعة"; resolved_paid "Review done: your payment counts" / "المراجعة خلصت: دفعك اتحسب"; resolved_unpaid "Review done: we could not find the payment" / "المراجعة خلصت: ماقدرناش نلاقي الدفع"; different_amount "Your coach received a different amount" / "مدرّبتك استلمت مبلغ مختلف"; expired "The request expired" / "الطلب انتهى"; cancelled "Cancelled" / "اتلغى"; refund_requested "You asked for a refund" / "طلبتي استرداد"; refunded "Refund recorded" / "اتسجّل الاسترداد"; refund_denied "Refund not agreed" / "الاسترداد ماتوافقش عليه"; service_dispute "You reported a problem with the service" / "بلّغتي عن مشكلة في الخدمة".
No guilt or loss words anywhere. Times are Cairo time (`Africa/Cairo`), stored UTC.
PAY6 = PAY2 with the top bar "Add proof" and the primary "Send": no new screen file; `ProofView(addEvidence: true)`.
On H05, while the subscription is `payment_review` (or the payment is in any state that is not `awaiting_payment`), the card shows "See your payment" and opens PAY3.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/presentation/status_view.dart | create | PAY3 |
| app/lib/features/instapay/presentation/status_text.dart | create | the words (status, next, timeline) |
| app/lib/features/instapay/domain/instapay_models.dart | edit | `reportedByCoach`, `cairoTime` |
| app/lib/features/instapay/presentation/proof_view.dart | edit | PAY6 title and label |
| app/lib/features/instapay/presentation/pay_card.dart | edit | second card "See your payment" |
| app/lib/features/private_coaching/presentation/client/my_coach_view.dart | edit | show it while the payment is in review |
| app/lib/routing/app_router.dart | edit | `onSent` opens PAY3; `onSeePayment` |
| app/test/features/instapay/status_view_test.dart | create | state tests |

## Steps
1. File `app/lib/features/instapay/domain/instapay_models.dart`. Add `import 'package:timezone/timezone.dart' as tz;` at the top. In class `Payment` add the field `final bool reportedByCoach;` with constructor default `this.reportedByCoach = false,` and in `fromMap` add `reportedByCoach: readBool(m['reportedByCoach']),` (UNVERIFIED field name: compare with WO-10b `coach_report_payment`). Add at the bottom of the file:
```dart
/// Cairo wall-clock time for a stored UTC time. Falls back to UTC+2 when the
/// time zone database is not loaded (UNVERIFIED: `grep -rn "initializeTimeZones" app/lib`).
DateTime cairoTime(DateTime t) {
  try {
    return tz.TZDateTime.from(t.toUtc(), tz.getLocation('Africa/Cairo'));
  } catch (_) {
    return t.toUtc().add(const Duration(hours: 2));
  }
}
```
2. File `app/lib/features/instapay/presentation/status_text.dart` (create). Full content:
```dart
library;

import '../../../l10n/app_l10n.dart';
import '../domain/instapay_models.dart';

String statusWord(AppL10n l, PaymentStatus s) => switch (s) {
  PaymentStatus.awaitingPayment => l.waitingForYourPayment,
  PaymentStatus.proofSubmitted => l.proofSent,
  PaymentStatus.confirmed => l.confirmed,
  PaymentStatus.resolvedPaid => l.confirmedAfterReview,
  PaymentStatus.coachNotReceived => l.yourCoachSaysItHasNotArrived,
  PaymentStatus.inReview => l.underReview,
  PaymentStatus.resolvedUnpaid => l.reviewDone,
  PaymentStatus.differentAmount => l.differentAmount,
  PaymentStatus.expired => l.expired,
  PaymentStatus.cancelled => l.cancelled,
  PaymentStatus.refundRequested => l.refundAsked,
  PaymentStatus.refunded => l.refunded,
  PaymentStatus.refundDenied => l.refundNotAgreed,
  PaymentStatus.serviceDispute => l.problemReported,
};

String nextLine(AppL10n l, Payment p, {required bool arabic}) => switch (p.status) {
  PaymentStatus.awaitingPayment => l.payWithYourBankAppThenTapIHavePaid,
  PaymentStatus.proofSubmitted => l.yourCoachWillConfirmIfSheDoesNotAnswerIn3Days,
  PaymentStatus.confirmed || PaymentStatus.resolvedPaid => l.allSetYourCoachingIsActive,
  PaymentStatus.coachNotReceived => l.addYourBankSTransactionScreenshotAndOwnHubWillLookAtIt,
  PaymentStatus.inReview => l.ownHubIsLookingAtBothSidesThisUsuallyTakesUpToTwo,
  PaymentStatus.resolvedUnpaid => l.weCouldNotFindThePaymentIfYouThinkThisIsWrong,
  PaymentStatus.differentAmount => l.yourCoachReceivedAmountPayTheRestToStart(
    egpText(p.differentAmountPiasters, arabic: arabic)),
  PaymentStatus.expired => l.ifYouAlreadyPaidYouCanSendYourProofFor7Days,
  PaymentStatus.cancelled => l.nothingWasPaid,
  PaymentStatus.refundRequested => l.yourCoachHas3DaysToAnswerThenOwnHubStepsIn,
  PaymentStatus.refunded => l.yourCoachRecordedTheRefund,
  PaymentStatus.refundDenied => l.ownHubWillLookAtIt,
  PaymentStatus.serviceDispute => l.ownHubIsLookingIntoIt,
};

String? timelineSentence(AppL10n l, String to) => switch (to) {
  'awaiting_payment' => l.paymentRequestCreated,
  'proof_submitted' => l.youSentYourProof,
  'confirmed' => l.yourCoachConfirmedIt,
  'coach_not_received' => l.yourCoachSaysItHasNotArrived,
  'in_review' => l.ownHubStartedAReview,
  'resolved_paid' => l.reviewDoneYourPaymentCounts,
  'resolved_unpaid' => l.reviewDoneWeCouldNotFindThePayment,
  'different_amount' => l.yourCoachReceivedADifferentAmount,
  'expired' => l.theRequestExpired,
  'cancelled' => l.cancelled,
  'refund_requested' => l.youAskedForARefund,
  'refunded' => l.refundRecorded,
  'refund_denied' => l.refundNotAgreed,
  'service_dispute' => l.youReportedAProblemWithTheService,
  _ => null,
};
```
(Getter names are placeholders; use the printed ones. The amount-aware string is parameterised: `Your coach received {amount}. Pay the rest to start.`)
3. File `app/lib/features/instapay/presentation/proof_view.dart`. Anchor: `appBar: AppTopBar(title: l10n.sendYourProof,` replace the title with `widget.addEvidence ? l10n.addProof : l10n.sendYourProof`. Anchor: `AppButton(l10n.sendToCoach,` replace the label with `widget.addEvidence ? l10n.send : l10n.sendToCoach`. (`Add proof`, `Send` exist or are added in Strings.)
4. File `app/lib/features/instapay/presentation/status_view.dart` (create). Full content:
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/instapay_models.dart';
import 'payment_text.dart';
import 'status_text.dart';

/// What the one primary does for the current state.
enum StatusAction { pay, sendProof, payRest, addProof, openCoaching }

class PaymentStatusView extends StatefulWidget {
  const PaymentStatusView({
    super.key,
    this.paymentId,
    this.coachUid,
    required this.onAction,
    this.repository,
    this.now,
    this.onBack,
  });

  /// Either the payment, or the coach whose latest payment to show.
  final String? paymentId;
  final String? coachUid;
  final void Function(StatusAction action, Payment payment) onAction;
  final InstapayRepository? repository;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<PaymentStatusView> createState() => _PaymentStatusViewState();
}

class _PaymentStatusViewState extends State<PaymentStatusView> {
  String _error = '';
  bool _busy = false;
  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;
  DateTime get _now => (widget.now ?? DateTime.now)();

  Stream<Payment?> _payment(InstapayRepository r) => widget.paymentId != null
      ? r.watchPayment(widget.paymentId!)
      : r.watchMyPaymentsAsClient().map((l) => l.where((p) => p.coachUid == widget.coachUid).firstOrNull);

  StatusAction? _action(Payment p) {
    final red = p.riskOutcome == RiskOutcome.red && p.status == PaymentStatus.proofSubmitted;
    if (red) return StatusAction.addProof;
    switch (p.status) {
      case PaymentStatus.awaitingPayment:
        return StatusAction.pay;
      case PaymentStatus.expired:
        final created = p.createdAt;
        return created != null && _now.difference(created) <= const Duration(days: 7) ? StatusAction.sendProof : null;
      case PaymentStatus.differentAmount:
        return StatusAction.payRest;
      case PaymentStatus.coachNotReceived:
        return StatusAction.addProof;
      case PaymentStatus.confirmed:
      case PaymentStatus.resolvedPaid:
        return StatusAction.openCoaching;
      default:
        return null;
    }
  }

  String _label(AppL10n l, StatusAction a) => switch (a) {
    StatusAction.pay => l.payNow,
    StatusAction.sendProof => l.sendMyProof,
    StatusAction.payRest => l.payTheRest,
    StatusAction.addProof => l.addProof,
    StatusAction.openCoaching => l.openMyCoaching,
  };

  Future<void> _answer(Payment p, bool yes) async {
    final repo = _repo;
    if (repo == null || _busy) return;
    final l10n = AppL10n.of(context);
    setState(() { _busy = true; _error = ''; });
    try {
      await repo.clientConfirmReport(paymentId: p.id, accept: yes);
    } on PaymentFailure catch (f) {
      if (mounted) setState(() => _error = paymentFailureText(l10n, f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(DateTime t) {
    final c = cairoTime(t);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(c.day)}/${two(c.month)} ${two(c.hour)}:${two(c.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final repo = _repo;
    return StreamBuilder<Payment?>(
      stream: repo == null ? null : _payment(repo),
      builder: (context, snap) {
        final p = snap.data;
        final events = repo == null || p == null ? const Stream<List<PaymentEvent>>.empty() : repo.watchEvents(p.id);
        final action = p == null ? null : _action(p);
        final coachAsks = p != null && p.reportedByCoach && p.status == PaymentStatus.proofSubmitted && p.txnNumber.isEmpty;
        final open = p?.accessUntil != null && p!.accessUntil!.isAfter(_now);
        return AppScaffold(
          showArt: false,
          appBar: AppTopBar(title: l10n.yourPayment, onBack: widget.onBack ?? () => Navigator.of(context).maybePop()),
          children: [
            if (p == null) const Center(child: CircularProgressIndicator()),
            if (p != null) ...[
              AppCard(children: [
                Text(egpText(p.amountPiasters, arabic: arabic), style: AppText.titleL),
                Text('${l10n.reference}  ${p.reference}', textDirection: TextDirection.ltr, style: AppText.bodyM),
                Text(statusWord(l10n, p.status), key: const ValueKey('status-word'), style: AppText.titleM),
              ]),
              Text(nextLine(l10n, p, arabic: arabic), key: const ValueKey('next-line'), style: AppText.bodyM),
              if (p.status == PaymentStatus.proofSubmitted && p.riskOutcome == RiskOutcome.green && open)
                AppCard(variant: AppCardVariant.tonal, children: [
                  Text(l10n.youCanStartNowThisStaysOpenUntilDateWhileYourCoachConfirms(_date(p.accessUntil!)), key: const ValueKey('green-access'), style: AppText.bodyM),
                ]),
              if (p.status == PaymentStatus.proofSubmitted && p.riskOutcome == RiskOutcome.amber)
                Text(l10n.yourCoachIsCheckingHerBankThisCanTakeUpToADay, key: const ValueKey('amber'), style: AppText.bodyM),
              if (p.status == PaymentStatus.proofSubmitted && p.riskOutcome == RiskOutcome.red)
                Text(l10n.weCouldNotMatchThisPaymentAddYourBankSTransactionHistory, key: const ValueKey('red'), style: AppText.bodyM),
              if (coachAsks)
                AppCard(variant: AppCardVariant.tonal, children: [
                  Text(l10n.yourCoachSaysYouPaidReferenceIsThatRight(p.reference), style: AppText.titleM),
                  AppButton(l10n.yesIPaid, key: const ValueKey('report-yes'), onPressed: _busy ? null : () => unawaited(_answer(p, true))),
                  AppButton(l10n.no, key: const ValueKey('report-no'), variant: AppButtonVariant.text, height: 44, fontSize: 15, onPressed: _busy ? null : () => unawaited(_answer(p, false))),
                ]),
              StreamBuilder<List<PaymentEvent>>(
                stream: events,
                builder: (context, es) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in es.data ?? const <PaymentEvent>[])
                      if (timelineSentence(l10n, e.to) != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${e.at == null ? '' : _date(e.at!)}  ${timelineSentence(l10n, e.to)}', style: AppText.bodyM),
                        ),
                  ],
                ),
              ),
              if (_error.isNotEmpty) Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
            ],
          ],
          footer: [
            if (p != null && action != null && !coachAsks)
              AppButton(_label(l10n, action), key: const ValueKey('status-primary'), onPressed: () => widget.onAction(action, p)),
          ],
        );
      },
    );
  }
}
```
UNVERIFIED: the `open` expression uses `p!` after a null-aware check on `p?.accessUntil`; if `dart analyze` complains, write it as `final until = p?.accessUntil; final open = until != null && until.isAfter(_now);`.
5. File `app/lib/features/instapay/presentation/pay_card.dart`. Add a second class below `PayCard`:
```dart
/// Shown on H05 while a payment is with the coach or under review.
class SeePaymentCard extends StatelessWidget {
  const SeePaymentCard({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      variant: AppCardVariant.filled,
      children: [
        Text(l10n.yourPaymentIsOnItsWay, style: AppText.titleM),
        AppButton(l10n.seeYourPayment, key: const ValueKey('see-payment'), variant: AppButtonVariant.outlined, onPressed: onOpen),
      ],
    );
  }
}
```
6. File `my_coach_view.dart`. Add a constructor parameter `this.onSeePayment,` and field `final VoidCallback? onSeePayment;` and a getter `bool get _paymentReview => widget.subscription.status == SubscriptionStatus.paymentReview;`. In the chain from WO-10e1 add after the `PayCard` branch: `else if (_paymentReview && widget.onSeePayment != null) SeePaymentCard(onOpen: widget.onSeePayment!)`.
7. File `app/lib/routing/app_router.dart`. In the `'H05'` builder (a) add next to `onPay:` a parameter `onSeePayment` with the same `featureFlags.isOn(Feature.instapayPayments)` test that pushes `PaymentStatusView(coachUid: sub.coachUid, onAction: ...)`; (b) replace the `onSent` body of WO-10e4 step 6 with a replacement push of PAY3:
```dart
onSent: (result, {required bool queued}) {
  if (queued) {
    ScaffoldMessenger.maybeOf(inner)?.showSnackBar(
      SnackBar(content: Text(AppL10n.of(inner).savedWeWillSendItWhenYouHaveSignal)),
    );
    Navigator.of(inner)..pop()..pop();
    return;
  }
  Navigator.of(inner).pushReplacement<void, void>(
    MaterialPageRoute<void>(
      builder: (_) => PaymentStatusView(paymentId: payment.id, onAction: (a, p) => _payStatusAction(inner, sub, a, p)),
    ),
  );
},
```
and add a static helper in `AppRouter` near `shareCoachInvite`:
```dart
  static void _payStatusAction(BuildContext context, Subscription sub, StatusAction a, Payment p) {
    final nav = Navigator.of(context);
    switch (a) {
      case StatusAction.pay:
      case StatusAction.payRest:
        nav.push<void>(MaterialPageRoute<void>(builder: (_) => PaymentView(
          subId: sub.id, packageId: sub.packageId,
          onIHavePaid: (np) => nav.push<void>(MaterialPageRoute<void>(builder: (_) => ProofView(payment: np, onSent: (r, {required bool queued}) => nav..pop()..pop()))),
        )));
      case StatusAction.sendProof:
        nav.push<void>(MaterialPageRoute<void>(builder: (_) => ProofView(payment: p, onSent: (r, {required bool queued}) => nav.pop())));
      case StatusAction.addProof:
        nav.push<void>(MaterialPageRoute<void>(builder: (_) => ProofView(payment: p, addEvidence: true, onSent: (r, {required bool queued}) => nav.pop())));
      case StatusAction.openCoaching:
        nav.popUntil((r) => r.isFirst || r.settings.name == appRoutes['H05']!.name);
    }
  }
```
UNVERIFIED: `Subscription` is imported in `app_router.dart` (`currentCoachingAsClient()` returns it: check `grep -n "import.*subscription.dart" app/lib/routing/app_router.dart`; the file imports private_coaching as `private`, so the type may be `private.Subscription`); `Payment`, `StatusAction`, `PaymentStatusView`, `ProofView` imports. The `nav..pop()..pop()` inside a lambda returning void is fine.
8. Add the strings, fix getters in `status_text.dart` and `status_view.dart`.

## Strings to add
File `app/tool/_wo10e5_strings.json`. Drop keys already present (`Cancelled`, `Confirmed`, `Expired`, `Refunded`, `No`, `Send`, `Pay now` likely exist). Parameterised: `Your coach received {amount}. Pay the rest to start.` (`amount` String, example `300 EGP`); `You can start now. This stays open until {date} while your coach confirms.` (`date` String, example `27/10 14:32`); `Your coach says you paid {reference}. Is that right?` (`reference` String, example `OH-4821`).
Strings: every English and Arabic pair in the tables of "Final result" above (status words, next lines, timeline sentences) plus: `Your payment` / `دفعك`; `Yes, I paid` / `أيوه، دفعت`; `Pay the rest` / `ادفعي الباقي`; `Add proof` / `ضيفي إثبات`; `Send my proof` / `ابعتي إثبات الدفع`; `Open my coaching` / `افتحي التدريب بتاعي`; `Your payment is on its way` / `دفعك في السكة`; `See your payment` / `شوفي دفعك`; the amber, red and green sentences; `Saved. We will send it when you have signal.` (WO-10e4).

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| status_view_test.dart | `every status shows a word and a next line and never a raw code` | loop `PaymentStatus.values`; `fake.setPayments([payment with that status])`; pump `PaymentStatusView(paymentId:'p1', onAction:..., repository: fake)`; `status-word` and `next-line` found; no text contains `_` |
| same | `primary by state` | table above: awaiting -> `pay`; expired within 7 days -> `sendProof`, after 7 days none; different_amount -> `payRest`; coach_not_received -> `addProof`; confirmed -> `openCoaching`; in_review none; tapping the primary calls `onAction` with that value |
| same | `red proof offers Add proof` | status proof_submitted, risk red: `red` text and `addProof` |
| same | `green access shows the date only while open` | `accessUntil` in the future shows `green-access`; in the past hides it |
| same | `amber shows the bank check line, no primary` | |
| same | `the coach report card asks and sends the answer` | `reportedByCoach: true`; tap `report-yes`; `fake.calls.last.$1 == 'clientConfirmReport'` with accept true; the footer primary is hidden |
| same | `timeline lists events in order in Cairo time` | `fake.events` two events; texts in order; `cairoTime(DateTime.utc(2026,10,27,12,0)).hour` equals 14 or 15 |
| same | `PAY6 reuses PAY2 with the Add proof title` | pump `ProofView(addEvidence:true...)`; top bar text `Add proof`; primary label `Send` |
| same | `budget at 390x844 and 375x667, EN and AR, 200 percent` | `<= 5` others, `filledPrimaryActions <= 1` in awaiting, coach_not_received, confirmed and the coach-report states (the coach-report state must have exactly one filled button) |
Run: `cd app && flutter test test/features/instapay`

## Verify
- `cd app && dart analyze lib/features/instapay lib/routing/app_router.dart lib/features/private_coaching/presentation/client` ends `No issues found!`
- `cd app && flutter test test/features/instapay test/features/private_coaching/client` ends `All tests passed!`

## Do not
- No loss, guilt or blame words about the coach or the client. Do not show the coach's name in a dispute line other than "your coach".
- Do not hide the timeline from a woman whose payment is in review.
- Do not show an amount on a lock screen (not this order, but never add one).

## Done checklist
- [ ] PAY3, text file, PAY6, H05 cards, router
- [ ] tests pass; strings added

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10f1).

UNVERIFIED in this order: 4 (`reportedByCoach` field, time zone database loaded, `Subscription` import alias, null-aware `p!` expression).
