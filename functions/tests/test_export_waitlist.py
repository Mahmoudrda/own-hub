"""W1: the owner's export of the waitlist, for the one launch message."""

from __future__ import annotations

import csv
import datetime as dt
import os
import stat

import pytest

from tests import fake_firestore
from tools import export_waitlist

AT = dt.datetime(2026, 10, 4, 9, tzinfo=dt.timezone.utc)


def seeded():
    db = fake_firestore.FakeFirestore()
    db.docs["waitlist/a"] = {"contact": "+201012345678", "kind": "phone", "lang": "ar", "at": AT}
    db.docs["waitlist/b"] = {"contact": "noor@example.com", "kind": "email", "lang": "en", "at": AT}
    # A duplicate that slipped through a race is exported once.
    db.docs["waitlist/c"] = {"contact": "+201012345678", "kind": "phone", "lang": "ar", "at": AT}
    db.docs["waitlistRate/x_2026-10-04"] = {"count": 3}
    return db


def run(argv, db, lines):
    return export_waitlist.main(argv, db=db, require_adc=lambda: None, out=lines.append)


def test_count_only_prints_the_count_and_no_contact():
    lines = []
    assert run([], seeded(), lines) == 0
    assert lines == ["2 contacts on the waitlist (1 phone, 1 email)"]


def test_export_writes_each_contact_once_to_a_private_file(tmp_path):
    target = tmp_path / "waitlist.csv"
    lines = []
    assert run(["--out", str(target)], seeded(), lines) == 0
    rows = list(csv.DictReader(open(target, encoding="utf-8")))
    assert [(r["kind"], r["contact"], r["lang"]) for r in rows] == [
        ("email", "noor@example.com", "en"),
        ("phone", "+201012345678", "ar"),
    ]
    assert stat.S_IMODE(os.stat(target).st_mode) == 0o600
    assert not any("+2010" in line or "noor@" in line for line in lines)


def test_an_existing_file_is_never_overwritten(tmp_path):
    target = tmp_path / "waitlist.csv"
    target.write_text("keep me")
    with pytest.raises(SystemExit):
        run(["--out", str(target)], seeded(), [])
    assert target.read_text() == "keep me"


def test_needs_adc():
    def no_adc():
        raise SystemExit("refused: no Application Default Credentials")

    with pytest.raises(SystemExit):
        export_waitlist.main([], db=seeded(), require_adc=no_adc, out=lambda line: None)
