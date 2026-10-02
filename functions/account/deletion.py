"""delete_account (S4): purge everything the manifest names, in a safe order.

Order is the G7 §3.3 state machine, and every step writes
deletionRequests/{uid}.state before it runs, so a failure part way is visible
and the sweeper (main.resume_account_deletions) finishes it:

    requested          the request is recorded
    authLocked         refresh tokens revoked and the Auth user disabled FIRST,
                       so nothing new can be written while she is purged
    purgingFirestore   users/{other}/blockedBy/{uid} for every account she
                       blocked (row 17, read before row 16 is deleted), then
                       users/{uid} recursively (rows 1-8, 10-16, 18, 19, 32,
                       35-38) and plans/{uid} (rows 20, 21)
    purgingStorage     user-media/{uid}/ and user-exports/{uid}/ in the default
                       bucket and in own-hub-personal (rows 24, 25). DELETE
                       only: nothing here ever writes to Storage
    purgingGroupHooks  verificationJobs, verification_flags and
                       verificationSessions where uid == (rows 22, 39, 41),
                       verificationLedger/{uid} (row 40), the registry entry
                       CLOSED not deleted (row 23), reports pseudonymised
                       (row 30)
    purgingThirdParty  nothing to call: no analytics SDK ships, and crash
                       reports never carry a user id (rows 27, 28)
    authDeleted        the Auth user deleted LAST (row 29)
    done               deletionRequests/{uid} reduced to state and timestamps,
                       the retained proof of erasure (row 31)

N9, after done: a still-valid ID token (up to an hour) or a queued offline
write can partly recreate users/{uid} or plans/{uid}. `done` therefore records
sweepAfter (config.DELETION_RESWEEP_MINUTES, 65, later) and the sweeper runs
one more recursive delete of both once it is due (`resweep`), then replaces
sweepAfter with sweptAt so it never runs again.

Idempotent: every step tolerates having already run, so a re-run after a
failure finishes the job rather than failing on what is already gone.

Not uid-keyed and therefore untouched: verificationReviewAccess (the review
audit log), verificationBehaviour, verificationInstalls (hash-keyed signals)
and verificationStats (counts with no uid).
"""

from __future__ import annotations

import datetime as dt
import secrets
from typing import Protocol

from identity import config

from . import manifest

JOURNAL = [
    "requested",
    "authLocked",
    "purgingFirestore",
    "purgingStorage",
    "purgingGroupHooks",
    "purgingThirdParty",
    "authDeleted",
    "done",
]
FAILED_RETRYABLE = "failedRetryable"
UNFINISHED_STATES = [s for s in JOURNAL if s != "done"] + [FAILED_RETRYABLE]

STORAGE_PREFIXES = ("user-media/{uid}/", "user-exports/{uid}/")
PERSONAL_BUCKET = "own-hub-personal"
DELETION_RECORD_FIELDS = frozenset(
    {"state", "requestedAt", "updatedAt", "doneAt", "sweepAfter", "sweptAt"}
)
"""State and timestamps only. sweepAfter and sweptAt are N9's second sweep."""


class Backend(Protocol):
    def set_state(self, uid: str, state: str) -> None: ...
    def finish_record(self, uid: str) -> None: ...
    def mark_swept(self, uid: str) -> None: ...
    def lock_auth(self, uid: str) -> None: ...
    def blocked_uids(self, uid: str) -> list[str]: ...
    def delete_blocked_by(self, other: str, uid: str) -> None: ...
    def delete_user_tree(self, uid: str) -> None: ...
    def delete_plans_tree(self, uid: str) -> None: ...
    def delete_storage_prefix(self, bucket: str | None, prefix: str) -> None: ...
    def delete_where_uid(self, collection: str, uid: str) -> None: ...
    def delete_doc(self, collection: str, doc_id: str) -> None: ...
    def close_registry(self, uid: str, may_rejoin: bool) -> None: ...
    def pseudonymise_reports(self, uid: str, token: str) -> None: ...
    def delete_auth(self, uid: str) -> None: ...


def pseudonym() -> str:
    """A per-run random token. Not derived from the uid, so not reversible."""
    return f"deleted-{secrets.token_hex(8)}"


def run(uid: str, backend: Backend) -> dict:
    """Delete her account. Returns {state: "done", journal: [...]}.

    Raises whatever the backend raised after recording `failedRetryable`; the
    caller turns that into INTERNAL and the sweeper finishes the job.
    """
    actions = {manifest.ACTIONS[row.number] for row in manifest.ROWS}
    try:
        backend.set_state(uid, "requested")

        backend.set_state(uid, "authLocked")
        backend.lock_auth(uid)

        backend.set_state(uid, "purgingFirestore")
        if manifest.REVERSE_BLOCKED_BY in actions:
            for other in backend.blocked_uids(uid):
                backend.delete_blocked_by(other, uid)
        backend.delete_user_tree(uid)
        if manifest.PLANS_RECURSIVE in actions:
            backend.delete_plans_tree(uid)

        backend.set_state(uid, "purgingStorage")
        for bucket in (None, PERSONAL_BUCKET):
            for prefix in STORAGE_PREFIXES:
                backend.delete_storage_prefix(bucket, prefix.format(uid=uid))

        backend.set_state(uid, "purgingGroupHooks")
        backend.delete_where_uid(config.COL_VERIFICATION_JOBS, uid)
        backend.delete_where_uid(config.COL_FLAGS, uid)
        backend.delete_where_uid(config.COL_SESSIONS, uid)
        backend.delete_doc(config.COL_LEDGER, uid)
        backend.close_registry(uid, config.DELETED_ACCOUNT_MAY_REJOIN)
        backend.pseudonymise_reports(uid, pseudonym())

        # Nothing to call. Recorded so the journal shows the step was weighed.
        backend.set_state(uid, "purgingThirdParty")

        backend.set_state(uid, "authDeleted")
        backend.delete_auth(uid)

        backend.finish_record(uid)
    except Exception:
        try:
            backend.set_state(uid, FAILED_RETRYABLE)
        except Exception:
            pass
        raise
    return {"state": "done", "journal": list(JOURNAL)}


