"""Requests, answers, cancelling, ending early: the front half of a
subscription's life. The helpers at the top are shared by the other
test_coaching_* files of this package."""

from __future__ import annotations

import copy
import datetime as dt
import itertools
import json

import cv2
import numpy as np
import pytest

from coaching import common, errors, subscriptions
from tests import fake_firestore
from tests.coaching_helpers import Pushes, _txn  # noqa: F401
from tests.fake_blobs import FakeBlobs

NOW = dt.datetime(2026, 10, 6, 12, tzinfo=dt.timezone.utc)
CLIENT = "client-uid-1"
COACH = "coach-uid-1"
STAFF = "finance-uid-1"
COACH_PRICE = 1000
FINAL = 1150
PACKAGE = "pkg1"
CODE = "OHABC234"
PNG = b"raw-upload"


def codes():
    """A payment code source: CODE first, then codes no other one repeats."""
    yield CODE
    for n in itertools.count():
        yield f"OHZ{n:05d}"


@pytest.fixture
def db():
    return fake_firestore.FakeFirestore()


@pytest.fixture
def pushes():
    return Pushes()


@pytest.fixture
def blobs():
    return FakeBlobs()


def later(**kw):
    return NOW + dt.timedelta(**kw)


def seed(db, *, auto=True, active=0, cap=15, published=True, accepting=True, accounts=True, seller=True):
    db.document(f"coaches/{COACH}").set(
        {
            "displayName": "Coach One",
            "published": published,
            "acceptingClients": accepting,
            "autoAccept": auto,
            "maxActiveClients": cap,
            "activeClients": active,
            "stats": {"clientsCoached": 0, "plansShared": 0, "sessionsDone": 0},
        }
    )
    db.document(f"coaches/{COACH}/packages/{PACKAGE}").set(
        {
            "title": "Strong in 4 weeks",
            "description": "Plan and calls",
            "durationDays": 28,
            "includes": ["Plan", "Chat"],
            "liveSessionsPerMonth": 4,
            "sessionMinutes": 45,
            "checkInsPerWeek": 2,
            "priceFinalEgp": FINAL,
            "active": True,
            "order": 0,
        }
    )
    db.document(f"coachPrivate/{COACH}/prices/{PACKAGE}").set(
        {"coachPriceEgp": COACH_PRICE, "priceFinalEgp": FINAL}
    )
    db.document(f"coachPrivate/{COACH}").set(
        {
            "payoutState": "confirmed",
            "payout": {"rail": "instapay", "account": "coach@instapay", "holderName": "Coach One"},
            "owedEgp": 0,
            "paidEgp": 0,
        }
    )
    if accounts:
        db.document("coachingConfig/receivingAccounts").set(
            {
                "instapay": {"address": "ownhub@instapay", "holderName": "Own Hub", "enabled": True},
                "vodafoneCash": {"address": "01012345678", "holderName": "Own Hub", "enabled": False},
                "version": 3,
            }
        )
    if seller:
        db.document("coachingConfig/seller").set(
            {
                "companyNameEn": "Own Hub LLC",
                "companyNameAr": "اون هب",
                "addressEn": "1 Street, Cairo",
                "addressAr": "شارع 1 القاهرة",
                "commercialRegistration": "CR-1",
                "taxCard": "TC-1",
                "vatRatePercent": 14,
                "supportEmail": "help@ownhub.app",
                "supportPhone": "",
            }
        )


def intake(**over):
    row = {
        "goal": "stronger",
        "level": "beginner",
        "daysPerWeek": 3,
        "place": "home",
        "allergies": ["peanut"],
        "lifeStage": "none",
        "health": {key: False for key in common.ENUMS["healthQuestions"]},
        "doctorAck": False,
        "note": "hello",
    }
    row.update(over)
    return row


def hash_of(locale, part, name="Coach One"):
    return common.sha(common.CONTRACT["consentTexts"]["coachingRequest2"][locale][part][0].replace("{name}", name))


