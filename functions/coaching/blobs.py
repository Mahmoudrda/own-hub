"""The personal bucket for the coaching modules (common.Blobs).

Coaching is the one part of the service that keeps files: a coach's application
documents, her published photo, and a transfer screenshot until staff decide
(DECISIONS D61). Nothing here returns a URL or an image to a caller.
"""

from __future__ import annotations


class PersonalBlobs:
    def __init__(self, bucket=None):
        if bucket is None:
            from firebase_admin import storage

            from account import deletion

            bucket = storage.bucket(deletion.PERSONAL_BUCKET)
        self._bucket = bucket

    def exists(self, path: str) -> bool:
        try:
            return self._bucket.blob(path).exists()
        except Exception:
            return False

    def read(self, path: str) -> bytes:
        return self._bucket.blob(path).download_as_bytes()

    def write(self, path: str, data: bytes, content_type: str) -> None:
        self._bucket.blob(path).upload_from_string(data, content_type=content_type)

    def delete(self, path: str) -> None:
        """Gone already counts as deleted."""
        try:
            self._bucket.blob(path).delete()
        except Exception as error:
            if type(error).__name__ != "NotFound":
                raise
