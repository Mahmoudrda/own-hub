"""The new callables and scheduled jobs, run through main.py with the fake Firestore."""

from __future__ import annotations

import inspect
from types import SimpleNamespace

import pytest
from firebase_functions import https_fn

import main
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, NOW, PAY, SUB, _txn, db, later, make_payment, payment_of, seed_world,
)
from tests.test_entrypoints import inner, raises, request
from tests.test_payments_staff import REASON, in_review

REVIEWER_TOKEN = {"verified": True, "womanReviewer": True}


@pytest.fixture
def world(db, monkeypatch):
    monkeypatch.setattr(main.store, "db", lambda: db)
    monkeypatch.setattr(main, "_coaching_now", lambda: NOW)
    monkeypatch.setattr(main, "_payments_notify", lambda uid, kind: None)
    return db


def test_a_lost_dispute_through_the_staff_callable_strikes_the_coach(world):
    in_review(world, "not_received")
    out = inner("staff_resolve_payment")(request({"paymentId": PAY, "outcome": "resolved_paid", "reason": REASON}, uid="rev-1", token=REVIEWER_TOKEN))
    assert out["status"] == "resolved_paid"
    assert world.document(f"paymentStrikes/{PAY}__coach").get().to_dict()["reason"] == "lost_dispute"
    assert world.document(f"paymentStanding/{COACH}").get().to_dict()["coachStrikes"] == 1


def test_the_owner_switches_payments_on_and_off_through_the_admin_callable(world):
    fn = inner("set_payments_enabled")
    assert fn(request({"enabled": True, "reason": "the real transfer passed"}, uid="admin-1", token={"admin": True})) == {"enabled": True}
    assert world.document("config/payments").get().to_dict()["enabled"] is True
    assert main._instapay_on() is True
    fn(request({"enabled": False, "reason": "pausing to look"}, uid="admin-1", token={"admin": True}))
    assert main._instapay_on() is False


def test_the_fee_callables_end_to_end(world):
    seed_world(world)
    make_payment(world, status="confirmed", feeState="owed", feePiasters=7500, feeOwedAt=later(days=-40))
    world.document(f"feeStatements/{COACH}__2026-10").set({"coachUid": COACH, "status": "open", "generatedAt": NOW, "totalDuePiasters": 7500,
                                                           "lines": [{"paymentId": PAY}], "dueAt": later(days=30)})
    coach_token = {"verified": True, "coachV": "active"}
    assert inner("record_fee_payment")(request({"statementId": f"{COACH}__2026-10", "txnNumber": "FEE1234567890"}, uid=COACH, token=coach_token)) == {"status": "paid_claimed"}
    listed = inner("list_fee_statements")(request({}, uid="fin-1", token={"finance": True}))
    assert [i["status"] for i in listed["items"]] == ["paid_claimed"]
    assert inner("confirm_fee_payment")(request({"statementId": f"{COACH}__2026-10"}, uid="fin-1", token={"finance": True})) == {"status": "paid"}
    assert payment_of(world)["feeState"] == "settled"


def test_the_flag_callables_end_to_end(world):
    seed_world(world)
    token = {"verified": True, "womanReviewer": True}
    body = {"coachUid": COACH, "action": "suspend", "reason": "two lost disputes in a month"}
    assert inner("staff_set_coach_payment_status")(request(body, uid="rev-1", token=token)) == {"status": "awaiting_second_approval"}
    assert inner("staff_set_coach_payment_status")(request(body, uid="adm-1", token={"admin": True})) == {"status": "suspended"}
    flags = inner("staff_list_payment_flags")(request({}, uid="rev-1", token=token))
    assert [f["uid"] for f in flags["flagged"]] == [COACH] and flags["flagged"][0]["coachSuspended"] is True   # stays listed so staff can lift
    assert flags["alerts"] == []                                   # a closed proposal is not an open alert
    assert inner("staff_set_coach_payment_status")(request(body, uid="rev-1", token=token)) == {"status": "suspended"}   # already suspended: nothing changes


def test_the_two_schedules_run_the_clock_and_never_ask_the_switch(world):
    seed_world(world)
    make_payment(world, "p-open", status="awaiting_payment", expiresAt=later(hours=-1), clientUid="c2")
    make_payment(world, "p-silent", status="proof_submitted", proofSubmittedAt=later(hours=-80), escalateAt=later(hours=-1), clientUid="c3")
    assert not world.document("config/payments").get().exists
    assert inspect.unwrap(main.expire_payments)(SimpleNamespace()) is None
    assert payment_of(world, "p-open")["status"] == "expired" and payment_of(world, "p-silent")["status"] == "in_review"
    make_payment(world, "p-late", status="proof_submitted", proofSubmittedAt=later(hours=-49), escalateAt=later(hours=23), clientUid="c4")
    assert inspect.unwrap(main.escalate_silent_payments)(SimpleNamespace()) is None
    assert payment_of(world, "p-late")["reminded48h"] is True


def test_a_failing_job_is_logged_and_never_raises(world, monkeypatch):
    from payments import timers

    def boom(*a, **k):
        raise RuntimeError("down")

    monkeypatch.setattr(timers, "hourly", boom)
    monkeypatch.setattr(timers, "half_hourly", boom)
    assert inspect.unwrap(main.expire_payments)(SimpleNamespace()) is None
    assert inspect.unwrap(main.escalate_silent_payments)(SimpleNamespace()) is None


def test_the_statement_job_and_the_daily_retention_job_run(world, monkeypatch):
    import datetime as dt

    from tests.fake_blobs import FakeBlobs

    seed_world(world)
    monkeypatch.setattr(main, "_coaching_now", lambda: dt.datetime(2026, 11, 1, 3, tzinfo=dt.timezone.utc))
    make_payment(world, status="confirmed", feeState="owed", feePiasters=7500, feeOwedAt=dt.datetime(2026, 10, 5, tzinfo=dt.timezone.utc))
    assert inspect.unwrap(main.generate_fee_statements)(SimpleNamespace()) is None
    assert world.document(f"feeStatements/{COACH}__2026-10").get().exists
    blobs = FakeBlobs()
    blobs.put("chat-media/c__k/k/lost.jpg", created=dt.datetime(2026, 10, 30, 12, tzinfo=dt.timezone.utc))
    monkeypatch.setattr(main, "_PersonalBlobs", lambda: blobs)
    assert inspect.unwrap(main.payments_retention)(SimpleNamespace()) is None
    assert blobs.deleted == ["chat-media/c__k/k/lost.jpg"]


def test_create_payment_through_main_fails_closed_without_a_switch_document(world):
    seed_world(world)
    token = {"verified": True}
    raises(lambda: inner("create_payment")(request({"subId": SUB, "idempotencyKey": "key-0001-abcd"}, uid=CLIENT, token=token)),
           https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    assert not list(world.collection("payments").stream()) and not list(world.collection("paymentAmountLocks").stream())
    err = None
    try:
        inner("create_payment")(request({"subId": SUB, "idempotencyKey": "key-0001-abcd"}, uid=CLIENT, token=token))
    except https_fn.HttpsError as caught:
        err = caught
    assert err is not None and err.message == "payments_off"
    world.document("config/payments").set({"enabled": True})
    assert inner("create_payment")(request({"subId": SUB, "idempotencyKey": "key-0002-abcd"}, uid=CLIENT, token=token))["status"] == "awaiting_payment"
