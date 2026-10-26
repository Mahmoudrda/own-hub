# WO-10b: State machine part 1: create_payment, cancel_payment, access grant and end, and the hook into coaching requests
Depends on: WO-10a, WO-10a2, WO-10m
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.6, 4.7, 4.11, 4.12, 13.1, 13.2, 13.9; `functions/coaching/subscriptions.py` lines 150-226 (`acceptance`, `held_places`, `free_start`, `begin`), 228-366 (`request`) and 377-432 (`respond`), 485-535 (`read_ending`, `write_ending`), 753-812 (`sweep`); `functions/main.py` lines 1894-1916 (`_require_verified`, `_payments_live`) and 2096-2121; `functions/tests/test_entrypoints.py` lines 39-95 (`CALLABLES`); `functions/payments/engine.py`, `allocation.py`

## Why
This is where a payment is born and where access to the coaching starts and ends. Rules that must all hold here: one open payment per client and package; at most 3 requests per client per day; the first payment of a new client can only be the coach's shortest package unless the coach allowed longer; the coach must be approved, have a confirmed address and not be suspended; the unique amount is reserved; a double tap makes one payment; the address and price are copied at creation and never change for that payment. Access is a plain subscription becoming `active`, using the same start routine as free coaching, with a bounded provisional flag (WO-10b2 uses it for a GREEN proof).

## Final result
No screen. Callables `create_payment` and `cancel_payment` (registered in `main.py`), the modules `payments/profile.py`, `create.py`, `activation.py`, `cancel.py`, and three edits to `coaching/subscriptions.py` so that a coach accepting a request while InstaPay is on moves it to `awaiting_payment` (no `payTo`, no payment code) instead of starting it free; with the kill switch off it starts free exactly as today ("Free for now").

Request of `create_payment`: `{subId, idempotencyKey}`. Answer: `{paymentId, amountPiasters, reference, address, accountName, expiresAt, status: "awaiting_payment"}`. Request of `cancel_payment`: `{paymentId}`; answer `{status: "cancelled"}`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/profile.py` | create | coach profile and standing readers |
| `functions/payments/create.py` | create | `create` |
| `functions/payments/cancel.py` | create | `cancel` |
| `functions/payments/activation.py` | create | `grant`, `read_for_end`, `end` |
| `functions/coaching/subscriptions.py` | edit | `instapay` flag in `request`, `respond`, `sweep` |
| `functions/main.py` | edit | `_instapay_on`, two callables, sweeper flag, two existing wrappers pass the flag |
| `functions/tests/test_entrypoints.py` | edit | two names in `CALLABLES` |
| `functions/tests/test_payments_create.py` | create | create, cancel, activation, hook tests |

## Steps
1. File `functions/payments/profile.py`, create:
```python
"""Readers for a woman's payment profile and standing (written by WO-10d and WO-10o)."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from coaching import common


def profile_ref(db, uid: str):
    return db.collection("coachPaymentProfiles").document(uid)


def standing_ref(db, uid: str):
    return db.collection("paymentStanding").document(uid)


def effective(profile: Optional[dict], now: dt.datetime) -> Optional[tuple]:
    """(address, accountName) the coach is paid at right now, or None when she
    has none. A pending change counts only after its 24 hour delay (4.4)."""
    if not profile:
        return None
    pending = profile.get("pending") or {}
    when = common.as_utc(pending.get("effectiveAt"))
    if pending.get("address") and when is not None and when <= now:
        return pending["address"], pending["accountName"]
    if profile.get("address"):
        return profile["address"], profile["accountName"]
    return None


def coach_suspended(standing: Optional[dict]) -> bool:
    return bool((standing or {}).get("coachSuspended"))


def client_suspended(standing: Optional[dict]) -> bool:
    return bool((standing or {}).get("clientSuspended"))
```
2. File `functions/payments/activation.py`, create:
```python
"""Starting and ending the coaching that a payment pays for. Reuses the routine
free coaching and the old proof flow already use (`subscriptions.begin`,
`subscriptions.write_ending`), so the relationship, the coach's place counter
and the chat line behave the same."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from coaching import common, subscriptions


