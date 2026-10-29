"""The one thing deletion keeps: a coach's signed agreement, for the period the
privacy policy states (while she coaches and 5 years after).

Before a coach's account is deleted, `retain` copies

* the signed agreement file(s) from coach-docs/{uid}/agreement/ to the
  server-only prefix legal-hold/{uid}/agreement/ in the personal bucket, and
* her agreement state (coachPrivate/{uid}.agreement) and her coach-terms
  consent records (with the agreement text hash)

to legalHolds/{uid} with `retainUntil`. Both places are closed to every client
(storage.rules and firestore.rules); only the Admin SDK reads them. The normal
deletion then runs unchanged, so nothing else of hers survives. `purge_due`
(a daily job) deletes a hold once `retainUntil` has passed.
"""

from __future__ import annotations

import datetime as dt

COLLECTION = "legalHolds"
RETENTION_DAYS = 5 * 365 + 2
"""5 years, with the leap days."""
SOURCE_PREFIX = "coach-docs/{uid}/agreement/"
HOLD_PREFIX = "legal-hold/{uid}/agreement/"
CONSENTS = ("coach-terms-v1", "coach-terms-v2")
PERSONAL_BUCKET = "own-hub-personal"


def retain(db, uid: str, copy_files, now: dt.datetime) -> bool:
    """Idempotent: an existing hold is never rewritten or extended. `copy_files(
    source_prefix, hold_prefix)` copies the objects and returns their new paths.
    Files are copied first and the record written last, so a retry after a
    failure starts over cleanly. Returns whether a hold exists afterwards."""
    ref = db.collection(COLLECTION).document(uid)
    if ref.get().exists:
        return True
    agreement = (db.collection("coachPrivate").document(uid).get().to_dict() or {}).get("agreement")
    consents = {}
    for name in CONSENTS:
        data = db.collection("users").document(uid).collection("consents").document(name).get().to_dict()
        if data:
            consents[name] = data
    files = copy_files(SOURCE_PREFIX.format(uid=uid), HOLD_PREFIX.format(uid=uid))
    if not (agreement or consents or files):
        return False
    ref.set({
        "agreement": agreement or None,
        "consents": consents,
        "files": list(files),
        "createdAt": now,
        "retainUntil": now + dt.timedelta(days=RETENTION_DAYS),
    })
    return True


def purge_due(db, delete_prefix, now: dt.datetime) -> int:
    """Deletes every hold whose time is up, files first. `delete_prefix(prefix)`
    removes the objects. A failure leaves that hold for the next run."""
    done = 0
    for snap in db.collection(COLLECTION).where("retainUntil", "<=", now).limit(200).stream():
        delete_prefix(HOLD_PREFIX.format(uid=snap.id))
        snap.reference.delete()
        done += 1
    return done
