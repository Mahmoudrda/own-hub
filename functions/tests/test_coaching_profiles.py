"""Coach profile edits and payout account confirmation."""

from __future__ import annotations

import copy
import datetime as dt

import pytest

from coaching import errors, profiles
from console import access
from tests import fake_firestore
from tests.coaching_helpers import _txn, refusal  # noqa: F401
from tests.fake_blobs import FakeBlobs

NOW = dt.datetime(2026, 10, 20, 12, tzinfo=dt.timezone.utc)
UID = "coach-1"
FINANCE = "fin-1"
ACCOUNT = {"rail": "instapay", "account": "mona.h@instapay", "holderName": "Mona Hassan Ali"}


@pytest.fixture
def db(monkeypatch):
    fs = fake_firestore.FakeFirestore()
    fs.docs[f"coaches/{UID}"] = {
        "displayName": "Mona", "headline": "Strength coach for busy women",
        "approach": {"text": "x" * 60, "checkInsPerWeek": 2, "replyHours": 12},
        "acceptingClients": True, "autoAccept": True, "maxActiveClients": 15, "published": True,
    }
    fs.docs[f"coachPrivate/{UID}"] = {
        "fullName": "Mona Hassan Ali", "payout": dict(ACCOUNT), "payoutState": "pending",
        "owedEgp": 0, "paidEgp": 0,
    }
    return fs


@pytest.fixture
def blobs():
    b = FakeBlobs()
    b.put(f"coach-docs/{UID}/photo/new.jpg", b"raw")
    return b


def update(db, blobs, data, *, live=True, coach_v="active"):
    return profiles.update(
        db, UID, data, live=live, coach_v=coach_v, blobs=blobs,
        reencode=lambda raw, long_side=None: (b"thumb:" if long_side else b"jpeg:") + raw, now=NOW,
    )


# ---------------------------------------------------------------- update


def test_every_field_can_change(db, blobs):
    out = update(db, blobs, {
        "headline": "Strength and mobility coach", "approachText": "y" * 80, "acceptingClients": False,
        "autoAccept": False, "maxActiveClients": 30, "photoPath": f"coach-docs/{UID}/photo/new.jpg",
    })
    assert out == {"ok": True}
    coach = db.docs[f"coaches/{UID}"]
    assert coach["headline"] == "Strength and mobility coach"
    assert coach["approach"] == {"text": "y" * 80, "checkInsPerWeek": 2, "replyHours": 12}
    assert coach["acceptingClients"] is False and coach["autoAccept"] is False and coach["maxActiveClients"] == 30
    assert coach["updatedAt"] == NOW and coach["published"] is True
    assert blobs.objects[f"coach-public/{UID}/photo.jpg"] == (b"jpeg:raw", "image/jpeg")
    assert blobs.objects[f"coach-public/{UID}/photo_s.jpg"] == (b"thumb:raw", "image/jpeg")


def test_one_field_is_enough(db, blobs):
    update(db, blobs, {"autoAccept": False})
    assert db.docs[f"coaches/{UID}"]["autoAccept"] is False
    assert db.docs[f"coaches/{UID}"]["headline"] == "Strength coach for busy women"


@pytest.mark.parametrize("data", [
    {}, {"unknown": 1}, {"headline": "short"}, {"headline": "h" * 121}, {"approachText": "short"},
    {"approachText": "a" * 1501}, {"acceptingClients": "yes"}, {"autoAccept": 1},
    {"maxActiveClients": 0}, {"maxActiveClients": 51}, {"maxActiveClients": True}, {"maxActiveClients": "5"},
])
def test_bad_fields_are_refused_and_nothing_changes(db, blobs, data):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: update(db, blobs, data))[1] == errors.BAD_REQUEST
    assert db.docs == before and f"coach-public/{UID}/photo.jpg" not in blobs.objects


