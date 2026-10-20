"""Reviewer settings, free slots, booking and the reviewer's schedule.

Availability is typed in Cairo time (weekday 1 = Monday ... 7 = Sunday, the
ISO numbering Dart's DateTime.weekday also uses) and turned into UTC per date,
so daylight saving moves the slots, not the reviewer. Every start time on the
wire is one canonical UTC string, YYYY-MM-DDTHH:MM:SSZ, so a slot listed is a
slot that books. Queries here filter on one field only; the rest is done in
Python, so no composite index is needed.
"""

from __future__ import annotations

import datetime as dt
import re
from typing import Any, Optional
from zoneinfo import ZoneInfo

from google.cloud import firestore

from . import approvals, config, reasons, review, store

_CLOCK = re.compile(r"^([01][0-9]|2[0-3]):([0-5][0-9])$")
MAX_WINDOWS = 28
MAX_NAME = 40


def _cairo() -> ZoneInfo:
    # Looked up on use, so a runtime without a tz database fails a booking
    # call and not the import of every function.
    return ZoneInfo(config.REVIEW_TZ)


def _fail(kind: str, reason: str = reasons.INTERNAL_ERROR):
    raise review.ReviewError(kind, reason)


def canonical(when: dt.datetime) -> str:
    return when.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_start(value: Any) -> dt.datetime:
    when = review.parse_when(value)
    return when.replace(second=0, microsecond=0)


def _minutes(clock: str) -> int:
    hours, minutes = clock.split(":")
    return int(hours) * 60 + int(minutes)


# ---------------------------------------------------------------- settings


def get_settings(reviewer_uid: str) -> dict:
    data = approvals.reviewer_doc(reviewer_uid)
    return {
        "firstName": data.get("firstName") or "",
        "listed": bool(data.get("listed")),
        "autoPassKnown": bool(data.get("autoPassKnown")),
        "availability": list(data.get("availability") or []),
        "slotMinutes": data.get("slotMinutes") or config.REVIEW_SLOT_DEFAULT_MINUTES,
    }


def _clean_availability(raw: Any) -> list[dict]:
    if not isinstance(raw, list) or len(raw) > MAX_WINDOWS:
        _fail(review.INVALID)
    out = []
    for item in raw:
        if not isinstance(item, dict):
            _fail(review.INVALID)
        weekday, start, end = item.get("weekday"), item.get("start"), item.get("end")
        if isinstance(weekday, bool) or not isinstance(weekday, int) or not 1 <= weekday <= 7:
            _fail(review.INVALID)
        if not (
            isinstance(start, str)
            and isinstance(end, str)
            and _CLOCK.match(start)
            and _CLOCK.match(end)
            and _minutes(start) < _minutes(end)
        ):
            _fail(review.INVALID)
        out.append({"weekday": weekday, "start": start, "end": end})
    return sorted(out, key=lambda w: (w["weekday"], w["start"]))


