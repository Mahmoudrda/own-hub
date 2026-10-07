"""The console dashboard: counts, and nothing that names anyone.

Every number here is a Firestore aggregation (`count()`), which bills one read
per thousand index entries it scans instead of one read per document, so the
whole dashboard costs a few dozen reads however large the product grows. No
document body is read except the single oldest open review flag, and from that
only its `createdAt`.

What it returns, and what it deliberately does not:

    members      accounts, and how many are verified
    reviews      open human reviews, how many are past the SLA, and the age of
                 the oldest in hours against config.REVIEW_SLA_HOURS
    outcomes     verification outcomes in the last 7 and 30 days, by code
    waitlist     how many entries the list holds
    deletions    deletion requests still running, and finished
    events       published events still to come, and drafts
    content      rows in each content library collection

No name, phone, uid, flag id, job id, reason text or health field is ever in
the answer. tests/test_console.py walks every key and value to hold that.

The answer is cached in the instance for CACHE_SECONDS: the owner opening the
dashboard twice in a minute should not pay twice. `refresh` skips the cache.
"""

from __future__ import annotations

import datetime as dt
import time
from typing import Callable, Optional

from identity import config, decisions

EVENTS = "events"
CONTENT_COLLECTIONS = ("exercises", "foods", "recipes", "programs")
WINDOWS_DAYS = (7, 30)
CACHE_SECONDS = 300

# Mirrors account/deletion.py, read here rather than imported so the dashboard
# never loads the deletion machinery.
_DELETION_DONE = "done"


def count(query) -> int:
    """`query.count()`, as a plain int.

    The server answers one list of aggregation results per partition; there is
    one partition and one alias here."""
    rows = query.count(alias="n").get()
    for row in rows:
        items = row if isinstance(row, (list, tuple)) else [row]
        for item in items:
            return int(item.value)
    return 0


def _as_utc(value) -> Optional[dt.datetime]:
    if not isinstance(value, dt.datetime):
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc)


def _members(db) -> dict:
    users = db.collection(config.COL_USERS)
    return {
        "total": count(users),
        "verified": count(users.where("verification.state", "==", "approved")),
    }


def _reviews(db, now: dt.datetime) -> dict:
    flags = db.collection(config.COL_FLAGS)
    open_flags = flags.where("state", "==", decisions.PENDING_REVIEW)
    oldest_hours = None
    for snapshot in open_flags.order_by("createdAt").limit(1).stream():
        created = _as_utc((snapshot.to_dict() or {}).get("createdAt"))
        if created is not None:
            oldest_hours = max(0, int((now - created).total_seconds() // 3600))
    return {
        "pending": count(open_flags),
        "overSla": count(
            flags.where("state", "==", decisions.PENDING_REVIEW).where(
                "slaExpiresAt", "<", now
            )
        ),
        "oldestHours": oldest_hours,
        "slaHours": config.REVIEW_SLA_HOURS,
    }


def _outcomes(db, now: dt.datetime) -> dict:
    jobs = db.collection(config.COL_VERIFICATION_JOBS)
    out = {}
    for days in WINDOWS_DAYS:
        since = now - dt.timedelta(days=days)
        out[str(days)] = {
            code: count(jobs.where("state", "==", code).where("decidedAt", ">=", since))
            for code in sorted(decisions.OUTCOMES)
        }
    return out


def _deletions(db) -> dict:
    from account import deletion

    requests = db.collection("deletionRequests")
    return {
        "pending": count(requests.where("state", "in", deletion.UNFINISHED_STATES)),
        "done": count(requests.where("state", "==", _DELETION_DONE)),
    }


def _events(db, now: dt.datetime) -> dict:
    events = db.collection(EVENTS)
    return {
        "upcoming": count(
            events.where("status", "==", "published").where("endsAt", ">=", now)
        ),
        "drafts": count(events.where("status", "==", "draft")),
    }


def build(db, now: dt.datetime) -> dict:
    """The whole dashboard, computed now."""
    return {
        "generatedAt": now.astimezone(dt.timezone.utc).isoformat(),
        "members": _members(db),
        "reviews": _reviews(db, now),
        "outcomes": _outcomes(db, now),
        "waitlist": {"total": count(db.collection("waitlist"))},
        "deletions": _deletions(db),
        "events": _events(db, now),
        "content": {name: count(db.collection(name)) for name in CONTENT_COLLECTIONS},
    }


_cache: dict = {}


def cached(
    db,
    now: dt.datetime,
    *,
    refresh: bool = False,
    clock: Callable[[], float] = time.monotonic,
) -> dict:
    """[build], or the answer from the last CACHE_SECONDS in this instance."""
    at = _cache.get("at")
    if not refresh and at is not None and clock() - at < CACHE_SECONDS:
        return _cache["data"]
    data = build(db, now)
    _cache["at"] = clock()
    _cache["data"] = data
    return data


def clear_cache() -> None:
    _cache.clear()
