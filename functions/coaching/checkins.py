"""C3: the weekly check-in.

`relationships/{relId}/checkIns/{weekKey}` is written only here (firestore.rules
lets the two parties read it, never write). Each week an ACTIVE coaching gets an `open` card, a system
message in the thread and one push; the client answers once; the coach's
"Needs attention" list reads the answers. The server never sees workout logs,
so "missed sessions" is the client's own answer.
"""

from __future__ import annotations

import datetime as dt
import logging
import re
from typing import Callable

from . import common, errors, subscriptions

COLLECTION = "checkIns"
TRAINING = ("all", "most", "some", "none")
NOTE_MAX = 300
LATE_AFTER_DAYS = 3
MAX_LIST = 50
_ANSWER_KEYS = {"training", "energy", "food", "pain", "note"}
# A relId is `{coachUid}__{clientUid}` and a weekKey is `2026-W44`. Both become
# Firestore path segments, so a `/` in either must be refused, not looked up.
_REL_ID = re.compile(r"[A-Za-z0-9_-]{1,128}__[A-Za-z0-9_-]{1,128}")
_WEEK_KEY = re.compile(r"\d{4}-W\d{2}")


def week_key(now: dt.datetime) -> str:
    iso = now.isocalendar()
    return f"{iso[0]}-W{iso[1]:02d}"


def _ref(db, rel_id: str, key: str):
    return db.collection("relationships").document(rel_id).collection(COLLECTION).document(key)


def _shaped(value, pattern: re.Pattern) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise common.bad()
    return value


def _answers(raw) -> dict:
    if not isinstance(raw, dict) or set(raw) - _ANSWER_KEYS:
        raise common.bad()
    if not isinstance(raw.get("pain"), bool):
        raise common.bad()
    return {
        "training": common.one_of(raw.get("training"), TRAINING),
        "energy": common.whole(raw.get("energy"), low=1, high=5),
        "food": common.whole(raw.get("food"), low=1, high=5),
        "pain": raw["pain"],
        "note": common.optional_text(raw.get("note"), max_len=NOTE_MAX),
    }


def _open_card(db, row: dict, key: str, now: dt.datetime) -> bool:
    ref = _ref(db, row["relId"], key)
    messages = db.collection("relationships").document(row["relId"]).collection("messages")

    def body(transaction):
        if common.read(ref, transaction) is not None:
            return False  # this week's card already exists: the job is safe to run twice
        transaction.set(
            ref,
            {
                "clientUid": row["clientUid"],
                "coachUid": row["coachUid"],
                "weekKey": key,
                "state": "open",
                "createdAt": now,
            },
        )
        transaction.set(
            messages.document(),
            {"senderUid": "system", "type": "system", "systemKind": "checkIn", "weekKey": key, "createdAt": now},
        )
        return True

    return common.run(db, body)


def _active(db):
    for snap in db.collection("subscriptions").where("status", "==", "active").stream():
        row = snap.to_dict() or {}
        if all(isinstance(row.get(k), str) and row[k] for k in ("relId", "clientUid", "coachUid")):
            yield snap.id, row


def send_cards(db, now: dt.datetime, notify: Callable[[str, str], None]) -> int:
    """Friday job. Returns how many cards it opened."""
    key = week_key(now)
    opened = 0
    for _sub_id, row in _active(db):
        per_week = (row.get("package") or {}).get("checkInsPerWeek")
        if not isinstance(per_week, int) or isinstance(per_week, bool) or per_week < 1:
            continue
        try:
            if _open_card(db, row, key, now):
                opened += 1
                notify(row["clientUid"], "checkInDue")
        except Exception:  # noqa: BLE001 - one client's failure must not stop the others
            logging.getLogger(__name__).error("check_in_card_failed")
    return opened


