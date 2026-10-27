"""Deterministic checks on the text of a payment screenshot (spec 13.3, 13.12, 13.13).

Nothing here knows a bank. Facts are searched in the text and each one has to
have the SHAPE it has on a real transfer receipt, not just appear: the amount
as a figure on its own line, the recipient as a whole handle (never a part of
a longer one), the status as a status line, labelled fields, a date in the
window. Anything not clearly consistent is left for the caller to call AMBER.

Honest limit (13.3): text that merely looks like a receipt can be typed or
drawn. These checks remove the lazy fakes; the coach's own bank, the bounded
access and the strikes are what remove the rest.

Every function accepts any string and returns a value; none raises.
"""

from __future__ import annotations

import datetime as dt
import re
import unicodedata
from typing import Optional

from coaching import common
from identity import imagesize

from . import errors, model, risk

_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
_DIACRITICS = re.compile("[ً-ْـ]")
_INVISIBLE = re.compile("[​-‏‪-‮⁠﻿]")
_WORD = re.compile(r"[^\W\d_]+")


def normalise(text) -> str:
    """Arabic-Indic and Persian digits to Western, Arabic decimal and thousands
    marks to . and , , full-width forms to plain ones, invisible direction
    marks removed, runs of spaces folded."""
    t = unicodedata.normalize("NFKC", text if isinstance(text, str) else "").translate(_DIGITS)
    t = _INVISIBLE.sub("", t)
    for old, new in (("٫", "."), ("٬", ",")):
        t = t.replace(old, new)
    return re.sub(r"[ \t]+", " ", t)


def fold(text: str) -> str:
    """Lower case and Arabic letter variants folded, so a phrase matches however it is spelled."""
    t = _DIACRITICS.sub("", text.lower())
    for old, new in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ى", "ي"), ("ة", "ه")):
        t = t.replace(old, new)
    return t


def _prep(text) -> str:
    return fold(normalise(text))


def _lines(text) -> list[str]:
    return [line.strip() for line in _prep(text).splitlines() if line.strip()]


def _words(line: str) -> list[str]:
    return _WORD.findall(line)


def _distance(a: str, b: str) -> int:
    """Edit distance, small strings only."""
    row = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        prev, row[0] = row[0], i
        for j, cb in enumerate(b, 1):
            prev, row[j] = row[j], min(row[j] + 1, row[j - 1] + 1, prev + (ca != cb))
    return row[-1]


# ---------------------------------------------------------------- amount

_AMOUNT = re.compile(r"(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d+)[.,](\d{2})(?!\d)")
_AMOUNT_LABEL = re.compile(r"egp|amount|total|المبلغ|مبلغ|جنيه|ج\.م")
_NOT_THE_AMOUNT = re.compile(r"fee|charge|commission|balance|limit|available|رسوم|عموله|رصيد|الحد|المتاح")
_CURRENCY = frozenset(("egp", "le", "l", "e", "pound", "pounds", "جنيه", "جم", "ج", "م"))


def amounts_in(text) -> list[tuple[int, str, bool]]:
    """[(piasters, its line, standalone)] for every number with two decimals.
    `standalone` is true when the figure sits on a line of its own, with at
    most a label and a currency beside it and no handle: the shape of the
    amount on a receipt, not of a number inside a sentence."""
    out = []
    for line in _prep(text).splitlines():
        for m in _AMOUNT.finditer(line):
            rest = _words(line[: m.start()] + " " + line[m.end():])
            alone = "@" not in line and len([w for w in rest if w not in _CURRENCY]) <= 3
            out.append((int(m.group(1).replace(",", "")) * 100 + int(m.group(2)), line, alone))
    return out


def amount_check(text, expected_piasters: int) -> str:
    """'match' when the exact amount stands alone on a line; 'different' when
    the amount-labelled figure on its own line (not a fee, a balance or a
    limit) is another one and the exact one is nowhere; else 'missing'. The
    exact amount inside a sentence is 'missing': it proves nothing."""
    found = amounts_in(text)
    if any(value == expected_piasters and alone for value, _, alone in found):
        return "match"
    if any(value == expected_piasters for value, _, _ in found):
        return "missing"
    if any(alone and value > 0 and _AMOUNT_LABEL.search(line) and not _NOT_THE_AMOUNT.search(line)
           for value, line, alone in found):
        return "different"
    return "missing"


