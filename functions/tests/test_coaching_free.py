"""Joining a coach while payments are off: accepting starts the coaching at
once, free, with no payment code, ledger or receipt. The paid path stays as it
was when payments are on. Also the clients switch, the sweeper split and the
cheap chat list."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import chat, common, errors, subscriptions
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    CLIENT, COACH, NOW, PACKAGE, consent, db, intake, later, pushes, refuse, seed, sub_of,
)


def ask(db, pushes, *, uid=CLIENT, payments=False, live=True, now=NOW, **over):
    data = {"coachUid": COACH, "packageId": PACKAGE, "intake": intake(), "consent": consent(), "locale": "en"}
    data.update(over)
    return subscriptions.request(
        db, uid, data, live=live, payments_live=payments, verified=True, now=now, notify=pushes
    )


def answer(db, pushes, sub_id, *, payments=False, now=NOW, **over):
    data = {"subId": sub_id, "decision": "accept", **over}
    return subscriptions.respond(
        db, COACH, data, live=True, payments_live=payments, coach_v="active", now=now, notify=pushes
    )


def coach(db):
    return db.document(f"coaches/{COACH}").get().to_dict()


def rel(db, client=CLIENT):
    return db.document(f"relationships/{common.rel_id(COACH, client)}").get().to_dict()


def messages(db, client=CLIENT):
    rows = db.collection("relationships").document(common.rel_id(COACH, client)).collection("messages").stream()
    return [row.to_dict() for row in rows]


def assert_free_and_active(db, sub_id, started):
    sub = sub_of(db, sub_id)
    assert sub["status"] == "active" and sub["free"] is True
    assert sub["startsAt"] == started and sub["endsAt"] == started + dt.timedelta(days=28)
    for key in ("payTo", "paymentCode", "payBy", "payment"):
        assert key not in sub
    assert not [p for p in db.docs if p.startswith(f"coachPrivate/{COACH}/ledger")]
    assert not [p for p in db.docs if p.startswith("receipts/")]
    row = rel(db)
    assert (row["status"], row["chatOpen"], row["activeSubId"]) == ("active", True, sub_id)
    assert coach(db)["activeClients"] == 1 and coach(db)["stats"]["clientsCoached"] == 1
    assert [m["systemKind"] for m in messages(db)] == ["started"]


def test_accepting_starts_the_coaching_at_once_and_needs_no_receiving_account(db, pushes):
    seed(db, auto=False, accounts=False, seller=False)
    sub_id = ask(db, pushes)["subId"]
    assert sub_of(db, sub_id)["status"] == "requested"
    pushes.clear()
    assert answer(db, pushes, sub_id, now=later(hours=5)) == {"status": "active"}
    assert_free_and_active(db, sub_id, later(hours=5))
    assert pushes == [(CLIENT, "requestAnswered"), (CLIENT, "coachingStarted")]


def test_the_request_pushes_the_coach(db, pushes):
    seed(db, auto=False, accounts=False)
    ask(db, pushes)
    assert pushes == [(COACH, "coachingRequest")]


def test_auto_accept_activates_in_the_same_call(db, pushes):
    seed(db, accounts=False, seller=False)
    result = ask(db, pushes)
    assert result["status"] == "active"
    assert_free_and_active(db, result["subId"], NOW)
    assert pushes == [(COACH, "coachingRequest")]


def test_a_health_yes_still_waits_for_the_coach_even_with_auto_accept(db, pushes):
    seed(db, accounts=False)
    health = {key: False for key in common.ENUMS["healthQuestions"]}
    health[next(iter(health))] = True
    result = ask(db, pushes, intake=intake(health=health, doctorAck=True))
    assert result["status"] == "requested"
    assert coach(db)["activeClients"] == 0


def test_a_second_coaching_with_the_same_coach_is_not_a_first_client(db, pushes):
    seed(db, auto=False, accounts=False)
    first = ask(db, pushes)["subId"]
    answer(db, pushes, first)
    db.document(f"subscriptions/{first}").update({"status": "ended"})
    db.document(f"relationships/{common.rel_id(COACH, CLIENT)}").update({"status": "ended", "chatOpen": False})
    db.document(f"coaches/{COACH}").update({"activeClients": 0})
    second = ask(db, pushes, now=later(days=40))["subId"]
    answer(db, pushes, second, now=later(days=40))
    assert coach(db)["stats"]["clientsCoached"] == 1
    assert rel(db)["activeSubId"] == second


def test_the_paid_path_is_unchanged_when_payments_are_on(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes, payments=True)["subId"]
    assert answer(db, pushes, sub_id, payments=True) == {"status": "awaiting_payment"}
    sub = sub_of(db, sub_id)
    assert "free" not in sub and sub["paymentCode"] and "payTo" in sub
    assert coach(db)["activeClients"] == 0


def test_payments_on_still_needs_a_receiving_account(db, pushes):
    seed(db, auto=False, accounts=False)
    refuse(lambda: ask(db, pushes, payments=True), errors.PRECONDITION, errors.ACCOUNTS_NOT_SET)


def test_decline_works_the_same_while_payments_are_off(db, pushes):
    seed(db, auto=False, accounts=False)
    sub_id = ask(db, pushes)["subId"]
    reason = common.ENUMS["declineReasons"][0]
    assert answer(db, pushes, sub_id, decision="decline", reason=reason) == {"status": "declined"}
    assert rel(db)["status"] == "none"


def test_capacity_for_a_hand_accept_counts_active_clients_not_other_requests(db, pushes):
    seed(db, auto=False, accounts=False, cap=1)
    a = ask(db, pushes, uid="c1")["subId"]
    b = ask(db, pushes, uid="c2")["subId"]
    assert answer(db, pushes, a) == {"status": "active"}
    refuse(lambda: answer(db, pushes, b), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


def test_open_requests_use_up_the_places_auto_accept_may_fill(db, pushes):
    seed(db, auto=False, accounts=False, cap=2)
    ask(db, pushes, uid="c1")
    ask(db, pushes, uid="c2")
    db.document(f"coaches/{COACH}").update({"autoAccept": True})
    assert ask(db, pushes, uid="c3")["status"] == "requested"


def test_a_free_coaching_cannot_be_ended_with_a_refund(db, pushes):
    seed(db, auto=False, accounts=False)
    sub_id = ask(db, pushes)["subId"]
    answer(db, pushes, sub_id)
    refuse(
        lambda: subscriptions.end_early(
            db, "staff-1", {"subId": sub_id, "reason": common.ENUMS["endReasons"][0],
                            "rail": "instapay", "refundEgp": 100, "refundReference": "REF1234567"},
            now=later(days=1), notify=pushes),
        errors.INVALID, errors.BAD_REQUEST,
    )


def test_staff_end_a_free_coaching_without_any_money_records(db, pushes):
    seed(db, auto=False, accounts=False)
    sub_id = ask(db, pushes)["subId"]
    answer(db, pushes, sub_id)
    subscriptions.end_early(
        db, "staff-1", {"subId": sub_id, "reason": common.ENUMS["endReasons"][0]},
        now=later(days=1), notify=pushes,
    )
    assert sub_of(db, sub_id)["status"] == "ended_early"
    assert rel(db)["status"] == "ended" and coach(db)["activeClients"] == 0


def test_every_client_call_refuses_when_the_clients_switch_is_off(db, pushes):
    seed(db, auto=False, accounts=False)
    refuse(lambda: ask(db, pushes, live=False), errors.PRECONDITION, errors.COACH_APP_CLOSED)
    sub_id = ask(db, pushes)["subId"]
    refuse(
        lambda: subscriptions.respond(
            db, COACH, {"subId": sub_id, "decision": "accept"}, live=False, coach_v="active", now=NOW, notify=pushes),
        errors.PRECONDITION, errors.COACH_APP_CLOSED,
    )
    refuse(
        lambda: subscriptions.cancel_request(db, CLIENT, {"subId": sub_id}, live=False, now=NOW),
        errors.PRECONDITION, errors.COACH_APP_CLOSED,
    )


# ------------------------------------------------------------------ the sweeper


def test_the_sweeper_clients_part_ends_a_finished_free_coaching_without_payments(db, pushes):
    seed(db, auto=False, accounts=False)
    sub_id = ask(db, pushes)["subId"]
    answer(db, pushes, sub_id)
    pushes.clear()
    counts = subscriptions.sweep(db, now=later(days=28, minutes=1), notify=pushes, clients=True, payments=False)
    assert counts["ended"] == 1
    assert sub_of(db, sub_id)["status"] == "ended"
    assert rel(db)["status"] == "ended" and coach(db)["activeClients"] == 0


def test_the_payments_part_does_not_run_without_its_switch(db, pushes):
    seed(db)
    paid = ask(db, pushes, payments=True, now=later(hours=-73))["subId"]
    old = db.collection("subscriptions").document()
    old.set({"status": "requested", "coachUid": COACH, "clientUid": "x", "statusAt": later(hours=-73)})
    counts = subscriptions.sweep(db, now=NOW, notify=pushes, clients=True, payments=False)
    assert counts["expiredRequests"] == 1 and counts["expiredPayments"] == 0
    assert sub_of(db, paid)["status"] == "awaiting_payment"


def test_the_clients_part_does_not_run_without_its_switch(db, pushes):
    seed(db, auto=False)
    old = db.collection("subscriptions").document()
    old.set({"status": "requested", "coachUid": COACH, "clientUid": "x", "statusAt": later(hours=-73)})
    unpaid = db.collection("subscriptions").document()
    unpaid.set({"status": "awaiting_payment", "coachUid": COACH, "clientUid": "y", "payBy": later(hours=-1), "statusAt": later(hours=-2)})
    counts = subscriptions.sweep(db, now=NOW, notify=pushes, clients=False, payments=True)
    assert counts["expiredRequests"] == 0 and counts["expiredPayments"] == 1
    assert old.get().to_dict()["status"] == "requested"


# --------------------------------------------------------------- the chat list

REL = common.rel_id("coach1", "client1")


def seed_thread(db, **extra):
    db.collection("relationships").document(REL).set(
        {"coachUid": "coach1", "clientUid": "client1", "status": "active", "chatOpen": True, **extra}
    )


def run_message(db, mid, row, now=NOW):
    db.collection("relationships").document(REL).collection("messages").document(mid).set(row)
    return chat.on_message(db, REL, mid, row, now=now, notify=lambda uid, kind: None)


def thread(db):
    return db.document(f"relationships/{REL}").get().to_dict()


def test_a_message_sets_the_preview_and_the_other_partys_unread_count(db):
    seed_thread(db)
    run_message(db, "m1", {"senderUid": "client1", "type": "text", "text": "x" * 120, "createdAt": NOW})
    row = thread(db)
    assert row["lastMessage"] == {"text": "x" * 80, "type": "text", "senderUid": "client1", "at": NOW}
    assert row["unreadFor"] == {"coach1": 1}
    run_message(db, "m2", {"senderUid": "client1", "type": "text", "text": "again", "createdAt": NOW})
    assert thread(db)["unreadFor"]["coach1"] == 2
    run_message(db, "m3", {"senderUid": "coach1", "type": "text", "text": "hello", "createdAt": NOW})
    assert thread(db)["unreadFor"] == {"coach1": 2, "client1": 1}


def test_a_recipe_shows_its_kind_not_words(db):
    seed_thread(db)
    run_message(db, "m1", {"senderUid": "coach1", "type": "recipe", "recipeId": "koshari", "createdAt": NOW})
    assert thread(db)["lastMessage"]["text"] == "" and thread(db)["lastMessage"]["type"] == "recipe"


def test_a_hidden_message_never_shows_its_words_and_is_not_counted(db):
    seed_thread(db)
    run_message(db, "m1", {"senderUid": "client1", "type": "text", "text": "call 01012345678", "createdAt": NOW})
    row = thread(db)
    assert row["lastMessage"]["text"] == "" and row["lastMessage"]["type"] == "hidden"
    assert "unreadFor" not in row


def test_reading_a_thread_zeroes_only_her_count_and_marks_the_time(db):
    seed_thread(db, unreadFor={"coach1": 3, "client1": 2})
    assert chat.mark_read(db, "coach1", {"relId": REL}, live=True, now=later(minutes=5)) == {"ok": True}
    assert thread(db)["unreadFor"] == {"coach1": 0, "client1": 2}
    assert db.docs[f"relationships/{REL}/reads/coach1"] == {"at": later(minutes=5)}


def test_a_stranger_or_a_missing_thread_is_not_found_and_nothing_is_written(db):
    seed_thread(db, unreadFor={"coach1": 3})
    before = dict(db.docs)
    refuse(lambda: chat.mark_read(db, "other", {"relId": REL}, live=True, now=NOW), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(lambda: chat.mark_read(db, "coach1", {"relId": "no__thread"}, live=True, now=NOW), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    assert db.docs == before


def test_mark_read_needs_the_clients_switch_and_a_relationship_id(db):
    seed_thread(db)
    refuse(lambda: chat.mark_read(db, "coach1", {"relId": REL}, live=False, now=NOW), errors.PRECONDITION, errors.COACH_APP_CLOSED)
    refuse(lambda: chat.mark_read(db, "coach1", {}, live=True, now=NOW), errors.INVALID, errors.BAD_REQUEST)


# -------------------------------------------------------------- clientName


def test_the_request_carries_her_first_name_only(db, pushes):
    seed(db, auto=False, accounts=False)
    db.document(f"users/{CLIENT}").set({"displayName": "Mona Hassan Ali", "phone": "+201000000000"})
    sub = sub_of(db, ask(db, pushes, clientName="Mona Hassan Ali")["subId"])
    assert sub["clientName"] == "Mona"
    assert "Hassan" not in str(sub) and "+2010" not in str(sub)


@pytest.mark.parametrize("stored", [None, "", "   ", "01012345678 Mona"])
def test_a_missing_or_odd_name_leaves_the_name_empty(db, pushes, stored):
    seed(db, auto=False, accounts=False)
    if stored is not None:
        db.document(f"users/{CLIENT}").set({"displayName": stored})
    assert sub_of(db, ask(db, pushes)["subId"])["clientName"] == ""


def test_the_name_she_gives_is_stored_as_a_first_name(db, pushes):
    seed(db, auto=False, accounts=False)
    db.document(f"users/{CLIENT}").set({"displayName": "Account Name"})
    sub = sub_of(db, ask(db, pushes, clientName="  Mona Hassan ")["subId"])
    assert sub["clientName"] == "Mona"


@pytest.mark.parametrize("given", ["Mona2", "x" * 41, 7, ["Mona"], {"a": 1}, True])
def test_a_bad_name_is_stored_empty_and_not_replaced(db, pushes, given):
    seed(db, auto=False, accounts=False)
    db.document(f"users/{CLIENT}").set({"displayName": "Account Name"})
    assert sub_of(db, ask(db, pushes, clientName=given)["subId"])["clientName"] == ""


@pytest.mark.parametrize("given", [None, "", "   "])
def test_no_name_given_shares_no_name(db, pushes, given):
    # Her account name is never used: the coach sees only what she typed.
    seed(db, auto=False, accounts=False)
    db.document(f"users/{CLIENT}").set({"displayName": "Mona Hassan"})
    over = {} if given is None else {"clientName": given}
    assert sub_of(db, ask(db, pushes, **over)["subId"])["clientName"] == ""


def test_the_ended_coaching_clears_the_next_session(db, pushes):
    seed(db, auto=False, accounts=False)
    sub_id = ask(db, pushes)["subId"]
    answer(db, pushes, sub_id)
    db.document(f"subscriptions/{sub_id}").update({"nextSessionAt": later(days=3)})
    subscriptions.end_early(
        db, "staff-1", {"subId": sub_id, "reason": common.ENUMS["endReasons"][0]},
        now=later(days=1), notify=pushes,
    )
    assert sub_of(db, sub_id)["nextSessionAt"] is None


@pytest.mark.parametrize("card", [
    {"type": "workoutPlan", "planId": "p1"}, {"type": "mealPlan", "planId": "p1"},
    {"type": "session", "sessionId": "s1"},
])
def test_a_server_card_adds_one_unread_for_the_other_party_and_no_message_push(db, card):
    seed_thread(db)
    pushed = []
    row = {"senderUid": "coach1", "createdAt": NOW, **card}
    db.collection("relationships").document(REL).collection("messages").document("m1").set(row)
    chat.on_message(db, REL, "m1", row, now=NOW, notify=lambda uid, kind: pushed.append(kind))
    assert thread(db)["unreadFor"] == {"client1": 1} and pushed == []


def test_a_system_line_adds_no_unread(db):
    seed_thread(db)
    run_message(db, "m1", {"senderUid": "system", "type": "system", "systemKind": "started", "createdAt": NOW})
    assert "unreadFor" not in thread(db)


def test_a_first_name_with_contact_details_is_refused(db, pushes):
    seed(db)
    with pytest.raises(errors.CoachingError) as caught:
        ask(db, pushes, clientName="mona.com")
    assert caught.value.reason == errors.CONTAINS_CONTACT
