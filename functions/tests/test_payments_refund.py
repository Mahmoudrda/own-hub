"""Tests for refunds and service disputes (WO-10b4)."""

from __future__ import annotations

import datetime as dt
import pytest

from coaching import errors as c_errors
from payments import errors, refund
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


def seed_confirmed_payment(db, **over):
    seed_world(db)
    row = {
        "status": "confirmed", "coachDecision": {"confirmedAt": NOW, "receivedPiasters": AMOUNT},
        "overpaidPiasters": 0, "access": {"state": "full", "until": None},
        "feeState": "owed", "feeOwedAt": NOW, "feePiasters": 7500,
    }
    row.update(over)
    make_payment(db, **row)
    db.document(f"subscriptions/{SUB}").update({
        "status": "active", "sessionsUsed": 0, "sessionsIncluded": 4,
    })


def test_client_asks_for_a_refund_once_inside_14_days(db, notes):
    seed_confirmed_payment(db)
    t = NOW + dt.timedelta(days=13)

    res = refund.request(db, CLIENT, {"paymentId": PAY}, now=t, notify=notes)
    assert res == {"status": "refund_requested"}

    pay = payment_of(db)
    assert pay["status"] == "refund_requested"
    assert pay["refund"]["coachDueAt"] == t + dt.timedelta(days=3)
    assert (COACH, "instapayRefundRequested") in notes.sent

    # Second call returns the same
    res2 = refund.request(db, CLIENT, {"paymentId": PAY}, now=t + dt.timedelta(hours=1), notify=notes)
    assert res2 == {"status": "refund_requested"}

    # After refunded, another ask raises REFUND_ALREADY_REQUESTED
    db.document(f"payments/{PAY}").update({"status": "refunded"})
    assert refusal(lambda: refund.request(db, CLIENT, {"paymentId": PAY}, now=t + dt.timedelta(hours=2), notify=notes)) == (errors.PRECONDITION, errors.REFUND_ALREADY_REQUESTED)


def test_the_window_closes_after_14_days(db, notes):
    seed_confirmed_payment(db)
    t = NOW + dt.timedelta(days=15)
    assert refusal(lambda: refund.request(db, CLIENT, {"paymentId": PAY}, now=t, notify=notes)) == (errors.PRECONDITION, errors.REFUND_WINDOW_CLOSED)


def test_only_a_paid_payment_can_ask_and_only_its_client(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")
    # proof_submitted -> ILLEGAL_TRANSITION
    assert refusal(lambda: refund.request(db, CLIENT, {"paymentId": PAY}, now=NOW, notify=notes)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)

    # coach uid -> PAYMENT_NOT_FOUND
    seed_confirmed_payment(db)
    assert refusal(lambda: refund.request(db, COACH, {"paymentId": PAY}, now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_coach_denies_and_the_client_can_appeal(db, notes):
    seed_confirmed_payment(db, status="refund_requested", refund={"requestedAt": NOW, "coachDueAt": NOW + dt.timedelta(days=3)})

    res = refund.deny(db, COACH, {"paymentId": PAY, "reasonCode": "sessions_delivered"}, coach_v="active", now=NOW + dt.timedelta(days=1), notify=notes)
    assert res == {"status": "refund_denied"}

    pay = payment_of(db)
    assert pay["status"] == "refund_denied"
    assert pay["refund"]["deniedReason"] == "sessions_delivered"
    assert (CLIENT, "instapayReviewDecided") in notes.sent

    # Client appeals via open_service_dispute
    res2 = refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=NOW + dt.timedelta(days=2), notify=notes)
    assert res2 == {"status": "in_review"}
    pay2 = payment_of(db)
    assert pay2["status"] == "in_review"
    assert pay2["dispute"]["kind"] == "refund"


def test_coach_records_a_refund_the_package_ends_and_the_fee_follows_what_was_kept(db, notes):
    seed_confirmed_payment(db, status="refund_requested", refund={"requestedAt": NOW, "coachDueAt": NOW + dt.timedelta(days=3)})
    db.document(f"coaches/{COACH}").update({"activeClients": 1})

    res = refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 50037, "kind": "refund"}, coach_v="active", now=NOW + dt.timedelta(days=1), notify=notes)
    assert res == {"status": "refunded"}

    pay = payment_of(db)
    assert pay["status"] == "refunded"
    assert pay["refund"]["partial"] is False
    assert pay["feePiasters"] == 0
    assert (CLIENT, "instapayRefundRecorded") in notes.sent

    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "ended_early"
    assert sub["endReason"] == "refund"

    coach_doc = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach_doc["activeClients"] == 0

    # Repeat is harmless
    res2 = refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 50037, "kind": "refund"}, coach_v="active", now=NOW + dt.timedelta(days=1), notify=notes)
    assert res2 == {"status": "refunded"}


