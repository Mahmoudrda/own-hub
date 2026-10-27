"""Deletion covers private coaching (rows 55 to 59).

Runs the REAL FirebaseBackend against tests/fake_firestore.py, for a woman who
is a coach and a client, with another coach, another client and a third woman's
data alongside to prove nothing of anyone else's is touched.
"""

from __future__ import annotations

import pytest

from account import deletion
from identity import store
from tests import fake_firestore

HER = "uid-her"
COACH = "uid-coach"
CLIENT = "uid-client"
THIRD = "uid-third"


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def seed(fs):
    d = fs.docs
    # Her, as a coach: application, private record, page, packages, drafts.
    d[f"coachApplications/{HER}"] = {"status": "approved", "personal": {"fullName": "Her"}}
    d[f"coachApplications/{COACH}"] = {"status": "approved"}
    d[f"coachPrivate/{HER}"] = {"payoutState": "none", "owedEgp": 0}
    d[f"coachPrivate/{HER}/prices/p1"] = {"coachPriceEgp": 500}
    d[f"coachPrivate/{HER}/ledger/sub-mine"] = {"status": "pending", "coachAmountEgp": 400}
    d[f"coachPrivate/{HER}/payouts/po1"] = {"amountEgp": 10}
    d[f"coachPrivate/{COACH}"] = {"payoutState": "none", "owedEgp": 0}
    d[f"coachPrivate/{COACH}/prices/p1"] = {"coachPriceEgp": 700}
    d[f"coachPrivate/{COACH}/ledger/sub-hers"] = {"status": "pending", "coachAmountEgp": 560}
    d[f"coaches/{HER}"] = {"displayName": "Her", "activeClients": 1}
    d[f"coaches/{HER}/packages/p1"] = {"title": "Eight weeks"}
    d[f"coaches/{HER}/drafts/d1"] = {"name": "Draft"}
    d[f"coaches/{HER}/media/m1"] = {"kind": "photo", "path": f"coach-public/{HER}/media/m1.jpg"}
    d[f"coaches/{COACH}/media/m1"] = {"kind": "photo"}
    d[f"coaches/{COACH}"] = {"displayName": "Coach", "activeClients": 2}
    d[f"coaches/{COACH}/packages/p1"] = {"title": "Other"}

    # A coaching she gave (client CLIENT), active.
    d[f"relationships/{HER}__{CLIENT}"] = {
        "coachUid": HER, "clientUid": CLIENT, "status": "active", "chatOpen": True, "activeSubId": "sub-mine",
    }
    d[f"relationships/{HER}__{CLIENT}/messages/m1"] = {"senderUid": CLIENT, "text": "hi"}
    d[f"relationships/{HER}__{CLIENT}/reads/{CLIENT}"] = {"at": 1}
    d[f"relationships/{HER}__{CLIENT}/checkIns/2026-W44"] = {"clientUid": CLIENT, "state": "answered", "answers": {"note": "x"}}
    d["subscriptions/sub-mine"] = {
        "coachUid": HER, "clientUid": CLIENT, "relId": f"{HER}__{CLIENT}", "status": "active",
        "intake": {"goal": "strength", "health": {"q1": True}},
    }
    d["subscriptions/sub-mine/private/terms"] = {"coachPriceEgp": 500}
    d["subscriptions/sub-mine/sessions/s1"] = {"minutes": 30}

    # A coaching she joined (coach COACH), active.
    d[f"relationships/{COACH}__{HER}"] = {
        "coachUid": COACH, "clientUid": HER, "status": "active", "chatOpen": True, "activeSubId": "sub-hers",
    }
    d[f"relationships/{COACH}__{HER}/messages/m1"] = {"senderUid": HER, "text": "hello"}
    d[f"relationships/{COACH}__{HER}/reads/{HER}"] = {"at": 1}
    d[f"relationships/{COACH}__{HER}/checkIns/2026-W44"] = {"clientUid": HER, "state": "answered", "answers": {"note": "my knee"}}
    d["subscriptions/sub-hers"] = {
        "coachUid": COACH, "clientUid": HER, "relId": f"{COACH}__{HER}", "status": "active",
        "intake": {"goal": "weight", "health": {"q1": False}},
    }
    d["subscriptions/sub-hers/private/terms"] = {"coachPriceEgp": 700}
    d["subscriptions/sub-hers/sessions/s1"] = {"minutes": 30}
    # A request she made that was never answered.
    d["subscriptions/sub-asked"] = {
        "coachUid": COACH, "clientUid": HER, "relId": f"{COACH}__{HER}", "status": "requested",
    }

    # Someone else's coaching, which must not be touched.
    d[f"relationships/{COACH}__{THIRD}"] = {
        "coachUid": COACH, "clientUid": THIRD, "status": "active", "chatOpen": True,
    }
    d[f"relationships/{COACH}__{THIRD}/messages/m1"] = {"senderUid": THIRD, "text": "x"}
    d[f"relationships/{COACH}__{THIRD}/checkIns/2026-W44"] = {"clientUid": THIRD, "state": "open"}
    d["subscriptions/sub-third"] = {
        "coachUid": COACH, "clientUid": THIRD, "relId": f"{COACH}__{THIRD}", "status": "active",
        "intake": {"goal": "x"},
    }
    d["subscriptions/sub-third/private/terms"] = {"coachPriceEgp": 700}

    # Her consents and coach plans.
    for name in ("coach-terms-v1", "coaching-share-v1", "payment-proof-v1", "transfer-abroad-v1"):
        d[f"users/{HER}/consents/{name}"] = {"version": 1, "at": 1}
        d[f"users/{THIRD}/consents/{name}"] = {"version": 1, "at": 1}
    d[f"users/{HER}"] = {"profile": {}}
    d[f"plans/{HER}/coachPlans/cp1"] = {"coachUid": COACH, "name": "Plan"}
    d[f"plans/{THIRD}/coachPlans/cp1"] = {"coachUid": COACH, "name": "Plan"}

    # Money: her receipt and proof as a client, and a receipt of her coaching.
    d["receipts/sub-hers"] = {"clientUid": HER, "coachName": "Coach", "priceFinalEgp": 800}
    d["receipts/sub-mine"] = {"clientUid": CLIENT, "coachName": "Her Name", "priceFinalEgp": 500}
    d["receipts/sub-third"] = {"clientUid": THIRD, "coachName": "Coach", "priceFinalEgp": 800}
    d["paymentProofs/pp1"] = {"clientUid": HER, "coachUid": COACH, "senderName": "Her Typed", "status": "approved"}
    d["paymentProofs/pp2"] = {"clientUid": CLIENT, "coachUid": HER, "senderName": "Client", "status": "approved"}
    d["paymentProofs/pp3"] = {"clientUid": THIRD, "coachUid": COACH, "senderName": "Third", "status": "approved"}


