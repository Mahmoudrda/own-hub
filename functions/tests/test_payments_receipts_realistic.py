"""The receipt checker against realistic receipt texts (spec 13.10, 13.12, 13.13).

tests/fixtures/receipts/texts holds what the server's OCR returns for one
receipt each: honest ones in several layouts and languages, and the fakes a
payer can type from what the pay screen already shows her. Colours come from the
whole path the server uses: run_checks, then risk.decide.
"""

from __future__ import annotations

import datetime as dt
import glob
import hashlib
import json
import os

import cv2
import numpy as np
import pytest

from coaching import dhash
from payments import proof, receipt_checks as rc, risk
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import (  # noqa: F401
    ADDRESS, CLIENT, CLIENT2, COACH, NOW, SUB, Notes, _txn, db, events, make_payment, notes, payment_of, seed_world,
)

TEXTS = os.path.join(os.path.dirname(__file__), "fixtures", "receipts", "texts")
CLEAN = {"txnReusedBy": None, "sameImageOf": None, "nearImageOf": None}
NAMES = sorted(os.path.basename(f)[:-4] for f in glob.glob(os.path.join(TEXTS, "*.txt")))


def load(name):
    want = json.load(open(os.path.join(TEXTS, name + ".expected.json"), encoding="utf-8"))
    texts = open(os.path.join(TEXTS, name + ".txt"), encoding="utf-8").read().rstrip("\n").split("\n=====\n")
    return texts, want


def colour_of(name, **over):
    texts, want = load(name)
    checks = rc.run_checks(
        texts, expected_piasters=want["amountPiasters"], address=want["address"],
        created_at=dt.datetime.fromisoformat(want["created"]), now=dt.datetime.fromisoformat(want["now"]),
        reference=want.get("reference"), screenshot=over.pop("screenshot", True), **over,
    )
    return risk.decide(checks, CLEAN, [], retry_used=False), want


def test_there_are_at_least_five_realistic_receipts_of_each_kind():
    assert sum(n.startswith("honest_") for n in NAMES) >= 5
    assert sum(n.startswith("fake_") for n in NAMES) >= 4


@pytest.mark.parametrize("name", NAMES)
def test_each_receipt_reaches_the_expected_colour_for_the_expected_reasons(name):
    out, want = colour_of(name)
    assert out.colour == want["colour"], (name, out.reasons)
    for reason in want.get("reasons", []):
        assert reason in out.reasons, (name, out.reasons)


def test_no_honest_receipt_is_red_and_nearly_all_are_green():
    honest = [n for n in NAMES if load(n)[1].get("honest")]
    colours = [colour_of(n)[0].colour for n in honest]
    assert risk.RED not in colours
    assert colours.count(risk.GREEN) / len(colours) >= 0.5   # the ambers among them are the cases the fixtures name on purpose
    assert all(c == risk.GREEN for n, c in zip(honest, colours) if not n.startswith("amber_"))


def test_no_fake_is_ever_green():
    for name in (n for n in NAMES if load(n)[1].get("honest") is False):
        assert colour_of(name)[0].colour != risk.GREEN, name


def test_the_audit_probes_a_typed_note_a_typed_number_and_a_lookalike_handle_are_not_green():
    note = "Your transaction was successful\n500.37 EGP\nTo rahma@instapay\n10/11/2026 14:05"
    assert risk.decide(rc.run_checks([note], expected_piasters=50037, address=ADDRESS, created_at=NOW,
                                     now=NOW + dt.timedelta(minutes=10), screenshot=True), CLEAN, [], retry_used=False).colour == risk.AMBER
    no_time = "Your transaction was successful\n500.37 EGP\nTo rahma@instapay"
    typed = rc.run_checks([no_time], expected_piasters=50037, address=ADDRESS, created_at=NOW,
                          now=NOW + dt.timedelta(minutes=10), typed_txn="301234567890", screenshot=True)
    assert risk.decide(typed, CLEAN, [], retry_used=False).colour == risk.AMBER
    for handle in ("mrahma@instapay", "rahma@instapayx", "xrahma@instapay"):
        assert rc.recipient_check(f"To\n{handle}", ADDRESS) in ("unclear", "mismatch"), handle
    for handle in ("rahma@instapay.evil", "mrahma@instapay", "RAHMA@INSTAPAYX", "rahma@@instapay"):
        assert rc.recipient_check(f"To {handle}", ADDRESS) != "match", handle
    assert rc.recipient_check("To RAHMA@INSTAPAY", ADDRESS) == "match"           # case and full-width marks are normalised
    assert rc.recipient_check("To rahma＠instapay", ADDRESS) == "match"


