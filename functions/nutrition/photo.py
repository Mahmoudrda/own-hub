"""The meal photo, made safe to send: decoded, shrunk, re-encoded.

Decoding goes through identity.faces.decode, the one place OpenCV is loaded
(with its decode ceilings set first) and the one place an uploaded image is
turned into pixels: the header is checked before anything is decoded, so a
decompression bomb is refused without being expanded, exactly as for the ID
photos.

Re-encoding from pixels is what strips the metadata. cv2.imencode writes a
bare JFIF with no EXIF, so the GPS position, the time and the phone model a
camera records never leave this process. The decoder has already turned the
pixels upright from the EXIF orientation, so nothing is lost by dropping it.

Nothing here writes to disk or logs a byte of the image.
"""

from __future__ import annotations

from identity import faces, reasons

from . import config


class PhotoRejected(ValueError):
    """The bytes are not a usable photo. Carries a reason code."""

    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def reencode(raw: bytes) -> bytes:
    """Any phone photo to a JPEG at most IMAGE_LONG_SIDE on its long edge."""
    cv2 = faces.cv2
    try:
        image = faces.decode(raw)
    except faces.ImageRejected as rejected:
        raise PhotoRejected(rejected.code) from None
    if image is None or image.size == 0:
        raise PhotoRejected(reasons.IMAGE_UNDECODABLE)
    height, width = image.shape[:2]
    longest = max(height, width)
    if longest > config.IMAGE_LONG_SIDE:
        scale = config.IMAGE_LONG_SIDE / longest
        image = cv2.resize(
            image,
            (max(1, round(width * scale)), max(1, round(height * scale))),
            interpolation=cv2.INTER_AREA,
        )
    ok, encoded = cv2.imencode(
        ".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, config.JPEG_QUALITY]
    )
    if not ok:
        raise PhotoRejected(reasons.IMAGE_UNDECODABLE)
    return encoded.tobytes()
