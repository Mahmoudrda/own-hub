"""An in-memory Firestore whose WRITE SEMANTICS come from the real SDK.

Hand-written fakes get merge semantics wrong in the same way the code under test
does, so this one does not interpret `set(..., merge=...)` or `update()` itself.
Every write is turned into Write protos by google-cloud-firestore's own
builders (`_helpers.pbs_for_set_with_merge`, `pbs_for_set_no_merge`,
`pbs_for_update`), exactly what the client would send, and then applied the
way the server applies a Write: with an update mask, each masked path is set
from the payload or deleted when the payload does not carry it; with no mask,
the document is replaced; transforms (Increment, SERVER_TIMESTAMP, ArrayUnion)
run after. So `merge=True` on a nested map leaf-merges here exactly as it does
in production.

Transactions buffer their writes and apply them on commit. Patch
`firestore.transactional` with `transactional` below so the store's
`@firestore.transactional` functions run against this fake.
"""

from __future__ import annotations

import datetime as dt
from typing import Any, Optional

from google.cloud.firestore_v1 import _helpers, field_path as fp

PREFIX = "projects/own-hub/databases/(default)/documents/"
_MISSING = object()


class NotFound(Exception):
    pass


def _get_path(data: dict, parts: list[str]):
    current: Any = data
    for part in parts:
        if not isinstance(current, dict) or part not in current:
            return _MISSING
        current = current[part]
    return current


def _set_path(data: dict, parts: list[str], value) -> None:
    current = data
    for part in parts[:-1]:
        nxt = current.get(part)
        if not isinstance(nxt, dict):
            nxt = {}
            current[part] = nxt
        current = nxt
    current[parts[-1]] = value


def _delete_path(data: dict, parts: list[str]) -> None:
    current = data
    for part in parts[:-1]:
        current = current.get(part)
        if not isinstance(current, dict):
            return
    current.pop(parts[-1], None)


class Snapshot:
    def __init__(self, reference, data: Optional[dict]):
        self.reference = reference
        self.id = reference.id
        self.exists = data is not None
        self._data = data

    def to_dict(self):
        import copy

        return copy.deepcopy(self._data) if self._data is not None else None

    def get(self, key):
        return (self._data or {}).get(key)


class FakeFirestore:
    def __init__(self):
        self.docs: dict[str, dict] = {}
        self.now = dt.datetime(2026, 10, 2, 12, tzinfo=dt.timezone.utc)

    # navigation
    def collection(self, name):
        return CollectionRef(self, name)

    def transaction(self):
        return Transaction(self)

    def get_all(self, refs):
        for ref in refs:
            yield ref.get()

    def recursive_delete(self, reference):
        prefix = reference.path
        for path in list(self.docs):
            if path == prefix or path.startswith(prefix + "/"):
                del self.docs[path]

    # the server side of a Write
    def apply(self, write) -> None:
        if "delete" in write:
            self.docs.pop(write.delete[len(PREFIX):], None)
            return
        path = write.update.name[len(PREFIX):]
        exists = path in self.docs
        if "current_document" in write and write.current_document.exists and not exists:
            raise NotFound(path)
        fields = _helpers.decode_dict(write.update.fields, None)
        if "update_mask" in write:
            doc = self.docs.get(path, {})
            for raw in write.update_mask.field_paths:
                parts = fp.split_field_path(raw)
                parts = [fp.parse_field_path(p)[0] if p.startswith("`") else p for p in parts]
                value = _get_path(fields, parts)
                if value is _MISSING:
                    _delete_path(doc, parts)
                else:
                    _set_path(doc, parts, value)
        else:
            doc = fields
        for transform in write.update_transforms:
            parts = fp.split_field_path(transform.field_path)
            kind = transform._pb.WhichOneof("transform_type")
            current = _get_path(doc, parts)
            if kind == "set_to_server_value":
                _set_path(doc, parts, self.now)
            elif kind == "increment":
                step = _helpers.decode_value(transform.increment, None)
                base = current if isinstance(current, (int, float)) else 0
                _set_path(doc, parts, base + step)
            elif kind == "append_missing_elements":
                items = list(current) if isinstance(current, list) else []
                for value in transform.append_missing_elements.values:
                    item = _helpers.decode_value(value, None)
                    if item not in items:
                        items.append(item)
                _set_path(doc, parts, items)
            elif kind == "remove_all_from_array":
                remove = [
                    _helpers.decode_value(v, None)
                    for v in transform.remove_all_from_array.values
                ]
                items = [i for i in (current if isinstance(current, list) else []) if i not in remove]
                _set_path(doc, parts, items)
            else:  # pragma: no cover
                raise NotImplementedError(kind)
        self.docs[path] = doc

    def writes_for_set(self, path, data, merge):
        name = PREFIX + path
        if merge:
            return _helpers.pbs_for_set_with_merge(name, data, merge=merge)
        return _helpers.pbs_for_set_no_merge(name, data)

    def writes_for_update(self, path, data):
        return _helpers.pbs_for_update(PREFIX + path, data, None)


