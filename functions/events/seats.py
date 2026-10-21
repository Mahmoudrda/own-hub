"""Seats for an event: reserve, give back, and release on account deletion.

The count lives on events/{id}.seatsTaken and her place on
events/{id}/attendees/{uid}. Both move in one transaction, so a count can never
disagree with the list, and a second tap changes nothing. Clients cannot write
either (firebase/firestore.rules), so this module is the only writer.
"""

from __future__ import annotations

import datetime as dt
import re

from google.cloud import firestore

COLLECTION = "events"
ATTENDEES = "attendees"
ID = re.compile(r"^[A-Za-z0-9_-]{1,100}$")

NOT_FOUND = "event_not_found"
FULL = "event_full"
CLOSED = "event_closed"


class SeatError(Exception):
    def __init__(self, kind: str, reason: str):
        super().__init__(reason)
        self.kind = kind
        self.reason = reason


def _count(event: dict) -> int:
    value = event.get("seatsTaken")
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else 0


def _capacity(event: dict):
    value = event.get("capacity")
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else None


def _ended(event: dict, now: dt.datetime) -> bool:
    ends = event.get("endsAt")
    if not isinstance(ends, dt.datetime):
        return True
    if ends.tzinfo is None:
        ends = ends.replace(tzinfo=dt.timezone.utc)
    return ends <= now


def _started(event: dict, now: dt.datetime) -> bool:
    starts = event.get("startsAt")
    if not isinstance(starts, dt.datetime):
        return True
    if starts.tzinfo is None:
        starts = starts.replace(tzinfo=dt.timezone.utc)
    return starts <= now


def register(db, uid: str, event_id: str, now: dt.datetime | None = None) -> dict:
    """Reserves her seat. Raises SeatError(NOT_FOUND | CLOSED | FULL). A new
    booking is refused once the event has started; a seat she already holds is
    still answered, and cancel works at any time."""
    now = now or dt.datetime.now(dt.timezone.utc)
    event_ref = db.collection(COLLECTION).document(event_id)
    attendee_ref = event_ref.collection(ATTENDEES).document(uid)

    @firestore.transactional
    def txn(transaction):
        snapshot = event_ref.get(transaction=transaction)
        attendee = attendee_ref.get(transaction=transaction)
        if not snapshot.exists:
            raise SeatError("not_found", NOT_FOUND)
        event = snapshot.to_dict() or {}
        capacity = _capacity(event)
        taken = _count(event)
        if event.get("status") != "published" or _ended(event, now) or capacity is None:
            raise SeatError("closed", CLOSED)
        if attendee.exists:
            return {"registered": True, "seatsTaken": taken, "capacity": capacity}
        if _started(event, now):
            raise SeatError("closed", CLOSED)
        if taken >= capacity:
            raise SeatError("full", FULL)
        transaction.set(
            attendee_ref,
            {"uid": uid, "joinedAt": firestore.SERVER_TIMESTAMP, "status": "registered"},
        )
        transaction.update(event_ref, {"seatsTaken": taken + 1})
        return {"registered": True, "seatsTaken": taken + 1, "capacity": capacity}

    return txn(db.transaction())


def cancel(db, uid: str, event_id: str) -> dict:
    """Gives her seat back. Works on a closed or finished event too, so a woman
    is never stuck holding a seat. Raises SeatError(NOT_FOUND)."""
    event_ref = db.collection(COLLECTION).document(event_id)
    attendee_ref = event_ref.collection(ATTENDEES).document(uid)

    @firestore.transactional
    def txn(transaction):
        snapshot = event_ref.get(transaction=transaction)
        attendee = attendee_ref.get(transaction=transaction)
        if not snapshot.exists:
            raise SeatError("not_found", NOT_FOUND)
        event = snapshot.to_dict() or {}
        taken = _count(event)
        if attendee.exists:
            taken = max(0, taken - 1)
            transaction.delete(attendee_ref)
            transaction.update(event_ref, {"seatsTaken": taken})
        return {"registered": False, "seatsTaken": taken, "capacity": _capacity(event)}

    return txn(db.transaction())


def release_all(db, uid: str) -> int:
    """Account deletion: removes her place on every event and gives each seat
    back. Events are few, so each is checked by id rather than by a
    collection-group query (which would need an index). Returns how many."""
    released = 0
    for snapshot in db.collection(COLLECTION).select([]).stream():
        event_ref = snapshot.reference
        attendee_ref = event_ref.collection(ATTENDEES).document(uid)

        @firestore.transactional
        def txn(transaction, event_ref=event_ref, attendee_ref=attendee_ref):
            attendee = attendee_ref.get(transaction=transaction)
            if not attendee.exists:
                return False
            event = event_ref.get(transaction=transaction)
            transaction.delete(attendee_ref)
            if event.exists:
                transaction.update(
                    event_ref, {"seatsTaken": max(0, _count(event.to_dict() or {}) - 1)}
                )
            return True

        if txn(db.transaction()):
            released += 1
    return released
