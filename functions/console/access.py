"""Who opened the console, and a short reference that is not an identifier.

Every admin read of the dashboard or the logs writes one line here, in the same
spirit as verificationReviewAccess: a capability that shows operational data is
a capability that needs a record of every use.

The line holds a short reference to the admin, never her uid. The reference is
a salted digest cut to eight hex characters: enough to tell two admins apart in
a list of a handful, and not a key that joins to anything else in the project.
That keeps adminAccessLog out of the deletion manifest (it is not keyed by a
person) and it expires by TTL a year after the read, like the reviewer log.
"""

from __future__ import annotations

import datetime as dt
import hashlib
from typing import Optional

COLLECTION = "adminAccessLog"
RETENTION_DAYS = 365
"""One year, matching config.ACCESS_LOG_RETENTION_DAYS for the reviewer log.
PENDING COUNSEL, like every retention period in this project."""

ACTIONS = frozenset(
    {
        "dashboard",
        "logs.decisions",
        "logs.reviews",
        "logs.deletions",
        "logs.waitlist",
        "logs.errors",
        "logs.access",
    }
)

_SALT = "ownhub-console-ref-v1:"


def short_ref(value: Optional[str]) -> Optional[str]:
    """Eight hex characters standing for a document id. None stays None.

    The same input always gives the same reference, so a case seen in the
    decisions log and again in the review log reads as the same case. It is
    not reversible without the id itself, which the console never returns.
    """
    if not isinstance(value, str) or not value:
        return None
    return hashlib.sha256((_SALT + value).encode("utf-8")).hexdigest()[:8]


def entry(admin_uid: str, action: str, now: dt.datetime) -> dict:
    """The one document a console read writes. No uid, no query, no result."""
    if action not in ACTIONS:
        raise ValueError(f"unknown console action {action!r}")
    return {
        "admin": short_ref(admin_uid),
        "action": action,
        "at": now,
        "expireAt": now + dt.timedelta(days=RETENTION_DAYS),
    }


def record(db, admin_uid: str, action: str, now: Optional[dt.datetime] = None) -> None:
    """Write the access line. Raises if it cannot be written: a read that
    cannot be recorded is a read that does not happen (see main.py)."""
    at = now or dt.datetime.now(dt.timezone.utc)
    db.collection(COLLECTION).add(entry(admin_uid, action, at))
