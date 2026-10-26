# WO-10j1: payment notifications (texts in English and Egyptian Arabic) and opening a screen from a push
Depends on: WO-10d0, WO-10f1, WO-10e5. Touches two server files (`functions/coaching/push.py`, `functions/coaching/coaching_contract.json`): tell the server agent in QUESTIONS.md before editing so the two agents do not clash.
Size: M
Reads first: `functions/coaching/push.py` (all, 100 lines); `functions/tests/test_coaching_push.py` lines 50-70; `functions/coaching/coaching_contract.json` lines 403-418; `app/lib/features/private_coaching/domain/coaching_contract.dart` lines 412-426; `app/lib/app_state/notification_taps.dart` lines 1-60; `app/lib/main.dart` lines 388-400; spec section 8

## Why
Every payment step tells the other woman, in calm words, that she should open the app. The lock screen is read by whoever holds the phone, so no text names a coach or a client or carries an amount (spec 8 default; spec 13.12 item 8 asks that the coach sees the amount and transaction number, which she does on screen after she opens the app, WO-10f1). Today the app opens no screen from a remote push (only local reminders do, `NotificationTaps`), so this order also adds the tap, which is what makes "2 taps from the notification" true.

## Final result
Thirteen new push kinds with texts below. A woman who taps a payment push lands on the right screen: a client on "My coach" (H05, where the pay card or the "See your payment" card is one tap from PAY3), a coach on PAY4 (which opens the single waiting payment by itself) or PAY9 for the statement.

| kind | to | English | Egyptian Arabic |
|---|---|---|---|
| instapayReminder | client | Your payment request is still open. Open Own Hub when you are ready. | طلب الدفع لسه مفتوح. افتحي Own Hub لما تبقي جاهزة. |
| instapayConfirmed | client | Your coach confirmed your payment. | مدرّبتك أكدت دفعك. |
| instapayNotReceived | client | There is news about your payment. Open Own Hub to see it. | فيه خبر عن دفعك. افتحي Own Hub وشوفيه. |
| instapayReviewStarted | client | Own Hub is looking at your payment. | Own Hub بتبص على دفعك. |
| instapayReviewDecided | client | Own Hub finished looking at your payment. Open Own Hub to see it. | Own Hub خلّصت مراجعة دفعك. افتحي Own Hub وشوفي. |
| instapayRefundRecorded | client | A refund was recorded for you. | اتسجّل ليكي استرداد. |
| instapayCoachReported | client | Your coach says you paid. Open Own Hub to answer. | مدرّبتك بتقول إنك دفعتي. افتحي Own Hub وردّي. |
| instapayAddressChanged | client | Your coach is changing where payments go. Open Own Hub before you pay. | مدرّبتك بتغيّر عنوان استلام الدفع. افتحي Own Hub قبل ما تدفعي. |
| instapayProofSent | coach | A client sent proof of a payment. Open Own Hub to check your bank. | عميلة بعتت إثبات دفع. افتحي Own Hub واتشيكي على البنك. |
| instapayCoachReminder | coach | A payment is still waiting for you. Open Own Hub. | فيه دفعة لسه مستنياكي. افتحي Own Hub. |
| instapayDisputeOpened | coach | There is news about a payment. Open Own Hub to see it. | فيه خبر عن دفعة. افتحي Own Hub وشوفيه. |
| instapayCoachReviewDecided | coach | Own Hub finished looking at a payment. Open Own Hub to see it. | Own Hub خلّصت مراجعة دفعة. افتحي Own Hub وشوفي. |
| instapayStatementReady | coach | Your monthly statement is ready. | كشف الشهر جاهز. |
Title for all: `Own Hub`. No amounts, names, references, no loss or guilt words, no em dashes, no digits. Payload is `{"kind": <kind>}` and nothing else (as `functions/coaching/push.py` says).

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| functions/coaching/push.py | edit | the 13 texts |
| functions/coaching/coaching_contract.json | edit | `pushKinds` gets the 13 kinds |
| app/lib/features/private_coaching/domain/coaching_contract.dart | edit | `pushKinds` gets the same 13 |
| app/lib/features/instapay/data/payment_push_taps.dart | create | remote tap to screen |
| app/lib/main.dart | edit | start it beside `NotificationTaps.start` |
| functions/tests/test_instapay_push_texts.py | create | text rules |
| app/test/features/instapay/payment_push_taps_test.dart | create | routing |

