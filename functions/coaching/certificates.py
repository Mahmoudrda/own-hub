"""K02: a coach's certificate photo, submitted for a woman reviewer to read.

The photo itself is uploaded by the app to `coach-docs/{uid}/` in the personal
bucket (storage.rules: hers only, an image or a PDF up to 10 MB, read by her and
an admin). This records that it is there and which credential it claims, at
`coaches/{uid}/certificates/{certificateId}`, a path no client may write: the
state can only be moved on by a reviewer through the Admin SDK, so a coach can
never mark her own certificate checked.

A credential is an id from a fixed list, never typed text (coach_credentials.dart
CredentialCatalogue.dictionaryBacked). A name outside the list is refused.
"""

from __future__ import annotations

import re
from typing import Callable

from . import errors

CREDENTIALS = frozenset({"nasm_cpt"})
"""The credentials a coach may claim. Mirrors the app's dictionary-backed
catalogue; adding one means adding it on both sides."""

MAX_CERTIFICATES = 10
"""More than any honest coach holds, and a ceiling on a write pump."""

_MEDIA = re.compile(
    r"^coach-docs/(?P<uid>[A-Za-z0-9]{1,128})/(?P<name>[A-Za-z0-9_-]{1,80})\.(?:jpg|jpeg|png|pdf)$"
)

FIELDS = ("credentialId", "mediaRef", "state", "submittedAt")
"""Every key a certificate record is born with, and nothing else."""


def certificate_id(media_ref: str) -> str:
    """The record's id: the file's own name, so a retry of the same upload
    lands on the same document."""
    return _MEDIA.match(media_ref).group("name")


def submit(
    db,
    uid: str,
    data: dict,
    *,
    verified: bool,
    live: bool,
    object_exists: Callable[[str], bool],
    timestamp,
) -> dict:
    if not live:
        raise errors.CoachingError(errors.PRECONDITION, errors.COACH_APP_CLOSED)
    if not verified:
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_VERIFIED)
    credential = data.get("credentialId")
    media_ref = data.get("mediaRef")
    if credential not in CREDENTIALS or not isinstance(media_ref, str):
        raise errors.CoachingError(errors.INVALID, errors.BAD_REQUEST)
    match = _MEDIA.match(media_ref)
    if match is None or match.group("uid") != uid:
        raise errors.CoachingError(errors.INVALID, errors.BAD_REQUEST)
    if not object_exists(media_ref):
        raise errors.CoachingError(errors.PRECONDITION, errors.CERTIFICATE_NOT_UPLOADED)

    certificates = db.collection("coaches").document(uid).collection("certificates")
    cert_id = certificate_id(media_ref)
    ref = certificates.document(cert_id)
    if ref.get().exists:
        return {"ok": True, "certificateId": cert_id, "state": "uploaded"}
    if len(list(certificates.stream())) >= MAX_CERTIFICATES:
        raise errors.CoachingError(errors.EXHAUSTED, errors.TOO_MANY_CERTIFICATES)
    record = {
        "credentialId": credential,
        "mediaRef": media_ref,
        "state": "uploaded",
        "submittedAt": timestamp,
    }
    assert set(record) <= set(FIELDS)
    ref.set(record)
    return {"ok": True, "certificateId": cert_id, "state": "uploaded"}