# ---------------------------------------------------------------- status

SUCCESS_PHRASES = tuple(fold(p) for p in (
    "your transaction was successful", "transaction was successful", "transaction successful",
    "approved transaction", "successful", "successfully", "completed",
    "تمت العملية بنجاح", "تمت بنجاح", "تم التحويل بنجاح", "عملية ناجحة", "تم بنجاح", "تمت العملية",
))
FAILED_PHRASES = tuple(fold(p) for p in (
    "unsuccessful", "failed", "declined", "rejected", "pending", "in progress", "processing",
    "insufficient", "فشل", "فشلت", "مرفوض", "معلقة", "قيد التنفيذ", "غير ناجحة", "لم تتم", "رصيد غير كاف",
))
# Words that may stand beside a status phrase on a status line.
_FILLER = frozenset(fold(w) for w in (
    "your the this a an transaction transfer payment operation process request status result was is has been "
    "now balance funds العملية عملية التحويل تحويل الدفع دفع الحالة حالة الطلب تم تمت"
).split())


def _status_line(line: str, phrases: tuple) -> bool:
    """A line that says the status: a phrase and nothing else but filler words.
    '2 pending requests' and 'Profile completed' are not status lines."""
    return any(p in line and all(w in _FILLER for w in _words(line.replace(p, " "))) for p in phrases)


def status_of(text) -> str:
    """'failed' wins over 'success' ('unsuccessful' contains 'successful'). A
    phrase counts only on a status line. Else 'success' or 'unknown'."""
    lines = _lines(text)
    if any(_status_line(line, FAILED_PHRASES) for line in lines):
        return "failed"
    if any(_status_line(line, SUCCESS_PHRASES) for line in lines):
        return "success"
    return "unknown"


# ------------------------------------------------- the wrong kind of message

_WRONG = re.compile(
    r"has been used for|available limit|available balance|your balance|one[- ]time password|\botp\b|"
    r"verification code|credit card ending|card ending|purchase|"
    r"رمز التحقق|كلمه المرور لمره|الرصيد المتاح|تم استخدام بطاقه|عمليه شراء"
)
_INSTAPAY_MARK = re.compile(r"instapay|insta pay|انستا")
_TRANSFER_MARK = re.compile(r"instapay|insta pay|انستا|transfer|تحويل")


def is_wrong_message(text) -> bool:
    """A card-purchase alert, a balance message or an OTP: not a transfer receipt (13.13 item 3).
    Only InstaPay itself or a handle clears it: the word 'transfer' in a card alert does not."""
    n = _prep(text)
    return bool(_WRONG.search(n)) and not (_INSTAPAY_MARK.search(n) or _AT.search(n))


# ------------------------------------------------------------ recipient

_AT = re.compile(r"(?<![a-z0-9._*@-])([a-z0-9._*-]{1,60})@([a-z]{2,20})(?![a-z0-9@_-]|\.[a-z0-9])")
_TO_LABELS = frozenset(tuple(fold(w) for w in p.split()) for p in (
    "to", "beneficiary", "recipient", "receiver", "payee", "pay to", "paid to", "sent to", "transferred to",
    "إلى", "المستفيد", "المستلم", "المستلمة",
))
_FROM_LABELS = frozenset(tuple(fold(w) for w in p.split()) for p in (
    "from", "sender", "payer", "paid from", "sent from", "transferred from", "من", "المرسل", "المرسلة", "الدافع",
))


def _label_of(line: str) -> Optional[str]:
    """'to' or 'from' when the line opens with such a label, else None."""
    words = tuple(_words(line)[:2])
    for size in (2, 1):
        if words[:size] in _TO_LABELS:
            return "to"
        if words[:size] in _FROM_LABELS:
            return "from"
    return None


