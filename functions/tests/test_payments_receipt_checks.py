"""Tests for receipt checks and OCR logic (WO-10l-server)."""

from __future__ import annotations

import datetime as dt
import random
import struct

import pytest

from coaching import common
from payments import errors, receipt_checks as rc, risk
from tests.payments_helpers import ADDRESS, AMOUNT, NOW, refusal

CREATED = NOW                       # 12:00 UTC = 14:00 in Cairo (winter time)
NOW_ = NOW + dt.timedelta(minutes=10)

INSTAPAY_FIRST = (
    "Approved Transaction\nYour transaction was successful\n500.37 EGP\n"
    "From\nlayla@instapay\n*** 4821\nTo Instapay\nRah*** M***\nrahma@instapay\nMore Details"
)
DETAILS = "More Details\nTransaction ID\n301234567890123\nDate 10/11/2026 14:05"
ARABIC = (
    "تمت العملية بنجاح\nالمبلغ ٥٠٠٫٣٧ جنيه\nإلى rahma@instapay\n"
    "رقم العملية ٣٠١٢٣٤٥٦٧٨٩٠١٢٣\nالتاريخ ١٠/١١/٢٠٢٦ ٠٢:٠٥ م"
)
CARD_SMS = "Your credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre"
FAILED = "Transaction unsuccessful\n500.37 EGP\nrahma@instapay"
PENDING = "Your transfer is pending\n500.37 EGP\nrahma@instapay"
WRONG_AMOUNT = (
    "Your transaction was successful\n450.00 EGP\nrahma@instapay\n"
    "Transaction ID 301234567890123\nDate 10/11/2026 14:05"
)
OTHER_RECIPIENT = (
    "Your transaction was successful\n500.37 EGP\nTo someone.else@instapay\n"
    "From layla@instapay\nTransaction ID 301234567890123"
)

CLEAN = {"txnReusedBy": None, "sameImageOf": None, "nearImageOf": None}


def run(*texts, **over):
    args = dict(expected_piasters=AMOUNT, address=ADDRESS, created_at=CREATED, now=NOW_)
    args.update(over)
    return rc.run_checks(list(texts), **args)


def test_digits_are_normalised():
    assert rc.normalise("٥٧٠٫٣٧") == "570.37"


@pytest.mark.parametrize(
    "t",
    ["570.37", "570,37", "٥٧٠٫٣٧", "Total 570.37 EGP"],
)
def test_the_exact_amount_matches_in_every_spelling(t):
    assert rc.amount_check(t, 57037) == "match"
    assert rc.amount_check("1,150.37 EGP", 115037) == "match"


def test_a_different_labelled_amount_is_different_and_an_unlabelled_one_is_missing():
    assert rc.amount_check("Amount 560.37 EGP", 57037) == "different"
    assert rc.amount_check("ref 12.34", 57037) == "missing"
    assert rc.amount_check("", 57037) == "missing"


def test_status_words():
    assert rc.status_of(INSTAPAY_FIRST) == "success"
    assert rc.status_of(ARABIC) == "success"
    assert rc.status_of(FAILED) == "failed"
    assert rc.status_of(PENDING) == "failed"
    assert rc.status_of("فشلت العملية") == "failed"
    assert rc.status_of("unsuccessful") == "failed"
    assert rc.status_of("hello") == "unknown"


def test_card_alert_is_the_wrong_kind_of_message():
    assert rc.is_wrong_message(CARD_SMS) is True
    assert rc.is_wrong_message(INSTAPAY_FIRST) is False
    assert rc.is_wrong_message("Your OTP is 4821") is True
    assert rc.is_wrong_message("footprint") is False


def test_recipient():
    assert rc.recipient_check(INSTAPAY_FIRST, ADDRESS) == "match"
    assert rc.recipient_check(OTHER_RECIPIENT, ADDRESS) == "mismatch"
    # A masked handle fits hers but is not proof: consistent, never a match.
    assert rc.recipient_check("To Rah*** M***\nrah***@instapay", ADDRESS) == "masked"
    # A two-column receipt read labels-first puts "Beneficiary" nearest to the payer's own handle:
    # that is no contradiction, only an unclear page (AMBER), never a RED.
    assert rc.recipient_check("Sender\nBeneficiary\nAmount\nlayla@instapay\nRahma M.\n500.37 EGP", ADDRESS) == "unclear"
    assert rc.recipient_check("From\nTo\nlayla@instapay\nRahma M.", ADDRESS) == "unclear"
    assert rc.recipient_check("nothing here", ADDRESS) == "missing"
    assert rc.recipient_check("to 01012345678", "01012345678") == "match"