def read_for_start(transaction, db, sub_id: str) -> dict:
    """Every read `grant` needs. Call before any write."""
    sub_ref = db.collection("subscriptions").document(sub_id)
    sub = common.read(sub_ref, transaction) or {}
    coach_ref = db.collection("coaches").document(sub.get("coachUid", "none"))
    rel_ref = db.collection("relationships").document(sub.get("relId", "none"))
    return {"subRef": sub_ref, "sub": sub, "coachRef": coach_ref, "coach": coach_ref.get(transaction=transaction),
            "rel": rel_ref.get(transaction=transaction)}


def grant(transaction, db, seen: dict, now: dt.datetime, *, provisional_until: Optional[dt.datetime] = None) -> str:
    """Makes the subscription `active`. With `provisional_until` the access is
    short and says so on the subscription (`provisionalUntil`); without it the
    access is full. Calling it again on a running subscription only upgrades a
    provisional one to full. Returns 'started', 'upgraded' or 'unchanged'."""
    sub, sub_ref = seen["sub"], seen["subRef"]
    payment = dict(sub.get("payment") or {})
    if sub.get("status") == "active":
        if provisional_until is None and sub.get("provisionalUntil"):
            transaction.update(sub_ref, {"provisionalUntil": None, "payment": {**payment, "state": "approved"}})
            return "upgraded"
        return "unchanged"
    if sub.get("status") != "awaiting_payment":
        raise common.refuse(common.errors.PRECONDITION, common.errors.WRONG_STATUS)
    package = sub.get("package") or {}
    transaction.update(
        sub_ref,
        {
            "status": "active",
            "startsAt": now,
            "endsAt": now + common.days(package["durationDays"]),
            "provisionalUntil": provisional_until,
            "payment": {**payment, "state": "review" if provisional_until else "approved"},
            "statusAt": now,
        },
    )
    subscriptions.begin(
        transaction, db, sub_id=sub_ref.id, coach_uid=sub["coachUid"], client_uid=sub["clientUid"],
        rel_id=sub["relId"], rel=seen["rel"], coach_ref=seen["coachRef"], coach=seen["coach"], now=now,
    )
    return "started"


def read_for_end(transaction, db, sub_id: str) -> dict:
    sub = common.read(db.collection("subscriptions").document(sub_id), transaction) or {}
    return {"sub": sub, "seen": subscriptions.read_ending(transaction, db, sub_id, sub, money=False) if sub else None}


def end(transaction, db, sub_id: str, read: dict, reason: str, now: dt.datetime) -> bool:
    """Ends a running subscription (`ended_early`, `reason` from the contract's
    endReasons: 'refund' or 'dispute'). Does nothing when it is not running."""
    sub = read["sub"]
    if sub.get("status") != "active":
        return False
    subscriptions.write_ending(
        transaction, db, sub_id, sub, read["seen"],
        changes={"status": "ended_early", "endReason": reason, "provisionalUntil": None, "statusAt": now}, now=now,
    )
    return True
```
(`common.errors` is the `errors` module imported inside `coaching/common.py`; if `AttributeError`, import `from coaching import errors as coaching_errors` at the top of this file and use it. UNVERIFIED: `grep -n "^from . import errors" functions/coaching/common.py` prints the import at line 24.)
3. File `functions/payments/create.py`, create:
```python
"""create_payment: one request for one package, with a unique amount (spec 4.6, 4.7, 4.11, 4.12, 13.1, 13.2)."""

from __future__ import annotations

import datetime as dt
import random
from typing import Optional

from google.cloud import firestore

from coaching import common

from . import allocation, engine, errors, model, profile, states

