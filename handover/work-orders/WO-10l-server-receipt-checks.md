# WO-10l-server: Server OCR adapter and the deterministic receipt checks (13.3, 13.12, 13.13) as pure Python
Depends on: WO-10m
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 13.3, 13.9, 13.12, 13.13 (all of them); `functions/identity/providers_selfhosted.py` lines 40-130 (`VisionOcr`); `functions/identity/imagesize.py` lines 28-66; `functions/requirements.txt` lines 8-12 (`google-cloud-vision`); `functions/payments/risk.py` (WO-10m, the `checks` contract); `functions/coaching/dhash.py` (all)

## Why
The server is the authority on a screenshot (the phone checks first, for instant feedback). 13.13 says the checks must not depend on any one bank's layout: they look for the same few facts anywhere in the text (success words, the exact unique amount, the coach's address, a transaction number or a time inside the window) and ask for a better picture when a fact is missing, instead of failing her. Only a contradiction (a different amount, a failed or pending status, a different recipient, a time outside the window, a reused number or picture) is RED. The code never throws on garbage and never stores the full OCR text.

## Final result
No screen. Pure functions in `payments/receipt_checks.py` that take the OCR text of one or more images and return the `checks` dictionary WO-10m's `decide` uses; an OCR adapter in `payments/ocr.py`; an image gate `receipt_checks.sanity(raw)`; a fixture-driven test file.

OCR engine decision (verified in the repo today, 26 Oct):
- Chosen: Google Cloud Vision `DOCUMENT_TEXT_DETECTION`, already installed (`google-cloud-vision==3.15.0` in `functions/requirements.txt`) and already wrapped by `identity.providers_selfhosted.VisionOcr`, which uses the EU endpoint (`config.VISION_ENDPOINT = "eu-vision.googleapis.com"`) and `language_hints=["ar","en"]`. This order reuses it as is.
- Rejected: Tesseract. `which tesseract` prints nothing on this machine, it is not in `requirements.txt`, and the Functions python312 image does not ship the binary or the `ara` language data.
- Rejected: Vertex AI (blocked for this project per the spec).
- UNVERIFIED: that the Vision API is enabled and not blocked for project `own-hub`. Verify: `gcloud services list --enabled --project=own-hub | grep -i vision` must print `vision.googleapis.com`. The existing ID check already calls it, so it is expected to work.
- UNVERIFIED: Vision's accuracy on bank receipts. Verified only by the optional live test in step 7.
- Offline: nothing in this order calls the network in tests; tests pass fake text or a fake reader.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/receipt_checks.py` | create | normalise, amount, status, recipient, txn, time, sender, sanity, `run_checks` |
| `functions/payments/ocr.py` | create | `TextReader` over `VisionOcr` |
| `functions/tests/test_payments_receipt_checks.py` | create | fixture tests |
| `functions/tests/fixtures/receipts/README.txt` | create | where real receipts go |

## Steps
1. File `functions/payments/receipt_checks.py`, create (full file):
```python
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
```
2. File `functions/payments/ocr.py`, create:
```python
"""Server OCR: Cloud Vision through the adapter the ID check already uses."""

from __future__ import annotations

from typing import Optional


class TextReader:
    """`read(jpeg)` returns the recognised text, or None when the reader could
    not run. The text is held in memory for one request: never logged, never
    stored (it can carry card digits and balances)."""

    def __init__(self, ocr=None):
        self._ocr = ocr

    def read(self, jpeg: bytes) -> Optional[str]:
        if self._ocr is None:
            from identity import providers_selfhosted

            self._ocr = providers_selfhosted.VisionOcr()
        result = self._ocr.read(jpeg)
        return result.text if getattr(result, "ok", False) else None
