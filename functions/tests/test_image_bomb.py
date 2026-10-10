"""T24: a decompression bomb is refused from its header, before any decode.

The pixel ceiling used to be checked AFTER cv2.imdecode, so a file of a few
hundred bytes that declares 20000x20000 pixels was allocated in full (1.2 GB of
BGR array) before it could be refused. These tests build exactly such files and
put a tripwire on cv2.imdecode: the refusal must happen without it ever being
reached.
"""

from __future__ import annotations

import base64
import os
import re
import struct
import subprocess
import sys
import zlib

import cv2
import numpy as np
import pytest
from firebase_functions import https_fn

import main
from identity import config, faces, imagesize, reasons
from tests.test_entrypoints import body, inner, request, stubbed  # noqa: F401

_FUNCTIONS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ------------------------------------------------------------- tiny bombs


def png_declaring(width: int, height: int) -> bytes:
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)

    def chunk(kind: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(kind + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", crc)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(b"\x00" * 64))
        + chunk(b"IEND", b"")
    )


def jpeg_declaring(width: int, height: int, *, app1: bytes = b"") -> bytes:
    out = b"\xff\xd8"
    if app1:
        out += b"\xff\xe1" + struct.pack(">H", len(app1) + 2) + app1
    sof = struct.pack(">BHHB", 8, height, width, 3) + b"\x01\x11\x00\x02\x11\x00\x03\x11\x00"
    out += b"\xff\xc0" + struct.pack(">H", len(sof) + 2) + sof
    return out + b"\xff\xd9"


def webp_vp8x_declaring(width: int, height: int) -> bytes:
    payload = b"\x00\x00\x00\x00" + (width - 1).to_bytes(3, "little") + (
        height - 1
    ).to_bytes(3, "little")
    chunk = b"VP8X" + struct.pack("<I", len(payload)) + payload
    return b"RIFF" + struct.pack("<I", 4 + len(chunk)) + b"WEBP" + chunk


BOMBS = {
    "png": png_declaring(20000, 20000),
    "jpeg": jpeg_declaring(20000, 20000),
    "webp": webp_vp8x_declaring(16000, 16000),
}


@pytest.fixture
def imdecode_tripwire(monkeypatch):
    calls = []

    def tripwire(*args, **kwargs):
        calls.append(1)
        raise AssertionError("cv2.imdecode was reached on an unchecked buffer")

    monkeypatch.setattr(faces.cv2, "imdecode", tripwire)
    return calls


# ------------------------------------------------------------ faces.decode


@pytest.mark.parametrize("kind", sorted(BOMBS))
def test_a_tiny_bomb_is_refused_without_decoding(kind, imdecode_tripwire):
    bomb = BOMBS[kind]
    assert len(bomb) < 200
    with pytest.raises(faces.ImageRejected) as caught:
        faces.decode(bomb)
    assert caught.value.code == reasons.IMAGE_TOO_LARGE
    assert imdecode_tripwire == []


def test_one_side_too_long_is_refused_even_under_the_pixel_ceiling(imdecode_tripwire):
    long_strip = png_declaring(config.MAX_IMAGE_SIDE + 1, 10)
    assert (config.MAX_IMAGE_SIDE + 1) * 10 < config.MAX_PIXELS
    with pytest.raises(faces.ImageRejected) as caught:
        faces.decode(long_strip)
    assert caught.value.code == reasons.IMAGE_TOO_LARGE
    assert imdecode_tripwire == []


def test_a_format_without_a_readable_header_is_never_decoded(imdecode_tripwire):
    # BMP, TIFF and anything else cv2 would happily decode: no header check,
    # no decode.
    for raw in (b"BM" + b"\x00" * 60, b"II*\x00" + b"\x00" * 60, b"\xff\xd8\xff"):
        with pytest.raises(faces.ImageRejected) as caught:
            faces.decode(raw)
        assert caught.value.code == reasons.IMAGE_UNDECODABLE
    assert imdecode_tripwire == []


def test_a_bomb_hidden_after_an_exif_thumbnail_is_still_read_correctly(imdecode_tripwire):
    # The EXIF block of a phone JPEG carries a thumbnail with its own SOF. The
    # parser must skip APPn segments by length and read the real frame header.
    decoy = jpeg_declaring(160, 120)
    bomb = jpeg_declaring(20000, 20000, app1=b"Exif\x00\x00" + decoy)
    assert imagesize.dimensions(bomb) == (20000, 20000)
    with pytest.raises(faces.ImageRejected):
        faces.decode(bomb)
    assert imdecode_tripwire == []


def test_a_decoder_refusal_maps_to_a_code(monkeypatch):
    def refuses(*args, **kwargs):
        raise cv2.error("validateInputImageSize")

    monkeypatch.setattr(faces.cv2, "imdecode", refuses)
    ok = cv2.imencode(".jpg", np.zeros((30, 40, 3), np.uint8))[1].tobytes()
    with pytest.raises(faces.ImageRejected) as caught:
        faces.decode(ok)
    assert caught.value.code == reasons.IMAGE_TOO_LARGE


# ----------------------------------------------------- real frames still pass


@pytest.mark.parametrize(
    "ext,params",
    [
        (".jpg", []),
        (".jpg", [cv2.IMWRITE_JPEG_PROGRESSIVE, 1]),
        (".png", []),
        (".webp", []),
        (".webp", [cv2.IMWRITE_WEBP_QUALITY, 101]),  # lossless, VP8L
    ],
)
def test_normal_frames_are_read_and_decoded(ext, params):
    image = np.full((480, 640, 3), 90, np.uint8)
    encoded = cv2.imencode(ext, image, params)[1].tobytes()
    assert imagesize.dimensions(encoded) == (640, 480)
    assert faces.decode(encoded).shape[:2] == (480, 640)


def test_a_full_size_phone_id_photo_still_passes():
    image = np.zeros((3000, 4000, 3), np.uint8)
    encoded = cv2.imencode(".jpg", image)[1].tobytes()
    assert imagesize.dimensions(encoded) == (4000, 3000)
    assert max(faces.decode(encoded).shape[:2]) == config.WORKING_LONG_EDGE


# ---------------------------------------------------- the callable's intake


def test_the_entry_point_refuses_a_bomb_with_invalid_argument():
    encoded = base64.b64encode(BOMBS["jpeg"]).decode()
    with pytest.raises(https_fn.HttpsError) as caught:
        main._decode_image(encoded, {})
    assert caught.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT
    assert caught.value.message == reasons.IMAGE_TOO_LARGE


def test_verify_identity_refuses_a_bomb_before_the_pipeline(stubbed):  # noqa: F811
    bomb = base64.b64encode(BOMBS["png"]).decode()
    with pytest.raises(https_fn.HttpsError) as caught:
        inner("verify_identity")(request(body(front=bomb)))
    assert caught.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT
    assert caught.value.message == reasons.IMAGE_TOO_LARGE


# --------------------------------------------------------- the second guard


def test_opencv_carries_its_own_ceiling_once_faces_is_imported():
    # OpenCV reads these once, when the library loads, so faces.py has to set
    # them before `import cv2`. Checked in a fresh interpreter, the way the
    # deployed code loads it: main.py no longer imports OpenCV at all (only the
    # two verification calls need it, through _deps()), and the moment the
    # verification wiring is imported the ceilings are already in place.
    script = (
        "import os, sys, main\n"
        "assert 'cv2' not in sys.modules, 'main imported OpenCV at load'\n"
        "from identity import providers_selfhosted\n"
        "assert 'cv2' in sys.modules\n"
        "print(os.environ['OPENCV_IO_MAX_IMAGE_PIXELS'], "
        "os.environ['OPENCV_IO_MAX_IMAGE_WIDTH'], "
        "os.environ['OPENCV_IO_MAX_IMAGE_HEIGHT'])\n"
    )
    env = {k: v for k, v in os.environ.items() if not k.startswith("OPENCV_IO_")}
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=_FUNCTIONS,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert result.returncode == 0, result.stderr[-2000:]
    pixels, width, height = result.stdout.split()
    assert int(pixels) == config.MAX_PIXELS
    assert int(width) == int(height) == config.MAX_IMAGE_SIDE


def test_only_faces_py_imports_opencv():
    # The ceilings above are set in faces.py, on the line before `import cv2`.
    # A second deployed module importing cv2 first would load it without them.
    # tools/ is the owner's local admin tooling, never deployed (firebase.json
    # ignores it) and never fed a member's upload.
    importers = []
    for root, _, files in os.walk(_FUNCTIONS):
        if any(part in root for part in ("/.venv", "/venv", "/tests", "/tools", "__pycache__")):
            continue
        for name in files:
            if not name.endswith(".py"):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
            if re.search(r"^\s*(import cv2|from cv2 )", text, re.M):
                importers.append(os.path.relpath(path, _FUNCTIONS))
    assert importers == [os.path.join("identity", "faces.py")]
