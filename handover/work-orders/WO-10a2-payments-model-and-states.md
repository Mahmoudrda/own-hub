# WO-10a2: InstaPay payments: Python package, errors, limits, the transition table as code, the event writer, idempotency, notices, kill-switch read
Depends on: none (WO-10a is independent, run either first)
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` sections 2, 3, 4.6, 4.17, 8; `functions/coaching/errors.py` lines 1-12 and 100-122; `functions/coaching/common.py` lines 66-80 (`run`, `read`), 192-215 (`refuse`, `bad`), 270-290 (`hours`, `days`, `as_utc`); `functions/coaching/push.py` lines 1-12 and 72-95; `functions/tests/coaching_helpers.py` (all)

## Why
Everything else in the payments server uses one set of limits, one list of legal transitions, one way to write a state change plus its event, and one way to make a repeated tap harmless. Putting them in one small package first means each later order only calls them. Money is stored as integer piasters everywhere in `payments/*` (500.37 EGP is `50037`); there is no second unit anywhere.

## Final result
No screen. A new package `functions/payments/` with:
- `errors.py`: the refusal codes (the app maps each code to its own words). It reuses `coaching.errors.CoachingError` so `main._coaching_call` already turns it into an `HttpsError`.
- `model.py`: `LIMITS`, `STATUSES`, helpers, and `enabled(db)` (reads `config/payments`).
- `states.py`: `TRANSITIONS` (every legal move and who may make it), `check()`, `notices_for()`.
- `engine.py`: `move()` (status change plus one event), `replay()` and `remember()` (idempotency).
- `notices.py`: push texts, English and Egyptian Arabic, no names and no amounts.
- Tests proving every legal transition passes, every other pair of statuses is refused, and a replayed key returns the first answer.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/__init__.py` | create | package marker and the docstring |
| `functions/payments/errors.py` | create | refusal codes |
| `functions/payments/model.py` | create | limits, statuses, `enabled` |
| `functions/payments/states.py` | create | the table, `check`, `notices_for` |
| `functions/payments/engine.py` | create | `move`, `replay`, `remember`, `idem_key` |
| `functions/payments/notices.py` | create | push text and `send_kind` |
| `functions/tests/payments_helpers.py` | create | world builder used by every payments test |
| `functions/tests/test_payments_states.py` | create | table, engine, notices tests |

## Steps
1. File `functions/payments/__init__.py`, create:
```python
"""InstaPay payments between a client and her coach (docs/plan/INSTAPAY-PAYMENTS-SPEC.md).

Own Hub never holds, receives or moves the money. This package records the
payment, decides who may do what next, and keeps a trail. Every state change is
made here by a callable in main.py; the phones only read (firebase/firestore.rules).

All amounts in this package are integer piasters (500.37 EGP is 50037).
"""
```
2. File `functions/payments/errors.py`, create:
```python
"""Refusal codes. No sentence is composed here: the app speaks both languages."""

from __future__ import annotations

from coaching.errors import (  # noqa: F401  (re-exported for the other modules)
    BAD_REQUEST,
    EXHAUSTED,
    IMAGE_INVALID,
    INVALID,
    NOT_FOUND,
    NOT_VERIFIED,
    PERMISSION,
    PRECONDITION,
    WRONG_STATUS,
    CoachingError,
)

PAYMENTS_OFF = "payments_off"
PAYMENT_NOT_FOUND = "payment_not_found"
ILLEGAL_TRANSITION = "illegal_transition"
COACH_NOT_READY = "coach_not_ready"
COACH_PAYMENTS_SUSPENDED = "coach_payments_suspended"
CLIENT_PAYMENTS_SUSPENDED = "client_payments_suspended"
AMOUNT_OVER_LIMIT = "amount_over_limit"
FIRST_PAYMENT_SHORTEST_ONLY = "first_payment_shortest_only"
TOO_MANY_REQUESTS = "too_many_requests"
OPEN_PAYMENT_EXISTS = "open_payment_exists"
AMOUNT_UNAVAILABLE = "amount_unavailable"
AMOUNT_MISMATCH = "amount_mismatch"
PROOF_WINDOW_CLOSED = "proof_window_closed"
TOO_MANY_SCREENSHOTS = "too_many_screenshots"
PROOF_INCOMPLETE = "proof_incomplete"
WRONG_KIND_OF_MESSAGE = "wrong_kind_of_message"
CLAIM_CONTRADICTED = "appears_in_statement"
EVIDENCE_REQUIRED = "evidence_required"
REASON_REQUIRED = "reason_required"
NO_COACH_REPORT = "no_coach_report"
TXN_REUSED = "txn_reused"
ADDRESS_NOT_HANDLE = "address_not_handle"
ADDRESS_FORMAT = "address_format"
RECENT_SIGN_IN_REQUIRED = "recent_sign_in_required"
REFUND_WINDOW_CLOSED = "refund_window_closed"
REFUND_ALREADY_REQUESTED = "refund_already_requested"
DISPUTE_LIMIT = "dispute_limit"
TWO_STAFF_REQUIRED = "two_staff_required"
SAME_STAFF = "same_staff"
NOT_YOUR_PAYMENT = PAYMENT_NOT_FOUND  # one reason, so a stranger learns nothing
```
3. File `functions/payments/model.py`, create:
```python
"""Limits, statuses and the one read of the kill switch."""

from __future__ import annotations

import datetime as dt
from typing import Any, Optional

STATUSES = (
    "awaiting_payment", "proof_submitted", "confirmed", "expired", "cancelled",
    "coach_not_received", "in_review", "resolved_paid", "resolved_unpaid",
    "different_amount", "refund_requested", "refunded", "refund_denied", "service_dispute",
)

# A payment in these statuses still holds the coach's unique amount (WO-10m).
HOLDS_AMOUNT = (
    "awaiting_payment", "expired", "proof_submitted", "coach_not_received",
    "in_review", "different_amount",
)

# The package may run (fully) only in these (spec section 3).
PAID_STATUSES = ("confirmed", "resolved_paid")

LIMITS = {
    "expiryHours": 24,            # 4.7: a request lasts 24 hours
    "lateProofDays": 7,           # 4.7: a proof within 7 days of the request is still accepted
    "coachRemindHours": 48,       # 4.1
    "escalateHours": 72,          # 4.1, 4.5
    "amberHours": 24,             # 13.4: amber turns into access after 24 hours with no objection
    "provisionalMaxDays": 7,      # 13.1: at most 7 days or the first package week
    "autoConfirmFlagHours": 48,   # 13.4: a coach may flag an auto-confirmed payment within 48 hours
    "refundCoachDays": 3,         # 4.8
    "refundWindowDays": 14,       # 4.8 / RELEASE-2-PLAN 3.10
    "requestsPerDay": 3,          # 4.12
    "disputesPerMonth": 3,        # 4.12
    "screenshotsPerPayment": 5,   # 4.12
    "screenshotMaxBytes": 5_000_000,   # 4.12: at most 5 MB
    "screenshotLongSidePx": 1600,
    "addressDelayHours": 24,      # 4.4
    "strikeWindowDays": 90,       # 13.5
    "strikesToSuspend": 2,        # 4.1, 4.2, 13.5
    "disputeRateMinPayments": 10, # 13.5 (owner tunable in coachingConfig/instapay)
    "disputeRatePercent": 10,
    "feeOverdueDays": 30,         # 4.13
    "idempotencyDays": 30,
    "firstPaymentsStaffVisible": 3,   # 13.1
    "cleanPaymentsForAutoConfirm": 3, # 13.4
    "feeBpsMarketplace": 1500,    # D63 default; the owner overrides in coachingConfig/instapay
    "feeBpsInvite": 800,          # D63 default
    "maxAmountEgp": 20000,        # UNVERIFIED placeholder, see WO-10m step 1
}


def hours(n: int) -> dt.timedelta:
    return dt.timedelta(hours=n)


def days(n: int) -> dt.timedelta:
    return dt.timedelta(days=n)


def pounds_text(piasters: int) -> str:
    """50037 -> '500.37' (Western digits, always two decimals)."""
    return f"{piasters // 100}.{piasters % 100:02d}"


def enabled(db) -> bool:
    """The kill switch. A missing document means OFF (safe); the owner creates
    config/payments with {enabled: true} at deploy (WO-10p)."""
    snap = db.collection("config").document("payments").get()
    row: Optional[dict] = snap.to_dict() if snap.exists else None
    return bool(row) and row.get("enabled") is True


def config(db) -> dict:
    """coachingConfig/instapay merged over the defaults in LIMITS. Server-only."""
    snap = db.collection("coachingConfig").document("instapay").get()
    row: dict[str, Any] = (snap.to_dict() or {}) if snap.exists else {}
    keys = ("feeBpsMarketplace", "feeBpsInvite", "maxAmountEgp",
            "disputeRateMinPayments", "disputeRatePercent")
    return {k: row[k] if isinstance(row.get(k), int) and not isinstance(row.get(k), bool) else LIMITS[k] for k in keys}
```
4. File `functions/payments/states.py`, create:
```python
"""The state machine as data. A change that is not in TRANSITIONS is refused."""

from __future__ import annotations

from . import errors

CLIENT, COACH, STAFF, SYSTEM = "client", "coach", "staff", "system"

# (from, to) -> who may make the move. Spec section 3 plus section 13:
#  - awaiting_payment/expired -> confirmed: the coach reported the payment and the client agrees (4.5)
#  - proof_submitted -> in_review by system: a RED proof, or 72 hours of silence (4.1, 13.4)
#  - confirmed -> in_review by coach: ONLY for an auto-confirmed payment within 48 hours,
#    with evidence (13.4); the callable checks that, not this table
#  - resolved_* / confirmed -> in_review by staff: a second reviewer reopens (13.9)
TRANSITIONS: dict[tuple[str, str], frozenset] = {
    ("awaiting_payment", "proof_submitted"): frozenset({CLIENT}),
    ("awaiting_payment", "confirmed"): frozenset({CLIENT}),
    ("awaiting_payment", "cancelled"): frozenset({CLIENT}),
    ("awaiting_payment", "expired"): frozenset({SYSTEM}),
    ("awaiting_payment", "in_review"): frozenset({SYSTEM}),
    ("expired", "proof_submitted"): frozenset({CLIENT}),
    ("expired", "confirmed"): frozenset({CLIENT}),
    ("expired", "in_review"): frozenset({SYSTEM}),
    ("proof_submitted", "confirmed"): frozenset({COACH, SYSTEM}),
    ("proof_submitted", "coach_not_received"): frozenset({COACH}),
    ("proof_submitted", "different_amount"): frozenset({COACH}),
    ("proof_submitted", "in_review"): frozenset({SYSTEM}),
    ("coach_not_received", "in_review"): frozenset({SYSTEM}),
    ("different_amount", "confirmed"): frozenset({CLIENT}),
    ("different_amount", "cancelled"): frozenset({CLIENT}),
    ("different_amount", "in_review"): frozenset({CLIENT, SYSTEM}),
    ("in_review", "resolved_paid"): frozenset({STAFF}),
    ("in_review", "resolved_unpaid"): frozenset({STAFF}),
    ("in_review", "confirmed"): frozenset({STAFF}),
    ("in_review", "refunded"): frozenset({COACH}),
    ("confirmed", "refund_requested"): frozenset({CLIENT}),
    ("confirmed", "service_dispute"): frozenset({CLIENT}),
    ("confirmed", "in_review"): frozenset({STAFF, COACH}),
    ("resolved_paid", "refund_requested"): frozenset({CLIENT}),
    ("resolved_paid", "service_dispute"): frozenset({CLIENT}),
    ("resolved_paid", "in_review"): frozenset({STAFF}),
    ("resolved_unpaid", "in_review"): frozenset({STAFF}),
    ("refund_requested", "refunded"): frozenset({COACH}),
    ("refund_requested", "refund_denied"): frozenset({COACH}),
    ("refund_requested", "in_review"): frozenset({SYSTEM}),
    ("refund_denied", "in_review"): frozenset({CLIENT}),
    ("service_dispute", "in_review"): frozenset({SYSTEM}),
}


def check(frm: str, to: str, role: str) -> None:
    """Raises illegal_transition unless `role` may move `frm` to `to`."""
    allowed = TRANSITIONS.get((frm, to))
    if allowed is None or role not in allowed:
        raise errors.CoachingError(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


# (from, to) -> [(who gets it, notice kind)]. Kinds are keys of notices.TEXT.
# A pair missing here sends nothing (for example expiry, which is silent).
_NOTICES: dict[tuple[str, str], list[tuple[str, str]]] = {
    ("awaiting_payment", "proof_submitted"): [(COACH, "proofSent")],
    ("expired", "proof_submitted"): [(COACH, "proofSent")],
    ("awaiting_payment", "confirmed"): [(COACH, "paymentConfirmedByClient")],
    ("proof_submitted", "confirmed"): [(CLIENT, "paymentConfirmed")],
    ("proof_submitted", "coach_not_received"): [(CLIENT, "coachNotReceived")],
    ("proof_submitted", "different_amount"): [(CLIENT, "differentAmount")],
    ("proof_submitted", "in_review"): [(CLIENT, "reviewStarted"), (COACH, "disputeOpened")],
    ("awaiting_payment", "in_review"): [(CLIENT, "reviewStarted"), (COACH, "disputeOpened")],
    ("expired", "in_review"): [(CLIENT, "reviewStarted"), (COACH, "disputeOpened")],
    ("coach_not_received", "in_review"): [(CLIENT, "reviewStarted")],
    ("different_amount", "in_review"): [(COACH, "disputeOpened")],
    ("in_review", "resolved_paid"): [(CLIENT, "reviewDecided"), (COACH, "reviewDecided")],
    ("in_review", "resolved_unpaid"): [(CLIENT, "reviewDecided"), (COACH, "reviewDecided")],
    ("in_review", "confirmed"): [(CLIENT, "reviewDecided"), (COACH, "reviewDecided")],
    ("in_review", "refunded"): [(CLIENT, "refundRecorded")],
    ("refund_requested", "refunded"): [(CLIENT, "refundRecorded")],
    ("confirmed", "refund_requested"): [(COACH, "refundRequested")],
    ("resolved_paid", "refund_requested"): [(COACH, "refundRequested")],
    ("refund_requested", "refund_denied"): [(CLIENT, "reviewDecided")],
    ("refund_requested", "in_review"): [(CLIENT, "reviewStarted"), (COACH, "disputeOpened")],
    ("service_dispute", "in_review"): [(CLIENT, "reviewStarted"), (COACH, "disputeOpened")],
    ("refund_denied", "in_review"): [(CLIENT, "reviewStarted"), (COACH, "disputeOpened")],
}


def notices_for(frm: str, to: str) -> list[tuple[str, str]]:
    return list(_NOTICES.get((frm, to), []))
```
5. File `functions/payments/engine.py`, create:
```python
"""One way to change a payment's status, and one way to make a repeat harmless."""

from __future__ import annotations

import datetime as dt
import re
from typing import Optional

from coaching import common

from . import errors, model, states

_KEY = re.compile(r"^[A-Za-z0-9_-]{8,64}$")


def idem_key(value) -> str:
    """The client's idempotency key: 8 to 64 characters of letters, digits, _ and -."""
    if not isinstance(value, str) or not _KEY.match(value):
        raise common.bad()
    return value


def payment_ref(db, payment_id: str):
    return db.collection("payments").document(payment_id)


def load(transaction, db, payment_id: str) -> tuple:
    """(ref, payment dict) or the one 'not found' refusal."""
    ref = payment_ref(db, payment_id)
    row = common.read(ref, transaction)
    if row is None:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    return ref, row


def load_for_party(transaction, db, payment_id: str, uid: str, role: str) -> tuple:
    """Like `load`, and the caller must be the client (role 'client') or the
    coach (role 'coach') named on it. A stranger gets the same 'not found'."""
    ref, row = load(transaction, db, payment_id)
    field = "clientUid" if role == states.CLIENT else "coachUid"
    if row.get(field) != uid:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    return ref, row


def actor_label(role: str, uid: str) -> str:
    return common.staff_ref(uid) if role == states.STAFF else role


def move(transaction, db, ref, payment: dict, to: str, role: str, actor_uid: Optional[str],
         now: dt.datetime, *, changes: Optional[dict] = None, code: Optional[str] = None) -> dict:
    """Checks the move against the table, writes the new status and ONE event
    document, and returns the payment as it now stands (so a caller can chain a
    second move in the same transaction). The event holds a role and a short
    code, never a name, an amount or a uid: both parties read the timeline."""
    states.check(payment["status"], to, role)
    update = {"status": to, "statusAt": now, **(changes or {})}
    transaction.update(ref, update)
    transaction.set(
        ref.collection("events").document(),
        {
            "at": now,
            "from": payment["status"],
            "to": to,
            "role": role,
            "actor": actor_label(role, actor_uid or ""),
            "code": code,
        },
    )
    return {**payment, **update}


def replay(transaction, db, uid: str, scope: str, key: str) -> Optional[dict]:
    """The answer already given for this (woman, call, key), or None."""
    snap = db.collection("paymentIdempotency").document(f"{uid}__{scope}__{key}").get(transaction=transaction)
    return (snap.to_dict() or {}).get("result") if snap.exists else None


def remember(transaction, db, uid: str, scope: str, key: str, result: dict, now: dt.datetime) -> None:
    transaction.set(
        db.collection("paymentIdempotency").document(f"{uid}__{scope}__{key}"),
        {"result": common.plain(result), "at": now, "expireAt": now + model.days(model.LIMITS["idempotencyDays"])},
    )
```
6. File `functions/payments/notices.py`, create (texts: no names, no amounts, calm; Egyptian Arabic, feminine address, no em dashes):
```python
"""Pushes for payments. A lock screen is read by whoever holds the phone, so no
text names a person or carries an amount (spec section 8, default)."""

from __future__ import annotations

from typing import Optional

from identity import push as identity_push

TITLE = "Own Hub"

TEXT: dict[str, dict[str, tuple[str, str]]] = {
    # to the client
    "payReminder": {"en": (TITLE, "Your payment request is still open. Open Own Hub to finish or cancel."),
                    "ar": (TITLE, "طلب الدفع لسه مفتوح. افتحي Own Hub وكمّلي أو الغي الطلب.")},
    "paymentConfirmed": {"en": (TITLE, "Your coach confirmed your payment."),
                         "ar": (TITLE, "المدربة أكدت إنها استلمت الدفع.")},
    "coachNotReceived": {"en": (TITLE, "Your coach says the payment has not reached her yet. Open Own Hub to add your proof."),
                         "ar": (TITLE, "المدربة بتقول إن الدفع لسه ماوصلهاش. افتحي Own Hub وضيفي إثبات التحويل.")},
    "differentAmount": {"en": (TITLE, "Your coach received a different amount. Open Own Hub to see it."),
                        "ar": (TITLE, "المدربة استلمت مبلغ مختلف. افتحي Own Hub وشوفيه.")},
    "coachReported": {"en": (TITLE, "Your coach says you paid. Open Own Hub to confirm."),
                      "ar": (TITLE, "المدربة بتقول إنك دفعتي. افتحي Own Hub وأكدي.")},
    "reviewStarted": {"en": (TITLE, "Our team is looking at your payment. You do not need to do anything now."),
                      "ar": (TITLE, "فريقنا بيراجع الدفع. مش مطلوب منك حاجة دلوقتي.")},
    "reviewDecided": {"en": (TITLE, "Your payment review has a decision. Open Own Hub to see it."),
                      "ar": (TITLE, "مراجعة الدفع ليها قرار. افتحي Own Hub وشوفيه.")},
    "refundRecorded": {"en": (TITLE, "A refund was recorded. Open Own Hub to see it."),
                       "ar": (TITLE, "اتسجّل استرداد. افتحي Own Hub وشوفيه.")},
    "addressChanged": {"en": (TITLE, "Your coach updated her payment details. Open Own Hub before you pay."),
                       "ar": (TITLE, "المدربة غيّرت بيانات الدفع بتاعتها. افتحي Own Hub قبل ما تدفعي.")},
    "accessEndsSoon": {"en": (TITLE, "Your temporary access ends soon. Open Own Hub to see what is left to do."),
                       "ar": (TITLE, "الفتح المؤقت هيخلص قريب. افتحي Own Hub وشوفي المطلوب.")},
    "paymentsPaused": {"en": (TITLE, "InstaPay payments are paused for your account. Open Own Hub for details."),
                       "ar": (TITLE, "الدفع بإنستا باي موقوف لحسابك. افتحي Own Hub للتفاصيل.")},
    # to the coach
    "proofSent": {"en": (TITLE, "A client sent proof of payment. Open Own Hub to check your bank."),
                  "ar": (TITLE, "عميلة بعتت إثبات الدفع. افتحي Own Hub وراجعي حسابك البنكي.")},
    "proofReminder48": {"en": (TITLE, "A payment is waiting for you to check. Please open Own Hub today."),
                        "ar": (TITLE, "فيه دفع مستنيكي تراجعيه. افتحي Own Hub النهارده.")},
    "paymentConfirmedByClient": {"en": (TITLE, "A client confirmed she paid. Open Own Hub to see it."),
                                 "ar": (TITLE, "عميلة أكدت إنها دفعت. افتحي Own Hub وشوفي.")},
    "disputeOpened": {"en": (TITLE, "A payment needs a second look. Open Own Hub to see what we need."),
                      "ar": (TITLE, "فيه دفع محتاج مراجعة تانية. افتحي Own Hub وشوفي المطلوب.")},
    "refundRequested": {"en": (TITLE, "A client asked for a refund. Open Own Hub to answer within 3 days."),
                        "ar": (TITLE, "عميلة طلبت استرداد. افتحي Own Hub وردّي خلال 3 أيام.")},
    "statementReady": {"en": (TITLE, "Your fee statement for last month is ready."),
                       "ar": (TITLE, "كشف الرسوم عن الشهر اللي فات جاهز.")},
    "feeOverdue": {"en": (TITLE, "Your Own Hub fee is late. Open Own Hub to see the statement."),
                   "ar": (TITLE, "رسوم Own Hub متأخرة. افتحي Own Hub وشوفي الكشف.")},
    "paymentsSuspended": {"en": (TITLE, "Taking payments is paused on your account. Open Own Hub for details."),
                          "ar": (TITLE, "استلام الدفع موقوف على حسابك. افتحي Own Hub للتفاصيل.")},
}

KINDS = tuple(TEXT)


def text_for(kind: str, locale: Optional[str]) -> tuple[str, str]:
    by_locale = TEXT[kind]
    return by_locale.get(locale or "", by_locale["ar"])


def send_kind(uid: str, kind: str, *, db, messaging, locale: Optional[str] = None) -> int:
    """Same delivery as coaching/push.send_kind; an unknown kind sends nothing."""
    if kind not in TEXT:
        return 0
    return identity_push.send_to_user(
        uid, "", "", {"kind": kind}, db, messaging,
        texts=lambda phone_locale: text_for(kind, phone_locale),
        fallback_locale=locale if locale in ("en", "ar") else "ar",
    )
```
7. File `functions/tests/payments_helpers.py`, create:
```python
"""The world every payments test starts from. Import what you use. The autouse
`_txn` fixture must be imported by name so pytest runs it in your module."""

from __future__ import annotations

import datetime as dt

import pytest

from tests import fake_firestore
from tests.coaching_helpers import Notes, Pushes, _txn, refusal  # noqa: F401

NOW = dt.datetime(2026, 11, 10, 12, 0, tzinfo=dt.timezone.utc)
CLIENT = "client-uid-1"
CLIENT2 = "client-uid-2"
COACH = "coach-uid-1"
COACH2 = "coach-uid-2"
REVIEWER = "reviewer-uid-1"
REVIEWER2 = "reviewer-uid-2"
FINANCE = "finance-uid-1"
SUB = "sub-1"
PAY = "pay-1"
ADDRESS = "rahma@instapay"
ACCOUNT_NAME = "Rahma Mohsen"
BASE = 50000          # 500.00 EGP in piasters
AMOUNT = 50037        # the unique amount to pay


@pytest.fixture
def db():
    return fake_firestore.FakeFirestore()


@pytest.fixture
def notes():
    return Notes()


def later(**kw):
    return NOW + dt.timedelta(**kw)


def seed_world(db, *, durations=(28,), suspended=False, ready=True):
    """A coach with a confirmed InstaPay address, her packages, and one client
    subscription waiting for payment."""
    db.document(f"coaches/{COACH}").set(
        {"displayName": "Coach One", "published": True, "acceptingClients": True,
         "maxActiveClients": 15, "activeClients": 0, "instapayReady": ready,
         "stats": {"clientsCoached": 0}}
    )
    for i, d in enumerate(durations):
        db.document(f"coaches/{COACH}/packages/pk{i}").set(
            {"title": f"P{i}", "durationDays": d, "priceFinalEgp": 500, "active": True, "order": i}
        )
    db.document(f"coachPrivate/{COACH}").set({"suspended": False})
    db.document(f"coachPaymentProfiles/{COACH}").set(
        {"address": ADDRESS, "accountName": ACCOUNT_NAME, "verifiedAt": NOW, "status": "ok",
         "paymentsCreated": 0, "cleanConfirmed": 0, "autoConfirmGreen": False, "allowLongFirst": False,
         "paymentsConfirmed": 0, "disputesLost": 0}
    )
    if suspended:
        db.document(f"paymentStanding/{COACH}").set({"coachSuspended": True, "coachStrikes": 2})
    db.document(f"subscriptions/{SUB}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "relId": f"{COACH}__{CLIENT}", "packageId": "pk0",
         "package": {"title": "P0", "durationDays": durations[0]}, "priceFinalEgp": 500,
         "status": "awaiting_payment", "statusAt": NOW, "payBy": later(days=7),
         "payment": {"state": "awaiting", "attempts": 0, "lastReason": None, "proofId": None}}
    )
    db.document(f"relationships/{COACH}__{CLIENT}").set(
        {"coachUid": COACH, "clientUid": CLIENT, "status": "none", "chatOpen": False}
    )


def make_payment(db, payment_id=PAY, **over):
    """A payments/{id} document written straight into the fake, in any status."""
    row = {
        "clientUid": CLIENT, "coachUid": COACH, "subId": SUB, "packageId": "pk0",
        "baseAmountPiasters": BASE, "amountPiasters": AMOUNT, "reference": "OH-4821",
        "addressSnapshot": {"address": ADDRESS, "accountName": ACCOUNT_NAME},
        "status": "awaiting_payment", "statusAt": NOW, "createdAt": NOW,
        "expiresAt": later(hours=24), "lateUntil": later(days=7),
        "proof": None, "outcome": None, "access": {"state": "none", "until": None},
        "feePiasters": 0, "feeState": None, "feeOwedAt": None,
    }
    row.update(over)
    db.document(f"payments/{payment_id}").set(row)
    return row


def events(db, payment_id=PAY):
    """[(from, to, role)] of the payment's timeline, oldest first."""
    rows = [r.to_dict() for r in db.collection(f"payments/{payment_id}/events").stream()]
    rows.sort(key=lambda r: r["at"])
    return [(r["from"], r["to"], r["role"]) for r in rows]


def payment_of(db, payment_id=PAY):
    return db.document(f"payments/{payment_id}").get().to_dict()
```
(`fake_firestore` orders events only by `at`; events written in one transaction share `at`, so `events()` must keep insertion order. `sort` is stable and the fake streams by sorted document path, which is random for auto ids. If a test needs the order of two events from one transaction, compare as a set. State this in the test.)
8. File `functions/tests/test_payments_states.py`, create:
```python
"""The transition table, the event writer and idempotency."""

from __future__ import annotations

import itertools

import pytest

from coaching import common
from payments import engine, errors, model, notices, states
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, NOW, PAY, REVIEWER, _txn, db, events, later, make_payment, payment_of, refusal,
)

ROLES = (states.CLIENT, states.COACH, states.STAFF, states.SYSTEM)


@pytest.mark.parametrize("pair,roles", sorted(states.TRANSITIONS.items()))
def test_every_legal_transition_passes_for_exactly_its_roles(pair, roles):
    for role in ROLES:
        if role in roles:
            states.check(pair[0], pair[1], role)
        else:
            assert refusal(lambda: states.check(pair[0], pair[1], role)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_every_pair_of_statuses_not_in_the_table_is_refused_for_every_role():
    pairs = [p for p in itertools.product(model.STATUSES, model.STATUSES) if p not in states.TRANSITIONS]
    assert len(pairs) == len(model.STATUSES) ** 2 - len(states.TRANSITIONS)
    for frm, to in pairs:
        for role in ROLES:
            assert refusal(lambda: states.check(frm, to, role)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_the_table_only_names_known_statuses():
    for frm, to in states.TRANSITIONS:
        assert frm in model.STATUSES and to in model.STATUSES


def test_terminal_statuses_only_reopen_by_staff():
    for terminal in ("cancelled", "refunded"):
        assert not [p for p in states.TRANSITIONS if p[0] == terminal]
    assert states.TRANSITIONS[("resolved_unpaid", "in_review")] == frozenset({states.STAFF})


def test_every_notice_kind_has_both_languages_and_no_amount_or_em_dash():
    for kind, by_locale in notices.TEXT.items():
        assert set(by_locale) == {"en", "ar"}, kind
        for title, body in by_locale.values():
            assert "—" not in body and not any(c.isdigit() for c in body.replace("48", "").replace("3", "")), kind
    for pair in states._NOTICES.values():
        for _, kind in pair:
            assert kind in notices.TEXT


def test_move_writes_the_status_and_one_event_and_returns_the_new_payment(db):
    make_payment(db, status="proof_submitted")
    ref = engine.payment_ref(db, PAY)

    def body(transaction):
        ref_, row = engine.load(transaction, db, PAY)
        return engine.move(transaction, db, ref_, row, "confirmed", states.COACH, COACH, NOW, changes={"x": 1}, code="coach_confirmed")

    out = common.run(db, body)
    assert out["status"] == "confirmed" and out["x"] == 1
    assert payment_of(db)["status"] == "confirmed"
    assert events(db) == [("proof_submitted", "confirmed", "coach")]
    event = next(iter(db.collection(f"payments/{PAY}/events").stream())).to_dict()
    assert event["actor"] == "coach" and event["code"] == "coach_confirmed"
    assert COACH not in str(event)


def test_move_refuses_an_illegal_pair_and_writes_nothing(db):
    make_payment(db, status="proof_submitted")

    def body(transaction):
        ref_, row = engine.load(transaction, db, PAY)
        engine.move(transaction, db, ref_, row, "refunded", states.COACH, COACH, NOW)

    assert refusal(lambda: common.run(db, body)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
    assert payment_of(db)["status"] == "proof_submitted" and events(db) == []


def test_a_staff_event_names_a_short_reference_never_the_uid(db):
    make_payment(db, status="in_review")

    def body(transaction):
        ref_, row = engine.load(transaction, db, PAY)
        engine.move(transaction, db, ref_, row, "resolved_paid", states.STAFF, REVIEWER, NOW)

    common.run(db, body)
    event = next(iter(db.collection(f"payments/{PAY}/events").stream())).to_dict()
    assert REVIEWER not in str(event) and event["actor"] != REVIEWER


def test_a_stranger_gets_payment_not_found(db):
    make_payment(db)

    def body(transaction):
        engine.load_for_party(transaction, db, PAY, "someone-else", states.CLIENT)

    assert refusal(lambda: common.run(db, body)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_idempotency_replays_the_first_answer(db):
    def first(transaction):
        assert engine.replay(transaction, db, CLIENT, "create", "key-12345678") is None
        engine.remember(transaction, db, CLIENT, "create", "key-12345678", {"paymentId": "p9"}, NOW)

    common.run(db, first)
    assert common.run(db, lambda t: engine.replay(t, db, CLIENT, "create", "key-12345678")) == {"paymentId": "p9"}
    assert common.run(db, lambda t: engine.replay(t, db, "other", "create", "key-12345678")) is None


@pytest.mark.parametrize("bad", [None, 5, "", "short", "has space 12345", "x" * 65])
def test_a_bad_idempotency_key_is_refused(bad):
    assert refusal(lambda: engine.idem_key(bad))[0] == errors.INVALID


def test_the_kill_switch_reads_off_when_missing_and_on_when_true(db):
    assert model.enabled(db) is False
    db.document("config/payments").set({"enabled": True})
    assert model.enabled(db) is True
    db.document("config/payments").set({"enabled": "yes"})
    assert model.enabled(db) is False


def test_pounds_text_uses_western_digits_and_two_decimals():
    assert model.pounds_text(50037) == "500.37" and model.pounds_text(50000) == "500.00" and model.pounds_text(5) == "0.05"
```

## Strings to add
None in the app. The push texts above are server constants (the app has no strings for them). The table of kinds the app must handle on tap: `payReminder, paymentConfirmed, coachNotReceived, differentAmount, coachReported, reviewStarted, reviewDecided, refundRecorded, addressChanged, accessEndsSoon, paymentsPaused, proofSent, proofReminder48, paymentConfirmedByClient, disputeOpened, refundRequested, statementReady, feeOverdue, paymentsSuspended`.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `functions/tests/test_payments_states.py` | each test above | as written |

Command: `cd functions && venv/bin/python -m pytest tests/test_payments_states.py -q`

## Verify
`cd functions && venv/bin/python -m pytest tests/test_payments_states.py -q` ends with `N passed` and no `failed` (N is about 160 because the table test is parametrized). Then `cd functions && venv/bin/python -m pytest tests/test_entrypoints.py tests/test_coaching_wrappers.py -q` still passes (nothing in `main.py` changed).

## Do not
- Do not add a second unit for money. Piasters only.
- Do not put a name, uid, amount or note into an event document: both parties read events.
- Do not add a transition without adding it to the notices table or deciding it sends nothing.
- Do not edit `functions/coaching/*` or `contracts/coaching_contract.json` here.

## Done checklist
- [ ] 8 files created, none edited
- [ ] table test passes for every pair
- [ ] kill switch reads OFF when the document is missing

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
