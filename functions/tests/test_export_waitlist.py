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
    later = AT + dt.timedelta(hours=1)
    db.docs["waitlist/a"] = {"contact": "noor@example.com", "kind": "email", "lang": "en", "at": later}
    db.docs["waitlist/b"] = {"contact": "+201012345678", "kind": "phone", "lang": "ar", "at": AT}
    # A duplicate that slipped through a race is exported once, at its first
    # join.
    db.docs["waitlist/c"] = {
        "contact": "+201012345678", "kind": "phone", "lang": "ar",
        "at": AT + dt.timedelta(hours=2),
    }
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
    # In the order they joined, numbered: the first 100 are founding members.
    assert [(r["place"], r["kind"], r["contact"], r["lang"], r["founding"]) for r in rows] == [
        ("1", "phone", "+201012345678", "ar", "yes"),
        ("2", "email", "noor@example.com", "en", "yes"),
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


def test_only_the_first_hundred_are_founding(tmp_path):
    db = fake_firestore.FakeFirestore()
    for i in range(101):
        db.docs[f"waitlist/{i:03d}"] = {
            "contact": f"w{i:03d}@example.com", "kind": "email", "lang": "en",
            "at": AT + dt.timedelta(minutes=101 - i),
        }
    target = tmp_path / "waitlist.csv"
    assert run(["--out", str(target)], db, []) == 0
    rows = list(csv.DictReader(open(target, encoding="utf-8")))
    assert len(rows) == 101
    # The last to join is first in line; the first to join is 101st and late.
    assert rows[0]["contact"] == "w100@example.com"
    assert [r["founding"] for r in rows].count("yes") == 100
    assert rows[100]["contact"] == "w000@example.com" and rows[100]["founding"] == ""
