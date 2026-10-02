"""S13 and S16: the queries the functions run have their indexes, and the TTL
fields have their policies declared next to them.

Reads firebase/firestore.indexes.json as text, the way the app's own index test
does, so it runs with no emulator and no project.
"""

from __future__ import annotations

import json
import os

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_INDEXES = os.path.join(_ROOT, "firebase", "firestore.indexes.json")


def _spec() -> dict:
    with open(_INDEXES, encoding="utf-8") as handle:
        return json.load(handle)


def _composite(group: str, fields: list[str]) -> bool:
    for index in _spec()["indexes"]:
        if index["collectionGroup"] != group:
            continue
        if [f["fieldPath"] for f in index["fields"]] == fields:
            return True
    return False


def test_expire_stale_reviews_has_its_composite_index():
    # state == PENDING_REVIEW and slaExpiresAt < now: equality plus a range on a
    # second field. Without the composite the hourly job fails on every run.
    assert _composite("verification_flags", ["state", "slaExpiresAt"])


def test_the_reviewer_queue_has_its_composite_index():
    assert _composite("verification_flags", ["state", "createdAt"])


def test_ttl_policies_are_declared_for_the_three_expiring_collections():
    ttl = {
        (o["collectionGroup"], o["fieldPath"])
        for o in _spec()["fieldOverrides"]
        if o.get("ttl") is True
    }
    assert ttl == {
        ("verificationSessions", "expiresAt"),
        ("verificationJobs", "expireAt"),
        ("verification_flags", "expireAt"),
    }


def test_no_ttl_on_the_registry_or_the_access_log():
    for o in _spec()["fieldOverrides"]:
        if o.get("ttl"):
            assert o["collectionGroup"] not in {"nidRegistry", "verificationReviewAccess"}


def test_every_entry_says_why_and_every_override_exempts():
    spec = _spec()
    for index in spec["indexes"]:
        assert index.get("_why")
    for override in spec["fieldOverrides"]:
        assert override.get("_why")
        assert override["indexes"] == []