def test_sender():
    assert rc.sender_check(INSTAPAY_FIRST, "layla@instapay") == "match"
    assert rc.sender_check(INSTAPAY_FIRST, "other@instapay") == "different"
    assert rc.sender_check(INSTAPAY_FIRST, None) == "unknown"
    assert rc.sender_check("one handle only layla@instapay", "other@instapay") == "unknown"


def test_transaction_number():
    assert rc.txn_number(DETAILS) == "301234567890123"
    assert rc.txn_number(ARABIC) == "301234567890123"
    assert rc.txn_number("Amount 12345678901234") is None


def test_times_are_read_as_cairo_and_returned_in_utc():
    assert rc.times_in("10/11/2026 14:05")[0] == dt.datetime(2026, 11, 10, 12, 5, tzinfo=dt.timezone.utc)
    assert rc.times_in("10/11/2026 02:05 PM")[0] == dt.datetime(2026, 11, 10, 12, 5, tzinfo=dt.timezone.utc)
    assert rc.times_in("١٠/١١/٢٠٢٦ ٠٢:٠٥ م")[0] == dt.datetime(2026, 11, 10, 12, 5, tzinfo=dt.timezone.utc)
    assert rc.times_in("2026-11-10 14:05")[0] == dt.datetime(2026, 11, 10, 12, 5, tzinfo=dt.timezone.utc)
    assert rc.times_in("31/02/2026 10:00") == []


def test_time_window():
    assert rc.time_check(DETAILS, CREATED, NOW_) == "in"
    assert rc.time_check("Date 09/11/2026 14:05", CREATED, NOW_) == "outside"
    assert rc.time_check("no date", CREATED, NOW_) == "missing"
    # A time 4 minutes before CREATED is still in (5 min slack)
    early = CREATED - dt.timedelta(minutes=4)
    cairo_early = early.astimezone(common.CAIRO)
    text_early = f"Date {cairo_early.strftime('%d/%m/%Y %H:%M')}"
    assert rc.time_check(text_early, CREATED, NOW_) == "in"


def test_two_screenshots_reach_green_through_risk_decide():
    checks = run(INSTAPAY_FIRST, DETAILS)
    assert checks["amount"] == "match"
    assert checks["status"] == "success"
    assert checks["recipient"] == "match"
    assert checks["when"] == "in"
    assert checks["txn"] == "301234567890123"
    assert checks["transferLike"] is True
    outcome = risk.decide(checks, CLEAN, [], retry_used=False)
    assert outcome.colour == risk.GREEN


def test_the_first_screen_alone_is_amber_need_details():
    outcome = risk.decide(run(INSTAPAY_FIRST), CLEAN, [], retry_used=False)
    assert outcome.colour == risk.AMBER
    assert "needDetails" in outcome.reasons


def test_arabic_receipt_is_green():
    outcome = risk.decide(run(ARABIC), CLEAN, [], retry_used=False)
    assert outcome.colour == risk.GREEN


def test_dark_mode_and_long_names_do_not_change_the_result():
    extra = "\n" + "ا" * 500
    res1 = risk.decide(run(INSTAPAY_FIRST, DETAILS), CLEAN, [], retry_used=False).colour
    res2 = risk.decide(run(INSTAPAY_FIRST.upper() + extra, DETAILS + extra), CLEAN, [], retry_used=False).colour
    assert res1 == res2


def test_card_alert_is_wrong_message_and_never_green_or_red():
    checks = run(CARD_SMS)
    assert checks["wrongMessage"] is True
    assert checks["transferLike"] is False
    out1 = risk.decide(checks, CLEAN, [], retry_used=False)
    assert out1.colour == risk.AMBER
    assert "wrongMessage" in out1.reasons

    checks2 = run(CARD_SMS, expected_piasters=57000)
    out2 = risk.decide(checks2, CLEAN, [], retry_used=False)
    assert out2.colour == risk.AMBER
    assert "wrongMessage" in out2.reasons


