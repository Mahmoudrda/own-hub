"""Packages: bounds, the coach's price staying private, and the recompute of
her page's from-price and published flag."""

from __future__ import annotations

import copy
import datetime as dt
import json
import os

import pytest

from coaching import errors, packages
from tests import fake_firestore
from tests.coaching_helpers import _txn, refusal  # noqa: F401

NOW = dt.datetime(2026, 10, 20, 12, tzinfo=dt.timezone.utc)
UID = "coach-1"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
with open(os.path.join(ROOT, "contracts", "coaching_price_vectors.json"), encoding="utf-8") as handle:
    VECTORS = json.load(handle)


@pytest.fixture
def db(monkeypatch):
    fs = fake_firestore.FakeFirestore()
    fs.docs[f"coaches/{UID}"] = {"displayName": "Mona", "published": False, "fromPriceEgp": None}
    fs.docs[f"coachPrivate/{UID}"] = {"payoutState": "confirmed"}
    return fs


def body(**overrides):
    data = {
        "title": "Twelve week reset",
        "description": "Weekly plan, two live sessions a month and daily support.",
        "durationDays": 84,
        "includes": ["Workout plan", "Meal plan"],
        "liveSessionsPerMonth": 2,
        "sessionMinutes": 45,
        "checkInsPerWeek": 2,
        "coachPriceEgp": 1000,
        "active": True,
        "order": 0,
    }
    data.update(overrides)
    return data


def save(db, data, *, live=True, coach_v="active"):
    return packages.save(db, UID, data, live=live, coach_v=coach_v, now=NOW)


def stored_packages(db):
    return {p: d for p, d in db.docs.items() if p.startswith(f"coaches/{UID}/packages/")}


def test_a_new_package(db):
    out = save(db, body())
    assert out["priceFinalEgp"] == 1150 and out["youReceiveEgp"] == 1000
    public = db.docs[f"coaches/{UID}/packages/{out['packageId']}"]
    assert set(public) == set(packages.PACKAGE_KEYS)
    assert public["priceFinalEgp"] == 1150 and public["updatedAt"] == NOW
    assert public["liveSessionsPerMonth"] == 2 and public["includes"] == ["Workout plan", "Meal plan"]
    private = db.docs[f"coachPrivate/{UID}/prices/{out['packageId']}"]
    assert private == {"coachPriceEgp": 1000, "priceFinalEgp": 1150, "updatedAt": NOW}


def test_nothing_client_visible_holds_the_coach_price(db):
    save(db, body(coachPriceEgp=1234))
    for path, doc in db.docs.items():
        if path.startswith("coaches/"):
            assert "coachPrice" not in repr(doc) and "1234" not in repr(doc)


@pytest.mark.parametrize("row", VECTORS["vectors"], ids=lambda r: str(r["coach"]))
def test_every_price_vector(db, row):
    out = save(db, body(coachPriceEgp=row["coach"]))
    assert out["priceFinalEgp"] == row["final"] and out["youReceiveEgp"] == row["coach"]


@pytest.mark.parametrize("value", VECTORS["refused"] + [None, "500", 500.0, True, 199.5])
def test_every_refused_price(db, value):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: save(db, body(coachPriceEgp=value))) == (errors.INVALID, errors.PRICE_OUT_OF_RANGE)
    assert db.docs == before


BAD = {
    "short title": dict(title="ab"),
    "long title": dict(title="t" * 61),
    "short description": dict(description="too short"),
    "long description": dict(description="d" * 601),
    "duration": dict(durationDays=30),
    "no includes": dict(includes=[]),
    "nine includes": dict(includes=["item one"] * 9),
    "short include": dict(includes=["a"]),
    "long include": dict(includes=["i" * 81]),
    "include not text": dict(includes=[5]),
    "one live session": dict(liveSessionsPerMonth=1),
    "thirteen live sessions": dict(liveSessionsPerMonth=13),
    "session minutes": dict(sessionMinutes=50),
    "check-ins eight": dict(checkInsPerWeek=8),
    "active as text": dict(active="yes"),
    "order 21": dict(order=21),
    "order negative": dict(order=-1),
    "package id": dict(packageId=7),
}


@pytest.mark.parametrize("name", sorted(BAD))
def test_bad_fields(db, name):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: save(db, body(**BAD[name])))[1] == errors.BAD_REQUEST
    assert db.docs == before


def test_bounds_are_accepted(db):
    save(db, body(coachPriceEgp=200, liveSessionsPerMonth=12, durationDays=28, sessionMinutes=30, checkInsPerWeek=0, order=20, title="abc", includes=["ab"] * 8))
    save(db, body(coachPriceEgp=30000))


