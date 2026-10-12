"""N14: deletion erases her community, coach and assistant data (row 26).

Row 26 ("G1 onAccountDelete(uid)") mapped to GROUP_HOOK, which deletion.run
never executed, so publicProfiles, followGraph, posts, comments, likes, group
memberships, relationships, coaches and assistantQuota all outlived her account.
The features are off today; erasure has to cover them before they ship.

Runs the REAL FirebaseBackend against tests/fake_firestore.py, with a second
woman's data alongside hers to prove nothing of anyone else's is touched.
"""

from __future__ import annotations

import pytest

from account import deletion, manifest
from identity import store
from tests import fake_firestore
from tests.test_account_deletion import FakeBackend

HER = "uid-her"
OTHER = "uid-two"
THIRD = "uid-three"


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def seed(fs):
    d = fs.docs
    for uid in (HER, OTHER):
        d[f"publicProfiles/{uid}"] = {"displayName": uid}
        d[f"assistantQuota/{uid}"] = {"day": "2026-10-02", "used": 2}
        d[f"coaches/{uid}"] = {"bio": uid}
        d[f"coaches/{uid}/portfolio/v1"] = {"published": True}
        d[f"coaches/{uid}/offers/o1"] = {"price": 1}

    # Follow edges in both directions, and the key-set documents.
    d[f"followGraph/{HER}"] = {"followingKeys": [f"a:{OTHER}"], "hiddenAuthors": []}
    d[f"followGraph/{HER}/following/{OTHER}"] = {"at": 1}
    d[f"followGraph/{OTHER}"] = {
        "followingKeys": [f"a:{HER}", f"a:{THIRD}"],
        "groupKeys": ["g:g1"],
        "hiddenAuthors": [HER, THIRD],
    }
    d[f"followGraph/{OTHER}/following/{HER}"] = {"at": 1}
    d[f"followGraph/{OTHER}/following/{THIRD}"] = {"at": 1}

    # Her post, with another woman's comment and like under it.
    d["posts/p-her"] = {"authorUid": HER, "audienceKeys": [f"a:{HER}"]}
    d["posts/p-her/comments/c-on-hers"] = {"authorUid": OTHER, "body": "lovely"}
    d[f"posts/p-her/likes/{OTHER}"] = {"at": 1}
    # Another woman's post, with her comment, her like, and a third woman's
    # comment and like that must survive.
    d["posts/p-other"] = {"authorUid": OTHER, "audienceKeys": [f"a:{OTHER}"]}
    d["posts/p-other/comments/c-1"] = {
        "authorUid": HER,
        "postAuthorUid": OTHER,
        "body": "my words",
        "createdAt": 1,
    }
    d[f"posts/p-other/comments/c-{HER}-2"] = {"authorUid": HER, "body": "again"}
    d["posts/p-other/comments/c-third"] = {"authorUid": THIRD, "body": "hi"}
    d[f"posts/p-other/likes/{HER}"] = {"at": 1}
    d[f"posts/p-other/likes/{THIRD}"] = {"at": 1}

    # Group membership.
    d["groups/g1"] = {"name": "Walkers"}
    d[f"groups/g1/members/{HER}"] = {"joinedAt": 1}
    d[f"groups/g1/members/{OTHER}"] = {"joinedAt": 1}

    # Relationships with her as client and as coach, and one she is not in.
    d[f"relationships/{OTHER}__{HER}"] = {"coachUid": OTHER, "clientUid": HER}
    d[f"relationships/{OTHER}__{HER}/messages/m1"] = {"senderUid": HER}
    d[f"relationships/{HER}__{THIRD}"] = {"coachUid": HER, "clientUid": THIRD}
    d[f"relationships/{HER}__{THIRD}/reviews/r1"] = {"stars": 5}
    d[f"relationships/{OTHER}__{THIRD}"] = {"coachUid": OTHER, "clientUid": THIRD}

    # A result about her, published on another coach's page.
    d[f"coaches/{OTHER}/results/res-her"] = {"clientUid": HER, "consentState": "granted"}
    d[f"coaches/{OTHER}/results/res-third"] = {"clientUid": THIRD}