def consent(locale="en", name="Coach One", **over):
    row = {"version": 2, "shareHash": hash_of(locale, "share", name), "transferHash": hash_of(locale, "transfer"), "appVersion": "1.1.0+5"}
    row.update(over)
    return row


def ask(db, pushes, *, uid=CLIENT, now=NOW, **over):
    data = {"coachUid": COACH, "packageId": PACKAGE, "intake": intake(), "locale": "en"}
    locale = over.get("locale", "en")
    data["consent"] = consent(locale if locale in ("en", "ar") else "en")
    data.update(over)
    source = codes()
    return subscriptions.request(
        db, uid, data, live=True, payments_live=True, verified=True, now=now, notify=pushes, code=lambda: next(source)
    )


def refuse(call, code, reason):
    with pytest.raises(errors.CoachingError) as caught:
        call()
    assert (caught.value.code, caught.value.reason) == (code, reason)


def make_jpeg(seed_value: int, noise: int = 0) -> bytes:
    rng = np.random.default_rng(seed_value)
    base = rng.integers(0, 255, (8, 9), dtype=np.uint8)
    image = cv2.resize(base, (180, 160), interpolation=cv2.INTER_NEAREST)
    if noise:
        image = np.clip(image.astype(int) + np.random.default_rng(99).integers(-noise, noise + 1, image.shape), 0, 255).astype(np.uint8)
    ok, out = cv2.imencode(".jpg", image)
    assert ok
    return out.tobytes()


def keep(raw, long_side=None):
    return raw


def awaiting(db, pushes, **over):
    """A subscription waiting for her payment (coach auto-accepts)."""
    seed(db)
    return ask(db, pushes, **over)["subId"]


def send_proof(db, blobs, sub_id, *, uid=CLIENT, now=NOW, image=None, **over):
    from coaching import proofs

    data = {
        "subId": sub_id,
        "rail": "instapay",
        "reference": "REF123456",
        "amountEgp": FINAL,
        "paidAt": "2026-10-06",
        "senderName": "Client Name",
        "locale": "en",
    }
    data.update(over)
    return proofs.submit(
        db, uid, data, image if image is not None else make_jpeg(1), live=True, now=now, blobs=blobs, reencode=keep
    )


def approve(db, blobs, pushes, proof_id, *, now=NOW):
    from coaching import proofs

    return proofs.decide(
        db, STAFF, {"proofId": proof_id, "decision": "approve"}, now=now, blobs=blobs, notify=pushes
    )


def active(db, pushes, blobs, *, now=NOW):
    """A started subscription; returns its id."""
    sub_id = awaiting(db, pushes)
    proof = send_proof(db, blobs, sub_id, now=now)
    approve(db, blobs, pushes, proof["proofId"], now=now)
    return sub_id


def sub_of(db, sub_id):
    return db.document(f"subscriptions/{sub_id}").get().to_dict()


def deep_values(value):
    if isinstance(value, dict):
        for item in value.values():
            yield from deep_values(item)
    elif isinstance(value, list):
        for item in value:
            yield from deep_values(item)
    else:
        yield value


# -- request -----------------------------------------------------------------


def test_request_waits_for_the_coach_when_auto_accept_is_off(db, pushes):
    seed(db, auto=False)
    out = ask(db, pushes)
    assert out["status"] == "requested"
    sub = sub_of(db, out["subId"])
    assert sub["coachUid"] == COACH and sub["clientUid"] == CLIENT
    assert sub["relId"] == f"{COACH}__{CLIENT}"
    assert sub["priceFinalEgp"] == FINAL
    assert sub["sessionsIncluded"] == 4 and sub["sessionsUsed"] == 0
    assert sub["package"]["title"] == "Strong in 4 weeks"
    assert set(sub["package"]) == set(common.CONTRACT["documents"]["subscription"]["packageSnapshot"])
    assert "payTo" not in sub and "paymentCode" not in sub
    assert sub["intake"]["goal"] == "stronger" and sub["intake"]["health"]["heart"] is False
    assert pushes == [(COACH, "coachingRequest")]


