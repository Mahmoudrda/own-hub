from __future__ import annotations

import pytest

from payments import risk

GOOD = dict(amount="match", status="success", recipient="match", when="in", txn="1234567890123", txnRead=True,
            txnTypedDiffers=False, wrongMessage=False, transferLike=True, sender="match", typedTxn=False,
            labels=4, reference="match", screenshot=True)
CLEAN = dict(txnReusedBy=None, sameImageOf=None, nearImageOf=None)


def decide(**over):
    checks = {**GOOD, **{k: v for k, v in over.items() if k in GOOD}}
    uniq = {**CLEAN, **{k: v for k, v in over.items() if k in CLEAN}}
    return risk.decide(checks, uniq, over.get("flags", []), retry_used=over.get("retry_used", False), other_payer_ok=over.get("other_payer_ok", False))


def test_everything_found_is_green():
    assert decide().colour == risk.GREEN


@pytest.mark.parametrize("over,reason", [
    ({"amount": "different"}, "amountDiffers"), ({"status": "failed"}, "transferFailed"),
    ({"recipient": "mismatch"}, "recipientDiffers"), ({"when": "outside"}, "timeOutsideWindow"),
    ({"txnReusedBy": "p9"}, "txnReused"), ({"sameImageOf": "p9"}, "sameImage"),
])
def test_a_contradiction_or_a_reuse_is_red_and_offers_no_retry(over, reason):
    out = decide(**over)
    assert out.colour == risk.RED and reason in out.reasons and out.retry_offered is False


@pytest.mark.parametrize("over", [
    {"amount": "missing"}, {"status": "unknown"}, {"recipient": "missing"},
    {"when": "missing", "txn": None, "txnRead": False}, {"transferLike": False},
    {"recipient": "masked"}, {"recipient": "unclear"}, {"txnRead": False}, {"txnTypedDiffers": True},
    {"labels": 2}, {"reference": "absent"}, {"reference": "different"}, {"screenshot": False},
])
def test_a_missing_invariant_is_amber_never_red(over):
    out = decide(**over)
    assert out.colour == risk.AMBER and out.retry_offered is True


def test_the_receipt_without_details_is_amber_with_need_details():
    out = decide(txn=None, txnRead=False, when="missing")
    assert out.colour == risk.AMBER and "needDetails" in out.reasons


def test_green_needs_the_number_read_from_the_picture_and_the_time_together():
    assert decide(txnRead=False).reasons == ["needDetails"]          # a typed number is not on the receipt
    assert decide(when="missing").reasons == ["needDetails"]         # a number without a date in the window
    assert decide(reference="notShown").colour == risk.GREEN         # a bank with no note field owes no reference


def test_a_similar_picture_raises_the_staff_score_and_never_the_colour():
    out = decide(nearImageOf="p9")
    assert out.colour == risk.GREEN and out.score == risk.WEIGHTS["nearImageOther"]


def test_an_exact_copy_is_the_only_picture_reuse_that_is_red():
    assert decide(sameImageOf="p9").colour == risk.RED


def test_the_second_amber_offers_no_retry_and_a_typed_number_offers_none():
    assert decide(amount="missing", retry_used=True).retry_offered is False
    assert decide(amount="missing", typedTxn=True).retry_offered is False


def test_a_card_message_is_amber_and_never_uses_the_retry():
    out = decide(wrongMessage=True, retry_used=True)
    assert out.colour == risk.AMBER and out.reasons == ["wrongMessage"] and out.retry_offered is True


def test_someone_else_paying_is_amber_until_she_confirms_once():
    assert decide(sender="different").reasons == ["someoneElsePaid"]
    assert decide(sender="different", other_payer_ok=True).colour == risk.GREEN


def test_tamper_flags_change_the_score_and_never_the_colour():
    flags = ["editorTag", "cameraExif", "oddSize", "tooSmall", "clockMismatch"]
    out = decide(flags=flags)
    assert out.colour == risk.GREEN and out.score == 90
    assert risk.score(flags + ["doubleCompression"]) == 100


def test_tamper_flags_read_editor_tags_and_camera_exif():
    jpeg_head = b"\xff\xd8\xff\xe1\x00\x10Exif\x00\x00Make Adobe Photoshop"
    flags = risk.tamper_flags(jpeg_head + b"\x00" * 50)
    assert "editorTag" in flags and "cameraExif" in flags


def test_garbage_bytes_never_raise():
    assert isinstance(risk.tamper_flags(b""), list) and isinstance(risk.tamper_flags(b"\x00" * 100), list)
