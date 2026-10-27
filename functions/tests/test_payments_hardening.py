"""Hardening of the InstaPay engine after the audit of commit 3bae145 (27 Oct 2026).

One test per hole: bounded provisional access, an acceptance that outlives a
payment in flight, refunds that are not self-attested, the lock that leaked
between payments, the evidence race, what the coach can read, the caps that
could be walked around, and the exits for expired requests.
"""

from __future__ import annotations

import datetime as dt
import random

import pytest

from coaching import common, errors as c_errors, subscriptions
from payments import address as address_mod, amounts, cancel, coach, create, errors, model, refund, staff, timers
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import (  # noqa: F401
    ADDRESS, AMOUNT, BASE, CLIENT, COACH, NOW, PAY, REVIEWER, SUB, Notes, _txn, db, events, later, make_payment,
    notes, payment_of, refusal, seed_world,
)
from tests.test_payments_proof import DETAILS, INSTAPAY_FIRST, WRONG_AMOUNT_TXT, Reader, blobs, send  # noqa: F401
from tests.payments_helpers import phone_jpeg
from tests.test_payments_refund import PAID_AT, seed_confirmed_payment

SENT = NOW + dt.timedelta(minutes=10)           # when send() submits the proof
WEEK = dt.timedelta(days=7)


def sub_of(db):
    return db.document(f"subscriptions/{SUB}").get().to_dict()


def green_proof(db, blobs, notes, **seed):
    seed_world(db, **seed)
    make_payment(db, with_created_event=True)
    return send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS))


# ------------------------------------------------ 1. provisional access is bounded

def test_a_green_proof_runs_the_coaching_for_seven_days_not_for_the_whole_package(db, blobs, notes):
    green_proof(db, blobs, notes)
    sub = sub_of(db)
    assert sub["status"] == "active"
    assert sub["endsAt"] == SENT + WEEK and sub["provisionalUntil"] == SENT + WEEK


def test_a_package_shorter_than_a_week_is_never_stretched_to_one(db, blobs, notes):
    green_proof(db, blobs, notes, durations=(3,))
    assert sub_of(db)["endsAt"] == SENT + dt.timedelta(days=3)


def test_the_sweeper_ends_provisional_access_the_coach_never_confirmed(db, blobs, notes):
    green_proof(db, blobs, notes)
    counts = subscriptions.sweep(db, now=SENT + WEEK + dt.timedelta(hours=1), notify=notes)
    assert counts["ended"] == 1
    assert sub_of(db)["status"] == "ended"
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["chatOpen"] is False
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0


def test_the_ends_soon_notice_is_not_sent_for_a_short_stay_waiting_on_the_coach(db, blobs, notes):
    green_proof(db, blobs, notes)
    counts = subscriptions.sweep(db, now=SENT + dt.timedelta(days=5), notify=notes)
    assert counts["endsSoon"] == 0 and sub_of(db)["status"] == "active"


def test_a_confirmation_inside_the_limit_extends_the_access_to_the_whole_package(db, blobs, notes):
    green_proof(db, blobs, notes)
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=SENT + dt.timedelta(days=1), notify=notes)
    sub = sub_of(db)
    assert sub["provisionalUntil"] is None and sub["endsAt"] == SENT + dt.timedelta(days=28)
    assert subscriptions.sweep(db, now=SENT + WEEK + dt.timedelta(days=1), notify=notes)["ended"] == 0


def test_a_confirmation_after_the_limit_restarts_the_coaching_for_the_whole_package(db, blobs, notes):
    green_proof(db, blobs, notes)
    subscriptions.sweep(db, now=SENT + WEEK + dt.timedelta(hours=1), notify=notes)
    late = SENT + WEEK + dt.timedelta(days=1)
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=late, notify=notes)
    sub = sub_of(db)
    assert sub["status"] == "active" and sub["provisionalUntil"] is None and sub["endsAt"] == late + dt.timedelta(days=28)
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["chatOpen"] is True
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 1
    assert payment_of(db)["access"]["state"] == "full"


def test_a_confirmation_when_the_acceptance_is_gone_is_honest_about_the_access(db, blobs, notes):
    green_proof(db, blobs, notes)
    db.document(f"subscriptions/{SUB}").update({"status": "ended_early", "provisionalUntil": None})
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=SENT + dt.timedelta(days=1), notify=notes)
    pay = payment_of(db)
    assert pay["status"] == "confirmed" and pay["access"]["state"] == "none"
    assert sub_of(db)["status"] == "ended_early"


# ------------------------------------------------ 8. auto-confirm is off until the owner turns it on