class CollectionRef:
    def __init__(self, db, path, filters=(), order=None, limit_n=None):
        self.db, self.path = db, path
        self.id = path.rsplit("/", 1)[-1]
        self._filters, self._order, self._limit = list(filters), order, limit_n

    def document(self, doc_id=None):
        if doc_id is None:
            import uuid

            doc_id = uuid.uuid4().hex[:20]
        return DocumentRef(self.db, f"{self.path}/{doc_id}")

    def add(self, data):
        ref = self.document()
        ref.set(data)
        return None, ref

    def where(self, field, op=None, value=None, *, filter=None):
        return CollectionRef(
            self.db, self.path, self._filters + [(field, op, value)], self._order, self._limit
        )

    def order_by(self, field, **_):
        return CollectionRef(self.db, self.path, self._filters, field, self._limit)

    def limit(self, n):
        return CollectionRef(self.db, self.path, self._filters, self._order, n)

    def _matches(self, data):
        for field, op, value in self._filters:
            have = _get_path(data, field.split("."))
            if have is _MISSING:
                return False
            if op == "==" and have != value:
                return False
            if op == "<" and not (have is not None and have < value):
                return False
            if op == "<=" and not (have is not None and have <= value):
                return False
            if op == "in" and have not in value:
                return False
        return True

    def stream(self, transaction=None):
        depth = self.path.count("/") + 1
        rows = []
        for path, data in sorted(self.db.docs.items()):
            if path.startswith(self.path + "/") and path.count("/") == depth:
                if self._matches(data):
                    rows.append(Snapshot(DocumentRef(self.db, path), data))
        if self._order:
            rows.sort(key=lambda s: str(s.get(self._order)))
        if self._limit is not None:
            rows = rows[: self._limit]
        return iter(rows)

    def get(self, transaction=None):
        return list(self.stream())


class DocumentRef:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.id = path.rsplit("/", 1)[-1]

    def collection(self, name):
        return CollectionRef(self.db, f"{self.path}/{name}")

    def get(self, transaction=None):
        if transaction is not None:
            transaction.reads += 1
            assert not transaction.writes, "Firestore transactions read before they write"
        return Snapshot(self, self.db.docs.get(self.path))

    def set(self, data, merge=False):
        for write in self.db.writes_for_set(self.path, data, merge):
            self.db.apply(write)

    def update(self, data):
        for write in self.db.writes_for_update(self.path, data):
            self.db.apply(write)

    def delete(self):
        self.db.docs.pop(self.path, None)


class Transaction:
    def __init__(self, db):
        self.db = db
        self.writes: list = []
        self.reads = 0
        self.committed = False

    def set(self, reference, data, merge=False):
        self.writes.extend(self.db.writes_for_set(reference.path, data, merge))

    def update(self, reference, data):
        self.writes.extend(self.db.writes_for_update(reference.path, data))

    def delete(self, reference):
        from google.cloud.firestore_v1.types import write as write_pb

        self.writes.append(write_pb.Write(delete=PREFIX + reference.path))

    def commit(self):
        for write in self.writes:
            self.db.apply(write)
        self.committed = True


def transactional(fn):
    """Stand-in for firestore.transactional: run once, commit, return."""

    def run(transaction, *args, **kwargs):
        result = fn(transaction, *args, **kwargs)
        transaction.commit()
        return result

    return run
