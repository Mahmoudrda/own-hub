# WO-10m: Unique piaster amount, reference code, risk score and the GREEN / AMBER / RED outcome
Depends on: WO-10a2
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.7, 4.12, 13.1, 13.2, 13.3 steps 5 to 7, 13.4, 13.9, 13.12 item 3; `functions/payments/engine.py` and `functions/payments/model.py` (from WO-10a2); `functions/coaching/common.py` lines 66-80; `functions/identity/imagesize.py` lines 28-47; `functions/tests/payments_helpers.py`

## Why
A unique amount (500.37 instead of 500.00) and a short reference are what make a payment impossible to confuse with another: the coach's bank SMS and the client's receipt show the same odd number. The outcome rules turn the checks into one of three results the rest of the server obeys. The tamper score only orders staff work; it never blocks an honest woman (spec 13.3 step 6).

## Final result
No screen. Pure, tested building blocks:
- `allocation.allocate(...)`: picks `base + 1..99` piasters not used by an open payment of the same coach, holds it with a lock document, and refuses when none is free. `engine.move` releases or extends the lock.
- `allocation.new_reference(...)`: `OH-` plus 6 characters from an alphabet without look-alikes, unique across payments.
- `risk.tamper_flags(raw)`, `risk.score(flags)`, `risk.decide(checks, uniq, ...)` returning `Outcome(colour, reasons, score, retry_offered)`.

