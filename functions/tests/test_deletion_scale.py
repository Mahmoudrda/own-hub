"""B3: the community deletion scales.

Comments, likes, following edges and results are found by scanning their
collection groups (a filtered collection-group query would need an index
override, and the app's index test allows only exemptions). The scan is now
paged by document name with a cursor, under a hard time budget. When the
budget runs out the cursor is saved on deletionRequests/{uid}, the record stays
at `purgingGroupHooks`, and the sweeper resumes from the cursor. The late
sweep runs the hook once more, so a comment or like a still-valid token wrote
behind the cursor is caught too.

Runs the REAL FirebaseBackend against tests/fake_firestore.py.
"""

from __future__ import annotations

import datetime as dt

import pytest

import main
from account import deletion
from identity import config, store
from tests import fake_firestore
from tests.test_account_deletion import FakeBackend
from tests.test_deletion_community import HER, OTHER, THIRD, seed

PAGE = 2


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    monkeypatch.setattr(config, "DELETION_SCAN_PAGE", PAGE)
    return db


@pytest.fixture
def streams(monkeypatch):
    """Every collection-group stream: (group, limit)."""
    seen = []
    original = fake_firestore.CollectionRef.stream

    def stream(self, transaction=None):
        if self._group:
            seen.append((self.path, self._limit))
        return original(self, transaction)

    monkeypatch.setattr(fake_firestore.CollectionRef, "stream", stream)
    return seen


def _many(fs, n=7):
    """Many posts, each with her comment and like and a third woman's."""
    for i in range(n):
        post = f"posts/q{i}"
        fs.docs[post] = {"authorUid": THIRD, "counts": {"likes": 2, "comments": 2}}
        fs.docs[f"{post}/comments/h{i}"] = {"authorUid": HER, "body": "mine"}
        fs.docs[f"{post}/comments/t{i}"] = {"authorUid": THIRD, "body": "theirs"}
        fs.docs[f"{post}/likes/{HER}"] = {"at": 1}
        fs.docs[f"{post}/likes/{THIRD}"] = {"at": 1}


class _Clock:
    """A monotonic clock that moves one second per reading."""

    def __init__(self):
        self.t = 0.0

    def __call__(self):
        self.t += 1.0
        return self.t


def _hers_left(fs):
    """Her data anywhere but her own deletion record."""
    docs = {p: v for p, v in fs.docs.items() if not p.startswith("deletionRequests/")}
    return [p for p in docs if HER in p] + [p for p, v in docs.items() if HER in repr(v)]


def test_every_collection_group_scan_is_paged(fs, streams):
    seed(fs)
    _many(fs)
    assert deletion.FirebaseBackend().purge_group_hook(HER) is True
    assert streams, "the hook scans collection groups"
    assert all(limit == PAGE for _, limit in streams), streams
    assert {g for g, _ in streams} == {"following", "comments", "likes", "results"}


def test_a_paged_scan_still_finds_everything(fs):
    seed(fs)
    _many(fs)
    assert deletion.FirebaseBackend().purge_group_hook(HER) is True
    assert _hers_left(fs) == []
    for i in range(7):
        # Untouched by the purge: the counter triggers own counts (C1).
        assert fs.docs[f"posts/q{i}"]["counts"] == {"likes": 2, "comments": 2}
        assert fs.docs[f"posts/q{i}/comments/t{i}"] == {"authorUid": THIRD, "body": "theirs"}


def test_the_budget_pauses_the_hook_and_saves_a_cursor(fs, monkeypatch):
    seed(fs)
    _many(fs)
    clock = _Clock()
    monkeypatch.setattr(deletion, "_clock", clock)
    backend = deletion.FirebaseBackend()
    assert backend.purge_group_hook(HER, deadline=6.0) is False
    cursor = fs.docs[f"deletionRequests/{HER}"]["hookCursor"]
    assert cursor["phase"] in deletion.SCAN_PHASES
    assert _hers_left(fs), "the budget stopped it part way"

    # Resumed slice by slice, it finishes, and nothing is decremented twice.
    for _ in range(100):
        clock.t = 0.0
        if backend.purge_group_hook(HER, deadline=6.0):
            break
    else:  # pragma: no cover
        pytest.fail("never finished")
    assert [p for p in _hers_left(fs) if not p.startswith("deletionRequests/")] == []
    for i in range(7):
        # Untouched by the purge: the counter triggers own counts (C1).
        assert fs.docs[f"posts/q{i}"]["counts"] == {"likes": 2, "comments": 2}
    assert fs.docs[f"deletionRequests/{HER}"]["hookCursor"]["phase"] == "done"