def test_request_creates_relationship_terms_and_consents(db, pushes):
    seed(db, auto=False)
    out = ask(db, pushes, locale="ar", consent=consent("ar"))
    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["status"] == "none" and rel["chatOpen"] is False
    assert rel["coachUid"] == COACH and rel["clientUid"] == CLIENT
    terms = db.document(f"subscriptions/{out['subId']}/private/terms").get().to_dict()
    assert terms["coachPriceEgp"] == COACH_PRICE and terms["packageId"] == PACKAGE
    record = db.document(f"users/{CLIENT}/consents/coaching-request-v2-{out['subId']}").get().to_dict()
    assert record == {
        "version": 2, "shareHash": hash_of("ar", "share"), "transferHash": hash_of("ar", "transfer"),
        "appVersion": "1.1.0+5",
        "at": NOW, "locale": "ar", "coachUid": COACH, "subId": out["subId"],
    }


def test_each_request_keeps_its_own_consent_record(db, pushes):
    seed(db, auto=False)
    first = ask(db, pushes, locale="ar", consent=consent("ar"))
    db.document(f"subscriptions/{first['subId']}").update({"status": "declined"})
    db.document(f"relationships/{COACH}__{CLIENT}").update({"status": "ended"})
    second = ask(db, pushes, now=later(days=1), locale="en")
    one = db.document(f"users/{CLIENT}/consents/coaching-request-v2-{first['subId']}").get().to_dict()
    two = db.document(f"users/{CLIENT}/consents/coaching-request-v2-{second['subId']}").get().to_dict()
    assert one["locale"] == "ar" and two["locale"] == "en" and two["at"] == later(days=1)
    assert db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()["status"] == "ended"


@pytest.mark.parametrize(
    "bad",
    [
        "yes",
        {},
        consent(version=1),
        consent(version=True),
        consent(shareHash="x"),
        consent(transferHash="Z" * 64),
        consent(appVersion="v" * 33),
        consent(shareHash="a" * 64),
        consent(transferHash="b" * 64),
        consent("ar"),
        {k: v for k, v in consent().items() if k != "shareHash"},
    ],
)
def test_a_request_without_both_ticks_recorded_is_refused_and_writes_nothing(db, pushes, bad):
    seed(db, auto=False)
    refuse(lambda: ask(db, pushes, consent=bad), errors.INVALID, errors.BAD_REQUEST)
    assert list(db.collection("subscriptions").stream()) == []
    assert list(db.collection(f"users/{CLIENT}/consents").stream()) == []
    assert pushes == []