def test_auto_confirm_is_off_by_default_in_config(db):
    assert model.config(db)["autoConfirmAllowed"] is False
    db.document("coachingConfig/instapay").set({"autoConfirmAllowed": "yes"})
    assert model.config(db)["autoConfirmAllowed"] is False
    db.document("coachingConfig/instapay").set({"autoConfirmAllowed": True})
    assert model.config(db)["autoConfirmAllowed"] is True


def test_a_green_proof_waits_for_the_coach_while_the_owners_switch_is_off(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"autoConfirmGreen": True})
    res = send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS))
    assert res["outcome"] == "green" and res["status"] == "proof_submitted"
    assert payment_of(db)["access"]["state"] == "provisional"


def test_a_coach_cannot_turn_auto_confirm_on_while_the_owners_switch_is_off(db):
    seed_world(db)
    db.document(f"coachPaymentProfiles/{COACH}").update({"cleanConfirmed": 5})
    assert refusal(lambda: coach.set_auto_confirm(db, COACH, {"enabled": True}, coach_v="active", now=NOW)) == (
        errors.PRECONDITION, errors.AUTO_CONFIRM_OFF)
    assert coach.set_auto_confirm(db, COACH, {"enabled": False}, coach_v="active", now=NOW) == {"autoConfirmGreen": False}


# ------------------------------------------------ 4. an acceptance outlives a payment in flight

def test_an_acceptance_with_a_payment_waiting_for_a_decision_is_held_past_its_pay_by_day(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")
    db.document(f"subscriptions/{SUB}").update({"payBy": NOW - dt.timedelta(days=1)})
    counts = subscriptions.sweep(db, now=NOW, notify=notes, payments=True)
    assert counts["expiredPayments"] == 0 and sub_of(db)["status"] == "awaiting_payment"


@pytest.mark.parametrize("status", ["cancelled", "resolved_unpaid", "confirmed"])
def test_an_acceptance_whose_payment_is_over_still_expires(db, notes, status):
    seed_world(db)
    make_payment(db, status=status)
    db.document(f"subscriptions/{SUB}").update({"payBy": NOW - dt.timedelta(days=1)})
    assert subscriptions.sweep(db, now=NOW, notify=notes, payments=True)["expiredPayments"] == 1


def test_an_acceptance_with_no_payment_at_all_expires_as_before(db, notes):
    seed_world(db)
    db.document(f"subscriptions/{SUB}").update({"payBy": NOW - dt.timedelta(days=1)})
    assert subscriptions.sweep(db, now=NOW, notify=notes, payments=True)["expiredPayments"] == 1


def test_creating_a_payment_late_in_the_week_keeps_the_acceptance_for_its_late_proof_window(db):
    seed_world(db)
    db.document(f"subscriptions/{SUB}").update({"payBy": NOW + dt.timedelta(days=1)})
    create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=True, rng=random.Random(1))
    assert sub_of(db)["payBy"] >= NOW + WEEK


def test_the_coach_confirming_after_the_original_pay_by_day_still_starts_the_coaching(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted", proof={"screenshotCount": 2, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []})
    db.document(f"subscriptions/{SUB}").update({"payBy": NOW + dt.timedelta(days=1)})
    three_days = NOW + dt.timedelta(days=3)
    subscriptions.sweep(db, now=three_days, notify=notes, payments=True)
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=three_days, notify=notes)
    assert sub_of(db)["status"] == "active"


# ------------------------------------------------ 5. refunds are not self-attested

def refund_requested(db):
    seed_confirmed_payment(db, status="refund_requested", refund={"requestedAt": NOW, "coachDueAt": NOW + dt.timedelta(days=3)},
                           proof={"txnKey": "301234567890123", "screenshotCount": 0, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []})


def record(db, notes, *, txn="400000000001", amount=AMOUNT, paid_at=PAID_AT, now=None, **extra):
    data = {"paymentId": PAY, "txnNumber": txn, "amountPiasters": amount, "kind": "refund", "paidAt": paid_at, **extra}
    return refund.record(db, COACH, data, coach_v="active", now=now or NOW + dt.timedelta(days=1), notify=notes)


@pytest.mark.parametrize("txn", ["R123456789012", "123456", "123456789", "1" * 21, "abcdefghijkl", "12 34"])
def test_a_refund_number_has_to_look_like_a_bank_transaction_number(db, notes, txn):
    refund_requested(db)
    assert refusal(lambda: record(db, notes, txn=txn)) == (c_errors.INVALID, errors.REFUND_TXN_INVALID)
    assert payment_of(db)["status"] == "refund_requested"


