"""Live sessions inside an active coaching subscription.

The coach proposes a time and a call link, the client confirms or declines, and
after the start each of them marks it done. A session counts against
the package, once both have marked it (`sessionsUsed`), which is what a cancellation refund is worked out
from, so the count moves in the same transaction as the session.

Sessions live at `subscriptions/{subId}/sessions/{sessionId}`; the chat gets a
card for each step in `relationships/{relId}/messages`.
"""

from __future__ import annotations

import datetime as dt
import re
from typing import Any
from urllib.parse import urlsplit

from google.cloud import firestore

from . import chat, common, errors, subscriptions

LIMITS = common.LIMITS
ENUMS = common.ENUMS
HOSTS = common.CONTRACT["sessionLinkHosts"]

LINK_MAX = 300
LEAD_MINUTES = 15

_FORBIDDEN_IN_LINK = re.compile(r"[\s\\\x00-\x1f\x7f]")


def parse_start(value: Any) -> dt.datetime:
    """An ISO-8601 time with an offset, as aware UTC. Anything else is refused."""
    if not isinstance(value, str) or not (10 <= len(value) <= 40):
        raise common.bad()
    try:
        parsed = dt.datetime.fromisoformat(value.strip())
    except ValueError:
        raise common.bad()
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise common.bad()
    return parsed.astimezone(dt.timezone.utc)


def host_allowed(host: str) -> bool:
    for allowed in HOSTS:
        if allowed.startswith("*."):
            suffix = allowed[1:]
            if host.endswith(suffix) and len(host) > len(suffix):
                return True
        elif host == allowed:
            return True
    return False


def check_link(link: Any) -> str:
    """https only, a host from the contract (or a subdomain of the wildcard
    ones), no credentials and no port."""
    bad = common.refuse(errors.INVALID, errors.SESSION_LINK_INVALID)
    if not isinstance(link, str) or not (1 <= len(link) <= LINK_MAX):
        raise bad
    if _FORBIDDEN_IN_LINK.search(link) or not link.isascii():
        raise bad
    try:
        parts = urlsplit(link)
        host = parts.hostname
        port = parts.port
    except ValueError:
        raise bad
    if parts.scheme != "https" or not host or port is not None:
        raise bad
    if "@" in parts.netloc or parts.netloc.lower() != host:
        raise bad
    if not host_allowed(host):
        raise bad
    if chat.has_contact_in_link(f"{parts.path} {parts.query} {parts.fragment}"):
        raise common.bad(errors.CONTAINS_CONTACT)
    return link


def _ids(data: dict) -> tuple[str, str]:
    return (
        common.text(data.get("subId"), max_len=128),
        common.text(data.get("sessionId"), max_len=128),
    )


def next_session_at(rows, now: dt.datetime, status_of: dict | None = None):
    """The earliest start, not yet past, among sessions that are proposed or
    confirmed; None when there is none. `status_of` maps a session id to the
    status it is about to have."""
    status_of = status_of or {}
    best = None
    for session_id, row in rows:
        status = status_of.get(session_id, row.get("status"))
        start = common.as_utc(row.get("startsAt"))
        if status in ("proposed", "confirmed") and start is not None and start >= now:
            best = start if best is None or start < best else best
    return best


def _frozen(sub: dict) -> bool:
    """A cancellation waiting for staff stops every session step."""
    return (sub.get("cancellation") or {}).get("state") == "requested"


def _messages(db, sub):
    return db.collection("relationships").document(sub["relId"]).collection("messages")


