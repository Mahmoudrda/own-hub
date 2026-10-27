"""Tests for submit_instapay_proof and coach_confirm_payment (WO-10b2)."""

from __future__ import annotations

import datetime as dt
import hashlib
import pytest

from coaching import dhash, errors as c_errors
from payments import coach, engine, errors, proof, risk
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import (
    ACCOUNT_NAME,
    ADDRESS,
    AMOUNT,
    BASE,
    CLIENT,
    CLIENT2,
    COACH,
    COACH2,
    NOW,
    PAY,
    SUB,
    Notes,
    _txn,
    db,
    events,
    later,
    make_payment,
    notes,
    payment_of,
    refusal,
    seed_world,
)
from tests.test_coaching_subscriptions import make_jpeg

INSTAPAY_FIRST = (
    "Approved Transaction\nYour transaction was successful\n500.37 EGP\n"
    "From\nlayla@instapay\n*** 4821\nTo Instapay\nRah*** M***\nrahma@instapay\nMore Details"
)
DETAILS = "More Details\nTransaction ID\n301234567890123\nDate 10/11/2026 14:05"
CARD_SMS = "Your credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre"
WRONG_AMOUNT_TXT = (
    "Your transaction was successful\n450.00 EGP\nrahma@instapay\n"
    "Transaction ID 301234567890123\nDate 10/11/2026 14:05"
)


class Reader:
    def __init__(self, *texts):
        self.texts = list(texts)
        self.idx = 0

    def read(self, jpeg):
        if not self.texts:
            return ""
        t = self.texts[min(self.idx, len(self.texts) - 1)]
        self.idx += 1
        return t


def keep(raw, long_side=None):
    return raw


@pytest.fixture
def blobs():
    return FakeBlobs()


def send(db, blobs, notes, reader, *, images=None, key="key-0001-abcd", **over):
    payload = {"paymentId": PAY, "idempotencyKey": key, "amountPiasters": AMOUNT}
    payload.update(over)
    return proof.submit(
        db, CLIENT, payload, images or [make_jpeg(1), make_jpeg(2)],
        now=NOW + dt.timedelta(minutes=10), blobs=blobs, reencode=keep, reader=reader, notify=notes,
    )


def test_green_two_screenshots_give_bounded_access_and_tell_the_coach(db, blobs, notes):
    seed_world(db)
    make_payment(db, with_created_event=True)
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    res = send(db, blobs, notes, reader)
    assert res["outcome"] == "green"
    assert res["status"] == "proof_submitted"
    assert res["retry"] is False

    pay = payment_of(db)
    assert pay["access"]["state"] == "provisional"
    assert pay["access"]["until"] == NOW + dt.timedelta(minutes=10, days=7)
    assert pay["feePiasters"] == 7500
    assert pay["feeState"] == "owed"

    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "active"
    assert sub["provisionalUntil"] is not None

    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["status"] == "active"

    assert f"payment-proofs/{PAY}/client-1.jpg" in blobs.objects
    assert f"payment-proofs/{PAY}/client-2.jpg" in blobs.objects
    assert notes.sent == [(COACH, "instapayProofSent")]

    review = db.document(f"payments/{PAY}/staff/review").get().to_dict()
    assert "riskScore" in review
    assert "hashes" in review

    assert db.document("paymentTxnNumbers/301234567890123").get().exists
    evs = events(db)
    assert (None, "awaiting_payment", "client") in evs
    assert ("awaiting_payment", "proof_submitted", "client") in evs


def test_the_first_screen_alone_is_amber_with_one_retry_and_records_only_the_attempt(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST)

    res = send(db, blobs, notes, reader, images=[make_jpeg(1)])
    assert res["retry"] is True
    assert res["outcome"] == "amber"
    assert "needDetails" in res["reasons"]

    pay = payment_of(db)
    assert pay["status"] == "awaiting_payment"
    assert len(blobs.objects) == 0
    assert pay["proof"]["amberAttempts"] == 1
    assert pay["proof"]["screenshotCount"] == 1

    reader2 = Reader(INSTAPAY_FIRST, DETAILS)
    res2 = send(db, blobs, notes, reader2, key="key-0002-wxyz")
    assert res2["outcome"] == "green"


