"""C1: posts/{id}.counts.likes and counts.comments, kept by Firestore triggers.

The triggers (main.post_like_counter, main.post_comment_counter) are the ONLY
writer of `counts`. The rules forbid a client from touching it, and the
deletion purge only deletes and tombstones, leaving the arithmetic to the
triggers its writes fire. One owner, so nothing is counted twice.

  likes     a document that exists is one like
  comments  a document that exists and is not a tombstone ({deleted: true})
            is one comment, so tombstoning in place takes one off and a
            tombstone created or deleted on its own changes nothing

Delivery is at least once. The event id is written to
posts/{postId}/countEvents/{eventId} in the same transaction as the count, so
a re-delivered event finds its marker and does nothing. The markers carry no
uid and go with the post when it is deleted. A post that no longer exists is
left alone: no count and no marker, so nothing is recreated under it.

Never below 0.
"""

from __future__ import annotations

from typing import Optional

KINDS = {"likes": "likes", "comments": "comments"}
MARKERS = "countEvents"


def _live(kind: str, data: Optional[dict]) -> bool:
    if data is None:
        return False
    if kind == "comments":
        return data.get("deleted") is not True
    return True


def delta(kind: str, before: Optional[dict], after: Optional[dict]) -> int:
    return int(_live(kind, after)) - int(_live(kind, before))


def on_change(db, event_id: str, path: str, before: Optional[dict], after: Optional[dict]) -> None:
    """Apply one written event on posts/{postId}/{likes|comments}/{id}."""
    parts = path.split("/")
    if len(parts) != 4 or parts[0] != "posts" or parts[2] not in KINDS:
        return
    kind = parts[2]
    step = delta(kind, before, after)
    if step == 0:
        return
    apply(db, event_id, parts[1], kind, step)


def apply(db, event_id: str, post_id: str, kind: str, step: int) -> None:
    from google.cloud import firestore

    post_ref = db.collection("posts").document(post_id)
    marker_ref = post_ref.collection(MARKERS).document(event_id)

    @firestore.transactional
    def txn(transaction):
        marker = marker_ref.get(transaction=transaction)
        post = post_ref.get(transaction=transaction)
        if marker.exists or not post.exists:
            return
        current = (post.to_dict() or {}).get("counts")
        value = current.get(kind) if isinstance(current, dict) else None
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            value = 0
        transaction.update(post_ref, {f"counts.{kind}": max(0, int(value) + step)})
        transaction.set(marker_ref, {"at": firestore.SERVER_TIMESTAMP})

    txn(db.transaction())
