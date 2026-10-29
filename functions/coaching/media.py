"""Portfolio photos members can see: a coach's transformations, client
feedback and gallery photos, each checked by a woman reviewer before anyone
else sees it.

`coaches/{uid}/media/{id}` is written only here. The coach uploads her files to
the private bucket (`coach-docs/{uid}/...`); an item starts `pending`, and only
an approval copies every image, re-encoded (no EXIF, no location), to
`coach-public/{uid}/media/` and sets the public fields. A rejection, or an item
still waiting, leaves nothing public. A transformation also needs her tick that
the client agreed in writing that Own Hub members may see the photos, kept with
the time and the terms version, and a picture of that written release,
uploaded to her private `transformations` folder, which only a woman reviewer
sees. Approval needs the picture; it then moves to `coachPrivate/{uid}/
mediaConsents/{id}` as the evidence and leaves the doc members read.

Uses `common.require_portfolio_live`: the portfolio group's switch.
"""

from __future__ import annotations

import datetime as dt
from typing import Optional

from . import applications, chat, common, errors

PAGE_SIZE = 25
MAX_ITEMS = 30
TERMS_VERSION = 1
KINDS = ("transformation", "feedback", "photo")
STATUSES = ("pending", "needsConsent", "approved", "rejected")
DECISIONS = ("approve", "reject")
REJECT_REASONS = ("unclear", "not_allowed", "no_consent", "other")
DECISION_PUSH = "portfolioDecision"

MEDIA_NOT_FOUND = errors.MEDIA_NOT_FOUND
TOO_MANY_MEDIA = errors.TOO_MANY_MEDIA
SEEDED = "app-"
"""Items made from her application have ids starting with this; their files
are still the application's, so a decision or a removal never deletes them."""

_PRIVATE_KEYS = ("beforePath", "afterPath", "imagePath")
_PUBLIC_NAMES = {"beforePath": "before", "afterPath": "after", "imagePath": "image"}


def _collection(db, uid: str):
    return db.collection("coaches").document(uid).collection("media")


def public_path(uid: str, media_id: str, part: str) -> str:
    return f"coach-public/{uid}/media/{media_id}_{part}.jpg"


def _file(blobs, uid: str, value, folders: tuple) -> str:
    """A private path under one of her folders, with a file behind it."""
    path = common.text(value, max_len=300)
    if not any(applications.under_prefix(path, f"coach-docs/{uid}/{folder}/") for folder in folders):
        raise common.refuse(errors.INVALID, errors.FILE_NOT_UPLOADED)
    if not blobs.exists(path):
        raise common.refuse(errors.INVALID, errors.FILE_NOT_UPLOADED)
    return path


def _consent_file(blobs, uid: str, data: dict) -> Optional[str]:
    """The picture of the client's written release: her own upload, and not one
    of the two photos. None when she sent none: coaches on app 1.0.0 do not
    send one, and approval stays blocked until a release is attached."""
    if data.get("consentPath") is None:
        return None
    path = _file(blobs, uid, data.get("consentPath"), ("transformations",))
    photos = [common.text(data[k], max_len=300) for k in ("beforePath", "afterPath") if isinstance(data.get(k), str)]
    if path in photos:
        raise common.bad()
    return path


def _lock(blobs, row: dict) -> None:
    """A transformation's files are evidence once it is submitted: storage rules
    stop her deleting or replacing them (a draft she never submitted stays hers)."""
    for key in ("beforePath", "afterPath", "consentPath"):
        if row.get(key):
            blobs.lock(row[key])


def _evidence_ref(db, uid: str, media_id: str):
    return db.collection("coachPrivate").document(uid).collection("mediaConsents").document(media_id)


def _fields(uid: str, data: dict, blobs) -> dict:
    kind = common.one_of(data.get("kind"), KINDS)
    if kind == "transformation":
        if data.get("clientConsentPublic") is not True:
            raise common.bad()
        return {
            "kind": kind,
            "beforePath": _file(blobs, uid, data.get("beforePath"), ("transformations",)),
            "afterPath": _file(blobs, uid, data.get("afterPath"), ("transformations",)),
            **({"consentPath": release} if (release := _consent_file(blobs, uid, data)) else {}),
            "weeks": common.whole(data.get("weeks"), low=1, high=104),
            "note": common.optional_text(data.get("note"), max_len=300),
            "clientConsentPublic": True,
        }
    if kind == "feedback":
        row = {
            "kind": kind,
            "text": common.text(data.get("text"), min_len=10, max_len=600),
            "from": common.text(data.get("from"), min_len=1, max_len=40),
            "imagePath": None,
        }
        if data.get("imagePath") not in (None, ""):
            row["imagePath"] = _file(blobs, uid, data.get("imagePath"), ("testimonials",))
        return row
    return {
        "kind": kind,
        "imagePath": _file(blobs, uid, data.get("imagePath"), ("photo", "gallery")),
        "caption": common.optional_text(data.get("caption"), max_len=120),
    }


# --------------------------------------------------------------------- coach


