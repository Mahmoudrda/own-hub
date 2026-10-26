"""The personal bucket in memory, for the coaching modules (coaching.common.Blobs)."""

from __future__ import annotations


class FakeBlobs:
    def __init__(self, objects: dict | None = None):
        self.objects: dict[str, tuple[bytes, str]] = dict(objects or {})
        self.deleted: list[str] = []
        self.locked: list[str] = []

    def put(self, path: str, data: bytes = b"x", content_type: str = "image/jpeg") -> None:
        self.objects[path] = (data, content_type)

    def exists(self, path: str) -> bool:
        return path in self.objects

    def info(self, path: str):
        if path not in self.objects:
            return None
        data, content_type = self.objects[path]
        return len(data), content_type

    def read(self, path: str) -> bytes:
        return self.objects[path][0]

    def write(self, path: str, data: bytes, content_type: str) -> None:
        self.objects[path] = (data, content_type)

    def delete(self, path: str) -> None:
        self.objects.pop(path, None)
        self.deleted.append(path)

    def lock(self, path: str) -> None:
        self.locked.append(path)