## Steps
1. File `functions/coaching/push.py`. Anchor: the closing `}` of the `TEXT` dict, after the `"payoutRecorded"` entry (about line 59-60). Add before that `}`:
```python
    "instapayReminder": {
        "en": (TITLE, "Your payment request is still open. Open Own Hub when you are ready."),
        "ar": (TITLE, "طلب الدفع لسه مفتوح. افتحي Own Hub لما تبقي جاهزة."),
    },
    "instapayConfirmed": {
        "en": (TITLE, "Your coach confirmed your payment."),
        "ar": (TITLE, "مدرّبتك أكدت دفعك."),
    },
    "instapayNotReceived": {
        "en": (TITLE, "There is news about your payment. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن دفعك. افتحي Own Hub وشوفيه."),
    },
    "instapayReviewStarted": {
        "en": (TITLE, "Own Hub is looking at your payment."),
        "ar": (TITLE, "Own Hub بتبص على دفعك."),
    },
    "instapayReviewDecided": {
        "en": (TITLE, "Own Hub finished looking at your payment. Open Own Hub to see it."),
        "ar": (TITLE, "Own Hub خلّصت مراجعة دفعك. افتحي Own Hub وشوفي."),
    },
    "instapayRefundRecorded": {
        "en": (TITLE, "A refund was recorded for you."),
        "ar": (TITLE, "اتسجّل ليكي استرداد."),
    },
    "instapayCoachReported": {
        "en": (TITLE, "Your coach says you paid. Open Own Hub to answer."),
        "ar": (TITLE, "مدرّبتك بتقول إنك دفعتي. افتحي Own Hub وردّي."),
    },
    "instapayAddressChanged": {
        "en": (TITLE, "Your coach is changing where payments go. Open Own Hub before you pay."),
        "ar": (TITLE, "مدرّبتك بتغيّر عنوان استلام الدفع. افتحي Own Hub قبل ما تدفعي."),
    },
    "instapayProofSent": {
        "en": (TITLE, "A client sent proof of a payment. Open Own Hub to check your bank."),
        "ar": (TITLE, "عميلة بعتت إثبات دفع. افتحي Own Hub واتشيكي على البنك."),
    },
    "instapayCoachReminder": {
        "en": (TITLE, "A payment is still waiting for you. Open Own Hub."),
        "ar": (TITLE, "فيه دفعة لسه مستنياكي. افتحي Own Hub."),
    },
    "instapayDisputeOpened": {
        "en": (TITLE, "There is news about a payment. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن دفعة. افتحي Own Hub وشوفيه."),
    },
    "instapayCoachReviewDecided": {
        "en": (TITLE, "Own Hub finished looking at a payment. Open Own Hub to see it."),
        "ar": (TITLE, "Own Hub خلّصت مراجعة دفعة. افتحي Own Hub وشوفي."),
    },
    "instapayStatementReady": {
        "en": (TITLE, "Your monthly statement is ready."),
        "ar": (TITLE, "كشف الشهر جاهز."),
    },
```
2. File `functions/coaching/coaching_contract.json`. Anchor: `"portfolioDecision"\n    ],\n    "reportDecision": [` (about line 415). Replace `"portfolioDecision"` by `"portfolioDecision",` and the 13 kinds in the order of the table, each on its own line in double quotes, the last without a comma. File `app/lib/features/private_coaching/domain/coaching_contract.dart`: anchor `'portfolioDecision',\n  ];\n  static const List<String> reportDecision` (about line 425). Add the same 13 kinds as single-quoted strings with trailing commas after `'portfolioDecision',`. The two lists must match in order: `functions/tests/test_coaching_contract.py` line 83 and `app/test/features/private_coaching/server_docs_test.dart` compare them (UNVERIFIED: `grep -n "pushKinds" app/test -r`).
3. File `app/lib/features/instapay/data/payment_push_taps.dart` (create). Full content:
```dart
/// A tap on a payment push (the app was in the background or closed), turned
/// into a screen. The payload is the kind and nothing else; the route is
/// pushed by name or as a screen, so the verification gate and the feature
/// flags still apply (`Feature.instapayPayments` must be on).
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../app_state/private_coaching_state.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../routing/app_router.dart';
import '../../../routing/app_routes.dart';
import '../presentation/coach_payments_view.dart';
import '../presentation/fee_statement_view.dart';

enum PaymentPushTarget { myCoach, coachPayments, statement }

class PaymentPushTaps {
  PaymentPushTaps._();

  static const Map<String, PaymentPushTarget> targets = {
    'instapayReminder': PaymentPushTarget.myCoach,
    'instapayConfirmed': PaymentPushTarget.myCoach,
    'instapayNotReceived': PaymentPushTarget.myCoach,
    'instapayReviewStarted': PaymentPushTarget.myCoach,
    'instapayReviewDecided': PaymentPushTarget.myCoach,
    'instapayRefundRecorded': PaymentPushTarget.myCoach,
    'instapayCoachReported': PaymentPushTarget.myCoach,
    'instapayAddressChanged': PaymentPushTarget.myCoach,
    'instapayProofSent': PaymentPushTarget.coachPayments,
    'instapayCoachReminder': PaymentPushTarget.coachPayments,
    'instapayDisputeOpened': PaymentPushTarget.coachPayments,
    'instapayCoachReviewDecided': PaymentPushTarget.coachPayments,
    'instapayStatementReady': PaymentPushTarget.statement,
  };

  /// Null for a kind that is not a payment kind or is not for this build.
  static PaymentPushTarget? targetFor(Object? kind) => kind is String ? targets[kind] : null;

  static bool _started = false;

  static void start(GlobalKey<NavigatorState> key) {
    if (_started) return;
    _started = true;
    FirebaseMessaging.onMessageOpenedApp.listen((m) => open(key, m.data['kind']), onError: (Object _) {});
    unawaited(
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m != null) open(key, m.data['kind']);
      }).catchError((Object _) {}),
    );
  }

  /// Visible for tests: opens the screen for [kind] on [key].
  static void open(GlobalKey<NavigatorState> key, Object? kind) {
    final target = targetFor(kind);
    final nav = key.currentState;
    if (target == null || nav == null) return;
    if (!AppRouter.featureFlags.isOn(Feature.instapayPayments)) return;
    switch (target) {
      case PaymentPushTarget.myCoach:
        unawaited(nav.pushNamed(appRoutes['H05']!.name));
      case PaymentPushTarget.coachPayments:
        unawaited(nav.push<void>(MaterialPageRoute<void>(
          builder: (_) => CoachPaymentsView(clients: PrivateCoachingState.instance.activeClients),
        )));
      case PaymentPushTarget.statement:
        unawaited(nav.push<void>(MaterialPageRoute<void>(builder: (_) => const FeeStatementView())));
    }
  }
}
```
UNVERIFIED: `AppRouter.featureFlags` is a static (the budget test sets `AppRouter.featureFlags = ...`, so yes); pushing `H05` by name passes through the verification gate (`onGenerateRoute`, `app_router.dart` about line 529-552); the screen decision on a not-yet-signed-in phone is the gate's. A tap on a coach kind from a phone without the coach claim opens PAY4 with an empty list; acceptable (the server only sends coach kinds to coaches).
4. File `app/lib/main.dart`. Anchor: the line `NotificationTaps.start(_navigatorKey);` (line 396). Add directly below it: `PaymentPushTaps.start(_navigatorKey);` and the import `import 'features/instapay/data/payment_push_taps.dart';` (UNVERIFIED: this fires only when Firebase is up; `FirebaseMessaging.instance` throws when it is not, so wrap: `if (FirebaseBoot.isReady) PaymentPushTaps.start(_navigatorKey);` using the import of `FirebaseBoot` that `main.dart` already has: `grep -n "FirebaseBoot" app/lib/main.dart | head -3`).
5. File `functions/tests/test_instapay_push_texts.py` (create):
```python
"""Payment pushes: calm, generic, in both languages."""

import re

import pytest

from coaching import common, push

KINDS = [k for k in push.TEXT if k.startswith("instapay")]
BAD = re.compile(r"lost|fail|miss|fraud|cheat|fake|false|loss|خسر|فشل|احتيال|كدب|مزور", re.I)


def test_all_thirteen_kinds_exist_in_the_contract():
    assert len(KINDS) == 13
    assert set(KINDS) <= set(common.ENUMS["pushKinds"])


@pytest.mark.parametrize("kind", KINDS)
@pytest.mark.parametrize("lang", ["en", "ar"])
def test_text_is_generic_and_calm(kind, lang):
    title, body = push.TEXT[kind][lang]
    assert title == "Own Hub"
    assert not re.search(r"[0-9٠-٩]", body), "no amounts or numbers on a lock screen"
    assert "—" not in body and "–" not in body
    assert not BAD.search(body)
    assert len(body) <= 90


@pytest.mark.parametrize("kind", KINDS)
def test_both_languages_present(kind):
    assert set(push.TEXT[kind]) == {"en", "ar"}
```

