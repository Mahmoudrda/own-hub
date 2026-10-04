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
    purgingStorage     user-media/{uid}/, user-exports/{uid}/ and
                       coach-docs/{uid}/ in the default bucket and in
                       own-hub-personal (rows 24, 25; see STORAGE_PREFIXES).
                       DELETE only: nothing here ever writes to Storage
    purgingGroupHooks  verificationJobs, verification_flags and
                       verificationSessions where uid == (rows 22, 39, 41),
                       verificationLedger/{uid} (row 40), the community, coach
                       and assistant data (row 26, purge_group_hook), the
                       registry entry CLOSED not deleted (row 23), reports
                       pseudonymised (row 30)
    purgingThirdParty  nothing to call: no analytics SDK ships, and crash
                       reports never carry a user id (rows 27, 28)
    authDeleted        the Auth user deleted LAST (row 29)
    done               deletionRequests/{uid} reduced to state and timestamps,
                       the retained proof of erasure (row 31)

N9, after done: a still-valid ID token (up to an hour) or a queued offline
write can partly recreate users/{uid} or plans/{uid}. `done` therefore records
sweepAfter (config.DELETION_RESWEEP_MINUTES, 65, later) and the sweeper runs
one more recursive delete of both, and one more purge of every Storage prefix
(a still-valid token can upload too), once it is due (`resweep`), then
replaces sweepAfter with sweptAt so it never runs again.

Idempotent: every step tolerates having already run, so a re-run after a
failure finishes the job rather than failing on what is already gone.

Not uid-keyed and therefore untouched: verificationReviewAccess (the review
audit log), verificationBehaviour, verificationInstalls (hash-keyed signals)
and verificationStats (counts with no uid).
"""

from __future__ import annotations

import datetime as dt
import secrets
import time
from typing import Optional, Protocol

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

STORAGE_PREFIXES = ("user-media/{uid}/", "user-exports/{uid}/", "coach-docs/{uid}/")
"""Every Storage place that holds her files (B1).

user-media/{uid}/ is the one prefix the community and coach-media groups own
(G7 §1.3): post media, profile photos, coach portfolio media, message
attachments and voice notes. user-exports/{uid}/ is her data export.
coach-docs/{uid}/ holds a coach's certificate scans (G12 §6). ID and selfie
images and progress photos have no Storage path at all. A new uid-keyed path
in storage.rules or the app fails tests/test_deletion_storage.py until it is
added here."""
PERSONAL_BUCKET = "own-hub-personal"
DELETION_RECORD_FIELDS = frozenset(
    {"state", "requestedAt", "updatedAt", "doneAt", "sweepAfter", "sweptAt"}
)
"""State and timestamps only. sweepAfter and sweptAt are N9's second sweep."""

SCAN_PHASES = ("following", "comments", "likes", "results")
"""B3: the collection groups the hook scans, in order. Her entries are found by
document id (following, likes) or by the projected field (comments.authorUid,
results.clientUid). A filtered collection-group query would need a
single-field index override, and firestore.indexes.json carries exemptions
only, so the scan stays and is paged instead."""
_SCAN_FIELDS = {"following": None, "comments": "authorUid", "likes": None, "results": "clientUid"}
SCAN_DONE = "done"

_clock = time.monotonic
"""Seconds. Deadlines passed to run, resweep and purge_group_hook are readings
of this clock."""


def expired(deadline: Optional[float]) -> bool:
    return deadline is not None and _clock() >= deadline


def deadline_after(seconds: float) -> float:
    return _clock() + seconds


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
    def purge_group_hook(self, uid: str, deadline: Optional[float] = None) -> bool: ...
    def close_registry(self, uid: str, may_rejoin: bool) -> None: ...
    def pseudonymise_reports(self, uid: str, token: str) -> None: ...
    def delete_auth(self, uid: str) -> None: ...


def pseudonym() -> str:
    """A per-run random token. Not derived from the uid, so not reversible."""
    return f"deleted-{secrets.token_hex(8)}"


