"""The kill switch (config/payments.enabled) and release gating (WO-10p, spec 10, 13.9)."""

from __future__ import annotations

import ast
import datetime as dt
import os

import pytest

from coaching import common, errors as c_errors
from payments import coach, create, errors, fees, model, refund, staff, switch, timers
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import (  # noqa: F401
    AMOUNT, CLIENT, COACH, NOW, PAY, REVIEWER, SUB, Notes, _txn, db, events, later, make_payment, notes, payment_of, refusal,
    seed_world,
)
from tests.test_payments_hardening import green_proof, sub_of
from tests.test_payments_proof import DETAILS, INSTAPAY_FIRST, Reader, blobs, send  # noqa: F401
from tests.test_payments_refund import PAID_AT
from tools import set_payments_switch

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = ast.parse(open(os.path.join(ROOT, "main.py"), encoding="utf-8").read())
RULES = open(os.path.join(os.path.dirname(ROOT), "firebase", "firestore.rules"), encoding="utf-8").read()


@pytest.mark.parametrize("doc,want", [(None, False), ({"enabled": False}, False), ({"enabled": "true"}, False), ({"enabled": 1}, False),
                                      ({"enabled": None}, False), ({}, False), ({"enabled": True}, True)])
def test_the_switch_is_on_only_when_exactly_true(db, doc, want):
    if doc is not None:
        db.document("config/payments").set(doc)
    assert model.enabled(db) is want


def test_set_enabled_writes_the_document_and_logs_without_a_uid(db):
    assert switch.set_enabled(db, "admin-1", {"enabled": True, "reason": "go live"}, now=NOW) == {"enabled": True}
    row = db.document("config/payments").get().to_dict()
    assert row["enabled"] is True and row["updatedAt"] == NOW and row["updatedBy"] == common.staff_ref("admin-1")
    assert "admin-1" not in str(row) and "go live" not in str(row) and set(row) == {"enabled", "updatedAt", "updatedBy"}   # every signed-in account can read this document
    logged = [r.to_dict() for r in db.collection("adminAccessLog").stream()]
    assert any("payments.switch.on" in str(r) for r in logged) and "admin-1" not in str(logged)
    assert switch.set_enabled(db, "admin-1", {"enabled": False, "reason": "pause it"}, now=NOW) == {"enabled": False}
    assert model.enabled(db) is False


@pytest.mark.parametrize("data", [{"enabled": "yes", "reason": "testing"}, {"enabled": True, "reason": "no"}, {"enabled": True},
                                  {"reason": "testing"}, {"enabled": 1, "reason": "testing"}])
def test_set_enabled_validates(db, data):
    with pytest.raises(c_errors.CoachingError):
        switch.set_enabled(db, "admin-1", data, now=NOW)
    assert not db.document("config/payments").get().exists


def test_the_owner_tool_flips_the_same_document(db):
    lines = []
    assert set_payments_switch.main(["off"], db=db, now=NOW, out=lines.append) == 0
    assert db.document("config/payments").get().to_dict()["enabled"] is False and lines == ["enabled: False"]
    set_payments_switch.main(["on"], db=db, now=NOW, out=lines.append)
    set_payments_switch.main(["status"], db=db, now=NOW, out=lines.append)
    assert lines[-2:] == ["enabled: True", "enabled: True"]
    assert set_payments_switch.main(["maybe"], db=db, out=lines.append) == 2 and set_payments_switch.main([], db=db, out=lines.append) == 2


def test_create_payment_refuses_when_off_and_makes_nothing(db):
    seed_world(db)
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=model.enabled(db))) == (
        errors.PRECONDITION, errors.PAYMENTS_OFF)
    assert not list(db.collection("payments").stream()) and not list(db.collection("paymentAmountLocks").stream())