def add(db, uid: str, data: dict, *, live: bool, coach_v, blobs, reencode, now: dt.datetime) -> dict:
    """`reencode` is not used here: nothing is copied before a reviewer says
    yes. It stays in the signature so the wrapper passes one set of adapters."""
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v)
    row = _fields(uid, data, blobs)
    chat.refuse_contact(row.get("note"), row.get("text"), row.get("from"), row.get("caption"))
    if row["kind"] == "transformation":
        row["consent"] = {"at": now, "termsVersion": TERMS_VERSION}

    media = _collection(db, uid)
    ref = media.document()
    row.update(coachUid=uid, status="pending", createdAt=now)

    def body(transaction):
        held = sum(1 for _ in media.stream(transaction=transaction))
        if held >= MAX_ITEMS:
            raise common.refuse(errors.EXHAUSTED, TOO_MANY_MEDIA)
        transaction.set(ref, row)

    common.run(db, body)
    _lock(blobs, row)
    return {"mediaId": ref.id, "status": "pending"}


def _own(db, uid: str, data: dict):
    media_id = common.text(data.get("mediaId"), max_len=128)
    ref = _collection(db, uid).document(media_id)
    snap = ref.get()
    if not snap.exists:
        raise common.refuse(errors.NOT_FOUND, MEDIA_NOT_FOUND)
    return ref, snap.to_dict() or {}


def remove(db, uid: str, data: dict, *, live: bool, coach_v, blobs, now: dt.datetime) -> dict:
    """Her own item goes, and so do its public copies. A suspended coach may
    still take photos down."""
    common.require_portfolio_live(live)
    if coach_v not in common.ENUMS["coachV"]:
        raise common.refuse(errors.PERMISSION, errors.NOT_A_COACH)
    ref, row = _own(db, uid, data)
    # Files first: when one cannot be deleted the item stays and she can retry.
    for path in (row.get("publicPaths") or {}).values():
        blobs.delete(path)
    if not ref.id.startswith(SEEDED):
        for key in _PRIVATE_KEYS:
            if row.get(key):
                blobs.delete(row[key])
    evidence = _evidence_ref(db, uid, ref.id)
    release = row.get("consentPath") or (evidence.get().to_dict() or {}).get("path")
    if release:
        blobs.delete(release)
    evidence.delete()
    ref.delete()
    return {"removed": True}


def confirm_consent(db, uid: str, data: dict, *, live: bool, coach_v, blobs, now: dt.datetime) -> dict:
    """The coach's own tick on a transformation that came in with her
    application, with a picture of her client's written release: it can go to
    review. A transformation already waiting without a release can be given
    one the same way."""
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v)
    media_id = common.text(data.get("mediaId"), max_len=128)
    ref = _collection(db, uid).document(media_id)
    held: dict = {}

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.NOT_FOUND, MEDIA_NOT_FOUND)
        held.update(row)
        waiting = row.get("status") == "needsConsent" or (row.get("status") == "pending" and not row.get("consentPath"))
        if row.get("kind") != "transformation" or not waiting:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        consent_path = _consent_file(
            blobs, uid, {**data, "beforePath": row.get("beforePath"), "afterPath": row.get("afterPath")}
        )
        pending = row.get("status") == "pending"
        if pending and not consent_path:
            raise common.bad()
        fields = {"status": "pending", "clientConsentPublic": True}
        if consent_path:
            fields["consentPath"] = consent_path
            held["consentPath"] = consent_path
        if not pending:
            # A pending item already carries the stamp from when it was added.
            fields["consent"] = {"at": now, "termsVersion": TERMS_VERSION}
        transaction.update(ref, fields)

    common.run(db, body)
    _lock(blobs, held)
    return {"status": "pending"}


def seed_from_application(db, uid: str, application: dict, *, now: dt.datetime) -> int:
    """At approval: her application's transformations (waiting for her own
    consent tick) and feedback that has a screenshot become portfolio items.
    The ids are fixed per row, so a retry adds nothing twice and never touches
    an item that was decided since. Returns how many were created."""
    media = _collection(db, uid)
    rows = []
    for index, row in enumerate(application.get("transformations") or []):
        rows.append(
            (
                f"app-t{index}",
                {
                    "kind": "transformation",
                    "beforePath": row["beforePath"],
                    "afterPath": row["afterPath"],
                    "weeks": row["weeks"],
                    "note": row.get("note") or "",
                    "clientConsentPublic": False,
                    "status": "needsConsent",
                },
            )
        )
    for index, row in enumerate(application.get("testimonials") or []):
        if row.get("imagePath"):
            rows.append(
                (
                    f"app-f{index}",
                    {
                        "kind": "feedback",
                        "text": row["text"],
                        "from": row["from"],
                        "imagePath": row["imagePath"],
                        "status": "pending",
                    },
                )
            )
    held = sum(1 for _ in media.stream())
    made = 0
    for media_id, fields in rows:
        ref = media.document(media_id)
        if ref.get().exists:
            continue
        if held + made >= MAX_ITEMS:
            break
        ref.set({**fields, "coachUid": uid, "createdAt": now})
        made += 1
    return made


# -------------------------------------------------------------------- review