@pytest.mark.parametrize("path", [
    "coach-docs/other/photo/new.jpg", f"coach-docs/{UID}/education/new.jpg",
    f"coach-docs/{UID}/photo/missing.jpg", f"coach-docs/{UID}/photo/../x.jpg",
])
def test_a_photo_must_be_hers_and_uploaded(db, blobs, path):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: update(db, blobs, {"photoPath": path, "headline": "A fine new headline"})) == (errors.INVALID, errors.FILE_NOT_UPLOADED)
    assert db.docs == before


def test_update_refusals_by_state(db, blobs):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: update(db, blobs, {"autoAccept": True}, live=False)) == (errors.PRECONDITION, errors.COACH_APP_CLOSED)
    assert refusal(lambda: update(db, blobs, {"autoAccept": True}, coach_v=None)) == (errors.PERMISSION, errors.NOT_A_COACH)
    assert refusal(lambda: update(db, blobs, {"autoAccept": True}, coach_v="suspended")) == (errors.PERMISSION, errors.COACH_SUSPENDED)
    assert db.docs == before


# ---------------------------------------------------------------- payout


def request_change(db, data, *, live=True, coach_v="active"):
    return profiles.request_payout_change(db, UID, data, live=live, coach_v=coach_v, now=NOW)


def test_a_change_waits_as_pending(db):
    out = request_change(db, {"rail": "vodafoneCash", "account": "01012345678", "holderName": "Mona H Ali"})
    assert out == {"state": "pending"}
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["pendingPayout"] == {"rail": "vodafoneCash", "account": "01012345678", "holderName": "Mona H Ali", "requestedAt": NOW}
    assert private["payout"] == ACCOUNT


@pytest.mark.parametrize("data", [
    {}, {**ACCOUNT, "rail": "paypal"}, {**ACCOUNT, "account": "bad"}, {**ACCOUNT, "holderName": "Mo"},
    {**ACCOUNT, "rail": "vodafoneCash"},
])
def test_a_bad_account_is_refused(db, data):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: request_change(db, data))[1] == errors.BAD_REQUEST
    assert db.docs == before


def test_payout_change_refusals_by_state(db):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: request_change(db, ACCOUNT, live=False))[1] == errors.COACH_APP_CLOSED
    assert refusal(lambda: request_change(db, ACCOUNT, coach_v=None))[1] == errors.NOT_A_COACH
    assert refusal(lambda: request_change(db, ACCOUNT, coach_v="suspended"))[1] == errors.COACH_SUSPENDED
    assert db.docs == before


def confirm(db, decision, uid=UID):
    return profiles.confirm_payout(db, FINANCE, {"uid": uid, "decision": decision}, now=NOW)


def test_confirming_the_first_account(db):
    assert confirm(db, "confirm") == {"state": "confirmed"}
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["payoutState"] == "confirmed" and private["payout"] == ACCOUNT
    assert private["payoutNameMatches"] is True and "pendingPayout" not in private


def test_confirming_a_change_moves_it_into_payout(db):
    db.docs[f"coachPrivate/{UID}"].update(payoutState="confirmed")
    request_change(db, {"rail": "vodafoneCash", "account": "01012345678", "holderName": "mona   HASSAN ali"})
    assert confirm(db, "confirm") == {"state": "confirmed"}
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["payout"] == {"rail": "vodafoneCash", "account": "01012345678", "holderName": "mona   HASSAN ali"}
    assert private["payoutNameMatches"] is True and "pendingPayout" not in private


def test_a_holder_name_that_differs_is_flagged(db):
    db.docs[f"coachPrivate/{UID}"]["payout"]["holderName"] = "Someone Else"
    assert confirm(db, "confirm") == {"state": "confirmed"}
    assert db.docs[f"coachPrivate/{UID}"]["payoutNameMatches"] is False


def test_rejecting_the_first_account(db):
    assert confirm(db, "reject") == {"state": "rejected"}
    assert db.docs[f"coachPrivate/{UID}"]["payoutState"] == "rejected"


