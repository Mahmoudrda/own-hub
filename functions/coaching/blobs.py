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

    def info(self, path: str):
        """(size in bytes, content type) of a file, or None when it is not there."""
        try:
            blob = self._bucket.blob(path)
            blob.reload()
            return int(blob.size or 0), blob.content_type or ""
        except Exception:
            return None

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

    def list_files(self, prefix: str):
        """(name, created) of every file under `prefix`, lazily, a page at a time."""
        for blob in self._bucket.list_blobs(prefix=prefix):
            yield blob.name, blob.time_created

    def lock(self, path: str) -> None:
        """Marks a coach's file as evidence: storage rules then refuse to let her
        delete or replace it. Removing the portfolio item deletes it from here."""
        blob = self._bucket.blob(path)
        blob.metadata = {"locked": "true"}
        blob.patch()
