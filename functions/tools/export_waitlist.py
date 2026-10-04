"""OWNER'S TOOL ONLY: count the waitlist, and export it for the launch message.

The waitlist promise is "we will message you once when Own Hub opens, then
delete your contact". This prints how many people are waiting and, with --out,
writes each contact once to a new CSV readable only by you (mode 600). Contacts
are never printed to the terminal. Delete the file after the launch message is
sent; Firestore deletes the entries itself 180 days after each one joined.

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


def _contacts(db) -> dict:
    """contact -> (kind, lang), each contact once."""
    out: dict = {}
    for snapshot in db.collection(COLLECTION).stream():
        data = snapshot.to_dict() or {}
        contact = data.get("contact")
        if isinstance(contact, str) and contact and contact not in out:
            out[contact] = (data.get("kind") or "", data.get("lang") or "")
    return out


def main(argv=None, *, db=None, require_adc=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="export_waitlist")
    parser.add_argument("--out", help="a NEW file to write the contacts to (CSV)")
    args = parser.parse_args(argv)

    (require_adc or _require_adc)()
    if db is None:
        from google.cloud import firestore

        db = firestore.Client(project=os.environ.get("GOOGLE_CLOUD_PROJECT", "own-hub"))

    contacts = _contacts(db)
    phones = sum(1 for kind, _ in contacts.values() if kind == "phone")
    emails = sum(1 for kind, _ in contacts.values() if kind == "email")
    out(f"{len(contacts)} contacts on the waitlist ({phones} phone, {emails} email)")

    if args.out:
        path = os.path.expanduser(args.out)
        try:
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            raise SystemExit(f"refused: {path} already exists; choose a new file")
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["kind", "contact", "lang"])
            for contact in sorted(contacts, key=lambda c: (contacts[c][0], c)):
                kind, lang = contacts[contact]
                writer.writerow([kind, contact, lang])
        out(f"written to {path}; delete it once the launch message is sent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
