"""A client's subscription to a coach, from request to the end.

requested -> awaiting_payment -> payment_review -> active -> ended, with the
side exits declined, cancelled, expired, payment_failed and ended_early. Only
this package (and proofs.py and refunds.py, which finish the journey) writes a
status; the client's phone only reads it.

The client sees one price, `priceFinalEgp`. The coach's own price lives in
`subscriptions/{id}/private/terms` and `coachPrivate/`, which no client rule
opens.
"""

from __future__ import annotations

import datetime as dt
import math
from typing import Callable, Optional

from google.cloud import firestore

from . import agreement, chat, common, errors, invites, receiving

OPEN = tuple(common.ENUMS["subscriptionOpen"])
LIMITS = common.LIMITS
PACKAGE_KEYS = tuple(common.CONTRACT["documents"]["subscription"]["packageSnapshot"])
HEALTH_KEYS = tuple(common.ENUMS["healthQuestions"])
FLAGGED_STAGES = ("pregnant", "postpartum")
INBODY_RANGES = common.CONTRACT["documents"]["subscription"]["inbody"]


def intake_flagged(intake: dict) -> bool:
    """Anything that makes her coach read her answers before a plan goes out."""
    return (
        any((intake.get("health") or {}).values())
        or intake.get("lifeStage") in FLAGGED_STAGES
        or intake.get("eatingHistory") is True
    )


def system_message(transaction, db, rel_id: str, kind: str, now: dt.datetime) -> None:
    ref = db.collection("relationships").document(rel_id).collection("messages").document()
    transaction.set(
        ref, {"senderUid": "system", "type": "system", "systemKind": kind, "createdAt": now}
    )


def locale_of(value) -> str:
    return common.one_of(value, common.ENUMS["languages"])


def _id(value, reason: str = errors.BAD_REQUEST) -> str:
    return common.text(value, max_len=128, reason=reason)


def inbody_of(raw) -> dict:
    """The InBody numbers she confirmed, each inside the contract's range. Only
    these numbers: never the picture, the text read from it or a date."""
    if not isinstance(raw, dict) or not raw or set(raw) - set(INBODY_RANGES):
        raise common.bad()
    out = {}
    for key, value in raw.items():
        low, high = INBODY_RANGES[key]
        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(value)
            or not low <= value <= high
        ):
            raise common.bad()
        out[key] = round(value) if key == "bmrKcal" else round(float(value), 1)
    return out


def intake_of(raw) -> dict:
    """The questions she answered, checked and trimmed to the contract."""
    if not isinstance(raw, dict):
        raise common.bad()
    health = raw.get("health")
    if not isinstance(health, dict) or set(health) != set(HEALTH_KEYS):
        raise common.bad()
    if any(not isinstance(health[key], bool) for key in HEALTH_KEYS):
        raise common.bad()
    ack = raw.get("doctorAck", False)
    if not isinstance(ack, bool):
        raise common.bad()
    eating = raw.get("eatingHistory", False)
    if not isinstance(eating, bool):
        raise common.bad()
    allergies = raw.get("allergies", [])
    if not isinstance(allergies, list) or len(allergies) > 16:
        raise common.bad()
    allergies = [common.text(item, min_len=1, max_len=30) for item in allergies]
    life_stage = raw.get("lifeStage")
    if life_stage is not None:
        life_stage = common.text(life_stage, min_len=1, max_len=30)
    flagged = any(health.values()) or life_stage in FLAGGED_STAGES or eating
    if flagged and not ack:
        raise common.bad()
    note = common.optional_text(raw.get("note"), max_len=LIMITS["noteMax"])
    chat.refuse_contact(allergies, life_stage, note)
    inbody = raw.get("inbody")
    out = {
        "goal": common.one_of(raw.get("goal"), common.ENUMS["goals"]),
        "level": common.one_of(raw.get("level"), common.ENUMS["levels"]),
        "daysPerWeek": common.whole(raw.get("daysPerWeek"), low=1, high=7),
        "place": common.one_of(raw.get("place"), common.ENUMS["places"]),
        "allergies": allergies,
        "lifeStage": life_stage,
        "eatingHistory": eating,
        "health": {key: health[key] for key in HEALTH_KEYS},
        "doctorAck": ack,
        "note": note,
    }
    if inbody is not None:
        out["inbody"] = inbody_of(inbody)
    return out


def first_name(value) -> str:
    """Her first name as she gave it, for the coach's list. Never a full name,
    a phone number or an id."""
    words = value.split() if isinstance(value, str) else []
    return words[0][:30] if words and not any(ch.isdigit() for ch in words[0]) else ""


CONSENT_VERSION = 2
"""Version of the two ticks on the request form (sharing her answers with the
coach, and storing them in Frankfurt). Version 1 was written by the server
without the client sending anything; version 2 is what she ticked, with the
hash of the words she saw."""
_HEX = set("0123456789abcdef")