def purge(fs):
    seed(fs)
    deletion.FirebaseBackend().purge_group_hook(HER)
    return fs.docs


def test_public_profile_and_assistant_quota_are_deleted_for_her_only(fs):
    docs = purge(fs)
    assert f"publicProfiles/{HER}" not in docs
    assert f"assistantQuota/{HER}" not in docs
    assert docs[f"publicProfiles/{OTHER}"] == {"displayName": OTHER}
    assert docs[f"assistantQuota/{OTHER}"]["used"] == 2


def test_her_coach_profile_is_deleted_with_everything_under_it(fs):
    docs = purge(fs)
    assert not [p for p in docs if p.startswith(f"coaches/{HER}")]
    assert f"coaches/{OTHER}" in docs
    assert f"coaches/{OTHER}/portfolio/v1" in docs
    assert f"coaches/{OTHER}/offers/o1" in docs


def test_a_result_about_her_on_another_coach_page_is_deleted(fs):
    docs = purge(fs)
    assert f"coaches/{OTHER}/results/res-her" not in docs
    assert f"coaches/{OTHER}/results/res-third" in docs


def test_follow_edges_go_in_both_directions(fs):
    docs = purge(fs)
    assert not [p for p in docs if p.startswith(f"followGraph/{HER}")]
    assert f"followGraph/{OTHER}/following/{HER}" not in docs
    assert f"followGraph/{OTHER}/following/{THIRD}" in docs
    graph = docs[f"followGraph/{OTHER}"]
    assert graph["followingKeys"] == [f"a:{THIRD}"]
    assert graph["hiddenAuthors"] == [THIRD]
    assert graph["groupKeys"] == ["g:g1"]


def test_her_posts_are_deleted_with_what_hangs_off_them(fs):
    docs = purge(fs)
    assert not [p for p in docs if p.startswith("posts/p-her")]
    assert "posts/p-other" in docs


def test_her_comments_on_another_womans_post_become_bare_tombstones(fs):
    docs = purge(fs)
    under = {p: v for p, v in docs.items() if p.startswith("posts/p-other/comments/")}
    assert under["posts/p-other/comments/c-third"] == {"authorUid": THIRD, "body": "hi"}
    tombstones = [v for p, v in under.items() if p != "posts/p-other/comments/c-third"]
    assert len(tombstones) == 2
    assert all(t == {"deleted": True} for t in tombstones)
    # A comment id that spells her uid is not kept as the tombstone's id.
    assert not [p for p in under if HER in p]
    # No trace of her anywhere in the thread.
    assert HER not in repr(under)


def test_her_likes_go_and_others_stay(fs):
    docs = purge(fs)
    assert f"posts/p-other/likes/{HER}" not in docs
    assert f"posts/p-other/likes/{THIRD}" in docs


def test_her_group_membership_goes_and_the_group_stays(fs):
    docs = purge(fs)
    assert f"groups/g1/members/{HER}" not in docs
    assert f"groups/g1/members/{OTHER}" in docs
    assert "groups/g1" in docs


def test_her_relationships_on_either_side_are_deleted(fs):
    docs = purge(fs)
    assert not [p for p in docs if p.startswith(f"relationships/{OTHER}__{HER}")]
    assert not [p for p in docs if p.startswith(f"relationships/{HER}__{THIRD}")]
    assert f"relationships/{OTHER}__{THIRD}" in docs


def test_nothing_of_hers_survives_the_hook(fs):
    docs = purge(fs)
    # deletionRequests/{uid} is the deletion's own record (B3 keeps its scan
    # cursor there while it runs); it is reduced at `done`.
    docs = {p: v for p, v in docs.items() if not p.startswith("deletionRequests/")}
    leftovers = [p for p in docs if HER in p] + [
        p for p, v in docs.items() if HER in repr(v)
    ]
    assert leftovers == []