LIMITS = model.LIMITS


def create(db, uid: str, data: dict, *, now: dt.datetime, on: bool, rng: Optional[random.Random] = None) -> dict:
    if not on:
        raise common.refuse(errors.PRECONDITION, errors.PAYMENTS_OFF)
    sub_id = common.text(data.get("subId"), max_len=128)
    key = engine.idem_key(data.get("idempotencyKey"))
    cfg = model.config(db)
    sub_ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        again = engine.replay(transaction, db, uid, "create", key)
        if again is not None:
            return again
        sub = common.read(sub_ref, transaction)
        if sub is None or sub.get("clientUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        if sub.get("status") != "awaiting_payment":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        coach_uid = sub["coachUid"]
        prof_ref = profile.profile_ref(db, coach_uid)
        prof = common.read(prof_ref, transaction)
        coach_private = common.read(db.collection("coachPrivate").document(coach_uid), transaction) or {}
        coach_standing = common.read(profile.standing_ref(db, coach_uid), transaction)
        client_standing = common.read(profile.standing_ref(db, uid), transaction)
        packages = list(db.collection("coaches").document(coach_uid).collection("packages").stream(transaction=transaction))
        mine = list(db.collection("payments").where("clientUid", "==", uid).stream(transaction=transaction))

        where = profile.effective(prof, now)
        if where is None:
            raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
        if coach_private.get("suspended") or profile.coach_suspended(coach_standing):
            raise common.refuse(errors.PRECONDITION, errors.COACH_PAYMENTS_SUSPENDED)
        if profile.client_suspended(client_standing):
            raise common.refuse(errors.PRECONDITION, errors.CLIENT_PAYMENTS_SUSPENDED)

        base = int(sub["priceFinalEgp"]) * 100
        if base > cfg["maxAmountEgp"] * 100:
            raise common.refuse(errors.PRECONDITION, errors.AMOUNT_OVER_LIMIT)

        rows = [(s.id, s.to_dict() or {}) for s in mine]
        if any(r.get("subId") == sub_id and r.get("status") in model.HOLDS_AMOUNT for _, r in rows):
            raise common.refuse(errors.PRECONDITION, errors.OPEN_PAYMENT_EXISTS)
        since = now - model.hours(24)
        recent = [r for _, r in rows if (common.as_utc(r.get("createdAt")) or since) > since and not r.get("topUpOf")]
        if len(recent) >= LIMITS["requestsPerDay"]:
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_REQUESTS)
        has_paid = any(r.get("status") in model.PAID_STATUSES for _, r in rows)
        if not has_paid and not (prof or {}).get("allowLongFirst"):
            lengths = [p.to_dict().get("durationDays") for p in packages if (p.to_dict() or {}).get("active") is True]
            if lengths and (sub.get("package") or {}).get("durationDays", 0) > min(lengths):
                raise common.refuse(errors.PRECONDITION, errors.FIRST_PAYMENT_SHORTEST_ONLY)

        pay_ref = db.collection("payments").document()
        amount, lock = allocation.allocate(transaction, db, coach_uid, base, pay_ref.id, now, rng=rng)
        reference = allocation.new_reference(transaction, db)
        seen_count = int((prof or {}).get("paymentsCreated", 0))

        allocation.claim(transaction, db, lock, coach_uid, amount, pay_ref.id, now)
        transaction.set(
            pay_ref,
            {
                "clientUid": uid, "coachUid": coach_uid, "subId": sub_id, "packageId": sub.get("packageId"),
                "baseAmountPiasters": base, "amountPiasters": amount, "lockId": lock, "reference": reference,
                "addressSnapshot": {"address": where[0], "accountName": where[1]},
                "status": "awaiting_payment", "statusAt": now, "createdAt": now,
                "expiresAt": now + model.hours(LIMITS["expiryHours"]),
                "lateUntil": now + model.days(LIMITS["lateProofDays"]),
                "proof": None, "outcome": None, "access": {"state": "none", "until": None},
                "coachDecision": None, "coachReport": None, "dispute": None, "refund": None,
                "feePiasters": 0, "feeState": None, "feeOwedAt": None, "idempotencyKey": key,
                "staffVisible": seen_count < LIMITS["firstPaymentsStaffVisible"],
                "relSource": None, "reminded12h": False, "reminded48h": False,
            },
        )
        transaction.set(
            pay_ref.collection("events").document(),
            {"at": now, "from": None, "to": "awaiting_payment", "role": states.CLIENT, "actor": states.CLIENT, "code": "created"},
        )
        transaction.update(prof_ref, {"paymentsCreated": firestore.Increment(1)})
        transaction.update(sub_ref, {"payment.paymentId": pay_ref.id})
        result = {
            "paymentId": pay_ref.id, "amountPiasters": amount, "reference": reference,
            "address": where[0], "accountName": where[1], "expiresAt": now + model.hours(LIMITS["expiryHours"]),
            "status": "awaiting_payment",
        }
        engine.remember(transaction, db, uid, "create", key, result, now)
        return result

    return common.run(db, body)