def known_hashes(version_key: str, locale: str, part: str, name: str = "") -> set:
    """The hashes of every text the app has shown for that tick, language and
    version (coaching_contract.json, consentTexts)."""
    texts = common.CONTRACT["consentTexts"][version_key][locale]
    texts = texts[part] if isinstance(texts, dict) else texts
    return {common.sha(text.replace("{name}", name)) for text in texts}


def consent_of(raw, locale: str, coach_name: str, with_inbody: bool = False) -> Optional[dict]:
    """Her ticks as the app sends them: the version, the hash of each text she
    saw and the app version. None when the app sent none: app 1.0.0 has no
    such field and its request is recorded with the version 1 ticks instead.
    The InBody tick is required when the intake holds her numbers and refused
    when it does not.
    shortcut: a modified app can skip the field and get the version 1 record,
    a weaker proof than none of it being possible; drop the legacy path once
    1.0.0 is no longer served. Anything else is refused: no ticks, no request."""
    if raw is None:
        if with_inbody:
            raise common.bad()
        return None
    if not isinstance(raw, dict) or raw.get("version") != CONSENT_VERSION or isinstance(raw.get("version"), bool):
        raise common.bad()
    if not with_inbody and raw.get("inbodyHash") is not None:
        raise common.bad()
    out = {"version": CONSENT_VERSION}
    parts = (("shareHash", "share"), ("transferHash", "transfer"))
    for key, part in parts + ((("inbodyHash", "inbody"),) if with_inbody else ()):
        value = raw.get(key)
        if not isinstance(value, str) or len(value) != 64 or not set(value) <= _HEX:
            raise common.bad()
        if value not in known_hashes("coachingRequest2", locale, part, coach_name):
            raise common.bad()
        out[key] = value
    app = raw.get("appVersion")
    if app is not None:
        if not isinstance(app, str) or len(app) > 32:
            raise common.bad()
        out["appVersion"] = app
    return out


def client_name(given) -> str:
    """The name the coach sees: only the first name she typed when she asked.
    Nothing typed, or a bad value (not text, over 40, digits), gives no name."""
    return first_name(given) if isinstance(given, str) and len(given) <= 40 else ""


def pay_to(accounts: dict) -> dict:
    """The enabled rails of the receiving accounts, as the client will see them."""
    snapshot = {}
    for rail in common.RAILS:
        account = accounts.get(rail)
        if isinstance(account, dict) and account.get("enabled") is True:
            snapshot[rail] = {
                "address": account["address"],
                "holderName": account["holderName"],
                "enabled": True,
            }
    if not snapshot:
        raise common.refuse(errors.PRECONDITION, errors.ACCOUNTS_NOT_SET)
    snapshot["version"] = accounts.get("version", 0)
    return snapshot


def acceptance(accounts: dict, now: dt.datetime, code: Callable[[], str]) -> dict:
    """The fields that move a request to awaiting_payment."""
    return {
        "status": "awaiting_payment",
        "acceptedAt": now,
        "payTo": pay_to(accounts),
        "paymentCode": code(),
        "payBy": now + common.hours(LIMITS["payByHours"]),
        "payment": {"state": "awaiting", "attempts": 0, "lastReason": None, "proofId": None},
        "statusAt": now,
    }


def _accounts(db, transaction) -> dict:
    accounts = common.read(receiving.accounts_ref(db), transaction)
    if accounts is None:
        raise common.refuse(errors.PRECONDITION, errors.ACCOUNTS_NOT_SET)
    return accounts


HOLDING = ("active",)
"""Statuses that hold one of a coach's places; with payments on, the two
waiting-for-money statuses hold one too. Asking is counted only when a request
is answered for her (automatic acceptance), never when she answers one."""
HOLDING_PAYING = ("awaiting_payment", "payment_review")


def held_places(
    db, transaction, coach_uid: str, payments_live: bool = False, asked: bool = False
) -> int:
    """How many of her places are taken: active, (with payments on) waiting for
    or under review of a payment, and with `asked` the open requests too."""
    statuses = HOLDING + (HOLDING_PAYING if payments_live else ()) + (("requested",) if asked else ())
    query = db.collection("subscriptions").where("coachUid", "==", coach_uid).where("status", "in", list(statuses))
    return sum(1 for _ in query.stream(transaction=transaction))


INSTAPAY_PAY_BY_DAYS = 7
"""How long an InstaPay acceptance waits for the client: the late-proof window."""


def instapay_acceptance(now: dt.datetime) -> dict:
    """The fields that move a request to awaiting_payment when the client pays
    the coach's own InstaPay address (functions/payments). No payment code and
    no `payTo`: the payment document carries the address and the amount."""
    return {
        "status": "awaiting_payment",
        "acceptedAt": now,
        "paymentCode": None,
        "payBy": now + common.days(INSTAPAY_PAY_BY_DAYS),
        "payment": {"state": "awaiting", "attempts": 0, "lastReason": None, "proofId": None},
        "statusAt": now,
    }


def free_start(package: dict, now: dt.datetime) -> dict:
    """The fields of a coaching that starts at once because nothing is paid."""
    return {
        "status": "active",
        "acceptedAt": now,
        "startsAt": now,
        "endsAt": now + common.days(package["durationDays"]),
        "free": True,
        "statusAt": now,
    }