def _handles(text) -> list[dict]:
    """Every handle on the page, whole: {local, domain, masked, role, inline}. The
    role is the nearest 'to' or 'from' label at the start of its line or of
    one of the three lines above it (not past another handle); `inline` says
    the label stands on the handle's own line. A two-column receipt that the
    reader emits labels-first puts a label near the wrong value, so only an
    inline label is trusted to call a handle foreign."""
    lines = _lines(text)
    labels = [_label_of(line) for line in lines]
    out = []
    for i, line in enumerate(lines):
        for m in _AT.finditer(line):
            role, inline = None, False
            for j in range(i, max(-1, i - 4), -1):
                if j < i and _AT.search(lines[j]):
                    break
                if labels[j]:
                    role, inline = labels[j], j == i
                    break
            local = m.group(1).strip(".-_")
            out.append({"local": local, "domain": m.group(2), "masked": "*" in local, "role": role, "inline": inline})
    return out


def _masked_fits(handle: dict, local: str, suffix: str) -> bool:
    parts = re.split(r"\*+", handle["local"])
    head, tail = parts[0], parts[-1]
    return (handle["domain"] == suffix and local.startswith(head) and local.endswith(tail)
            and 2 <= len(head) + len(tail) < len(local))


def recipient_check(text, address: str) -> str:
    """Whether the receipt names the coach's address.
    'match'    her whole handle is on it (not as part of a longer one), not as the sender;
    'masked'   a masked handle fits hers (r***@instapay): consistent, not proof;
    'mismatch' a handle on a line that opens with a 'to' label is clearly another (three or more characters away);
    'unclear'  other handles are shown, none clearly hers or clearly not;
    'missing'  no handle at all. A phone-number address matches on its whole digit run."""
    addr = (address or "").strip().lower()
    if not addr:
        return "missing"
    if addr.isdigit():
        digits = re.sub(r"(?<=\d)[\s-](?=\d)", "", _prep(text))
        return "match" if re.search(rf"(?<!\d){addr}(?!\d)", digits) else "missing"
    shown = _handles(text)
    if not shown:
        return "missing"
    local, _, suffix = addr.partition("@")
    ours = [h for h in shown if h["role"] != "from"]
    if any(not h["masked"] and h["local"] == local and h["domain"] == suffix for h in ours):
        return "match"
    if any(h["masked"] and _masked_fits(h, local, suffix) for h in ours):
        return "masked"
    if any(h["role"] == "to" and h["inline"] and not h["masked"] and _distance(f"{h['local']}@{h['domain']}", addr) >= 3 for h in shown):
        return "mismatch"
    return "unclear"


def sender_check(text, saved_handle: Optional[str]) -> str:
    """'match' when her saved handle is on the receipt whole; 'different' when a
    'from' handle or two or more handles are shown and hers is none of them;
    else 'unknown'."""
    if not saved_handle:
        return "unknown"
    shown = [h for h in _handles(text) if not h["masked"]]
    whole = {f"{h['local']}@{h['domain']}" for h in shown}
    if saved_handle.strip().lower() in whole:
        return "match"
    return "different" if len(whole) >= 2 or any(h["role"] == "from" for h in shown) else "unknown"


# ------------------------------------------------------- transaction number

_LABELS = tuple(fold(p) for p in (
    "transaction id", "transaction number", "transaction no", "reference number", "reference no",
    "reference", "rrn", "txn id", "رقم العملية", "رقم المرجع", "الرقم المرجعي", "رقم المعاملة", "مرجع",
))
_TXN = re.compile(r"(?<!\d)\d{10,20}(?!\d)")


def txn_number(text) -> Optional[str]:
    """A 10 to 20 digit number next to a label (same line, or the line after)."""
    lines = [line.strip() for line in _prep(text).splitlines()]
    for i, line in enumerate(lines):
        for label in _LABELS:
            pos = line.find(label)
            if pos < 0:
                continue
            m = _TXN.search(line[pos + len(label):]) or (_TXN.search(lines[i + 1]) if i + 1 < len(lines) else None)
            if m:
                return m.group(0)
    return None