def test_a_partial_refund_after_sessions_were_delivered(db, notes):
    seed_confirmed_payment(db, status="refund_requested", refund={"requestedAt": NOW, "coachDueAt": NOW + dt.timedelta(days=3)})

    refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 20000, "kind": "refund"}, coach_v="active", now=NOW + dt.timedelta(days=1), notify=notes)

    pay = payment_of(db)
    assert pay["refund"]["partial"] is True
    # Kept: 50037 - 20000 = 30037. Base is 50000. Lower is 30037. 15% of 30037 = 4505
    assert pay["feePiasters"] == 4505


def test_an_overpayment_is_recorded_without_ending_anything(db, notes):
    seed_confirmed_payment(db, overpaidPiasters=963)

    res = refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "OP12345678901", "amountPiasters": 963, "kind": "overpayment"}, coach_v="active", now=NOW, notify=notes)
    assert res == {"status": "confirmed"}

    pay = payment_of(db)
    assert pay["status"] == "confirmed"
    assert pay["refund"]["overpayment"]["amountPiasters"] == 963

    # amount > overpaidPiasters -> bad_request
    assert refusal(lambda: refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "OP12345678901", "amountPiasters": 964, "kind": "overpayment"}, coach_v="active", now=NOW, notify=notes))[0] == c_errors.INVALID


def test_a_refund_cannot_exceed_the_payment_and_needs_a_valid_number(db, notes):
    seed_confirmed_payment(db, status="refund_requested")

    assert refusal(lambda: refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 50038, "kind": "refund"}, coach_v="active", now=NOW, notify=notes))[0] == c_errors.INVALID

    assert refusal(lambda: refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "12", "amountPiasters": 50000, "kind": "refund"}, coach_v="active", now=NOW, notify=notes))[0] == c_errors.INVALID


def test_in_review_needs_the_staff_refund_decision_before_the_coach_records(db, notes):
    seed_confirmed_payment(db, status="in_review")

    # Without staffDecision -> ILLEGAL_TRANSITION
    assert refusal(lambda: refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 50000, "kind": "refund"}, coach_v="active", now=NOW, notify=notes)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)

    # With staffDecision == refund_owed -> success
    db.document(f"payments/{PAY}").update({"dispute.staffDecision": "refund_owed"})
    res = refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 50000, "kind": "refund"}, coach_v="active", now=NOW, notify=notes)
    assert res == {"status": "refunded"}


def test_service_dispute_goes_to_review_with_the_facts_and_is_limited_to_three_a_month(db, notes):
    seed_confirmed_payment(db)
    db.document(f"subscriptions/{SUB}").update({"sessionsUsed": 1, "sessionsIncluded": 4})

    res = refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=NOW, notify=notes)
    assert res == {"status": "in_review"}

    pay = payment_of(db)
    assert pay["status"] == "in_review"
    assert pay["dispute"]["serviceFacts"] == {"sessionsUsed": 1, "sessionsIncluded": 4}
    assert pay["access"]["state"] == "full"

    evs = events(db)
    assert ("confirmed", "service_dispute", "client") in evs
    assert ("service_dispute", "in_review", "system") in evs

    # Limited to 3 a month
    db.document(f"paymentStanding/{CLIENT}").set({"disputes_202611": 3})
    make_payment(db, "pay-disp-limit", status="confirmed")
    assert refusal(lambda: refund.open_service_dispute(db, CLIENT, {"paymentId": "pay-disp-limit"}, now=NOW, notify=notes)) == (errors.EXHAUSTED, errors.DISPUTE_LIMIT)


def test_no_cross_party_access(db, notes):
    seed_confirmed_payment(db)
    # Coach cannot open service dispute
    assert refusal(lambda: refund.open_service_dispute(db, COACH, {"paymentId": PAY}, now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)

    # Client cannot record refund
    db.document(f"coachPrivate/{CLIENT}").set({"suspended": False})
    assert refusal(lambda: refund.record(db, CLIENT, {"paymentId": PAY, "txnNumber": "R123456789012", "amountPiasters": 50000, "kind": "refund"}, coach_v="active", now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
