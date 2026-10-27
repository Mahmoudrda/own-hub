"""Tests for different amounts, coach reports, and auto-confirm (WO-10b3)."""

from __future__ import annotations

import datetime as dt
import pytest

from coaching import errors as c_errors
from payments import amounts, coach, create, errors, profile, report
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


def test_coach_marks_less_and_the_client_is_told(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")

    res = amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": 40000, "acceptLower": False}, coach_v="active", now=NOW, notify=notes)
    assert res == {"status": "different_amount"}

    pay = payment_of(db)
    assert pay["status"] == "different_amount"
    assert pay["coachDecision"]["differentAmountPiasters"] == 40000
    assert pay["coachDecision"]["acceptLower"] is False
    assert (CLIENT, "instapayDifferentAmount") in notes.sent

    # Repeat call changes nothing
    res2 = amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": 40000, "acceptLower": False}, coach_v="active", now=NOW, notify=notes)
    assert res2 == {"status": "different_amount"}


def test_equal_or_more_is_not_a_different_amount(db, notes):
    seed_world(db)
    make_payment(db, status="proof_submitted")

    assert refusal(lambda: amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": AMOUNT, "acceptLower": False}, coach_v="active", now=NOW, notify=notes))[0] == c_errors.INVALID
    assert refusal(lambda: amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": 60000, "acceptLower": False}, coach_v="active", now=NOW, notify=notes))[0] == c_errors.INVALID

    pay = payment_of(db)
    assert pay["status"] == "proof_submitted"


def test_from_awaiting_payment_it_is_illegal(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment")
    assert refusal(lambda: amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": 40000, "acceptLower": False}, coach_v="active", now=NOW, notify=notes)) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_client_agrees_to_a_written_lower_amount_and_the_package_starts(db, notes):
    seed_world(db)
    make_payment(db, status="different_amount", coachDecision={"differentAmountPiasters": 40000, "acceptLower": True, "decidedAt": NOW})

    res = amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "agree"}, now=NOW, notify=notes)
    assert res == {"status": "confirmed"}

    pay = payment_of(db)
    assert pay["status"] == "confirmed"
    assert pay["access"]["state"] == "full"
    assert pay["feePiasters"] == 6000  # 15% of 40000

    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "active"


def test_agree_without_the_coach_accepting_is_refused_and_nothing_starts(db, notes):
    seed_world(db)
    make_payment(db, status="different_amount", coachDecision={"differentAmountPiasters": 40000, "acceptLower": False, "decidedAt": NOW})

    assert refusal(lambda: amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "agree"}, now=NOW, notify=notes)) == (errors.PRECONDITION, errors.WRONG_STATUS)

    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "awaiting_payment"


def test_client_disputes_a_different_amount_and_it_goes_to_review(db, notes):
    seed_world(db)
    make_payment(db, status="different_amount", coachDecision={"differentAmountPiasters": 40000, "acceptLower": False, "decidedAt": NOW})

    res = amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "dispute"}, now=NOW, notify=notes)
    assert res == {"status": "in_review"}

    pay = payment_of(db)
    assert pay["status"] == "in_review"
    assert pay["dispute"]["kind"] == "different_amount"
    assert (COACH, "instapayDisputeOpened") in notes.sent


def test_pay_the_rest_makes_a_new_reference_cancels_the_old_one_and_fees_the_whole_price(db, notes):
    seed_world(db)
    make_payment(db, status="different_amount", coachDecision={"differentAmountPiasters": 40000, "acceptLower": False, "decidedAt": NOW})

    res = create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-topup-0001", "topUpOf": PAY}, now=NOW, on=True)
    new_pid = res["paymentId"]
    assert new_pid != PAY

    new_pay = payment_of(db, new_pid)
    assert new_pay["topUpOf"] == PAY
    assert new_pay["baseAmountPiasters"] == 50037 - 40000  # 10037
    assert new_pay["feeBasePiasters"] == 50000

    old_pay = payment_of(db, PAY)
    assert old_pay["status"] == "cancelled"

    # Confirming the new payment computes fee on full feeBasePiasters (50000)
    from coaching import common
    from payments import activation
    def _do_confirm(txn):
        seen = activation.read_for_start(txn, db, new_pay["subId"])
        return coach.apply_confirmation(
            txn, db, db.document(f"payments/{new_pid}"), new_pay,
            seen, profile.profile_ref(db, COACH), {}, {"feeBpsMarketplace": 1500, "feeBpsInvite": 800},
            NOW, "client", CLIENT, None,
        )
    common.run(db, _do_confirm)
    confirmed_new = payment_of(db, new_pid)
    assert confirmed_new["feePiasters"] == 7500


def test_top_up_of_someone_elses_or_a_wrong_status_payment_is_refused(db):
    seed_world(db)
    # Wrong status: proof_submitted
    make_payment(db, "pay-ps", status="proof_submitted")
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-top-err-1", "topUpOf": "pay-ps"}, now=NOW, on=True)) == (errors.PRECONDITION, errors.WRONG_STATUS)

    # acceptLower is True -> refuse WRONG_STATUS
    make_payment(db, "pay-lower-acc", status="different_amount", coachDecision={"differentAmountPiasters": 40000, "acceptLower": True})
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-top-err-2", "topUpOf": "pay-lower-acc"}, now=NOW, on=True)) == (errors.PRECONDITION, errors.WRONG_STATUS)


