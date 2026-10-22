"""A woman applies to coach, a reviewer decides.

Nobody signs herself up as a coach. She sends one application with every
section filled in; a reviewer reads it (documents and all) and approves it,
asks for changes or rejects it. Approving mints the `coachV` claim, builds the
public coach page from the fields that are meant to be public, and opens the
private side (`coachPrivate`) that holds her legal name and payout account.

`coachApplications/{uid}` and everything under `coach-docs/{uid}/` are private
to her and to staff. The public page never carries her legal name, her payout
account, the before and after photos or the testimonial screenshots.
"""

from __future__ import annotations

import datetime as dt
import logging
import re
from typing import Optional

from . import common, errors

COLLECTION = "coachApplications"

COACH_TERMS = "coach-terms-v1"

TERMS_VERSION = 1

PAGE_SIZE = 25

_SLUG = re.compile(r"[a-z0-9-]{1,40}")
_CERT_MIMES = ("image/jpeg", "image/png", "image/webp", "application/pdf")
_FIRST_YEAR = 1960

APPLICATION_KEYS = (
    "status",
    "round",
    "personal",
    "education",
    "certificates",
    "specialties",
    "qualifications",
    "yearsExperience",
    "testimonials",
    "transformations",
    "approach",
    "payout",
    "termsVersion",
    "rules",
    "reasons",
    "note",
    "submittedAt",
    "decidedAt",
    "decidedBy",
)

COACH_PUBLIC_KEYS = (
    "displayName",
    "headline",
    "photoUrl",
    "governorate",
    "languages",
    "specialties",
    "approach",
    "yearsExperience",
    "certificates",
    "testimonials",
    "badges",
    "stats",
    "fromPriceEgp",
    "fromMonthlyEgp",
    "acceptingClients",
    "autoAccept",
    "maxActiveClients",
    "activeClients",
    "published",
    "replyHours",
    "trainsWhere",
    "updatedAt",
)

_KEPT_WHEN_RETURNING = (
    "stats",
    "activeClients",
    "fromPriceEgp",
    "fromMonthlyEgp",
    "published",
    "acceptingClients",
    "autoAccept",
    "maxActiveClients",
)
"""A coach page that already exists keeps her numbers and switches."""


SMALL_PHOTO_SIDE = 288


def photo_prefix(uid: str) -> str:
    return f"coach-docs/{uid}/photo/"


def public_photo_path(uid: str) -> str:
    return f"coach-public/{uid}/photo.jpg"


def public_photo_small_path(uid: str) -> str:
    return f"coach-public/{uid}/photo_s.jpg"


def write_public_photos(blobs, reencode, uid: str, raw: bytes) -> None:
    """The full photo for her page header and a 288 px copy for the small avatars."""
    blobs.write(public_photo_path(uid), reencode(raw), "image/jpeg")
    blobs.write(public_photo_small_path(uid), reencode(raw, long_side=SMALL_PHOTO_SIDE), "image/jpeg")


# ------------------------------------------------------------------ submit


def _dict(value) -> dict:
    if not isinstance(value, dict):
        raise common.bad()
    return value


def _rows(value, *, low: int, high: int) -> list:
    if not isinstance(value, list) or not (low <= len(value) <= high):
        raise common.bad()
    return [_dict(row) for row in value]


def _year(value, now: dt.datetime) -> int:
    return common.whole(value, low=_FIRST_YEAR, high=now.year)


def _path(value) -> str:
    return common.text(value, max_len=300)


def _optional_path(value) -> Optional[str]:
    if value is None or value == "":
        return None
    return _path(value)