def test_the_refund_number_cannot_be_the_clients_own_payment_number(db, notes):
    refund_requested(db)
    assert refusal(lambda: record(db, notes, txn="301234567890123")) == (errors.PRECONDITION, errors.TXN_REUSED)


def test_a_number_already_used_for_another_payment_cannot_prove_a_refund(db, notes):
    refund_requested(db)
    db.document("paymentTxnNumbers/400000000001").set({"paymentId": "some-other-payment"})
    assert refusal(lambda: record(db, notes)) == (errors.PRECONDITION, errors.TXN_REUSED)


def test_a_recorded_refund_claims_its_number_for_good(db, notes):
    refund_requested(db)
    record(db, notes)
    assert db.document("paymentTxnNumbers/400000000001").get().to_dict()["paymentId"] == PAY
    assert payment_of(db)["refund"]["txnKey"] == "400000000001"


@pytest.mark.parametrize("paid_at", [None, "yesterday", 5, "2026-11-09T12:00:00+00:00", "2026-11-12T12:00:00+00:00"])
def test_a_refund_needs_the_time_she_sent_the_money_and_it_must_be_plausible(db, notes, paid_at):
    refund_requested(db)
    assert refusal(lambda: record(db, notes, paid_at=paid_at)) == (c_errors.INVALID, errors.REFUND_PAID_AT_INVALID)


def test_a_refund_staff_ordered_cannot_be_smaller_than_the_amount_they_named(db, notes):
    seed_confirmed_payment(db, status="in_review", dispute={"kind": "service", "staffDecision": "refund_owed", "refundOwedPiasters": 40000, "decidedAt": NOW})
    with pytest.raises(c_errors.CoachingError):
        record(db, notes, amount=30000)
    assert record(db, notes, amount=40000) == {"status": "refunded"}


def test_the_client_can_answer_a_refund_she_never_received_and_refunded_is_not_final(db, notes):
    refund_requested(db)
    record(db, notes)
    t = NOW + dt.timedelta(days=2)
    assert refund.open_service_dispute(db, CLIENT, {"paymentId": PAY, "note": "nothing arrived"}, now=t, notify=notes) == {"status": "in_review"}
    pay = payment_of(db)
    assert pay["status"] == "in_review" and pay["dispute"]["kind"] == "refund_not_received"
    assert ("refunded", "in_review", "client") in events(db)
    assert (COACH, "instapayDisputeOpened") in notes.sent

    staff.resolve(db, REVIEWER, {"paymentId": PAY, "outcome": "refund_owed", "reason": "the client says it never came", "refundPiasters": AMOUNT},
                  now=t + dt.timedelta(hours=1), notify=notes)
    # the coach may record again, but not with the number the client disputed
    again = dict(now=t + dt.timedelta(hours=2), paid_at=(t + dt.timedelta(hours=2)).isoformat())
    assert refusal(lambda: record(db, notes, **again)) == (errors.PRECONDITION, errors.TXN_REUSED)
    assert record(db, notes, txn="400000000002", **again) == {"status": "refunded"}
    assert payment_of(db)["refund"]["txnKey"] == "400000000002"


def test_a_refund_dispute_has_a_window_and_is_used_once(db, notes):
    refund_requested(db)
    record(db, notes)
    assert refusal(lambda: refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=NOW + dt.timedelta(days=40), notify=notes)) == (
        errors.PRECONDITION, errors.DISPUTE_WINDOW_CLOSED)
    db.document(f"payments/{PAY}").update({"disputeKinds": ["refund_not_received"]})
    assert refusal(lambda: refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=NOW + dt.timedelta(days=2), notify=notes)) == (
        errors.PRECONDITION, errors.DISPUTE_ALREADY_USED)


# ------------------------------------------------ 6. money, evidence and who reads what

def test_cancelling_a_lapsed_payment_leaves_the_lock_another_payment_now_holds(db):
    seed_world(db)
    lock = f"{COACH}__{AMOUNT}"
    make_payment(db, "pay-a", lockId=lock)
    db.document(f"paymentAmountLocks/{lock}").set({"coachUid": COACH, "amountPiasters": AMOUNT, "paymentId": "pay-b", "heldUntil": later(days=7)})
    cancel.cancel(db, CLIENT, {"paymentId": "pay-a"}, now=NOW + dt.timedelta(hours=1))
    held = db.document(f"paymentAmountLocks/{lock}").get().to_dict()
    assert held["paymentId"] == "pay-b" and held["heldUntil"] == later(days=7)