def _has_coached(rel) -> bool:
    """A renewal: this pair already had a coaching (existing clients are not affected by the agreement rule)."""
    row = (rel.to_dict() or {}) if rel.exists else {}
    return row.get("status") in ("active", "ended") or bool(row.get("activeSubId"))


def begin(
    transaction, db, *, sub_id: str, coach_uid: str, client_uid: str, rel_id: str,
    rel, coach_ref, coach, now: dt.datetime, source: Optional[str] = None, held: bool = False,
) -> None:
    """The relationship opens, her client count goes up and the chat says it
    started. `rel` and `coach` are snapshots read before any write. `source`
    ('invite' or 'app') is written once, when the pair's first coaching begins."""
    first_time = not rel.exists or (rel.to_dict() or {}).get("status", "none") == "none"
    relation = {"status": "active", "chatOpen": True, "activeSubId": sub_id}
    if not rel.exists:
        relation.update(coachUid=coach_uid, clientUid=client_uid, createdAt=now)
    if not (rel.to_dict() or {}).get("source"):  # the pair's fee rate is fixed by its first coaching
        relation["source"] = source or "app"
    if held:  # her account is on hold (coachPrivate, read by the caller before any write)
        relation["coachAway"] = True
    transaction.set(db.collection("relationships").document(rel_id), relation, merge=True)
    if coach.exists:
        counters = {"activeClients": firestore.Increment(1)}
        if first_time:
            counters["stats.clientsCoached"] = firestore.Increment(1)
        transaction.update(coach_ref, counters)
    system_message(transaction, db, rel_id, "started", now)


def fresh_code(db, transaction, code: Callable[[], str]) -> str:
    """A payment code no other subscription carries (five tries)."""
    for _ in range(5):
        candidate = code()
        taken = db.collection("subscriptions").where("paymentCode", "==", candidate).limit(1)
        if not any(True for _ in taken.stream(transaction=transaction)):
            return candidate
    raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)


