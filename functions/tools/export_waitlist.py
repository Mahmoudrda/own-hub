"""OWNER'S TOOL ONLY: count the waitlist, and export it for the launch message.

The waitlist promise is "we will message you once: an early invite if you
are among the first 100, or the day Own Hub opens, then we delete your
contact". This prints how many people are waiting and, with --out, writes each
contact once to a new CSV readable only by you (mode 600), in the order they
joined, numbered, with the first 100 marked as founding members: those are
the women to invite early. Contacts are never printed to the terminal. Delete
the file once the messages are sent; Firestore deletes the entries itself 180
days after each one joined.

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub venv/bin/python -m tools.export_waitlist
    GOOGLE_CLOUD_PROJECT=own-hub venv/bin/python -m tools.export_waitlist --out ~/waitlist.csv

Do not save the export inside this repository.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys

COLLECTION = "waitlist"


def _require_adc() -> None:
    if os.environ.get("FIRESTORE_EMULATOR_HOST"):
        return
    import google.auth

    try:
        google.auth.default()
    except Exception:
        raise SystemExit(
            "refused: no Application Default Credentials. This is the owner's "
            "tool; run `gcloud auth application-default login` as the owner."
        )


FOUNDING_PLACES = 100
"""The first this many to join are the founding members the site promises
an early invite to."""


def _contacts(db) -> dict:
    """contact -> (kind, lang, joined), each contact once, at its first join."""
    out: dict = {}
    for snapshot in db.collection(COLLECTION).stream():
        data = snapshot.to_dict() or {}
        contact = data.get("contact")
        if not (isinstance(contact, str) and contact):
            continue
        joined = data.get("at")
        known = out.get(contact)
        if known is None or (
            joined is not None and (known[2] is None or joined < known[2])
        ):
            out[contact] = (data.get("kind") or "", data.get("lang") or "", joined)
    return out


def _in_join_order(contacts: dict) -> list:
    """Earliest first. An entry with no date goes last, never ahead of one
    that has it."""
    return sorted(
        contacts,
        key=lambda c: (contacts[c][2] is None, contacts[c][2] or 0, c),
    )


def main(argv=None, *, db=None, require_adc=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="export_waitlist")
    parser.add_argument("--out", help="a NEW file to write the contacts to (CSV)")
    args = parser.parse_args(argv)

    (require_adc or _require_adc)()
    if db is None:
        from google.cloud import firestore

        db = firestore.Client(project=os.environ.get("GOOGLE_CLOUD_PROJECT", "own-hub"))

    contacts = _contacts(db)
    phones = sum(1 for kind, _, _ in contacts.values() if kind == "phone")
    emails = sum(1 for kind, _, _ in contacts.values() if kind == "email")
    out(f"{len(contacts)} contacts on the waitlist ({phones} phone, {emails} email)")

    if args.out:
        path = os.path.expanduser(args.out)
        try:
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            raise SystemExit(f"refused: {path} already exists; choose a new file")
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["place", "kind", "contact", "lang", "founding"])
            for place, contact in enumerate(_in_join_order(contacts), start=1):
                kind, lang, _ = contacts[contact]
                founding = "yes" if place <= FOUNDING_PLACES else ""
                writer.writerow([place, kind, contact, lang, founding])
        out(f"written to {path}; delete it once the messages are sent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