def test_the_switch_is_read_in_the_few_places_that_start_something_new_and_nowhere_else():
    users = {}
    for node in ast.walk(MAIN):
        if isinstance(node, ast.FunctionDef):
            for call in ast.walk(node):
                if isinstance(call, ast.Call) and isinstance(call.func, ast.Name) and call.func.id == "_instapay_on":
                    users[node.name] = users.get(node.name, 0) + 1
    assert set(users) == {"create_payment", "request_coaching", "respond_coaching_request", "coaching_sweeper"}
    for name in os.listdir(os.path.join(ROOT, "payments")):
        if name.endswith(".py") and name not in ("model.py", "switch.py"):   # the reader and the writer of the switch
            source = open(os.path.join(ROOT, "payments", name), encoding="utf-8").read()
            assert "model.enabled" not in source and "config/payments" not in source and '"payments").get' not in source, name


def test_the_rules_for_a_payment_do_not_mention_the_switch():
    block = RULES[RULES.index("match /payments/{paymentId}"):RULES.index("match /paymentTxnNumbers")]
    assert "config/payments" not in block and "enabled" not in block


def test_turning_it_off_mid_payment_leaves_everything_open_readable_and_resolvable(db, blobs, notes):
    green_proof(db, blobs, notes)                                        # a paid-in-flight payment, made while the switch was on
    db.document("config/payments").set({"enabled": False})
    assert payment_of(db)["status"] == "proof_submitted"
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW + dt.timedelta(hours=1), notify=notes)
    assert payment_of(db)["status"] == "confirmed"
    t = NOW + dt.timedelta(days=2)
    refund.request(db, CLIENT, {"paymentId": PAY}, now=t, notify=notes)
    refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "400000000001", "amountPiasters": AMOUNT, "kind": "refund", "paidAt": t.isoformat()},
                  coach_v="active", now=t, notify=notes)
    assert payment_of(db)["status"] == "refunded"
    make_payment(db, "pay-r", status="in_review", clientUid="client-r", dispute={"kind": "proof_red", "openedBy": "system", "openedAt": NOW})
    assert staff.resolve(db, REVIEWER, {"paymentId": "pay-r", "outcome": "resolved_unpaid", "reason": "the line does not show it"}, now=t, notify=notes)["status"] == "resolved_unpaid"
    make_payment(db, "pay-s", status="proof_submitted", clientUid="client-s", proofSubmittedAt=NOW, escalateAt=NOW + dt.timedelta(hours=72))
    timers.hourly(db, NOW + dt.timedelta(days=5), notes)
    timers.half_hourly(db, NOW + dt.timedelta(days=5), notes)
    fees.generate(db, now=dt.datetime(2026, 12, 1, 6, tzinfo=dt.timezone.utc), notify=notes)
    assert payment_of(db, "pay-s")["status"] == "in_review"
    assert model.enabled(db) is False


def test_staff_decisions_and_the_clock_continue_while_off(db, notes):
    make_payment(db, status="in_review", dispute={"kind": "proof_red", "openedBy": "system", "openedAt": NOW})
    seed_world(db)
    db.document("config/payments").set({"enabled": False})
    assert staff.resolve(db, REVIEWER, {"paymentId": PAY, "outcome": "resolved_paid", "reason": "the line shows it"}, now=NOW, notify=notes)["status"] == "resolved_paid"
    assert timers.sweep(db, NOW, notes) == {"escalated": 0, "expired": 0, "cancelled": 0}


def test_a_switch_that_cannot_be_read_stops_a_new_payment_and_nothing_else(db, monkeypatch):
    seed_world(db)

    def broken(_):
        raise RuntimeError("down")

    monkeypatch.setattr(model, "enabled", broken)
    with pytest.raises(RuntimeError):
        model.enabled(db)
    assert refusal(lambda: create.create(db, CLIENT, {"subId": SUB, "idempotencyKey": "key-0001-abcd"}, now=NOW, on=False)) == (
        errors.PRECONDITION, errors.PAYMENTS_OFF)
    make_payment(db, status="awaiting_payment")
    assert timers.sweep(db, NOW, Notes()) == {"escalated": 0, "expired": 0, "cancelled": 0}
