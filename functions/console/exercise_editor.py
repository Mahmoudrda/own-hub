"""The exercise library editor behind the reviewer dashboard.

The same checks as tools/publish_exercise_library.py, for one exercise at a
time: the dashboard uploads the clip and poster to Storage, this module reads
what is stored, fills in the md5 and size, validates the row against the
contract, writes the media register lines, and commits the exercise, the
member library and its version in one batch. Nothing here deletes.
"""

from __future__ import annotations

from typing import Optional

from tools import publish_exercise_library as lib
from tools.upload_media import CONTENT_BUCKET, REGISTRY, registry_id, storage_path

VOCAB_KEYS = (
    "muscles", "bodyRegions", "patterns", "equipment", "places", "levels",
    "kinds", "angles", "contraindicationTags", "limits",
)
ROW_FIELDS = (
    "exerciseId", "name_en", "name_ar", "kind", "primaryMuscles", "secondaryMuscles",
    "bodyRegion", "pattern", "equipment", "place", "level", "quiet", "floorOnly",
    "contraindicationTags", "setup_en", "setup_ar",
)


def _library(db) -> dict:
    return lib._get(db, lib.LIBRARY_DOC) or {}


def list_library(db) -> dict:
    return {
        "exercises": list(_library(db).get("exercises") or []),
        "vocab": {key: lib.CONTRACT[key] for key in VOCAB_KEYS},
    }


def _row(data: dict, bucket, problems: list[str]) -> Optional[dict]:
    rid = data.get("exerciseId")
    if not isinstance(rid, str) or not lib._ID.match(rid):
        problems.append("the exercise id may hold lowercase letters, digits and _ only")
        return None
    row = {key: data[key] for key in ROW_FIELDS if key in data}
    for key in ("setup_en", "setup_ar"):
        if not row.get(key):
            row.pop(key, None)

    def md5_of(name) -> str:
        blob = bucket.get_blob(storage_path(lib.COLLECTION, rid, str(name)))
        if blob is None:
            problems.append(f"{name} is not uploaded")
            return ""
        return lib._md5_hex(blob) or ""

    clips = data.get("clips") if isinstance(data.get("clips"), list) else []
    row["clips"] = [
        {"file": c.get("file"), "angle": c.get("angle"), "seconds": c.get("seconds"),
         "source": "dashboard", "md5": md5_of(c.get("file"))}
        for c in clips if isinstance(c, dict)
    ]
    poster = data.get("poster") if isinstance(data.get("poster"), dict) else {}
    row["poster"] = {"file": poster.get("file"), "md5": md5_of(poster.get("file"))}
    return row


def _register(db, bucket, row) -> None:
    for name, _md5, kind, _ceiling in lib._files(row):
        path = storage_path(lib.COLLECTION, row["exerciseId"], name)
        blob = bucket.get_blob(path)
        if blob is None:
            continue
        db.collection(REGISTRY).document(registry_id(lib.COLLECTION, row["exerciseId"], name)).set(
            {"path": path, "kind": kind, "bytes": blob.size, "source": "dashboard"}
        )


def save(db, bucket, data: dict) -> dict:
    problems: list[str] = []
    row = _row(data, bucket, problems)
    if row is None or problems:
        return {"ok": False, "problems": problems}
    problems = lib.validate({"tagsReview": "edited in the dashboard", "exercises": [row]})
    if problems:
        return {"ok": False, "problems": problems}
    _register(db, bucket, row)
    sizes, problems = lib.check_media([row], bucket=bucket, db=db)
    if problems:
        return {"ok": False, "problems": problems}
    try:
        version = lib.next_version(db)
    except lib.LibraryRefused as refused:
        return {"ok": False, "problems": [str(refused)]}
    rid = row["exerciseId"]
    rows = [r for r in (_library(db).get("exercises") or []) if r.get("id") != rid]
    rows.append(lib.library_row(row, sizes))
    library = {"version": version, "schema": lib.CONTRACT["schema"], "exercises": rows}
    size = lib.document_bytes(library)
    if size > lib.LIMITS["maxDocumentBytes"]:
        return {"ok": False, "problems": [f"the library would be {size} bytes, over {lib.LIMITS['maxDocumentBytes']}"]}
    batch = db.batch()
    batch.set(db.collection(lib.COLLECTION).document(rid), lib.exercise_document(row))
    batch.set(db.collection(lib.LIBRARY_DOC[0]).document(lib.LIBRARY_DOC[1]), library)
    batch.set(db.collection(lib.VERSION_DOC[0]).document(lib.VERSION_DOC[1]), {"version": version})
    batch.commit()
    return {"ok": True, "version": version}