def test_a_screenshot_that_cannot_be_one_keeps_an_otherwise_perfect_receipt_amber():
    out, _ = colour_of("honest_instapay_two_screens", screenshot=False)
    assert out.colour == risk.AMBER and out.reasons == ["notAScreenshot"]


def test_screen_like_asks_for_phone_shaped_pictures_without_camera_or_editor_marks():
    def png(w, h):
        import struct
        return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", w, h) + b"\x08\x06\x00\x00\x00"

    assert rc.screen_like(png(1170, 2532)) is True
    assert rc.screen_like(png(720, 900)) is True                 # a crop she made to hide a line
    assert rc.screen_like(png(300, 600)) is False                # too small to be a screen
    assert rc.screen_like(png(1000, 4000)) is False              # a strip
    assert rc.screen_like(b"not an image") is False
    assert rc.screen_like(b"\xff\xd8\xff\xe1\x00\x10Exif\x00\x00Make Canon" + b"\x00" * 60) is False


@pytest.mark.parametrize("text,piasters,want", [
    ("500.37 EGP", 50037, "match"),
    ("I paid 500.37 EGP to my coach today and she said thanks", 50037, "missing"),   # inside a sentence proves nothing
    ("Paid 500.37 to rahma@instapay", 50037, "missing"),
    ("Amount\nEGP 500.37", 50037, "match"),
    ("Fees 0.00 EGP\nAmount 500.37 EGP", 50037, "match"),
    ("Fees 5.00 EGP", 50037, "missing"),                                              # a fee is not the amount
    ("Available balance 9,999.00 EGP", 50037, "missing"),
    ("Amount 500.4 EGP", 50037, "missing"),                                           # one decimal: unreadable, not different
    ("Amount 500.00 EGP", 50037, "different"),
])
def test_the_amount_must_stand_alone_on_a_line(text, piasters, want):
    assert rc.amount_check(text, piasters) == want


@pytest.mark.parametrize("line,want", [
    ("Your transaction was successful", "success"),
    ("Transfer successful", "success"),
    ("Profile completed", "unknown"),
    ("Login successful, welcome back to your account", "unknown"),
    ("2 pending requests", "unknown"),
    ("Your transfer is pending", "failed"),
    ("Insufficient balance", "failed"),
    ("I think the transaction was successful", "unknown"),
])
def test_a_status_phrase_counts_only_on_a_status_line(line, want):
    assert rc.status_of(line) == want


def test_dates_in_month_names_and_on_two_lines_are_read_as_cairo_time():
    expect = dt.datetime(2026, 11, 10, 12, 5, tzinfo=dt.timezone.utc)
    assert rc.times_in("10 Nov 2026 02:05 PM") == [expect]
    assert rc.times_in("10/11/2026\n14:05") == [expect]
    assert rc.times_in("10 November 2026, 14:05") == [expect]
    summer = rc.times_in("10/07/2026 14:05")[0]
    assert summer == dt.datetime(2026, 7, 10, 11, 5, tzinfo=dt.timezone.utc)      # Cairo is UTC+3 in summer


def test_a_reference_is_required_only_where_the_receipt_has_a_note_field():
    assert rc.reference_check("Note\nOH-K7M4PQ", "OH-K7M4PQ") == "match"
    assert rc.reference_check("Remarks oh k7m4pq", "OH-K7M4PQ") == "match"
    assert rc.reference_check("Note\nthanks", "OH-K7M4PQ") == "absent"
    assert rc.reference_check("Amount 500.37", "OH-K7M4PQ") == "notShown"
    assert rc.reference_check("Note\nOH-ZZZZ22", "OH-K7M4PQ") == "different"


