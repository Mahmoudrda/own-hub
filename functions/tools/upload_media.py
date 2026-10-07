"""OWNER'S TOOL ONLY: put a picture or a clip into the content library.

The member app asks for one permission, the camera, and never the photo
library. So pictures for recipes, events and exercises are not picked on a
phone: they are uploaded from the owner's computer with this tool, on owner
credentials, the same way tools/grant_admin.py sets the admin claim.

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.upload_media \\
        --collection recipes --doc om_ali ~/Pictures/om-ali.jpg

app/tool/admin_access.sh upload-media wraps it.

What it does, in order, and refuses at the first step that fails:

  1. The type, by extension AND by the file's own first bytes: jpg, png, webp
     or mp4. A file whose bytes do not match its name is refused.
  2. The size, under the limit storage.library.rules sets for content/
     (200 MB), and a picture under MAX_PIXELS.
  3. A picture is re-encoded as WebP with its longest side at most MAX_SIDE
     pixels (OpenCV, already in this virtualenv; nothing new is installed and
     nothing here is deployed). A clip is uploaded as it is.
  4. Upload to the content bucket at content/{collection}/{doc}/{file}, the one
     path the rules let an admin write and a signed-in member read, cached by
     phones for a year.
  5. A line in Firestore mediaLibrary/{collection}__{doc}__{file}, which is how
     the console's media library (Z10) lists it, and how Z12, Z18 and Z03 offer
     it to be chosen.

The `doc` is the recipe id, the event id or the exercise id the file belongs
to: a recipe's photo must be uploaded under that recipe's id.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
from dataclasses import dataclass
from typing import Callable, Optional

CONTENT_BUCKET = "own-hub.firebasestorage.app"
REGISTRY = "mediaLibrary"
COLLECTIONS = ("exercises", "foods", "recipes", "programs", "events")

MAX_BYTES = 200 * 1024 * 1024 - 1
"""storage.library.rules: request.resource.size < 200 * 1024 * 1024."""

MAX_SIDE = 1600
"""The longest side of a stored picture. A phone draws it at most screen-wide."""

MAX_PIXELS = 50_000_000
WEBP_QUALITY = 82
CACHE_CONTROL = "public, max-age=31536000"

_DOC = re.compile(r"^[A-Za-z0-9_-]{1,100}$")

IMAGE_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}
VIDEO_TYPES = {".mp4": "video/mp4"}


class MediaRefused(ValueError):
    """Why a file was not uploaded. Always a short reason, never the file."""


@dataclass(frozen=True)
class Prepared:
    name: str
    data: bytes
    content_type: str
    kind: str  # "picture" or "video", as the console's MediaKind names them


def _sniff(data: bytes) -> Optional[str]:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data[4:8] == b"ftyp":
        return "video/mp4"
    return None


def safe_name(filename: str) -> str:
    """Lower case letters, digits, `_`, `-` and one extension. Never a path."""
    base = os.path.basename(filename).lower()
    stem, ext = os.path.splitext(base)
    stem = re.sub(r"[^a-z0-9_-]+", "_", stem).strip("_-")[:80]
    if not stem:
        raise MediaRefused("the file name has nothing usable in it")
    return stem + ext


def _to_webp(data: bytes) -> bytes:
    import cv2
    import numpy as np

    image = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise MediaRefused("the picture could not be read")
    height, width = image.shape[:2]
    if height * width > MAX_PIXELS:
        raise MediaRefused("the picture is too large")
    longest = max(height, width)
    if longest > MAX_SIDE:
        scale = MAX_SIDE / longest
        image = cv2.resize(
            image,
            (max(1, round(width * scale)), max(1, round(height * scale))),
            interpolation=cv2.INTER_AREA,
        )
    ok, encoded = cv2.imencode(".webp", image, [cv2.IMWRITE_WEBP_QUALITY, WEBP_QUALITY])
    if not ok:
        raise MediaRefused("the picture could not be converted")
    return encoded.tobytes()


def prepare(filename: str, data: bytes, *, convert: bool = True) -> Prepared:
    """Checks one file and, for a picture, converts it. Raises MediaRefused."""
    name = safe_name(filename)
    stem, ext = os.path.splitext(name)
    expected = IMAGE_TYPES.get(ext) or VIDEO_TYPES.get(ext)
    if expected is None:
        raise MediaRefused("only jpg, png, webp and mp4 are accepted")
    if not data:
        raise MediaRefused("the file is empty")
    if len(data) > MAX_BYTES:
        raise MediaRefused("the file is over 200 MB")
    if _sniff(data) != expected:
        raise MediaRefused("the file's contents do not match its name")
    if ext in VIDEO_TYPES:
        return Prepared(name=name, data=data, content_type=expected, kind="video")
    if convert:
        return Prepared(
            name=stem + ".webp",
            data=_to_webp(data),
            content_type="image/webp",
            kind="picture",
        )
    return Prepared(name=name, data=data, content_type=expected, kind="picture")


def storage_path(collection: str, doc: str, name: str) -> str:
    if collection not in COLLECTIONS:
        raise MediaRefused(f"collection must be one of {', '.join(COLLECTIONS)}")
    if not _DOC.match(doc):
        raise MediaRefused("the document id may hold letters, digits, _ and - only")
    return f"content/{collection}/{doc}/{name}"


def registry_id(collection: str, doc: str, name: str) -> str:
    return f"{collection}__{doc}__{name}"


def upload(prepared: Prepared, collection: str, doc: str, *, bucket, db, now=None) -> str:
    """Stores the file and registers it. Returns its Storage path."""
    path = storage_path(collection, doc, prepared.name)
    blob = bucket.blob(path)
    blob.cache_control = CACHE_CONTROL
    blob.upload_from_string(prepared.data, content_type=prepared.content_type)
    db.collection(REGISTRY).document(registry_id(collection, doc, prepared.name)).set(
        {
            "collection": collection,
            "docId": doc,
            "name": prepared.name,
            "path": path,
            "kind": prepared.kind,
            "bytes": len(prepared.data),
            "contentType": prepared.content_type,
            "uploadedAt": now or dt.datetime.now(dt.timezone.utc),
        }
    )
    return path


def _require_adc() -> None:
    import google.auth

    try:
        google.auth.default()
    except Exception:
        raise SystemExit(
            "refused: no Application Default Credentials. This is the owner's "
            "tool; run `gcloud auth application-default login` as the owner."
        )


def _clients():
    import firebase_admin
    from firebase_admin import firestore, storage

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    return storage.bucket(CONTENT_BUCKET), firestore.client()


def main(
    argv=None,
    *,
    clients: Optional[Callable] = None,
    require_adc: Optional[Callable] = None,
    read: Callable[[str], bytes] = lambda p: open(p, "rb").read(),
    out=print,
) -> int:
    parser = argparse.ArgumentParser(prog="upload_media")
    parser.add_argument("--collection", required=True, choices=COLLECTIONS)
    parser.add_argument("--doc", required=True)
    parser.add_argument(
        "--keep-original",
        action="store_true",
        help="upload a picture as it is instead of converting it to WebP",
    )
    parser.add_argument("files", nargs="+")
    args = parser.parse_args(argv)

    # Everything is checked before anything is uploaded.
    try:
        storage_path(args.collection, args.doc, "x")
        prepared = [
            prepare(f, read(f), convert=not args.keep_original) for f in args.files
        ]
    except MediaRefused as refused:
        out(f"refused: {refused}")
        return 2
    except OSError:
        out("refused: a file could not be read")
        return 2

    (require_adc or _require_adc)()
    bucket, db = (clients or _clients)()
    for item in prepared:
        path = upload(item, args.collection, args.doc, bucket=bucket, db=db)
        out(f"uploaded {path} ({len(item.data)} bytes). Choose it as {item.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