def test_cancelling_frees_the_lock_the_payment_still_owns(db):
    seed_world(db)
    lock = f"{COACH}__{AMOUNT}"
    make_payment(db, "pay-a", lockId=lock)
    db.document(f"paymentAmountLocks/{lock}").set({"coachUid": COACH, "amountPiasters": AMOUNT, "paymentId": "pay-a", "heldUntil": later(days=7)})
    cancel.cancel(db, CLIENT, {"paymentId": "pay-a"}, now=NOW + dt.timedelta(hours=1))
    assert db.document(f"paymentAmountLocks/{lock}").get().to_dict()["heldUntil"] == NOW + dt.timedelta(hours=1)


def mark_less(db, notes, received, accept):
    return amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": received, "acceptLower": accept},
                        coach_v="active", now=NOW, notify=notes)


def test_a_coach_cannot_accept_a_token_amount_in_writing_to_shrink_the_fee(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")
    assert refusal(lambda: mark_less(db, notes, 39999, True)) == (c_errors.INVALID, errors.ACCEPT_LOWER_TOO_LOW)
    assert refusal(lambda: mark_less(db, notes, 1, True)) == (c_errors.INVALID, errors.ACCEPT_LOWER_TOO_LOW)
    assert mark_less(db, notes, 40000, True) == {"status": "different_amount"}


def test_reporting_a_much_lower_amount_without_accepting_it_stays_possible(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")
    assert mark_less(db, notes, 100, False) == {"status": "different_amount"}


class Tripwire(FakeBlobs):
    """On its first write another call gets in and finishes first: the race."""

    def __init__(self, other):
        super().__init__()
        self.other, self.fired = other, False

    def write(self, path, data, content_type):
        super().write(path, data, content_type)
        if not self.fired:
            self.fired = True
            self.other(self)


def test_a_call_that_loses_the_race_deletes_only_its_own_files(db, notes):
    seed_world(db)
    make_payment(db)
    win = lambda store: send(db, store, notes, Reader(INSTAPAY_FIRST, DETAILS), key="key-winner-0001")  # noqa: E731
    store = Tripwire(win)
    lose = lambda: send(db, store, notes, Reader(INSTAPAY_FIRST, DETAILS), key="key-loser-00001", images=[phone_jpeg(3), phone_jpeg(4)])  # noqa: E731
    assert refusal(lose) == (errors.PRECONDITION, errors.WRONG_STATUS)
    kept = payment_of(db)["proof"]["screenshotPaths"]
    assert len(kept) == 2 and set(store.objects) == set(kept)


def test_the_five_picture_limit_is_judged_inside_the_transaction(db, notes):
    seed_world(db)
    make_payment(db)
    first_screen_only = lambda store: send(db, store, notes, Reader(INSTAPAY_FIRST), key="key-winner-0002",  # noqa: E731
                                           images=[phone_jpeg(5), phone_jpeg(6), phone_jpeg(7)])
    store = Tripwire(first_screen_only)
    lose = lambda: send(db, store, notes, Reader(INSTAPAY_FIRST, DETAILS), key="key-loser-00002",  # noqa: E731
                        images=[phone_jpeg(1), phone_jpeg(2), phone_jpeg(3)])
    assert refusal(lose) == (errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
    assert payment_of(db)["proof"]["screenshotCount"] == 3 and not store.objects


def test_a_repeat_with_the_same_key_leaves_no_orphan_pictures(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS), key="key-double-0009")
    before = set(blobs.objects)
    send(db, blobs, notes, Reader(INSTAPAY_FIRST, DETAILS), key="key-double-0009")
    assert set(blobs.objects) == before


def test_the_clients_dispute_note_is_not_on_the_payment_the_coach_reads(db, notes):
    seed_confirmed_payment(db)
    refund.open_service_dispute(db, CLIENT, {"paymentId": PAY, "note": "private words to staff"}, now=NOW, notify=notes)
    assert "private words" not in str(payment_of(db)) and "clientNote" not in str(payment_of(db))
    assert db.document(f"payments/{PAY}/staff/dispute").get().to_dict()["clientNote"] == "private words to staff"
    evidence = staff.get_evidence(db, REVIEWER, {"paymentId": PAY}, now=NOW)
    assert evidence["dispute"]["clientNote"] == "private words to staff"


def test_the_fraud_reasons_live_in_the_staff_document_not_on_the_payment(db, blobs, notes):
    seed_world(db)
    make_payment(db)
    res = send(db, blobs, notes, Reader(WRONG_AMOUNT_TXT))
    assert res["outcome"] == "red" and res["reasons"] == ["review"]   # neutral: a forger is not told which check failed
    pay = payment_of(db)
    assert "reasons" not in pay and "reasons" not in pay["dispute"]
    assert pay["outcome"] == "red" and pay["hint"] == "review" and "amountDiffers" not in str(pay)
    assert db.document(f"payments/{PAY}/staff/review").get().to_dict()["reasons"] == ["amountDiffers"]


def test_a_service_problem_must_be_raised_inside_the_package_and_a_grace_period(db, notes):
    seed_confirmed_payment(db)       # a 28 day package that began at NOW
    inside = NOW + dt.timedelta(days=28 + 13)
    outside = NOW + dt.timedelta(days=28 + 15)
    assert refusal(lambda: refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=outside, notify=notes)) == (
        errors.PRECONDITION, errors.DISPUTE_WINDOW_CLOSED)
    assert refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=inside, notify=notes) == {"status": "in_review"}


