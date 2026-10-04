"""B2: when her likes and comments on other women's posts are removed or
tombstoned, posts/{id}.counts.likes and counts.comments come down with them,
in the same transaction, never below 0 and never twice.

Follower and following counts are not stored anywhere: the rules forbid a
followerCount on coach documents, publicProfiles carries none, and the app
counts edges (community_repository.followerCountOf). Deleting the edges, which
the hook already does, is what keeps those true.

Runs the REAL FirebaseBackend against tests/fake_firestore.py.
"""

from __future__ import annotations

import pytest

from account import deletion
from identity import store
from tests import fake_firestore
from tests.test_deletion_community import HER, OTHER, THIRD, seed


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def _seed_counts(fs):
    seed(fs)
    d = fs.docs
    # p-other: her like and THIRD's like; her two comments and THIRD's one.
    d["posts/p-other"]["counts"] = {"likes": 2, "comments": 3}
    # A count that has already drifted to 0 must not go negative.
    d["posts/p-zero"] = {"authorUid": THIRD, "counts": {"likes": 0, "comments": 0}}
    d[f"posts/p-zero/likes/{HER}"] = {"at": 1}
    d["posts/p-zero/comments/cz"] = {"authorUid": HER, "body": "x"}
    # A post with no counts map yet: none is invented.
    d["posts/p-bare"] = {"authorUid": THIRD}
    d[f"posts/p-bare/likes/{HER}"] = {"at": 1}


def _purge(fs):
    deletion.FirebaseBackend().purge_group_hook(HER)


def test_her_like_and_comments_come_off_the_counts(fs):
    _seed_counts(fs)
    _purge(fs)
    assert fs.docs["posts/p-other"]["counts"] == {"likes": 1, "comments": 1}


def test_counts_never_go_below_zero(fs):
    _seed_counts(fs)
    _purge(fs)
    assert fs.docs["posts/p-zero"]["counts"] == {"likes": 0, "comments": 0}


def test_a_post_without_counts_is_not_given_any(fs):
    _seed_counts(fs)
    _purge(fs)
    assert "counts" not in fs.docs["posts/p-bare"]


def test_a_rerun_does_not_decrement_twice(fs):
    _seed_counts(fs)
    _purge(fs)
    _purge(fs)
    assert fs.docs["posts/p-other"]["counts"] == {"likes": 1, "comments": 1}


def test_other_womens_counts_are_untouched(fs):
    _seed_counts(fs)
    fs.docs["posts/p-third"] = {"authorUid": THIRD, "counts": {"likes": 4, "comments": 2}}
    fs.docs[f"posts/p-third/likes/{OTHER}"] = {"at": 1}
    _purge(fs)
    assert fs.docs["posts/p-third"]["counts"] == {"likes": 4, "comments": 2}