```
3. File `functions/tests/fixtures/receipts/README.txt`, create with exactly:
```
Real bank receipts go here, one pair per receipt: NAME.jpg and NAME.expected.json.
Black out names, phone numbers and account digits BEFORE the file is added.
NAME.expected.json: {"amountPiasters": 50037, "address": "rahma@instapay", "outcome": "green"}
Never commit the original the owner sent. The live test (OWNHUB_LIVE_OCR=1) skips when this folder has no .jpg.
```
4. File `functions/tests/test_payments_receipt_checks.py`, create. Write these fixtures and tests (all Western-digit text unless stated; `CREATED` is the request time, `NOW_` ten minutes later):
```python
from __future__ import annotations

import datetime as dt
import os
import random
import struct

import pytest

from coaching import common
from payments import errors, receipt_checks as rc, risk
from tests.payments_helpers import ADDRESS, AMOUNT, NOW, refusal

CREATED = NOW                       # 12:00 UTC = 14:00 in Cairo (winter time)
NOW_ = NOW + dt.timedelta(minutes=10)

INSTAPAY_FIRST = "Approved Transaction\nYour transaction was successful\n500.37 EGP\nFrom\nlayla@instapay\n*** 4821\nTo Instapay\nRah*** M***\nrahma@instapay\nMore Details"
DETAILS = "More Details\nTransaction ID\n301234567890123\nDate 10/11/2026 14:05"
ARABIC = "تمت العملية بنجاح\nالمبلغ ٥٠٠٫٣٧ جنيه\nإلى rahma@instapay\nرقم العملية ٣٠١٢٣٤٥٦٧٨٩٠١٢٣\nالتاريخ ١٠/١١/٢٠٢٦ ٠٢:٠٥ م"
CARD_SMS = "Your credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre"
FAILED = "Transaction unsuccessful\n500.37 EGP\nrahma@instapay"
PENDING = "Your transfer is pending\n500.37 EGP\nrahma@instapay"
WRONG_AMOUNT = "Your transaction was successful\n450.00 EGP\nrahma@instapay\nTransaction ID 301234567890123\nDate 10/11/2026 14:05"
OTHER_RECIPIENT = "Your transaction was successful\n500.37 EGP\nTo someone.else@instapay\nFrom layla@instapay\nTransaction ID 301234567890123"


def run(*texts, **over):
    args = dict(expected_piasters=AMOUNT, address=ADDRESS, created_at=CREATED, now=NOW_)
    args.update(over)
    return rc.run_checks(list(texts), **args)