def test_a_second_amber_stands_and_waits_for_the_coach_for_24_hours(db, blobs, notes):
    seed_world(db)
    make_payment(db, proof={"screenshotCount": 1, "amberAttempts": 1, "screenshotPaths": [], "imageFlags": []})
    reader = Reader(INSTAPAY_FIRST)

    res = send(db, blobs, notes, reader, images=[make_jpeg(1)])
    assert res["retry"] is False
    assert res["status"] == "proof_submitted"

    pay = payment_of(db)
    assert pay["access"]["state"] == "none"
    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "awaiting_payment"
    assert pay["amberUntil"] == NOW + dt.timedelta(minutes=10, hours=24)


def test_a_typed_transaction_number_lets_an_amber_stand_at_once(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST)

    res = send(db, blobs, notes, reader, images=[make_jpeg(1)], txnNumber="301234567890123")
    assert res["status"] == "proof_submitted"
    assert res["retry"] is False


def test_wrong_amount_is_red_and_goes_to_review(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(WRONG_AMOUNT_TXT)

    res = send(db, blobs, notes, reader, images=[make_jpeg(1)])
    assert res["outcome"] == "red"
    assert res["status"] == "in_review"

    pay = payment_of(db)
    assert pay["dispute"]["kind"] == "proof_red"
    assert pay["access"]["state"] == "none"
    assert (CLIENT, "instapayReviewStarted") in notes.sent
    assert (COACH, "instapayDisputeOpened") in notes.sent
    evs = events(db)
    assert ("proof_submitted", "in_review", "system") in evs


def test_a_reused_transaction_number_is_red_and_flagged_for_both(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    db.document("paymentTxnNumbers/301234567890123").set({"paymentId": "other"})
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    res = send(db, blobs, notes, reader)
    assert res["outcome"] == "red"
    pay = payment_of(db)
    assert "txnReused" in pay["proof"]["imageFlags"]
    assert db.document("paymentTxnNumbers/301234567890123").get().to_dict()["paymentId"] == "other"


def test_the_same_picture_for_another_payment_is_red(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    sha1 = hashlib.sha256(make_jpeg(1)).hexdigest()
    db.document(f"paymentImageHashes/{sha1}").set({"paymentId": "other", "dHash": "0000000000000000"})
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    res = send(db, blobs, notes, reader)
    assert res["outcome"] == "red"
    pay = payment_of(db)
    assert "sameImage" in pay["proof"]["imageFlags"]


def test_a_near_copy_is_red(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    h1 = dhash.to_text(dhash.dhash(make_jpeg(1)))
    db.document("paymentImageHashes/prior-sha").set({"paymentId": "other", "dHash": h1, "createdAt": NOW})
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    # noise=1 or 3
    img = make_jpeg(1, noise=1)
    res = send(db, blobs, notes, reader, images=[img, make_jpeg(2)])
    assert res["outcome"] == "red"
    pay = payment_of(db)
    assert "nearImage" in pay["proof"]["imageFlags"]


def test_a_card_message_gets_a_retry_that_does_not_count(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(CARD_SMS)

    res = send(db, blobs, notes, reader, images=[make_jpeg(1)])
    assert res["retry"] is True
    assert res["reasons"] == ["wrongMessage"]
    pay = payment_of(db)
    assert pay["proof"]["amberAttempts"] == 0
    assert pay["proof"]["screenshotCount"] == 1


def test_amount_typed_must_equal_the_payment(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    assert refusal(lambda: send(db, blobs, notes, reader, amountPiasters=50000)) == (errors.INVALID, errors.AMOUNT_MISMATCH)
    assert len(blobs.objects) == 0


def test_five_screenshots_is_the_most_per_payment(db, blobs, notes):
    seed_world(db)
    make_payment(db, proof={"screenshotCount": 4, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []})
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    assert refusal(lambda: send(db, blobs, notes, reader, images=[make_jpeg(1), make_jpeg(2)])) == (errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
    assert refusal(lambda: send(db, blobs, notes, reader, images=[make_jpeg(1), make_jpeg(2), make_jpeg(3), make_jpeg(4)]))[0] == c_errors.INVALID


def test_late_proof_within_seven_days_is_accepted_and_after_is_not(db, blobs, notes):
    seed_world(db)
    make_payment(db, status="expired", lateUntil=NOW + dt.timedelta(days=7))
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    # 6 days later: accepted
    t_in = NOW + dt.timedelta(days=6)
    proof.submit(
        db, CLIENT, {"paymentId": PAY, "idempotencyKey": "k-late-1", "amountPiasters": AMOUNT},
        [make_jpeg(1), make_jpeg(2)], now=t_in, blobs=blobs, reencode=keep, reader=reader, notify=notes,
    )

    # 8 days later: closed
    make_payment(db, "pay-late-2", status="expired", lateUntil=NOW + dt.timedelta(days=7))
    t_out = NOW + dt.timedelta(days=8)
    assert refusal(lambda: proof.submit(
        db, CLIENT, {"paymentId": "pay-late-2", "idempotencyKey": "k-late-2", "amountPiasters": AMOUNT},
        [make_jpeg(1), make_jpeg(2)], now=t_out, blobs=blobs, reencode=keep, reader=reader, notify=notes,
    )) == (errors.PRECONDITION, errors.PROOF_WINDOW_CLOSED)

    # confirmed status: wrong status
    make_payment(db, "pay-conf", status="confirmed")
    assert refusal(lambda: proof.submit(
        db, CLIENT, {"paymentId": "pay-conf", "idempotencyKey": "key-conf-0001", "amountPiasters": AMOUNT},
        [make_jpeg(1), make_jpeg(2)], now=NOW, blobs=blobs, reencode=keep, reader=reader, notify=notes,
    )) == (errors.PRECONDITION, errors.WRONG_STATUS)


def test_a_double_tap_makes_one_proof(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    res1 = send(db, blobs, notes, reader, key="key-double-0001")
    count_blobs = len(blobs.objects)
    count_events = len([e for e in events(db) if e[1] == "proof_submitted"])
    count_notices = len(notes.sent)

    res2 = send(db, blobs, notes, reader, key="key-double-0001")
    assert res1 == res2
    assert len(blobs.objects) == count_blobs
    assert len([e for e in events(db) if e[1] == "proof_submitted"]) == count_events
    assert len(notes.sent) == count_notices


def test_a_failing_transaction_deletes_the_files(db, blobs, notes, monkeypatch):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    def blow_up(*args, **kwargs):
        raise RuntimeError("boom")

    monkeypatch.setattr(engine, "move", blow_up)
    with pytest.raises(RuntimeError):
        send(db, blobs, notes, reader)
    assert len(blobs.objects) == 0


def test_a_suspended_client_cannot_send_proof(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    db.document(f"paymentStanding/{CLIENT}").set({"clientSuspended": True})
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    assert refusal(lambda: send(db, blobs, notes, reader)) == (errors.PRECONDITION, errors.CLIENT_PAYMENTS_SUSPENDED)


def test_a_phone_clock_claim_changes_nothing(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    res = send(db, blobs, notes, reader, paidAtClaimed="2031-01-01T00:00:00Z")
    assert res["outcome"] == "green"
    pay = payment_of(db)
    assert pay["proof"]["paidAtClaimed"] == "2031-01-01T00:00:00Z"


def test_someone_else_paying_is_amber_then_allowed_once(db, blobs, notes):
    seed_world(db)
    make_payment(db)

    # senderHandle != text sender (text sender is layla@instapay)
    res = send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS), senderHandle="mine@instapay")
    assert res["outcome"] == "amber"
    assert "someoneElsePaid" in res["reasons"]

    # Allowed once with otherPayerOk=True
    res2 = send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS), senderHandle="mine@instapay", otherPayerOk=True, key="key-0002-other")
    assert res2["outcome"] == "green"
    st = db.document(f"paymentStanding/{CLIENT}").get().to_dict()
    assert st["otherPayerCount"] == 1

    # Second time with otherPayerCount=1 is amber again
    make_payment(db, "pay-second")
    details_new_txn = DETAILS.replace("301234567890123", "999999999999999")
    res3 = proof.submit(
        db, CLIENT, {"paymentId": "pay-second", "idempotencyKey": "key-0003-second", "amountPiasters": AMOUNT, "otherPayerOk": True},
        [make_jpeg(3), make_jpeg(4)], now=NOW + dt.timedelta(minutes=10), blobs=blobs, reencode=keep, reader=Reader(INSTAPAY_FIRST, details_new_txn), notify=notes,
    )
    assert res3["outcome"] == "amber"


def test_auto_confirm_green_confirms_at_once_and_keeps_the_audit(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"autoConfirmGreen": True})
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    res = send(db, blobs, notes, reader)
    assert res["status"] == "confirmed"
    pay = payment_of(db)
    assert pay["coachDecision"]["autoConfirmed"] is True
    assert pay["access"]["state"] == "full"
    evs = events(db)
    assert any(e[1] == "confirmed" and e[2] == "system" for e in evs)
    assert (CLIENT, "instapayConfirmed") in notes.sent


def test_a_stranger_cannot_send_proof(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)

    assert refusal(lambda: proof.submit(
        db, "stranger-uid", {"paymentId": PAY, "idempotencyKey": "k-stranger", "amountPiasters": AMOUNT},
        [make_jpeg(1), make_jpeg(2)], now=NOW + dt.timedelta(minutes=10), blobs=blobs, reencode=keep, reader=reader, notify=notes,
    )) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


# ---------------------------------------------------- Coach Confirm Tests

def test_coach_confirms_after_a_green_proof_and_access_becomes_full(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)
    send(db, blobs, notes, reader)

    res = coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW + dt.timedelta(minutes=15), notify=notes)
    assert res == {"status": "confirmed"}

    pay = payment_of(db)
    assert pay["status"] == "confirmed"
    assert pay["access"]["state"] == "full"
    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub.get("provisionalUntil") is None

    coach_doc = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach_doc["activeClients"] == 1

    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["paymentsConfirmed"] == 1
    assert prof["cleanConfirmed"] == 1
    assert (CLIENT, "instapayConfirmed") in notes.sent


def test_coach_confirms_an_amber_and_the_coaching_starts_then(db, blobs, notes):
    seed_world(db)
    make_payment(db, proof={"screenshotCount": 1, "amberAttempts": 1, "screenshotPaths": [], "imageFlags": []})
    reader = Reader(INSTAPAY_FIRST)
    send(db, blobs, notes, reader, images=[make_jpeg(1)])

    res = coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW + dt.timedelta(minutes=15), notify=notes)
    assert res == {"status": "confirmed"}
    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "active"


def test_a_repeat_confirm_changes_nothing(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)
    send(db, blobs, notes, reader)

    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW + dt.timedelta(minutes=15), notify=notes)
    count1 = len([e for e in events(db) if e[1] == "confirmed"])
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW + dt.timedelta(minutes=16), notify=notes)
    count2 = len([e for e in events(db) if e[1] == "confirmed"])
    assert count1 == count2 == 1


def test_nobody_but_the_payments_coach_can_confirm_and_a_record_is_needed(db, blobs, notes):
    seed_world(db)
    db.document(f"coaches/{COACH2}").set({"published": True})
    db.document(f"coachPrivate/{COACH2}").set({"suspended": False})
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)
    send(db, blobs, notes, reader)

    # Other coach
    assert refusal(lambda: coach.confirm(db, COACH2, {"paymentId": PAY}, coach_v="active", now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    # Unknown id
    assert refusal(lambda: coach.confirm(db, COACH, {"paymentId": "wrong-id"}, coach_v="active", now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    # Client calling (even if registered as a coach)
    db.document(f"coachPrivate/{CLIENT}").set({"suspended": False})
    assert refusal(lambda: coach.confirm(db, CLIENT, {"paymentId": PAY}, coach_v="active", now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_confirm_needs_a_proof(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment")
    assert refusal(lambda: coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW, notify=notes)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_a_suspended_coach_cannot_confirm_and_the_client_stays_protected(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)
    send(db, blobs, notes, reader)

    db.document(f"coachPrivate/{COACH}").set({"suspended": True})
    assert refusal(lambda: coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW, notify=notes)) == (c_errors.PERMISSION, c_errors.COACH_SUSPENDED)
    pay = payment_of(db)
    assert pay["access"]["state"] == "provisional"


def test_received_less_is_refused_here_and_more_is_recorded_as_overpaid(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    reader = Reader(INSTAPAY_FIRST, DETAILS)
    send(db, blobs, notes, reader)

    assert refusal(lambda: coach.confirm(db, COACH, {"paymentId": PAY, "receivedPiasters": 40000}, coach_v="active", now=NOW, notify=notes))[0] == c_errors.INVALID

    coach.confirm(db, COACH, {"paymentId": PAY, "receivedPiasters": 51000}, coach_v="active", now=NOW, notify=notes)
    pay = payment_of(db)
    assert pay["overpaidPiasters"] == 51000 - AMOUNT


def test_the_invite_fee_tier_is_eight_percent(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    db.document(f"relationships/{COACH}__{CLIENT}").update({"source": "invite"})
    reader = Reader(INSTAPAY_FIRST, DETAILS)
    send(db, blobs, notes, reader)

    pay = payment_of(db)
    assert pay["feePiasters"] == 4000
    assert pay["feeBps"] == 800
