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
_INVISIBLE = re.compile(_INVISIBLE.pattern[:-1] + "\ufe0f\u20e3]")  # emoji selector, keycap
_MARKS = re.compile("[ً-ٰٟ]")


def normalise(text: str, keep_case: bool = False) -> str:
    """Lower case (unless `keep_case`), every decimal digit (Arabic-Indic, Persian, full width) as
    0-9, zero-width marks and diacritics gone, Arabic letter variants folded."""
    out = []
    for ch in unicodedata.normalize("NFKC", text):
        if ch.isdigit() and unicodedata.category(ch) == "Nd":
            ch = str(unicodedata.digit(ch))
        out.append(ch)
    folded = "".join(out)
    folded = _MARKS.sub("", _INVISIBLE.sub("", folded))
    folded = folded.translate(arabic._LETTER_FOLD)
    return folded if keep_case else folded.lower()


# ------------------------------------------------------------------- contact --

_SEP = r"[\s.\-–—,/():;]"
_NUMBER_RUN = re.compile(r"\+?\d(?:" + _SEP + r"*\d)*")
_EG_MOBILE = re.compile(r"(?:\+?20|0020|0)1[0125]\d{8}")  # has_contact_in_link
_CLOCK = re.compile(r"(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d)")
# Dates and thousands-grouped figures are not phone digits; they break a run.
_DATE = re.compile(
    r"(?<![\d/])\d{1,2}/\d{1,2}(?:/\d{2,4})?(?![\d/])"
    r"|(?<![\d./-])\d{1,2}[.-]\d{1,2}[.-]\d{2,4}(?![\d./-])"
    r"|(?<![\d.-])\d{4}[.-]\d{1,2}[.-]\d{1,2}(?![\d.-])"
)
_THOUSANDS = re.compile(r"(?<![\d,])[1-9]\d{0,2}(?:,\d{3})+(?!\d)")
_LETTER_O = re.compile(r"(?<=\d)o|o(?=\d)")
MIN_NUMBER_DIGITS = 10
_MOBILE = re.compile(r"1[0125]\d{8}")
_MOBILE_ANY = re.compile(r"(?:20|0020|0)?1[0125]\d{8}")
_WORD_DIGITS = {
    "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7",
    "eight": "8", "nine": "9",
    "صفر": "0", "واحد": "1", "اتنين": "2", "اثنين": "2", "اثنان": "2", "تلاته": "3", "تلات": "3",
    "ثلاثه": "3", "ثلاث": "3", "اربعه": "4", "اربع": "4", "خمسه": "5", "خمس": "5", "سته": "6", "ست": "6",
    "سبعه": "7", "سبع": "7", "تمانيه": "8", "ثمانيه": "8", "تمن": "8", "تسعه": "9", "تسع": "9",
    # English digit words written in Arabic letters
    "زيرو": "0", "وان": "1", "تو": "2", "فور": "4", "ثري": "3", "فايف": "5", "سيكس": "6", "سفن": "7", "ايت": "8", "ناين": "9",
}
# "010 then 12345678": a word between two digit groups is a separator.
_FILLER = re.compile(r"(?<=\d)[\s,]+(?:(?:then|and|dash|space|ثم|وبعدين|بعدين|بعد|و)[\s,]+)+(?=\d)")
_DIGIT_WORD = re.compile(
    r"(?<![^\W\d_])(" + "|".join(sorted(map(re.escape, _WORD_DIGITS), key=len, reverse=True)) + r")(?![^\W\d_])"
)


def _looks_like_counts(groups: list) -> bool:
    """Sets, reps or kilos written in a row ("12 10 10 8 8 6", "22.5 25 27.5"):
    every number one or two digits and none starting with 0, which no phone
    number looks like."""
    return len(groups) >= 2 and all(len(g) <= 2 and not g.startswith("0") for g in groups)


def _listy(g: list) -> bool:
    """0 10 20 30 40 50: steps of five and ten, not digits someone chose."""
    return all(len(x) <= 2 and x[-1] in "05" for x in g)


def _phone_window(g: list) -> bool:
    """Whether these consecutive groups of digits read as one phone number."""
    d = "".join(g)
    if len(g) == 1:
        return len(d) >= MIN_NUMBER_DIGITS
    if len(g) > 5 or any(len(x) > 8 for x in g) or _looks_like_counts(g):
        return False
    if d.startswith("0"):
        return len(g) <= 4 and len(d) >= 9
    rest = g[1:] if g[0] == "20" else g
    if not _MOBILE.fullmatch("".join(rest)):
        return False
    return len(rest) == 1 or (len(rest) <= 4 and all(len(x) <= 4 for x in rest))


