"""The coaching chat's screen and the trigger that applies it.

A coach and a client talk inside Own Hub so a payment, a phone number or a link
to somewhere else cannot move the relationship off the platform (the coach
rules forbid off-platform payment, and a woman's number is hers to keep). The
phone refuses these before sending; this is the same check on the server, run
on every message that reaches Firestore, for a client that did not.

`screen` and the app's ChatScreen give one verdict for every case in
contracts/coaching_chat_screen_vectors.json.
"""

from __future__ import annotations

import datetime as dt
import re
import unicodedata
from typing import Optional

from google.cloud import firestore

from identity import arabic

from . import common, errors

LIMITS = common.LIMITS
ENUMS = common.ENUMS

CONTACT, PAYMENT, LINK, ABUSE = "contact", "payment", "link", "abuse"

CHAT_MEDIA_HOLD = "after"
"""Owner decision 4 (open). "after": media shows at once and can be reported.
"before": media is hidden with reason "held"; NO release path exists yet, so
do not switch it until the dashboard queue is built."""

MEDIA_TYPES = ("image", "video", "audio")
_MEDIA_MIME = {
    "image": ("image/jpeg",),
    "video": ("video/mp4", "video/quicktime"),
    "audio": ("audio/mp4", "audio/aac", "audio/x-m4a"),
}
_MEDIA_MAX = {
    "image": LIMITS["chatImageMaxBytes"],
    "video": LIMITS["chatVideoMaxBytes"],
    "audio": LIMITS["chatAudioMaxBytes"],
}
_MEDIA_SECONDS = {"video": LIMITS["chatVideoMaxSeconds"], "audio": LIMITS["chatAudioMaxSeconds"]}


def media_problem(rel_id: str, sender: str, data: dict, blobs) -> Optional[str]:
    """None when the media line is fine, else the hiddenReason."""
    kind = data.get("type")
    path = data.get("mediaPath")
    if not isinstance(path, str) or not path.startswith(f"chat-media/{rel_id}/{sender}/") or ".." in path:
        return "media"
    found = blobs.info(path)
    if found is None:
        return "media"
    size, content_type = found
    if size <= 0 or size > _MEDIA_MAX[kind] or content_type not in _MEDIA_MIME[kind]:
        return "media"
    if kind in _MEDIA_SECONDS:
        ms = data.get("durationMs")
        if isinstance(ms, bool) or not isinstance(ms, int) or not 500 <= ms <= _MEDIA_SECONDS[kind] * 1000 + 1500:
            return "media"
    return None


def too_fast(db, rel_ref, sender: str, kind: str, now: dt.datetime) -> bool:
    """More than chatMessagesPerMinute lines in 60 s, or chatMediaPerHour media
    lines in an hour, from this sender (the new line counts)."""
    lines = rel_ref.collection("messages")
    minute = lines.where("senderUid", "==", sender).where("createdAt", ">=", now - dt.timedelta(seconds=60))
    if sum(1 for _ in minute.stream()) > LIMITS["chatMessagesPerMinute"]:
        return True
    if kind in MEDIA_TYPES:
        hour = lines.where("senderUid", "==", sender).where("createdAt", ">=", now - dt.timedelta(hours=1))
        if sum(1 for m in hour.stream() if (m.to_dict() or {}).get("type") in MEDIA_TYPES) > LIMITS["chatMediaPerHour"]:
            return True
    return False

_INVISIBLE = re.compile("[​-‏‪-‮⁦-⁩ـ﻿]")
_MARKS = re.compile("[ً-ٰٟ]")


def normalise(text: str) -> str:
    """Lower case, every decimal digit (Arabic-Indic, Persian, full width) as
    0-9, zero-width marks and diacritics gone, Arabic letter variants folded."""
    out = []
    for ch in unicodedata.normalize("NFKC", text):
        if ch.isdigit() and unicodedata.category(ch) == "Nd":
            ch = str(unicodedata.digit(ch))
        out.append(ch)
    folded = "".join(out)
    folded = _MARKS.sub("", _INVISIBLE.sub("", folded))
    return folded.translate(arabic._LETTER_FOLD).lower()


# ------------------------------------------------------------------- contact --

_NUMBER_RUN = re.compile(r"\+?\d(?:[\s.\-]*\d)*")
_EG_MOBILE = re.compile(r"(?:\+?20|0020|0)1[0125]\d{8}")
MIN_NUMBER_DIGITS = 10


def _looks_like_counts(run: str) -> bool:
    """Sets, reps or kilos written in a row ("12 10 10 8 8 6", "22.5 25 27.5"):
    every number one or two digits and none starting with 0, which no phone
    number looks like."""
    if run.startswith("+"):
        return False
    groups = [g for g in re.split(r"[\s.\-]+", run) if g]
    return len(groups) >= 2 and all(len(g) <= 2 and not g.startswith("0") for g in groups)


