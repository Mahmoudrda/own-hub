"""S6: the global kill-switch counter is sharded so one hot document cannot
contend, and the sum over the shards is what the limit is compared against."""

from __future__ import annotations

from identity import config, store


class _Snap:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return self._data


class _Doc:
    def __init__(self, db, doc_id):
        self.db, self.id = db, doc_id

    def set(self, payload, merge=False):
        self.db.sets.append((self.id, payload, merge))
        current = self.db.docs.setdefault(self.id, {})
        for key, value in payload.items():
            if type(value).__name__ == "Increment":
                current[key] = current.get(key, 0) + value.value
            else:
                current[key] = value


class _Col:
    def __init__(self, db):
        self.db = db

    def document(self, doc_id):
        return _Doc(self.db, doc_id)


class _Db:
    def __init__(self, docs):
        self.docs = docs
        self.sets = []
        self.read_ids = []

    def collection(self, name):
        assert name == config.COL_STATS
        return _Col(self)

    def get_all(self, refs):
        for ref in refs:
            self.read_ids.append(ref.id)
            yield _Snap(self.docs.get(ref.id))


def test_the_sum_is_over_every_shard_including_this_write(monkeypatch):
    day = store._today()
    docs = {f"{day}_s{i}": {"verifications": i} for i in range(config.DAILY_COUNTER_SHARDS)}
    db = _Db(docs)
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.random, "randrange", lambda n: 3)

    total = store.daily_count_and_increment(store.DAILY_VERIFY_FIELD)

    assert total == sum(range(config.DAILY_COUNTER_SHARDS)) + 1
    assert db.sets[0][0] == f"{day}_s3" and db.sets[0][2] is True
    assert sorted(db.read_ids) == sorted(f"{day}_s{i}" for i in range(config.DAILY_COUNTER_SHARDS))


def test_missing_shards_count_as_zero_and_fields_are_separate(monkeypatch):
    day = store._today()
    db = _Db({f"{day}_s0": {"sessions": 5}})
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.random, "randrange", lambda n: 7)
    assert store.daily_count_and_increment(store.DAILY_VERIFY_FIELD) == 1
    assert store.daily_count_and_increment("sessions") == 6


def test_shards_are_ten():
    assert config.DAILY_COUNTER_SHARDS == 10