```
Tests (names and exact assertions):
- `test_digits_are_normalised`: `rc.normalise("٥٧٠٫٣٧") == "570.37"`.
- `test_the_exact_amount_matches_in_every_spelling` parametrized over `"570.37"`, `"570,37"`, `"٥٧٠٫٣٧"`, `"Total 570.37 EGP"` with expected `57037`: `rc.amount_check(t, 57037) == "match"`; and `"1,150.37 EGP"` with `115037` matches.
- `test_a_different_labelled_amount_is_different_and_an_unlabelled_one_is_missing`: `rc.amount_check("Amount 560.37 EGP", 57037) == "different"`; `rc.amount_check("ref 12.34", 57037) == "missing"`; `rc.amount_check("", 57037) == "missing"`.
- `test_status_words`: success for `INSTAPAY_FIRST`, `ARABIC`; failed for `FAILED`, `PENDING`, `"فشلت العملية"`; `"unsuccessful"` is failed; `"hello"` unknown.
- `test_card_alert_is_the_wrong_kind_of_message`: `rc.is_wrong_message(CARD_SMS)` true; `rc.is_wrong_message(INSTAPAY_FIRST)` false; `"Your OTP is 4821"` true; `"footprint"` false.
- `test_recipient`: `INSTAPAY_FIRST` match; `OTHER_RECIPIENT` mismatch; `"To Rah*** M***\nrah***@instapay"` match (masked: local `rahma` startswith `rah`, tail empty); `"nothing here"` missing; phone address `"01012345678"` with text `"to 010 1234 5678"` is match (`rc.recipient_check("to 01012345678", "01012345678") == "match"`).
- `test_sender`: saved `layla@instapay` on `INSTAPAY_FIRST`: match; saved `other@instapay`: different (two handles shown); no saved handle: unknown; a text with one handle only and saved elsewhere: unknown.
- `test_transaction_number`: `DETAILS` gives `301234567890123`; `ARABIC` gives `301234567890123`; `"Amount 12345678901234"` gives `None`; label with the number on the next line works (that is `DETAILS`).
- `test_times_are_read_as_cairo_and_returned_in_utc`: `rc.times_in("10/11/2026 14:05")[0] == dt.datetime(2026,11,10,12,5,tzinfo=dt.timezone.utc)`; `"10/11/2026 02:05 PM"` and `"١٠/١١/٢٠٢٦ ٠٢:٠٥ م"` give the same; `"2026-11-10 14:05"` same; `"31/02/2026 10:00"` gives `[]`.
- `test_time_window`: `rc.time_check(DETAILS, CREATED, NOW_) == "in"`; a page dated `09/11/2026 14:05` is `"outside"`; no date is `"missing"`; a time 4 minutes before `CREATED` is still `"in"` (slack).
- `test_two_screenshots_reach_green_through_risk_decide`: `checks = run(INSTAPAY_FIRST, DETAILS)`; assert `checks["amount"]=="match"`, `status=="success"`, `recipient=="match"`, `when=="in"`, `txn=="301234567890123"`, `transferLike` true; then `risk.decide(checks, {"txnReusedBy":None,"sameImageOf":None,"nearImageOf":None}, [], retry_used=False).colour == risk.GREEN`.
- `test_the_first_screen_alone_is_amber_need_details`: `risk.decide(run(INSTAPAY_FIRST), CLEAN, [], retry_used=False)` is AMBER with `needDetails` in reasons (spec 13.12 item 1).
- `test_arabic_receipt_is_green`: `run(ARABIC)` decides GREEN.
- `test_dark_mode_and_long_names_do_not_change_the_result`: the same text with `"\n" + "ا" * 500` appended and with upper case Latin gives the same colour.
- `test_card_alert_is_wrong_message_and_never_green_or_red`: `run(CARD_SMS)` has `wrongMessage` true and `transferLike` false; the decision is AMBER with reasons `["wrongMessage"]` both with the default expected amount (the 570.00 in the SMS differs, and still is not RED) and with `expected_piasters=57000`.
- `test_an_sms_alone_is_never_green`: text `"You paid 500.37 EGP on 10/11/2026 14:05 Transaction ID 301234567890123 successful"` (no instapay word, no recipient): `transferLike` false, outcome AMBER with `notATransferReceipt`.
- `test_failed_and_pending_are_red`, `test_wrong_amount_is_red`, `test_other_recipient_is_red`: use `FAILED`, `PENDING`, `WRONG_AMOUNT`, `OTHER_RECIPIENT`; assert RED with reasons `transferFailed`, `transferFailed`, `amountDiffers`, `recipientDiffers`.
- `test_a_cropped_screenshot_without_the_amount_is_amber`: `"Your transaction was successful\nrahma@instapay"` plus `DETAILS` without the amount line: `amount=="missing"`, AMBER `amountUnreadable`.
- `test_a_screenshot_in_a_language_the_ocr_cannot_read_is_amber`: text `""` and text `None` both give AMBER (`run("")`, `run(None)`), never an exception.
- `test_unknown_layout_is_amber_never_red`: `run("500.37 EGP\nsome layout nobody knows\nrahma@instapay")`: not RED.
- `test_typed_txn_counts_as_found`: `run(INSTAPAY_FIRST, typed_txn="301234567890123")` has `txn` set and `typedTxn` true; GREEN needs `when` or `txn`, so it is GREEN.
- `test_garbage_never_raises`: for 300 random strings built with `random.Random(0)` from the alphabet `"0123456789:/.,-@*abcXYZ مرحبا\n"` of length 0 to 400, `run(text)` returns a dict and `risk.decide(...)` returns an `Outcome`.
- `test_sanity`: a synthetic 1080x2340 PNG header `b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 1080, 2340) + b"\x08\x06\x00\x00\x00"` returns `[]` from `rc.sanity`; the same header with 500x500 returns `["oddSize", "tooSmall"]`; `rc.sanity(b"")`, `rc.sanity(b"not an image")` and 6 MB of zeros each raise with `(errors.INVALID, errors.IMAGE_INVALID)` (use `refusal`).
- `test_tamper_never_changes_the_colour`: `risk.decide(run(INSTAPAY_FIRST, DETAILS), CLEAN, ["editorTag","oddSize"], retry_used=False).colour == risk.GREEN`.
5. In the same test file add the live test, skipped by default:
```python
FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures", "receipts")