def test_refusals_by_state(db):
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: save(db, body(), live=False))[1] == errors.COACH_APP_CLOSED
    assert refusal(lambda: save(db, body(), coach_v=None))[1] == errors.NOT_A_COACH
    assert refusal(lambda: save(db, body(), coach_v="suspended"))[1] == errors.COACH_SUSPENDED
    assert db.docs == before


def test_a_coach_page_must_exist(db):
    del db.docs[f"coaches/{UID}"]
    assert refusal(lambda: save(db, body()))[1] == errors.NOT_A_COACH
    assert db.docs == {f"coachPrivate/{UID}": {"payoutState": "confirmed"}}


def test_at_most_six_packages(db):
    for i in range(6):
        save(db, body(title=f"Package {i}"))
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: save(db, body(title="Seventh"))) == (errors.EXHAUSTED, errors.TOO_MANY_PACKAGES)
    assert db.docs == before
    first = sorted(stored_packages(db))[0].rsplit("/", 1)[-1]
    assert save(db, body(packageId=first, title="Edited"))["packageId"] == first


def test_editing_updates_in_place(db):
    pid = save(db, body())["packageId"]
    out = save(db, body(packageId=pid, coachPriceEgp=2000, title="Edited"))
    assert out["packageId"] == pid and out["priceFinalEgp"] == 2300
    assert len(stored_packages(db)) == 1
    assert db.docs[f"coaches/{UID}/packages/{pid}"]["title"] == "Edited"
    assert db.docs[f"coachPrivate/{UID}/prices/{pid}"]["coachPriceEgp"] == 2000


def test_a_package_that_is_not_hers_is_refused(db):
    db.docs["coaches/other/packages/p1"] = {"title": "Theirs", "active": True, "priceFinalEgp": 300}
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: save(db, body(packageId="p1"))) == (errors.NOT_FOUND, errors.PACKAGE_NOT_FOUND)
    assert refusal(lambda: save(db, body(packageId="never-saved")))[1] == errors.PACKAGE_NOT_FOUND
    assert db.docs == before


def test_published_and_from_price_follow_the_active_packages(db):
    coach = lambda: db.docs[f"coaches/{UID}"]
    cheap = save(db, body(title="Cheap one", coachPriceEgp=500, active=False))["packageId"]
    assert coach()["published"] is False and coach()["fromPriceEgp"] is None

    dear = save(db, body(title="Dear one", coachPriceEgp=2000))["packageId"]
    assert coach()["published"] is True and coach()["fromPriceEgp"] == 2300

    save(db, body(packageId=cheap, title="Cheap one", coachPriceEgp=500, active=True))
    assert coach()["fromPriceEgp"] == 575

    save(db, body(packageId=cheap, title="Cheap one", coachPriceEgp=500, active=False))
    assert coach()["fromPriceEgp"] == 2300 and coach()["published"] is True

    save(db, body(packageId=dear, title="Dear one", coachPriceEgp=2000, active=False))
    assert coach()["published"] is False and coach()["fromPriceEgp"] is None
    assert coach()["displayName"] == "Mona" and coach()["updatedAt"] == NOW
    assert coach()["fromMonthlyEgp"] is None


def test_from_monthly_is_the_lowest_28_day_equivalent_of_the_active_packages(db):
    coach = lambda: db.docs[f"coaches/{UID}"]
    # 2300 over 84 days is 766 a month; 1150 over 28 days is 1150: the longer one is cheaper per month
    save(db, body(title="Long one", coachPriceEgp=2000, durationDays=84))
    save(db, body(title="Short one", coachPriceEgp=1000, durationDays=28))
    assert coach()["fromPriceEgp"] == 1150 and coach()["fromMonthlyEgp"] == 766
    off = save(db, body(title="Tiny one", coachPriceEgp=500, durationDays=56, active=False))["packageId"]
    assert coach()["fromMonthlyEgp"] == 766
    save(db, body(packageId=off, title="Tiny one", coachPriceEgp=500, durationDays=56, active=True))
    assert coach()["fromMonthlyEgp"] == 575 * 28 // 56


def test_a_suspended_coach_with_a_valid_claim_cannot_save_or_publish(db):
    db.docs[f"coachPrivate/{UID}"]["suspended"] = True
    db.docs[f"coaches/{UID}"].update(published=False, acceptingClients=False)
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: save(db, body()))[1] == errors.COACH_SUSPENDED
    assert db.docs == before and stored_packages(db) == {}


def test_a_suspension_that_lands_during_the_save_still_publishes_nothing(db, monkeypatch):
    real = packages.common.require_active_coach

    def late(db_, uid, coach_v):
        row = real(db_, uid, coach_v)
        db_.docs[f"coachPrivate/{UID}"]["suspended"] = True
        return row

    monkeypatch.setattr(packages.common, "require_active_coach", late)
    assert refusal(lambda: save(db, body()))[1] == errors.COACH_SUSPENDED
    assert db.docs[f"coaches/{UID}"]["published"] is False and stored_packages(db) == {}