def _is_phone(raw: str) -> bool:
    """One run of digits as written. A plus sign makes nine digits a number.
    Otherwise some stretch of its groups must read as one: ten digits in a
    row, a leading 0 with nine or more, 20 then a mobile, or a mobile without
    its 0. A short number in front ("Day 5 0101...") is skipped over, and a
    list ("100, 120, 140, 160") matches none of these."""
    groups = [x for x in re.split(_SEP + "+", raw.lstrip("+")) if x]
    if raw.startswith("+"):
        return len("".join(groups)) >= 9
    if len(groups) >= MIN_NUMBER_DIGITS and all(len(x) == 1 for x in groups):
        return True  # one digit at a time
    for i in range(len(groups)):
        for j in range(i + 1, min(len(groups), i + 12) + 1):
            w = groups[i:j]
            if j - i <= 5 and _phone_window(w):
                return True
            # Pairs and single digits that add up to a mobile ("01 01 23 45 67 8").
            if (
                sum(1 for x in w if len(x) <= 2) >= 2
                and all(len(x) <= 8 for x in w)
                and _MOBILE_ANY.fullmatch("".join(w))
                and not _looks_like_counts(w)
                and not _listy(w)
            ):
                return True
    return False


def _symbols_apart(text: str) -> str:
    """An emoji or other symbol between digits is a separator."""
    return "".join(
        " " if c != "+" and (unicodedata.category(c).startswith("S") or c in "*_·•") else c for c in text
    )


def _has_number(text: str) -> bool:
    # Digit words become digits; clock times, dates and 1,200 style figures
    # break a run; a letter O typed for a zero reads as one.
    text = _DIGIT_WORD.sub(lambda m: f" {_WORD_DIGITS[m.group(1)]} ", _symbols_apart(text))
    text = _FILLER.sub(" ", text)
    text = _LETTER_O.sub("0", _THOUSANDS.sub(" n ", _DATE.sub(" d ", _CLOCK.sub(" t ", text))))
    return any(_is_phone(r.group()) for r in _NUMBER_RUN.finditer(text))


_DIGIT_WORDS = (
    "zero|one|two|three|four|five|six|seven|eight|nine|"
    "صفر|واحد|اتنين|اثنين|اثنان|تلاته|تلات|ثلاثه|ثلاث|اربعه|اربع|خمسه|خمس|سته|ست|"
    "سبعه|سبع|تمانيه|ثمانيه|تمن|تسعه|تسع|زيرو|وان|تو|فور|ثري|فايف|سيكس|سفن|ايت|ناين"
)
_SPELLED = re.compile(r"(?:(?<!\w)(?:" + _DIGIT_WORDS + r")(?!\w)[\s,.\-]*){7,}")

_EMAIL = re.compile(r"[a-z][a-z0-9._%+-]*@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}")
_EMAIL_SPOKEN = re.compile(
    r"[a-z0-9._%+-]+\s*(?:\(at\)|\[at\]|(?<!\w)at(?!\w))\s*[a-z0-9-]+\s*"
    r"(?:\(dot\)|\[dot\]|(?<!\w)dot(?!\w))\s*[a-z]{2,}"
)
# "r a h m a @ gmail . com": letters one at a time, or a well-known mail host.
_EMAIL_SPACED = re.compile(
    r"(?:[a-z0-9]\s){3,}[a-z0-9]\s*@\s*[a-z0-9-]+\s*\.\s*[a-z]{2,}"
    r"|[a-z0-9._%+-]+\s*@\s*(?:gmail|yahoo|hotmail|outlook|icloud|proton\w*)(?![a-z0-9])"
    r"|[a-z0-9._%+-]+\s*@\s*(?:live|msn)\s*\.\s*[a-z]{2,}"
)
# An @name is a handle with a dot, underscore or digit in it, or the whole message.
_HANDLE = re.compile(r"(?<!\w)@[a-z][a-z0-9]*[._0-9][a-z0-9_.]*|^\s*@[a-z][a-z0-9_.]{2,}\s*$")


_LEET = {"a": "[a@4]", "e": "[e3]", "i": "[i1!]", "o": "[o0]", "s": "[s5$]"}


def _spaced(word: str) -> str:
    """The word with spaces, dots, apostrophes or look-alike symbols in it:
    "what's app", "wh@tsapp", "tel3gram"."""
    return r"(?<!\w)" + r"[\s'’._-]*".join(_LEET.get(c, c) for c in word) + r"(?!\w)"