def follow_up(db, now: dt.datetime, notify: Callable[[str, str], None]) -> int:
    """Monday job: ONE kind push for last week's card still open."""
    key = week_key(now - dt.timedelta(days=7))
    sent = 0
    for _sub_id, row in _active(db):
        ref = _ref(db, row["relId"], key)

        def body(transaction, ref=ref):
            card = common.read(ref, transaction)
            if card is None or card.get("state") != "open" or card.get("followUpAt"):
                return False
            transaction.update(ref, {"followUpAt": now})
            return True

        try:
            if common.run(db, body):
                sent += 1
                notify(row["clientUid"], "checkInFollowUp")
        except Exception:  # noqa: BLE001 - one client's failure must not stop the others
            logging.getLogger(__name__).error("check_in_follow_up_failed")
    return sent


def submit(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    """The client answers her open card once."""
    common.require_clients_live(live)
    rel_id = _shaped(data.get("relId"), _REL_ID)
    key = _shaped(data.get("weekKey"), _WEEK_KEY)
    answers = _answers(data.get("answers"))
    ref = _ref(db, rel_id, key)
    rel_ref = db.collection("relationships").document(rel_id)

    def body(transaction):
        card = common.read(ref, transaction)
        rel = common.read(rel_ref, transaction)
        # Answers are health data for her coach: only while the coaching runs.
        if card is None or card.get("clientUid") != uid or (rel or {}).get("status") != "active":
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if card.get("state") != "open":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, {"state": "answered", "answers": answers, "answeredAt": now})
        return {"ok": True}

    return common.run(db, body)


def needs_attention(db, coach_uid: str, *, live: bool, coach_v, now: dt.datetime) -> dict:
    common.require_clients_live(live)
    common.require_active_coach(db, coach_uid, coach_v)
    this_week = week_key(now)
    last_week = week_key(now - dt.timedelta(days=7))
    out = []
    for snap in db.collection("subscriptions").where("coachUid", "==", coach_uid).stream():
        row = snap.to_dict() or {}
        if row.get("status") != "active" or not row.get("relId"):
            continue
        reasons = []
        rel = db.collection("relationships").document(row["relId"])
        cards = {k: rel.collection(COLLECTION).document(k).get() for k in (this_week, last_week)}
        cards = {k: (s.to_dict() or {}) for k, s in cards.items() if s.exists}
        late = cards.get(last_week, {}).get("state") == "open"
        current = cards.get(this_week, {})
        created = current.get("createdAt")
        if current.get("state") == "open" and isinstance(created, dt.datetime):
            late = late or (now - _aware(created)) > dt.timedelta(days=LATE_AFTER_DAYS)
        if late:
            reasons.append("noCheckIn")
        answered = [c for c in cards.values() if c.get("state") == "answered"]
        latest = max(answered, key=lambda c: _aware(c.get("answeredAt")), default=None) if answered else None
        if latest and (latest.get("answers") or {}).get("training") in ("some", "none"):
            reasons.append("missedSessions")
        intake = row.get("intake") or {}
        if subscriptions.intake_flagged(intake) and not row.get("healthReviewedAt"):
            reasons.append("healthFlag")  # review_health sets healthReviewedAt
        elif latest and (latest.get("answers") or {}).get("pain") is True:
            reasons.append("healthFlag")
        unread = ((rel.get().to_dict() or {}).get("unreadFor") or {}).get(coach_uid, 0)
        if isinstance(unread, int) and unread > 0:
            reasons.append("unread")
        answers = (latest or {}).get("answers") or {}
        # A note she wrote is for her coach to read, even in a good week.
        if reasons or answers.get("note"):
            entry = {"subId": snap.id, "relId": row["relId"], "clientName": row.get("clientName", ""), "reasons": reasons}
            if latest:
                entry["checkIn"] = {"weekKey": latest.get("weekKey"), "answers": answers}
            out.append(entry)
    out.sort(key=lambda c: (-len(c["reasons"]), c["clientName"]))
    return {"clients": out[:MAX_LIST]}


def _aware(value) -> dt.datetime:
    if not isinstance(value, dt.datetime):
        return dt.datetime.min.replace(tzinfo=dt.timezone.utc)
    return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)