def test_an_sms_alone_is_never_green():
    text = "You paid 500.37 EGP on 10/11/2026 14:05 Transaction ID 301234567890123 successful"
    checks = run(text)
    assert checks["transferLike"] is False
    out = risk.decide(checks, CLEAN, [], retry_used=False)
    assert out.colour == risk.AMBER
    assert "notATransferReceipt" in out.reasons


def test_failed_and_pending_are_red():
    out1 = risk.decide(run(FAILED), CLEAN, [], retry_used=False)
    assert out1.colour == risk.RED
    assert "transferFailed" in out1.reasons

    out2 = risk.decide(run(PENDING), CLEAN, [], retry_used=False)
    assert out2.colour == risk.RED
    assert "transferFailed" in out2.reasons


def test_wrong_amount_is_red():
    out = risk.decide(run(WRONG_AMOUNT), CLEAN, [], retry_used=False)
    assert out.colour == risk.RED
    assert "amountDiffers" in out.reasons


def test_other_recipient_is_red():
    out = risk.decide(run(OTHER_RECIPIENT), CLEAN, [], retry_used=False)
    assert out.colour == risk.RED
    assert "recipientDiffers" in out.reasons


def test_a_cropped_screenshot_without_the_amount_is_amber():
    details_no_amount = "More Details\nTransaction ID\n301234567890123\nDate 10/11/2026 14:05"
    first_no_amount = "Your transaction was successful\nrahma@instapay"
    checks = run(first_no_amount, details_no_amount)
    assert checks["amount"] == "missing"
    out = risk.decide(checks, CLEAN, [], retry_used=False)
    assert out.colour == risk.AMBER
    assert "amountUnreadable" in out.reasons


def test_a_screenshot_in_a_language_the_ocr_cannot_read_is_amber():
    out1 = risk.decide(run(""), CLEAN, [], retry_used=False)
    assert out1.colour == risk.AMBER
    out2 = risk.decide(run(None), CLEAN, [], retry_used=False)
    assert out2.colour == risk.AMBER


def test_unknown_layout_is_amber_never_red():
    checks = run("500.37 EGP\nsome layout nobody knows\nrahma@instapay")
    out = risk.decide(checks, CLEAN, [], retry_used=False)
    assert out.colour != risk.RED


def test_a_typed_transaction_number_is_kept_but_never_makes_a_green():
    checks = run(INSTAPAY_FIRST, typed_txn="301234567890123")
    assert checks["txn"] == "301234567890123"
    assert checks["typedTxn"] is True and checks["txnRead"] is False
    out = risk.decide(checks, CLEAN, [], retry_used=False)
    assert out.colour == risk.AMBER and "needDetails" in out.reasons


def test_garbage_never_raises():
    rng = random.Random(0)
    chars = "0123456789:/.,-@*abcXYZ مرحبا\n"
    for _ in range(300):
        length = rng.randint(0, 400)
        s = "".join(rng.choice(chars) for _ in range(length))
        checks = run(s)
        assert isinstance(checks, dict)
        out = risk.decide(checks, CLEAN, [], retry_used=False)
        assert isinstance(out, risk.Outcome)


def test_sanity():
    # Synthetic 1080x2340 PNG
    png_hdr = (
        b"\x89PNG\r\n\x1a\n"
        + struct.pack(">I", 13)
        + b"IHDR"
        + struct.pack(">II", 1080, 2340)
        + b"\x08\x06\x00\x00\x00"
    )
    assert rc.sanity(png_hdr) == []

    # 500x500 PNG -> oddSize, tooSmall
    png_500 = (
        b"\x89PNG\r\n\x1a\n"
        + struct.pack(">I", 13)
        + b"IHDR"
        + struct.pack(">II", 500, 500)
        + b"\x08\x06\x00\x00\x00"
    )
    assert rc.sanity(png_500) == ["oddSize", "tooSmall"]

    assert refusal(lambda: rc.sanity(b"")) == (errors.INVALID, errors.IMAGE_INVALID)
    assert refusal(lambda: rc.sanity(b"not an image")) == (errors.INVALID, errors.IMAGE_INVALID)
    assert refusal(lambda: rc.sanity(b"\x00" * (6 * 1024 * 1024))) == (errors.INVALID, errors.IMAGE_INVALID)


def test_tamper_never_changes_the_colour():
    out = risk.decide(run(INSTAPAY_FIRST, DETAILS), CLEAN, ["editorTag", "oddSize"], retry_used=False)
    assert out.colour == risk.GREEN