def _validate(data: dict, now: dt.datetime) -> dict:
    """The application as it will be stored, or a bad-request refusal. File
    paths are only shaped here; `_check_files` looks at the bucket."""
    limits, enums = common.LIMITS, common.ENUMS

    p = _dict(data.get("personal"))
    personal = {
        "fullName": common.text(p.get("fullName"), min_len=3, max_len=limits["fullNameMax"]),
        "displayName": common.text(p.get("displayName"), min_len=2, max_len=limits["displayNameMax"]),
        "governorate": common.one_of(p.get("governorate"), enums["governorates"]),
        "languages": common.subset(p.get("languages"), enums["languages"], low=1, high=2),
        "headline": common.text(p.get("headline"), min_len=10, max_len=limits["headlineMax"]),
        "photoPath": _path(p.get("photoPath")),
    }

    education = []
    for row in _rows(data.get("education"), low=limits["educationMin"], high=limits["educationMax"]):
        education.append(
            {
                "degree": common.text(row.get("degree"), min_len=2, max_len=80),
                "institution": common.text(row.get("institution"), min_len=2, max_len=80),
                "year": _year(row.get("year"), now),
                "path": _optional_path(row.get("path")),
            }
        )

    certificates, seen = [], set()
    for row in _rows(data.get("certificates"), low=limits["certificatesMin"], high=limits["certificatesMax"]):
        cert_id = row.get("id")
        if not isinstance(cert_id, str) or not _SLUG.fullmatch(cert_id) or cert_id in seen:
            raise common.bad()
        seen.add(cert_id)
        certificates.append(
            {
                "id": cert_id,
                "title": common.text(row.get("title"), min_len=2, max_len=80),
                "issuer": common.text(row.get("issuer"), min_len=2, max_len=80),
                "year": _year(row.get("year"), now),
                "path": _path(row.get("path")),
                "mime": common.one_of(row.get("mime"), _CERT_MIMES),
            }
        )

    testimonials = []
    for row in _rows(data.get("testimonials"), low=limits["testimonialsMin"], high=limits["testimonialsMax"]):
        testimonials.append(
            {
                "text": common.text(row.get("text"), min_len=10, max_len=limits["testimonialTextMax"]),
                "from": common.text(row.get("from"), min_len=1, max_len=40),
                "source": common.one_of(row.get("source"), enums["testimonialSource"]),
                "imagePath": _optional_path(row.get("imagePath")),
            }
        )

    transformations = []
    for row in _rows(
        data.get("transformations"), low=limits["transformationsMin"], high=limits["transformationsMax"]
    ):
        if row.get("clientConsent") is not True:
            raise common.bad()
        transformations.append(
            {
                "beforePath": _path(row.get("beforePath")),
                "afterPath": _path(row.get("afterPath")),
                "weeks": common.whole(row.get("weeks"), low=1, high=104),
                "note": common.optional_text(row.get("note"), max_len=300),
                "clientConsent": True,
            }
        )

    a = _dict(data.get("approach"))
    approach = {
        "text": common.text(
            a.get("text"), min_len=limits["approachTextMin"], max_len=limits["approachTextMax"]
        ),
        "checkInsPerWeek": common.whole(a.get("checkInsPerWeek"), low=0, high=limits["checkInsPerWeekMax"]),
        "replyHours": common.whole_of(a.get("replyHours"), enums["replyHours"]),
        "trainsWhere": common.subset(a.get("trainsWhere"), enums["trainsWhere"], low=1, high=3),
    }

    payout = None
    if data.get("payout") is not None:
        o = _dict(data.get("payout"))
        rail, account = o.get("rail"), o.get("account")
        if not common.account_ok(rail, account):
            raise common.bad()
        payout = {
            "rail": rail,
            "account": account,
            "holderName": common.text(o.get("holderName"), min_len=3, max_len=limits["fullNameMax"]),
        }

    if isinstance(data.get("termsVersion"), bool) or data.get("termsVersion") != TERMS_VERSION:
        raise common.bad()
    rules = data.get("rules")
    wanted = list(enums["coachRules"])
    if not isinstance(rules, list) or sorted(map(str, rules)) != sorted(wanted) or len(rules) != len(wanted):
        raise common.bad()

    return {
        "personal": personal,
        "education": education,
        "certificates": certificates,
        "specialties": common.subset(
            data.get("specialties"), enums["specialties"], low=limits["specialtiesMin"], high=limits["specialtiesMax"]
        ),
        "qualifications": common.text(data.get("qualifications"), min_len=20, max_len=limits["qualificationsMax"]),
        "yearsExperience": common.whole(data.get("yearsExperience"), low=0, high=limits["yearsExperienceMax"]),
        "testimonials": testimonials,
        "transformations": transformations,
        "approach": approach,
        "payout": payout,
        "termsVersion": TERMS_VERSION,
        "rules": wanted,
    }


