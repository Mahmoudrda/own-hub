"""C1: posts/{id}.counts.likes and counts.comments are kept by Firestore
triggers, and only by them.

  * a like or a live comment created: +1; deleted: -1;
  * a comment tombstoned ({deleted: true}) in place: -1; a tombstone created
    or deleted on its own: 0. counts.comments is the number of LIVE comments;
  * a re-delivered event (same event id) changes nothing: the event id is
    recorded on posts/{id}/countEvents/{eventId} in the same transaction;
  * never below 0; a post that is gone is left alone (no marker is written
    under it, so nothing is recreated beneath a deleted post).

The deletion purge does NOT touch counts any more (B2 moved here): it deletes
and tombstones, and the triggers those writes fire do the arithmetic. One
owner, so no double decrement.

Runs against tests/fake_firestore.py.
"""

from __future__ import annotations

import ast
import os

import pytest

from account import deletion
from community import counts
from identity import store
from tests import fake_firestore
from tests.test_deletion_community import HER, THIRD, seed

_FUNCTIONS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def _counts(fs, post="p1"):
    return fs.docs[f"posts/{post}"].get("counts")


def test_a_like_counts_once_even_when_the_event_is_delivered_twice(fs):
    fs.docs["posts/p1"] = {"authorUid": THIRD}
    counts.on_change(fs, "e1", "posts/p1/likes/u1", None, {"at": 1})
    counts.on_change(fs, "e1", "posts/p1/likes/u1", None, {"at": 1})
    assert _counts(fs) == {"likes": 1}
    counts.on_change(fs, "e2", "posts/p1/likes/u2", None, {"at": 1})
    assert _counts(fs) == {"likes": 2}


def test_unlike_comes_off_and_never_below_zero(fs):
    fs.docs["posts/p1"] = {"authorUid": THIRD, "counts": {"likes": 1, "comments": 0}}
    counts.on_change(fs, "e1", "posts/p1/likes/u1", {"at": 1}, None)
    counts.on_change(fs, "e2", "posts/p1/likes/u2", {"at": 1}, None)
    assert _counts(fs) == {"likes": 0, "comments": 0}


def test_comments_count_live_comments_only(fs):
    fs.docs["posts/p1"] = {"authorUid": THIRD}
    path = "posts/p1/comments/c1"
    counts.on_change(fs, "e1", path, None, {"authorUid": "u", "body": "hi"})
    counts.on_change(fs, "e2", "posts/p1/comments/c2", None, {"authorUid": "u", "body": "x"})
    assert _counts(fs) == {"comments": 2}
    # Tombstoned in place.
    counts.on_change(fs, "e3", path, {"authorUid": "u", "body": "hi"}, {"deleted": True})
    assert _counts(fs) == {"comments": 1}
    # A tombstone created, or deleted, on its own is not a comment.
    counts.on_change(fs, "e4", "posts/p1/comments/t", None, {"deleted": True})
    counts.on_change(fs, "e5", path, {"deleted": True}, None)
    assert _counts(fs) == {"comments": 1}
    # An ordinary edit changes nothing.
    counts.on_change(fs, "e6", "posts/p1/comments/c2", {"body": "x"}, {"body": "y"})
    assert _counts(fs) == {"comments": 1}


def test_a_post_that_is_gone_is_left_alone(fs):
    counts.on_change(fs, "e1", "posts/gone/likes/u1", {"at": 1}, None)
    assert fs.docs == {}


def test_only_post_likes_and_comments_are_counted(fs):
    fs.docs["groups/g1"] = {"name": "x"}
    counts.on_change(fs, "e1", "groups/g1/likes/u1", None, {"at": 1})
    assert fs.docs == {"groups/g1": {"name": "x"}}


def test_the_purge_leaves_counts_to_the_triggers_and_the_sum_is_right(fs):
    """One owner for the decrement: the purge writes, the triggers count."""
    seed(fs)
    fs.docs["posts/p-other"]["counts"] = {"likes": 2, "comments": 3}
    fs.docs["posts/p-zero"] = {"authorUid": THIRD, "counts": {"likes": 0, "comments": 0}}
    fs.docs[f"posts/p-zero/likes/{HER}"] = {"at": 1}
    before = dict(fs.docs)
    deletion.FirebaseBackend().purge_group_hook(HER)
    after = dict(fs.docs)
    # The purge itself did not touch any count.
    assert after["posts/p-other"]["counts"] == {"likes": 2, "comments": 3}
    assert after["posts/p-zero"]["counts"] == {"likes": 0, "comments": 0}
    # Feed every change it made to the trigger, as Firestore would.
    changed = sorted(p for p in set(before) | set(after) if before.get(p) != after.get(p))
    for i, path in enumerate(changed):
        counts.on_change(fs, f"ev{i}", path, before.get(path), after.get(path))
    assert fs.docs["posts/p-other"]["counts"] == {"likes": 1, "comments": 1}
    assert fs.docs["posts/p-zero"]["counts"] == {"likes": 0, "comments": 0}


def test_the_triggers_are_deployed_on_both_subcollections():
    tree = ast.parse(open(os.path.join(_FUNCTIONS, "main.py"), encoding="utf-8").read())
    documents = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            for decorator in node.decorator_list:
                if isinstance(decorator, ast.Call) and ast.unparse(decorator.func) == (
                    "firestore_fn.on_document_written"
                ):
                    keywords = {k.arg: ast.unparse(k.value) for k in decorator.keywords}
                    assert keywords["region"] == "config.REGION"
                    documents.add(keywords["document"])
    assert documents == {"'posts/{postId}/likes/{likeId}'", "'posts/{postId}/comments/{commentId}'"}


def test_the_trigger_adapter_reads_the_event(fs):
    from types import SimpleNamespace

    import main

    def snap(data):
        return SimpleNamespace(exists=data is not None, to_dict=lambda: data)

    fs.docs["posts/p1"] = {"authorUid": THIRD}
    event = SimpleNamespace(
        id="evt-1",
        document="posts/p1/likes/u1",
        data=SimpleNamespace(before=None, after=snap({"at": 1})),
    )
    main._count_change(event)
    main._count_change(event)  # re-delivered
    assert _counts(fs) == {"likes": 1}
    gone = SimpleNamespace(
        id="evt-2", document="posts/p1/likes/u1",
        data=SimpleNamespace(before=snap({"at": 1}), after=None),
    )
    main._count_change(gone)
    assert _counts(fs) == {"likes": 0}