def request(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    verified: bool,
    now: dt.datetime,
    notify,
    payments_live: bool = False,
    instapay: bool = False,
    code=common.payment_code,
) -> dict:
    common.require_clients_live(live)
    common.require_verified(verified)
    if (payments_live or instapay) and not common.app_can_pay(data.get("appBuild")):
        raise common.refuse(errors.PRECONDITION, errors.APP_UPDATE_NEEDED)
    coach_uid = _id(data.get("coachUid"))
    package_id = _id(data.get("packageId"))
    intake = intake_of(data.get("intake"))
    locale = locale_of(data.get("locale"))
    raw_consent = data.get("consent")
    given_name = data.get("clientName")
    chat.refuse_contact(given_name)
    unavailable = common.refuse(errors.PRECONDITION, errors.COACH_UNAVAILABLE)
    if coach_uid == uid:
        raise unavailable

    coach_ref = db.collection("coaches").document(coach_uid)
    package_ref = coach_ref.collection("packages").document(package_id)
    price_ref = db.collection("coachPrivate").document(coach_uid).collection("prices").document(package_id)
    users = db.collection("users")
    rel_id = common.rel_id(coach_uid, uid)
    rel_ref = db.collection("relationships").document(rel_id)
    sub_ref = db.collection("subscriptions").document()
    source = "app"
    if data.get("inviteCode") is not None:
        try:  # her own code only; any other code is the same as none
            source = "invite" if invites.coach_for_code(db, uid, data["inviteCode"], now) == coach_uid else "app"
        except errors.CoachingError:
            pass

    def body(transaction):
        coach = coach_ref.get(transaction=transaction)
        blocked_her = users.document(coach_uid).collection("blocks").document(uid).get(transaction=transaction)
        blocked_coach = users.document(uid).collection("blocks").document(coach_uid).get(transaction=transaction)
        package = package_ref.get(transaction=transaction)
        price = price_ref.get(transaction=transaction)
        rel = rel_ref.get(transaction=transaction)
        coach_private = db.collection("coachPrivate").document(coach_uid).get(transaction=transaction)
        open_pair = (
            db.collection("subscriptions")
            .where("clientUid", "==", uid)
            .where("coachUid", "==", coach_uid)
            .where("status", "in", list(OPEN))
            .limit(1)
        )
        existing = list(open_pair.stream(transaction=transaction))
        seen = {
            name: common.consent_ref(db, uid, name).get(transaction=transaction)
            for name in ("coaching-share-v1", "transfer-abroad-v1")
        } if raw_consent is None else {}
        row = coach.to_dict() if coach.exists else None
        if (
            row is None
            or row.get("published") is not True
            or row.get("acceptingClients") is not True
            or blocked_her.exists
            or blocked_coach.exists
        ):
            raise unavailable
        consent = consent_of(raw_consent, locale, row.get("displayName") or "", "inbody" in intake)
        cap = row.get("maxActiveClients", LIMITS["maxActiveClientsDefault"])
        if row.get("activeClients", 0) >= cap:
            raise unavailable
        if instapay and row.get("instapayReady") is not True:
            raise unavailable  # 4.11: no address yet, the package shows "Message the coach"
        pack = package.to_dict() if package.exists else None
        if pack is None or pack.get("active") is not True or not price.exists:
            raise common.refuse(errors.NOT_FOUND, errors.PACKAGE_NOT_FOUND)
        stale = [
            snap for snap in existing
            if common.app_can_pay(data.get("appBuild"))
            and (snap.to_dict() or {}).get("status") == "requested"
            and not common.app_can_pay((snap.to_dict() or {}).get("appBuild"))
        ]
        if existing and len(stale) != len(existing):
            raise common.refuse(errors.PRECONDITION, errors.ALREADY_REQUESTED)
        pair_source = (rel.to_dict() or {}).get("source") or source  # fixed once the pair's first coaching has begun
        accounts = None
        if payments_live:
            accounts = _accounts(db, transaction)
            pay_to(accounts)  # refuses here when no rail is enabled

        sub = {
            "coachUid": coach_uid,
            "clientUid": uid,
            "relId": rel_id,
            "packageId": package_id,
            "package": {key: pack.get(key) for key in PACKAGE_KEYS},
            "priceFinalEgp": pack["priceFinalEgp"],
            "clientName": client_name(given_name),
            "source": pair_source,
            "appBuild": data["appBuild"] if common.app_can_pay(data.get("appBuild")) else None,
            "status": "requested",
            "intake": intake,
            "sessionsIncluded": common.sessions_included(pack["liveSessionsPerMonth"], pack["durationDays"]),
            "sessionsUsed": 0,
            "createdAt": now,
            "statusAt": now,
        }
        auto = (
            row.get("autoAccept") is True
            and (agreement.ready(coach_private.to_dict()) or _has_coached(rel))
            and not intake_flagged(intake)
            and held_places(db, transaction, coach_uid, payments_live or instapay, asked=True) < cap
        )
        free = auto and not (payments_live or instapay)
        if free:
            sub.update(free_start(sub["package"], now))
        elif auto:
            sub.update(
                acceptance(accounts, now, lambda: fresh_code(db, transaction, code))
                if payments_live else instapay_acceptance(now)
            )

        if free:
            begin(
                transaction, db, sub_id=sub_ref.id, coach_uid=coach_uid, client_uid=uid,
                rel_id=rel_id, rel=rel, coach_ref=coach_ref, coach=coach, now=now, source=pair_source,
            )
        elif not rel.exists:
            transaction.set(
                rel_ref,
                {
                    "coachUid": coach_uid,
                    "clientUid": uid,
                    "status": "none",
                    "chatOpen": False,
                    "createdAt": now,
                },
            )
        for snap in stale:  # her old request from an app that cannot pay: replaced by this one
            transaction.update(snap.reference, {"status": "cancelled", "endReason": "other", "statusAt": now})
        transaction.set(sub_ref, sub)
        transaction.set(
            sub_ref.collection("private").document("terms"),
            {
                "coachPriceEgp": price.to_dict()["coachPriceEgp"],
                "packageId": package_id,
                "createdAt": now,
            },
        )
        if consent is None:
            for name, snap in seen.items():
                common.record_consent(transaction, common.consent_ref(db, uid, name), snap, locale, now)
        else:
            transaction.set(
                common.consent_ref(db, uid, f"coaching-request-v{CONSENT_VERSION}-{sub_ref.id}"),
                {**consent, "at": now, "locale": locale, "coachUid": coach_uid, "subId": sub_ref.id},
            )
        return sub["status"]

    status = common.run(db, body)
    notify(coach_uid, "coachingRequest")
    return {"subId": sub_ref.id, "status": status}


def _own_sub(transaction, db, sub_id: str, field: str, uid: str):
    ref = db.collection("subscriptions").document(sub_id)
    snap = ref.get(transaction=transaction)
    row = snap.to_dict() if snap.exists else None
    if row is None or row.get(field) != uid:
        raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    return ref, row