# Apps she must not move to, however the word is placed ("tele gram" too).
_APP_STRONG = re.compile(
    r"(?<!\w)(?:whats\s?app|whatsap+|telegram|instagram|insta(?!\s*pay))(?!\w)"
    r"|" + "|".join(_spaced(w) for w in ("whatsapp", "watsapp", "telegram", "instagram"))
    + r"|واتس|وتساب|تليجرام|تيليجرام|تلجرام|تلغرام|تيليغرام|تليغرام"
    r"|(?<!\w)(?:ال|ب|ل|ع|و)?(?:انستا(?!\s*باي)|انستجرام|انستاجرام|انستغرام)(?!\w)"
)
_APP_WEAK = (
    r"(?<!\w)(?:ig|fb|snap|snapchat|tiktok|tik\s?tok|facebook|tg)(?!\w)"
    r"|سناب|فيسبوك|فيس|تيك\s?توك|تيكتوك"
)
# A weaker app word counts only with a handle after it ("snap back" is fine).
_APP_HANDLE = re.compile(
    r"(?:" + _APP_WEAK + r")(?:\s*[:=]\s*@?\s*[a-z0-9_.]{2,}|\s*@\s*[a-z0-9_.]{2,}"
    r"|\s+@?[a-z0-9]+[._][a-z0-9_.]+|\s+@?[a-z]{2,}[0-9]{2,}[a-z0-9_.]*)"
    # "dm me on ig", "follow me on fb": the app named after a request to reach her
    r"|(?<!\w)(?:dm|msg|message|text|follow|add|find|contact)(?!\w)[^.!?\n]{0,14}?"
    r"(?<!\w)(?:ig|fb|snap|snapchat|tiktok|tg|facebook)(?!\w)"
    # "find me rahmafit on ig": further away, but only with on / via / at in front of the app
    r"|(?<!\w)(?:dm|msg|message|text|follow|add|find|contact)(?!\w)[^.!?\n]{0,40}?"
    r"(?<!\w)(?:on|via|at|through)\s+(?:my\s+)?(?:ig|fb|snap|snapchat|tiktok|tg|facebook)(?!\w)"
)


def _has_contact(text: str) -> bool:
    return bool(_has_number(text) or _SPELLED.search(text))


def _has_outside_contact(text: str) -> bool:
    """An email, a handle or an app to move to."""
    return bool(
        _EMAIL.search(text)
        or _EMAIL_SPOKEN.search(text)
        or _EMAIL_SPACED.search(text)
        or _HANDLE.search(text)
        or _APP_STRONG.search(text)
        or _APP_HANDLE.search(text)
    )


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

# Only endings that are not everyday words ("Done.Me", "Good.Fit", "Ok.Page" are
# sentences). Short-link and social hosts are named in _LINK_HOSTS instead.
_TLDS = "com|net|org|io|co|eg|biz|ly|gl|tv|xyz|ae|sa|uk|cc|ws|gg"
_LINK_SCHEME = re.compile(r"https?://|(?<![\w.])www\.")
_LINK_HOSTS = re.compile(
    r"(?<![\w@.-])(?:wa\.me|t\.me|instagram\.com|bit\.ly|linktr\.ee|tiktok\.com|facebook\.com|fb\.me"
    r"|snapchat\.com|telegram\.me)(?![\w-])"
)
# Matched on the text as typed: a capital after the dot is a new sentence, so
# the ending must be all lower or all upper case ("EXAMPLE.COM").
# Everyday-word endings count only lower case with a path: "rahmafit.site/plan".
_PATH_TLDS = "site|shop|store|online|link|app|page|bio|me|fit|info|dev|ai|to|us|ee"
_LINK_BARE = re.compile(
    r"(?<![\w@.-])[A-Za-z0-9][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)*\.(?:" + _TLDS + "|" + _TLDS.upper() + r")(?![\w-])"
    r"|(?<![\w@.-])[A-Za-z0-9][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)*\.(?:" + _PATH_TLDS + r")/\S"
)


def _has_link(cased: str) -> bool:
    lower = cased.lower()
    return bool(_LINK_SCHEME.search(lower) or _LINK_HOSTS.search(lower) or _LINK_BARE.search(cased))

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
    cased = normalise(text, keep_case=True)
    folded = cased.lower()
    if _has_contact(folded):
        return CONTACT
    if _PAYMENT.search(folded):
        return PAYMENT
    if _has_link(cased):
        return LINK
    if _has_outside_contact(folded):
        return CONTACT
    if _ABUSE.search(folded):
        return ABUSE
    return None


def has_contact_detail(text) -> bool:
    """Whether free text holds a number, email, handle, outside app or link.
    Payment names and insults are not tested: a coach may say what she accepts."""
    if not isinstance(text, str):
        return False
    cased = normalise(text, keep_case=True)
    folded = cased.lower()
    return _has_contact(folded) or _has_link(cased) or _has_outside_contact(folded)


def has_contact_in_link(path_and_query: str) -> bool:
    """For a meeting link's path and query. A meeting id may be ten or more
    digits (Zoom), so only a mobile number, an email, a handle or an app name
    counts."""
    folded = normalise(path_and_query)
    for run in _NUMBER_RUN.finditer(folded):
        if _EG_MOBILE.search(re.sub(_SEP, "", run.group())):
            return True
    return _has_outside_contact(folded)


