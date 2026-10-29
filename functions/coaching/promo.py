"""Marketing videos: the 2 a month a coach makes for Own Hub (Coach Agreement,
section 5).

The video goes from her phone to `coach-docs/{uid}/promo/` in the personal bucket
(storage.rules: hers to write, an mp4 or mov, read by her and a woman reviewer),
then `add` records it at `coachPrivate/{uid}/promoVideos/{id}`. That path is
hers to read and nobody's to write, so a video is never on her public page and a
coach cannot mark her own video approved. Staff approve it or ask for changes;
only approved videos count towards the month's 2.

A video belongs to the Cairo calendar month it was uploaded in (`month`,
"2026-10"), whenever staff decide on it. Nothing here blocks a coach who is short:
staff see the counts, and on the 20th a coach below the target gets one kind
reminder (`remind`, once a month). A coach on hold may still upload.

The server cannot play a video. It checks the file's size and type in the bucket;
the length is what the app read from the file, and staff watch the video before
they approve it.
"""

from __future__ import annotations

import datetime as dt
import logging
import re
from typing import Callable

from . import common, errors

TARGET = 2
TOPICS = ("workout_tip", "eating_idea", "training_myth", "how_coaching_works", "introduction")
MIN_SECONDS = 30
MAX_SECONDS = 180
MAX_BYTES = 200 * 1024 * 1024  # storage.rules holds the same figure
CONTENT_TYPES = ("video/mp4", "video/quicktime")
MAX_PER_MONTH = 6
"""More than two so a coach can send a better take; a ceiling on a write pump."""
STATUSES = ("waiting", "approved", "changes")
DECISIONS = ("approve", "changes")
REASON_MAX = 200
REMINDER_DAY = 20
DECISION_PUSH = "promoDecision"
REMINDER_PUSH = "promoReminder"
MAX_STAFF_ROWS = 200

COLLECTION = "promoVideos"
_MEDIA = re.compile(r"^coach-docs/(?P<uid>[A-Za-z0-9_-]{1,128})/promo/(?P<name>[A-Za-z0-9_-]{1,80})\.(?:mp4|mov)$")
_MONTH = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


def month_key(moment: dt.datetime) -> str:
    """The Cairo calendar month, "2026-10"."""
    local = moment.astimezone(common.CAIRO)
    return f"{local.year}-{local.month:02d}"


def _videos(db, uid: str):
    return db.collection("coachPrivate").document(uid).collection(COLLECTION)


def _item(snap) -> dict:
    row = snap.to_dict() or {}
    return {
        "id": snap.id,
        "topic": row.get("topic"),
        "status": row.get("status"),
        "reason": row.get("reason") or "",
        "durationSeconds": row.get("durationSeconds"),
        "createdAt": row.get("createdAt"),
    }


# --------------------------------------------------------------------- coach


def add(db, uid: str, data: dict, *, live: bool, coach_v, blobs, now: dt.datetime) -> dict:
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v, allow_hold=True)
    path = data.get("mediaRef")
    match = _MEDIA.match(path) if isinstance(path, str) else None
    if match is None or match.group("uid") != uid:
        raise common.bad()
    topic = common.one_of(data.get("topic"), TOPICS)
    seconds = common.whole(data.get("durationSeconds"), low=MIN_SECONDS, high=MAX_SECONDS)
    info = blobs.info(path)
    if info is None:
        raise common.refuse(errors.INVALID, errors.FILE_NOT_UPLOADED)
    size, content_type = info
    if not 0 < size <= MAX_BYTES or content_type not in CONTENT_TYPES:
        # A file storage.rules should have stopped: it is not kept.
        _forget(blobs, path)
        raise common.refuse(errors.INVALID, errors.FILE_NOT_UPLOADED)

    month = month_key(now)
    videos = _videos(db, uid)
    ref = videos.document(match.group("name"))

    def body(transaction):
        if common.read(ref, transaction) is not None:
            return ref.id  # the same upload sent twice
        held = sum(1 for _ in videos.where("month", "==", month).stream(transaction=transaction))
        if held >= MAX_PER_MONTH:
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_MEDIA)
        transaction.set(
            ref,
            {
                "coachUid": uid,
                "month": month,
                "path": path,
                "topic": topic,
                "durationSeconds": seconds,
                "status": "waiting",
                "createdAt": now,
            },
        )
        return ref.id

    video_id = common.run(db, body)
    blobs.lock(path)  # evidence from here on: storage rules stop her replacing it
    return {"videoId": video_id, "status": "waiting"}


def _forget(blobs, path: str) -> None:
    try:
        blobs.delete(path)
    except Exception:  # noqa: BLE001 - the refusal matters more than the clean-up
        pass


def mine(db, uid: str, *, live: bool, coach_v, now: dt.datetime) -> dict:
    """This month's videos and where the month stands."""
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v, allow_hold=True)
    month = month_key(now)
    items = sorted(
        (_item(s) for s in _videos(db, uid).where("month", "==", month).stream()),
        key=lambda i: str(i["createdAt"]),
    )
    return {
        "month": month,
        "target": TARGET,
        "approved": sum(1 for i in items if i["status"] == "approved"),
        "items": items,
    }


