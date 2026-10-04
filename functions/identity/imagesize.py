"""Image dimensions from the header alone, before anything is decoded (T24).

A JPEG's byte size says nothing about how many pixels it holds: a file of a few
hundred bytes can declare 20000x20000 and make a decoder allocate 1.2 GB before
any check after decode gets a chance to run. This module reads only the header
fields that declare the size, so faces.decode can refuse a bomb before
cv2.imdecode is ever called.

Pure: no I/O, no decoding, no allocation beyond slicing the header. Only the
three formats a phone camera produces are recognised. Anything else returns
None and is treated as undecodable, so no buffer reaches a decoder unchecked.
"""

from __future__ import annotations

import struct
from typing import Optional, Tuple

from . import config, reasons

# SOFn markers that carry a frame header. C4 (DHT), C8 (JPG) and CC (DAC) share
# the range and are not frame headers.
_JPEG_SOF = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
# Markers with no length field.
_JPEG_STANDALONE = {0x01, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7}


def dimensions(data: bytes) -> Optional[Tuple[int, int]]:
    """(width, height) declared by a JPEG, PNG or WebP header, else None."""
    if not isinstance(data, (bytes, bytearray, memoryview)):
        return None
    data = bytes(data)
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        size = _png(data)
    elif data[:3] == b"\xff\xd8\xff":
        size = _jpeg(data)
    elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        size = _webp(data)
    else:
        size = None
    # A zero side (a JPEG deferring its height to a DNL marker, say) is not a
    # size that can be checked, so it is not one that may be decoded.
    if size is None or size[0] <= 0 or size[1] <= 0:
        return None
    return size


def refusal(data: bytes) -> Optional[str]:
    """The reason code to refuse these bytes with, or None if they may be decoded.

    image_too_large when the header declares more than config.MAX_PIXELS in
    total or more than config.MAX_IMAGE_SIDE on either side; image_undecodable
    when there is no JPEG, PNG or WebP header to read the size from.
    """
    size = dimensions(data)
    if size is None:
        return reasons.IMAGE_UNDECODABLE
    width, height = size
    if (
        width > config.MAX_IMAGE_SIDE
        or height > config.MAX_IMAGE_SIDE
        or width * height > config.MAX_PIXELS
    ):
        return reasons.IMAGE_TOO_LARGE
    return None


def _png(data: bytes) -> Optional[Tuple[int, int]]:
    # IHDR is required to be the first chunk.
    if len(data) < 24 or data[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def _jpeg(data: bytes) -> Optional[Tuple[int, int]]:
    """Walk the marker segments up to the first frame header.

    APPn segments (EXIF, with its own embedded thumbnail and that thumbnail's
    SOF) are skipped by their length, so the size read is the main frame's.
    """
    i = 2
    n = len(data)
    while i < n:
        if data[i] != 0xFF:
            return None
        # Fill bytes: any number of 0xFF may precede a marker.
        while i < n and data[i] == 0xFF:
            i += 1
        if i >= n:
            return None
        marker = data[i]
        i += 1
        if marker in _JPEG_STANDALONE:
            continue
        if marker in (0xD8, 0xD9, 0xDA):
            # A second SOI, the end, or scan data before any frame header.
            return None
        if i + 2 > n:
            return None
        (length,) = struct.unpack(">H", data[i : i + 2])
        if length < 2:
            return None
        if marker in _JPEG_SOF:
            if i + 7 > n:
                return None
            height, width = struct.unpack(">HH", data[i + 3 : i + 7])
            return width, height
        i += length
    return None


def _webp(data: bytes) -> Optional[Tuple[int, int]]:
    kind = data[12:16]
    if kind == b"VP8X" and len(data) >= 30:
        width = int.from_bytes(data[24:27], "little") + 1
        height = int.from_bytes(data[27:30], "little") + 1
        return width, height
    if kind == b"VP8L" and len(data) >= 25 and data[20] == 0x2F:
        bits = int.from_bytes(data[21:25], "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if kind == b"VP8 " and len(data) >= 30 and data[23:26] == b"\x9d\x01\x2a":
        width = int.from_bytes(data[26:28], "little") & 0x3FFF
        height = int.from_bytes(data[28:30], "little") & 0x3FFF
        return width, height
    return None