def _cursor(value) -> Optional[tuple]:
    if value is None or value == "":
        return None
    text = common.text(value, max_len=300)
    parts = text.split("/")
    if len(parts) != 2 or not all(parts):
        raise common.bad()
    return parts[0], parts[1]


def list_for_review(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    """Pending first (the default), oldest first, 25 to a page. `after` is the
    `next` of the page before: "coachUid/mediaId"."""
    status = data.get("status", "pending")
    if status is None:
        status = "pending"
    common.one_of(status, STATUSES)
    after = _cursor(data.get("after"))
    common.log_access(db, actor_uid, "media.list", status, now)

    query = db.collection_group("media").where("status", "==", status).order_by("createdAt")
    rows = []
    if after is None:
        rows = list(query.limit(PAGE_SIZE + 1).stream())
    else:
        marker = _collection(db, after[0]).document(after[1]).get()
        if marker.exists:
            rows = list(query.start_after(marker).limit(PAGE_SIZE + 1).stream())
    more = len(rows) > PAGE_SIZE
    rows = rows[:PAGE_SIZE]

    names: dict = {}
    items = []
    for snap in rows:
        row = snap.to_dict() or {}
        coach_uid = row.get("coachUid") or snap.reference.path.split("/")[1]
        if coach_uid not in names:
            coach = db.collection("coaches").document(coach_uid).get()
            names[coach_uid] = (coach.to_dict() or {}).get("displayName", "") if coach.exists else ""
        items.append({**common.plain(row), "mediaId": snap.id, "coachUid": coach_uid, "coachName": names[coach_uid]})
    last = items[-1] if items else None
    return {"items": items, "next": f"{last['coachUid']}/{last['mediaId']}" if more and last else None}


def decide(db, actor_uid: str, data: dict, *, blobs, reencode, notify, now: dt.datetime) -> dict:
    coach_uid = common.text(data.get("coachUid"), max_len=128)
    media_id = common.text(data.get("mediaId"), max_len=128)
    decision = common.one_of(data.get("decision"), DECISIONS)
    reason = None
    if decision == "reject":
        reason = common.one_of(data.get("reason"), REJECT_REASONS)
    common.refuse_if_subject(actor_uid, coach_uid)

    ref = _collection(db, coach_uid).document(media_id)
    snap = ref.get()
    if not snap.exists:
        raise common.refuse(errors.NOT_FOUND, MEDIA_NOT_FOUND)
    row = snap.to_dict() or {}
    if row.get("status") != "pending":
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    if row.get("kind") == "transformation" and (
        row.get("clientConsentPublic") is not True or (decision == "approve" and not row.get("consentPath"))
    ):
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    common.log_access(db, actor_uid, f"media.{decision}", media_id, now)
    decided = common.decided_stamp(actor_uid, now)

    published: dict = {}
    written: list = []
    if decision == "approve":
        try:
            # Every image is decoded and encoded again: nothing from the
            # original file (EXIF, location, an embedded thumbnail) survives.
            for key in _PRIVATE_KEYS:
                if row.get(key):
                    jpeg = reencode(blobs.read(row[key]))
                    path = public_path(coach_uid, media_id, _PUBLIC_NAMES[key])
                    blobs.write(path, jpeg, "image/jpeg")
                    written.append(path)
                    published[_PUBLIC_NAMES[key]] = path
        except Exception:
            _drop(blobs, written)
            raise common.refuse(errors.INVALID, errors.IMAGE_INVALID) from None

    def body(transaction):
        current = common.read(ref, transaction)
        if current is None:
            raise common.refuse(errors.NOT_FOUND, MEDIA_NOT_FOUND)
        if current.get("status") != "pending":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        if decision == "approve":
            # Members read approved docs, so the private originals' names leave
            # the doc and the originals themselves are deleted below.
            cleared = {key: None for key in _PRIVATE_KEYS if current.get(key)}
            if current.get("consentPath"):
                cleared["consentPath"] = None
                transaction.set(
                    _evidence_ref(db, coach_uid, media_id),
                    {
                        "path": current["consentPath"],
                        "consent": current.get("consent"),
                        "approvedAt": now,
                        "approvedBy": common.staff_ref(actor_uid),
                    },
                )
            transaction.update(
                ref, {"status": "approved", "publicPaths": published, "reason": None, **cleared, **decided}
            )
        else:
            cleared = {} if media_id.startswith(SEEDED) else {key: None for key in _PRIVATE_KEYS if current.get(key)}
            if current.get("consentPath"):
                cleared["consentPath"] = None
            transaction.update(ref, {"status": "rejected", "reason": reason, **cleared, **decided})

    try:
        common.run(db, body)
    except BaseException:
        _drop(blobs, written)
        raise
    if not media_id.startswith(SEEDED):
        _drop(blobs, [row[key] for key in _PRIVATE_KEYS if row.get(key)])
    if decision == "reject" and row.get("consentPath"):
        _drop(blobs, [row["consentPath"]])
    notify(coach_uid, DECISION_PUSH)
    return {"status": "approved" if decision == "approve" else "rejected"}


def _drop(blobs, paths: list) -> None:
    for path in paths:
        try:
            blobs.delete(path)
        except Exception:  # noqa: BLE001
            pass