def respond(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    coach_v,
    now: dt.datetime,
    notify,
    payments_live: bool = False,
    instapay: bool = False,
    code=common.payment_code,
) -> dict:
    common.require_clients_live(live)
    common.require_active_coach(db, uid, coach_v)
    sub_id = _id(data.get("subId"))
    decision = common.one_of(data.get("decision"), common.ENUMS["requestDecision"])
    reason = None
    if decision == "decline":
        reason = common.one_of(data.get("reason"), common.ENUMS["declineReasons"])

    holder = {}

    def body(transaction):
        ref, sub = _own_sub(transaction, db, sub_id, "coachUid", uid)
        if sub.get("status") != "requested":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        holder["client"] = sub["clientUid"]
        if decision == "accept":
            coach_ref = db.collection("coaches").document(uid)
            coach = coach_ref.get(transaction=transaction)
            renewal = _has_coached(db.collection("relationships").document(sub["relId"]).get(transaction=transaction))
            if not (renewal or agreement.ready(db.collection("coachPrivate").document(uid).get(transaction=transaction).to_dict())):
                raise common.refuse(errors.PRECONDITION, errors.AGREEMENT_NEEDED)
            cap = (coach.to_dict() or {}).get("maxActiveClients", LIMITS["maxActiveClientsDefault"])
            if held_places(db, transaction, uid, payments_live or instapay) >= cap:
                raise common.refuse(errors.PRECONDITION, errors.COACH_UNAVAILABLE)
            if (payments_live or instapay) and not common.app_can_pay(sub.get("appBuild")):
                # shortcut: only the request's own build is checked; an app that updates later is accepted on a new request.
                raise common.refuse(errors.PRECONDITION, errors.CLIENT_UPDATE_NEEDED)
            if instapay and not payments_live and (coach.to_dict() or {}).get("instapayReady") is not True:
                from payments import errors as p_errors
                raise common.refuse(errors.PRECONDITION, p_errors.COACH_NOT_READY)
            if payments_live or instapay:
                changes = (
                    acceptance(_accounts(db, transaction), now, lambda: fresh_code(db, transaction, code))
                    if payments_live else instapay_acceptance(now)
                )
            else:
                rel = db.collection("relationships").document(sub["relId"]).get(transaction=transaction)
                changes = free_start(sub["package"], now)
                holder["started"] = True
                transaction.update(ref, changes)
                begin(
                    transaction, db, sub_id=sub_id, coach_uid=uid, client_uid=sub["clientUid"],
                    rel_id=sub["relId"], rel=rel, coach_ref=coach_ref, coach=coach, now=now, source=sub.get("source"),
                )
                return changes["status"]
        else:
            changes = {"status": "declined", "declineReason": reason, "statusAt": now}
        transaction.update(ref, changes)
        return changes["status"]

    try:
        status = common.run(db, body)
    except errors.CoachingError as refused:
        if refused.reason == errors.CLIENT_UPDATE_NEEDED:
            ref = db.collection("subscriptions").document(sub_id)
            if not (ref.get().to_dict() or {}).get("updateNudged"):  # once per request
                ref.update({"updateNudged": True})
                notify(holder["client"], "updateToContinue")
        raise
    notify(holder["client"], "requestAnswered")
    if holder.get("started"):
        notify(holder["client"], "coachingStarted")
    return {"status": status}


def cancel_request(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    common.require_clients_live(live)
    sub_id = _id(data.get("subId"))

    def body(transaction):
        ref, sub = _own_sub(transaction, db, sub_id, "clientUid", uid)
        if sub.get("status") not in ("requested", "awaiting_payment"):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, {"status": "cancelled", "statusAt": now})

    common.run(db, body)
    return {"status": "cancelled"}


def release_slot(transaction, coach_ref, coach: dict) -> None:
    """One active client fewer on her page, never below zero."""
    transaction.update(coach_ref, {"activeClients": max(0, coach.get("activeClients", 0) - 1)})


def close_relationship(transaction, db, rel_id: str) -> None:
    transaction.update(
        db.collection("relationships").document(rel_id), {"status": "ended", "chatOpen": False}
    )


def settle_ledger(transaction, db, coach_uid: str, sub_id: str, entry: dict) -> None:
    """Reverses a coach's ledger line when the subscription ends early. A line
    already paid out stays as it is: that money has gone."""
    if entry.get("status") not in ("pending", "eligible"):
        return
    private = db.collection("coachPrivate").document(coach_uid)
    transaction.update(private.collection("ledger").document(sub_id), {"status": "reversed"})
    if entry["status"] == "eligible":
        transaction.set(private, {"owedEgp": firestore.Increment(-entry.get("coachAmountEgp", 0))}, merge=True)


def settle_ledger_to(transaction, db, coach_uid: str, sub_id: str, entry: dict, share: int, now: dt.datetime) -> None:
    """Sets a coach's ledger line to `share` after a refund: eligible now, or
    reversed when nothing is left. A line already paid out stays as it is."""
    if entry.get("status") not in ("pending", "eligible"):
        return
    private = db.collection("coachPrivate").document(coach_uid)
    owed_before = entry.get("coachAmountEgp", 0) if entry["status"] == "eligible" else 0
    changes = {"coachAmountEgp": share, "status": "eligible" if share > 0 else "reversed"}
    if share > 0:
        changes["eligibleAt"] = now
    transaction.update(private.collection("ledger").document(sub_id), changes)
    if share != owed_before:
        transaction.set(private, {"owedEgp": firestore.Increment(share - owed_before)}, merge=True)