def test_rejecting_a_change_keeps_the_confirmed_account(db):
    db.docs[f"coachPrivate/{UID}"].update(payoutState="confirmed", payoutNameMatches=True)
    request_change(db, {**ACCOUNT, "account": "other@instapay"})
    assert confirm(db, "reject") == {"state": "confirmed"}
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["payout"] == ACCOUNT and private["payoutState"] == "confirmed" and "pendingPayout" not in private


def test_rejecting_a_change_before_any_confirmation_is_rejected(db):
    request_change(db, {**ACCOUNT, "account": "other@instapay"})
    assert confirm(db, "reject") == {"state": "rejected"}
    assert "pendingPayout" not in db.docs[f"coachPrivate/{UID}"]


def test_nothing_to_decide(db):
    db.docs[f"coachPrivate/{UID}"].update(payoutState="confirmed")
    before = copy.deepcopy(db.docs)
    for decision in ("confirm", "reject"):
        assert refusal(lambda: confirm(db, decision)) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert db.docs == before


@pytest.mark.parametrize("data", [{"uid": UID, "decision": "maybe"}, {"decision": "confirm"}, {"uid": "", "decision": "confirm"}])
def test_confirm_bad_requests(db, data):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: profiles.confirm_payout(db, FINANCE, data, now=NOW))[1] == errors.BAD_REQUEST
    assert db.docs == before


def test_confirming_for_someone_who_is_not_a_coach(db):
    assert refusal(lambda: confirm(db, "confirm", uid="nobody")) == (errors.NOT_FOUND, errors.NOT_A_COACH)


def test_a_decision_leaves_one_access_line_and_a_refusal_none(db):
    refusal(lambda: confirm(db, "maybe"))
    assert not [p for p in db.docs if p.startswith(access.COLLECTION)]
    confirm(db, "confirm")
    lines = [d for p, d in db.docs.items() if p.startswith(access.COLLECTION)]
    assert len(lines) == 1 and lines[0]["admin"] == access.short_ref(FINANCE)
    assert UID not in str(lines[0]) and "instapay" not in str(lines[0])


def test_finance_never_confirm_their_own_payout_account(db):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: profiles.confirm_payout(db, UID, {"uid": UID, "decision": "confirm"}, now=NOW)) == (
        errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert db.docs == before


def test_a_suspended_coach_with_a_valid_claim_cannot_edit_her_page_or_account(db, blobs):
    db.docs[f"coachPrivate/{UID}"]["suspended"] = True
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: update(db, blobs, {"acceptingClients": True}))[1] == errors.COACH_SUSPENDED
    assert refusal(lambda: profiles.request_payout_change(
        db, UID, ACCOUNT, live=True, coach_v="active", now=NOW))[1] == errors.COACH_SUSPENDED
    assert db.docs == before


def test_a_coach_with_no_private_record_is_not_a_coach(db, blobs):
    del db.docs[f"coachPrivate/{UID}"]
    assert refusal(lambda: update(db, blobs, {"acceptingClients": True}))[1] == errors.NOT_A_COACH


def test_a_coach_without_an_account_adds_one_later_and_finance_confirms_it(db):
    db.docs[f"coachPrivate/{UID}"] = {"fullName": "Mona Hassan Ali", "payoutState": "none"}
    assert request_change(db, ACCOUNT) == {"state": "pending"}
    assert confirm(db, "confirm") == {"state": "confirmed"}
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["payoutState"] == "confirmed" and private["payout"] == ACCOUNT


def test_rejecting_the_first_requested_account_keeps_the_state_none(db):
    db.docs[f"coachPrivate/{UID}"] = {"fullName": "Mona Hassan Ali", "payoutState": "none"}
    request_change(db, ACCOUNT)
    assert confirm(db, "reject") == {"state": "none"}


def test_a_payout_change_needs_the_payments_switch(db):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: request_change(db, ACCOUNT, live=False))[1] == errors.COACH_APP_CLOSED
    assert db.docs == before
