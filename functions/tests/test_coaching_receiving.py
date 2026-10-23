"""Receiving accounts, seller details and the receipt counter."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import common, errors, receiving, receipts
from tests.coaching_helpers import _txn  # noqa: F401
from tests.test_coaching_subscriptions import (  # noqa: F401
    FINAL,
    NOW,
    STAFF,
    db,
    refuse,
)

GOOD = {
    "instapay": {"address": "ownhub@instapay", "holderName": "Own Hub", "enabled": True},
    "vodafoneCash": {"address": "01012345678", "holderName": "Own Hub", "enabled": False},
}


def put(db, **over):
    data = {**GOOD, **over}
    return receiving.set_accounts(db, STAFF, data, now=NOW)


def test_nothing_is_set_at_first(db):
    assert receiving.get(db, STAFF, {}, now=NOW) == {
        "instapay": None, "vodafoneCash": None, "version": 0, "seller": None,
    }


def test_the_saved_seller_comes_back_for_the_settings_card(db):
    db.document("coachingConfig/seller").set({"companyNameEn": "Own Hub LLC", "taxCard": "123-456-789", "updatedAt": NOW})
    assert receiving.get(db, STAFF, {}, now=NOW)["seller"] == {"companyNameEn": "Own Hub LLC", "taxCard": "123-456-789"}


def test_setting_accounts_bumps_the_version(db):
    assert put(db) == {"version": 1}
    assert put(db) == {"version": 2}
    out = receiving.get(db, STAFF, {}, now=NOW)
    assert out["version"] == 2 and out["instapay"] == GOOD["instapay"] and out["vodafoneCash"]["enabled"] is False
    assert db.document("coachingConfig/receivingAccounts").get().to_dict()["updatedAt"] == NOW
    actions = {r.to_dict()["action"] for r in db.collection("adminAccessLog").stream()}
    assert {"coaching.receiving.get", "coaching.receiving.set"} <= actions


@pytest.mark.parametrize(
    "over",
    [
        {"instapay": {**GOOD["instapay"], "address": "no-suffix"}},
        {"instapay": {**GOOD["instapay"], "address": "ownhub@vodafone"}},
        {"vodafoneCash": {**GOOD["vodafoneCash"], "address": "0212345678"}},
        {"vodafoneCash": {**GOOD["vodafoneCash"], "address": "01112345678"}},
        {"instapay": {**GOOD["instapay"], "holderName": "ab"}},
        {"instapay": {**GOOD["instapay"], "holderName": "x" * 81}},
        {"instapay": {**GOOD["instapay"], "enabled": "yes"}},
        {"instapay": None},
        {"vodafoneCash": "01012345678"},
        {
            "instapay": {**GOOD["instapay"], "enabled": False},
            "vodafoneCash": {**GOOD["vodafoneCash"], "enabled": False},
        },
    ],
)
def test_bad_accounts_are_refused_and_nothing_changes(db, over):
    put(db)
    refuse(lambda: put(db, **over), errors.INVALID, errors.BAD_REQUEST)
    assert receiving.get(db, STAFF, {}, now=NOW)["version"] == 1


OFF = {"address": "", "holderName": "", "enabled": False}


def test_one_rail_can_be_saved_with_the_other_switched_off_and_empty(db):
    assert put(db, vodafoneCash=OFF) == {"version": 1}
    out = receiving.get(db, STAFF, {}, now=NOW)
    assert out["instapay"] == GOOD["instapay"] and out["vodafoneCash"] == OFF
    assert put(db, instapay=OFF, vodafoneCash={**GOOD["vodafoneCash"], "enabled": True}) == {"version": 2}


@pytest.mark.parametrize(
    "over",
    [
        {"instapay": OFF, "vodafoneCash": OFF},
        {"vodafoneCash": {**OFF, "enabled": True}},
        {"vodafoneCash": {**OFF, "address": "01012345678"}},
        {"vodafoneCash": {**OFF, "holderName": "Own Hub"}},
        {"vodafoneCash": {**OFF, "address": "12345"}},
        {"vodafoneCash": {"address": "", "holderName": ""}},
        {"vodafoneCash": {"address": None, "holderName": None, "enabled": False}},
    ],
)
def test_an_empty_rail_is_accepted_only_when_it_is_off_and_something_else_is_on(db, over):
    refuse(lambda: put(db, **over), errors.INVALID, errors.BAD_REQUEST)
    assert not db.document("coachingConfig/receivingAccounts").get().exists


def test_a_client_is_shown_only_the_rail_that_is_on(db):
    from coaching import subscriptions

    put(db, vodafoneCash=OFF)
    row = db.document("coachingConfig/receivingAccounts").get().to_dict()
    assert set(subscriptions.pay_to(row)) == {"instapay", "version"}


SELLER = {
    "companyNameEn": "Own Hub LLC",
    "companyNameAr": "اون هب",
    "addressEn": "1 Street, Cairo",
    "addressAr": "شارع 1 القاهرة",
    "commercialRegistration": "CR-1",
    "taxCard": "TC-1",
    "vatRatePercent": 14,
    "supportEmail": "help@ownhub.app",
    "supportPhone": "01012345678",
}


def test_seller_details_are_saved(db):
    assert receiving.set_seller(db, STAFF, SELLER, now=NOW) == {"ok": True}
    row = db.document("coachingConfig/seller").get().to_dict()
    assert row["companyNameEn"] == "Own Hub LLC" and row["vatRatePercent"] == 14 and row["updatedAt"] == NOW
    receiving.set_seller(db, STAFF, {k: v for k, v in SELLER.items() if k != "supportPhone"}, now=NOW)
    assert db.document("coachingConfig/seller").get().to_dict()["supportPhone"] == ""


@pytest.mark.parametrize("key", [k for k in SELLER if k != "supportPhone"])
def test_every_seller_key_but_the_phone_is_required(db, key):
    refuse(lambda: receiving.set_seller(db, STAFF, {k: v for k, v in SELLER.items() if k != key}, now=NOW), errors.INVALID, errors.BAD_REQUEST)
    assert not db.document("coachingConfig/seller").get().exists


@pytest.mark.parametrize("over", [{"vatRatePercent": 15}, {"vatRatePercent": -1}, {"vatRatePercent": 14.5}, {"vatRatePercent": True}, {"supportEmail": "nope"}])
def test_bad_seller_values_are_refused(db, over):
    refuse(lambda: receiving.set_seller(db, STAFF, {**SELLER, **over}, now=NOW), errors.INVALID, errors.BAD_REQUEST)


# -- receipts ----------------------------------------------------------------


def issue(db, sub_id, now, rate=14):
    sub = {"clientUid": "c", "priceFinalEgp": FINAL, "package": {"title": "T", "durationDays": 28}}
    seller = {**SELLER, "vatRatePercent": rate, "updatedAt": NOW}

    def body(transaction):
        return receipts.issue(transaction, db, sub_id, sub, seller, "Coach", now=now)

    return common.run(db, body)


def test_receipt_numbers_count_up_and_restart_each_year(db):
    assert issue(db, "a", NOW) == "OH-2026-000001"
    assert issue(db, "b", NOW) == "OH-2026-000002"
    assert issue(db, "c", dt.datetime(2027, 1, 1, tzinfo=dt.timezone.utc)) == "OH-2027-000001"
    assert db.document("coachingConfig/receiptCounter").get().to_dict() == {"year": 2027, "seq": 1}
    assert db.document("receipts/b").get().to_dict()["number"] == "OH-2026-000002"


def test_vat_is_the_part_of_the_price_that_is_tax(db):
    issue(db, "a", NOW, rate=14)
    issue(db, "b", NOW, rate=0)
    assert db.document("receipts/a").get().to_dict()["vatEgp"] == FINAL * 14 // 114
    assert db.document("receipts/b").get().to_dict()["vatEgp"] == 0
    assert receipts.vat_included(114, 14) == 14 and receipts.vat_included(100, 0) == 0


def test_the_receipt_copies_the_seller_without_its_timestamp(db):
    issue(db, "a", NOW)
    row = db.document("receipts/a").get().to_dict()
    assert row["seller"]["taxCard"] == "TC-1" and "updatedAt" not in row["seller"]
    assert row["issuedAt"] == NOW and row["clientUid"] == "c"
