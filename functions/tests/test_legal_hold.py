"""A deleted coach's signed agreement is kept, server-only, for 5 years."""

from __future__ import annotations

import datetime as dt

import pytest

from account import deletion, legal_hold
from tests.test_account_deletion import FakeBackend
from tests.test_deletion_coaching import fs  # noqa: F401

HER = "uid-her"
OTHER = "uid-other"
NOW = dt.datetime(2026, 11, 1, 9, tzinfo=dt.timezone.utc)


class FakeBlob:
    def __init__(self, name):
        self.name = name


class FakeBucket:
    def __init__(self, names):
        self.names = set(names)

    def list_blobs(self, prefix=""):
        return [FakeBlob(n) for n in sorted(self.names) if n.startswith(prefix)]

    def copy_blob(self, blob, bucket, name):
        self.names.add(name)


def seed(fs, agreement=True):
    d = fs.docs
    if agreement:
        d[f"coachPrivate/{HER}"] = {
            "fullName": "Her", "owedEgp": 0,
            "agreement": {"version": 2, "status": "verified", "path": f"coach-docs/{HER}/agreement/a.pdf"},
        }
        d[f"users/{HER}/consents/coach-terms-v2"] = {"version": 2, "at": NOW, "locale": "en", "textHash": "abc"}
        d[f"users/{HER}/consents/coaching-share-v1"] = {"version": 1}
    d[f"users/{HER}"] = {"profile": {}}
    d[f"coachPrivate/{OTHER}"] = {"agreement": {"version": 2, "status": "verified"}}


def delete_account(fs, monkeypatch, bucket):
    from firebase_admin import storage

    monkeypatch.setattr(storage, "bucket", lambda name=None: bucket)
    backend = deletion.FirebaseBackend()
    backend.retain_legal_hold(HER)
    backend.purge_group_hook(HER)
    backend.delete_user_tree(HER)
    for prefix in deletion.STORAGE_PREFIXES:
        bucket.names = {n for n in bucket.names if not n.startswith(prefix.format(uid=HER))}


def test_deletion_keeps_the_hold_and_everything_else_is_gone(fs, monkeypatch):
    seed(fs)
    bucket = FakeBucket({f"coach-docs/{HER}/agreement/a.pdf", f"coach-docs/{HER}/photo/p.jpg"})
    delete_account(fs, monkeypatch, bucket)

    hold = fs.docs[f"{legal_hold.COLLECTION}/{HER}"]
    assert hold["agreement"]["status"] == "verified"
    assert set(hold["consents"]) == {"coach-terms-v2"} and hold["consents"]["coach-terms-v2"]["textHash"] == "abc"
    assert hold["files"] == [f"legal-hold/{HER}/agreement/a.pdf"]
    assert hold["retainUntil"] - hold["createdAt"] == dt.timedelta(days=legal_hold.RETENTION_DAYS)
    assert hold["retainUntil"] - hold["createdAt"] > dt.timedelta(days=5 * 365)

    assert bucket.names == {f"legal-hold/{HER}/agreement/a.pdf"}, "only the agreement copy is left"
    left = [p for p in fs.docs if HER in p and not p.startswith((legal_hold.COLLECTION, "deletionRequests"))]
    assert left == []
    assert f"coachPrivate/{OTHER}" in fs.docs


def test_a_retry_never_rewrites_or_extends_the_hold(fs, monkeypatch):
    seed(fs)
    bucket = FakeBucket({f"coach-docs/{HER}/agreement/a.pdf"})
    delete_account(fs, monkeypatch, bucket)
    first = dict(fs.docs[f"{legal_hold.COLLECTION}/{HER}"])
    deletion.FirebaseBackend().retain_legal_hold(HER)  # her data is gone now
    assert fs.docs[f"{legal_hold.COLLECTION}/{HER}"] == first


def test_a_woman_who_never_coached_leaves_no_hold(fs, monkeypatch):
    seed(fs, agreement=False)
    delete_account(fs, monkeypatch, FakeBucket(set()))
    assert not [p for p in fs.docs if p.startswith(legal_hold.COLLECTION)]


def test_the_hold_is_made_before_anything_is_deleted():
    fake = FakeBackend()
    deletion.run("her", fake)
    names = [c[0] for c in fake.calls]
    first_destructive = names.index(
        next(n for n in names if n.startswith("delete") or n in {"close_registry", "pseudonymise_reports"})
    )
    assert names.index("retain_legal_hold") < first_destructive


def test_a_failed_copy_stops_the_deletion_before_anything_is_removed():
    fake = FakeBackend(fail_at="retain_legal_hold")
    with pytest.raises(RuntimeError):
        deletion.run("her", fake)
    assert not [c for c in fake.calls if c[0].startswith("delete")]


def test_the_purge_job_deletes_a_hold_only_after_five_years(fs):
    removed = []
    legal_hold_doc = lambda uid, until: fs.docs.__setitem__(  # noqa: E731
        f"{legal_hold.COLLECTION}/{uid}", {"retainUntil": until, "files": []}
    )
    legal_hold_doc("old", NOW - dt.timedelta(days=1))
    legal_hold_doc("young", NOW + dt.timedelta(days=400))

    assert legal_hold.purge_due(fs, removed.append, NOW) == 1
    assert removed == ["legal-hold/old/agreement/"]
    assert f"{legal_hold.COLLECTION}/old" not in fs.docs
    assert f"{legal_hold.COLLECTION}/young" in fs.docs
    five_years_on = NOW + dt.timedelta(days=legal_hold.RETENTION_DAYS + 500)
    assert legal_hold.purge_due(fs, removed.append, five_years_on) == 1
    assert f"{legal_hold.COLLECTION}/young" not in fs.docs


def test_a_missing_bucket_with_a_signed_copy_refuses_instead_of_losing_it(fs, monkeypatch):
    from firebase_admin import storage
    from google.api_core import exceptions

    seed(fs)

    class Gone(FakeBucket):
        def list_blobs(self, prefix=""):
            raise exceptions.NotFound("no bucket")

    monkeypatch.setattr(storage, "bucket", lambda name=None: Gone(set()))
    with pytest.raises(exceptions.NotFound):
        deletion.FirebaseBackend().retain_legal_hold(HER)
    assert f"legalHolds/{HER}" not in fs.docs
    fs.docs[f"coachPrivate/{HER}"]["agreement"].pop("path")        # nothing to keep: it carries on
    deletion.FirebaseBackend().retain_legal_hold(HER)
    assert f"legalHolds/{HER}" in fs.docs
