"""N9: a deleted account can be partly rewritten for up to an hour by a
still-valid ID token or a queued client write. One more recursive delete of
users/{uid} and plans/{uid} runs about 65 minutes after `done`, once.

Runs the REAL FirebaseBackend against tests/fake_firestore.py."""

from __future__ import annotations

import datetime as dt

import pytest

import main
from account import deletion
from identity import config, store
from tests import fake_firestore


class _Blob:
    def __init__(self, objects, key):
        self._objects, self._key = objects, key

    def delete(self):
        self._objects.discard(self._key)


class _Bucket:
    def __init__(self, objects, name):
        self._objects, self._name = objects, name

    def list_blobs(self, prefix):
        return [
            _Blob(self._objects, (b, p))
            for b, p in sorted(self._objects, key=str)
            if b == self._name and p.startswith(prefix)
        ]


@pytest.fixture
def objects(monkeypatch):
    """Cloud Storage, in memory: {(bucket or None, path)}. Never the network."""
    from firebase_admin import storage

    held: set = set()
    monkeypatch.setattr(storage, "bucket", lambda name=None, app=None: _Bucket(held, name))
    return held


@pytest.fixture
def fs(monkeypatch, objects):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    return db


def _record(fs, uid="her"):
    return fs.docs.get(f"deletionRequests/{uid}")


def _late_writes(fs, uid="her"):
    fs.collection(config.COL_USERS).document(uid).set({"profile": {"goal": "x"}})
    fs.collection(config.COL_USERS).document(uid).collection("checkins").document("c1").set({"a": 1})
    fs.collection("plans").document(uid).collection("weeks").document("w1").set({"a": 1})


def _her_docs(fs, uid="her"):
    return [
        p for p in fs.docs
        if p.startswith(f"{config.COL_USERS}/{uid}") or p.startswith(f"plans/{uid}")
    ]


def test_done_records_when_the_second_sweep_is_due(fs):
    backend = deletion.FirebaseBackend()
    backend.set_state("her", "requested")
    before = dt.datetime.now(dt.timezone.utc)
    backend.finish_record("her")
    record = _record(fs)
    assert record["state"] == "done"
    assert set(record) <= deletion.DELETION_RECORD_FIELDS
    due = record["sweepAfter"]
    assert due >= before + dt.timedelta(minutes=config.DELETION_RESWEEP_MINUTES)
    assert due <= dt.datetime.now(dt.timezone.utc) + dt.timedelta(
        minutes=config.DELETION_RESWEEP_MINUTES
    )
    assert config.DELETION_RESWEEP_MINUTES == 65


def test_the_second_sweep_runs_once_when_due_and_removes_late_writes(fs):
    backend = deletion.FirebaseBackend()
    backend.finish_record("her")
    _late_writes(fs)
    due = _record(fs)["sweepAfter"]

    assert deletion.due_resweeps(fs, due - dt.timedelta(minutes=1)) == []
    assert deletion.due_resweeps(fs, due) == ["her"]

    deletion.resweep("her", backend)
    assert _her_docs(fs) == []
    record = _record(fs)
    assert record["state"] == "done" and "sweepAfter" not in record
    assert "sweptAt" in record
    assert set(record) <= deletion.DELETION_RECORD_FIELDS
    # Once: it is not picked up again.
    assert deletion.due_resweeps(fs, due + dt.timedelta(days=1)) == []


def test_someone_elses_data_is_untouched(fs):
    backend = deletion.FirebaseBackend()
    backend.finish_record("her")
    _late_writes(fs, uid="other")
    deletion.resweep("her", backend)
    assert len(_her_docs(fs, uid="other")) == 3


def test_resume_account_deletions_performs_due_sweeps(fs, monkeypatch):
    backend = deletion.FirebaseBackend()
    backend.finish_record("her")
    _late_writes(fs)
    fs.docs["deletionRequests/her"]["sweepAfter"] = dt.datetime(
        2000, 1, 1, tzinfo=dt.timezone.utc
    )
    main.resume_account_deletions.__wrapped__(None) if hasattr(
        main.resume_account_deletions, "__wrapped__"
    ) else main.resume_account_deletions(None)
    assert _her_docs(fs) == []
    assert "sweepAfter" not in _record(fs)


def test_the_second_sweep_purges_uploads_made_after_done(fs, objects):
    """B1: a still-valid token can upload after the purge, in either bucket."""
    backend = deletion.FirebaseBackend()
    backend.finish_record("her")
    for bucket in (None, deletion.PERSONAL_BUCKET):
        objects.add((bucket, "user-media/her/late.jpg"))
        objects.add((bucket, "coach-docs/her/late.jpg"))
        objects.add((bucket, "user-media/other/keep.jpg"))
    deletion.resweep("her", backend)
    assert sorted(objects, key=str) == sorted(
        [(None, "user-media/other/keep.jpg"), (deletion.PERSONAL_BUCKET, "user-media/other/keep.jpg")],
        key=str,
    )