def run_all(fs):
    seed(fs)
    backend = deletion.FirebaseBackend()
    backend.purge_group_hook(HER)
    backend.delete_user_tree(HER)
    backend.delete_plans_tree(HER)
    return fs.docs


def under(docs, *prefixes):
    return [p for p in docs if any(p == x or p.startswith(x + "/") for x in prefixes)]


def test_every_coaching_path_of_hers_is_gone(fs):
    docs = run_all(fs)
    assert not under(
        docs,
        f"coachApplications/{HER}",
        f"coachPrivate/{HER}",
        f"coaches/{HER}",
        f"relationships/{HER}__{CLIENT}",
        f"relationships/{COACH}__{HER}",
        "subscriptions/sub-mine",
        "subscriptions/sub-hers",
        "subscriptions/sub-asked",
        f"users/{HER}",
        f"plans/{HER}",
    )


def test_her_consent_records_go_with_her_user_tree(fs):
    docs = run_all(fs)
    for name in ("coach-terms-v1", "coaching-share-v1", "payment-proof-v1", "transfer-abroad-v1"):
        assert f"users/{HER}/consents/{name}" not in docs
        assert f"users/{THIRD}/consents/{name}" in docs


def test_nothing_of_anyone_elses_is_touched(fs):
    docs = run_all(fs)
    assert docs[f"coachApplications/{COACH}"] == {"status": "approved"}
    assert docs[f"coachPrivate/{COACH}/prices/p1"] == {"coachPriceEgp": 700}
    assert docs[f"coaches/{COACH}/packages/p1"] == {"title": "Other"}
    assert docs[f"coaches/{COACH}/media/m1"] == {"kind": "photo"}
    assert docs[f"relationships/{COACH}__{THIRD}"]["status"] == "active"
    assert docs[f"relationships/{COACH}__{THIRD}"]["chatOpen"] is True
    assert f"relationships/{COACH}__{THIRD}/messages/m1" in docs
    assert docs[f"relationships/{COACH}__{THIRD}/checkIns/2026-W44"]["state"] == "open"
    assert docs["subscriptions/sub-third"]["status"] == "active"
    assert docs["subscriptions/sub-third"]["intake"] == {"goal": "x"}
    assert f"subscriptions/sub-third/private/terms" in docs
    assert docs[f"plans/{THIRD}/coachPlans/cp1"]["name"] == "Plan"
    assert docs["receipts/sub-third"] == {"clientUid": THIRD, "coachName": "Coach", "priceFinalEgp": 800}
    assert docs["paymentProofs/pp3"]["senderName"] == "Third"


def test_a_coach_she_joined_gets_her_place_and_ledger_line_back(fs):
    docs = run_all(fs)
    assert docs[f"coaches/{COACH}"]["activeClients"] == 1
    assert docs[f"coachPrivate/{COACH}/ledger/sub-hers"]["status"] == "reversed"