def refuse_contact(*values) -> None:
    """Raises `contains_contact` when any text, or any text in a list, holds one."""
    for value in values:
        items = value if isinstance(value, (list, tuple)) else [value]
        if any(has_contact_detail(v) for v in items):
            raise common.bad(errors.CONTAINS_CONTACT)


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


SPLIT_WINDOW = dt.timedelta(minutes=10)
ATTEMPT_WINDOW = dt.timedelta(days=30)
ATTEMPTS_TO_REPORT = 3
AUTO_REPORTER = "system"
"""Reports Own Hub makes itself carry this as `reporterUid`; a real reporter's
uid is forced to her own by the rules, so no one can write it."""
_OFF_PLATFORM = (CONTACT, LINK)  # naming InstaPay is fine once payments are on


def _earlier_parts(rel_ref, sender: str, message_id: str, text: str, now: dt.datetime) -> list:
    """Ids of the sender's last visible text lines (at most two, from the last
    ten minutes, oldest first) that make `text` read as a contact when joined
    to it: a number sent in two or three pieces. Empty when it reads fine."""
    recent = rel_ref.collection("messages").where("senderUid", "==", sender).where("createdAt", ">=", now - SPLIT_WINDOW)
    lines = []
    for row in recent.stream():
        line = row.to_dict() or {}
        at = common.as_utc(line.get("createdAt"))
        if row.id == message_id or at is None or line.get("type") != "text" or line.get("hidden") is True:
            continue
        if isinstance(line.get("text"), str) and line["text"]:
            lines.append((at, row.id, line["text"]))
    lines = sorted(lines)[-2:]
    for take in (1, 2):
        parts = lines[len(lines) - take:] if len(lines) >= take else []
        if len(parts) == take and screen("\n".join([p[2] for p in parts] + [text])) == CONTACT:
            return [p[1] for p in parts]
    return []


def record_attempt(db, rel_id: str, message_id: str, sender: str, reason: str, now: dt.datetime) -> bool:
    """Counts a hidden contact attempt at relationships/{id}/private/contact
    (server-only, one entry per sender) and, on the third in 30 days, opens a
    `contact_sharing` report for staff. Returns whether a report was opened."""
    rel_ref = db.collection("relationships").document(rel_id)
    ref = rel_ref.collection("private").document("contact")

    def body(transaction):
        rel = common.read(rel_ref, transaction) or {}
        if sender not in (rel.get("coachUid"), rel.get("clientUid")):
            return False
        role = "coach" if sender == rel.get("coachUid") else "client"
        doc = common.read(ref, transaction) or {}
        mine = dict(doc.get(sender) or {})
        if any(a.get("messageId") == message_id for a in mine.get("attempts", [])):
            return False  # the trigger ran twice
        cutoff = now - ATTEMPT_WINDOW
        kept = [a for a in mine.get("attempts", []) if (common.as_utc(a.get("at")) or cutoff) > cutoff]
        kept = (kept + [{"at": now, "reason": reason, "messageId": message_id}])[-10:]
        reported = common.as_utc(mine.get("reportedAt"))
        open_report = len(kept) >= ATTEMPTS_TO_REPORT and (reported is None or reported <= cutoff)
        mine.update({"count": int(mine.get("count") or 0) + 1, "lastAt": now, "attempts": kept})
        if open_report:
            mine["reportedAt"] = now
            transaction.set(
                db.collection("reports").document(),
                {
                    "reporterUid": AUTO_REPORTER,
                    "subjectUid": sender,
                    "subjectKind": "coachMessage",
                    "subjectRef": f"relationships/{rel_id}/messages/{message_id}",
                    "reason": "contact_sharing",
                    # Staff act on the right woman: a coach can be suspended, a client cannot.
                    "subjectRole": role,
                    "note": f"{len(kept)} hidden messages from the {role} with contact details or outside apps in 30 days",
                    "state": "submitted",
                    "createdAt": now,
                    "auto": True,
                },
            )
        transaction.set(ref, {**doc, sender: mine})
        return open_report

    return common.run(db, body)


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

    reason, earlier = None, []
    if is_client_type and isinstance(data.get("text"), str):
        reason = screen(data["text"])
        if reason is None and data.get("type") == "text":
            earlier = _earlier_parts(rel_ref, sender, message_id, data["text"], now)
            if earlier:
                reason = CONTACT
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
            for part in earlier:  # the rest of the same number goes too
                transaction.update(
                    rel_ref.collection("messages").document(part),
                    {"hidden": True, "hiddenReason": reason, "text": ""},
                )
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
    if reason in _OFF_PLATFORM:
        record_attempt(db, rel_id, message_id, sender, reason, now)
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