The `checks` dictionary is the contract WO-10l fills in: `amount` (`match|different|missing`), `status` (`success|failed|unknown`), `recipient` (`match|mismatch|missing`), `when` (`in|outside|missing`), `txn` (text or None), `wrongMessage` (bool), `transferLike` (bool), `sender` (`match|different|unknown`), `typedTxn` (bool). `uniq` is `{txnReusedBy, sameImageOf, nearImageOf}` (payment ids or None).

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/allocation.py` | create | amount lock and reference |
| `functions/payments/risk.py` | create | tamper flags, score, decide |
| `functions/payments/engine.py` | edit | `move` keeps the amount lock in step |
| `functions/tests/test_payments_allocation.py` | create | allocation and reference tests |
| `functions/tests/test_payments_risk.py` | create | outcome and score tests |

## Steps
1. Limits. File `functions/payments/model.py`, anchor: the `LIMITS` dict key `"maxAmountEgp": 20000,`. Leave it. Add the note (comment line above it): `# UNVERIFIED: the Central Bank InstaPay per-transaction and daily limits. Verify with the owner or the bank's current limits page, then set coachingConfig/instapay.maxAmountEgp below them. The code refuses a payment above this number (WO-10b).` No other change.
2. File `functions/payments/allocation.py`, create:
```python
"""The unique amount and the reference code (spec 13.2, 13.9)."""

from __future__ import annotations

import datetime as dt
import random

from coaching import common

from . import errors, model

REF_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"   # no 0 O 1 I L
MAX_TRIES = 99   # every candidate; a nearly full coach costs up to 99 small reads


def lock_id(coach_uid: str, amount: int) -> str:
    return f"{coach_uid}__{amount}"


def allocate(transaction, db, coach_uid: str, base_piasters: int, payment_id: str,
             now: dt.datetime, *, rng: random.Random | None = None) -> tuple[int, str]:
    """Reads, then (after the caller's other reads) the caller writes with
    `claim`. Returns (amount, lockId) of a free amount between base+1 and
    base+99 piasters. A lock is free when it does not exist or its heldUntil
    has passed. Two payments of one coach never share an amount while either
    is open; refuses amount_unavailable when none of the 99 is free."""
    rng = rng or random.Random()
    extras = list(range(1, 100))
    rng.shuffle(extras)
    locks = db.collection("paymentAmountLocks")
    for extra in extras[:MAX_TRIES]:
        amount = base_piasters + extra
        snap = locks.document(lock_id(coach_uid, amount)).get(transaction=transaction)
        held = common.as_utc((snap.to_dict() or {}).get("heldUntil")) if snap.exists else None
        if held is None or held <= now:
            return amount, lock_id(coach_uid, amount)
    raise common.refuse(errors.EXHAUSTED, errors.AMOUNT_UNAVAILABLE)


def claim(transaction, db, lock: str, coach_uid: str, amount: int, payment_id: str, now: dt.datetime) -> None:
    """Writes the lock. Held for the late-proof window (7 days); `engine.move`
    extends it while the payment is open and frees it when it ends."""
    transaction.set(
        db.collection("paymentAmountLocks").document(lock),
        {"coachUid": coach_uid, "amountPiasters": amount, "paymentId": payment_id,
         "heldUntil": now + model.days(model.LIMITS["lateProofDays"])},
    )


def new_reference(transaction, db, *, rng: random.Random | None = None) -> str:
    """OH-XXXXXX, not used by any payment (five tries)."""
    rng = rng or random.SystemRandom()
    for _ in range(5):
        candidate = "OH-" + "".join(rng.choice(REF_ALPHABET) for _ in range(6))
        taken = db.collection("payments").where("reference", "==", candidate).limit(1)
        if not any(True for _ in taken.stream(transaction=transaction)):
            return candidate
    raise common.refuse(errors.EXHAUSTED, errors.AMOUNT_UNAVAILABLE)
```
3. File `functions/payments/engine.py` (WO-10a2). Anchor: in `move`, the line `transaction.update(ref, update)`. Immediately after that line insert (4-space indent, inside the function):
```python
    lock = payment.get("lockId")
    if lock:
        held = now + model.days(30) if to in model.HOLDS_AMOUNT else now
        transaction.update(db.collection("paymentAmountLocks").document(lock), {"heldUntil": held})
```
This is a blind update (no read), so it never breaks the reads-before-writes rule of a Firestore transaction.
4. File `functions/payments/risk.py`, create:
```python
"""The outcome of a proof, and a score that only orders staff work (spec 13.3, 13.4, 13.12)."""

from __future__ import annotations

from dataclasses import dataclass, field

from identity import imagesize

GREEN, AMBER, RED = "green", "amber", "red"

WEIGHTS = {
    "editorTag": 30,        # the file names a photo editor
    "cameraExif": 20,       # a camera photo, not a screenshot
    "oddSize": 15,          # not a phone-screen shape
    "tooSmall": 10,
    "clockMismatch": 15,    # the status-bar clock disagrees with the claimed time (WO-10l)
    "doubleCompression": 20,  # reserved: JPEG double compression (UNVERIFIED: no library installed)
    "sameImageOther": 40,
    "nearImageOther": 30,
    "txnReused": 40,
}
_EDITORS = (b"Photoshop", b"Adobe", b"GIMP", b"Canva", b"Snapseed", b"PicsArt", b"Pixelmator", b"Lightroom")


def tamper_flags(raw: bytes) -> list[str]:
    """Cheap signals from the bytes of a screenshot BEFORE it is re-encoded.
    They never reject a picture; they raise the score."""
    flags: list[str] = []
    head = raw[:65536]
    if any(tag in head for tag in _EDITORS):
        flags.append("editorTag")
    if b"Exif\x00\x00" in head and (b"Make" in head or b"Model" in head):
        flags.append("cameraExif")
    size = imagesize.dimensions(raw)
    if size is not None:
        width, height = size
        long_side, short_side = max(width, height), max(1, min(width, height))
        if not (1.6 <= long_side / short_side <= 2.4):
            flags.append("oddSize")
        if short_side < 600:
            flags.append("tooSmall")
    return flags


def score(flags: list[str]) -> int:
    return min(100, sum(WEIGHTS.get(f, 0) for f in set(flags)))


@dataclass(frozen=True)
class Outcome:
    colour: str
    reasons: list[str] = field(default_factory=list)
    score: int = 0
    retry_offered: bool = False


def decide(checks: dict, uniq: dict, flags: list[str], *, retry_used: bool, other_payer_ok: bool = False) -> Outcome:
    """GREEN: amount, success status and recipient all found, and a transaction
    number or a time inside the window, on something that looks like a transfer
    receipt. RED: a deterministic contradiction or a reuse. Everything else is
    AMBER. A card or balance message is AMBER with reason wrongMessage and never
    uses up the retry. Tamper flags change the score only."""
    all_flags = list(flags)
    if uniq.get("sameImageOf"):
        all_flags.append("sameImageOther")
    if uniq.get("nearImageOf"):
        all_flags.append("nearImageOther")
    if uniq.get("txnReusedBy"):
        all_flags.append("txnReused")
    points = score(all_flags)

    if checks.get("wrongMessage"):
        # A card or balance message is not a transfer receipt, so nothing it says
        # (a different amount, an old date) can be a contradiction. Never RED.
        return Outcome(AMBER, ["wrongMessage"], points, True)  # always another try, never counted

    red = []
    if checks.get("amount") == "different":
        red.append("amountDiffers")
    if checks.get("status") == "failed":
        red.append("transferFailed")
    if checks.get("recipient") == "mismatch":
        red.append("recipientDiffers")
    if checks.get("when") == "outside":
        red.append("timeOutsideWindow")
    if uniq.get("txnReusedBy"):
        red.append("txnReused")
    if uniq.get("sameImageOf"):
        red.append("sameImage")
    if uniq.get("nearImageOf"):
        red.append("nearImage")
    if red:
        return Outcome(RED, red, points, False)

    missing = []
    if checks.get("amount") != "match":
        missing.append("amountUnreadable")
    if checks.get("status") != "success":
        missing.append("statusUnknown")
    if checks.get("recipient") != "match":
        missing.append("recipientUnreadable")
    if not (checks.get("txn") or checks.get("when") == "in"):
        missing.append("needDetails")          # the receipt without More Details open (13.12 item 1)
    if not checks.get("transferLike"):
        missing.append("notATransferReceipt")  # an SMS alone is never GREEN (13.13)
    if checks.get("sender") == "different" and not other_payer_ok:
        missing.append("someoneElsePaid")
    if missing:
        offer = (not retry_used) and not checks.get("typedTxn")
        return Outcome(AMBER, missing, points, offer)
    return Outcome(GREEN, [], points, False)
```
5. File `functions/tests/test_payments_allocation.py`, create:
```python
from __future__ import annotations

import random

import pytest

from coaching import common
from payments import allocation, engine, errors, model, states
from tests.payments_helpers import AMOUNT, BASE, COACH, NOW, PAY, REVIEWER, _txn, db, later, make_payment, refusal  # noqa: F401


def test_an_amount_is_between_one_and_ninety_nine_piasters_above_the_base(db):
    amount, lock = common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW, rng=random.Random(1)))
    assert BASE + 1 <= amount <= BASE + 99 and lock == f"{COACH}__{amount}"


def test_two_open_payments_of_one_coach_never_share_an_amount(db):
    seen = set()
    for n in range(30):
        def body(t, n=n):
            amount, lock = allocation.allocate(t, db, COACH, BASE, f"p{n}", NOW, rng=random.Random(n))
            allocation.claim(t, db, lock, COACH, amount, f"p{n}", NOW)
            return amount
        seen.add(common.run(db, body))
    assert len(seen) == 30


def test_a_lock_that_has_expired_is_free_again(db):
    db.document(f"paymentAmountLocks/{COACH}__{BASE + 1}").set({"heldUntil": later(hours=-1), "paymentId": "old"})
    rng = random.Random(3)
    for extra in range(2, 100):
        db.document(f"paymentAmountLocks/{COACH}__{BASE + extra}").set({"heldUntil": later(days=2), "paymentId": "x"})
    amount, _ = common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW, rng=rng))
    assert amount == BASE + 1


def test_all_ninety_nine_taken_is_refused(db):
    for extra in range(1, 100):
        db.document(f"paymentAmountLocks/{COACH}__{BASE + extra}").set({"heldUntil": later(days=2), "paymentId": "x"})
    assert refusal(lambda: common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW))) == (errors.EXHAUSTED, errors.AMOUNT_UNAVAILABLE)


def test_another_coach_may_use_the_same_amount(db):
    db.document(f"paymentAmountLocks/other-coach__{BASE + 5}").set({"heldUntil": later(days=2), "paymentId": "x"})
    for extra in range(1, 100):
        if extra != 5:
            db.document(f"paymentAmountLocks/{COACH}__{BASE + extra}").set({"heldUntil": later(days=2), "paymentId": "x"})
    amount, _ = common.run(db, lambda t: allocation.allocate(t, db, COACH, BASE, PAY, NOW, rng=random.Random(0)))
    assert amount == BASE + 5


def test_moving_to_a_finished_status_frees_the_lock_and_open_statuses_extend_it(db):
    make_payment(db, status="awaiting_payment", lockId=f"{COACH}__{AMOUNT}")
    db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").set({"heldUntil": later(days=7), "paymentId": PAY})

    def to(status, role):
        def body(t):
            ref, row = engine.load(t, db, PAY)
            engine.move(t, db, ref, row, status, role, None, NOW)
        common.run(db, body)

    to("proof_submitted", states.CLIENT)
    assert db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").get().to_dict()["heldUntil"] == later(days=30)
    to("confirmed", states.COACH)
    assert db.document(f"paymentAmountLocks/{COACH}__{AMOUNT}").get().to_dict()["heldUntil"] == NOW


def test_a_reference_has_six_characters_without_lookalikes_and_is_unique(db):
    made = set()
    for n in range(50):
        ref = common.run(db, lambda t, n=n: allocation.new_reference(t, db, rng=random.Random(n)))
        assert ref.startswith("OH-") and len(ref) == 9 and not set(ref[3:]) & set("01OIL")
        make_payment(db, f"p{n}", reference=ref)
        made.add(ref)
    assert len(made) == 50


def test_a_reference_already_in_use_is_skipped(db):
    first = common.run(db, lambda t: allocation.new_reference(t, db, rng=random.Random(7)))
    make_payment(db, "pa", reference=first)
    again = common.run(db, lambda t: allocation.new_reference(t, db, rng=random.Random(7)))
    assert again != first
```
(With the same seed the first draw clashes, so the function draws again from the same generator and returns a different reference.)
6. File `functions/tests/test_payments_risk.py`, create:
```python
from __future__ import annotations

import pytest

from payments import risk

GOOD = dict(amount="match", status="success", recipient="match", when="in", txn="1234567890123",
            wrongMessage=False, transferLike=True, sender="match", typedTxn=False)
CLEAN = dict(txnReusedBy=None, sameImageOf=None, nearImageOf=None)


def decide(**over):
    checks = {**GOOD, **{k: v for k, v in over.items() if k in GOOD}}
    uniq = {**CLEAN, **{k: v for k, v in over.items() if k in CLEAN}}
    return risk.decide(checks, uniq, over.get("flags", []), retry_used=over.get("retry_used", False), other_payer_ok=over.get("other_payer_ok", False))


def test_everything_found_is_green():
    assert decide().colour == risk.GREEN


@pytest.mark.parametrize("over,reason", [
    ({"amount": "different"}, "amountDiffers"), ({"status": "failed"}, "transferFailed"),
    ({"recipient": "mismatch"}, "recipientDiffers"), ({"when": "outside"}, "timeOutsideWindow"),
    ({"txnReusedBy": "p9"}, "txnReused"), ({"sameImageOf": "p9"}, "sameImage"), ({"nearImageOf": "p9"}, "nearImage"),
])
def test_a_contradiction_or_a_reuse_is_red_and_offers_no_retry(over, reason):
    out = decide(**over)
    assert out.colour == risk.RED and reason in out.reasons and out.retry_offered is False


@pytest.mark.parametrize("over", [
    {"amount": "missing"}, {"status": "unknown"}, {"recipient": "missing"},
    {"when": "missing", "txn": None}, {"transferLike": False},
])
def test_a_missing_invariant_is_amber_never_red(over):
    out = decide(**over)
    assert out.colour == risk.AMBER and out.retry_offered is True


def test_the_receipt_without_details_is_amber_with_need_details():
    out = decide(txn=None, when="missing")
    assert out.colour == risk.AMBER and "needDetails" in out.reasons


def test_a_time_inside_the_window_replaces_the_transaction_number():
    assert decide(txn=None, when="in").colour == risk.GREEN


def test_the_second_amber_offers_no_retry_and_a_typed_number_offers_none():
    assert decide(amount="missing", retry_used=True).retry_offered is False
    assert decide(amount="missing", typedTxn=True).retry_offered is False


def test_a_card_message_is_amber_and_never_uses_the_retry():
    out = decide(wrongMessage=True, retry_used=True)
    assert out.colour == risk.AMBER and out.reasons == ["wrongMessage"] and out.retry_offered is True


def test_someone_else_paying_is_amber_until_she_confirms_once():
    assert decide(sender="different").reasons == ["someoneElsePaid"]
    assert decide(sender="different", other_payer_ok=True).colour == risk.GREEN


def test_tamper_flags_change_the_score_and_never_the_colour():
    flags = ["editorTag", "cameraExif", "oddSize", "tooSmall", "clockMismatch"]
    out = decide(flags=flags)
    assert out.colour == risk.GREEN and out.score == 90
    assert risk.score(flags + ["doubleCompression"]) == 100


def test_tamper_flags_read_editor_tags_and_camera_exif():
    jpeg_head = b"\xff\xd8\xff\xe1\x00\x10Exif\x00\x00Make Adobe Photoshop"
    flags = risk.tamper_flags(jpeg_head + b"\x00" * 50)
    assert "editorTag" in flags and "cameraExif" in flags


def test_garbage_bytes_never_raise():
    assert isinstance(risk.tamper_flags(b""), list) and isinstance(risk.tamper_flags(b"\x00" * 100), list)
```
(The size flags need a real image header; they are tested in WO-10l with a synthetic PNG header. Do not add one here.)

## Strings to add
None.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `functions/tests/test_payments_allocation.py` | the eight above | as written |
| `functions/tests/test_payments_risk.py` | the tests above (about 26 with parametrize) | as written |

Command: `cd functions && venv/bin/python -m pytest tests/test_payments_allocation.py tests/test_payments_risk.py tests/test_payments_states.py -q`

## Verify
The command ends with `N passed`, no `failed`. In `test_payments_states.py` the move test still passes with the lock edit (a payment without `lockId` is untouched).

## Do not
- Do not let a tamper flag, an unknown layout or a card message produce RED.
- Do not read a document after a write inside a transaction.
- Do not put the amount lock query behind a composite index; it is a get by id.
- Do not pick the amount in the app: the server picks it.

## Done checklist
- [ ] allocation, reference, risk files created
- [ ] `engine.move` keeps the lock in step
- [ ] all tests pass, including the earlier states tests

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
