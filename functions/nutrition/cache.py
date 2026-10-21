"""Exact-photo cache for meal scans.

scanCache/{sha256 of the re-encoded JPEG} holds what the model said about that
photo: its items, a creation time and an expiry. No uid, no image, no locale.
The same photo again is answered from here without a model call and without
spending anyone's scan. The collection is server-only (firebase/firestore.rules
denies every client) and carries a Firestore TTL policy on `expiresAt`.

The model's items are kept rather than the finished answer, so the numbers on a
cache hit are computed by nutrition/meal.py from today's tables.
"""

from __future__ import annotations

import dataclasses
import datetime as dt
import hashlib
from typing import Optional

from . import config, model


def key(jpeg: bytes) -> str:
    return hashlib.sha256(jpeg).hexdigest()


def _aware(value) -> Optional[dt.datetime]:
    if not isinstance(value, dt.datetime):
        return None
    return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)


def get(db, cache_key: str, now: dt.datetime) -> Optional[list]:
    """The cached items, or None for a miss, an expired row or one that is not
    the shape this code writes."""
    snapshot = db.collection(config.SCAN_CACHE_COLLECTION).document(cache_key).get()
    if not snapshot.exists:
        return None
    data = snapshot.to_dict() or {}
    expires = _aware(data.get("expiresAt"))
    if expires is None or expires <= now:
        return None
    try:
        items = [
            model.Item(
                **{
                    **raw,
                    "ingredients": [model.Ingredient(**part) for part in raw["ingredients"]],
                }
            )
            for raw in data["items"]
        ]
    except (KeyError, TypeError):
        return None
    return items or None


def put(db, cache_key: str, items: list, now: dt.datetime) -> None:
    db.collection(config.SCAN_CACHE_COLLECTION).document(cache_key).set(
        {
            "items": [dataclasses.asdict(item) for item in items],
            "createdAt": now,
            "expiresAt": now + dt.timedelta(days=config.SCAN_CACHE_DAYS),
        }
    )