def run(uid: str, backend: Backend, deadline: Optional[float] = None) -> dict:
    """Delete her account. Returns {state: "done", journal: [...]}.

    B3: with a `deadline` (a reading of `_clock`), the community scan stops
    when it passes, its cursor saved. The record then stays at
    `purgingGroupHooks` (an unfinished state the sweeper resumes) and this
    returns {state: "purgingGroupHooks", journal: [... "purgingGroupHooks"]},
    which the app reads as "not done yet, it will finish".

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
        purge_storage(uid, backend)

        backend.set_state(uid, "purgingGroupHooks")
        backend.delete_where_uid(config.COL_VERIFICATION_JOBS, uid)
        backend.delete_where_uid(config.COL_FLAGS, uid)
        backend.delete_where_uid(config.COL_SESSIONS, uid)
        backend.delete_doc(config.COL_LEDGER, uid)
        # Row 26 (N14). Unconditional: erasure must not depend on a manifest
        # row still being present.
        if backend.purge_group_hook(uid, deadline) is False:
            paused = JOURNAL[: JOURNAL.index("purgingGroupHooks") + 1]
            return {"state": "purgingGroupHooks", "journal": paused}
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


def purge_storage(uid: str, backend: Backend) -> None:
    """Every prefix in STORAGE_PREFIXES, in both buckets. A bucket that does
    not exist counts as empty (FirebaseBackend.delete_storage_prefix)."""
    for bucket in (None, PERSONAL_BUCKET):
        for prefix in STORAGE_PREFIXES:
            backend.delete_storage_prefix(bucket, prefix.format(uid=uid))


def resweep(uid: str, backend: Backend, deadline: Optional[float] = None) -> None:
    """N9: the one late sweep of users/{uid}, plans/{uid}, her Storage
    prefixes and her community data (B3: a like or comment a still-valid token
    wrote behind the scan cursor), then marked so it never runs again.
    Idempotent: deleting what is already gone is a no-op. A failure, or a
    community scan that runs out of time, leaves sweepAfter set so the sweeper
    tries again, from the saved cursor."""
    backend.delete_user_tree(uid)
    if manifest.PLANS_RECURSIVE in {manifest.ACTIONS[row.number] for row in manifest.ROWS}:
        backend.delete_plans_tree(uid)
    purge_storage(uid, backend)
    if backend.purge_group_hook(uid, deadline) is False:
        return
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
                "hookCursor": firestore.DELETE_FIELD,
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

    def purge_group_hook(self, uid, deadline=None):
        """Row 26 (N14): her community, coach and assistant data.

        The most protective default. DELETED: publicProfiles/{uid}, her
        followGraph tree and every edge pointing at her (the following/{uid}
        edge documents and the a:{uid} key and hiddenAuthors entries on other
        women's key sets), her posts with everything under them, her likes,
        her group memberships, every relationship she is a party to (as client
        or coach) with its messages and reviews, coaches/{uid} with everything
        under it, results about her on other coaches' pages, and
        assistantQuota/{uid}.

        Her comments on ANOTHER woman's post are replaced, not removed, so that
        woman's thread does not silently lose a turn: the document is
        overwritten with exactly {deleted: true}, no text and no uid. A comment
        id that spells her uid is not kept as the tombstone's id.

        B2: each removed like and each tombstoned comment takes counts.likes or
        counts.comments on its post down by one in the same transaction, never
        below 0. Follower and following counts are not stored (the app counts
        edges), so deleting the edges keeps them true.

        Comments, likes, following edges and results are found by scanning
        their collection group with a projection, not by a filtered query: a
        collection-group filter needs a single-field index override, and
        firestore.indexes.json only carries exemptions. Idempotent.

        B3: the scan is paged (config.DELETION_SCAN_PAGE, by document name)
        and stops once `deadline` passes, saving {phase, after} on
        deletionRequests/{uid}.hookCursor. A later call resumes from it.
        Returns True when everything is done, False when it ran out of time.
        """
        from google.cloud import firestore

        db = self.db
        db.collection("publicProfiles").document(uid).delete()
        db.collection("assistantQuota").document(uid).delete()

        # Follow graph: hers, then every pointer to her on anyone else's.
        db.recursive_delete(db.collection("followGraph").document(uid))
        graphs = db.collection("followGraph")
        for field, value in (("followingKeys", f"a:{uid}"), ("hiddenAuthors", uid)):
            for snapshot in graphs.where(field, "array_contains", value).stream():
                snapshot.reference.update({field: firestore.ArrayRemove([value])})

        # Her posts, with every comment and like under them.
        # (The pointers to her on other women's follow lists are the
        # `following` phase of the scan below.)
        for snapshot in db.collection("posts").where("authorUid", "==", uid).stream():
            db.recursive_delete(snapshot.reference)

        for group in db.collection("groups").select([]).stream():
            group.reference.collection("members").document(uid).delete()

        relationships = db.collection("relationships")
        for field in ("clientUid", "coachUid"):
            for snapshot in relationships.where(field, "==", uid).stream():
                db.recursive_delete(snapshot.reference)

        db.recursive_delete(db.collection("coaches").document(uid))

        # What is left is on other women's posts, follow lists and coach
        # pages. Each like or comment removal takes its post's counter down in
        # the same transaction (B2).
        return self._scan_phases(uid, deadline)

    def _purge_found(self, phase, snapshot, uid):
        if phase == "following":
            if snapshot.id == uid:
                snapshot.reference.delete()
        elif phase == "comments":
            if (snapshot.to_dict() or {}).get("authorUid") == uid:
                self._tombstone_comment(snapshot.reference, uid)
        elif phase == "likes":
            if snapshot.id == uid:
                self._remove_like(snapshot.reference)
        elif phase == "results":
            if (snapshot.to_dict() or {}).get("clientUid") == uid:
                snapshot.reference.delete()

    def _scan_phases(self, uid, deadline):
        """B3: every SCAN_PHASES group, a page at a time, from the saved cursor."""
        saved = (self._record(uid).get().to_dict() or {}).get("hookCursor") or {}
        phase = saved.get("phase")
        if phase == SCAN_DONE:
            return True
        start = SCAN_PHASES.index(phase) if phase in SCAN_PHASES else 0
        after = saved.get("after") if phase in SCAN_PHASES else None
        page_size = config.DELETION_SCAN_PAGE
        for index in range(start, len(SCAN_PHASES)):
            group = SCAN_PHASES[index]
            field = _SCAN_FIELDS[group]
            while True:
                if expired(deadline):
                    self._save_cursor(uid, group, after)
                    return False
                query = (
                    self.db.collection_group(group)
                    .select([field] if field else [])
                    .order_by("__name__")
                )
                if after:
                    query = query.start_after({"__name__": self.db.document(after)})
                page = list(query.limit(page_size).stream())
                for snapshot in page:
                    self._purge_found(group, snapshot, uid)
                    after = snapshot.reference.path
                    if expired(deadline):
                        self._save_cursor(uid, group, after)
                        return False
                if len(page) < page_size:
                    break
                self._save_cursor(uid, group, after)
            after = None
            following = SCAN_PHASES[index + 1] if index + 1 < len(SCAN_PHASES) else SCAN_DONE
            self._save_cursor(uid, following, None)
        return True

    def _save_cursor(self, uid, phase, after):
        """On her deletion record, beside the state. Removed when the record
        is reduced at `done` and again when the late sweep is marked."""
        from google.cloud import firestore

        self._record(uid).set(
            {
                "hookCursor": {"phase": phase, "after": after},
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    def _remove_like(self, like_ref):
        """B2: delete her like and take counts.likes on its post down by one,
        atomically. A like already gone changes nothing, so a re-run never
        decrements twice."""
        from google.cloud import firestore

        post_ref = like_ref.parent.parent

        @firestore.transactional
        def txn(transaction):
            like = like_ref.get(transaction=transaction)
            post = post_ref.get(transaction=transaction) if post_ref is not None else None
            if not like.exists:
                return
            transaction.delete(like_ref)
            _decrement(transaction, post, "likes")

        txn(self.db.transaction())

    def _tombstone_comment(self, comment_ref, uid):
        """B2: replace her comment with exactly {deleted: true} and take
        counts.comments on its post down by one, atomically. A comment id that
        spells her uid is not kept as the tombstone's id. Re-checks the author
        inside the transaction, so a re-run never decrements twice."""
        from google.cloud import firestore

        post_ref = comment_ref.parent.parent
        target = comment_ref.parent.document() if uid in comment_ref.id else comment_ref

        @firestore.transactional
        def txn(transaction):
            comment = comment_ref.get(transaction=transaction)
            post = post_ref.get(transaction=transaction) if post_ref is not None else None
            if not comment.exists or (comment.to_dict() or {}).get("authorUid") != uid:
                return
            transaction.set(target, {"deleted": True})
            if target.path != comment_ref.path:
                transaction.delete(comment_ref)
            _decrement(transaction, post, "comments")

        txn(self.db.transaction())

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


def _decrement(transaction, post, field) -> None:
    """counts.<field> on a post, down by one and never below 0. A post that is
    gone, or that has no such count, is left alone: no counter is invented."""
    if post is None or not post.exists or not post.reference.path.startswith("posts/"):
        return
    counts = (post.to_dict() or {}).get("counts")
    current = counts.get(field) if isinstance(counts, dict) else None
    if isinstance(current, bool) or not isinstance(current, (int, float)):
        return
    transaction.update(post.reference, {f"counts.{field}": max(0, int(current) - 1)})


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