# --------------------------------------------------------------------- staff


def list_for_staff(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    """`waiting`: every video waiting for a decision, oldest first. `coaches`: the
    month's counts for each coach."""
    month = data.get("month")
    if month is None or month == "":
        month = month_key(now)
    if not isinstance(month, str) or not _MONTH.match(month):
        raise common.bad()
    common.log_access(db, actor_uid, "promo.list", month, now)

    counts: dict = {}
    for snap in db.collection_group(COLLECTION).where("month", "==", month).stream():
        row = snap.to_dict() or {}
        by_status = counts.setdefault(row.get("coachUid") or snap.reference.path.split("/")[1], {})
        by_status[row.get("status")] = by_status.get(row.get("status"), 0) + 1

    names: dict = {}
    coaches = []
    for snap in db.collection("coachPrivate").limit(MAX_STAFF_ROWS).stream():
        private = snap.to_dict() or {}
        if private.get("suspended"):
            continue
        page = db.collection("coaches").document(snap.id).get()
        name = ((page.to_dict() or {}).get("displayName") if page.exists else "") or private.get("fullName", "")
        names[snap.id] = name
        have = counts.get(snap.id, {})
        coaches.append(
            {
                "uid": snap.id,
                "name": name,
                "approved": have.get("approved", 0),
                "waiting": have.get("waiting", 0),
                "changes": have.get("changes", 0),
                "target": TARGET,
            }
        )
    coaches.sort(key=lambda c: (c["approved"], c["name"]))

    waiting = []
    for snap in db.collection_group(COLLECTION).where("status", "==", "waiting").limit(MAX_STAFF_ROWS).stream():
        row = snap.to_dict() or {}
        coach_uid = row.get("coachUid") or snap.reference.path.split("/")[1]
        waiting.append(
            {
                **_item(snap),
                "coachUid": coach_uid,
                "coachName": names.get(coach_uid, ""),
                "path": row.get("path"),
                "month": row.get("month"),
            }
        )
    waiting.sort(key=lambda i: str(i["createdAt"]))
    return {"month": month, "target": TARGET, "coaches": coaches, "waiting": waiting}


def decide(db, actor_uid: str, data: dict, *, notify: Callable[[str, str], None], now: dt.datetime) -> dict:
    coach_uid = common.text(data.get("coachUid"), max_len=128)
    video_id = common.text(data.get("videoId"), max_len=128)
    decision = common.one_of(data.get("decision"), DECISIONS)
    reason = common.text(data.get("reason"), max_len=REASON_MAX) if decision == "changes" else None
    common.refuse_if_subject(actor_uid, coach_uid)
    ref = _videos(db, coach_uid).document(video_id)
    if not ref.get().exists:
        raise common.refuse(errors.NOT_FOUND, errors.MEDIA_NOT_FOUND)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.NOT_FOUND, errors.MEDIA_NOT_FOUND)
        if row.get("status") != "waiting":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        status = "approved" if decision == "approve" else "changes"
        transaction.update(ref, {"status": status, "reason": reason, **common.decided_stamp(actor_uid, now)})
        return status

    status = common.run(db, body)
    common.log_access(db, actor_uid, f"promo.{decision}", video_id, now)
    notify(coach_uid, DECISION_PUSH)
    return {"status": status}


# ------------------------------------------------------------------ reminder


def remind(db, now: dt.datetime, notify: Callable[[str, str], None]) -> int:
    """The 20th (Cairo): one kind push to each coach with fewer than the target
    approved this month, once a month. A coach on hold is included; a suspended
    one is not, nor one whose coach page is missing or unpublished. Returns how many were reminded."""
    month = month_key(now)
    approved: dict = {}
    for snap in db.collection_group(COLLECTION).where("month", "==", month).stream():
        row = snap.to_dict() or {}
        if row.get("status") == "approved":
            who = row.get("coachUid") or snap.reference.path.split("/")[1]
            approved[who] = approved.get(who, 0) + 1

    sent = 0
    for snap in list(db.collection("coachPrivate").stream()):
        row = snap.to_dict() or {}
        if row.get("suspended") or approved.get(snap.id, 0) >= TARGET or row.get("promoReminderMonth") == month:
            continue
        if not (db.collection("coaches").document(snap.id).get().to_dict() or {}).get("published"):
            continue  # no page, or a page not published: not an active coach yet
        ref = db.collection("coachPrivate").document(snap.id)

        def body(transaction, ref=ref):
            current = common.read(ref, transaction) or {}
            if current.get("promoReminderMonth") == month or current.get("suspended"):
                return False
            transaction.update(ref, {"promoReminderMonth": month})
            return True

        try:
            if common.run(db, body):
                notify(snap.id, REMINDER_PUSH)
                sent += 1
        except Exception:  # noqa: BLE001 - one coach's failure must not stop the others
            logging.getLogger(__name__).error("promo_reminder_failed")
    return sent
