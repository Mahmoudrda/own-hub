"""A 64-bit difference hash of a payment screenshot, to spot the same picture
sent twice even after it was cropped or recompressed.

The picture is shrunk to 9 x 8 grey pixels; each bit says whether a pixel is
brighter than its left neighbour. Two screenshots of one transfer land a few
bits apart, two different ones land about 32 apart.

Decoding goes through the one place OpenCV is loaded. The bytes passed in were
already re-encoded by the caller, so they are known to be a small JPEG.
"""

from __future__ import annotations

import numpy as np

from identity import faces

WIDTH = 9
HEIGHT = 8


def dhash(data: bytes) -> int:
    cv2 = faces.cv2
    image = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
    if image is None or image.size == 0:
        raise ValueError("not an image")
    small = cv2.resize(image, (WIDTH, HEIGHT), interpolation=cv2.INTER_AREA)
    value = 0
    for row in small:
        for x in range(WIDTH - 1):
            value = (value << 1) | int(row[x + 1] > row[x])
    return value


def hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def to_text(value: int) -> str:
    """How it is stored: 16 hex digits, because Firestore integers are signed."""
    return format(value, "016x")


def from_text(text: str) -> int:
    return int(text, 16)