def txn_key(txn: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", (txn or "").upper())


# ------------------------------------------------------------------ time

_MERIDIEM = r"\s*(am|pm|ص|م)?(?![a-zA-Z؀-ۿ])"
_DMY = re.compile(r"(?<!\d)(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})[\s,tT]+(\d{1,2}):(\d{2})(?::\d{2})?" + _MERIDIEM, re.I)
_YMD = re.compile(r"(?<!\d)(\d{4})-(\d{2})-(\d{2})[\s,tT]+(\d{1,2}):(\d{2})(?::\d{2})?" + _MERIDIEM, re.I)
_MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
_DMON = re.compile(
    r"(?<!\d)(\d{1,2})[\s-]+(" + "|".join(_MONTHS) + r")[a-z]*\.?,?[\s-]+(\d{4})[\s,tT]+(\d{1,2}):(\d{2})(?::\d{2})?" + _MERIDIEM,
    re.I,
)


def _make(y, mo, d, h, mi, mer) -> Optional[dt.datetime]:
    h, mer = int(h), (mer or "").lower()
    if mer in ("pm", "م") and h < 12:
        h += 12
    if mer in ("am", "ص") and h == 12:
        h = 0
    try:
        return dt.datetime(int(y), int(mo), int(d), h, int(mi), tzinfo=common.CAIRO).astimezone(dt.timezone.utc)
    except ValueError:
        return None


def times_in(text) -> list[dt.datetime]:
    """Every date and time on the page, read as Cairo time, returned in UTC."""
    n = normalise(text)
    out = []
    for d, mo, y, h, mi, mer in _DMY.findall(n):
        t = _make(y, mo, d, h, mi, mer)
        if t:
            out.append(t)
    for y, mo, d, h, mi, mer in _YMD.findall(n):
        t = _make(y, mo, d, h, mi, mer)
        if t:
            out.append(t)
    for d, mon, y, h, mi, mer in _DMON.findall(n):
        t = _make(y, _MONTHS.index(mon.lower()) + 1, d, h, mi, mer)
        if t:
            out.append(t)
    return out


def time_check(text, start: dt.datetime, end: dt.datetime) -> str:
    """'in' when any time on the page lies between the request and now (five
    minutes of slack for the phones' clocks); 'outside' when times are shown and
    none does; else 'missing'. The server's own `now` is the only clock."""
    found = times_in(text)
    if not found:
        return "missing"
    slack = dt.timedelta(minutes=5)
    return "in" if any(start - slack <= t <= end + slack for t in found) else "outside"


# ------------------------------------------------- reference code and labels

_REF_SHAPE = re.compile(r"\bOH[-\s]?[A-HJKMNP-Z2-9]{6}\b")
_NOTE_LABELS = tuple(fold(w) for w in (
    "note", "notes", "remarks", "remark", "description", "purpose", "message", "reason",
    "ملاحظات", "ملاحظة", "البيان", "الوصف", "السبب", "الغرض",
))
_KIND_LABELS = {
    "amount": ("amount", "total", "transfer amount", "المبلغ", "مبلغ", "القيمة"),
    "date": ("date", "time", "التاريخ", "الوقت", "تاريخ"),
    "txn": ("transaction id", "transaction number", "transaction no", "txn id", "rrn", "رقم العملية", "رقم المعاملة"),
    "reference": ("reference", "ref", "رقم المرجع", "الرقم المرجعي", "مرجع"),
    "fee": ("fee", "fees", "charges", "commission", "الرسوم", "رسوم", "العمولة"),
    "note": _NOTE_LABELS,
    "status": ("status", "الحالة"),
}
_KIND_LABELS = {kind: tuple(fold(w) for w in words) for kind, words in _KIND_LABELS.items()}


def _opens_with(line: str, labels: tuple) -> bool:
    return any(line.startswith(w) and not line[len(w):len(w) + 1].isalpha() for w in labels)


def label_kinds(text) -> set:
    """The kinds of labelled field the page shows (from, to, amount, date, txn,
    reference, fee, note, status): the layout of a transfer receipt, found by
    synonym lists, not by any one bank's template (13.13 item 1)."""
    kinds = set()
    for line in _lines(text):
        role = _label_of(line)
        if role:
            kinds.add(role)
        kinds.update(kind for kind, labels in _KIND_LABELS.items() if _opens_with(line, labels))
    if status_of(text) == "success":
        kinds.add("status")
    return kinds


def reference_check(text, reference: Optional[str]) -> str:
    """The unique reference (OH-XXXXXX) in the transfer note (13.2). 'match' when
    it is on the page; 'different' when another one is; 'absent' when the page
    has a note field without it (it is required there); 'notShown' when the
    page has no note field (the bank may not offer one)."""
    if not reference:
        return "notShown"
    n = normalise(text).upper()
    if re.sub(r"[\s\-_]", "", reference.upper()) in re.sub(r"[\s\-_.:]", "", n):
        return "match"
    if _REF_SHAPE.search(n):
        return "different"
    return "absent" if any(_opens_with(line, _NOTE_LABELS) for line in _lines(text)) else "notShown"


# ------------------------------------------------------------ the image gate

def sanity(raw: bytes) -> list[str]:
    """Refuses what cannot be a screenshot (too big, not an image, a pixel
    bomb) with image_invalid; otherwise returns the tamper flags (score only)."""
    if not isinstance(raw, (bytes, bytearray)) or not raw or len(raw) > model.LIMITS["screenshotMaxBytes"]:
        raise common.refuse(errors.INVALID, errors.IMAGE_INVALID)
    if imagesize.dimensions(bytes(raw)) is None or imagesize.refusal(bytes(raw)) is not None:
        raise common.refuse(errors.INVALID, errors.IMAGE_INVALID)
    return risk.tamper_flags(bytes(raw))


def screen_like(raw: bytes) -> bool:
    """Whether the picture can be a screenshot of a phone screen or a crop of
    one: at least 480 pixels on the short side, no more than 3 to 1, no camera
    EXIF and no editor's tag (13.3 step 1). Failing it never rejects a picture;
    it only keeps the proof from being GREEN."""
    size = imagesize.dimensions(bytes(raw)) if isinstance(raw, (bytes, bytearray)) else None
    if size is None:
        return False
    short, long_ = sorted(size)
    if short < 480 or long_ > 3 * short:
        return False
    return not ({"cameraExif", "editorTag"} & set(risk.tamper_flags(bytes(raw))))


# ------------------------------------------------------------- everything

_RECIPIENT_RANK = ("match", "masked", "mismatch", "unclear", "missing")


def run_checks(texts: list, *, expected_piasters: int, address: str, created_at: dt.datetime,
               now: dt.datetime, sender_handle: Optional[str] = None, typed_txn: Optional[str] = None,
               reference: Optional[str] = None, screenshot: Optional[bool] = None) -> dict:
    """The `checks` dictionary risk.decide reads. `texts` is the OCR text of
    each image she sent (one or more). Amount, recipient, status and time are
    judged over all of them together. `screenshot` is whether every picture
    passed `screen_like` (None when the caller has no pictures to judge)."""
    texts = [t for t in (texts or []) if isinstance(t, str)]
    per = []
    for t in texts:
        status = status_of(t)
        recipient = recipient_check(t, address)
        per.append({
            "amount": amount_check(t, expected_piasters), "status": status, "recipient": recipient,
            "when": time_check(t, created_at, now), "txn": txn_number(t), "sender": sender_check(t, sender_handle),
            "wrong": is_wrong_message(t), "reference": reference_check(t, reference), "kinds": label_kinds(t),
            "transfer": status == "success" and (recipient != "missing" or bool(_INSTAPAY_MARK.search(_prep(t)))),
        })

    def pick(key, ranking, default):
        values = [p[key] for p in per]
        return next((v for v in ranking if v in values), default)

    read = next((p["txn"] for p in per if p["txn"]), None)
    txn = read or (typed_txn or None)
    transfer_like = any(p["transfer"] for p in per)
    return {
        "amount": pick("amount", ("match", "different"), "missing"),
        "status": "failed" if any(p["status"] == "failed" for p in per)
        else ("success" if any(p["status"] == "success" for p in per) else "unknown"),
        "recipient": pick("recipient", _RECIPIENT_RANK, "missing"),
        "when": pick("when", ("in", "outside"), "missing"),
        "txn": txn,
        "txnRead": read is not None,
        "txnTypedDiffers": bool(read and typed_txn and txn_key(read) != txn_key(typed_txn)),
        "typedTxn": bool(typed_txn),
        "wrongMessage": any(p["wrong"] for p in per) and not transfer_like,
        "transferLike": transfer_like,
        "sender": pick("sender", ("match", "different"), "unknown"),
        "reference": pick("reference", ("match", "different", "absent"), "notShown"),
        "labels": len(set().union(*(p["kinds"] for p in per))) if per else 0,
        "screenshot": screenshot,
    }