def test_coach_reports_a_payment_by_reference_and_by_subscription(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment", reference="OH-4821")

    # By reference
    res = report.coach_report(db, COACH, {"reference": "OH-4821", "txnNumber": "301234567890123"}, coach_v="active", now=NOW, notify=notes)
    assert res["paymentId"] == PAY
    assert res["status"] == "awaiting_payment"

    pay = payment_of(db)
    assert pay["coachReport"]["txnNumber"] == "301234567890123"
    assert (CLIENT, "instapayCoachReported") in notes.sent

    # Repeat is idempotent
    res2 = report.coach_report(db, COACH, {"reference": "OH-4821", "txnNumber": "301234567890123"}, coach_v="active", now=NOW, notify=notes)
    assert res2 == res

    # By subId (delete earlier payment so only one open payment matches this sub)
    db.document(f"payments/{PAY}").delete()
    make_payment(db, "pay-sub-report", status="awaiting_payment", reference="OH-9999")
    db.document(f"subscriptions/{SUB}").update({"payment.paymentId": "pay-sub-report"})
    res3 = report.coach_report(db, COACH, {"subId": SUB, "txnNumber": "444444444444444"}, coach_v="active", now=NOW, notify=notes)
    assert res3["paymentId"] == "pay-sub-report"


def test_report_refuses_unknown_closed_and_reused(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment", reference="OH-4821")

    # Unknown reference
    assert refusal(lambda: report.coach_report(db, COACH, {"reference": "OH-NONE", "txnNumber": "1234567890"}, coach_v="active", now=NOW, notify=notes)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)

    # Confirmed status
    make_payment(db, "pay-conf", status="confirmed", reference="OH-CONF")
    assert refusal(lambda: report.coach_report(db, COACH, {"reference": "OH-CONF", "txnNumber": "1234567890"}, coach_v="active", now=NOW, notify=notes)) == (errors.PRECONDITION, errors.WRONG_STATUS)

    # Reused txn key
    db.document("paymentTxnNumbers/REUSEDTXNKEY").set({"paymentId": "other-pay"})
    assert refusal(lambda: report.coach_report(db, COACH, {"reference": "OH-4821", "txnNumber": "REUSEDTXNKEY"}, coach_v="active", now=NOW, notify=notes)) == (errors.PRECONDITION, errors.TXN_REUSED)

    # After lateUntil
    make_payment(db, "pay-past-late", status="awaiting_payment", reference="OH-LATE", lateUntil=NOW - dt.timedelta(hours=1))
    assert refusal(lambda: report.coach_report(db, COACH, {"reference": "OH-LATE", "txnNumber": "1234567890"}, coach_v="active", now=NOW, notify=notes)) == (errors.PRECONDITION, errors.WRONG_STATUS)


def test_client_says_yes_and_the_package_starts_with_the_fee(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment", coachReport={"txnNumber": "123", "txnKey": "123", "reportedAt": NOW, "clientAnswer": None})

    res = report.client_answer(db, CLIENT, {"paymentId": PAY, "answer": "yes"}, now=NOW, notify=notes)
    assert res == {"status": "confirmed"}

    pay = payment_of(db)
    assert pay["status"] == "confirmed"
    assert pay["feeState"] == "owed"
    assert pay["access"]["state"] == "full"
    sub = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert sub["status"] == "active"
    assert (COACH, "instapayConfirmedByClient") in notes.sent

    # Also works from expired status
    make_payment(db, "pay-exp", status="expired", coachReport={"txnNumber": "123", "txnKey": "123", "reportedAt": NOW, "clientAnswer": None})
    res2 = report.client_answer(db, CLIENT, {"paymentId": "pay-exp", "answer": "yes"}, now=NOW, notify=notes)
    assert res2 == {"status": "confirmed"}


def test_client_says_no_and_nothing_changes_but_the_note(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment", coachReport={"txnNumber": "123", "txnKey": "123", "reportedAt": NOW, "clientAnswer": None})

    res = report.client_answer(db, CLIENT, {"paymentId": PAY, "answer": "no"}, now=NOW, notify=notes)
    assert res == {"status": "awaiting_payment"}

    pay = payment_of(db)
    assert pay["coachReport"]["clientAnswer"] == "no"
    assert pay["access"]["state"] == "none"


def test_client_answer_needs_a_report(db, notes):
    seed_world(db)
    make_payment(db, status="awaiting_payment")
    assert refusal(lambda: report.client_answer(db, CLIENT, {"paymentId": PAY, "answer": "yes"}, now=NOW, notify=notes)) == (errors.PRECONDITION, errors.NO_COACH_REPORT)


def test_auto_confirm_needs_three_clean_payments(db):
    seed_world(db)
    db.document("coachingConfig/instapay").set({"autoConfirmAllowed": True})
    db.document(f"coachPaymentProfiles/{COACH}").update({"cleanConfirmed": 2})

    # cleanConfirmed < 3 -> WRONG_STATUS
    assert refusal(lambda: coach.set_auto_confirm(db, COACH, {"enabled": True}, coach_v="active", now=NOW)) == (errors.PRECONDITION, errors.WRONG_STATUS)

    # cleanConfirmed == 3 -> success
    db.document(f"coachPaymentProfiles/{COACH}").update({"cleanConfirmed": 3})
    res = coach.set_auto_confirm(db, COACH, {"enabled": True}, coach_v="active", now=NOW)
    assert res == {"autoConfirmGreen": True}

    # Disabling always works
    res2 = coach.set_auto_confirm(db, COACH, {"enabled": False}, coach_v="active", now=NOW)
    assert res2 == {"autoConfirmGreen": False}

    # Non-bool -> bad_request
    assert refusal(lambda: coach.set_auto_confirm(db, COACH, {"enabled": "true"}, coach_v="active", now=NOW))[0] == c_errors.INVALID


def test_a_new_coach_defaults_to_manual_confirmation(db):
    seed_world(db)
    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["autoConfirmGreen"] is False
