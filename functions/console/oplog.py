"""The console logs: what happened, in codes, newest first, a page at a time.

Six kinds, each read from a Firestore collection the system already writes:

    decisions   verificationJobs            outcome, reason codes, case ref
    reviews     verificationReviewAccess    reviewer action, case ref, reviewer ref
    deletions   deletionRequests            state and timings, no reference at all
    waitlist    waitlist                    joins per day, counts only
    errors      opsErrors                   function errors per day, by event code
    access      adminAccessLog              who opened the console, by ref

Every row is built field by field from an allowlist. Nothing is copied through
from a document, so a field added to a job tomorrow cannot leak through here.
A "case ref" is access.short_ref of the document id: the same case shows the
same ref in the decisions and the reviews logs, and no ref is an id.

Paging is by time: `before` is the ISO timestamp of the last row on the page,
and the next page is everything strictly older. The waitlist kind is not paged,
it is the last WAITLIST_DAYS days.
"""

from __future__ import annotations

import datetime as dt
from typing import Optional

from identity import config, decisions, reasons

from . import access
from .dashboard import count

KINDS = ("decisions", "reviews", "deletions", "waitlist", "errors", "access")
DEFAULT_LIMIT = 25
MAX_LIMIT = 50
WAITLIST_DAYS = 14

OPS_ERRORS = "opsErrors"
"""opsErrors/{yyyy-mm-dd} = {<event code>: count}. Written by logs.error."""

REVIEW_ACTIONS = frozenset({"list", "contact", "schedule", "decide", "reviewerBypass"})
"""What review.py and main.py write. `schedule:video` is read as `schedule`:
the route is the woman's choice of how to be met, and the log does not need it."""

_NOT_A_CASE = frozenset({"*", "store-review"})


class LogRequestError(ValueError):
    """A request the console does not serve. Always a code, never input."""


def _iso(value) -> Optional[str]:
    if not isinstance(value, dt.datetime):
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc).isoformat()


def _parse_before(raw) -> Optional[dt.datetime]:
    if raw is None:
        return None
    if not isinstance(raw, str) or len(raw) > 40:
        raise LogRequestError("bad_cursor")
    try:
        value = dt.datetime.fromisoformat(raw)
    except ValueError:
        raise LogRequestError("bad_cursor")
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value


def _limit(raw) -> int:
    if raw is None:
        return DEFAULT_LIMIT
    if not isinstance(raw, int) or isinstance(raw, bool):
        raise LogRequestError("bad_limit")
    return max(1, min(MAX_LIMIT, raw))


def _codes(values) -> list:
    """Reason codes this system defines, and nothing else."""
    return [c for c in (values or []) if isinstance(c, str) and c in reasons.ALL]


def _paged(query, field: str, before, limit: int):
    from google.cloud import firestore

    query = query.order_by(field, direction=firestore.Query.DESCENDING)
    if before is not None:
        query = query.where(field, "<", before)
    return list(query.limit(limit).stream())


def _decisions(db, before, limit, outcome):
    jobs = db.collection(config.COL_VERIFICATION_JOBS)
    if outcome is not None:
        if outcome not in decisions.OUTCOMES:
            raise LogRequestError("bad_outcome")
        jobs = jobs.where("state", "==", outcome)
    rows = []
    for snapshot in _paged(jobs, "decidedAt", before, limit):
        data = snapshot.to_dict() or {}
        state = data.get("state")
        rows.append(
            {
                "at": _iso(data.get("decidedAt")),
                "outcome": state if state in decisions.OUTCOMES else None,
                "reasons": _codes(data.get("reasons")),
                "case": access.short_ref(snapshot.id),
            }
        )
    return rows


def _reviews(db, before, limit, _outcome):
    log = db.collection(config.COL_REVIEW_ACCESS)
    rows = []
    for snapshot in _paged(log, "at", before, limit):
        data = snapshot.to_dict() or {}
        action = str(data.get("action") or "").split(":", 1)[0]
        flag_id = data.get("flagId")
        rows.append(
            {
                "at": _iso(data.get("at")),
                "action": action if action in REVIEW_ACTIONS else None,
                "case": None if flag_id in _NOT_A_CASE else access.short_ref(flag_id),
                "reviewer": access.short_ref(data.get("reviewerUid")),
            }
        )
    return rows