def resweep(uid: str, backend: Backend) -> None:
    """N9: the one late sweep of users/{uid} and plans/{uid}, then marked so it
    never runs again. Idempotent: deleting what is already gone is a no-op."""
    backend.delete_user_tree(uid)
    if manifest.PLANS_RECURSIVE in {manifest.ACTIONS[row.number] for row in manifest.ROWS}:
        backend.delete_plans_tree(uid)
    backend.mark_swept(uid)


class FirebaseBackend:
    """The live Backend: Firestore, Firebase Auth and Cloud Storage (delete only)."""

    def __init__(self):
        from identity import store

        self.db = store.db()

    def _record(self, uid):
        return self.db.collection("deletionRequests").document(uid)

    def set_state(self, uid, state):
        from google.cloud import firestore

        reference = self._record(uid)
        snapshot = reference.get()
        payload = {"state": state, "updatedAt": firestore.SERVER_TIMESTAMP}
        if not snapshot.exists or not (snapshot.to_dict() or {}).get("requestedAt"):
            payload["requestedAt"] = firestore.SERVER_TIMESTAMP
        reference.set(payload, merge=True)

    def finish_record(self, uid):
        from google.cloud import firestore

        reference = self._record(uid)
        current = reference.get().to_dict() or {}
        # A full set, not a merge: the record is REDUCED to state and
        # timestamps. sweepAfter schedules N9's one late sweep.
        reference.set(
            {
                "state": "done",
                "requestedAt": current.get("requestedAt") or firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "doneAt": firestore.SERVER_TIMESTAMP,
                "sweepAfter": dt.datetime.now(dt.timezone.utc)
                + dt.timedelta(minutes=config.DELETION_RESWEEP_MINUTES),
            }
        )

    def mark_swept(self, uid):
        from google.cloud import firestore

        self._record(uid).set(
            {
                "sweepAfter": firestore.DELETE_FIELD,
                "sweptAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    def lock_auth(self, uid):
        from firebase_admin import auth

        try:
            auth.revoke_refresh_tokens(uid)
            auth.update_user(uid, disabled=True)
        except auth.UserNotFoundError:
            pass  # a re-run after the Auth user was already deleted

    def blocked_uids(self, uid):
        blocks = self.db.collection(config.COL_USERS).document(uid).collection("blocks")
        return [snapshot.id for snapshot in blocks.stream()]

    def delete_blocked_by(self, other, uid):
        (
            self.db.collection(config.COL_USERS)
            .document(other)
            .collection("blockedBy")
            .document(uid)
            .delete()
        )

    def delete_user_tree(self, uid):
        self.db.recursive_delete(self.db.collection(config.COL_USERS).document(uid))

    def delete_plans_tree(self, uid):
        self.db.recursive_delete(self.db.collection("plans").document(uid))

    def delete_storage_prefix(self, bucket, prefix):
        from firebase_admin import storage
        from google.api_core import exceptions

        try:
            target = storage.bucket(bucket) if bucket else storage.bucket()
            blobs = list(target.list_blobs(prefix=prefix))
        except (ValueError, exceptions.NotFound):
            # No default bucket configured, or the bucket does not exist: it
            # holds nothing of hers. Failing here would loop the deletion on
            # failedRetryable for ever over an empty place.
            return
        for blob in blobs:
            try:
                blob.delete()
            except exceptions.NotFound:
                pass

    def delete_where_uid(self, collection, uid):
        for snapshot in self.db.collection(collection).where("uid", "==", uid).stream():
            snapshot.reference.delete()

    def delete_doc(self, collection, doc_id):
        self.db.collection(collection).document(doc_id).delete()

    def close_registry(self, uid, may_rejoin):
        from google.cloud import firestore

        query = self.db.collection(config.COL_NID_REGISTRY).where("uid", "==", uid)
        for snapshot in query.stream():
            if may_rejoin:
                snapshot.reference.delete()
            else:
                snapshot.reference.set(
                    {"state": "closed", "uid": None, "closedAt": firestore.SERVER_TIMESTAMP},
                    merge=True,
                )

    def pseudonymise_reports(self, uid, token):
        reports = self.db.collection("reports")
        for field in ("reporterUid", "subjectUid"):
            for snapshot in reports.where(field, "==", uid).stream():
                snapshot.reference.update({field: token})

    def delete_auth(self, uid):
        from firebase_admin import auth

        try:
            auth.delete_user(uid)
        except auth.UserNotFoundError:
            pass


def unfinished(db, older_than) -> list[str]:
    """deletionRequests not yet done and untouched since `older_than`.

    `state in [...]` is a single-field query (auto-indexed); the age filter runs
    here so no composite index is needed."""
    query = (
        db.collection("deletionRequests")
        .where("state", "in", UNFINISHED_STATES)
        .limit(100)
    )
    out = []
    for snapshot in query.stream():
        updated = (snapshot.to_dict() or {}).get("updatedAt")
        if updated is None or updated < older_than:
            out.append(snapshot.id)
    return out


def due_resweeps(db, now) -> list[str]:
    """deletionRequests whose late sweep (N9) is due. A single-field range on
    sweepAfter (auto-indexed); a swept record has no sweepAfter and so never
    matches again."""
    query = (
        db.collection("deletionRequests").where("sweepAfter", "<=", now).limit(100)
    )
    return [snapshot.id for snapshot in query.stream()]