def test_a_paused_run_stays_unfinished_and_the_sweeper_resumes_it(fs, monkeypatch):
    seed(fs)
    _many(fs)
    clock = _Clock()
    monkeypatch.setattr(deletion, "_clock", clock)
    monkeypatch.setattr(deletion.FirebaseBackend, "lock_auth", lambda self, uid: None)
    monkeypatch.setattr(deletion.FirebaseBackend, "delete_auth", lambda self, uid: None)
    monkeypatch.setattr(deletion.FirebaseBackend, "delete_storage_prefix", lambda *a: None)
    backend = deletion.FirebaseBackend()

    result = deletion.run(HER, backend, deadline=6.0)
    assert result["state"] == "purgingGroupHooks"
    assert result["journal"][-1] == "purgingGroupHooks"
    assert "done" not in result["journal"]
    record = fs.docs[f"deletionRequests/{HER}"]
    assert record["state"] == "purgingGroupHooks"
    assert record["state"] in deletion.UNFINISHED_STATES
    later = fs.now + dt.timedelta(hours=1)
    assert deletion.unfinished(fs, later) == [HER]

    clock.t = -10_000.0
    assert deletion.run(HER, backend, deadline=None)["state"] == "done"
    record = fs.docs[f"deletionRequests/{HER}"]
    assert set(record) <= deletion.DELETION_RECORD_FIELDS, record
    assert [p for p in _hers_left(fs) if not p.startswith("deletionRequests/")] == []


def test_the_late_sweep_runs_the_hook_again(fs, monkeypatch):
    """A like or comment written behind the cursor with a still-valid token."""
    monkeypatch.setattr(deletion.FirebaseBackend, "delete_storage_prefix", lambda *a: None)
    backend = deletion.FirebaseBackend()
    backend.finish_record(HER)
    fs.docs["posts/late"] = {"authorUid": OTHER, "counts": {"likes": 1, "comments": 1}}
    fs.docs["posts/late/comments/c"] = {"authorUid": HER, "body": "late"}
    fs.docs[f"posts/late/likes/{HER}"] = {"at": 1}
    deletion.resweep(HER, backend)
    assert fs.docs["posts/late/comments/c"] == {"deleted": True}
    assert f"posts/late/likes/{HER}" not in fs.docs
    # Untouched by the sweep: the counter triggers own counts (C1).
    assert fs.docs["posts/late"]["counts"] == {"likes": 1, "comments": 1}
    record = fs.docs[f"deletionRequests/{HER}"]
    assert "sweptAt" in record and set(record) <= deletion.DELETION_RECORD_FIELDS


def test_a_late_sweep_out_of_time_is_not_marked_swept():
    fake = FakeBackend()
    deletion.run("her", fake)
    fake.hook_pauses = 1
    deletion.resweep("her", fake, deadline=1.0)
    assert "sweptAt" not in fake.record and fake.record.get("sweepAfter")
    deletion.resweep("her", fake)
    assert "sweptAt" in fake.record


def test_the_callable_and_the_sweeper_both_pass_a_deadline(fs, monkeypatch):
    seen = []

    def fake_run(uid, backend, deadline=None):
        seen.append(deadline)
        return {"state": "done", "journal": list(deletion.JOURNAL)}

    monkeypatch.setattr(deletion, "run", fake_run)
    monkeypatch.setattr(deletion, "unfinished", lambda db, older: ["a", "b"])
    monkeypatch.setattr(deletion, "due_resweeps", lambda db, now: [])
    sweep = getattr(main.resume_account_deletions, "__wrapped__", main.resume_account_deletions)
    sweep(None)
    assert len(seen) == 2 and all(d is not None for d in seen)
    assert config.DELETION_SWEEP_BUDGET_SEC < config.TIMEOUT_SEC
    assert config.DELETION_CALL_BUDGET_SEC < 60  # the client waits 60 seconds


def test_the_sweeper_stops_taking_work_when_its_budget_is_spent(fs, monkeypatch):
    clock = _Clock()
    monkeypatch.setattr(deletion, "_clock", clock)
    monkeypatch.setattr(config, "DELETION_SWEEP_BUDGET_SEC", 3)
    ran = []
    monkeypatch.setattr(
        deletion, "run", lambda uid, backend, deadline=None: ran.append(uid) or {}
    )
    monkeypatch.setattr(deletion, "unfinished", lambda db, older: [str(i) for i in range(50)])
    monkeypatch.setattr(deletion, "due_resweeps", lambda db, now: [])
    sweep = getattr(main.resume_account_deletions, "__wrapped__", main.resume_account_deletions)
    sweep(None)
    assert 0 < len(ran) < 50
