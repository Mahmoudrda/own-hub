"""What coaches are owed and the payouts staff record."""

from __future__ import annotations

import pytest

from coaching import errors, payouts
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    COACH,
    NOW,
    STAFF,
    db,
    later,
    pushes,
    refuse,
    seed,
)


def line(db, sub_id, amount, status="eligible", coach=COACH):
    db.document(f"coachPrivate/{coach}/ledger/{sub_id}").set(
        {"subId": sub_id, "coachAmountEgp": amount, "status": status, "eligibleAt": NOW, "createdAt": NOW}
    )


def pay(db, pushes, ids, **over):
    data = {"coachUid": COACH, "entryIds": ids, "rail": "instapay", "reference": "PAYOUT-0001", "paidAt": "2026-10-06"}
    data.update(over)
    return payouts.record(db, STAFF, data, now=NOW, notify=pushes)


def test_owed_adds_up_eligible_lines_per_coach(db):
    seed(db)
    line(db, "s1", 1000)
    line(db, "s2", 500)
    line(db, "s3", 700, status="pending")
    line(db, "s4", 300, status="paid")
    line(db, "s5", 200, status="reversed")
    db.document("coaches/coach-2").set({"displayName": "Coach Two"})
    db.document("coachPrivate/coach-2").set({"payoutState": "pending", "payout": {"account": "secret"}})
    line(db, "s6", 90, coach="coach-2")
    out = payouts.owed(db, STAFF, {}, now=NOW)["coaches"]
    assert [c["coachUid"] for c in out] == ["coach-2", COACH]
    second, first = out
    assert first["amountEgp"] == 1500 and first["entryIds"] == ["s1", "s2"] and first["displayName"] == "Coach One"
    assert first["payoutState"] == "confirmed" and first["account"]["account"] == "coach@instapay"
    assert second["amountEgp"] == 90 and second["payoutState"] == "pending" and second["account"] is None
    assert any(r.to_dict()["action"] == "coaching.payouts.owed" for r in db.collection("adminAccessLog").stream())


def test_owed_is_empty_when_nothing_is_eligible(db):
    seed(db)
    line(db, "s1", 100, status="pending")
    assert payouts.owed(db, STAFF, {}, now=NOW) == {"coaches": []}


def test_a_coach_with_an_account_waiting_is_listed_even_when_nothing_is_owed(db):
    seed(db)
    db.document("coaches/coach-3").set({"displayName": "Coach Three"})
    db.document("coachPrivate/coach-3").set({
        "fullName": "Mona  Adel",
        "payoutState": "pending",
        "payout": {"rail": "instapay", "account": "mona.adel@instapay", "holderName": "mona adel"},
    })
    out = {c["coachUid"]: c for c in payouts.owed(db, STAFF, {}, now=NOW)["coaches"]}
    three = out["coach-3"]
    assert three["amountEgp"] == 0 and three["entryIds"] == [] and three["account"] is None
    assert three["pendingPayout"] == {"rail": "instapay", "account": "mona.adel@instapay", "holderName": "mona adel"}
    assert three["payoutNameMatches"] is True


def test_a_requested_change_shows_with_its_name_check(db):
    seed(db)
    db.document("coaches/coach-4").set({"displayName": "Coach Four"})
    db.document("coachPrivate/coach-4").set({
        "fullName": "Sara Ali",
        "payoutState": "confirmed",
        "payout": {"rail": "instapay", "account": "sara@instapay", "holderName": "Sara Ali"},
        "pendingPayout": {"rail": "vodafoneCash", "account": "01012345678", "holderName": "Someone Else", "requestedAt": NOW},
    })
    four = {c["coachUid"]: c for c in payouts.owed(db, STAFF, {}, now=NOW)["coaches"]}["coach-4"]
    assert four["account"]["account"] == "sara@instapay"
    assert four["pendingPayout"]["account"] == "01012345678"
    assert four["payoutNameMatches"] is False


def test_a_payout_sums_marks_paid_and_moves_the_balance(db, pushes):
    seed(db)
    db.document(f"coachPrivate/{COACH}").update({"owedEgp": 1500})
    line(db, "s1", 1000)
    line(db, "s2", 500)
    line(db, "s3", 700, status="pending")
    out = pay(db, pushes, ["s1", "s2"])
    assert out["amountEgp"] == 1500
    payout = db.document(f"coachPrivate/{COACH}/payouts/{out['payoutId']}").get().to_dict()
    assert payout["amountEgp"] == 1500 and payout["entryIds"] == ["s1", "s2"]
    assert payout["rail"] == "instapay" and payout["reference"] == "PAYOUT-0001" and payout["paidAt"] == "2026-10-06"
    assert payout["recordedBy"] and payout["recordedBy"] != STAFF
    for sub_id in ("s1", "s2"):
        entry = db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()
        assert entry["status"] == "paid" and entry["payoutId"] == out["payoutId"]
    assert db.document(f"coachPrivate/{COACH}/ledger/s3").get().to_dict()["status"] == "pending"
    private = db.document(f"coachPrivate/{COACH}").get().to_dict()
    assert private["owedEgp"] == 0 and private["paidEgp"] == 1500
    assert pushes == [(COACH, "payoutRecorded")]
    assert payouts.owed(db, STAFF, {}, now=NOW) == {"coaches": []}