def test_the_hook_is_idempotent(fs):
    purge(fs)
    snapshot = dict(fs.docs)
    deletion.FirebaseBackend().purge_group_hook(HER)
    assert fs.docs == snapshot


# ------------------------------------------------------------- wiring


def test_run_executes_the_group_hook_inside_the_group_hooks_step():
    fake = FakeBackend(uid=HER)
    deletion.run(HER, fake)
    names = [c[0] for c in fake.calls]
    assert "purge_group_hook" in names
    hook = names.index("purge_group_hook")
    states = [(i, c[1]) for i, c in enumerate(fake.calls) if c[0] == "set_state"]
    before = [s for i, s in states if i < hook][-1]
    assert before == "purgingGroupHooks"
    assert hook < names.index("delete_auth")


# Each action, and the backend call (or journal state) that proves it ran.
# HANDSET rows have no server copy by definition; their proof is that the
# server never claims to touch them.
_PROOF = {
    manifest.USERS_RECURSIVE: ("delete_user_tree",),
    manifest.PLANS_RECURSIVE: ("delete_plans_tree",),
    manifest.REVERSE_BLOCKED_BY: ("delete_blocked_by",),
    manifest.JOBS: ("delete_where_uid", "verificationJobs"),
    manifest.FLAGS: ("delete_where_uid", "verification_flags"),
    manifest.SESSIONS: ("delete_where_uid", "verificationSessions"),
    manifest.LEDGER: ("delete_doc", "verificationLedger"),
    manifest.REGISTRY: ("close_registry",),
    manifest.STORAGE: ("delete_storage_prefix",),
    manifest.GROUP_HOOK: ("purge_group_hook",),
    manifest.THIRD_PARTY: ("set_state", "purgingThirdParty"),
    manifest.AUTH: ("delete_auth",),
    manifest.REPORTS: ("pseudonymise_reports",),
    manifest.DELETION_RECORD: ("finish_record",),
}


def test_every_manifest_row_maps_to_an_action_that_actually_runs():
    fake = FakeBackend(uid=HER)
    deletion.run(HER, fake)
    for row in manifest.ROWS:
        action = manifest.ACTIONS[row.number]
        if action == manifest.HANDSET:
            assert row.method == "localOnly", row
            continue
        if action == manifest.TTL:
            # Not linked to her account, so deletion cannot find them. Their
            # proof is the expireAt every write carries (test_ttl_fields).
            assert row.method == "ttl", row
            continue
        assert action in _PROOF, f"row {row.number} maps to {action!r}, which has no proof"
        proof = _PROOF[action]
        assert any(c[: len(proof)] == proof for c in fake.calls), (
            f"row {row.number} ({row.path}) maps to {action!r}, which run() never executed"
        )


def test_her_coach_certificates_and_invite_codes_go_and_no_one_elses(fs):
    # Rows 47 and 49: coaches/{uid}/certificates is under her coach page, and
    # her invite codes are found by coachUid.
    fs.docs[f"coaches/{HER}/certificates/nasm_cpt-1"] = {"state": "uploaded"}
    fs.docs[f"coaches/{OTHER}/certificates/nasm_cpt-1"] = {"state": "uploaded"}
    fs.docs["coachInvites/HERC2345"] = {"coachUid": HER}
    fs.docs["coachInvites/OTHR2345"] = {"coachUid": OTHER}
    docs = purge(fs)
    assert f"coaches/{HER}/certificates/nasm_cpt-1" not in docs
    assert "coachInvites/HERC2345" not in docs
    assert docs[f"coaches/{OTHER}/certificates/nasm_cpt-1"] == {"state": "uploaded"}
    assert docs["coachInvites/OTHR2345"] == {"coachUid": OTHER}
