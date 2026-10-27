"""Deterministic checks on the text of a payment screenshot (spec 13.3, 13.12, 13.13).

Nothing here knows a bank. Facts are searched anywhere in the text. Every
function accepts any string and returns a value; none raises.
"""

from __future__ import annotations

import datetime as dt
import re
from typing import Optional

from coaching import common
from identity import imagesize

from . import errors, model, risk

_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
_DIACRITICS = re.compile("[ً-ْـ]")


def normalise(text) -> str:
    """Arabic-Indic and Persian digits to Western, Arabic decimal and thousands
    marks to . and , , invisible direction marks removed, runs of spaces folded."""
    t = (text if isinstance(text, str) else "").translate(_DIGITS)
    for old, new in (("٫", "."), ("٬", ","), ("‏", ""), ("‎", ""), (" ", " ")):
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


# ---------------------------------------------------------------- amount

_AMOUNT = re.compile(r"(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d+)[.,](\d{2})(?!\d)")
_AMOUNT_LABEL = re.compile(r"egp|amount|total|المبلغ|مبلغ|جنيه|ج\.م")


def amounts_in(text) -> list[tuple[int, str]]:
    """[(piasters, the 60 characters around it)] for every number with two decimals."""
    n = _prep(text)
    out = []
    for m in _AMOUNT.finditer(n):
        pounds = int(m.group(1).replace(",", ""))
        out.append((pounds * 100 + int(m.group(2)), n[max(0, m.start() - 30): m.end() + 30]))
    return out


def amount_check(text, expected_piasters: int) -> str:
    """'match' when the exact amount is there; 'different' when a number that is
    labelled as the amount (EGP, Amount, المبلغ, جنيه) is another one and the
    exact one is absent; else 'missing'."""
    found = amounts_in(text)
    if any(value == expected_piasters for value, _ in found):
        return "match"
    if any(_AMOUNT_LABEL.search(context) for _, context in found):
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


def status_of(text) -> str:
    """'failed' wins over 'success' ('unsuccessful' contains 'successful'). Else 'success' or 'unknown'."""
    n = _prep(text)
    if any(p in n for p in FAILED_PHRASES):
        return "failed"
    if any(p in n for p in SUCCESS_PHRASES):
        return "success"
    return "unknown"


# ------------------------------------------------- the wrong kind of message

_WRONG = re.compile(
    r"has been used for|available limit|available balance|your balance|one[- ]time password|\botp\b|"
    r"verification code|credit card ending|card ending|purchase|"
    r"رمز التحقق|كلمه المرور لمره|الرصيد المتاح|تم استخدام بطاقه|عمليه شراء"
)
_TRANSFER_MARK = re.compile(r"instapay|insta pay|انستا|transfer|تحويل")


def is_wrong_message(text) -> bool:
    """A card-purchase alert, a balance message or an OTP: not a transfer receipt (13.13 item 3)."""
    n = _prep(text)
    return bool(_WRONG.search(n)) and not _TRANSFER_MARK.search(n)


# ------------------------------------------------------------ recipient

_HANDLE = re.compile(r"[a-z0-9._-]{3,40}@[a-z]{3,20}")
_MASKED = re.compile(r"([a-z0-9._-]*)\*+([a-z0-9._-]*)@([a-z]{3,20})")


def recipient_check(text, address: str) -> str:
    """'match' when the coach's address is on the receipt, whole or with the
    middle masked by stars; 'mismatch' when handles are shown and hers is not
    among them; else 'missing'. A phone-number address matches on its digits."""
    n = _prep(text)
    addr = (address or "").strip().lower()
    if not addr:
        return "missing"
    if addr.isdigit():
        return "match" if addr in re.sub(r"[\s-]", "", n) else "missing"
    handles = set(_HANDLE.findall(n))
    if addr in handles or addr in n:
        return "match"
    local, _, suffix = addr.partition("@")
    for head, tail, dom in _MASKED.findall(n):
        if dom == suffix and local.startswith(head) and local.endswith(tail) and len(head) + len(tail) < len(local):
            return "match"
    return "mismatch" if handles else "missing"


def sender_check(text, saved_handle: Optional[str]) -> str:
    """'match' when her saved handle is on the receipt; 'different' when two or
    more handles are shown and hers is none of them; else 'unknown'."""
    if not saved_handle:
        return "unknown"
    n = _prep(text)
    handles = set(_HANDLE.findall(n))
    if saved_handle.strip().lower() in handles:
        return "match"
    return "different" if len(handles) >= 2 else "unknown"


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


# ------------------------------------------------------------------ time

_MERIDIEM = r"\s*(am|pm|ص|م)?(?![a-zA-Z؀-ۿ])"
_DMY = re.compile(r"(?<!\d)(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})[ ,tT]+(\d{1,2}):(\d{2})(?::\d{2})?" + _MERIDIEM, re.I)
_YMD = re.compile(r"(?<!\d)(\d{4})-(\d{2})-(\d{2})[ tT]+(\d{1,2}):(\d{2})(?::\d{2})?" + _MERIDIEM, re.I)


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


# ------------------------------------------------------------ the image gate

def sanity(raw: bytes) -> list[str]:
    """Refuses what cannot be a screenshot (too big, not an image, a pixel
    bomb) with image_invalid; otherwise returns the tamper flags (score only)."""
    if not isinstance(raw, (bytes, bytearray)) or not raw or len(raw) > model.LIMITS["screenshotMaxBytes"]:
        raise common.refuse(errors.INVALID, errors.IMAGE_INVALID)
    if imagesize.dimensions(bytes(raw)) is None or imagesize.refusal(bytes(raw)) is not None:
        raise common.refuse(errors.INVALID, errors.IMAGE_INVALID)
    return risk.tamper_flags(bytes(raw))


# ------------------------------------------------------------- everything

def run_checks(texts: list, *, expected_piasters: int, address: str, created_at: dt.datetime,
               now: dt.datetime, sender_handle: Optional[str] = None, typed_txn: Optional[str] = None) -> dict:
    """The `checks` dictionary WO-10m's risk.decide reads. `texts` is the OCR
    text of each image she sent (one or more). Amount, recipient, status and
    time are judged over all of them together."""
    texts = [t for t in (texts or []) if isinstance(t, str)]
    per = []
    for t in texts:
        status = status_of(t)
        recipient = recipient_check(t, address)
        per.append({
            "amount": amount_check(t, expected_piasters), "status": status, "recipient": recipient,
            "when": time_check(t, created_at, now), "txn": txn_number(t), "sender": sender_check(t, sender_handle),
            "wrong": is_wrong_message(t),
            "transfer": status == "success" and (recipient != "missing" or bool(_TRANSFER_MARK.search(_prep(t)))),
        })

    def pick(key, win, lose, default):
        values = [p[key] for p in per]
        if win in values:
            return win
        if lose in values:
            return lose
        return default

    txn = next((p["txn"] for p in per if p["txn"]), None) or (typed_txn or None)
    transfer_like = any(p["transfer"] for p in per)
    return {
        "amount": pick("amount", "match", "different", "missing"),
        "status": "failed" if any(p["status"] == "failed" for p in per)
        else ("success" if any(p["status"] == "success" for p in per) else "unknown"),
        "recipient": pick("recipient", "match", "mismatch", "missing"),
        "when": pick("when", "in", "outside", "missing"),
        "txn": txn,
        "typedTxn": bool(typed_txn),
        "wrongMessage": any(p["wrong"] for p in per) and not transfer_like,
        "transferLike": transfer_like,
        "sender": pick("sender", "match", "different", "unknown"),
    }