def read_ending(transaction, db, sub_id: str, sub: dict, *, money: bool) -> dict:
    """Every read the end of a coaching needs, done before any write. With
    `money` it also reads her ledger line, the terms and the receipt."""
    coach_ref = db.collection("coaches").document(sub["coachUid"])
    seen = {"coachRef": coach_ref, "coach": coach_ref.get(transaction=transaction)}
    if money:
        ref = db.collection("subscriptions").document(sub_id)
        receipt_ref = db.collection("receipts").document(sub_id)
        ledger = db.collection("coachPrivate").document(sub["coachUid"]).collection("ledger").document(sub_id)
        seen.update(
            entry=ledger.get(transaction=transaction),
            terms=ref.collection("private").document("terms").get(transaction=transaction),
            receiptRef=receipt_ref,
            receipt=receipt_ref.get(transaction=transaction),
        )
    return seen


def write_ending(
    transaction,
    db,
    sub_id: str,
    sub: dict,
    seen: dict,
    *,
    changes: dict,
    now: dt.datetime,
    ledger: str = "keep",
    share: int = 0,
    refund=None,
) -> None:
    """Ends one coaching: the subscription's new fields, the chat closed, her
    place freed and a system line in the chat. `ledger` says what happens to
    the coach's line: "keep" leaves it, "reverse" cancels it, "share" sets it
    to `share`. A `refund` amount is noted on the receipt."""
    transaction.update(db.collection("subscriptions").document(sub_id), {**changes, "nextSessionAt": None})
    close_relationship(transaction, db, sub["relId"])
    if seen["coach"].exists:
        release_slot(transaction, seen["coachRef"], seen["coach"].to_dict())
    entry = seen.get("entry")
    if entry is not None and entry.exists:
        if ledger == "share":
            settle_ledger_to(transaction, db, sub["coachUid"], sub_id, entry.to_dict(), share, now)
        elif ledger == "reverse":
            settle_ledger(transaction, db, sub["coachUid"], sub_id, entry.to_dict())
    receipt = seen.get("receipt")
    if refund is not None and receipt is not None and receipt.exists:
        transaction.update(seen["receiptRef"], {"refund": {"amountEgp": refund, "at": now}})
    system_message(transaction, db, sub["relId"], "ended", now)


def notify_ended(notify, client_uid: str, coach_uid: str) -> None:
    notify(client_uid, "coachingEnded")
    notify(coach_uid, "coachingEnded")


def end_early(db, actor_uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    sub_id = _id(data.get("subId"))
    reason = common.one_of(data.get("reason"), common.ENUMS["endReasons"])
    rail, amount, reference = data.get("rail"), data.get("refundEgp"), data.get("refundReference")
    refunding = any(value is not None for value in (rail, amount, reference))
    if refunding:
        rail = common.one_of(rail, common.RAILS)
        if not common.reference_ok(rail, reference):
            raise common.bad()
        amount = common.whole(amount, low=0, high=100000)
    common.log_access(db, actor_uid, "end", sub_id, now)

    parties = {}

    def body(transaction):
        sub = common.read(db.collection("subscriptions").document(sub_id), transaction)
        if sub is None:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        common.refuse_if_subject(actor_uid, sub.get("clientUid"), sub.get("coachUid"))
        if sub.get("status") != "active" or (sub.get("cancellation") or {}).get("state") == "requested":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        price = sub["priceFinalEgp"]
        if refunding and (amount > price or sub.get("free")):
            raise common.bad()
        seen = read_ending(transaction, db, sub_id, sub, money=True)
        parties.update(coach=sub["coachUid"], client=sub["clientUid"])

        changes = {"status": "ended_early", "endReason": reason, "statusAt": now}
        ledger, share = "reverse", 0
        if refunding:
            changes["refund"] = {"amountEgp": amount, "rail": rail, "reference": reference, "at": now}
            if seen["terms"].exists:
                ledger = "share"
                share = common.coach_share_of_kept(seen["terms"].to_dict()["coachPriceEgp"], price, amount)
        write_ending(
            transaction, db, sub_id, sub, seen,
            changes=changes, now=now, ledger=ledger, share=share, refund=amount if refunding else None,
        )

    common.run(db, body)
    notify_ended(notify, parties["client"], parties["coach"])
    return {"status": "ended_early"}


def blocked_either(transaction, db, a: str, b: str) -> bool:
    """Whether either of the two has blocked the other."""
    users = db.collection("users")
    return (
        users.document(a).collection("blocks").document(b).get(transaction=transaction).exists
        or users.document(b).collection("blocks").document(a).get(transaction=transaction).exists
    )


def end_open(transaction, db, sub_id: str, sub: dict, end_reason: str, now: dt.datetime) -> str:
    """Ends one open coaching for a party who left or a block. Asking becomes
    `cancelled`; waiting for the transfer, or running, becomes `ended_early`
    with `end_reason` (a running one also closes the chat, frees her place and
    says so in the chat). Money in review, or a cancellation waiting for staff,
    is left to staff."""
    ref = db.collection("subscriptions").document(sub_id)
    status = sub.get("status")
    if status == "requested":
        transaction.update(ref, {"status": "cancelled", "statusAt": now})
        return "cancelled"
    changes = {"status": "ended_early", "endReason": end_reason, "statusAt": now}
    if status == "awaiting_payment":
        transaction.update(ref, changes)
        return "ended_early"
    if status == "active" and (sub.get("cancellation") or {}).get("state") != "requested":
        seen = read_ending(transaction, db, sub_id, sub, money=False)
        write_ending(transaction, db, sub_id, sub, seen, changes=changes, now=now)
        return "ended_early"
    raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)