def _receipt_picture(amount, name, handle, txn, when):
    """The InstaPay result screen drawn the same way each time (white page, green check, black text)."""
    img = np.full((2532, 1170, 3), 255, np.uint8)
    cv2.circle(img, (585, 500), 120, (60, 180, 75), -1)
    for text, y, size in (("Your transaction was successful", 800, 1.6), (f"{amount} EGP", 950, 2.4), (f"To: {name}", 1150, 1.4),
                          (handle, 1250, 1.4), (f"Transaction ID {txn}", 1450, 1.2), (when, 1550, 1.2)):
        cv2.putText(img, text, (120, y), cv2.FONT_HERSHEY_SIMPLEX, size, (20, 20, 20), 3)
    cv2.rectangle(img, (150, 2150), (1020, 2300), (140, 40, 160), -1)
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 85])
    assert ok
    return buf.tobytes()


def test_three_honest_receipts_of_one_bank_template_are_all_green_not_red(db):
    """M4: three different women paying three different amounts with the same bank app. The pictures differ by a few
    bits of a 64-bit hash (a hash cannot read text), so a threshold of 6 sent the second and third to staff."""
    seed_world(db)
    blobs, notes_ = FakeBlobs(), Notes()
    cases = [
        (CLIENT, "pay-1", 50037, "500.37", "Rahma Mohsen", "301234567890123", "10/11/2026 14:05"),
        (CLIENT2, "pay-2", 75012, "750.12", "Rahma Mohsen", "301234567890999", "10/11/2026 14:06"),
        ("client-uid-3", "pay-3", 120088, "1,200.88", "Rahma Mohsen", "301234567891234", "10/11/2026 14:07"),
    ]
    pictures = [_receipt_picture(a, n, ADDRESS, t, w) for _, _, _, a, n, t, w in cases]
    hashes = [dhash.dhash(p) for p in pictures]
    gaps = [dhash.hamming(hashes[i], hashes[j]) for i in range(3) for j in range(i + 1, 3)]
    assert 0 < max(gaps) <= 6, gaps   # the premise: different receipts of one template, closer than the old threshold of 6

    for (uid, pay, piasters, amount, name, txn, when), picture in zip(cases, pictures):
        make_payment(db, pay, clientUid=uid, amountPiasters=piasters, baseAmountPiasters=piasters - 37, reference="OH-4821")
        text = (f"Approved Transaction\nYour transaction was successful\n{amount} EGP\nFrom\nlayla@instapay\nTo Instapay\n"
                f"{name}\n{ADDRESS}\nTransaction ID\n{txn}\nDate {when}")
        out = proof.submit(
            db, uid, {"paymentId": pay, "idempotencyKey": f"key-honest-{pay}", "amountPiasters": piasters}, [picture],
            now=NOW + dt.timedelta(minutes=10), blobs=blobs, reencode=lambda raw, long_side=None: raw,
            reader=type("R", (), {"read": lambda self, jpeg, t=text: t})(), notify=notes_,
        )
        assert out["outcome"] == "green", (pay, out)
        assert payment_of(db, pay)["status"] == "proof_submitted"


PICTURES = os.path.join(os.path.dirname(__file__), "fixtures", "receipts")


@pytest.mark.skipif(
    os.environ.get("OWNHUB_LIVE_OCR") != "1" or not any(f.endswith(".jpg") for f in os.listdir(PICTURES)),
    reason="live Vision test: set OWNHUB_LIVE_OCR=1 and add real receipts (NAME.jpg and NAME.expected.json) to tests/fixtures/receipts",
)
def test_real_receipts_reach_the_expected_colour_and_none_is_red():
    """Cloud Vision on real receipts (owner supplied, details blacked out). Billed calls, so opt-in."""
    from payments import ocr

    reader, green, total = ocr.TextReader(), 0, 0
    for name in sorted(f for f in os.listdir(PICTURES) if f.endswith(".jpg")):
        want = json.load(open(os.path.join(PICTURES, name[:-4] + ".expected.json"), encoding="utf-8"))
        text = reader.read(open(os.path.join(PICTURES, name), "rb").read())
        checks = rc.run_checks(
            [text or ""], expected_piasters=want["amountPiasters"], address=want["address"],
            created_at=dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc), now=dt.datetime(2100, 1, 1, tzinfo=dt.timezone.utc),
            reference=want.get("reference"), screenshot=True,
        )
        colour = risk.decide(checks, CLEAN, [], retry_used=False).colour
        assert colour != risk.RED, name
        total += 1
        green += colour == risk.GREEN
    assert total and green / total >= 0.95
