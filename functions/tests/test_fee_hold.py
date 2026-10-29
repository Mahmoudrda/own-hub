"""Owner decisions of 28 Oct 2026: the rate follows the code the client came with,
one bill per payment (due in 3 days), the account goes on hold at 7 days and
comes back when staff confirm the fee."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import common, errors as c_errors, invites, packages, plans, profiles, push as coaching_push, sessions, subscriptions
from payments import amounts, coach, fees, notices, refund, timers
from tests import test_coaching_subscriptions as subs
from tests.coaching_helpers import Pushes
from tests.payments_helpers import (  # noqa: F401
    CLIENT, COACH, COACH2, NOW, PAY, SUB, Notes, _txn, db, make_payment, notes, payment_of, refusal, seed_world,
)

UTC = dt.timezone.utc
FINANCE = "finance-uid-1"
BILL = f"{COACH}__{PAY}"
CODE = "ABCD2345"


@pytest.fixture
def pushes():
    return Pushes()


def code_for(db, coach_uid=COACH, expires=None):
    db.document(f"coachInvites/{CODE}").set({"coachUid": coach_uid, "createdAt": subs.NOW, "expiresAt": expires or subs.later(days=30)})


def ask_with(db, pushes, **over):
    return subs.ask(db, pushes, **over)


def relationship(db):
    return db.document(f"relationships/{subs.COACH}__{subs.CLIENT}").get().to_dict()


# --------------------------------------------------------------------- source

def free_ask(db, pushes, **over):
    data = {"coachUid": subs.COACH, "packageId": subs.PACKAGE, "intake": subs.intake(), "locale": "en", "consent": subs.consent(), **over}
    return subscriptions.request(db, subs.CLIENT, data, live=True, verified=True, now=subs.NOW, notify=pushes)


def test_the_relationship_source_is_written_when_the_first_coaching_begins(db, pushes):
    subs.seed(db)
    code_for(db, subs.COACH)
    out = ask_with(db, pushes, inviteCode="abcd-2345")
    assert db.document(f"subscriptions/{out['subId']}").get().to_dict()["source"] == "invite"
    assert "source" not in relationship(db)           # a request that is never accepted fixes nothing


def test_a_free_coaching_with_the_coaches_own_code_records_invite_once(db, pushes):
    subs.seed(db, accounts=False)
    code_for(db, subs.COACH)
    free_ask(db, pushes, inviteCode=CODE)
    assert relationship(db)["source"] == "invite"


@pytest.mark.parametrize("make", ["other", "expired", "none", "junk"])
def test_any_other_code_or_none_is_the_app_source(db, pushes, make):
    subs.seed(db, accounts=False)
    db.document("coaches/other-coach").set({"displayName": "Other"})
    if make == "other":
        code_for(db, "other-coach")
    elif make == "expired":
        code_for(db, subs.COACH, expires=subs.later(days=-1))
    extra = {} if make == "none" else {"inviteCode": CODE if make != "junk" else "x"}
    free_ask(db, pushes, **extra)
    assert relationship(db)["source"] == "app"


def test_an_existing_relationship_keeps_its_source(db, pushes):
    subs.seed(db, accounts=False)
    db.document(f"relationships/{subs.COACH}__{subs.CLIENT}").set(
        {"coachUid": subs.COACH, "clientUid": subs.CLIENT, "status": "none", "chatOpen": False, "source": "app"})
    code_for(db, subs.COACH)
    free_ask(db, pushes, inviteCode=CODE)
    assert relationship(db)["source"] == "app"


def test_accepting_a_code_still_names_the_coach_and_writes_nothing(db):
    subs.seed(db)
    code_for(db, subs.COACH)
    assert invites.coach_for_code(db, subs.CLIENT, CODE, subs.NOW) == subs.COACH
    assert invites.accept(db, subs.CLIENT, {"code": CODE}, verified=True, live=True, now=subs.NOW, timestamp=None)["coachUid"] == subs.COACH


# ----------------------------------------------------------------------- bills

def confirmed_payment(db, notes, *, pay_id=PAY, source=None, at=NOW):
    seed_world(db)
    if source:
        db.document(f"relationships/{COACH}__{CLIENT}").update({"source": source})
    make_payment(db, pay_id, status="proof_submitted", proofSubmittedAt=at)
    coach.confirm(db, COACH, {"paymentId": pay_id}, coach_v="active", now=at, notify=notes)


def test_confirming_a_payment_makes_one_bill_due_in_3_days_and_on_hold_in_7(db, notes):
    db.document("coachingConfig/receivingAccounts").set({"instapay": {"address": "ownhub@instapay", "holderName": "Own Hub"}})
    confirmed_payment(db, notes, source="invite")
    pay = payment_of(db)
    assert pay["feeBps"] == 750 and pay["feeStatementId"] == BILL
    bill = db.document(f"feeStatements/{BILL}").get().to_dict()
    assert bill["dueAt"] == NOW + dt.timedelta(days=3) and bill["holdAt"] == NOW + dt.timedelta(days=7)
    assert bill["status"] == "open" and bill["totalDuePiasters"] == pay["feePiasters"] == 3750
    assert [line["paymentId"] for line in bill["lines"]] == [PAY] and bill["payTo"]["address"] == "ownhub@instapay"


def test_the_monthly_job_bills_only_lines_without_a_bill(db, notes):
    confirmed_payment(db, notes, at=dt.datetime(2026, 10, 12, 9, tzinfo=UTC))
    make_payment(db, "old", status="confirmed", feeState="owed", feePiasters=500, feeOwedAt=dt.datetime(2026, 10, 3, tzinfo=UTC), clientUid="c-old")
    assert fees.generate(db, now=dt.datetime(2026, 11, 1, 6, tzinfo=common.CAIRO), notify=notes) == 1
    monthly = db.document(f"feeStatements/{COACH}__2026-10").get().to_dict()
    assert [line["paymentId"] for line in monthly["lines"]] == ["old"]
    assert payment_of(db, "old")["feeStatementId"] == f"{COACH}__2026-10"
    assert fees.generate(db, now=dt.datetime(2026, 11, 1, 6, tzinfo=common.CAIRO), notify=notes) == 0


def test_a_zero_fee_makes_no_bill(db):
    seed_world(db)
    make_payment(db, PAY, status="proof_submitted", proofSubmittedAt=NOW, baseAmountPiasters=5)
    coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=NOW, notify=Notes())
    assert not db.document(f"feeStatements/{BILL}").get().exists


# ------------------------------------------------------------------- reminders

def test_reminders_go_once_each_and_name_no_amount(db, notes):
    confirmed_payment(db, notes)
    notes.sent.clear()
    notes.refs.clear()
    assert fees.remind(db, now=NOW + dt.timedelta(hours=1), notify=notes) == {"ready": 1, "dueSoon": 0, "dueToday": 0}
    assert fees.remind(db, now=NOW + dt.timedelta(hours=2), notify=notes)["ready"] == 0
    assert fees.remind(db, now=NOW + dt.timedelta(hours=49), notify=notes) == {"ready": 0, "dueSoon": 1, "dueToday": 0}
    assert fees.remind(db, now=NOW + dt.timedelta(hours=50), notify=notes)["dueSoon"] == 0
    assert fees.remind(db, now=NOW + dt.timedelta(days=3, hours=1), notify=notes) == {"ready": 0, "dueSoon": 0, "dueToday": 1}
    assert fees.remind(db, now=NOW + dt.timedelta(days=3, hours=2), notify=notes) == {"ready": 0, "dueSoon": 0, "dueToday": 0}
    assert [k for _, k in notes.sent] == ["instapayStatementReady", "instapayFeeDueSoon", "instapayFeeDueToday"]
    for kind in ("instapayFeeDueSoon", "instapayFeeDueToday", "instapayAccountActive"):
        assert kind in notices.KINDS and all(not any(ch.isdigit() for ch in text) for lang in notices.TEXT[kind].values() for text in lang)
    assert "coachBack" in coaching_push.TEXT


def test_a_paid_claim_gets_no_reminder_and_a_refunded_fee_closes_the_bill(db, notes):
    confirmed_payment(db, notes)
    notes.sent.clear()
    fees.record_payment(db, COACH, {"statementId": BILL, "txnNumber": "FEE1234567890"}, coach_v="active", now=NOW)
    assert fees.remind(db, now=NOW + dt.timedelta(days=4), notify=notes) == {"ready": 0, "dueSoon": 0, "dueToday": 0}
    db.document(f"feeStatements/{BILL}").update({"status": "open"})
    db.document(f"payments/{PAY}").update({"feeState": "waived"})
    assert fees.remind(db, now=NOW + dt.timedelta(days=4), notify=notes)["dueToday"] == 0
    assert fees.mark_overdue(db, now=NOW + dt.timedelta(days=9), notify=notes) == 0
    assert db.document(f"feeStatements/{BILL}").get().to_dict()["status"] == "paid"


# ------------------------------------------------------------------------ hold

def on_hold(db, notes):
    confirmed_payment(db, notes)
    db.document(f"subscriptions/{SUB}").update({"status": "active", "startsAt": NOW, "endsAt": NOW + dt.timedelta(days=28), "clientUid": CLIENT})
    db.document(f"relationships/{COACH}__{CLIENT}").update({"status": "active"})
    assert fees.mark_overdue(db, now=NOW + dt.timedelta(days=6), notify=notes) == 0
    assert fees.mark_overdue(db, now=NOW + dt.timedelta(days=7), notify=notes) == 1


def test_unpaid_for_7_days_puts_her_on_hold_and_marks_her_clients(db, notes):
    on_hold(db, notes)
    row = db.document(f"coaches/{COACH}").get().to_dict()
    private = db.document(f"coachPrivate/{COACH}").get().to_dict()
    assert private["hold"] == {"reason": "fee", "since": NOW + dt.timedelta(days=7)} and private["acceptingBeforeOverdue"] is True
    assert row["acceptingClients"] is False and row["published"] is True and "hold" not in row   # the public page says nothing about why
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["coachAway"] is True
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["status"] == "active"


def test_every_coach_write_is_refused_while_on_hold_but_fee_recording_works(db, notes):
    on_hold(db, notes)
    for call in (
        lambda: common.require_active_coach(db, COACH, "active"),
        lambda: subscriptions.respond(db, COACH, {"subId": SUB, "decision": "accept"}, live=True, coach_v="active", now=NOW, notify=notes),
        lambda: packages.save(db, COACH, {}, coach_v="active", live=True, now=NOW),
    ):
        with pytest.raises(c_errors.CoachingError) as caught:
            call()
        assert caught.value.reason == c_errors.COACH_ON_HOLD
    assert fees.record_payment(db, COACH, {"statementId": BILL, "txnNumber": "FEE1234567890"}, coach_v="active", now=NOW) == {"status": "paid_claimed"}


def test_on_hold_the_other_coach_writes_are_refused(db, notes):
    on_hold(db, notes)
    for call in (
        lambda: plans.publish(db, COACH, {}, live=True, coach_v="active", now=NOW, notify=notes),
        lambda: sessions.schedule(db, COACH, {"subId": SUB}, live=True, coach_v="active", now=NOW, notify=notes),
        lambda: profiles.update(db, COACH, {"headline": "x"}, live=True, coach_v="active", blobs=None, reencode=None, now=NOW),
    ):
        with pytest.raises(c_errors.CoachingError) as caught:
            call()
        assert caught.value.reason == c_errors.COACH_ON_HOLD


def test_on_hold_she_can_still_answer_her_clients_payments_and_refunds(db, notes):
    on_hold(db, notes)
    make_payment(db, "pay-d", status="proof_submitted", proofSubmittedAt=NOW, clientUid="client-d")
    assert amounts.mark(db, COACH, {"paymentId": "pay-d", "receivedPiasters": 40000, "acceptLower": False},
                        coach_v="active", now=NOW, notify=notes) == {"status": "different_amount"}
    make_payment(db, "pay-c", status="proof_submitted", proofSubmittedAt=NOW, clientUid="client-c")
    coach.confirm(db, COACH, {"paymentId": "pay-c"}, coach_v="active", now=NOW, notify=notes)
    assert payment_of(db, "pay-c")["status"] == "confirmed"
    make_payment(db, "pay-r", status="refund_requested", clientUid="client-r",
                 refund={"requestedAt": NOW, "coachDueAt": NOW + dt.timedelta(days=3)})
    assert refund.deny(db, COACH, {"paymentId": "pay-r", "reasonCode": "sessions_delivered"},
                       coach_v="active", now=NOW, notify=notes) == {"status": "refund_denied"}


def test_a_claimed_but_unconfirmed_bill_still_puts_her_on_hold_and_staff_can_reject_the_claim(db, notes):
    confirmed_payment(db, notes)
    fees.record_payment(db, COACH, {"statementId": BILL, "txnNumber": "FEE1234567890"}, coach_v="active", now=NOW)
    assert fees.mark_overdue(db, now=NOW + dt.timedelta(days=7), notify=notes) == 1
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]
    notes.sent.clear()
    with pytest.raises(c_errors.CoachingError):
        fees.reject_claim(db, FINANCE, {"statementId": BILL, "reason": "short"}, now=NOW)
    assert fees.reject_claim(db, FINANCE, {"statementId": BILL, "reason": "Nothing arrived on the 3rd"}, now=NOW + dt.timedelta(days=8), notify=notes) == {"status": "open"}
    row = db.document(f"feeStatements/{BILL}").get().to_dict()
    assert row["status"] == "open" and row["claimedTxn"] is None and row["claimRejected"]["reason"] == "Nothing arrived on the 3rd"
    assert row["claimRejected"]["by"] == common.staff_ref(FINANCE) and FINANCE not in str(row)
    assert notes.sent == [(COACH, "instapayFeeClaimRejected")] and "instapayFeeClaimRejected" in notices.STATEMENT_KINDS
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]          # only a confirmation ends it
    with pytest.raises(c_errors.CoachingError):                              # nothing to reject now
        fees.reject_claim(db, FINANCE, {"statementId": BILL, "reason": "Nothing arrived on the 3rd"}, now=NOW)
    assert any("fees.reject" in str(r.to_dict()) for r in db.collection("adminAccessLog").stream())


def test_staff_confirming_ends_the_hold_and_moves_every_end_date(db, notes):
    on_hold(db, notes)
    notes.sent.clear()
    clients = []
    release = NOW + dt.timedelta(days=10)
    out = fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=release, notify=notes, notify_client=lambda u, k: clients.append((u, k)))
    assert out == {"status": "paid"}
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is True
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["coachAway"] is False
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["endsAt"] == NOW + dt.timedelta(days=28) + dt.timedelta(days=3)
    assert notes.sent == [(COACH, "instapayAccountActive")] and clients == [(CLIENT, "coachBack")]
    common.require_active_coach(db, COACH, "active")


def test_two_overdue_bills_keep_her_on_hold_until_both_are_confirmed(db, notes):
    on_hold(db, notes)
    make_payment(db, "pay-2", status="confirmed", feeState="owed", feePiasters=900, feeOwedAt=NOW, clientUid="client-2")
    db.document("feeStatements/second").set({"coachUid": COACH, "status": "open", "year": 2026, "month": 11, "lines": [], "dueAt": NOW,
                                             "holdAt": NOW + dt.timedelta(days=7), "overdueNotified": True})
    later_ = NOW + dt.timedelta(days=10)
    fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=later_, notify=notes)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["coachAway"] is True
    fees.confirm_payment(db, FINANCE, {"statementId": "second"}, now=later_ + dt.timedelta(days=1), notify=notes)
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is True
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["endsAt"] == NOW + dt.timedelta(days=28) + dt.timedelta(days=4)


def test_hourly_runs_the_reminders_and_the_hold(db, notes):
    confirmed_payment(db, notes)
    counts = timers.hourly(db, NOW + dt.timedelta(days=7, hours=1), notes)
    assert counts["feesOverdue"] == 1 and counts["feeReminders"]["dueToday"] == 1


def test_the_overview_lists_accounts_on_hold_first(db):
    for sid, held, day in (("a", False, 3), ("b", True, 1), ("c", False, 2)):
        db.document(f"feeStatements/{sid}").set({"coachUid": COACH, "status": "open", "overdueNotified": held,
                                                 "generatedAt": NOW + dt.timedelta(days=day)})
    out = fees.list_statements(db, FINANCE, {}, now=NOW)
    assert [i["statementId"] for i in out["items"]] == ["b", "a", "c"]


def test_a_push_about_one_bill_carries_the_payment_id_not_a_uid(db, notes):
    confirmed_payment(db, notes)
    notes.refs.clear()
    fees.remind(db, now=NOW + dt.timedelta(hours=49), notify=notes)
    assert (COACH, "instapayFeeDueSoon", PAY) in notes.refs
    assert notices.data_for("instapayFeeDueSoon", PAY) == {"kind": "instapayFeeDueSoon", "billId": PAY}
    assert notices.data_for("instapayFeeDueSoon", "2026-10") == {"kind": "instapayFeeDueSoon", "statementMonth": "2026-10"}


# ---------------------------------------------- the bill follows the payment

def test_a_lower_accepted_amount_lowers_the_bill(db, notes):
    seed_world(db)
    make_payment(db, PAY, status="proof_submitted", proofSubmittedAt=NOW)
    amounts.mark(db, COACH, {"paymentId": PAY, "receivedPiasters": 40000, "acceptLower": True}, coach_v="active", now=NOW, notify=notes)
    amounts.respond(db, CLIENT, {"paymentId": PAY, "decision": "agree"}, now=NOW, notify=notes)
    pay = payment_of(db)
    bill = db.document(f"feeStatements/{pay['feeStatementId']}").get().to_dict()
    assert pay["feePiasters"] < 7500 and bill["totalDuePiasters"] == pay["feePiasters"] == bill["lines"][0]["feePiasters"]


def test_a_full_refund_closes_the_bill_as_waived(db, notes):
    confirmed_payment(db, notes)
    db.document(f"payments/{PAY}").update({"status": "refund_requested", "refund": {"requestedAt": NOW, "coachDueAt": NOW + dt.timedelta(days=3)}})
    refund.record(db, COACH, {"paymentId": PAY, "txnNumber": "123456789012", "kind": "refund", "amountPiasters": payment_of(db)["amountPiasters"],
                              "paidAt": NOW.isoformat()}, coach_v="active", now=NOW + dt.timedelta(days=1), notify=notes)
    bill = db.document(f"feeStatements/{BILL}").get().to_dict()
    assert bill["totalDuePiasters"] == 0 and bill["status"] == "paid" and bill["waived"] is True
    assert fees.mark_overdue(db, now=NOW + dt.timedelta(days=8), notify=notes) == 0


def test_a_fee_waived_during_the_hold_ends_it_through_the_shared_release(db, notes):
    on_hold(db, notes)
    db.document(f"payments/{PAY}").update({"feeState": "waived"})
    fees.refresh(db, PAY, NOW + dt.timedelta(days=9), notify=notes)
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is True
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["coachAway"] is False
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["endsAt"] == NOW + dt.timedelta(days=28) + dt.timedelta(days=2)


def test_a_bill_in_dispute_does_not_keep_her_held_and_cannot_hold_her(db, notes):
    on_hold(db, notes)
    make_payment(db, "pay-2", status="confirmed", feeState="disputed", feePiasters=900, feeOwedAt=NOW, clientUid="client-2", coachUid=COACH)
    db.document("feeStatements/second").set({"coachUid": COACH, "status": "open", "year": 2026, "month": 11, "dueAt": NOW,
                                             "holdAt": NOW + dt.timedelta(days=7), "overdueNotified": False, "totalDuePiasters": 0,
                                             "lines": [{"paymentId": "pay-2", "feeState": "disputed"}]})
    fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=NOW + dt.timedelta(days=10), notify=notes)
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]
    db.document(f"feeStatements/second").update({"overdueNotified": False})
    assert fees.mark_overdue(db, now=NOW + dt.timedelta(days=20), notify=notes) == 0


# --------------------------------------------------- coachings during a hold

def test_a_coaching_that_would_end_during_the_hold_is_kept_and_one_that_began_in_it_gets_only_its_part(db, notes):
    on_hold(db, notes)
    db.document(f"subscriptions/{SUB}").update({"endsAt": NOW + dt.timedelta(days=8)})
    db.document("subscriptions/during").set({"coachUid": COACH, "clientUid": "client-d", "status": "active", "relId": f"{COACH}__client-d",
                                             "startsAt": NOW + dt.timedelta(days=8), "endsAt": NOW + dt.timedelta(days=36), "package": {"durationDays": 28}})
    counts = subscriptions.sweep(db, now=NOW + dt.timedelta(days=9), notify=notes)
    assert counts["ended"] == 0 and db.document(f"subscriptions/{SUB}").get().to_dict()["status"] == "active"
    fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=NOW + dt.timedelta(days=10), notify=notes)
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["endsAt"] == NOW + dt.timedelta(days=8) + dt.timedelta(days=3)
    assert db.document("subscriptions/during").get().to_dict()["endsAt"] == NOW + dt.timedelta(days=36) + dt.timedelta(days=2)


# ----------------------------------------------- the held coach's other doors

def test_a_held_coach_cannot_leave_a_coaching_mark_a_session_or_make_a_code(db, notes):
    on_hold(db, notes)
    for call in (
        lambda: subscriptions.end_mine(db, COACH, {"subId": SUB}, live=True, now=NOW, notify=notes),
        lambda: sessions.mark_done(db, COACH, {"subId": SUB, "sessionId": "x"}, live=True, now=NOW),
        lambda: invites.create(db, COACH, is_coach=True, verified=True, live=True, now=NOW),
    ):
        with pytest.raises(c_errors.CoachingError) as caught:
            call()
        assert caught.value.reason == c_errors.COACH_ON_HOLD
    subscriptions.end_mine(db, CLIENT, {"subId": SUB}, live=True, now=NOW, notify=notes)    # her client may


def test_the_hold_is_not_readable_from_the_public_coach_page(db, notes):
    on_hold(db, notes)
    assert "hold" not in db.document(f"coaches/{COACH}").get().to_dict()
    assert "acceptingBeforeOverdue" not in db.document(f"coaches/{COACH}").get().to_dict()


def test_the_needs_you_view_lists_claims_and_held_accounts_only(db):
    rows = {"claimed": ("paid_claimed", False), "held": ("open", True), "plain": ("open", False), "done": ("paid", True)}
    for i, (sid, (status, held)) in enumerate(rows.items()):
        db.document(f"feeStatements/{sid}").set({"coachUid": COACH, "status": status, "overdueNotified": held, "generatedAt": NOW + dt.timedelta(days=i)})
    out = fees.list_statements(db, FINANCE, {"status": "attention"}, now=NOW)
    assert [i["statementId"] for i in out["items"]] == ["held", "claimed"]


# ----------------------------------------------------- second review round

D = dt.timedelta(days=1)


def test_the_invite_rate_applies_to_the_first_paid_payment_end_to_end(db, notes, pushes):
    subs.seed(db, accounts=False)
    db.document(f"coaches/{COACH}").update({"instapayReady": True, "autoAccept": False})
    db.document(f"coachPaymentProfiles/{COACH}").set({"paymentsConfirmed": 0, "cleanConfirmed": 0})
    code_for(db, COACH)
    out = subscriptions.request(db, subs.CLIENT, {"coachUid": COACH, "packageId": subs.PACKAGE, "intake": subs.intake(), "locale": "en",
                                                  "consent": subs.consent(), "inviteCode": CODE},
                                live=True, verified=True, now=subs.NOW, notify=pushes, instapay=True)
    sub_id = out["subId"]
    subscriptions.respond(db, COACH, {"subId": sub_id, "decision": "accept"}, live=True, coach_v="active", now=subs.NOW, notify=pushes, instapay=True)
    assert "source" not in relationship(db)
    make_payment(db, "pay-e2e", status="proof_submitted", proofSubmittedAt=subs.NOW, subId=sub_id, clientUid=subs.CLIENT)
    coach.confirm(db, COACH, {"paymentId": "pay-e2e"}, coach_v="active", now=subs.NOW, notify=notes)
    assert payment_of(db, "pay-e2e")["feeBps"] == 750 and relationship(db)["source"] == "invite"


def test_a_coaching_that_starts_during_the_hold_is_marked_away_and_extended_by_its_part(db, notes):
    on_hold(db, notes)
    db.document("subscriptions/sub-2").set({"coachUid": COACH, "clientUid": "c2", "relId": f"{COACH}__c2", "packageId": "pk0",
                                            "package": {"title": "P0", "durationDays": 28}, "priceFinalEgp": 500, "status": "awaiting_payment",
                                            "statusAt": NOW, "payBy": NOW + 20 * D, "payment": {"state": "awaiting"}, "source": "app"})
    db.document(f"relationships/{COACH}__c2").set({"coachUid": COACH, "clientUid": "c2", "status": "none", "chatOpen": False})
    make_payment(db, "pay-2", status="proof_submitted", proofSubmittedAt=NOW + 8 * D, clientUid="c2", subId="sub-2")
    coach.confirm(db, COACH, {"paymentId": "pay-2"}, coach_v="active", now=NOW + 8 * D, notify=notes)
    assert db.document(f"relationships/{COACH}__c2").get().to_dict()["coachAway"] is True
    before = db.document("subscriptions/sub-2").get().to_dict()["endsAt"]
    fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=NOW + 10 * D, notify=notes)   # her new bill is not yet past its own hold time
    assert db.document("subscriptions/sub-2").get().to_dict()["endsAt"] - before == 2 * D


def test_a_later_closure_never_flips_her_own_not_taking_clients_choice(db, notes):
    on_hold(db, notes)
    fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=NOW + 8 * D, notify=notes)
    db.document(f"coaches/{COACH}").update({"acceptingClients": False})
    make_payment(db, "pay-3", status="confirmed", feeState="owed", feePiasters=900, feeOwedAt=NOW + 9 * D, clientUid="c3", feeStatementId=f"{COACH}__pay-3")
    db.document(f"feeStatements/{COACH}__pay-3").set({"coachUid": COACH, "status": "open", "lines": [{"paymentId": "pay-3"}], "totalDuePiasters": 900,
                                                      "dueAt": NOW + 12 * D, "holdAt": NOW + 16 * D, "overdueNotified": False})
    db.document("payments/pay-3").update({"feeState": "waived"})
    fees.refresh(db, "pay-3", NOW + 10 * D, notify=notes)
    assert db.document(f"coaches/{COACH}").get().to_dict()["acceptingClients"] is False


def test_the_hourly_pass_releases_a_held_coach_whose_only_late_line_went_into_dispute(db, notes):
    on_hold(db, notes)
    db.document(f"payments/{PAY}").update({"feeState": "disputed", "status": "in_review"})
    assert timers.hourly(db, NOW + 8 * D, notes)["holdsReleased"] == 1
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]


def test_a_bill_with_only_a_disputed_line_cannot_be_confirmed_and_a_mixed_one_keeps_the_disputed_fee(db, notes):
    confirmed_payment(db, notes)
    db.document(f"payments/{PAY}").update({"feeState": "disputed"})
    with pytest.raises(c_errors.CoachingError):
        fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=NOW + D, notify=notes)
    # a monthly statement with one owed and one disputed line
    make_payment(db, "pay-b", status="confirmed", feeState="owed", feePiasters=500, feeOwedAt=NOW, clientUid="cb")
    db.document("feeStatements/m").set({"coachUid": COACH, "status": "open", "year": 2026, "month": 10, "dueAt": NOW, "holdAt": NOW + 7 * D,
                                        "lines": [{"paymentId": PAY}, {"paymentId": "pay-b"}]})
    fees.confirm_payment(db, FINANCE, {"statementId": "m"}, now=NOW + D, notify=notes)
    assert payment_of(db, "pay-b")["feeState"] == "settled"
    own = db.document(f"feeStatements/{COACH}__{PAY}").get().to_dict()
    assert own["status"] == "open" and payment_of(db)["feeStatementId"] == f"{COACH}__{PAY}"
    db.document(f"payments/{PAY}").update({"feeState": "owed"})        # the dispute resolved as owed
    fees.refresh(db, PAY, NOW + 2 * D, notify=notes)
    assert db.document(f"feeStatements/{COACH}__{PAY}").get().to_dict()["totalDuePiasters"] == payment_of(db)["feePiasters"] > 0


def test_the_provisional_upgrade_keeps_the_days_given_back_after_a_hold(db, notes):
    on_hold(db, notes)
    db.document(f"subscriptions/{SUB}").update({"provisionalUntil": NOW + 9 * D, "endsAt": NOW + 9 * D})
    fees.confirm_payment(db, FINANCE, {"statementId": BILL}, now=NOW + 17 * D, notify=notes)
    row = db.document(f"subscriptions/{SUB}").get().to_dict()
    assert row["holdCreditSeconds"] == 10 * 86400
    from payments import activation
    seen = {"sub": {**row, "payment": {}}, "subRef": db.document(f"subscriptions/{SUB}")}
    db.document(f"subscriptions/{SUB}").update({"payment": {}})
    common.run(db, lambda t: activation.grant(t, db, {**seen, "sub": db.document(f"subscriptions/{SUB}").get().to_dict()}, NOW + 17 * D))
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["endsAt"] == NOW + 28 * D + 10 * D


def test_a_coaching_is_not_ended_by_a_sweep_that_raced_the_hold(db, notes):
    on_hold(db, notes)
    db.document(f"subscriptions/{SUB}").update({"endsAt": NOW + 8 * D})
    assert subscriptions._finish(db, SUB, NOW + 9 * D) is None
    assert db.document(f"subscriptions/{SUB}").get().to_dict()["status"] == "active"


def test_a_bill_that_owes_nothing_is_not_an_account_on_hold_and_makes_no_ready_push(db, notes):
    assert not fees.on_hold_bill({"overdueNotified": True, "status": "open", "totalDuePiasters": 0})
    assert fees.on_hold_bill({"overdueNotified": True, "status": "open", "totalDuePiasters": 5})
    seed_world(db)
    make_payment(db, "z", status="confirmed", feeState="waived", feePiasters=0, feeOwedAt=dt.datetime(2026, 10, 3, tzinfo=UTC), clientUid="cz")
    assert fees.generate(db, now=dt.datetime(2026, 11, 1, 6, tzinfo=common.CAIRO), notify=notes) == 0
    assert notes.sent == []


def test_needs_attention_works_on_hold(db, notes):
    from coaching import checkins
    on_hold(db, notes)
    checkins.needs_attention(db, COACH, live=True, coach_v="active", now=NOW + 8 * D)


def test_a_fee_that_leaves_a_dispute_as_owed_gets_fresh_dates_and_no_instant_hold(db, notes):
    confirmed_payment(db, notes)
    db.document(f"payments/{PAY}").update({"feeState": "disputed", "status": "in_review"})
    timers.hourly(db, NOW + 2 * D, notes)
    timers.hourly(db, NOW + 8 * D, notes)
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict().get("hold")        # a fee in dispute holds nobody
    db.document(f"payments/{PAY}").update({"feeState": "owed", "status": "resolved_paid"})
    fees.refresh(db, PAY, NOW + 10 * D, notify=notes)
    timers.hourly(db, NOW + 10 * D + dt.timedelta(hours=1), notes)
    bill = db.document(f"feeStatements/{BILL}").get().to_dict()
    assert bill["dueAt"] == NOW + 13 * D and bill["holdAt"] == NOW + 17 * D and bill["overdueNotified"] is False
    assert not db.document(f"coachPrivate/{COACH}").get().to_dict().get("hold")
    timers.hourly(db, NOW + 17 * D + dt.timedelta(hours=1), notes)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]            # still held if she then leaves it unpaid


def _two_line_bill(db, *, hold_at, overdue):
    make_payment(db, "pa", status="confirmed", feeState="owed", feePiasters=700, feeOwedAt=NOW, clientUid="ca", feeStatementId="two")
    make_payment(db, "pb", status="in_review", feeState="disputed", feePiasters=800, feeOwedAt=NOW, clientUid="cb", feeStatementId="two")
    db.document("feeStatements/two").set({"coachUid": COACH, "status": "open", "year": 2026, "month": 11, "dueAt": hold_at - 4 * D,
                                          "holdAt": hold_at, "overdueNotified": overdue, "totalDuePiasters": 700,
                                          "lines": [{"paymentId": "pa", "feeState": "owed"}, {"paymentId": "pb", "feeState": "disputed"}]})


def test_a_disputed_line_returning_does_not_let_off_a_coach_held_for_another_owed_line(db, notes):
    seed_world(db)
    _two_line_bill(db, hold_at=NOW + 7 * D, overdue=False)
    assert fees.mark_overdue(db, now=NOW + 8 * D, notify=notes) == 1
    db.document("payments/pb").update({"feeState": "owed", "status": "resolved_paid"})
    fees.refresh(db, "pb", NOW + 9 * D, notify=notes)
    timers.hourly(db, NOW + 9 * D + dt.timedelta(hours=1), notes)
    bill = db.document("feeStatements/two").get().to_dict()
    assert bill["holdAt"] == NOW + 7 * D and bill["totalDuePiasters"] == 1500
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["hold"]


def test_a_two_line_bill_with_both_fine_keeps_its_dates_when_a_dispute_returns(db, notes):
    seed_world(db)
    _two_line_bill(db, hold_at=NOW + 7 * D, overdue=False)
    db.document("payments/pb").update({"feeState": "owed", "status": "resolved_paid"})
    fees.refresh(db, "pb", NOW + 1 * D, notify=notes)
    bill = db.document("feeStatements/two").get().to_dict()
    assert bill["holdAt"] == NOW + 7 * D and bill["totalDuePiasters"] == 1500 and not bill["overdueNotified"]
    assert not (db.document(f"coachPrivate/{COACH}").get().to_dict() or {}).get("hold")