def _file_refs(uid: str, app: dict) -> list:
    """Every (folder, path) pair the application names, in a fixed order."""
    base = f"coach-docs/{uid}/"
    refs = [(base + "photo/", app["personal"]["photoPath"])]
    refs += [(base + "education/", row["path"]) for row in app["education"] if row["path"]]
    refs += [(base + "certificates/", row["path"]) for row in app["certificates"]]
    refs += [(base + "testimonials/", row["imagePath"]) for row in app["testimonials"] if row["imagePath"]]
    for row in app["transformations"]:
        refs.append((base + "transformations/", row["beforePath"]))
        refs.append((base + "transformations/", row["afterPath"]))
    return refs


def under_prefix(path: str, prefix: str) -> bool:
    rest = path[len(prefix):] if path.startswith(prefix) else ""
    return bool(rest) and "/" not in rest and ".." not in rest


def _check_files(uid: str, app: dict, blobs) -> None:
    for prefix, path in _file_refs(uid, app):
        if not under_prefix(path, prefix) or not blobs.exists(path):
            raise common.refuse(errors.INVALID, errors.FILE_NOT_UPLOADED)


def _gate(snapshot, now: dt.datetime) -> int:
    """The round this application will carry, or the refusal that stops her."""
    if not snapshot.exists:
        return 1
    stored = snapshot.to_dict() or {}
    status = stored.get("status")
    previous = stored.get("round")
    previous = previous if isinstance(previous, int) and not isinstance(previous, bool) else 0
    if status == "submitted":
        raise common.refuse(errors.PRECONDITION, errors.APPLICATION_OPEN)
    if status == "rejected":
        decided = common.as_utc(stored.get("decidedAt"))
        if decided is not None and decided + common.days(common.LIMITS["reapplyAfterDays"]) > now:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    elif status != "needs_changes":
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    return previous + 1


def submit(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    verified: bool,
    coach_v: Optional[str],
    blobs,
    now: dt.datetime,
    payments_live: bool = False,
) -> dict:
    common.require_portfolio_live(live)
    common.require_verified(verified)
    if coach_v == "active":
        raise common.refuse(errors.PRECONDITION, errors.ALREADY_A_COACH)
    ref = db.collection(COLLECTION).document(uid)
    _gate(ref.get(), now)

    try:
        app = _validate(data, now)
    except errors.CoachingError as refusal:
        if refusal.reason == errors.BAD_REQUEST:
            raise common.bad(errors.APPLICATION_INCOMPLETE)
        raise
    if not payments_live:
        app["payout"] = None  # no money moves yet, so no account is kept
    _check_files(uid, app, blobs)

    locale = data.get("locale") if data.get("locale") in ("ar", "en") else "ar"
    consent = common.consent_ref(db, uid, COACH_TERMS)

    def body(transaction):
        round_no = _gate(ref.get(transaction=transaction), now)
        record = {
            "status": "submitted",
            "round": round_no,
            **app,
            "reasons": {},
            "note": "",
            "submittedAt": now,
            "decidedAt": None,
            "decidedBy": None,
        }
        assert set(record) == set(APPLICATION_KEYS)
        transaction.set(ref, record)
        transaction.set(consent, {"version": TERMS_VERSION, "at": now, "locale": locale})
        return round_no

    return {"status": "submitted", "round": common.run(db, body)}


# ------------------------------------------------------------------ review