def set_settings(reviewer_uid: str, data: dict) -> dict:
    name = data.get("firstName")
    if not isinstance(name, str) or len(name.strip()) > MAX_NAME:
        _fail(review.INVALID)
    name = name.strip()
    listed, auto = data.get("listed"), data.get("autoPassKnown")
    if not isinstance(listed, bool) or not isinstance(auto, bool):
        _fail(review.INVALID)
    if listed and not name:
        _fail(review.INVALID)
    minutes = data.get("slotMinutes", config.REVIEW_SLOT_DEFAULT_MINUTES)
    if isinstance(minutes, bool) or minutes not in config.REVIEW_SLOT_MINUTES:
        _fail(review.INVALID)
    availability = _clean_availability(data.get("availability", []))
    store.db().collection(config.COL_REVIEWERS).document(reviewer_uid).set(
        {
            "firstName": name,
            "listed": listed,
            "autoPassKnown": auto,
            "availability": availability,
            "slotMinutes": minutes,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return get_settings(reviewer_uid)


def list_reviewers() -> list[dict]:
    query = store.db().collection(config.COL_REVIEWERS).where("listed", "==", True).limit(50)
    out = []
    for snapshot in query.stream():
        name = (snapshot.to_dict() or {}).get("firstName")
        if isinstance(name, str) and name and approvals.reviewer_active(snapshot.id):
            out.append({"reviewerId": snapshot.id, "firstName": name})
    return sorted(out, key=lambda r: (r["firstName"], r["reviewerId"]))


# ------------------------------------------------------------------- slots


def _slot_starts(settings: dict, now: dt.datetime, days: int) -> list[dt.datetime]:
    step = settings.get("slotMinutes") or config.REVIEW_SLOT_DEFAULT_MINUTES
    earliest = now + dt.timedelta(minutes=config.REVIEW_SLOT_LEAD_MINUTES)
    horizon = now + dt.timedelta(days=days)
    today = now.astimezone(_cairo()).date()
    found: set[dt.datetime] = set()
    for offset in range(days + 1):
        day = today + dt.timedelta(days=offset)
        for window in settings.get("availability") or []:
            if window["weekday"] != day.isoweekday():
                continue
            at, end = _minutes(window["start"]), _minutes(window["end"])
            while at + step <= end:
                local = dt.datetime(day.year, day.month, day.day, at // 60, at % 60, tzinfo=_cairo())
                start = local.astimezone(dt.timezone.utc)
                if earliest <= start < horizon:
                    found.add(start)
                at += step
    return sorted(found)


def _booked(now: dt.datetime) -> dict[str, str]:
    """canonical start + reviewer -> uid, for bookings from an hour ago on."""
    since = canonical(now - dt.timedelta(hours=1))
    query = store.db().collection(config.COL_BOOKINGS).where("start", ">=", since).limit(2000)
    return {s.id: (s.to_dict() or {}).get("uid") for s in query.stream()}


def _slot_id(reviewer_id: str, start: dt.datetime) -> str:
    return f"{reviewer_id}_{start.astimezone(dt.timezone.utc).strftime('%Y%m%dT%H%MZ')}"


def list_slots(days: Any) -> list[dict]:
    if isinstance(days, bool) or not isinstance(days, int) or days < 1:
        days = config.REVIEW_BOOKING_MAX_DAYS
    days = min(days, config.REVIEW_BOOKING_MAX_DAYS)
    now = review._now()
    taken = _booked(now)
    out = []
    for reviewer in list_reviewers():
        settings = get_settings(reviewer["reviewerId"])
        for start in _slot_starts(settings, now, days):
            if _slot_id(reviewer["reviewerId"], start) not in taken:
                out.append({"reviewerId": reviewer["reviewerId"], "start": canonical(start)})
    return out


# ----------------------------------------------------------------- booking


def _book(uid: str, reviewer_id: str, start: dt.datetime) -> dict:
    """Take the slot, move her open flag to it, free any slot she held."""
    rs = store.FirestoreReviewStore()
    gate = store.verification_gate(uid)
    if gate.state != review.STATE_PENDING or not gate.open_flag_id:
        _fail(review.PRECONDITION, reasons.REVIEW_NOT_PENDING)
    flag_id = gate.open_flag_id
    ref = store.db().collection(config.COL_BOOKINGS).document(_slot_id(reviewer_id, start))

    @firestore.transactional
    def take(transaction):
        snapshot = ref.get(transaction=transaction)
        if snapshot.exists and (snapshot.to_dict() or {}).get("uid") != uid:
            return False
        transaction.set(
            ref,
            {
                "uid": uid,
                "reviewerId": reviewer_id,
                "start": canonical(start),
                "bookedAt": firestore.SERVER_TIMESTAMP,
                "expireAt": start + dt.timedelta(days=config.REVIEW_BOOKING_RETENTION_DAYS),
            },
        )
        return True

    if not take(store.db().transaction()):
        _fail(review.PRECONDITION, reasons.SLOT_UNAVAILABLE)
    record = rs.get_flag(flag_id) or {}
    sla = start + dt.timedelta(hours=config.REVIEW_BOOKING_GRACE_HOURS)
    current = review._as_utc(record.get("slaExpiresAt"))
    if current is not None and current > sla:
        sla = current
    refusal = rs.mark_scheduled(flag_id, "video", start, reviewer_id, sla)
    if refusal:
        ref.delete()
        _fail(review.PRECONDITION, refusal)
    approvals._drop_bookings(uid, keep=ref.id)
    rs.log_access(reviewer_id, flag_id, "schedule:slot")
    return {"scheduledFor": canonical(start)}


def book(uid: str, reviewer_id: Any, start_value: Any) -> dict:
    if not isinstance(reviewer_id, str) or not reviewer_id or reviewer_id == uid:
        _fail(review.INVALID)
    start = parse_start(start_value)
    now = review._now()
    settings = approvals.reviewer_doc(reviewer_id)
    if not settings.get("listed") or not approvals.reviewer_active(reviewer_id):
        _fail(review.PRECONDITION, reasons.SLOT_UNAVAILABLE)
    if start not in _slot_starts(get_settings(reviewer_id), now, config.REVIEW_BOOKING_MAX_DAYS):
        _fail(review.PRECONDITION, reasons.SLOT_UNAVAILABLE)
    return _book(uid, reviewer_id, start)


def reschedule(reviewer_uid: str, uid: Any, start_value: Any) -> dict:
    """The reviewer moves a woman to a time she picks, availability or not."""
    uid = approvals._uid(uid)
    if uid == reviewer_uid:
        _fail(review.PRECONDITION, reasons.REVIEWER_IS_SUBJECT)
    start = parse_start(start_value)
    now = review._now()
    tolerance = dt.timedelta(minutes=config.REVIEW_BOOKING_PAST_TOLERANCE_MINUTES)
    if start < now - tolerance or start > now + dt.timedelta(days=config.REVIEW_BOOKING_MAX_DAYS):
        _fail(review.INVALID, reasons.REVIEW_TIME_OUT_OF_RANGE)
    return _book(uid, reviewer_uid, start)


# ---------------------------------------------------------------- schedule


def list_schedule(reviewer_uid: str, from_value: Any, to_value: Any) -> list[dict]:
    frm, to = parse_start(from_value), parse_start(to_value)
    if to <= frm or to - frm > dt.timedelta(days=config.SCHEDULE_MAX_DAYS):
        _fail(review.INVALID)
    query = (
        store.db()
        .collection(config.COL_BOOKINGS)
        .where("start", ">=", canonical(frm))
        .limit(2000)
    )
    mine = []
    for snapshot in query.stream():
        data = snapshot.to_dict() or {}
        if data.get("reviewerId") == reviewer_uid and data.get("start", "") < canonical(to):
            mine.append(data)
    mine.sort(key=lambda b: b["start"])
    mine = mine[: config.QUEUE_MAX_ROWS * 2]
    rs = store.FirestoreReviewStore()
    uids = [b["uid"] for b in mine]
    users = approvals._names(uids)
    flags = {u: store.verification_gate(u).open_flag_id for u in uids}
    consented = rs.review_consented_flags([(u, f) for u, f in flags.items() if f])
    phones = approvals.phones_for([u for u, f in flags.items() if f in consented])
    rows = []
    for booking in mine:
        uid = booking["uid"]
        row = {"uid": uid, "start": booking["start"]}
        name = approvals._display_name(users.get(uid, {}))
        if name:
            row["displayName"] = name
        if flags.get(uid) in consented and uid in phones:
            row["phone"] = phones[uid]
            rs.log_access(reviewer_uid, flags[uid], "schedule:phone")
        rows.append(row)
    return rows
