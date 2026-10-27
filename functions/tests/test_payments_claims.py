"""The coach's 'not received' with her own bank list, and adding evidence (WO-10n, spec 13.5)."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import errors as c_errors
from payments import claims, engine, errors
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import (  # noqa: F401
    AMOUNT, CLIENT, COACH, COACH2, NOW, PAY, SUB, Notes, _txn, db, events, later, make_payment, notes, payment_of, refusal,
    seed_world,
)
from tests.payments_helpers import phone_jpeg
from tests.test_payments_hardening import sub_of
from tests.test_payments_proof import Reader, keep

TXN = "301234567890123"
NOW1 = NOW + dt.timedelta(hours=1)


@pytest.fixture
def blobs():
    return FakeBlobs()


def proof_submitted(db, **over):
    seed_world(db)
    row = dict(status="proof_submitted", outcome="green", access={"state": "provisional", "until": later(days=7)}, feeState="owed",
               feeOwedAt=NOW, feePiasters=7500, proof={"screenshotCount": 2, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": [], "txnNumber": TXN})
    row.update(over)
    make_payment(db, **row)
    db.document(f"subscriptions/{SUB}").update({"status": "active", "provisionalUntil": later(days=7), "endsAt": later(days=7)})


def claim(db, blobs, notes, *texts, who=COACH, now=NOW1, images=None, **over):
    data = {"paymentId": PAY, "reasonCode": "not_seen", "note": "I looked at my bank", "searched": True, **over}
    return claims.not_received(db, who, data, images if images is not None else [phone_jpeg(5)], coach_v="active", now=now,
                                 blobs=blobs, reencode=keep, reader=Reader(*texts), notify=notes)


def test_statement_checks_find_the_amount_or_the_number_or_neither():
    assert claims.statement_checks(["10/11 500.37 EGP in"], AMOUNT, TXN) == {"readable": True, "amountFound": True, "txnFound": False}
    assert claims.statement_checks(["ref 3012 3456 7890 123"], AMOUNT, TXN)["txnFound"] is True
    assert claims.statement_checks(["ref ٣٠١٢٣٤٥٦٧٨٩٠١٢٣"], AMOUNT, TXN)["txnFound"] is True
    assert claims.statement_checks(["balance 120.00"], AMOUNT, TXN) == {"readable": True, "amountFound": False, "txnFound": False}
    assert claims.statement_checks(["", None, 5], AMOUNT, TXN) == {"readable": False, "amountFound": False, "txnFound": False}
    assert claims.statement_checks(["500.37"], AMOUNT, None)["amountFound"] is True
    assert claims.statement_checks(["Credit 500,37 EGP"], AMOUNT, TXN)["amountFound"] is True


def test_a_statement_that_shows_the_amount_rejects_the_claim_and_changes_nothing_but_the_count(db, blobs, notes):
    proof_submitted(db)
    assert refusal(lambda: claim(db, blobs, notes, "Credit 500.37 EGP")) == (errors.PRECONDITION, errors.CLAIM_CONTRADICTED)
    assert payment_of(db)["status"] == "proof_submitted" and sub_of(db)["status"] == "active"
    assert blobs.objects == {} and notes.sent == []
    assert db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()["autoRejectedClaims"] == 1
    assert events(db) == [("proof_submitted", "proof_submitted", "system")]


def test_a_statement_that_shows_the_transaction_number_rejects_the_claim(db, blobs, notes):
    proof_submitted(db)
    assert refusal(lambda: claim(db, blobs, notes, f"Ref {TXN}")) == (errors.PRECONDITION, errors.CLAIM_CONTRADICTED)


def test_rejecting_a_claim_works_even_when_her_profile_document_is_missing(db, blobs, notes):
    proof_submitted(db)
    db.document(f"coachPaymentProfiles/{COACH}").delete()
    assert refusal(lambda: claim(db, blobs, notes, "Credit 500.37 EGP"))[1] == errors.CLAIM_CONTRADICTED
    assert db.document(f"coachPaymentProfiles/{COACH}").get().to_dict() == {"autoRejectedClaims": 1}


def test_a_readable_statement_without_the_payment_goes_to_staff_with_both_pictures(db, blobs, notes):
    proof_submitted(db)
    assert claim(db, blobs, notes, "Credit 120.00 EGP") == {"status": "in_review"}
    pay = payment_of(db)
    assert pay["status"] == "in_review" and pay["dispute"]["kind"] == "not_received" and pay["dispute"]["openedBy"] == "coach"
    assert pay["coachDecision"]["reasonCode"] == "not_seen"
    assert len(pay["coachDecision"]["statementPaths"]) == 1 and pay["coachDecision"]["statementPaths"][0] in blobs.objects
    assert sorted(events(db)) == [("coach_not_received", "in_review", "system"), ("proof_submitted", "coach_not_received", "coach")]   # both at one instant
    statement = db.document(f"payments/{PAY}/staff/statement").get().to_dict()
    assert statement["readable"] is True and statement["note"] == "I looked at my bank"
    assert "I looked at my bank" not in str(pay)
    assert (CLIENT, "instapayNotReceived") in notes.sent and (CLIENT, "instapayReviewStarted") in notes.sent


def test_an_unreadable_statement_goes_to_staff_marked_unreadable(db, blobs, notes):
    proof_submitted(db)
    assert claim(db, blobs, notes, "") == {"status": "in_review"}
    assert db.document(f"payments/{PAY}/staff/statement").get().to_dict()["readable"] is False


def test_the_claim_does_not_remove_the_clients_access_or_the_fee(db, blobs, notes):
    proof_submitted(db)
    claim(db, blobs, notes, "Credit 120.00 EGP")
    pay = payment_of(db)
    assert sub_of(db)["status"] == "active" and sub_of(db)["provisionalUntil"] is not None
    assert pay["access"]["state"] == "provisional" and pay["feeState"] == "disputed" and pay["feePiasters"] == 7500


@pytest.mark.parametrize("over,expected", [
    ({"searched": False}, (errors.INVALID, errors.EVIDENCE_REQUIRED)),
    ({"images": []}, (errors.INVALID, errors.EVIDENCE_REQUIRED)),
    ({"note": ""}, (errors.INVALID, errors.REASON_REQUIRED)),
])
def test_the_claim_needs_the_tick_the_picture_and_a_note(db, blobs, notes, over, expected):
    proof_submitted(db)
    images = over.pop("images", None)
    assert refusal(lambda: claim(db, blobs, notes, "x", images=images, **over)) == expected


def test_too_many_pictures_and_an_unknown_reason_are_a_bad_request(db, blobs, notes):
    proof_submitted(db)
    with pytest.raises(c_errors.CoachingError):
        claim(db, blobs, notes, "x", images=[phone_jpeg(i) for i in range(4)])
    with pytest.raises(c_errors.CoachingError):
        claim(db, blobs, notes, "x", reasonCode="because")
    assert payment_of(db)["status"] == "proof_submitted" and blobs.objects == {}


def test_a_double_tap_is_harmless(db, blobs, notes):
    proof_submitted(db)
    first = claim(db, blobs, notes, "Credit 120.00 EGP")
    assert claim(db, blobs, notes, "Credit 120.00 EGP") == first
    assert [e for e in events(db) if e[1] == "coach_not_received"] == [("proof_submitted", "coach_not_received", "coach")]


def test_only_this_payments_coach_and_only_from_proof_submitted(db, blobs, notes):
    proof_submitted(db)
    db.document(f"coachPrivate/{COACH2}").set({"suspended": False})
    assert refusal(lambda: claim(db, blobs, notes, "x", who=COACH2)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    for status in ("awaiting_payment", "different_amount", "resolved_paid"):
        db.document(f"payments/{PAY}").update({"status": status})
        assert refusal(lambda: claim(db, blobs, notes, "x")) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_a_suspended_coach_cannot_open_claims(db, blobs, notes):
    proof_submitted(db)
    db.document(f"coachPrivate/{COACH}").update({"suspended": True})
    assert refusal(lambda: claim(db, blobs, notes, "x"))[1] == c_errors.COACH_SUSPENDED


def test_a_coach_can_flag_an_auto_confirmed_payment_within_48_hours_only(db, blobs, notes):
    proof_submitted(db, status="confirmed", coachDecision={"autoConfirmed": True, "confirmedAt": NOW})
    assert claim(db, blobs, notes, "Credit 120.00 EGP", now=NOW + dt.timedelta(hours=47)) == {"status": "in_review"}
    assert events(db) == [("confirmed", "in_review", "coach")]
    proof_submitted(db, status="confirmed", coachDecision={"autoConfirmed": True, "confirmedAt": NOW})
    assert refusal(lambda: claim(db, blobs, notes, "x", now=NOW + dt.timedelta(hours=49))) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
    proof_submitted(db, status="confirmed", coachDecision={"autoConfirmed": False, "confirmedAt": NOW})
    assert refusal(lambda: claim(db, blobs, notes, "x", now=NOW + dt.timedelta(hours=1))) == (errors.PRECONDITION, errors.ILLEGAL_TRANSITION)


def test_a_failed_write_deletes_the_pictures(db, blobs, notes, monkeypatch):
    proof_submitted(db)

    def boom(*a, **k):
        raise RuntimeError("down")

    monkeypatch.setattr(engine, "move", boom)
    with pytest.raises(RuntimeError):
        claim(db, blobs, notes, "Credit 120.00 EGP")
    assert blobs.objects == {} and payment_of(db)["status"] == "proof_submitted"


def test_two_claims_never_share_a_file_name(db, blobs, notes):
    proof_submitted(db)
    names = {n for _ in range(2) for n in claims._names(PAY, "coach", 2)}
    assert len(names) == 4 and all(n.startswith(f"payment-proofs/{PAY}/coach-") for n in names)


def add(db, blobs, who, *texts, n=1, **over):
    return claims.add_evidence(db, who, {"paymentId": PAY, **over}, [phone_jpeg(i + 1) for i in range(n)], now=NOW1, blobs=blobs,
                                 reencode=keep, reader=Reader(*texts))


def test_client_adds_proof_while_in_review_and_the_coach_adds_a_bank_sms(db, blobs):
    proof_submitted(db, status="in_review", dispute={"kind": "proof_red", "openedBy": "system", "openedAt": NOW})
    assert add(db, blobs, CLIENT, "Transfer 500.37 EGP", note="my bank line") == {"added": 1}
    pay = payment_of(db)
    assert len(pay["proof"]["screenshotPaths"]) == 1 and pay["proof"]["screenshotPaths"][0].startswith(f"payment-proofs/{PAY}/client-")
    assert pay["proof"]["screenshotCount"] == 3 and pay["dispute"]["evidenceAt"] == NOW1
    staff_doc = db.document(f"payments/{PAY}/staff/evidence").get().to_dict()
    assert any(v["note"] == "my bank line" and v["amountFound"] for v in staff_doc.values())
    assert "my bank line" not in str(pay)
    assert add(db, blobs, COACH, "SMS", n=2) == {"added": 2}
    assert len(payment_of(db)["coachDecision"]["statementPaths"]) == 2


def test_add_evidence_limits_and_roles(db, blobs):
    proof_submitted(db, status="confirmed")
    assert refusal(lambda: add(db, blobs, CLIENT)) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert add(db, blobs, COACH) == {"added": 1}   # the coach may add her SMS to a confirmed payment
    proof_submitted(db, status="in_review", proof={"screenshotCount": 5, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []})
    assert refusal(lambda: add(db, blobs, CLIENT)) == (errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
    assert refusal(lambda: add(db, blobs, "stranger")) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    with pytest.raises(c_errors.CoachingError):
        claims.add_evidence(db, CLIENT, {"paymentId": PAY}, [], now=NOW1, blobs=blobs, reencode=keep, reader=Reader())
    assert not any("stranger" in n for n in blobs.objects)


def test_the_coach_adds_her_sms_while_her_decision_is_still_null(db, blobs):
    proof_submitted(db, coachDecision=None)
    assert add(db, blobs, COACH, "SMS") == {"added": 1}
    row = payment_of(db)
    assert len(row["coachDecision"]["statementPaths"]) == 1 and row["coachDecision"]["statementPaths"][0] in blobs.objects
    assert add(db, blobs, COACH, "SMS") == {"added": 1} and len(payment_of(db)["coachDecision"]["statementPaths"]) == 2


def test_a_client_adding_proof_keeps_the_rest_of_the_proof_and_the_dispute(db, blobs):
    proof_submitted(db, status="in_review", dispute={"kind": "proof_red", "openedBy": "system", "openedAt": NOW})
    add(db, blobs, CLIENT)
    row = payment_of(db)
    assert row["proof"]["txnNumber"] == TXN and row["proof"]["screenshotCount"] == 3
    assert row["dispute"]["kind"] == "proof_red" and row["dispute"]["evidenceAt"] == NOW1
