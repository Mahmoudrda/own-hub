"""C3: the weekly check-in.

`relationships/{relId}/checkIns/{weekKey}` is written only here (firestore.rules
lets the two parties read it, never write). Each week an ACTIVE coaching gets an `open` card, a system
message in the thread and one push; the client answers once; the coach's
"Needs attention" list reads the answers. The server never sees workout logs,
so "missed sessions" is the client's own answer. Two numbers are optional and
only there when she chose to share them: her weight and how many coach-plan
workouts she finished that week. Both are health data: they sit in the answers,
leave with her export and go with the coaching when it is deleted.

The coach may reply once to an answered card (`reply`); the client reads it in
her check-in history.
"""

from __future__ import annotations

import datetime as dt
import logging
import math
import re
from typing import Callable

from . import chat, common, errors, subscriptions

COLLECTION = "checkIns"
TRAINING = ("all", "most", "some", "none")
NOTE_MAX = 300
REPLY_MAX = 400
HISTORY_WEEKS = 8
WEIGHT_MIN_KG = 30.0
WEIGHT_MAX_KG = 300.0
WORKOUTS_MAX = 14
ANSWERED_PUSH = "checkInAnswered"
REPLY_PUSH = "checkInReply"
LATE_AFTER_DAYS = 3
MAX_LIST = 50
_ANSWER_KEYS = {"training", "energy", "food", "pain", "note", "weightKg", "weightConsent", "workoutsDone"}
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
    note = common.optional_text(raw.get("note"), max_len=NOTE_MAX)
    chat.refuse_contact(note)
    answers = {
        "training": common.one_of(raw.get("training"), TRAINING),
        "energy": common.whole(raw.get("energy"), low=1, high=5),
        "food": common.whole(raw.get("food"), low=1, high=5),
        "pain": raw["pain"],
        "note": note,
    }
    if raw.get("weightKg") is not None:
        # Health data: only with her own tick, which the app sends with it.
        if raw.get("weightConsent") is not True:
            raise common.bad()
        answers["weightKg"] = _weight(raw["weightKg"])
    if raw.get("workoutsDone") is not None:
        answers["workoutsDone"] = common.whole(raw["workoutsDone"], low=0, high=WORKOUTS_MAX)
    return answers


def _weight(value) -> float:
    """Kilograms to one decimal, within what a woman can weigh."""
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise common.bad()
    kg = round(float(value), 1)
    if not WEIGHT_MIN_KG <= kg <= WEIGHT_MAX_KG:
        raise common.bad()
    return kg


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


def submit(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    now: dt.datetime,
    notify: Callable[[str, str], None] = lambda uid, kind: None,
) -> dict:
    """The client answers her open card once. Her coach is told once."""
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
        fields = {"state": "answered", "answers": answers, "answeredAt": now}
        if "weightKg" in answers:
            fields["consent"] = {"weight": {"at": now}}  # her tick, kept with the answer
        transaction.update(ref, fields)
        return card.get("coachUid")

    coach_uid = common.run(db, body)
    if coach_uid:
        notify(coach_uid, ANSWERED_PUSH)
    return {"ok": True}


def _party(db, uid: str, rel_id: str) -> dict:
    """The relationship, for one of its two people; anyone else is told it is
    not there."""
    rel = db.collection("relationships").document(rel_id).get().to_dict() or {}
    if uid not in (rel.get("clientUid"), rel.get("coachUid")):
        raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    return rel


def list_cards(db, uid: str, data: dict, *, live: bool) -> dict:
    """The last weeks of check-ins of one coaching, newest first, for either
    person. Her coach reads them only while the coaching is active, as the
    rules say; the client reads hers after it ended too."""
    common.require_clients_live(live)
    rel_id = _shaped(data.get("relId"), _REL_ID)
    rel = _party(db, uid, rel_id)
    if uid == rel.get("coachUid") and rel.get("status") != "active":
        raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    cards = []
    for snap in db.collection("relationships").document(rel_id).collection(COLLECTION).stream():
        card = snap.to_dict() or {}
        if card.get("state") != "answered":
            continue
        cards.append(
            {
                "weekKey": snap.id,
                "answers": card.get("answers") or {},
                "answeredAt": card.get("answeredAt"),
                "reply": card.get("reply"),
                "repliedAt": card.get("repliedAt"),
            }
        )
    cards.sort(key=lambda c: c["weekKey"], reverse=True)
    return {"checkIns": cards[:HISTORY_WEEKS]}


def reply(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    coach_v,
    now: dt.datetime,
    notify: Callable[[str, str], None],
) -> dict:
    """Her coach answers an answered card, once, while the coaching runs. A coach
    whose account is on hold for an unpaid fee cannot."""
    common.require_clients_live(live)
    common.require_active_coach(db, uid, coach_v)
    rel_id = _shaped(data.get("relId"), _REL_ID)
    key = _shaped(data.get("weekKey"), _WEEK_KEY)
    text = common.text(data.get("text"), max_len=REPLY_MAX)
    chat.refuse_contact(text)
    ref = _ref(db, rel_id, key)
    rel_ref = db.collection("relationships").document(rel_id)

    def body(transaction):
        card = common.read(ref, transaction)
        rel = common.read(rel_ref, transaction)
        if card is None or card.get("coachUid") != uid or (rel or {}).get("status") != "active":
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if card.get("state") != "answered" or card.get("reply"):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, {"reply": text, "repliedAt": now})
        return card.get("clientUid")

    client_uid = common.run(db, body)
    if client_uid:
        notify(client_uid, REPLY_PUSH)
    return {"ok": True}


def needs_attention(db, coach_uid: str, *, live: bool, coach_v, now: dt.datetime) -> dict:
    common.require_clients_live(live)
    common.require_active_coach(db, coach_uid, coach_v, allow_hold=True)  # a read
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