def test_ending_a_coaching_she_gave_writes_nothing_on_the_clients_side_but_the_thread(fs):
    seed(fs)
    backend = deletion.FirebaseBackend()
    backend._end_open_coachings(HER)
    docs = fs.docs
    assert docs["subscriptions/sub-mine"]["status"] == "ended_early"
    assert docs["subscriptions/sub-mine"]["endReason"] == "coach_left"
    assert docs[f"relationships/{HER}__{CLIENT}"]["status"] == "ended"
    assert docs[f"relationships/{HER}__{CLIENT}"]["chatOpen"] is False
    assert docs["subscriptions/sub-hers"]["endReason"] == "client_left"
    assert docs[f"relationships/{COACH}__{HER}"]["chatOpen"] is False
    # No chat line and no push-triggering write is left behind.
    assert not [p for p in docs if "/messages/" in p and p not in (
        f"relationships/{HER}__{CLIENT}/messages/m1",
        f"relationships/{COACH}__{HER}/messages/m1",
        f"relationships/{COACH}__{THIRD}/messages/m1",
    )]


def test_ending_is_a_no_op_for_a_request_that_was_never_answered(fs):
    seed(fs)
    deletion.FirebaseBackend()._end_open_coachings(HER)
    assert fs.docs["subscriptions/sub-asked"]["status"] == "ended_early"
    # A request holds no place, so the coach's count only fell for the active one.
    assert fs.docs[f"coaches/{COACH}"]["activeClients"] == 1


def test_receipts_and_proofs_keep_the_record_and_lose_her_name(fs):
    docs = run_all(fs)
    assert docs["receipts/sub-hers"]["clientUid"].startswith("deleted-")
    assert docs["receipts/sub-hers"]["priceFinalEgp"] == 800
    assert docs["receipts/sub-mine"]["coachName"] == ""
    assert docs["receipts/sub-mine"]["clientUid"] == CLIENT
    assert docs["paymentProofs/pp1"]["clientUid"].startswith("deleted-")
    assert docs["paymentProofs/pp1"]["senderName"] == ""
    assert docs["paymentProofs/pp1"]["coachUid"] == COACH
    assert docs["paymentProofs/pp2"]["coachUid"].startswith("deleted-")
    assert docs["paymentProofs/pp2"]["senderName"] == "Client"
    money = {k: v for k, v in docs.items() if k.startswith(("receipts", "paymentProofs"))}
    assert HER not in repr(money)


def test_running_it_again_changes_nothing(fs):
    run_all(fs)
    before = dict(fs.docs)
    backend = deletion.FirebaseBackend()
    backend.purge_group_hook(HER)
    assert fs.docs == before


def test_the_late_sweep_covers_a_coaching_a_stale_token_wrote(fs):
    run_all(fs)
    fs.docs["coachApplications/" + HER] = {"status": "draft"}
    fs.docs[f"coachPrivate/{HER}"] = {"payoutState": "none"}
    fs.docs["subscriptions/sub-late"] = {"coachUid": COACH, "clientUid": HER, "relId": "x", "status": "requested"}
    deletion.FirebaseBackend().purge_group_hook(HER)
    assert not under(fs.docs, f"coachApplications/{HER}", f"coachPrivate/{HER}", "subscriptions/sub-late")


def test_chat_media_of_every_thread_of_hers_is_purged_before_the_thread(fs, monkeypatch):
    # Both people's photos, clips and voice notes of a thread (row 48): the
    # whole chat-media/{relId}/ prefix, in both buckets, files before the
    # messages that point at them, and no other thread's folder.
    seed(fs)
    calls = []

    def spy(self, bucket, prefix):
        calls.append((bucket, prefix, f"relationships/{prefix.split('/')[1]}" in fs.docs))

    monkeypatch.setattr(deletion.FirebaseBackend, "delete_storage_prefix", spy)
    deletion.FirebaseBackend().purge_group_hook(HER)
    mine = (f"{HER}__{CLIENT}", f"{COACH}__{HER}")
    for rel in mine:
        for bucket in (None, deletion.PERSONAL_BUCKET):
            assert (bucket, f"chat-media/{rel}/", True) in calls
    assert not any(THIRD in prefix for _, prefix, _ in calls)
    assert len(calls) == 4


def test_the_manifest_names_the_chat_media_folder_in_row_48():
    from account import manifest

    row = {r.number: r for r in manifest.load()}[48]
    assert "chat-media/{relId}/**" in row.path
    assert manifest.ACTIONS[48] == manifest.GROUP_HOOK


def test_portfolio_media_docs_go_with_the_coach_page(fs):
    docs = run_all(fs)
    assert not under(docs, f"coaches/{HER}/media")


def test_portfolio_media_files_are_in_the_purged_storage_prefixes():
    # coach-public/{uid}/media/** and coach-docs/{uid}/gallery/** sit under
    # prefixes purge_storage already empties, in both buckets.
    assert "coach-public/{uid}/" in deletion.STORAGE_PREFIXES
    assert "coach-docs/{uid}/" in deletion.STORAGE_PREFIXES
    calls = []

    class Spy:
        def delete_storage_prefix(self, bucket, prefix):
            calls.append((bucket, prefix))

    deletion.purge_storage(HER, Spy())
    for bucket in (None, deletion.PERSONAL_BUCKET):
        assert (bucket, f"coach-public/{HER}/") in calls
        assert (bucket, f"coach-docs/{HER}/") in calls