def test_a_line_cannot_be_paid_twice(db, pushes):
    seed(db)
    line(db, "s1", 1000)
    pay(db, pushes, ["s1"])
    refuse(lambda: pay(db, pushes, ["s1"]), errors.PRECONDITION, errors.WRONG_STATUS)


@pytest.mark.parametrize("status", ["pending", "paid", "reversed"])
def test_only_eligible_lines_can_be_paid(db, pushes, status):
    seed(db)
    line(db, "s1", 1000)
    line(db, "s2", 500, status=status)
    refuse(lambda: pay(db, pushes, ["s1", "s2"]), errors.PRECONDITION, errors.WRONG_STATUS)
    assert db.document(f"coachPrivate/{COACH}/ledger/s1").get().to_dict()["status"] == "eligible"


def test_another_coachs_line_or_a_missing_one_is_refused(db, pushes):
    seed(db)
    line(db, "s1", 1000)
    line(db, "other", 50, coach="coach-2")
    refuse(lambda: pay(db, pushes, ["s1", "other"]), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: pay(db, pushes, ["nope"]), errors.PRECONDITION, errors.WRONG_STATUS)
    assert pushes == []


def test_nothing_owed(db, pushes):
    seed(db)
    refuse(lambda: pay(db, pushes, []), errors.PRECONDITION, errors.NOTHING_OWED)
    line(db, "zero", 0)
    refuse(lambda: pay(db, pushes, ["zero"]), errors.PRECONDITION, errors.NOTHING_OWED)


@pytest.mark.parametrize("state", ["pending", "rejected", None])
def test_the_account_must_be_confirmed(db, pushes, state):
    seed(db)
    line(db, "s1", 1000)
    db.document(f"coachPrivate/{COACH}").update({"payoutState": state})
    refuse(lambda: pay(db, pushes, ["s1"]), errors.PRECONDITION, errors.PAYOUT_ACCOUNT_PENDING)
    assert db.document(f"coachPrivate/{COACH}/ledger/s1").get().to_dict()["status"] == "eligible"


@pytest.mark.parametrize(
    "over",
    [
        {"rail": "paypal"},
        {"reference": "x"},
        {"paidAt": "yesterday"},
        {"paidAt": "2026-10-09"},
        {"entryIds": "s1"},
        {"entryIds": ["s1", "s1"]},
        {"entryIds": [1]},
        {"coachUid": ""},
    ],
)
def test_bad_input_is_refused(db, pushes, over):
    seed(db)
    line(db, "s1", 1000)
    ids = over.pop("entryIds", ["s1"])
    refuse(lambda: pay(db, pushes, ids, **over), errors.INVALID, errors.BAD_REQUEST)
    assert db.document(f"coachPrivate/{COACH}/ledger/s1").get().to_dict()["status"] == "eligible"


def test_staff_never_record_a_payout_to_themselves(db, pushes):
    seed(db)
    line(db, "s1", 1000)
    before = {k: dict(v) for k, v in db.docs.items()}
    with pytest.raises(errors.CoachingError) as caught:
        payouts.record(db, COACH, {"coachUid": COACH, "entryIds": ["s1"], "rail": "instapay",
                                   "reference": "PAYOUT-0001", "paidAt": "2026-10-06"}, now=NOW, notify=pushes)
    assert (caught.value.code, caught.value.reason) == (errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert {k: dict(v) for k, v in db.docs.items()} == before and pushes == []


def test_the_payout_goes_by_the_rail_of_the_confirmed_account(db, pushes):
    seed(db)
    line(db, "s1", 1000)
    refuse(lambda: pay(db, pushes, ["s1"], rail="vodafoneCash", reference="01012345678"),
           errors.INVALID, errors.BAD_REQUEST)
    assert db.document(f"coachPrivate/{COACH}/ledger/s1").get().to_dict()["status"] == "eligible"
    assert pay(db, pushes, ["s1"])["amountEgp"] == 1000