def end_mine(db, uid: str, data: dict, *, live: bool, now: dt.datetime, notify) -> dict:
    """Either party leaves a coaching: the client (`client_left`) or the coach
    (`coach_left`). The other party is pushed. The optional `reason` is checked
    and not kept."""
    common.require_clients_live(live)
    sub_id = _id(data.get("subId"))
    common.optional_text(data.get("reason"), max_len=LIMITS["noteMax"])
    ref = db.collection("subscriptions").document(sub_id)
    other = {}

    def body(transaction):
        sub = common.read(ref, transaction)
        if sub is None or uid not in (sub.get("clientUid"), sub.get("coachUid")):
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        by_client = uid == sub["clientUid"]
        if not by_client:
            common.require_not_on_hold(db, uid, transaction)
        other["uid"] = sub["coachUid"] if by_client else sub["clientUid"]
        return end_open(transaction, db, sub_id, sub, "client_left" if by_client else "coach_left", now)

    status = common.run(db, body)
    notify(other["uid"], "coachingEnded")
    return {"status": status}


def end_for_block(db, blocker_uid: str, blocked_uid: str, *, now: dt.datetime) -> int:
    """A block between a client and a coach ends every open coaching between
    them (`safety`). Nobody is pushed, so the block is not signalled. Returns
    how many it ended."""
    ended = 0
    for client_uid, coach_uid in ((blocker_uid, blocked_uid), (blocked_uid, blocker_uid)):
        open_pair = (
            db.collection("subscriptions")
            .where("clientUid", "==", client_uid)
            .where("coachUid", "==", coach_uid)
            .where("status", "in", list(OPEN))
        )
        for snap in list(open_pair.stream()):
            ref = snap.reference

            def body(transaction, ref=ref):
                row = common.read(ref, transaction)
                if row is None or row.get("status") not in OPEN:
                    return False
                try:
                    end_open(transaction, db, ref.id, row, "safety", now)
                except errors.CoachingError:
                    return False  # money in review: staff decide
                return True

            ended += bool(common.run(db, body))
    return ended


def _at(row: dict, *keys: str):
    for key in keys:
        value = common.as_utc(row.get(key))
        if value is not None:
            return value
    return None


def _due(row: dict, limit: dt.datetime, *keys: str) -> bool:
    """Whether the first of these times she has is at or before `limit`."""
    moment = _at(row, *keys)
    return moment is not None and moment <= limit


def _expire(db, sub_id: str, wanted: str, now: dt.datetime, due: Callable[[dict], bool]) -> Optional[dict]:
    """The row it expired, or None when it was no longer due."""
    ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None or row.get("status") != wanted or not due(row):
            return None
        transaction.update(ref, {"status": "expired", "statusAt": now})
        return row

    return common.run(db, body)


PAYMENT_WAITING = ("proof_submitted", "coach_not_received", "in_review", "different_amount")
"""InstaPay payment statuses in which a decision is pending: the acceptance it
pays for must outlive its pay-by day (functions/payments/model.py)."""


def _payment_in_flight(transaction, db, sub_id: str, now: dt.datetime) -> bool:
    """Whether a payment for this acceptance still has a proof to come or a
    decision to wait for. Such an acceptance is held, never expired."""
    for snap in db.collection("payments").where("subId", "==", sub_id).stream(transaction=transaction):
        row = snap.to_dict() or {}
        if row.get("status") in PAYMENT_WAITING:
            return True
        if row.get("status") in ("awaiting_payment", "expired") and (_at(row, "lateUntil") or now) > now:
            return True
    return False


def _expire_unpaid(db, sub_id: str, now: dt.datetime) -> bool:
    ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None or row.get("status") != "awaiting_payment" or not _due(row, now, "payBy"):
            return False
        if _payment_in_flight(transaction, db, sub_id, now):
            return False
        transaction.update(ref, {"status": "expired", "statusAt": now})
        return True

    return common.run(db, body)


def _finish(db, sub_id: str, now: dt.datetime):
    """Active past its end: ended, chat read-only, her slot freed."""
    ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None or row.get("status") != "active" or not _due(row, now, "endsAt"):
            return None
        if (row.get("cancellation") or {}).get("state") == "requested":
            return None
        if (common.read(db.collection("coachPrivate").document(row["coachUid"]), transaction) or {}).get("hold"):
            return None  # her account went on hold since the sweep looked; release moves the end date
        seen = read_ending(transaction, db, sub_id, row, money=False)
        write_ending(transaction, db, sub_id, row, seen, changes={"status": "ended", "statusAt": now}, now=now)
        return row["coachUid"], row["clientUid"]

    return common.run(db, body)


