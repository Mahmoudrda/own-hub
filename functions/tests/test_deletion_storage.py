"""B1: every Storage place that holds a woman's files is purged on deletion, in
both buckets, and again by the late sweep.

The places, from the app and the rules:
  user-media/{uid}/    community post media, profile photos, coach portfolio
                       media, message attachments and voice notes (G7 §1.3:
                       the one prefix the community and coach-media groups own)
  user-exports/{uid}/  her data export (row 25)
  coach-docs/{uid}/    a coach's certificate scans (coach_credentials.dart,
                       G12 §6)

ID and selfie images and progress photos have no Storage path at all
(storage.rules), so there is nothing to purge for them.
"""

from __future__ import annotations

import os
import re

from account import deletion
from tests.test_account_deletion import FakeBackend

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_RULES = os.path.join(_ROOT, "firebase", "storage.rules")
_APP_LIB = os.path.join(_ROOT, "app", "lib")

PERSONAL = deletion.PERSONAL_BUCKET


def _seeded(uid="her"):
    fake = FakeBackend(uid=uid)
    for bucket in (None, PERSONAL):
        fake.storage |= {
            (bucket, f"user-media/{uid}/posts/p1/a.jpg"),
            (bucket, f"user-media/{uid}/avatar.jpg"),
            (bucket, f"user-media/{uid}/voice/v1.m4a"),
            (bucket, f"user-media/{uid}/portfolio/m1.mp4"),
            (bucket, f"user-exports/{uid}/export.zip"),
            (bucket, f"coach-docs/{uid}/cert-1.jpg"),
            (bucket, "coach-docs/someone/cert-1.jpg"),
        }
    return fake


def _hers(fake, uid="her"):
    return sorted((b or "", p) for b, p in fake.storage if f"/{uid}/" in p)


def test_the_storage_prefixes_cover_every_place_she_has_files():
    assert set(deletion.STORAGE_PREFIXES) == {
        "user-media/{uid}/",
        "user-exports/{uid}/",
        "coach-docs/{uid}/",
    }


def test_deletion_purges_every_prefix_in_both_buckets():
    fake = _seeded()
    deletion.run("her", fake)
    assert _hers(fake) == []
    # Nobody else's files are touched.
    assert (None, "coach-docs/someone/cert-1.jpg") in fake.storage
    assert (PERSONAL, "coach-docs/someone/cert-1.jpg") in fake.storage
    assert (None, "user-media/someone/c.jpg") in fake.storage
    calls = {c[1:] for c in fake.calls if c[0] == "delete_storage_prefix"}
    for bucket in (None, PERSONAL):
        for prefix in deletion.STORAGE_PREFIXES:
            assert (bucket, prefix.format(uid="her")) in calls


def test_the_late_sweep_purges_storage_written_after_done():
    """A still-valid token can upload for up to an hour after the purge."""
    fake = FakeBackend()
    deletion.run("her", fake)
    late = _seeded()
    fake.storage |= late.storage
    assert _hers(fake)
    deletion.resweep("her", fake)
    assert _hers(fake) == []
    assert (None, "coach-docs/someone/cert-1.jpg") in fake.storage
    assert fake.record.get("sweptAt")
    names = [c[0] for c in fake.calls]
    # Marked swept only after the storage purge, so a failure re-runs it.
    assert names.index("mark_swept") > max(
        i for i, n in enumerate(names) if n == "delete_storage_prefix"
    )


def test_a_failed_storage_purge_in_the_late_sweep_does_not_mark_it_swept():
    fake = FakeBackend()
    deletion.run("her", fake)
    fake.fail_at = "delete_storage_prefix"
    try:
        deletion.resweep("her", fake)
    except RuntimeError:
        pass
    assert "sweptAt" not in fake.record and fake.record.get("sweepAfter")


# ---------------------------------------------------- nothing left out later


def _prefix(path: str) -> str:
    return path.split("/", 1)[0]


def test_every_uid_keyed_storage_rule_path_is_purged():
    """A media group that adds `match /x/{uid}/...` to storage.rules must add
    x/{uid}/ to STORAGE_PREFIXES, or this fails."""
    source = open(_RULES, encoding="utf-8").read()
    purged = {_prefix(p) for p in deletion.STORAGE_PREFIXES}
    keyed = set(re.findall(r"match\s+/([A-Za-z0-9_-]+)/\{[A-Za-z]*[uU]id\}", source))
    assert keyed, "expected at least user-exports/{uid} in storage.rules"
    assert keyed <= purged, sorted(keyed - purged)


# Firestore collections that the app also names as 'x/$uid/...'. Anything else
# with that shape is a Storage path and must be purged.
_FIRESTORE = {"users", "coaches", "plans", "relationships", "followGraph", "posts"}


def test_every_uid_keyed_path_the_app_names_is_firestore_or_purged():
    if not os.path.isdir(_APP_LIB):  # pragma: no cover - functions-only checkout
        return
    found = set()
    for folder, _, files in os.walk(_APP_LIB):
        for name in files:
            if not name.endswith(".dart") or name.endswith(".g.dart"):
                continue
            text = open(os.path.join(folder, name), encoding="utf-8").read()
            found |= set(
                re.findall(r"'([a-z][A-Za-z0-9-]*)/\$\{?[A-Za-z.]*[uU]id\}?/", text)
            )
    assert "coach-docs" in found
    purged = {_prefix(p) for p in deletion.STORAGE_PREFIXES}
    assert found - _FIRESTORE <= purged, sorted(found - _FIRESTORE - purged)