def _has_contact(text: str) -> bool:
    for run in _NUMBER_RUN.finditer(text):
        if _looks_like_counts(run.group()):
            continue
        digits = re.sub(r"[\s.\-]", "", run.group())
        if _EG_MOBILE.search(digits) or len(digits.lstrip("+")) >= MIN_NUMBER_DIGITS:
            return True
    return False


# ------------------------------------------------------------------- payment --

_PAYMENT_NAMES = (
    "instapay",
    "insta pay",
    "vodafone cash",
    "vodafonecash",
    "etisalat cash",
    "orange cash",
    "we pay",
    "wepay",
    "fawry",
    "فودافون كاش",
    "فودافون كش",
    "انستاباي",
    "انستا باي",
    "اتصالات كاش",
    "اورنج كاش",
    "فوري",
)
_PAYMENT = re.compile(
    r"(?<!\w)(?:" + "|".join(re.escape(n).replace(r"\ ", r"\s+") for n in _PAYMENT_NAMES) + r")(?!\w)"
)

# ---------------------------------------------------------------------- link --

_TLDS = (
    "com|net|org|io|me|co|app|eg|info|biz|ly|gl|tv|xyz|link|shop|store|online|site|"
    "ai|dev|ae|sa|uk|us|ws|cc|to|gg|page|bio"
)
_LINK = re.compile(
    r"https?://|(?<![\w.])www\.|(?<![\w@.-])[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:"
    + _TLDS
    + r")(?![\w-])"
)

# --------------------------------------------------------------------- abuse --

_ABUSE_WORDS = (
    "stupid", "idiot", "moron", "bitch", "slut", "whore", "fuck", "fucking", "shit",
    "غبيه", "غبي", "حمار", "حماره", "شرموطه", "قحبه", "عرص", "متخلفه", "متخلف", "زباله",
)
_ABUSE = re.compile(r"(?<!\w)(?:" + "|".join(_ABUSE_WORDS) + r")(?!\w)")


def screen(text: str) -> Optional[str]:
    """"contact", "payment", "link" or "abuse", or None when the text is fine."""
    if not isinstance(text, str):
        return None
    folded = normalise(text)
    if _has_contact(folded):
        return CONTACT
    if _PAYMENT.search(folded):
        return PAYMENT
    if _LINK.search(folded):
        return LINK
    if _ABUSE.search(folded):
        return ABUSE
    return None


# ------------------------------------------------------------------- trigger --

PREVIEW_CHARS = 80


def preview(data: dict, hidden: bool) -> dict:
    """What the chat list shows for the newest message: the first words of a
    text, or the kind of message for anything else. A hidden message shows no
    words at all."""
    kind = "hidden" if hidden else str(data.get("type") or "text")
    text = data.get("text")
    words = text[:PREVIEW_CHARS] if kind == "text" and isinstance(text, str) else ""
    return {"text": words, "type": kind, "senderUid": data.get("senderUid")}


def parties_client(db, rel_id: str):
    return (db.collection("relationships").document(rel_id).get().to_dict() or {}).get("clientUid")


def _coach_first_name(db, coach_uid: str) -> str:
    name = (db.collection("coaches").document(coach_uid).get().to_dict() or {}).get("displayName") or ""
    return name.split()[0][:20] if name.split() else ""