```
(The relationship `source` for the fee tier is read at activation time in WO-10c, not here.)
4. File `functions/payments/cancel.py`, create:
```python
"""cancel_payment: the client withdraws an unpaid request, or turns down a different amount."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import engine, states


def cancel(db, uid: str, data: dict, *, now: dt.datetime) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)

    def body(transaction):
        ref, row = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if row["status"] == "cancelled":
            return {"status": "cancelled"}  # a second tap changes nothing
        engine.move(transaction, db, ref, row, "cancelled", states.CLIENT, uid, now, code="client_cancelled")
        return {"status": "cancelled"}

    return common.run(db, body)
```
(`engine.move` frees the amount lock because `cancelled` is not in `HOLDS_AMOUNT`.)
5. File `functions/coaching/subscriptions.py`. Make exactly these five edits.
   a. Anchor: the function `free_start` (about line 187). Immediately before `def free_start`, insert:
```python
INSTAPAY_PAY_BY_DAYS = 7
"""How long an InstaPay acceptance waits for the client: the late-proof window."""


def instapay_acceptance(now: dt.datetime) -> dict:
    """The fields that move a request to awaiting_payment when the client pays
    the coach's own InstaPay address (functions/payments). No payment code and
    no `payTo`: the payment document carries the address and the amount."""
    return {
        "status": "awaiting_payment",
        "acceptedAt": now,
        "paymentCode": None,
        "payBy": now + common.days(INSTAPAY_PAY_BY_DAYS),
        "payment": {"state": "awaiting", "attempts": 0, "lastReason": None, "proofId": None},
        "statusAt": now,
    }


```
   b. Anchor: `def request(` signature block (about line 228): after the line `payments_live: bool = False,` add the line `instapay: bool = False,`. Then in the body: (i) after the existing line `if coach.get("activeClients"...` no change; find the block
```
        if row.get("activeClients", 0) >= cap:
            raise unavailable
```
   and add after it:
```
        if instapay and row.get("instapayReady") is not True:
            raise unavailable  # 4.11: no address yet, the package shows "Message the coach"
```
   (ii) replace `and held_places(db, transaction, coach_uid, payments_live, asked=True) < cap` with `and held_places(db, transaction, coach_uid, payments_live or instapay, asked=True) < cap`; (iii) replace `free = auto and not payments_live` with `free = auto and not (payments_live or instapay)`; (iv) replace `sub.update(acceptance(accounts, now, lambda: fresh_code(db, transaction, code)))` (the `elif auto:` branch) with:
```
            sub.update(
                acceptance(accounts, now, lambda: fresh_code(db, transaction, code))
                if payments_live else instapay_acceptance(now)
            )
```
   c. Anchor: `def respond(` (about line 377): after the line `payments_live: bool = False,` add `instapay: bool = False,`. In the body replace `if held_places(db, transaction, uid, payments_live) >= cap:` with `if held_places(db, transaction, uid, payments_live or instapay) >= cap:`. Then replace the line `if payments_live:` (the one directly under that cap check, followed by `changes = acceptance(_accounts(db, transaction), now, lambda: fresh_code(db, transaction, code))`) with:
```
            if instapay and not payments_live and (coach.to_dict() or {}).get("instapayReady") is not True:
                raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
            if payments_live or instapay:
```
   and replace its next line (`changes = acceptance(_accounts(...), ...)`) with:
```
                changes = (
                    acceptance(_accounts(db, transaction), now, lambda: fresh_code(db, transaction, code))
                    if payments_live else instapay_acceptance(now)
                )
```
   d. Add the error code. File `functions/coaching/errors.py`, after the line `SELLER_NOT_SET = "seller_not_set"` add: `COACH_NOT_READY = "coach_not_ready"` with the docstring line `"""InstaPay is on and she has not saved a payment address yet."""`. (`payments/errors.py` imports its own constant of the same text; both equal `"coach_not_ready"`.)
   e. Anchor: the signature of `def sweep(` (about line 753): leave unchanged. The caller passes `payments=payments or instapay` (step 6).
   Note for (d): add `functions/coaching/errors.py` to the files table of this order's report (it is the 9th file; this edit is three lines and the order stays buildable).
6. File `functions/main.py`. (i) Anchor: the function `_payments_live()` (about line 1912). After it insert:
```python
def _instapay_on() -> bool:
    """The InstaPay kill switch (config/payments.enabled). Off when missing."""
    from payments import model as payments_model

    return payments_model.enabled(store.db())
```
   (ii) Anchor: in `request_coaching` (about line 2104) change `live=_clients_live(), payments_live=_payments_live(), verified=_verified(request),` to `live=_clients_live(), payments_live=_payments_live(), instapay=_instapay_on(), verified=_verified(request),`. In `respond_coaching_request` (about line 2118) change `live=_clients_live(), payments_live=_payments_live(), coach_v=_claim(request, "coachV"),` to `live=_clients_live(), payments_live=_payments_live(), instapay=_instapay_on(), coach_v=_claim(request, "coachV"),`.
   (iii) Anchor: in `coaching_sweeper` (about line 2455) the line `clients, payments = _clients_live(), _payments_live()` becomes `clients, payments = _clients_live(), _payments_live() or _instapay_on()`.
   (iv) Anchor: end of `respond_coaching_request` (the blank lines before `@https_fn.on_call()` of `end_my_coaching`, about line 2121). Insert:
```python
@https_fn.on_call()
def create_payment(request: https_fn.CallableRequest) -> dict:
    """PAY1: a client starts a payment for her accepted package. {subId, idempotencyKey}."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import create

    return _coaching_call(create.create, store.db(), uid, data, now=_coaching_now(), on=_instapay_on())


