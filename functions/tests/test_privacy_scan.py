"""The privacy scanner's detection logic.

Why these tests exist: running `scripts/privacy_scan` against the live project
returns CLEAN, and that currently proves nothing, because the project is empty —
zero Firestore collections, zero Storage objects. A clean scan of an empty
surface is a smoke test of the scanner, not evidence about privacy.

What can be proved right now is that the detectors fire on the things spec §9.5
names and stay quiet on the things they must not fire on. A scanner that cries
wolf gets switched off, and a switched-off scanner is worse than none.

The script has no `.py` extension (it is an executable), so it is loaded by
path.
"""

from __future__ import annotations

import importlib.util
import os

import pytest

_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "scripts",
    "privacy_scan",
)

_spec = importlib.util.spec_from_loader(
    "privacy_scan", importlib.machinery.SourceFileLoader("privacy_scan", _PATH)
)
scan = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(scan)


# All synthetic. Rule of engagement 7.
SYNTHETIC_ID = "29507142101345"
ARABIC_ID = "".join(chr(0x0660 + int(d)) for d in SYNTHETIC_ID)
PERSIAN_ID = "".join(chr(0x06F0 + int(d)) for d in SYNTHETIC_ID)


# ------------------------------------------------------------ it must fire


def test_an_ascii_id_number_is_found():
    assert "14-digit-ascii" in scan.scan_text(SYNTHETIC_ID)


def test_an_arabic_indic_id_number_is_found():
    # The form actually printed on the card, and the one a scanner written by
    # someone testing only in English would miss entirely.
    assert "14-digit-arabic-indic" in scan.scan_text(ARABIC_ID)


def test_a_persian_digit_id_number_is_found():
    assert "14-digit-persian" in scan.scan_text(PERSIAN_ID)


def test_an_id_number_embedded_in_a_log_line_is_found():
    line = f'{{"level":"info","msg":"parsed card","value":"{SYNTHETIC_ID}"}}'
    assert "14-digit-ascii" in scan.scan_text(line)


def test_a_base64_jpeg_payload_is_found():
    # What an image looks like after being put into a JSON field by accident.
    assert "base64-image-payload" in scan.scan_text("/9j/4AAQSkZJRgABAQAAAQ")


def test_a_base64_png_payload_is_found():
    assert "base64-image-payload" in scan.scan_text("iVBORw0KGgoAAAANSUhEUg")


def test_a_data_uri_image_is_found():
    assert "base64-image-payload" in scan.scan_text("data:image/jpeg;base64,AAAA")


@pytest.mark.parametrize(
    "magic,label",
    [
        (b"\xff\xd8\xff\xe0", "JPEG"),
        (b"\x89PNG\r\n\x1a\n", "PNG"),
        (b"GIF89a", "GIF"),
    ],
)
def test_raw_image_bytes_in_a_firestore_field_are_found(magic, label):
    hits = list(scan.walk({"blob": magic + b"payload"}, "col/doc"))
    kinds = {kind for _, kind in hits}
    assert f"image-bytes-{label}" in kinds


def test_any_binary_field_at_all_is_reported():
    # Nothing in spec §4's allowlist is binary, so a bytes field is a finding
    # whatever it holds.
    kinds = {kind for _, kind in scan.walk({"x": b"not-an-image"}, "col/doc")}
    assert "unexpected-binary-field" in kinds


def test_findings_are_located_by_nested_field_path():
    hits = list(scan.walk({"a": {"b": [{"c": SYNTHETIC_ID}]}}, "col/doc"))
    paths = [path for path, _ in hits]
    assert "col/doc.a.b[0].c" in paths


# -------------------------------------------------------- it must stay quiet


def test_a_sha256_hex_digest_is_not_mistaken_for_an_id():
    # nidRegistry document ids are 64 hex characters. If these tripped the
    # scanner, every clean run would report thousands of false findings and
    # people would stop running it.
    import hashlib

    digest = hashlib.sha256(b"anything").hexdigest()
    assert scan.scan_text(digest) == []


def test_a_longer_digit_run_is_not_a_fourteen_digit_id():
    # The lookarounds earn their keep here: a 22-digit number contains nine
    # 14-digit windows and none of them is an ID.
    assert scan.scan_text("1234567890123456789012") == []


def test_a_thirteen_digit_run_is_not_an_id():
    assert scan.scan_text(SYNTHETIC_ID[:13]) == []


def test_a_timestamp_is_not_an_id():
    assert scan.scan_text("2026-09-25T14:03:11.482Z") == []


def test_ordinary_arabic_text_is_not_a_finding():
    assert scan.scan_text("النوع أنثى الديانة مسلم") == []


def test_a_uuid_is_not_a_finding():
    assert scan.scan_text("f47ac10b-58cc-4372-a567-0e02b2c3d479") == []


def test_an_empty_string_is_not_a_finding():
    assert scan.scan_text("") == []


# ---------------------------------------------------- the reporting contract


def test_a_clean_run_exits_zero():
    assert scan.Findings().report() == 0


def test_a_dirty_run_exits_one():
    findings = scan.Findings()
    findings.add("col/doc", "14-digit-ascii")
    assert findings.report() == 1


def test_the_report_never_prints_the_offending_value(capsys):
    # A privacy scanner that prints the ID number it found has just written that
    # number to a terminal scrollback and a CI log. The whole point is to say
    # WHERE and WHAT KIND, never WHAT.
    findings = scan.Findings()
    findings.add(f"verificationJobs/{SYNTHETIC_ID}", "document-id-14-digit-ascii")
    findings.report()
    printed = capsys.readouterr().out
    assert "document-id-14-digit-ascii" in printed
    # The location genuinely contains the number in this contrived case, but the
    # scanner must never add the CONTENT of a field on top of the location.
    assert "The content is deliberately NOT printed" in printed


def test_an_unreachable_surface_is_reported_not_silently_skipped():
    # Silence would read as "clean", which is the one thing it is not.
    findings = scan.Findings()
    findings.add("Firestore", "SCAN-FAILED-SURFACE-NOT-CHECKED", "PermissionDenied")
    assert findings.report() == 1