def list_for_review(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    """Oldest first, 25 to a page. `after` is the last uid of the page before."""
    status = data.get("status", "submitted")
    if status is None:
        status = "submitted"
    common.one_of(status, common.ENUMS["applicationStatus"])
    after = data.get("after")
    if after is not None and (not isinstance(after, str) or not after or len(after) > 128):
        raise common.bad()

    collection = db.collection(COLLECTION)
    query = collection.where("status", "==", status).order_by("submittedAt")
    rows = []
    if not after:
        rows = list(query.limit(PAGE_SIZE + 1).stream())
    else:
        marker = collection.document(after).get()
        if marker.exists:
            # The cursor is the document itself, so equal times page cleanly.
            rows = list(query.start_after(marker).limit(PAGE_SIZE + 1).stream())
    more = len(rows) > PAGE_SIZE
    items = [{"uid": snapshot.id, **(snapshot.to_dict() or {})} for snapshot in rows[:PAGE_SIZE]]
    common.log_access(db, actor_uid, "applications_list", status, now)
    return {"items": items, "next": items[-1]["uid"] if more else None}


# ------------------------------------------------------------------ decide


def _reasons(value, decision: str) -> dict:
    if decision == "approve":
        return {}
    if not isinstance(value, dict) or not value:
        raise common.bad()
    out = {}
    for section, reason in value.items():
        common.one_of(section, common.ENUMS["applicationSections"])
        common.one_of(reason, common.ENUMS["sectionReasons"])
        out[section] = reason
    return out


def _checked(value, app: dict, decision: str) -> list:
    if decision != "approve":
        return []
    if not isinstance(value, list) or not value:
        raise common.bad()
    known = [row.get("id") for row in app.get("certificates") or []]
    if len(set(map(str, value))) != len(value) or any(v not in known for v in value):
        raise common.bad()
    return list(value)


def _public_coach(uid: str, app: dict, checked: list, now: dt.datetime) -> dict:
    personal, approach = app["personal"], app["approach"]
    badges = ["verifiedCoach", "certificatesChecked"]
    if app["yearsExperience"] >= 1:
        badges.append("yearsCoaching")
    doc = {
        "displayName": personal["displayName"],
        "headline": personal["headline"],
        "photoUrl": public_photo_path(uid),
        "governorate": personal["governorate"],
        "languages": list(personal["languages"]),
        "specialties": list(app["specialties"]),
        "approach": {
            "text": approach["text"],
            "checkInsPerWeek": approach["checkInsPerWeek"],
            "replyHours": approach["replyHours"],
            "trainsWhere": list(approach["trainsWhere"]),
        },
        "yearsExperience": app["yearsExperience"],
        "certificates": [
            {"title": row["title"], "issuer": row["issuer"], "year": row["year"]}
            for row in app["certificates"]
            if row["id"] in checked
        ],
        "testimonials": [{"text": row["text"], "from": row["from"]} for row in app["testimonials"]],
        "badges": badges,
        "stats": {"clientsCoached": 0, "plansShared": 0, "sessionsDone": 0},
        "fromPriceEgp": None,
        "fromMonthlyEgp": None,
        "acceptingClients": True,
        "autoAccept": True,
        "maxActiveClients": common.LIMITS["maxActiveClientsDefault"],
        "activeClients": 0,
        "published": False,
        "replyHours": approach["replyHours"],
        "trainsWhere": list(approach["trainsWhere"]),
        "updatedAt": now,
    }
    assert set(doc) == set(COACH_PUBLIC_KEYS)
    return doc


def decide(
    db,
    actor_uid: str,
    data: dict,
    *,
    merge_claims,
    blobs,
    notify,
    reencode,
    now: dt.datetime,
) -> dict:
    uid = common.text(data.get("uid"), max_len=128)
    common.refuse_if_subject(actor_uid, uid)
    decision = common.one_of(data.get("decision"), common.ENUMS["applicationDecision"])
    reasons = _reasons(data.get("reasons"), decision)
    note = common.optional_text(data.get("note"), max_len=common.LIMITS["noteMax"])

    ref = db.collection(COLLECTION).document(uid)
    snapshot = ref.get()
    if not snapshot.exists:
        raise common.refuse(errors.NOT_FOUND, errors.APPLICATION_NOT_FOUND)
    app = snapshot.to_dict() or {}
    if app.get("status") != "submitted":
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    checked = _checked(data.get("checkedCertificates"), app, decision)

    decided = common.decided_stamp(actor_uid, now)
    common.log_access(db, actor_uid, f"application_{decision}", uid, now)

    if decision != "approve":
        status = "needs_changes" if decision == "needs_changes" else "rejected"
        _finish(db, ref, {"status": status, "reasons": reasons, "note": note, **decided})
        notify(uid, "coachDecision")
        return {"status": status}

    # The photo comes first: it can be repeated safely if the write below
    # fails. The claim comes after the write, so a decision that loses a race
    # (a reject that commits first) never leaves her with a coach claim.
    write_public_photos(blobs, reencode, uid, blobs.read(app["personal"]["photoPath"]))

    coach_ref = db.collection("coaches").document(uid)
    private_ref = db.collection("coachPrivate").document(uid)
    user_ref = db.collection("users").document(uid)

    def body(transaction):
        current = ref.get(transaction=transaction)
        if (current.to_dict() or {}).get("status") != "submitted":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        existing_coach = coach_ref.get(transaction=transaction)
        existing_private = private_ref.get(transaction=transaction)
        user = user_ref.get(transaction=transaction)

        coach = _public_coach(uid, app, checked, now)
        before = existing_coach.to_dict() or {}
        for key in _KEPT_WHEN_RETURNING:
            if key in before:
                coach[key] = before[key]
        private = {
            "fullName": app["personal"]["fullName"],
            "payoutState": "pending" if app["payout"] else "none",
            "suspended": False,
            "claimPending": True,
            "owedEgp": 0,
            "paidEgp": 0,
            "updatedAt": now,
        }
        if app["payout"]:
            private["payout"] = dict(app["payout"])
        before_private = existing_private.to_dict() or {}
        for key in ("owedEgp", "paidEgp"):
            if isinstance(before_private.get(key), int):
                private[key] = before_private[key]
        roles = (user.to_dict() or {}).get("roles") or {}
        held = list(roles.get("held") or [])
        if "coach" not in held:
            held.append("coach")

        transaction.set(coach_ref, coach)
        transaction.set(private_ref, private)
        transaction.set(user_ref, {"roles": {"held": held}}, merge=True)
        transaction.update(ref, {"status": "approved", "reasons": {}, "note": note, **decided})

    common.run(db, body)
    _mint(db, uid, merge_claims)
    try:
        from . import media

        media.seed_from_application(db, uid, app, now=now)
    except Exception:
        # Safe to repeat; the approval stands and her items can be added again.
        logging.getLogger(__name__).error("portfolio_seed_failed")
    notify(uid, "coachDecision")
    return {"status": "approved"}


def _mint(db, uid: str, merge_claims) -> bool:
    """The coach claim, after the approval has committed. A failure leaves
    `claimPending` for the hourly sweep; the approval stands."""
    try:
        merge_claims(uid, {"coachV": "active"})
        db.collection("coachPrivate").document(uid).update({"claimPending": False})
    except Exception:  # noqa: BLE001
        logging.getLogger(__name__).error("coach_claim_mint_failed")
        return False
    return True


def retry_claims(db, *, merge_claims) -> int:
    """Mints the claim for every approved coach still waiting for it. A coach
    who has been suspended since is left alone. Returns how many it minted."""
    minted = 0
    for snap in list(db.collection("coachPrivate").where("claimPending", "==", True).stream()):
        row = snap.to_dict() or {}
        if row.get("suspended"):
            continue
        application = db.collection(COLLECTION).document(snap.id).get()
        if not application.exists or (application.to_dict() or {}).get("status") != "approved":
            continue
        if _mint(db, snap.id, merge_claims):
            minted += 1
    return minted


def _finish(db, ref, changes: dict) -> None:
    def body(transaction):
        if (ref.get(transaction=transaction).to_dict() or {}).get("status") != "submitted":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, changes)

    common.run(db, body)
