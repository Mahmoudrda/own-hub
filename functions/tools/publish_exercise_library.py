"""OWNER'S TOOL ONLY: publish the exercise library members browse (D42).

The clips and posters are uploaded first, one exercise at a time, with
tools/upload_media.py. This tool then writes what names them, from one
reviewed catalogue file, on owner credentials:

    cd functions
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.publish_exercise_library \\
        ../6-v2/content/exercise_library/catalogue.json            # dry run
    ... the same, with --write                                       # commit

app/tool/admin_access.sh publish-exercises wraps it.

What it does, in order, and refuses at the first step that fails:

  1. Every row is checked against contracts/exercise_library_contract.json:
     the vocabularies, the names in both languages, the tags, the clips.
  2. Every file a row names is checked where it lives: its mediaLibrary line
     exists and points at content/exercises/{id}/{file}, the stored object is
     there with that size and type, and its md5 is the one the catalogue
     recorded when the file was made.
  3. The member library is built, and refused over the size ceiling.
  4. A dry run prints what would change and writes nothing. --write commits
     everything in one batch: exercises/{id} for the console, the library in
     meta/exerciseLibrary, and its version in meta/exercises, which members'
     phones check once a day.

Exercises already in Firestore that the catalogue does not name are listed and
left alone. Nothing is ever deleted here.

Both documents live under meta/ because that is the one library path the
deployed rules already open to verified members; no rule changes for this.
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import sys
from pathlib import Path
from typing import Callable, Optional

from tools.upload_media import REGISTRY, _clients, _require_adc, registry_id, storage_path

COLLECTION = "exercises"
_HERE = Path(__file__).resolve()
CONTRACT_PATH = next(
    (c for c in (_HERE.parents[1] / "exercise_library_contract.json", _HERE.parents[2] / "contracts" / "exercise_library_contract.json") if c.exists()),
    _HERE.parents[2] / "contracts" / "exercise_library_contract.json",
)
CONTRACT = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
LIMITS = CONTRACT["limits"]
VERSION_DOC = CONTRACT["versionPath"].split("/")
LIBRARY_DOC = CONTRACT["libraryPath"].split("/")

PREGNANCY_FLOOR = {
    "pelvic_floor_load",
    "high_impact",
    "jumping",
    "supine_load",
    "breath_hold_valsalva",
}
"""LifeStageSafetyPolicy.pregnancyAndEarlyPostpartumFloor, for the dry run's
report of what a pregnant or newly postpartum member will not be shown."""

ROW_KEYS = {
    "exerciseId",
    "name_en",
    "name_ar",
    "kind",
    "primaryMuscles",
    "secondaryMuscles",
    "bodyRegion",
    "pattern",
    "equipment",
    "place",
    "level",
    "quiet",
    "floorOnly",
    "contraindicationTags",
    "setup_en",
    "setup_ar",
    "clips",
    "poster",
}
CLIP_KEYS = {"file", "angle", "seconds", "source", "md5"}
POSTER_KEYS = {"file", "md5"}

_ID = re.compile(CONTRACT["idPattern"])
_CLIP = re.compile(CONTRACT["clipPattern"])
_POSTER = re.compile(CONTRACT["posterPattern"])
_MD5 = re.compile(r"^[0-9a-f]{32}$")


class LibraryRefused(ValueError):
    """Why nothing was written."""


def _tokens(row, key, vocabulary, problems, *, allow_empty=False):
    value = row.get(key)
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        problems.append(f"{row.get('exerciseId')}: {key} must be a list of words")
        return []
    if not value and not allow_empty:
        problems.append(f"{row.get('exerciseId')}: {key} is empty")
    for token in value:
        if token not in vocabulary:
            problems.append(f"{row.get('exerciseId')}: {key} has an unknown {token!r}")
    if len(set(value)) != len(value):
        problems.append(f"{row.get('exerciseId')}: {key} repeats a word")
    return value


def _text(row, key, problems, *, required=True):
    value = row.get(key)
    if value is None and not required:
        return None
    if not isinstance(value, str) or not value.strip():
        problems.append(f"{row.get('exerciseId')}: {key} is empty")
        return None
    if len(value) > LIMITS["maxTextChars"]:
        problems.append(f"{row.get('exerciseId')}: {key} is over {LIMITS['maxTextChars']} characters")
    if "\u2014" in value or "\u2013" in value:
        problems.append(f"{row.get('exerciseId')}: {key} has a dash members would read; use a comma or a full stop")
    return value


def validate(catalogue) -> list[str]:
    """Every reason the catalogue cannot be published. Empty when it can."""
    problems: list[str] = []
    if not isinstance(catalogue, dict):
        return ["the catalogue must be an object"]
    unknown = set(catalogue) - {"tagsReview", "exercises"}
    if unknown:
        problems.append(f"unknown catalogue keys: {sorted(unknown)}")
    review = catalogue.get("tagsReview")
    if not isinstance(review, str) or not review.strip():
        problems.append("tagsReview must say who reviewed the safety tags, or that a review is pending")
    rows = catalogue.get("exercises")
    if not isinstance(rows, list) or not rows:
        return problems + ["exercises must be a non-empty list"]

    seen_ids: set[str] = set()
    seen_files: set[str] = set()
    for row in rows:
        if not isinstance(row, dict):
            problems.append("every exercise must be an object")
            continue
        rid = row.get("exerciseId")
        extra = set(row) - ROW_KEYS
        if extra:
            problems.append(f"{rid}: unknown keys {sorted(extra)}")
        if not isinstance(rid, str) or not _ID.match(rid):
            problems.append(f"{rid!r}: exerciseId must match {CONTRACT['idPattern']}")
        elif rid in seen_ids:
            problems.append(f"{rid}: exerciseId is used twice")
        else:
            seen_ids.add(rid)

        _text(row, "name_en", problems)
        _text(row, "name_ar", problems)
        setup_en = _text(row, "setup_en", problems, required=False)
        setup_ar = _text(row, "setup_ar", problems, required=False)
        if (setup_en is None) != (setup_ar is None):
            problems.append(f"{rid}: setup notes must be in both languages or neither")

        for key, vocabulary in (
            ("kind", CONTRACT["kinds"]),
            ("bodyRegion", CONTRACT["bodyRegions"]),
            ("pattern", CONTRACT["patterns"]),
            ("place", CONTRACT["places"]),
            ("level", CONTRACT["levels"]),
        ):
            if row.get(key) not in vocabulary:
                problems.append(f"{rid}: {key} {row.get(key)!r} is not one of {vocabulary}")
        if (row.get("kind") == "stretch") != (row.get("pattern") == "mobility"):
            problems.append(f"{rid}: a stretch is a mobility move, and only a stretch is")

        primary = _tokens(row, "primaryMuscles", CONTRACT["muscles"], problems)
        secondary = _tokens(row, "secondaryMuscles", CONTRACT["muscles"], problems, allow_empty=True)
        if set(primary) & set(secondary):
            problems.append(f"{rid}: a muscle is both primary and secondary")
        equipment = _tokens(row, "equipment", CONTRACT["equipment"], problems)
        if "none" in equipment and len(equipment) > 1:
            problems.append(f"{rid}: equipment 'none' cannot sit with other equipment")
        tags = _tokens(row, "contraindicationTags", CONTRACT["contraindicationTags"], problems)
        if "none" in tags and len(tags) > 1:
            problems.append(f"{rid}: tag 'none' cannot sit with other tags")
        for key in ("quiet", "floorOnly"):
            if not isinstance(row.get(key), bool):
                problems.append(f"{rid}: {key} must be true or false")

        clips = row.get("clips")
        if not isinstance(clips, list) or not 1 <= len(clips) <= LIMITS["maxClips"]:
            problems.append(f"{rid}: one or {LIMITS['maxClips']} clips")
            clips = []
        angles = []
        for clip in clips:
            if not isinstance(clip, dict) or set(clip) - CLIP_KEYS or not {"file", "angle", "seconds", "md5"} <= set(clip):
                problems.append(f"{rid}: a clip needs file, angle, seconds and md5, and nothing unknown")
                continue
            if not isinstance(clip["file"], str) or not _CLIP.match(clip["file"]):
                problems.append(f"{rid}: clip file {clip['file']!r} must match {CONTRACT['clipPattern']}")
            elif clip["file"] in seen_files:
                problems.append(f"{rid}: {clip['file']} is named twice")
            else:
                seen_files.add(clip["file"])
            if clip["angle"] not in CONTRACT["angles"]:
                problems.append(f"{rid}: angle {clip['angle']!r} is not one of {CONTRACT['angles']}")
            angles.append(clip["angle"])
            seconds = clip["seconds"]
            if not isinstance(seconds, (int, float)) or isinstance(seconds, bool) or seconds < LIMITS["minClipSeconds"]:
                problems.append(f"{rid}: a clip runs at least {LIMITS['minClipSeconds']} s")
            if not isinstance(clip["md5"], str) or not _MD5.match(clip["md5"]):
                problems.append(f"{rid}: clip md5 must be 32 lowercase hex digits")
        if len(set(angles)) != len(angles):
            problems.append(f"{rid}: two clips from the same angle")

        poster = row.get("poster")
        if not isinstance(poster, dict) or set(poster) != POSTER_KEYS:
            problems.append(f"{rid}: poster needs file and md5")
        else:
            if not isinstance(poster["file"], str) or not _POSTER.match(poster["file"]):
                problems.append(f"{rid}: poster file {poster['file']!r} must match {CONTRACT['posterPattern']}")
            elif poster["file"] in seen_files:
                problems.append(f"{rid}: {poster['file']} is named twice")
            else:
                seen_files.add(poster["file"])
            if not isinstance(poster["md5"], str) or not _MD5.match(poster["md5"]):
                problems.append(f"{rid}: poster md5 must be 32 lowercase hex digits")
    return problems


def _files(row):
    for clip in row["clips"]:
        yield clip["file"], clip["md5"], "video", LIMITS["maxClipBytes"]
    yield row["poster"]["file"], row["poster"]["md5"], "picture", LIMITS["maxPosterBytes"]


def _md5_hex(blob) -> Optional[str]:
    value = getattr(blob, "md5_hash", None)
    if not value:
        return None
    return base64.b64decode(value).hex()


def check_media(rows, *, bucket, db) -> tuple[dict[str, int], list[str]]:
    """The stored size of every file, and every reason a file is not right."""
    sizes: dict[str, int] = {}
    problems: list[str] = []
    for row in rows:
        rid = row["exerciseId"]
        for name, md5, kind, ceiling in _files(row):
            path = storage_path(COLLECTION, rid, name)
            record = db.collection(REGISTRY).document(registry_id(COLLECTION, rid, name)).get()
            if not getattr(record, "exists", False):
                problems.append(f"{rid}: {name} was never uploaded with upload_media")
                continue
            entry = record.to_dict() or {}
            if entry.get("path") != path or entry.get("kind") != kind:
                problems.append(f"{rid}: the media record for {name} does not point at {path}")
                continue
            blob = bucket.get_blob(path)
            if blob is None:
                problems.append(f"{rid}: {path} is not in the bucket")
                continue
            expected_type = "video/mp4" if kind == "video" else "image/webp"
            if blob.content_type != expected_type:
                problems.append(f"{rid}: {path} is stored as {blob.content_type}, not {expected_type}")
            if blob.size != entry.get("bytes"):
                problems.append(f"{rid}: {path} is {blob.size} bytes, its record says {entry.get('bytes')}")
            if blob.size is None or blob.size > ceiling:
                problems.append(f"{rid}: {path} is over {ceiling} bytes")
            if _md5_hex(blob) != md5:
                problems.append(f"{rid}: {path} is not the file the catalogue recorded (md5)")
            sizes[name] = blob.size or 0
    return sizes, problems


def exercise_document(row) -> dict:
    """exercises/{id}: exactly the console's columns, typed as it types them,
    so a later save from the console keeps every field."""
    clips = row["clips"]
    return {
        "exerciseId": row["exerciseId"],
        "name_en": row["name_en"],
        "name_ar": row["name_ar"],
        "equipment": list(row["equipment"]),
        "pattern": row["pattern"],
        "contraindicationTags": list(row["contraindicationTags"]),
        "quiet": row["quiet"],
        "floorOnly": row["floorOnly"],
        "videoFile": clips[0]["file"],
        "thumbFile": row["poster"]["file"],
        "angleVideoFile": clips[1]["file"] if len(clips) > 1 else "",
        "primaryMuscles": list(row["primaryMuscles"]),
        "secondaryMuscles": list(row["secondaryMuscles"]),
        "bodyRegion": row["bodyRegion"],
        "place": row["place"],
        "level": row["level"],
        "kind": row["kind"],
    }


def library_row(row, sizes) -> dict:
    out = {
        "id": row["exerciseId"],
        "nameEn": row["name_en"],
        "nameAr": row["name_ar"],
        "kind": row["kind"],
        "primaryMuscles": list(row["primaryMuscles"]),
        "secondaryMuscles": list(row["secondaryMuscles"]),
        "bodyRegion": row["bodyRegion"],
        "pattern": row["pattern"],
        "equipment": list(row["equipment"]),
        "place": row["place"],
        "level": row["level"],
        "quiet": row["quiet"],
        "floorOnly": row["floorOnly"],
        "tags": list(row["contraindicationTags"]),
    }
    if row.get("setup_en") is not None:
        out["setupEn"] = row["setup_en"]
        out["setupAr"] = row["setup_ar"]
    out["clips"] = [
        {
            "file": clip["file"],
            "angle": clip["angle"],
            "bytes": sizes[clip["file"]],
            "seconds": round(float(clip["seconds"]), 2),
        }
        for clip in row["clips"]
    ]
    out["poster"] = {"file": row["poster"]["file"], "bytes": sizes[row["poster"]["file"]]}
    return out


def library_document(rows, sizes, version: int) -> dict:
    return {
        "version": version,
        "schema": CONTRACT["schema"],
        "exercises": [library_row(row, sizes) for row in rows],
    }


def document_bytes(document) -> int:
    return len(json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def _get(db, path):
    snapshot = db.collection(path[0]).document(path[1]).get()
    return snapshot.to_dict() if getattr(snapshot, "exists", False) else None


def next_version(db) -> int:
    meta = _get(db, VERSION_DOC)
    library = _get(db, LIBRARY_DOC)
    current = int((meta or {}).get("version") or 0)
    if library is not None and int(library.get("version") or 0) != current:
        raise LibraryRefused(
            f"meta/exercises says version {current} but meta/exerciseLibrary holds "
            f"{library.get('version')}; fix that by hand before publishing again"
        )
    return current + 1


def _diff(live, new) -> list[str]:
    return sorted(k for k in set(live) | set(new) if live.get(k) != new.get(k))


def main(
    argv=None,
    *,
    clients: Optional[Callable] = None,
    require_adc: Optional[Callable] = None,
    read: Callable[[str], str] = lambda p: Path(p).read_text(encoding="utf-8"),
    out=print,
) -> int:
    parser = argparse.ArgumentParser(prog="publish_exercise_library")
    parser.add_argument("catalogue")
    parser.add_argument("--write", action="store_true", help="commit; without it nothing is written")
    args = parser.parse_args(argv)

    try:
        catalogue = json.loads(read(args.catalogue))
    except (OSError, ValueError):
        out("refused: the catalogue could not be read as JSON")
        return 2
    problems = validate(catalogue)
    if problems:
        for problem in problems:
            out(f"refused: {problem}")
        return 2
    rows = catalogue["exercises"]
    if len(rows) + 2 > LIMITS["maxBatchWrites"]:
        out(f"refused: {len(rows) + 2} writes is more than one batch of {LIMITS['maxBatchWrites']}")
        return 2

    (require_adc or _require_adc)()
    bucket, db = (clients or _clients)()

    sizes, problems = check_media(rows, bucket=bucket, db=db)
    if problems:
        for problem in problems:
            out(f"refused: {problem}")
        return 2
    try:
        version = next_version(db)
    except LibraryRefused as refused:
        out(f"refused: {refused}")
        return 2
    library = library_document(rows, sizes, version)
    size = document_bytes(library)
    if size > LIMITS["maxDocumentBytes"]:
        out(f"refused: the library is {size} bytes, over {LIMITS['maxDocumentBytes']}")
        return 2

    documents = {row["exerciseId"]: exercise_document(row) for row in rows}
    for rid, document in documents.items():
        live = _get(db, (COLLECTION, rid))
        if live is None:
            out(f"new      exercises/{rid}")
        elif _diff(live, document):
            out(f"replaces exercises/{rid}: {', '.join(_diff(live, document))}")
        else:
            out(f"same     exercises/{rid}")
    left_alone = sorted(
        snapshot.id
        for snapshot in db.collection(COLLECTION).stream()
        if snapshot.id not in documents
    )
    if left_alone:
        out(f"left alone (not in the catalogue): {', '.join(left_alone)}")
    hidden = [row["exerciseId"] for row in rows if PREGNANCY_FLOOR & set(row["contraindicationTags"])]
    out(f"hidden while pregnant or in the first weeks after a birth: {len(hidden)} of {len(rows)}")
    if hidden:
        out(f"  {', '.join(hidden)}")
    out(f"safety tags: {catalogue['tagsReview']}")
    for row in rows:
        tags = ", ".join(row["contraindicationTags"]) or "none"
        out(f"  {row['exerciseId']}: {tags}")
    out(f"version {version - 1} -> {version}; library {size} bytes ({size * 100 // (1024 * 1024)}% of 1 MiB)")

    if not args.write:
        out("dry run: nothing written. Run again with --write to publish.")
        return 0

    batch = db.batch()
    for rid, document in documents.items():
        batch.set(db.collection(COLLECTION).document(rid), document)
    batch.set(db.collection(LIBRARY_DOC[0]).document(LIBRARY_DOC[1]), library)
    batch.set(db.collection(VERSION_DOC[0]).document(VERSION_DOC[1]), {"version": version})
    batch.commit()
    out(f"published version {version}: {len(documents)} exercises")
    return 0


if __name__ == "__main__":
    sys.exit(main())
