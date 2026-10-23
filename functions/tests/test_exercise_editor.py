import base64

from console import exercise_editor as ed


class Blob:
    def __init__(self, size, kind):
        self.size, self.content_type = size, kind
        self.md5_hash = base64.b64encode(bytes(range(16))).decode()


class Bucket:
    def __init__(self, blobs):
        self.blobs = blobs

    def get_blob(self, path):
        return self.blobs.get(path)


class Doc:
    def __init__(self, store, key):
        self.store, self.key = store, key

    def get(self):
        value = self.store.get(self.key)
        return type("S", (), {"exists": value is not None, "to_dict": lambda s: value, "id": self.key[1]})()

    def set(self, value):
        self.store[self.key] = value


class Db:
    def __init__(self):
        self.store = {}

    def collection(self, name):
        db = self
        return type("C", (), {"document": lambda s, i: Doc(db.store, (name, i))})()

    def batch(self):
        db = self
        pending = []
        return type("B", (), {
            "set": lambda s, ref, v: pending.append((ref, v)),
            "commit": lambda s: [r.set(v) for r, v in pending],
        })()


def body():
    return {
        "exerciseId": "test_move", "name_en": "Test move", "name_ar": "تمرين تجريبي", "kind": "strength",
        "primaryMuscles": ["glutes"], "secondaryMuscles": [], "bodyRegion": "lower_body",
        "pattern": "hinge", "equipment": ["none"], "place": "both", "level": "beginner",
        "quiet": True, "floorOnly": False, "contraindicationTags": ["high_impact"],
        "clips": [{"file": "test_move_front_a1b2c3d4.mp4", "angle": "front", "seconds": 5}],
        "poster": {"file": "test_move_a1b2c3d4.webp"},
    }


def bucket():
    return Bucket({
        "content/exercises/test_move/test_move_front_a1b2c3d4.mp4": Blob(200000, "video/mp4"),
        "content/exercises/test_move/test_move_a1b2c3d4.webp": Blob(20000, "image/webp"),
    })


def test_refuses_a_file_that_was_never_uploaded():
    result = ed.save(Db(), Bucket({}), body())
    assert result["ok"] is False and result["problems"]


def test_refuses_a_bad_row_and_writes_nothing():
    db, data = Db(), body()
    data["pattern"] = "not_a_pattern"
    assert ed.save(db, bucket(), data)["ok"] is False
    assert ("exercises", "test_move") not in db.store


def test_saves_one_exercise_and_bumps_the_version():
    db = Db()
    first = ed.save(db, bucket(), body())
    assert first == {"ok": True, "version": 1}, first
    assert db.store[("meta", "exercises")] == {"version": 1}
    assert [r["id"] for r in db.store[("meta", "exerciseLibrary")]["exercises"]] == ["test_move"]
    edited = body()
    edited["name_en"] = "Renamed"
    assert ed.save(db, bucket(), edited)["version"] == 2
    rows = db.store[("meta", "exerciseLibrary")]["exercises"]
    assert len(rows) == 1 and rows[0]["nameEn"] == "Renamed"


def test_deployed_contract_copy_matches_the_source():
    from pathlib import Path

    root = Path(__file__).resolve().parents[2]
    assert (root / "functions" / "exercise_library_contract.json").read_bytes() == (
        root / "contracts" / "exercise_library_contract.json"
    ).read_bytes()
