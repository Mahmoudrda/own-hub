"""Tests for coach InstaPay address setup (WO-10d-server)."""

from __future__ import annotations

import datetime as dt
import pytest

from coaching import common, errors as c_errors
from payments import address as address_mod, errors, profile
from tests.payments_helpers import (
    ACCOUNT_NAME,
    ADDRESS,
    CLIENT,
    CLIENT2,
    COACH,
    COACH2,
    NOW,
    Notes,
    _txn,
    db,
    later,
    make_payment,
    notes,
    refusal,
    seed_world,
)


def go(db, notes, address="rahma@instapay", name="Rahma M.", recent=True, now=NOW):
    return address_mod.set_address(
        db, COACH, {"address": address, "accountName": name},
        coach_v="active", recent_sign_in=recent, now=now, notify=notes,
    )


def test_the_first_address_is_active_at_once_and_makes_the_coach_ready(db, notes):
    seed_world(db, ready=False)
    db.document(f"coachPaymentProfiles/{COACH}").delete()

    res = go(db, notes, address="first@instapay", name="First Coach")
    assert res == {"status": "active", "effectiveAt": common.plain(NOW)}

    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["address"] == "first@instapay"
    assert prof["accountName"] == "First Coach"
    assert prof["allowLongFirst"] is False
    assert prof["autoConfirmGreen"] is False
    assert prof["pending"] is None

    coach = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach["instapayReady"] is True

    alerts = [d.to_dict() for d in db.collection("paymentAlerts").stream()]
    assert len(alerts) == 1
    assert alerts[0]["type"] == "addressChange"
    assert alerts[0]["firstTime"] is True
    assert len(notes.sent) == 0


def test_a_change_is_pending_for_24_hours_and_old_payments_keep_the_old_address(db, notes):
    seed_world(db)
    make_payment(db, "pay-old")

    res = go(db, notes, address="new@instapay", name="New Name", now=NOW)
    assert res["status"] == "pending"
    assert res["effectiveAt"] == common.plain(NOW + dt.timedelta(hours=24))

    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert profile.effective(prof, NOW + dt.timedelta(hours=23)) == (ADDRESS, ACCOUNT_NAME)
    assert profile.effective(prof, NOW + dt.timedelta(hours=25)) == ("new@instapay", "New Name")

    old_pay = db.document("payments/pay-old").get().to_dict()
    assert old_pay["addressSnapshot"] == {"address": ADDRESS, "accountName": ACCOUNT_NAME}


def test_clients_with_an_open_payment_are_told_and_others_are_not(db, notes):
    seed_world(db)
    # Client A: awaiting_payment
    make_payment(db, "p-a", clientUid=CLIENT, status="awaiting_payment", lateUntil=later(days=7))
    # Client B: expired within 7 days
    make_payment(db, "p-b", clientUid=CLIENT2, status="expired", lateUntil=later(days=3))
    # Client C: confirmed
    make_payment(db, "p-c", clientUid="client-3", status="confirmed", lateUntil=later(days=7))
    # Client D: awaiting_payment of another coach
    make_payment(db, "p-d", clientUid="client-4", coachUid=COACH2, status="awaiting_payment", lateUntil=later(days=7))

    go(db, notes, address="updated@instapay", name="Updated Coach", now=NOW)

    notified = [call[0] for call in notes.sent if call[1] == "instapayAddressChanged"]
    assert set(notified) == {CLIENT, CLIENT2}
    assert {(uid, ref) for uid, kind, ref in notes.refs if kind == "instapayAddressChanged"} == {(CLIENT, "p-a"), (CLIENT2, "p-b")}


def test_a_second_change_replaces_the_pending_one_and_restarts_the_delay(db, notes):
    seed_world(db)
    go(db, notes, address="pending1@instapay", name="Pending One", now=NOW)

    # 5 minutes after last -> EXHAUSTED TOO_MANY_REQUESTS
    assert refusal(lambda: go(db, notes, address="pending2@instapay", name="Pending Two", now=NOW + dt.timedelta(minutes=5))) == (errors.EXHAUSTED, errors.TOO_MANY_REQUESTS)

    # 30 minutes after last -> replaces pending and restarts 24 hours
    res = go(db, notes, address="pending2@instapay", name="Pending Two", now=NOW + dt.timedelta(minutes=30))
    assert res["status"] == "pending"
    assert res["effectiveAt"] == common.plain(NOW + dt.timedelta(minutes=30, hours=24))

    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["pending"]["address"] == "pending2@instapay"