## Strings to add
None in the app (push texts live on the server).

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| functions/tests/test_instapay_push_texts.py | as in step 5 | run `cd functions && venv/bin/python -m pytest tests/test_instapay_push_texts.py tests/test_coaching_push.py tests/test_coaching_contract.py -q` (UNVERIFIED runner: `ls functions/venv/bin | head`) |
| payment_push_taps_test.dart | `every client kind maps to myCoach, every coach kind to coachPayments, the statement kind to statement` | table in the test; 13 entries |
| same | `an unknown kind or a non-string opens nothing` | `targetFor('newMessage')` null; `targetFor(5)` null |
| same | `open pushes the right screen when the flag is on and nothing when off` | `MaterialApp(navigatorKey: key, routes: {appRoutes['H05']!.name: ...}, home: ...)`; flag on: `open(key,'instapayProofSent')` shows `CoachPaymentsView` (with `InstapayHub.override = fake`); flag off (`AppRouter.featureFlags = AppRouter.featureFlags.with_({Feature.instapayPayments:false})`): nothing pushed |
| coaching contract tests (existing) | `pushKinds match between JSON and Dart` | stay green |
Run: `cd app && flutter test test/features/instapay/payment_push_taps_test.dart test/features/private_coaching/server_docs_test.dart`

## Verify
- the pytest command ends with `passed` and no failures; the flutter command ends `All tests passed!`
- Manual on the Android emulator with a staging project: send a data push `{kind: instapayProofSent}` with the Firebase console "test message" while the app is in the background; tapping opens PAY4 and the sheet for a single waiting payment.

## Do not
- Do not put an amount, a name, a reference or a payment id in a push (payload is the kind only).
- Do not add a kind without adding it to BOTH contract lists and to `TEXT` (the existing test enforces it).
- Do not open anything when the flag is off.
- No em dashes.

## Done checklist
- [ ] 13 texts, both contract lists, tap routing, main.dart, tests green

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10j3).

UNVERIFIED in this order: 4 (pytest runner path, the Dart-side contract test name, `H05` named push through the gate, `FirebaseBoot` use in main.dart).
