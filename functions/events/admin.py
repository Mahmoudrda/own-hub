"""The events the owner publishes from the dashboard.

`validate` holds the same limits as `validEvent` in firebase/firestore.rules,
so a row the server writes is a row the rules would accept. seatsTaken is never
read from the request: it is only changed by events/seats.py.
"""

from __future__ import annotations

import datetime as dt
import re
import secrets
from typing import Any

from google.cloud import firestore

from .seats import COLLECTION, ID

MAX_IMAGES = 6
MAX_VIDEOS = 2
IMAGE_FILE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,80}\.(webp|jpg|jpeg)$")
VIDEO_FILE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,80}\.mp4$")
MAPS_URL = re.compile(
    r"https://((maps\.google\.com|maps\.app\.goo\.gl)([/?#]\S*)?"
    r"|goo\.gl/maps([/?#]\S*)?"
    r"|www\.google\.com/maps([/?#]\S*)?)"
)
LINK = re.compile(r"https://\S{3,500}")
STATUSES = ("draft", "published", "cancelled")
MODES = ("online", "place")
TIME_ZONE = "Africa/Cairo"


def _text(data: dict, key: str, limit: int, problems: list[str], required: bool = False):
    value = data.get(key)
    if value is None or value == "":
        if required:
            problems.append(f"{key} is required")
        return None
    if not isinstance(value, str) or len(value) > limit:
        problems.append(f"{key} must be text of at most {limit} characters")
        return None
    return value


def _when(data: dict, key: str, problems: list[str]):
    value = data.get(key)
    if isinstance(value, str):
        try:
            parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            parsed = None
        if parsed is not None and parsed.tzinfo is not None:
            return parsed.astimezone(dt.timezone.utc)
    problems.append(f"{key} must be a date and time with a zone")
    return None


def _files(data: dict, key: str, limit: int, pattern, problems: list[str]) -> list[str]:
    value = data.get(key)
    if value is None:
        return []
    if not isinstance(value, list) or len(value) > limit:
        problems.append(f"{key} may hold at most {limit} files")
        return []
    if not all(isinstance(name, str) and pattern.match(name) for name in value):
        problems.append(f"{key} holds a file name that is not allowed")
        return []
    if len(set(value)) != len(value):
        problems.append(f"{key} names a file twice")
        return []
    return list(value)


def validate(data: Any) -> tuple[dict, list[str]]:
    """Returns (the fields to store, problems). Nothing is stored when there are
    problems. seatsTaken, createdAt, updatedAt, timeZone and audience are not
    read from `data`."""
    problems: list[str] = []
    if not isinstance(data, dict):
        return {}, ["the request is not an event"]
    row: dict = {}
    row["titleEn"] = _text(data, "titleEn", 120, problems, required=True)
    row["titleAr"] = _text(data, "titleAr", 120, problems, required=True)
    for key in ("descriptionEn", "descriptionAr"):
        row[key] = _text(data, key, 2000, problems)
    starts = _when(data, "startsAt", problems)
    ends = _when(data, "endsAt", problems)
    if starts and ends and not starts < ends:
        problems.append("the event must end after it starts")
    row["startsAt"], row["endsAt"] = starts, ends

    mode = data.get("mode")
    if mode not in MODES:
        problems.append("mode must be online or place")
    row["mode"] = mode
    status = data.get("status")
    if status not in STATUSES:
        problems.append("status must be draft, published or cancelled")
    row["status"] = status

    link = _text(data, "link", 510, problems)
    place = _text(data, "placeName", 120, problems)
    address = _text(data, "locationAddress", 300, problems)
    map_url = _text(data, "locationUrl", 500, problems)
    if mode == "online":
        if not link or not LINK.fullmatch(link):
            problems.append("an online event needs an https link")
        place = address = map_url = None
    elif mode == "place":
        if not place:
            problems.append("an event in person needs a place name")
        if map_url and not MAPS_URL.fullmatch(map_url):
            problems.append("the map link must be an https Google Maps link")
        link = None
    row["link"], row["placeName"] = link, place
    row["locationAddress"], row["locationUrl"] = address, map_url

    capacity = data.get("capacity")
    if capacity is not None and (
        isinstance(capacity, bool) or not isinstance(capacity, int) or not 1 <= capacity <= 100000
    ):
        problems.append("seats must be a whole number from 1 to 100000")
        capacity = None
    row["capacity"] = capacity
    row["coverFile"] = _text(data, "coverFile", 200, problems)
    row["imageFiles"] = _files(data, "imageFiles", MAX_IMAGES, IMAGE_FILE, problems)
    row["videoFiles"] = _files(data, "videoFiles", MAX_VIDEOS, VIDEO_FILE, problems)
    return row, problems


def save(db, data: Any) -> dict:
    """Creates or edits one event: `{ok, eventId}` or `{ok: False, problems}`."""
    row, problems = validate(data)
    event_id = data.get("eventId") if isinstance(data, dict) else None
    if event_id is not None and not (isinstance(event_id, str) and ID.match(event_id)):
        problems.append("eventId is not a valid id")
    if problems:
        return {"ok": False, "problems": problems}
    if event_id is None:
        event_id = "ev_" + secrets.token_hex(8)
    reference = db.collection(COLLECTION).document(event_id)

    @firestore.transactional
    def txn(transaction):
        snapshot = reference.get(transaction=transaction)
        current = (snapshot.to_dict() or {}) if snapshot.exists else {}
        taken = current.get("seatsTaken")
        taken = taken if isinstance(taken, int) and taken > 0 else 0
        if taken and (row["capacity"] is None or row["capacity"] < taken):
            return {
                "ok": False,
                "problems": [f"{taken} seats are already booked, so seats cannot go below that"],
            }
        document = {key: value for key, value in row.items() if value is not None}
        if "coverFile" not in data and current.get("coverFile"):
            document["coverFile"] = current["coverFile"]
        document.update(
            {
                "timeZone": TIME_ZONE,
                "audience": "all",
                "seatsTaken": taken,
                "createdAt": current.get("createdAt") or firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
        )
        transaction.set(reference, document)
        return {"ok": True, "eventId": event_id}

    return txn(db.transaction())


def _iso(value) -> str | None:
    if not isinstance(value, dt.datetime):
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def list_all(db) -> dict:
    """Every event, soonest first, for the dashboard's list and form."""
    events = []
    for snapshot in db.collection(COLLECTION).stream():
        data = snapshot.to_dict() or {}
        events.append(
            {
                "eventId": snapshot.id,
                "titleEn": data.get("titleEn"),
                "titleAr": data.get("titleAr"),
                "descriptionEn": data.get("descriptionEn"),
                "descriptionAr": data.get("descriptionAr"),
                "startsAt": _iso(data.get("startsAt")),
                "endsAt": _iso(data.get("endsAt")),
                "mode": data.get("mode"),
                "status": data.get("status"),
                "link": data.get("link"),
                "placeName": data.get("placeName"),
                "locationAddress": data.get("locationAddress"),
                "locationUrl": data.get("locationUrl"),
                "capacity": data.get("capacity"),
                "seatsTaken": data.get("seatsTaken") or 0,
                "coverFile": data.get("coverFile"),
                "imageFiles": list(data.get("imageFiles") or []),
                "videoFiles": list(data.get("videoFiles") or []),
            }
        )
    events.sort(key=lambda e: (e["startsAt"] or "", e["eventId"]))
    return {"events": events}