def test_the_coach_price_never_reaches_a_client_readable_document(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    for path, doc in db.docs.items():
        private = path.startswith("coachPrivate/") or "/private/" in path
        if private:
            continue
        assert COACH_PRICE not in list(deep_values(doc)), path
        assert "coachPriceEgp" not in json.dumps(doc, default=str), path
    assert db.document(f"subscriptions/{sub_id}/private/terms").get().to_dict()["coachPriceEgp"] == COACH_PRICE


def test_auto_accept_goes_straight_to_payment(db, pushes):
    seed(db, auto=True)
    out = ask(db, pushes)
    assert out["status"] == "awaiting_payment"
    sub = sub_of(db, out["subId"])
    assert sub["acceptedAt"] == NOW and sub["statusAt"] == NOW
    assert sub["paymentCode"] == CODE
    assert sub["payBy"] == NOW + dt.timedelta(hours=72)
    assert set(sub["payTo"]) == {"instapay", "version"}
    assert sub["payTo"]["instapay"]["address"] == "ownhub@instapay" and sub["payTo"]["version"] == 3
    assert sub["payment"] == {"state": "awaiting", "attempts": 0, "lastReason": None, "proofId": None}


def test_a_health_yes_always_waits_for_the_coach(db, pushes):
    seed(db, auto=True)
    health = {key: False for key in common.ENUMS["healthQuestions"]} | {"heart": True}
    out = ask(db, pushes, intake=intake(health=health, doctorAck=True))
    assert out["status"] == "requested"
    assert sub_of(db, out["subId"])["intake"]["doctorAck"] is True


@pytest.mark.parametrize("flag", ["published", "accepting"])
def test_coach_off_the_shelf_is_unavailable(db, pushes, flag):
    seed(db, **{flag: False})
    refuse(lambda: ask(db, pushes), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


def test_a_full_coach_is_unavailable(db, pushes):
    seed(db, active=3, cap=3)
    refuse(lambda: ask(db, pushes), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


def test_a_missing_coach_is_unavailable(db, pushes):
    seed(db)
    refuse(lambda: ask(db, pushes, coachUid="nobody"), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


def test_requesting_herself_is_unavailable(db, pushes):
    seed(db)
    refuse(lambda: ask(db, pushes, uid=COACH), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


@pytest.mark.parametrize("blocker,blocked", [(COACH, CLIENT), (CLIENT, COACH)])
def test_a_block_either_way_looks_like_unavailable(db, pushes, blocker, blocked):
    seed(db)
    db.document(f"users/{blocker}/blocks/{blocked}").set({"createdAt": NOW})
    refuse(lambda: ask(db, pushes), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


def test_package_missing_or_inactive_is_not_found(db, pushes):
    seed(db)
    refuse(lambda: ask(db, pushes, packageId="nope"), errors.NOT_FOUND, errors.PACKAGE_NOT_FOUND)
    db.document(f"coaches/{COACH}/packages/{PACKAGE}").update({"active": False})
    refuse(lambda: ask(db, pushes), errors.NOT_FOUND, errors.PACKAGE_NOT_FOUND)


@pytest.mark.parametrize("status", ["requested", "awaiting_payment", "payment_review", "active"])
def test_an_open_subscription_blocks_another(db, pushes, status):
    seed(db)
    first = ask(db, pushes)
    db.document(f"subscriptions/{first['subId']}").update({"status": status})
    refuse(lambda: ask(db, pushes), errors.PRECONDITION, errors.ALREADY_REQUESTED)


@pytest.mark.parametrize("status", ["declined", "cancelled", "expired", "payment_failed", "ended", "ended_early"])
def test_a_closed_subscription_does_not(db, pushes, status):
    seed(db)
    first = ask(db, pushes)
    db.document(f"subscriptions/{first['subId']}").update({"status": status})
    assert ask(db, pushes)["subId"] != first["subId"]


def test_no_receiving_account_stops_a_request(db, pushes):
    seed(db, accounts=False)
    refuse(lambda: ask(db, pushes), errors.PRECONDITION, errors.ACCOUNTS_NOT_SET)
    seed(db)
    db.document("coachingConfig/receivingAccounts").update(
        {"instapay.enabled": False, "vodafoneCash.enabled": False}
    )
    refuse(lambda: ask(db, pushes), errors.PRECONDITION, errors.ACCOUNTS_NOT_SET)


def test_closed_app_and_unverified_are_refused(db, pushes):
    seed(db)
    data = {"coachUid": COACH, "packageId": PACKAGE, "intake": intake(), "locale": "en"}
    refuse(
        lambda: subscriptions.request(db, CLIENT, data, live=False, verified=True, now=NOW, notify=pushes),
        errors.PRECONDITION,
        errors.COACH_APP_CLOSED,
    )
    refuse(
        lambda: subscriptions.request(db, CLIENT, data, live=True, payments_live=True, verified=False, now=NOW, notify=pushes),
        errors.PERMISSION,
        errors.NOT_VERIFIED,
    )


def _health(**yes):
    return {key: yes.get(key, False) for key in common.ENUMS["healthQuestions"]}


BAD_INTAKES = [
    {"goal": "fly"},
    {"level": "god"},
    {"daysPerWeek": 0},
    {"daysPerWeek": 8},
    {"daysPerWeek": True},
    {"place": "moon"},
    {"allergies": ["x"] * 17},
    {"allergies": ["a" * 31]},
    {"allergies": [""]},
    {"allergies": "peanut"},
    {"lifeStage": ""},
    {"lifeStage": "x" * 31},
    {"health": {"heart": False}},
    {"health": {**_health(), "extra": False}},
    {"health": {**_health(), "heart": "no"}},
    {"health": _health(heart=True), "doctorAck": False},
    {"doctorAck": "yes"},
    {"note": "x" * 501},
    {"note": 5},
]


@pytest.mark.parametrize("override", BAD_INTAKES)
def test_a_bad_intake_is_refused_and_writes_nothing(db, pushes, override):
    seed(db)
    before = copy.deepcopy(db.docs)
    refuse(lambda: ask(db, pushes, intake=intake(**override)), errors.INVALID, errors.BAD_REQUEST)
    assert db.docs == before and pushes == []


@pytest.mark.parametrize("over", [{"coachUid": ""}, {"packageId": 5}, {"locale": "fr"}, {"intake": "x"}])
def test_bad_request_fields_are_refused(db, pushes, over):
    seed(db)
    refuse(lambda: ask(db, pushes, **over), errors.INVALID, errors.BAD_REQUEST)


def test_a_refusal_writes_nothing(db, pushes):
    seed(db, published=False)
    before = copy.deepcopy(db.docs)
    with pytest.raises(errors.CoachingError):
        ask(db, pushes)
    assert db.docs == before


# -- respond ------------------------------------------------------------------


def answer(db, pushes, sub_id, *, uid=COACH, coach_v="active", now=NOW, **over):
    data = {"subId": sub_id, "decision": "accept"}
    data.update(over)
    source = codes()
    return subscriptions.respond(
        db, uid, data, live=True, payments_live=True, coach_v=coach_v, now=now, notify=pushes, code=lambda: next(source)
    )


def test_the_coach_accepts(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    pushes.clear()
    assert answer(db, pushes, sub_id, now=later(hours=5)) == {"status": "awaiting_payment"}
    sub = sub_of(db, sub_id)
    assert sub["acceptedAt"] == later(hours=5) and sub["payBy"] == later(hours=5 + 72)
    assert sub["paymentCode"] == CODE and "instapay" in sub["payTo"] and "vodafoneCash" not in sub["payTo"]
    assert pushes == [(CLIENT, "requestAnswered")]


def test_the_coach_declines_with_a_reason(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    assert answer(db, pushes, sub_id, decision="decline", reason="not_a_fit") == {"status": "declined"}
    assert sub_of(db, sub_id)["declineReason"] == "not_a_fit"
    assert (CLIENT, "requestAnswered") in pushes


def test_decline_needs_a_known_reason(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    refuse(lambda: answer(db, pushes, sub_id, decision="decline"), errors.INVALID, errors.BAD_REQUEST)
    refuse(lambda: answer(db, pushes, sub_id, decision="decline", reason="rude"), errors.INVALID, errors.BAD_REQUEST)
    refuse(lambda: answer(db, pushes, sub_id, decision="maybe"), errors.INVALID, errors.BAD_REQUEST)
    assert sub_of(db, sub_id)["status"] == "requested"


def test_only_her_own_request_in_requested(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    db.document("coachPrivate/other-coach").set({"payoutState": "confirmed"})
    refuse(lambda: answer(db, pushes, sub_id, uid="other-coach"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(lambda: answer(db, pushes, "missing"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    answer(db, pushes, sub_id)
    refuse(lambda: answer(db, pushes, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)


def test_a_suspended_or_missing_coach_claim_is_refused(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    refuse(lambda: answer(db, pushes, sub_id, coach_v="suspended"), errors.PERMISSION, errors.COACH_SUSPENDED)
    refuse(lambda: answer(db, pushes, sub_id, coach_v=None), errors.PERMISSION, errors.NOT_A_COACH)


def test_accepting_needs_a_receiving_account(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    db.document("coachingConfig/receivingAccounts").delete()
    refuse(lambda: answer(db, pushes, sub_id), errors.PRECONDITION, errors.ACCOUNTS_NOT_SET)


# -- cancel ------------------------------------------------------------------


def cancel(db, sub_id, *, uid=CLIENT):
    return subscriptions.cancel_request(db, uid, {"subId": sub_id}, live=True, now=later(hours=1))


@pytest.mark.parametrize("auto", [False, True])
def test_the_client_cancels_before_paying(db, pushes, auto):
    seed(db, auto=auto)
    sub_id = ask(db, pushes)["subId"]
    assert cancel(db, sub_id) == {"status": "cancelled"}
    assert sub_of(db, sub_id)["status"] == "cancelled"


@pytest.mark.parametrize("status", ["payment_review", "active", "ended", "cancelled"])
def test_cancelling_later_is_refused(db, pushes, status):
    seed(db)
    sub_id = ask(db, pushes)["subId"]
    db.document(f"subscriptions/{sub_id}").update({"status": status})
    refuse(lambda: cancel(db, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)


def test_cancelling_someone_elses_is_not_found(db, pushes):
    seed(db)
    sub_id = ask(db, pushes)["subId"]
    refuse(lambda: cancel(db, sub_id, uid="stranger"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(
        lambda: subscriptions.cancel_request(db, CLIENT, {"subId": sub_id}, live=False, now=NOW),
        errors.PRECONDITION,
        errors.COACH_APP_CLOSED,
    )


# -- end early ---------------------------------------------------------------


def end(db, pushes, sub_id, **over):
    data = {"subId": sub_id, "reason": "dispute"}
    data.update(over)
    return subscriptions.end_early(db, STAFF, data, now=later(days=3), notify=pushes)


def test_staff_end_a_subscription_early(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    pushes.clear()
    assert end(db, pushes, sub_id) == {"status": "ended_early"}
    sub = sub_of(db, sub_id)
    assert sub["status"] == "ended_early" and sub["endReason"] == "dispute"
    rel = db.document(f"relationships/{COACH}__{CLIENT}").get().to_dict()
    assert rel["status"] == "ended" and rel["chatOpen"] is False
    assert db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()["status"] == "reversed"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0
    kinds = [m.to_dict().get("systemKind") for m in db.collection(f"relationships/{COACH}__{CLIENT}/messages").stream()]
    assert kinds.count("ended") == 1
    assert sorted(pushes) == sorted([(CLIENT, "coachingEnded"), (COACH, "coachingEnded")])
    assert any(row.to_dict()["action"] == "coaching.end" for row in db.collection("adminAccessLog").stream())


def test_ending_early_takes_back_what_was_owed(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").update({"status": "eligible"})
    db.document(f"coachPrivate/{COACH}").update({"owedEgp": COACH_PRICE})
    end(db, pushes, sub_id)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == 0


def test_a_paid_ledger_line_is_left_alone(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").update({"status": "paid"})
    end(db, pushes, sub_id)
    assert db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()["status"] == "paid"


def test_end_early_refusals(db, pushes, blobs):
    seed(db)
    sub_id = ask(db, pushes)["subId"]
    refuse(lambda: end(db, pushes, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)
    refuse(lambda: end(db, pushes, "missing"), errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    refuse(lambda: end(db, pushes, sub_id, reason="bored"), errors.INVALID, errors.BAD_REQUEST)
    refuse(lambda: end(db, pushes, sub_id, refundReference=5), errors.INVALID, errors.BAD_REQUEST)


# -- staff never decide their own case; ending early with a refund ------------------


def refund_end(db, pushes, sub_id, actor=STAFF, **over):
    data = {"subId": sub_id, "reason": "dispute", "rail": "instapay", "refundEgp": 575, "refundReference": "REFUND-0001"}
    data.update(over)
    return subscriptions.end_early(db, actor, data, now=later(days=3), notify=pushes)


@pytest.mark.parametrize("actor", [CLIENT, COACH])
def test_staff_never_end_their_own_subscription(db, pushes, blobs, actor):
    sub_id = active(db, pushes, blobs)
    before = sub_of(db, sub_id)
    refuse(lambda: subscriptions.end_early(db, actor, {"subId": sub_id, "reason": "dispute"}, now=later(days=3), notify=pushes),
           errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert sub_of(db, sub_id) == before


def test_ending_early_is_refused_while_a_cancellation_is_requested(db, pushes, blobs):
    from coaching import refunds

    sub_id = active(db, pushes, blobs)
    refunds.request(db, CLIENT, {"subId": sub_id}, live=True, now=later(days=1))
    refuse(lambda: end(db, pushes, sub_id), errors.PRECONDITION, errors.WRONG_STATUS)
    assert sub_of(db, sub_id)["status"] == "active"


def test_a_partial_refund_sets_the_coach_share_and_the_receipt(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").update({"status": "eligible"})
    db.document(f"coachPrivate/{COACH}").update({"owedEgp": COACH_PRICE})
    assert refund_end(db, pushes, sub_id) == {"status": "ended_early"}
    sub = sub_of(db, sub_id)
    assert sub["refund"] == {"amountEgp": 575, "rail": "instapay", "reference": "REFUND-0001", "at": later(days=3)}
    share = COACH_PRICE * (FINAL - 575) // FINAL
    ledger = db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()
    assert ledger["coachAmountEgp"] == share and ledger["status"] == "eligible" and ledger["eligibleAt"] == later(days=3)
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == share
    assert db.document(f"receipts/{sub_id}").get().to_dict()["refund"] == {"amountEgp": 575, "at": later(days=3)}


def test_a_pending_line_becomes_eligible_now_with_the_reduced_share(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    refund_end(db, pushes, sub_id)
    share = COACH_PRICE * (FINAL - 575) // FINAL
    ledger = db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()
    assert ledger["status"] == "eligible" and ledger["coachAmountEgp"] == share
    assert db.document(f"coachPrivate/{COACH}").get().to_dict()["owedEgp"] == share


def test_a_full_refund_reverses_the_coach_line(db, pushes, blobs):
    sub_id = active(db, pushes, blobs)
    refund_end(db, pushes, sub_id, refundEgp=FINAL)
    assert db.document(f"coachPrivate/{COACH}/ledger/{sub_id}").get().to_dict()["status"] == "reversed"
    assert db.document(f"coachPrivate/{COACH}").get().to_dict().get("owedEgp", 0) == 0


@pytest.mark.parametrize(
    "over",
    [
        {"rail": None}, {"refundEgp": None}, {"refundReference": None},
        {"refundEgp": FINAL + 1}, {"refundEgp": -1}, {"refundEgp": 5.5}, {"refundEgp": True},
        {"rail": "paypal"}, {"refundReference": "x"},
    ],
)
def test_a_refund_needs_the_rail_the_amount_and_the_reference_together(db, pushes, blobs, over):
    sub_id = active(db, pushes, blobs)
    before = sub_of(db, sub_id)
    refuse(lambda: refund_end(db, pushes, sub_id, **over), errors.INVALID, errors.BAD_REQUEST)
    assert sub_of(db, sub_id) == before


# -- capacity counts places that are taken, not only active clients -----------------


def test_auto_accept_stops_when_the_places_in_payment_are_full(db, pushes):
    seed(db, cap=2)
    first = ask(db, pushes, uid="c1")
    second = ask(db, pushes, uid="c2")
    third = ask(db, pushes, uid="c3")
    assert (first["status"], second["status"]) == ("awaiting_payment", "awaiting_payment")
    assert third["status"] == "requested"
    assert db.document(f"coaches/{COACH}").get().to_dict()["activeClients"] == 0


def test_accepting_by_hand_is_refused_when_the_places_are_full(db, pushes):
    seed(db, auto=False, cap=1)
    held = ask(db, pushes, uid="c1")["subId"]
    waiting = ask(db, pushes, uid="c2")["subId"]
    answer(db, pushes, held)
    refuse(lambda: answer(db, pushes, waiting), errors.PRECONDITION, errors.COACH_UNAVAILABLE)
    assert sub_of(db, waiting)["status"] == "requested"
    answer(db, pushes, waiting, decision="decline", reason=common.ENUMS["declineReasons"][0])
    assert sub_of(db, waiting)["status"] == "declined"


@pytest.mark.parametrize("status", ["awaiting_payment", "payment_review", "active"])
def test_each_holding_status_takes_a_place(db, pushes, status):
    seed(db, auto=False, cap=1)
    other = db.collection("subscriptions").document()
    other.set({"coachUid": COACH, "clientUid": "x", "status": status})
    waiting = ask(db, pushes, uid="c2")["subId"]
    refuse(lambda: answer(db, pushes, waiting), errors.PRECONDITION, errors.COACH_UNAVAILABLE)


def test_finished_and_declined_requests_free_their_place(db, pushes):
    seed(db, auto=False, cap=1)
    for status in ("ended", "declined", "cancelled", "expired", "ended_early", "payment_failed", "requested"):
        db.collection("subscriptions").document().set({"coachUid": COACH, "clientUid": "x", "status": status})
    waiting = ask(db, pushes, uid="c2")["subId"]
    assert answer(db, pushes, waiting) == {"status": "awaiting_payment"}


# -- payment codes are unique -----------------------------------------------------


def test_a_payment_code_another_subscription_has_is_not_reused(db, pushes):
    seed(db)
    first = ask(db, pushes, uid="c1")
    options = iter([CODE, CODE, "OHFRESH2"])
    second = subscriptions.request(
        db, "c2", {"coachUid": COACH, "packageId": PACKAGE, "intake": intake(), "consent": consent(), "locale": "en"},
        live=True, payments_live=True, verified=True, now=NOW, notify=pushes, code=lambda: next(options),
    )
    assert sub_of(db, first["subId"])["paymentCode"] == CODE
    assert sub_of(db, second["subId"])["paymentCode"] == "OHFRESH2"


def test_the_hand_accept_also_draws_a_fresh_code(db, pushes):
    seed(db, auto=False)
    taken = db.collection("subscriptions").document()
    taken.set({"coachUid": "other", "clientUid": "x", "status": "active", "paymentCode": CODE})
    sub_id = ask(db, pushes)["subId"]
    options = iter([CODE, "OHFRESH3"])
    subscriptions.respond(db, COACH, {"subId": sub_id, "decision": "accept"}, live=True, payments_live=True, coach_v="active",
                          now=NOW, notify=pushes, code=lambda: next(options))
    assert sub_of(db, sub_id)["paymentCode"] == "OHFRESH3"


def test_five_taken_codes_in_a_row_refuse_rather_than_loop(db, pushes):
    seed(db)
    ask(db, pushes, uid="c1")
    with pytest.raises(errors.CoachingError):
        subscriptions.request(
            db, "c2", {"coachUid": COACH, "packageId": PACKAGE, "intake": intake(), "locale": "en"},
            live=True, payments_live=True, verified=True, now=NOW, notify=pushes, code=lambda: CODE,
        )
    assert len(list(db.collection("subscriptions").stream())) == 1


# -- a suspended coach cannot answer requests even with a valid claim ----------------


def test_a_suspended_coach_cannot_answer_a_request_on_a_valid_claim(db, pushes):
    seed(db, auto=False)
    sub_id = ask(db, pushes)["subId"]
    db.document(f"coachPrivate/{COACH}").update({"suspended": True})
    refuse(lambda: answer(db, pushes, sub_id), errors.PERMISSION, errors.COACH_SUSPENDED)
    assert sub_of(db, sub_id)["status"] == "requested"


def test_the_app_1_0_0_request_has_no_consent_field_and_records_the_version_1_ticks(db, pushes):
    """The exact body 1.0.0 sends: coachUid, packageId, intake, locale, clientName."""
    seed(db, auto=False)
    body = {"coachUid": COACH, "packageId": PACKAGE, "intake": intake(), "locale": "ar", "clientName": "Mona"}
    source = codes()
    out = subscriptions.request(
        db, CLIENT, body, live=True, payments_live=True, verified=True, now=NOW, notify=pushes,
        code=lambda: next(source),
    )
    assert out["status"] == "requested"
    for name in ("coaching-share-v1", "transfer-abroad-v1"):
        assert db.document(f"users/{CLIENT}/consents/{name}").get().to_dict() == {"version": 1, "at": NOW, "locale": "ar"}
    assert db.document(f"users/{CLIENT}/consents/coaching-request-v2-{out['subId']}").get().to_dict() is None