def _deletions(db, before, limit, _outcome):
    from account import deletion

    known = set(deletion.JOURNAL) | {deletion.FAILED_RETRYABLE}
    requests = db.collection("deletionRequests")
    rows = []
    for snapshot in _paged(requests, "updatedAt", before, limit):
        data = snapshot.to_dict() or {}
        state = data.get("state")
        rows.append(
            {
                "at": _iso(data.get("updatedAt")),
                "state": state if state in known else None,
                "requestedAt": _iso(data.get("requestedAt")),
                "doneAt": _iso(data.get("doneAt")),
                "swept": data.get("sweptAt") is not None,
            }
        )
    return rows


def _waitlist(db, now: dt.datetime):
    entries = db.collection("waitlist")
    today = now.astimezone(dt.timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    rows = []
    for back in range(WAITLIST_DAYS):
        start = today - dt.timedelta(days=back)
        end = start + dt.timedelta(days=1)
        joined = count(entries.where("at", ">=", start).where("at", "<", end))
        rows.append({"day": start.date().isoformat(), "joined": joined})
    return rows


def _errors(db, before, limit, _outcome):
    from google.cloud import firestore

    days = db.collection(OPS_ERRORS)
    query = days.order_by("day", direction=firestore.Query.DESCENDING)
    if before is not None:
        query = query.where("day", "<", before.date().isoformat())
    rows = []
    for snapshot in query.limit(limit).stream():
        data = snapshot.to_dict() or {}
        counts = data.get("counts") or {}
        rows.append(
            {
                "day": data.get("day") if isinstance(data.get("day"), str) else None,
                "counts": {
                    str(event): int(n)
                    for event, n in sorted(counts.items())
                    if isinstance(n, int) and _is_code(event)
                },
            }
        )
    return rows


def _access(db, before, limit, _outcome):
    log = db.collection(access.COLLECTION)
    rows = []
    for snapshot in _paged(log, "at", before, limit):
        data = snapshot.to_dict() or {}
        action = data.get("action")
        admin = data.get("admin")
        rows.append(
            {
                "at": _iso(data.get("at")),
                "action": action if action in access.ACTIONS else None,
                "admin": admin if isinstance(admin, str) and len(admin) == 8 else None,
            }
        )
    return rows


def _is_code(value) -> bool:
    """An event code: lower snake case, short, no digits run. Never free text."""
    import re

    return isinstance(value, str) and re.fullmatch(r"[a-z][a-z_]{0,47}", value) is not None


_READERS = {
    "decisions": _decisions,
    "reviews": _reviews,
    "deletions": _deletions,
    "errors": _errors,
    "access": _access,
}


def page(db, data: dict, now: dt.datetime) -> dict:
    """One page of one log. `data` is the callable's body:
    {kind, before?, limit?, outcome?}."""
    kind = data.get("kind")
    if kind not in KINDS:
        raise LogRequestError("bad_kind")
    if kind == "waitlist":
        return {"kind": kind, "rows": _waitlist(db, now), "next": None}
    before = _parse_before(data.get("before"))
    limit = _limit(data.get("limit"))
    outcome = data.get("outcome")
    if outcome is not None and kind != "decisions":
        raise LogRequestError("bad_outcome")
    rows = _READERS[kind](db, before, limit, outcome)
    last = rows[-1] if len(rows) == limit else None
    if last is None:
        cursor = None
    elif kind == "errors":
        cursor = f"{last['day']}T00:00:00+00:00" if last.get("day") else None
    else:
        cursor = last.get("at")
    return {"kind": kind, "rows": rows, "next": cursor}


def record_error(db, event: str, now: Optional[dt.datetime] = None) -> None:
    """Count one function error under today's opsErrors document.

    The event code only: logs.error is called with codes such as
    `account_deletion_failed`, and a code that is not lower snake case is not
    counted at all rather than stored."""
    if not _is_code(event):
        return
    from google.cloud import firestore

    at = now or dt.datetime.now(dt.timezone.utc)
    day = at.astimezone(dt.timezone.utc).date().isoformat()
    db.collection(OPS_ERRORS).document(day).set(
        {
            "day": day,
            "counts": {event: firestore.Increment(1)},
            "expireAt": at + dt.timedelta(days=ERRORS_RETENTION_DAYS),
        },
        merge=True,
    )


ERRORS_RETENTION_DAYS = 90
"""A daily count of error codes, with no person in it, kept for a quarter."""