def on_message(
    db,
    rel_id: str,
    message_id: str,
    data: dict,
    *,
    now: dt.datetime,
    notify: common.Notify,
    blobs=None,
    reencode=None,
) -> dict:
    """Runs when a message is created. Client messages are screened and hidden
    when they fail; the other party is pushed at most once per throttle window,
    and never for a hidden message. Returns what happened, for the logs."""
    sender = data.get("senderUid")
    rel_ref = db.collection("relationships").document(rel_id)
    message_ref = rel_ref.collection("messages").document(message_id)
    is_client_type = data.get("type") in ENUMS["messageTypeClient"]
    # Plan and session cards are written by the server and push on their own.
    is_card = data.get("type") in ENUMS["messageTypeServer"] and data.get("type") != "system"

    reason = None
    if is_client_type and isinstance(data.get("text"), str):
        reason = screen(data["text"])
    kind = data.get("type")
    if reason is None and is_client_type and too_fast(db, rel_ref, sender, kind, now):
        reason = "rate"
    if reason is None and kind in MEDIA_TYPES:
        if blobs is None:
            reason = "media"
        elif CHAT_MEDIA_HOLD == "before":
            reason = "held"
        else:
            reason = media_problem(rel_id, sender, data, blobs)
        if reason is None and kind == "image" and reencode is not None:
            try:
                blobs.write(data["mediaPath"], reencode(blobs.read(data["mediaPath"]), long_side=LIMITS["chatImageLongSidePx"]), "image/jpeg")
            except Exception:
                reason = "media"
    # Whatever hid a media line, its file goes too (a rate-hidden flood included),
    # unless it is only held for a release that does not exist yet.
    path = data.get("mediaPath")
    if reason not in (None, "held") and kind in MEDIA_TYPES and blobs is not None \
            and isinstance(path, str) \
            and path.startswith(f"chat-media/{rel_id}/{sender}/"):
        blobs.delete(path)
    hidden = reason is not None or data.get("hidden") is True
    window = dt.timedelta(minutes=LIMITS["pushThrottleMinutes"])

    def body(transaction):
        snapshot = rel_ref.get(transaction=transaction)
        if not snapshot.exists:
            return None
        rel = snapshot.to_dict() or {}
        parties = (rel.get("coachUid"), rel.get("clientUid"))
        if sender not in parties:
            return None
        changes = {"lastMessageAt": now, "lastMessage": {**preview(data, hidden), "at": now}}
        recipient = None
        if (is_client_type or is_card) and not hidden:
            other = parties[1] if sender == parties[0] else parties[0]
            changes[f"unreadFor.{other}"] = firestore.Increment(1)
            last = common.as_utc((rel.get("lastPushAt") or {}).get(other))
            if is_client_type and (last is None or now - last >= window):
                recipient = other
                changes[f"lastPushAt.{other}"] = now
        transaction.update(rel_ref, changes)
        if reason is not None:
            hide = {"hidden": True, "hiddenReason": reason, "text": ""}
            if reason != "held":
                hide["mediaPath"] = None
            transaction.update(message_ref, hide)
            transaction.set(
                rel_ref.collection("messages").document(f"hidden_{message_id}"),
                {
                    "senderUid": sender,
                    "type": "system",
                    "systemKind": "hidden",
                    "createdAt": now,
                },
            )
        return recipient

    recipient = common.run(db, body)
    if recipient is not None:
        from . import push

        label = "newMessage"
        if push.NEW_MESSAGE_TEXT_MODE == "first_name" and recipient == parties_client(db, rel_id):
            first = _coach_first_name(db, sender)
            label = f"newMessageFrom:{first}" if first else "newMessage"
        notify(recipient, label)
    return {
        "hidden": reason is not None,
        "reason": reason,
        "pushed": recipient is not None,
    }


RULES_VERSION = 1
"""Version of the chat and conduct rules she ticks before her first coaching
message. Recorded at users/{uid}/consents/chat-rules-v1."""


def accept_rules(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    """Her tick on the chat rules: the version, the hash of the words she saw,
    her language and the app version. The first tick stays; ticking again
    changes nothing."""
    common.require_clients_live(live)
    if data.get("version") != RULES_VERSION or isinstance(data.get("version"), bool):
        raise common.bad()
    text_hash = data.get("textHash")
    if not isinstance(text_hash, str) or len(text_hash) != 64 or not set(text_hash) <= set("0123456789abcdef"):
        raise common.bad()
    locale = common.one_of(data.get("locale"), ENUMS["languages"])
    if text_hash not in {common.sha(t) for t in common.CONTRACT["consentTexts"]["chatRules1"][locale]}:
        raise common.bad()
    record = {
        "version": RULES_VERSION,
        "at": now,
        "locale": locale,
        "textHash": text_hash,
    }
    app = data.get("appVersion")
    if app is not None:
        if not isinstance(app, str) or len(app) > 32:
            raise common.bad()
        record["appVersion"] = app
    ref = common.consent_ref(db, uid, f"chat-rules-v{RULES_VERSION}")

    def body(transaction):
        if not ref.get(transaction=transaction).exists:
            transaction.set(ref, record)

    common.run(db, body)
    return {"ok": True}


def mark_read(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    """She opened the thread: her unread count is zero and `reads/{uid}` holds
    the time, in one write. Only the two parties can; anyone else is told the
    thread does not exist."""
    common.require_clients_live(live)
    rel_id = common.text(data.get("relId"), max_len=128)
    rel_ref = db.collection("relationships").document(rel_id)

    def body(transaction):
        rel = common.read(rel_ref, transaction)
        if rel is None or uid not in (rel.get("coachUid"), rel.get("clientUid")):
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        transaction.update(rel_ref, {f"unreadFor.{uid}": 0})
        transaction.set(rel_ref.collection("reads").document(uid), {"at": now})

    common.run(db, body)
    return {"ok": True}