def test_a_service_problem_cannot_be_raised_twice_on_one_payment(db, notes):
    seed_confirmed_payment(db, disputeKinds=["service"])
    assert refusal(lambda: refund.open_service_dispute(db, CLIENT, {"paymentId": PAY}, now=NOW, notify=notes)) == (
        errors.PRECONDITION, errors.DISPUTE_ALREADY_USED)


def test_disputing_a_different_amount_counts_toward_the_three_a_month(db, notes):
    seed_world(db)
    make_payment(db, status="different_amount", coachDecision={"differentAmountPiasters": 40000, "acceptLower": False})
    db.document(f"paymentStanding/{CLIENT}").set({"disputes_202611": 3})
    assert refusal(lambda: amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "dispute"}, now=NOW, notify=notes)) == (
        errors.EXHAUSTED, errors.DISPUTE_LIMIT)
    db.document(f"paymentStanding/{CLIENT}").set({"disputes_202611": 2})
    amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "dispute"}, now=NOW, notify=notes)
    assert db.document(f"paymentStanding/{CLIENT}").get().to_dict()["disputes_202611"] == 3


@pytest.mark.parametrize("status", ["refund_denied", "confirmed", "proof_submitted", "resolved_unpaid"])
def test_respond_is_no_back_door_into_review_around_the_cap(db, notes, status):
    seed_world(db)
    make_payment(db, status=status)
    assert refusal(lambda: amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "dispute"}, now=NOW, notify=notes)) == (
        errors.PRECONDITION, errors.WRONG_STATUS)
    assert payment_of(db)["status"] == status


def test_the_coach_is_told_when_her_own_payment_details_change_but_not_when_she_first_sets_them(db, notes):
    seed_world(db)
    change = lambda: address_mod.set_address(db, COACH, {"address": "new.name@instapay", "accountName": "Rahma M."},  # noqa: E731
                                             coach_v="active", recent_sign_in=True, now=NOW, notify=notes)
    change()
    assert (COACH, "instapayAddressChangedCoach") in notes.sent

    other = Notes()
    seed_world(db, ready=False)
    db.document(f"coachPaymentProfiles/{COACH}").delete()
    address_mod.set_address(db, COACH, {"address": "first@instapay", "accountName": "First Coach"},
                            coach_v="active", recent_sign_in=True, now=NOW, notify=other)
    assert other.sent == []


# ------------------------------------------------ an expired request has an exit

def test_an_expired_request_can_be_cancelled_by_the_client_and_frees_its_amount(db, notes):
    seed_world(db)
    made = create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=True, rng=random.Random(1))
    later_ = NOW + dt.timedelta(days=1, hours=1)
    assert timers.expire(db, made["paymentId"], later_) == "expired"
    cancel.cancel(db, CLIENT, {"paymentId": made["paymentId"]}, now=later_)
    assert payment_of(db, made["paymentId"])["status"] == "cancelled"
    lock = db.document(f"paymentAmountLocks/{COACH}__{made['amountPiasters']}").get().to_dict()
    assert lock["heldUntil"] <= later_
    create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0002-abcd"}, now=later_, on=True, rng=random.Random(2))


def test_an_expired_request_whose_late_window_closed_does_not_block_a_new_one(db):
    seed_world(db)
    make_payment(db, status="expired", lateUntil=NOW - dt.timedelta(hours=1))
    create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0003-abcd"}, now=NOW, on=True, rng=random.Random(3))


def test_an_expired_request_still_inside_its_late_window_does_block_a_second_one(db):
    seed_world(db)
    make_payment(db, status="expired", lateUntil=NOW + dt.timedelta(hours=1))
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0004-abcd"}, now=NOW, on=True)) == (
        errors.PRECONDITION, errors.OPEN_PAYMENT_EXISTS)