@https_fn.on_call()
def cancel_payment(request: https_fn.CallableRequest) -> dict:
    """PAY3: the client withdraws an unpaid request. {paymentId}. Works with the switch off."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import cancel

    return _coaching_call(cancel.cancel, store.db(), uid, data, now=_coaching_now())
```
7. File `functions/tests/test_entrypoints.py`. Anchor: the line `"respond_coaching_request",` inside the `CALLABLES` set (about line 95). After it add the lines `"create_payment", "cancel_payment",`. (Every later order adds its callable names here the same way.)
8. File `functions/tests/test_payments_create.py`, create. Imports: `from payments import activation, cancel, create, engine, errors, model, profile`, helpers from `tests.payments_helpers` (including `seed_world`, `SUB`, `CLIENT`, `COACH`, `NOW`, `later`, `payment_of`, `events`, `refusal`, `db`, `_txn`), and `import random`. Helper `go(db, **over)` = `create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd", **over}, now=NOW, on=True, rng=random.Random(1))`. Tests:
| test | arrange, act, assert |
|---|---|
| `test_create_makes_one_payment_with_a_unique_amount_and_a_copy_of_the_address` | `seed_world(db)`; act `go`; assert answer status awaiting_payment, `50001 <= amount <= 50099`, reference matches `^OH-[A-Z2-9]{6}$` without 0 O 1 I L; stored doc has `addressSnapshot == {address, accountName}`, `expiresAt == NOW+24h`, `lateUntil == NOW+7d`, `lockId`, `staffVisible` True, one event `(None, "awaiting_payment", "client")` (the events helper returns `from` None); lock doc exists; profile `paymentsCreated == 1`; subscription `payment.paymentId` equals the id |
| `test_a_repeat_with_the_same_key_returns_the_first_answer_and_makes_no_second_payment` | `go` twice; same `paymentId`; `len(list(db.collection("payments").stream())) == 1` |
| `test_switch_off_refuses_and_writes_nothing` | `on=False` -> `(PRECONDITION, PAYMENTS_OFF)`; no payments |
| `test_someone_elses_subscription_and_a_wrong_status_are_refused` | `uid="other"` -> `(NOT_FOUND, PAYMENT_NOT_FOUND)`; set sub status `active` -> `(PRECONDITION, WRONG_STATUS)` |
| `test_coach_not_ready_when_she_has_no_address_or_is_suspended` | delete the profile address -> `COACH_NOT_READY`; `seed_world(db, suspended=True)` -> `COACH_PAYMENTS_SUSPENDED`; `coachPrivate.suspended = True` -> same |
| `test_a_suspended_client_cannot_start_a_payment` | `paymentStanding/CLIENT = {"clientSuspended": True}` -> `CLIENT_PAYMENTS_SUSPENDED` |
| `test_a_pending_address_is_used_only_after_its_delay` | profile `pending = {address: "new@instapay", accountName: "N", effectiveAt: NOW+1h}` -> snapshot keeps the old address; with `effectiveAt: NOW-1h` -> snapshot is `new@instapay` |
| `test_price_over_the_limit_is_refused` | `coachingConfig/instapay = {"maxAmountEgp": 400}` -> `AMOUNT_OVER_LIMIT` |
| `test_one_open_payment_per_client_and_package` | `go`, then `go(idempotencyKey="key-0002-abcd")` -> `OPEN_PAYMENT_EXISTS`; after `cancel` a new key works |
| `test_three_requests_per_day_then_refused` | create three subscriptions `sub-a..c` (copy of SUB for the same client, status awaiting_payment), create + cancel each, the fourth -> `(EXHAUSTED, TOO_MANY_REQUESTS)`; 25 hours later it works |
| `test_first_payment_is_the_shortest_package_unless_allowed` | `seed_world(db, durations=(28, 56))`, set sub package `durationDays` 56 -> `FIRST_PAYMENT_SHORTEST_ONLY`; profile `allowLongFirst` True -> works; or a prior `confirmed` payment of the client -> works |
| `test_a_collision_cannot_happen_two_clients_same_coach` | second client with its own subscription gets a different amount for the same coach (seeded lock for the first) |
| `test_the_third_payment_of_a_new_coach_is_staff_visible_the_fourth_is_not` | set profile `paymentsCreated` 3 -> `staffVisible` False |
| `test_cancel_ends_the_request_frees_the_amount_and_is_safe_to_repeat` | create, cancel twice: status `cancelled`, lock `heldUntil == NOW`, one cancel event; a stranger gets `PAYMENT_NOT_FOUND`; cancelling a `confirmed` payment -> `(PRECONDITION, ILLEGAL_TRANSITION)` |
| `test_grant_starts_the_coaching_and_provisional_becomes_full` | payment untouched; run in `common.run`: `seen = activation.read_for_start(t, db, SUB)`; `activation.grant(t, db, seen, NOW, provisional_until=later(days=7))` returns `started`; sub is `active`, `provisionalUntil` set, relationship `active`, coach `activeClients == 1`; a second transaction `grant(..., provisional_until=None)` returns `upgraded`, `provisionalUntil` None; a third returns `unchanged` and `activeClients` is still 1 |
| `test_end_stops_a_running_coaching_and_frees_the_place` | after grant, `activation.read_for_end` then `end(..., "dispute", NOW)` returns True; sub `ended_early`, `endReason == "dispute"`, coach `activeClients == 0`; calling again on the ended sub returns False |
| `test_grant_refuses_a_subscription_that_is_not_waiting` | sub status `ended` -> `(PRECONDITION, WRONG_STATUS)` |
Hook tests (same file, import `from coaching import subscriptions` and the helpers `seed, consent, intake, PACKAGE` from `tests.test_coaching_subscriptions`; those helpers seed coach `COACH` = `"coach-uid-1"`, which equals `payments_helpers.COACH`; do NOT call both seeders on one db): `test_respond_with_instapay_waits_for_payment_without_payto`: `seed(db, auto=False, accounts=False)`, set `coaches/coach-uid-1.instapayReady = True`, request (with `instapay=True, payments_live=False`, copy `ask` from that file but pass `instapay=True`), `subscriptions.respond(db, COACH, {"subId": id, "decision": "accept"}, live=True, coach_v="active", now=NOW, notify=Pushes(), instapay=True)`; assert status `awaiting_payment`, `"payTo"` not in the document, `paymentCode` None, `payBy == NOW + 7 days`, no relationship `active`. `test_respond_refuses_when_the_coach_has_no_address`: `instapayReady` absent -> `(PRECONDITION, "coach_not_ready")`. `test_request_auto_accept_with_instapay_waits_for_payment`: `seed(db, auto=True, accounts=False)` with `instapayReady`, request with `instapay=True` -> `awaiting_payment`; without `instapayReady` -> `coach_unavailable`. `test_with_the_switch_off_acceptance_is_free_as_today`: `instapay=False, payments_live=False` -> `active`, `free` True. `test_sweep_expires_an_unpaid_instapay_acceptance_after_seven_days`: accepted request, `subscriptions.sweep(db, now=NOW + 8 days, notify=Pushes(), payments=True)` -> status `expired`.

## Strings to add
None (reason codes only). The app maps these refusals: `payments_off, payment_not_found, wrong_status, coach_not_ready, coach_payments_suspended, client_payments_suspended, amount_over_limit, open_payment_exists, too_many_requests, first_payment_shortest_only, amount_unavailable, illegal_transition`.

## Tests to add or change
`functions/tests/test_payments_create.py` as listed; `functions/tests/test_entrypoints.py` picks up the two new names automatically (its parametrized tests run them).
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_create.py tests/test_entrypoints.py tests/test_coaching_subscriptions.py tests/test_coaching_wrappers.py tests/test_coaching_sweeper.py -q`

## Verify
The command ends with `N passed` and no `failed`. All existing subscription tests must still pass unchanged: they call `request` and `respond` without the new `instapay` argument, which defaults to False.

## Do not
- Do not make `COACH_PAYMENTS_LIVE` True. InstaPay is the kill switch `config/payments`.
- Do not read the price from the request. It comes from the subscription.
- Do not write before every read of the transaction is done.
- Do not start coaching free when InstaPay is on and the coach has no address (the two refusals in step 5).
- Do not edit `contracts/coaching_contract.json`.

## Done checklist
- [ ] profile, create, cancel, activation created
- [ ] subscriptions.py edited in the five places; old tests green
- [ ] two callables registered, names in `CALLABLES`
- [ ] new tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