@pytest.mark.skipif(os.environ.get("OWNHUB_LIVE_OCR") != "1" or not any(f.endswith(".jpg") for f in os.listdir(FIXTURES)),
                    reason="live Vision test: set OWNHUB_LIVE_OCR=1 and add real receipts")
def test_real_receipts_reach_the_expected_colour_and_none_is_red():
    import json
    from payments import ocr
    reader, green, total = ocr.TextReader(), 0, 0
    for name in sorted(f for f in os.listdir(FIXTURES) if f.endswith(".jpg")):
        want = json.load(open(os.path.join(FIXTURES, name[:-4] + ".expected.json")))
        text = reader.read(open(os.path.join(FIXTURES, name), "rb").read())
        checks = rc.run_checks([text], expected_piasters=want["amountPiasters"], address=want["address"],
                               created_at=dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc), now=dt.datetime(2100, 1, 1, tzinfo=dt.timezone.utc))
        colour = risk.decide(checks, {"txnReusedBy": None, "sameImageOf": None, "nearImageOf": None}, [], retry_used=False).colour
        assert colour != risk.RED, name
        total += 1
        green += colour == risk.GREEN
    assert green / total >= 0.95
```
(Spec 13.10: at least 95 percent of real fixtures GREEN, and none RED. A single-image receipt may legitimately be AMBER for `needDetails`; owner receipts must therefore be the two-screenshot kind merged into one image or the test lowers to `>= 0.5` and the owner is told. Decision for now: keep 0.95 and label this test UNVERIFIED until the owner supplies receipts.)

## Strings to add
None here. The reasons returned (`amountUnreadable`, `statusUnknown`, `recipientUnreadable`, `needDetails`, `notATransferReceipt`, `someoneElsePaid`, `wrongMessage`, `amountDiffers`, `transferFailed`, `recipientDiffers`, `timeOutsideWindow`, `txnReused`, `sameImage`, `nearImage`) are codes. The app side maps each to words; the wrong-message sentence the spec gives is: EN "This looks like a card message, not an InstaPay transfer receipt. Please send the transfer receipt." AR "دي شكلها رسالة بطاقة مش إيصال تحويل إنستا باي. ابعتي إيصال التحويل."

## Tests to add or change
`functions/tests/test_payments_receipt_checks.py` as listed. Command:
`cd functions && venv/bin/python -m pytest tests/test_payments_receipt_checks.py tests/test_payments_risk.py -q`

## Verify
The command ends with `N passed, 1 skipped` (the live test) and no `failed`. Optional live run after the owner supplies receipts: `cd functions && OWNHUB_LIVE_OCR=1 venv/bin/python -m pytest tests/test_payments_receipt_checks.py -q -k real_receipts`. Latency (spec 13.10, under 10 seconds): UNVERIFIED, measure with `time` on that run.

## Do not
- Do not add a per-bank template table (13.13 removes it).
- Do not store `text` anywhere or log it.
- Do not make a missing field RED. Only the contradictions in `risk.decide` are RED.
- Do not call Vision from a test.

## Done checklist
- [ ] two source files and the fixtures README created
- [ ] all fixture tests pass
- [ ] garbage test passes
- [ ] live test skipped by default

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