def schedule(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    coach_v: Any,
    now: dt.datetime,
    notify: common.Notify,
) -> dict:
    common.require_clients_live(live)
    common.require_active_coach(db, uid, coach_v)

    sub_id = common.text(data.get("subId"), max_len=128)
    starts_at = parse_start(data.get("startsAt"))
    minutes = common.whole(data.get("minutes"), low=0, high=1000)
    common.one_of(minutes, LIMITS["sessionMinutes"])
    if starts_at < now + dt.timedelta(minutes=LEAD_MINUTES):
        raise common.bad()
    link = check_link(data.get("link"))

    sub_ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        sub = common.read(sub_ref, transaction)
        if sub is None or sub.get("coachUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if sub.get("status") != "active" or _frozen(sub):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        if subscriptions.blocked_either(transaction, db, uid, sub.get("clientUid")):
            raise common.refuse(errors.PRECONDITION, errors.COACH_UNAVAILABLE)
        ends_at = common.as_utc(sub.get("endsAt"))
        if ends_at is not None and starts_at > ends_at:
            raise common.bad()
        sessions = sub_ref.collection("sessions")
        rows = [(row.id, row.to_dict() or {}) for row in sessions.stream(transaction=transaction)]
        counted = sum(1 for _, row in rows if row.get("status") not in ("cancelled", "declined"))
        if counted >= int(sub.get("sessionsIncluded") or 0):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        client_uid = sub.get("clientUid")
        session_ref = sessions.document()
        upcoming = next_session_at(rows + [(session_ref.id, {"status": "proposed", "startsAt": starts_at})], now)
        transaction.update(sub_ref, {"nextSessionAt": upcoming})
        transaction.set(
            session_ref,
            {
                "startsAt": starts_at,
                "minutes": minutes,
                "link": link,
                "status": "proposed",
                "proposedBy": uid,
                "createdAt": now,
                "statusAt": now,
            },
        )
        transaction.set(
            _messages(db, sub).document(),
            {
                "senderUid": uid,
                "type": "session",
                "sessionId": session_ref.id,
                "startsAt": starts_at,
                "minutes": minutes,
                "createdAt": now,
            },
        )
        return session_ref.id, client_uid

    session_id, client_uid = common.run(db, body)
    notify(client_uid, "sessionProposed")
    return {"sessionId": session_id}


def respond(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    now: dt.datetime,
) -> dict:
    """The client confirms or declines a proposed session. Nobody is pushed:
    the coach sees the card change in the chat."""
    common.require_clients_live(live)
    sub_id, session_id = _ids(data)
    decision = common.one_of(data.get("decision"), ENUMS["sessionDecision"])
    new_status = "confirmed" if decision == "confirm" else "declined"
    sub_ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        sub = common.read(sub_ref, transaction)
        if sub is None or sub.get("clientUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if sub.get("status") != "active" or _frozen(sub):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        session_ref = sub_ref.collection("sessions").document(session_id)
        session = common.read(session_ref, transaction)
        if session is None:
            raise common.refuse(errors.NOT_FOUND, errors.SESSION_NOT_FOUND)
        if session.get("status") != "proposed":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        rows = [(row.id, row.to_dict() or {}) for row in sub_ref.collection("sessions").stream(transaction=transaction)]
        transaction.update(session_ref, {"status": new_status, "statusAt": now})
        transaction.update(sub_ref, {"nextSessionAt": next_session_at(rows, now, {session_id: new_status})})
        if new_status == "confirmed":
            transaction.set(
                _messages(db, sub).document(),
                {
                    "senderUid": uid,
                    "type": "system",
                    "systemKind": "sessionConfirmed",
                    "sessionId": session_id,
                    "createdAt": now,
                },
            )

    common.run(db, body)
    return {"status": new_status}


def _marked(session: dict) -> list:
    done = session.get("doneBy")
    return [item for item in done if isinstance(item, str)] if isinstance(done, list) else []


def mark_done(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    """Each party marks a confirmed session done once it has started. It is
    done, and counts against the package, only when both have marked it."""
    common.require_clients_live(live)
    sub_id, session_id = _ids(data)
    sub_ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        sub = common.read(sub_ref, transaction)
        if sub is None:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        coach_uid, client_uid = sub.get("coachUid"), sub.get("clientUid")
        if uid not in (coach_uid, client_uid):
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if uid == coach_uid:
            common.require_not_on_hold(db, uid, transaction)
        if sub.get("status") != "active" or _frozen(sub):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        session_ref = sub_ref.collection("sessions").document(session_id)
        session = common.read(session_ref, transaction)
        if session is None:
            raise common.refuse(errors.NOT_FOUND, errors.SESSION_NOT_FOUND)
        marked = _marked(session)
        if uid in marked:
            return session.get("status"), int(sub.get("sessionsUsed") or 0)
        if session.get("status") != "confirmed":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        starts_at = common.as_utc(session.get("startsAt"))
        if starts_at is None or now < starts_at:
            raise common.refuse(errors.PRECONDITION, errors.SESSION_NOT_STARTED)
        marked.append(uid)
        used = int(sub.get("sessionsUsed") or 0)
        if not {coach_uid, client_uid} <= set(marked):
            transaction.update(session_ref, {"doneBy": marked, "statusAt": now})
            return "confirmed", used

        used += 1
        coach_ref = db.collection("coaches").document(coach_uid)
        coach = common.read(coach_ref, transaction)
        rows = [(row.id, row.to_dict() or {}) for row in sub_ref.collection("sessions").stream(transaction=transaction)]
        transaction.update(session_ref, {"status": "done", "doneBy": marked, "statusAt": now})
        transaction.update(
            sub_ref,
            {"sessionsUsed": used, "nextSessionAt": next_session_at(rows, now, {session_id: "done"})},
        )
        if coach is not None:
            transaction.update(coach_ref, {"stats.sessionsDone": firestore.Increment(1)})
        transaction.set(
            _messages(db, sub).document(),
            {
                "senderUid": uid,
                "type": "system",
                "systemKind": "sessionDone",
                "sessionId": session_id,
                "createdAt": now,
            },
        )
        return "done", used

    status, used = common.run(db, body)
    return {"status": status, "sessionsUsed": used}