def test_the_same_address_again_changes_nothing(db, notes):
    seed_world(db)
    alerts_before = len([d for d in db.collection("paymentAlerts").stream()])

    res = go(db, notes, address=ADDRESS, name=ACCOUNT_NAME, now=NOW)
    assert res["status"] == "active"

    alerts_after = len([d for d in db.collection("paymentAlerts").stream()])
    assert alerts_after == alerts_before


def test_a_stale_sign_in_is_refused_and_nothing_is_written(db, notes):
    seed_world(db)
    alerts_before = len([d for d in db.collection("paymentAlerts").stream()])

    assert refusal(lambda: go(db, notes, address="stale@instapay", name="Stale Coach", recent=False)) == (errors.PERMISSION, errors.RECENT_SIGN_IN_REQUIRED)

    alerts_after = len([d for d in db.collection("paymentAlerts").stream()])
    assert alerts_after == alerts_before


def test_a_phone_number_is_not_an_address(db, notes):
    seed_world(db)
    for bad in ("01012345678", "+201012345678", "010 1234 5678"):
        assert refusal(lambda: go(db, notes, address=bad)) == (errors.INVALID, errors.ADDRESS_NOT_HANDLE)


def test_format_rules(db, notes):
    seed_world(db)
    for bad in ("nobody", "a@instapay", "rahma@cib", "rah ma@instapay", "", None, 5):
        with pytest.raises(Exception):
            go(db, notes, address=bad)

    # Uppercase normalized to lowercase
    res = go(db, notes, address="RAHMA2@InstaPay", name="Rahma M", now=NOW)
    assert res["status"] == "pending"
    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["pending"]["address"] == "rahma2@instapay"

    # With allowed suffixes config
    db.document("coachingConfig/instapay").set({"addressSuffixes": ["instapay", "cib"]})
    res2 = go(db, notes, address="rahma@cib", name="Rahma CIB", now=NOW + dt.timedelta(minutes=15))
    assert res2["status"] == "pending"
    prof2 = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof2["pending"]["address"] == "rahma@cib"


def test_the_name_is_required(db, notes):
    seed_world(db)
    for bad_name in ("", "A", "x" * 81):
        assert refusal(lambda: go(db, notes, name=bad_name))[0] == c_errors.INVALID


def test_only_an_active_coach_can_save(db, notes):
    seed_world(db)
    assert refusal(lambda: address_mod.set_address(db, COACH, {"address": "x@instapay", "accountName": "Name"}, coach_v=None, recent_sign_in=True, now=NOW, notify=notes)) == (c_errors.PERMISSION, c_errors.NOT_A_COACH)

    assert refusal(lambda: address_mod.set_address(db, COACH, {"address": "x@instapay", "accountName": "Name"}, coach_v="suspended", recent_sign_in=True, now=NOW, notify=notes)) == (c_errors.PERMISSION, c_errors.COACH_SUSPENDED)


def test_a_suspended_coach_who_changes_her_address_stays_not_ready(db, notes):
    seed_world(db, suspended=True)
    go(db, notes, address="suspended@instapay", name="Suspended Coach", now=NOW)
    coach = db.document(f"coaches/{COACH}").get().to_dict()
    assert coach["instapayReady"] is False


def test_options_toggle_allow_long_first(db):
    seed_world(db)
    res = address_mod.set_options(db, COACH, {"allowLongFirst": True}, coach_v="active", now=NOW)
    assert res == {"allowLongFirst": True}
    prof = db.document(f"coachPaymentProfiles/{COACH}").get().to_dict()
    assert prof["allowLongFirst"] is True

    # Non-bool
    assert refusal(lambda: address_mod.set_options(db, COACH, {"allowLongFirst": "yes"}, coach_v="active", now=NOW))[0] == c_errors.INVALID

    # No profile
    db.document(f"coachPaymentProfiles/{COACH}").delete()
    assert refusal(lambda: address_mod.set_options(db, COACH, {"allowLongFirst": False}, coach_v="active", now=NOW)) == (errors.PRECONDITION, errors.COACH_NOT_READY)