def _warn(db, sub_id: str, now: dt.datetime):
    ref = db.collection("subscriptions").document(sub_id)
    horizon = now + common.days(LIMITS["endsSoonDays"])

    def body(transaction):
        row = common.read(ref, transaction) or {}
        ends = _at(row, "endsAt")
        if row.get("status") != "active" or row.get("endsSoonSent") or ends is None:
            return None
        if row.get("provisionalUntil"):
            return None  # a short stay waiting for the coach's confirmation, not a package running out
        if not (now < ends <= horizon):
            return None
        transaction.update(ref, {"endsSoonSent": True})
        system_message(transaction, db, row["relId"], "endsSoon", now)
        return row["clientUid"], row.get("coachUid")

    return common.run(db, body)


def _release_entry(db, ref, now: dt.datetime) -> bool:
    private = ref.parent.parent

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None or row.get("status") != "pending":
            return False
        eligible = _at(row, "eligibleAt")
        if eligible is None or eligible > now:
            return False
        # The cancel window and the payout delay end on the same day, so a
        # request made at the last moment may still be waiting for staff. Her
        # share stays pending until the refund is decided.
        sub = common.read(db.collection("subscriptions").document(ref.id), transaction)
        if ((sub or {}).get("cancellation") or {}).get("state") == "requested":
            return False
        transaction.update(ref, {"status": "eligible"})
        transaction.set(private, {"owedEgp": firestore.Increment(row.get("coachAmountEgp", 0))}, merge=True)
        return True

    return common.run(db, body)


def sweep(
    db, *, now: dt.datetime, notify, blobs=None, clients: bool = True, payments: bool = False
) -> dict:
    """The hourly pass. Each query asks only for what is due, and every change
    is re-checked inside its own transaction, so a sweep that overlaps a
    client's action does the right thing. `clients` covers unanswered
    requests, finished programmes and the ends-soon push; `payments` covers
    unpaid acceptances, the coach ledger and payment screenshots."""
    counts = {
        "expiredRequests": 0,
        "expiredPayments": 0,
        "ended": 0,
        "endsSoon": 0,
        "ledgerEligible": 0,
        "staleProofImages": 0,
    }
    subs = db.collection("subscriptions")

    if clients:
        answer_by = now - common.hours(LIMITS["requestAnswerHours"])
        unanswered = subs.where("status", "==", "requested").where("statusAt", "<=", answer_by)
        for snap in list(unanswered.stream()):
            lapsed = _expire(db, snap.id, "requested", now, lambda row: _due(row, answer_by, "statusAt"))
            if lapsed is not None:
                counts["expiredRequests"] += 1
                if lapsed.get("clientUid"):
                    notify(lapsed["clientUid"], "requestExpired")

        on_hold = common.coaches_on_hold(db)  # their coachings neither end nor warn; the hold's release moves the end dates
        ending = subs.where("status", "==", "active").where("endsAt", "<=", now + common.days(LIMITS["endsSoonDays"]))
        for snap in list(ending.stream()):
            row = snap.to_dict()
            if row.get("coachUid") in on_hold:
                continue
            if (row.get("cancellation") or {}).get("state") == "requested":
                continue  # staff decide the refund first
            if _due(row, now, "endsAt"):
                done = _finish(db, snap.id, now)
                if done:
                    counts["ended"] += 1
                    notify_ended(notify, done[1], done[0])
            elif not row.get("endsSoonSent"):
                warned = _warn(db, snap.id, now)
                if warned:
                    counts["endsSoon"] += 1
                    notify(warned[0], "endsSoon")
                    if warned[1]:
                        notify(warned[1], "coachEndsSoon")

    if payments:
        unpaid = subs.where("status", "==", "awaiting_payment").where("payBy", "<=", now)
        for snap in list(unpaid.stream()):
            counts["expiredPayments"] += _expire_unpaid(db, snap.id, now)

        for snap in list(db.collection_group("ledger").where("status", "==", "pending").where("eligibleAt", "<=", now).stream()):
            counts["ledgerEligible"] += _release_entry(db, snap.reference, now)

        stale_before = now - common.days(LIMITS["proofImageAlertDays"])
        pending = db.collection("paymentProofs").where("status", "==", "pending").where("createdAt", "<=", stale_before)
        counts["staleProofImages"] = sum(1 for snap in pending.stream() if (snap.to_dict() or {}).get("imagePath"))
        for snap in list(db.collection("paymentProofs").where("imageDeletePending", "==", True).stream()):
            if blobs is None or not common.drop_proof_image(snap.reference, (snap.to_dict() or {}).get("imagePath"), blobs):
                counts["staleProofImages"] += 1

    return counts


def review_health(db, uid: str, data: dict, *, live: bool, coach_v, now: dt.datetime) -> dict:
    """The coach records that she has read the client's health answers."""
    common.require_clients_live(live)
    common.require_active_coach(db, uid, coach_v)
    sub_id = _id(data.get("subId"))
    ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        sub = common.read(ref, transaction)
        if sub is None or sub.get("coachUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if not sub.get("healthReviewedAt"):
            transaction.update(ref, {"healthReviewedAt": now, "healthReviewedBy": uid})
        return {"ok": True}

    return common.run(db, body)
