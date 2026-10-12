"""The real store functions against a fake that applies Firestore's own merge
semantics (see tests/fake_firestore.py). A nested map written with merge=True
is a LEAF merge in Firestore; these tests catch code that assumes otherwise."""

from __future__ import annotations

import pytest

from identity import config, store
from tests import fake_firestore


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def _ledger(fs, uid="her"):
    return fs.docs.get(f"{config.COL_LEDGER}/{uid}", {})


def test_the_fake_reproduces_firestore_leaf_merge(fs):
    ref = fs.collection("x").document("y")
    ref.set({"m": {"a": 1, "b": 2}})
    ref.set({"m": {"a": 3}}, merge=True)
    assert fs.docs["x/y"] == {"m": {"a": 3, "b": 2}}
    ref.set({"m": {"a": 4}}, merge=["m"])
    assert fs.docs["x/y"] == {"m": {"a": 4}}


def test_a_new_day_resets_every_daily_counter_not_only_the_one_written(fs, monkeypatch):
    monkeypatch.setattr(store, "_today", lambda: "2026-10-01")
    for _ in range(config.PER_UID_DAILY_VERIFY_LIMIT):
        store.uid_daily_count_and_increment("her", "verifies")
    for _ in range(config.PER_UID_DAILY_REVIEW_LIMIT):
        store.uid_daily_count_and_increment("her", "reviews")

    monkeypatch.setattr(store, "_today", lambda: "2026-10-02")
    # The first call of the new day is a start; the old verifies and reviews
    # must not survive it.
    assert store.uid_daily_count_and_increment("her", "starts") == 1
    assert _ledger(fs)["daily"] == {"day": "2026-10-02", "starts": 1}
    assert store.uid_daily_count_and_increment("her", "verifies") == 1
    assert store.uid_daily_count_and_increment("her", "reviews") == 1


def test_the_daily_counter_leaves_the_rest_of_the_ledger_alone(fs, monkeypatch):
    fs.collection(config.COL_LEDGER).document("her").set(
        {"spent_micro_usd": 1234, "openFlagId": "f-1", "bonusOcrSubmissions": 1}
    )
    monkeypatch.setattr(store, "_today", lambda: "2026-10-02")
    store.uid_daily_count_and_increment("her", "starts")
    store.uid_daily_count_and_increment("her", "starts")
    ledger = _ledger(fs)
    assert ledger["spent_micro_usd"] == 1234
    assert ledger["openFlagId"] == "f-1"
    assert ledger["bonusOcrSubmissions"] == 1
    assert ledger["daily"] == {"day": "2026-10-02", "starts": 2}


def test_the_verification_map_is_a_leaf_merge_on_purpose(fs):
    # set_verification_state relies on leaf merge: decidedAt survives a later
    # state write, and reset_booking clears the booking explicitly.
    store.set_verification_state("her", "pending", route="video", scheduled_for=fs.now)
    store.set_verification_state("her", "pending", reset_booking=True)
    verification = fs.docs[f"{config.COL_USERS}/her"]["verification"]
    assert verification["state"] == "pending"
    assert verification["reviewRoute"] is None
    assert verification["reviewScheduledFor"] is None
