"""The monthly fee statement, the coach's 'I paid', the owner's confirmation, late fees (WO-10c, spec 4.13)."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import common, errors as c_errors
from payments import errors, fees, timers
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, COACH2, NOW, PAY, REVIEWER, SUB, Notes, _txn, db, later, make_payment, notes, payment_of, refusal, seed_world,
)

CAIRO = common.CAIRO
UTC = dt.timezone.utc
FIRST_NOV = dt.datetime(2026, 11, 1, 6, 0, tzinfo=CAIRO)
FINANCE = "finance-uid-1"
ID = f"{COACH}__2026-10"


def october(day, hour=12):
    return dt.datetime(2026, 10, day, hour, tzinfo=UTC)


def fee_payment(db, pid, state="owed", fee=7500, when=None, coach=COACH, **over):
    make_payment(db, pid, status="confirmed", feeState=state, feePiasters=fee, feeOwedAt=when or october(5), coachUid=coach,
                 clientUid=f"client-{pid}", **over)


def test_build_lines_counts_owed_lists_disputed_and_ignores_waived():
    out = fees.build_lines([("a", {"feeState": "owed", "feePiasters": 7500, "feeOwedAt": october(3)}),
                            ("b", {"feeState": "disputed", "feePiasters": 3000, "feeOwedAt": october(2)}),
                            ("c", {"feeState": "settled", "feePiasters": 1000, "feeOwedAt": october(4)}),
                            ("d", {"feeState": "waived", "feePiasters": 500, "feeOwedAt": october(1)})])
    assert (out["totalDuePiasters"], out["disputedPiasters"], out["settledPiasters"], out["waivedPiasters"]) == (7500, 3000, 1000, 500)
    assert [line["paymentId"] for line in out["lines"]] == ["d", "b", "a", "c"]


def test_month_bounds_follow_cairo_time():
    start, end = fees.month_bounds(2026, 10)
    assert start == dt.datetime(2026, 10, 1, tzinfo=CAIRO).astimezone(UTC) and end == dt.datetime(2026, 11, 1, tzinfo=CAIRO).astimezone(UTC)
    assert start == dt.datetime(2026, 9, 30, 21, tzinfo=UTC)      # Cairo is UTC+3 until the clocks go back on 29 October 2026
    assert end == dt.datetime(2026, 10, 31, 22, tzinfo=UTC)       # and UTC+2 on 1 November
    assert fees.month_bounds(2026, 12)[1] == dt.datetime(2027, 1, 1, tzinfo=CAIRO).astimezone(UTC)
    assert fees.previous_month(dt.datetime(2026, 11, 1, 5, tzinfo=UTC)) == (2026, 10)
    assert fees.previous_month(dt.datetime(2027, 1, 1, 5, tzinfo=UTC)) == (2026, 12)


def test_the_first_of_the_month_makes_one_statement_per_coach_with_fees(db, notes):
    seed_world(db)
    db.document("coachingConfig/receivingAccounts").set({"instapay": {"address": "ownhub@instapay", "holderName": "Own Hub"}})
    fee_payment(db, "p1", when=october(3))
    fee_payment(db, "p2", state="disputed", fee=3000, when=october(10))
    fee_payment(db, "p3", fee=1500, when=october(31, 20))
    fee_payment(db, "p4", when=dt.datetime(2026, 9, 29, tzinfo=UTC))                    # September: not this statement
    fee_payment(db, "p5", when=october(6), coach=COACH2)
    assert fees.generate(db, now=FIRST_NOV, notify=notes) == 2
    row = db.document(f"feeStatements/{ID}").get().to_dict()
    assert (row["totalDuePiasters"], row["disputedPiasters"], row["status"]) == (9000, 3000, "open")
    assert row["dueAt"] == row["generatedAt"] + dt.timedelta(days=3) and row["holdAt"] == row["generatedAt"] + dt.timedelta(days=7) and row["payTo"] == {"address": "ownhub@instapay", "holderName": "Own Hub"}
    assert [line["paymentId"] for line in row["lines"]] == ["p1", "p2", "p3"]
    assert sorted(notes.sent) == sorted([(COACH, "instapayStatementReady"), (COACH2, "instapayStatementReady")])
    assert sorted(notes.refs) == sorted([(COACH, "instapayStatementReady", "2026-10"), (COACH2, "instapayStatementReady", "2026-10")])
    assert fees.generate(db, now=FIRST_NOV, notify=notes) == 0 and len(notes.sent) == 2


def test_a_payment_in_the_last_cairo_hours_of_october_belongs_to_october_and_one_after_midnight_to_november(db, notes):
    seed_world(db)
    fee_payment(db, "late", when=dt.datetime(2026, 10, 31, 21, 30, tzinfo=UTC))        # 23:30 in Cairo
    fee_payment(db, "after", when=dt.datetime(2026, 10, 31, 22, 30, tzinfo=UTC), coach=COACH2)    # 00:30 on 1 November in Cairo
    fees.generate(db, now=FIRST_NOV, notify=notes)
    assert db.document(f"feeStatements/{ID}").get().exists and not db.document(f"feeStatements/{COACH2}__2026-10").get().exists


def test_the_coach_marks_the_fee_paid_once_and_the_number_is_unique(db, notes):
    seed_world(db)
    fee_payment(db, "p1")
    fee_payment(db, "p5", coach=COACH2, when=october(6))
    fees.generate(db, now=FIRST_NOV, notify=notes)
    ask = lambda who, sid, txn: fees.record_payment(db, who, {"statementId": sid, "txnNumber": txn}, coach_v="active", now=FIRST_NOV)   # noqa: E731
    assert ask(COACH, ID, "FEE1234567890") == {"status": "paid_claimed"} and ask(COACH, ID, "FEE1234567890") == {"status": "paid_claimed"}
    assert db.document(f"feeStatements/{ID}").get().to_dict()["claimedTxn"] == "FEE1234567890"
    assert refusal(lambda: ask(COACH2, f"{COACH2}__2026-10", "FEE1234567890")) == (errors.PRECONDITION, errors.TXN_REUSED)
    assert refusal(lambda: ask(COACH2, ID, "FEE9999999999")) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    with pytest.raises(c_errors.CoachingError):
        ask(COACH2, f"{COACH2}__2026-10", "12")
    assert refusal(lambda: fees.record_payment(db, COACH, {"statementId": ID, "txnNumber": "FEE1234567890"}, coach_v=None, now=FIRST_NOV)) == (
        c_errors.PERMISSION, c_errors.NOT_A_COACH)


def test_the_overview_lists_statements_newest_first_with_a_status_filter_and_no_lines(db, notes):
    for i, status in enumerate(("open", "paid", "paid_claimed")):
        db.document(f"feeStatements/s{i}").set({"coachUid": COACH, "status": status, "generatedAt": FIRST_NOV + dt.timedelta(days=i), "lines": [{"x": 1}], "totalDuePiasters": 100})
    out = fees.list_statements(db, FINANCE, {}, now=NOW)
    assert [i["statementId"] for i in out["items"]] == ["s2", "s1", "s0"] and all("lines" not in i for i in out["items"])
    assert [i["statementId"] for i in fees.list_statements(db, FINANCE, {"status": "paid"}, now=NOW)["items"]] == ["s1"]
    with pytest.raises(c_errors.CoachingError):
        fees.list_statements(db, FINANCE, {"status": "nope"}, now=NOW)
    assert any("fees.list" in str(r.to_dict()) for r in db.collection("adminAccessLog").stream())
    for i in range(30):
        db.document(f"feeStatements/x{i:02d}").set({"coachUid": COACH, "status": "open", "generatedAt": FIRST_NOV + dt.timedelta(days=10 + i)})
    page = fees.list_statements(db, FINANCE, {}, now=NOW)
    assert len(page["items"]) == 25 and page["next"]
    assert len(fees.list_statements(db, FINANCE, {"after": page["next"]}, now=NOW)["items"]) == 8


def test_the_owner_confirms_and_the_owed_lines_settle(db, notes):
    seed_world(db)
    fee_payment(db, "p1")
    fee_payment(db, "p2", state="disputed", fee=3000)
    fees.generate(db, now=FIRST_NOV, notify=notes)
    assert fees.confirm_payment(db, FINANCE, {"statementId": ID}, now=FIRST_NOV + dt.timedelta(days=3)) == {"status": "paid"}
    assert payment_of(db, "p1")["feeState"] == "settled" and payment_of(db, "p2")["feeState"] == "disputed"
    row = db.document(f"feeStatements/{ID}").get().to_dict()
    assert row["status"] == "paid" and row["confirmedBy"] == common.staff_ref(FINANCE) and FINANCE not in str(row)
    assert fees.confirm_payment(db, FINANCE, {"statementId": ID}, now=FIRST_NOV) == {"status": "paid"}
    assert refusal(lambda: fees.confirm_payment(db, FINANCE, {"statementId": "nope"}, now=FIRST_NOV)) == (errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)


def test_7_days_unpaid_puts_the_account_on_hold_but_existing_clients_stay(db, notes):
    seed_world(db)
    db.document(f"subscriptions/{SUB}").update({"status": "active"})
    fee_payment(db, "p1")
    fees.generate(db, now=FIRST_NOV, notify=notes)
    notes.sent.clear()
    notes.refs.clear()
    assert timers.hourly(db, FIRST_NOV + dt.timedelta(days=6), notes)["feesOverdue"] == 0
    assert timers.hourly(db, FIRST_NOV + dt.timedelta(days=8), notes)["feesOverdue"] == 1
    coach_row = db.document(f"coaches/{COACH}").get().to_dict()
    private = db.document(f"coachPrivate/{COACH}").get().to_dict()
    assert coach_row["acceptingClients"] is False and private["acceptingBeforeOverdue"] is True
    assert private["hold"] == {"reason": "fee", "since": FIRST_NOV + dt.timedelta(days=8)}
    assert "hold" not in coach_row and "acceptingBeforeOverdue" not in coach_row     # members can read this document
    assert db.document(f"paymentStanding/{COACH}").get().to_dict()["feeOverdue"] is True
    assert (COACH, "instapayFeeOverdue", "2026-10") in notes.refs
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["status"] == "active"
    notes.sent.clear()
    timers.hourly(db, FIRST_NOV + dt.timedelta(days=9), notes)
    assert notes.sent == []


def test_paying_restores_what_she_had_chosen(db, notes):
    seed_world(db)
    fee_payment(db, "p1")
    fees.generate(db, now=FIRST_NOV, notify=notes)
    timers.hourly(db, FIRST_NOV + dt.timedelta(days=8), notes)
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is False
    fees.confirm_payment(db, FINANCE, {"statementId": ID}, now=FIRST_NOV + dt.timedelta(days=10))
    row = db.document(f"coaches/{COACH}").get().to_dict()
    assert row["acceptingClients"] is True and db.document(f"coachPrivate/{COACH}").get().to_dict()["acceptingBeforeOverdue"] is None
    assert db.document(f"paymentStanding/{COACH}").get().to_dict()["feeOverdue"] is False


def test_a_coach_who_had_stopped_taking_clients_herself_stays_stopped_after_paying(db, notes):
    seed_world(db)
    db.document(f"coaches/{COACH}").update({"acceptingClients": False})
    fee_payment(db, "p1")
    fees.generate(db, now=FIRST_NOV, notify=notes)
    timers.hourly(db, FIRST_NOV + dt.timedelta(days=8), notes)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["acceptingBeforeOverdue"] is False
    fees.confirm_payment(db, FINANCE, {"statementId": ID}, now=FIRST_NOV + dt.timedelta(days=10))
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is False


def test_paying_one_late_statement_does_not_free_a_coach_with_another_late_one(db, notes):
    seed_world(db)
    fee_payment(db, "p1")
    fee_payment(db, "p2", when=dt.datetime(2026, 9, 5, tzinfo=UTC))
    fees.generate(db, now=FIRST_NOV, notify=notes)
    fees.generate(db, now=dt.datetime(2026, 10, 1, 6, tzinfo=CAIRO), notify=notes)
    late = FIRST_NOV + dt.timedelta(days=45)
    timers.hourly(db, late, notes)
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is False
    fees.confirm_payment(db, FINANCE, {"statementId": ID}, now=late)
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is False
    assert db.document(f"paymentStanding/{COACH}").get().to_dict()["feeOverdue"] is True
