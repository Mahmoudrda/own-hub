"""tools/publish_exercise_library.py: the only way the member exercise library
changes (D42).

It must refuse a catalogue the contract would refuse, refuse a file that was
not uploaded or is not the file the catalogue recorded, write nothing on a dry
run, and on --write commit the console's exercises, the member library and its
version in one batch, with exactly the columns the console reads.
"""

from __future__ import annotations

import base64
import copy
import hashlib
import json
import re
from pathlib import Path

import pytest

from tools import publish_exercise_library as pel

ROOT = Path(__file__).resolve().parents[2]
CLIP = b"\x00\x00\x00\x18ftypmp42" + b"\x01" * 500
CLIP2 = b"\x00\x00\x00\x18ftypmp42" + b"\x02" * 400
POSTER = b"RIFF\x00\x00\x00\x00WEBP" + b"\x03" * 120


def _md5(data):
    return hashlib.md5(data).hexdigest()


def _row(rid="glute_bridge", **over):
    row = {
        "exerciseId": rid,
        "name_en": "Glute bridge",
        "name_ar": "جلوت بريدج",
        "kind": "strength",
        "primaryMuscles": ["glutes"],
        "secondaryMuscles": ["hamstrings"],
        "bodyRegion": "lower_body",
        "pattern": "hip_thrust_bridge",
        "equipment": ["mat"],
        "place": "both",
        "level": "beginner",
        "quiet": True,
        "floorOnly": True,
        "contraindicationTags": ["supine_load"],
        "clips": [
            {"file": f"{rid}_front_aaaa1111.mp4", "angle": "front", "seconds": 6.2, "source": "IMG_1.mov", "md5": _md5(CLIP)},
            {"file": f"{rid}_side_bbbb2222.mp4", "angle": "side", "seconds": 5.0, "source": "IMG_2.mov", "md5": _md5(CLIP2)},
        ],
        "poster": {"file": f"{rid}_aaaa1111.webp", "md5": _md5(POSTER)},
    }
    row.update(over)
    return row


def _catalogue(*rows):
    return {"tagsReview": "pending coach review", "exercises": list(rows) or [_row()]}


class FakeBlob:
    def __init__(self, data, content_type):
        self.size = len(data)
        self.content_type = content_type
        self.md5_hash = base64.b64encode(hashlib.md5(data).digest()).decode()


class FakeBucket:
    def __init__(self):
        self.blobs = {}

    def get_blob(self, path):
        return self.blobs.get(path)


class Snap:
    def __init__(self, doc_id, data):
        self.id, self._data = doc_id, data
        self.exists = data is not None

    def to_dict(self):
        return copy.deepcopy(self._data)


class FakeDb:
    def __init__(self):
        self.docs = {}
        self.commits = []

    def collection(self, name):
        db = self

        class _Doc:
            def __init__(self, doc_id):
                self.path = f"{name}/{doc_id}"
                self.id = doc_id

            def get(self):
                return Snap(self.id, db.docs.get(self.path))

        class _Col:
            def document(self, doc_id):
                return _Doc(doc_id)

            def stream(self):
                prefix = f"{name}/"
                return [Snap(k[len(prefix):], v) for k, v in db.docs.items() if k.startswith(prefix)]

        return _Col()

    def batch(self):
        db = self

        class _Batch:
            def __init__(self):
                self.writes = {}

            def set(self, ref, data):
                self.writes[ref.path] = data

            def commit(self):
                db.commits.append(dict(self.writes))
                db.docs.update(self.writes)

        return _Batch()


def _uploaded(bucket, db, row):
    rid = row["exerciseId"]
    files = [(row["clips"][0]["file"], CLIP, "video"), (row["poster"]["file"], POSTER, "picture")]
    if len(row["clips"]) > 1:
        files.append((row["clips"][1]["file"], CLIP2, "video"))
    for name, data, kind in files:
        path = f"content/exercises/{rid}/{name}"
        bucket.blobs[path] = FakeBlob(data, "video/mp4" if kind == "video" else "image/webp")
        db.docs[f"mediaLibrary/exercises__{rid}__{name}"] = {"path": path, "kind": kind, "bytes": len(data)}


def run(catalogue, argv=("cat.json",), *, upload=True, db=None, bucket=None):
    bucket = bucket or FakeBucket()
    db = db or FakeDb()
    if upload:
        for row in catalogue["exercises"]:
            _uploaded(bucket, db, row)
    lines = []
    code = pel.main(
        list(argv),
        clients=lambda: (bucket, db),
        require_adc=lambda: None,
        read=lambda path: json.dumps(catalogue),
        out=lines.append,
    )
    return code, bucket, db, lines


def test_a_dry_run_writes_nothing_and_says_what_would_change():
    code, _, db, lines = run(_catalogue())
    assert code == 0
    assert db.commits == []
    assert "new      exercises/glute_bridge" in lines
    assert "hidden while pregnant or in the first weeks after a birth: 1 of 1" in lines
    assert "  glute_bridge" in lines
    assert any(line.startswith("version 0 -> 1;") for line in lines)
    assert lines[-1].startswith("dry run")


def test_the_dry_run_lists_every_id_with_its_tags():
    plain = _row("plank", contraindicationTags=["high_impact"])
    code, _, _, lines = run(_catalogue(_row(), plain))
    assert code == 0
    assert "  glute_bridge: supine_load" in lines
    assert "  plank: high_impact" in lines


def test_write_commits_one_batch_with_both_meta_documents():
    code, _, db, lines = run(_catalogue(), argv=("cat.json", "--write"))
    assert code == 0
    assert len(db.commits) == 1
    writes = db.commits[0]
    assert set(writes) == {"exercises/glute_bridge", "meta/exerciseLibrary", "meta/exercises"}
    assert writes["meta/exercises"] == {"version": 1}
    library = writes["meta/exerciseLibrary"]
    assert library["version"] == 1 and library["schema"] == 1
    row = library["exercises"][0]
    assert row["clips"][0] == {"file": "glute_bridge_front_aaaa1111.mp4", "angle": "front", "bytes": len(CLIP), "seconds": 6.2}
    assert row["poster"] == {"file": "glute_bridge_aaaa1111.webp", "bytes": len(POSTER)}
    assert row["tags"] == ["supine_load"]
    assert "setupEn" not in row
    exercise = writes["exercises/glute_bridge"]
    assert exercise["videoFile"] == "glute_bridge_front_aaaa1111.mp4"
    assert exercise["angleVideoFile"] == "glute_bridge_side_bbbb2222.mp4"
    assert exercise["thumbFile"] == "glute_bridge_aaaa1111.webp"
    assert lines[-1] == "published version 1: 1 exercises"


def test_the_next_publish_moves_the_version_on():
    db = FakeDb()
    run(_catalogue(), argv=("cat.json", "--write"), db=db)
    code, _, db, _ = run(_catalogue(), argv=("cat.json", "--write"), db=db)
    assert code == 0
    assert db.docs["meta/exercises"] == {"version": 2}
    assert db.docs["meta/exerciseLibrary"]["version"] == 2


def test_meta_documents_that_disagree_are_refused():
    db = FakeDb()
    db.docs["meta/exercises"] = {"version": 4}
    db.docs["meta/exerciseLibrary"] = {"version": 3, "exercises": []}
    code, _, db, lines = run(_catalogue(), argv=("cat.json", "--write"), db=db)
    assert code == 2 and db.commits == []
    assert "version 4" in lines[0]


def _console_columns():
    source = (ROOT / "app/lib/features/admin/domain/content_schema.dart").read_text(encoding="utf-8")
    block = source[source.index("static const ContentSchema _exercises"):source.index("static const ContentSchema _foods")]
    return re.findall(r"ContentColumn\(\s*'(\w+)'", block)


def test_an_exercise_document_holds_exactly_the_console_columns():
    assert list(pel.exercise_document(_row())) == _console_columns()


def test_the_member_rows_match_the_contract_sample():
    sample = json.loads((ROOT / "contracts/exercise_library_sample.json").read_text(encoding="utf-8"))
    built = pel.library_row(
        _row(setup_en="Feet flat.", setup_ar="رجليكي على الأرض."),
        {name: 1 for name in ("glute_bridge_front_aaaa1111.mp4", "glute_bridge_side_bbbb2222.mp4", "glute_bridge_aaaa1111.webp")},
    )
    for row in sample["exercises"]:
        assert set(row) <= set(built), row["id"]
        assert set(row["clips"][0]) == set(built["clips"][0])
        assert set(row["poster"]) == set(built["poster"])


def test_the_pregnancy_floor_is_the_apps():
    source = (ROOT / "app/lib/domain/safety/life_stage_safety_policy.dart").read_text(encoding="utf-8")
    block = source[source.index("pregnancyAndEarlyPostpartumFloor = {"):]
    block = block[: block.index("};")]
    camel = re.findall(r"ContraindicationTag\.(\w+)", block)
    snake = {re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower() for name in camel}
    assert snake == pel.PREGNANCY_FLOOR


@pytest.mark.parametrize(
    "change, reason",
    [
        (lambda c: c.pop("tagsReview"), "tagsReview"),
        (lambda c: c["exercises"][0].update(exerciseId="Glute Bridge"), "exerciseId must match"),
        (lambda c: c["exercises"][0].update(name_ar=""), "name_ar is empty"),
        (lambda c: c["exercises"][0].update(primaryMuscles=["traps"]), "unknown 'traps'"),
        (lambda c: c["exercises"][0].update(primaryMuscles=[]), "primaryMuscles is empty"),
        (lambda c: c["exercises"][0].update(secondaryMuscles=["glutes"]), "both primary and secondary"),
        (lambda c: c["exercises"][0].update(equipment=["none", "mat"]), "'none' cannot sit"),
        (lambda c: c["exercises"][0].update(contraindicationTags=[]), "contraindicationTags is empty"),
        (lambda c: c["exercises"][0].update(contraindicationTags=["none", "supine_load"]), "tag 'none'"),
        (lambda c: c["exercises"][0].update(contraindicationTags=["bad_knees"]), "unknown 'bad_knees'"),
        (lambda c: c["exercises"][0].update(quiet="yes"), "quiet must be true or false"),
        (lambda c: c["exercises"][0].update(setup_en="Feet flat."), "both languages or neither"),
        (lambda c: c["exercises"][0].update(kind="stretch"), "a stretch is a mobility move"),
        (lambda c: c["exercises"][0].update(place="home"), "place 'home'"),
        (lambda c: c["exercises"][0]["clips"].append(dict(c["exercises"][0]["clips"][0], file="x_rear.mp4", angle="rear")), "one or 2 clips"),
        (lambda c: c["exercises"][0]["clips"][1].update(angle="front"), "same angle"),
        (lambda c: c["exercises"][0]["clips"][0].update(file="../x.mp4"), "clip file"),
        (lambda c: c["exercises"][0]["clips"][0].update(seconds=0.5), "at least 0.9 s"),
        (lambda c: c["exercises"][0]["poster"].update(file="poster.jpg"), "poster file"),
        (lambda c: c["exercises"][0].update(colour="red"), "unknown keys"),
        (lambda c: c["exercises"].append(_row()), "used twice"),
        (lambda c: c["exercises"][0].update(name_en="Glute bridge \u2014 floor"), "has a dash"),
    ],
)
def test_a_bad_catalogue_is_refused_and_nothing_is_touched(change, reason):
    catalogue = _catalogue()
    change(catalogue)
    code, _, db, lines = run(catalogue, argv=("cat.json", "--write"), upload=False)
    assert code == 2
    assert db.commits == [] and db.docs == {}
    assert any(reason in line for line in lines), lines


def test_a_file_that_was_never_uploaded_is_refused():
    catalogue = _catalogue()
    bucket, db = FakeBucket(), FakeDb()
    _uploaded(bucket, db, catalogue["exercises"][0])
    del db.docs["mediaLibrary/exercises__glute_bridge__glute_bridge_aaaa1111.webp"]
    code, _, db, lines = run(catalogue, argv=("cat.json", "--write"), upload=False, db=db, bucket=bucket)
    assert code == 2 and db.commits == []
    assert any("never uploaded" in line for line in lines)


def test_a_file_that_is_not_the_one_recorded_is_refused():
    catalogue = _catalogue()
    bucket, db = FakeBucket(), FakeDb()
    _uploaded(bucket, db, catalogue["exercises"][0])
    bucket.blobs["content/exercises/glute_bridge/glute_bridge_front_aaaa1111.mp4"] = FakeBlob(CLIP2, "video/mp4")
    db.docs["mediaLibrary/exercises__glute_bridge__glute_bridge_front_aaaa1111.mp4"]["bytes"] = len(CLIP2)
    code, _, db, lines = run(catalogue, argv=("cat.json", "--write"), upload=False, db=db, bucket=bucket)
    assert code == 2 and db.commits == []
    assert any("(md5)" in line for line in lines)


def test_a_missing_object_or_wrong_type_is_refused():
    catalogue = _catalogue()
    bucket, db = FakeBucket(), FakeDb()
    _uploaded(bucket, db, catalogue["exercises"][0])
    del bucket.blobs["content/exercises/glute_bridge/glute_bridge_side_bbbb2222.mp4"]
    bucket.blobs["content/exercises/glute_bridge/glute_bridge_aaaa1111.webp"].content_type = "image/jpeg"
    code, _, db, lines = run(catalogue, argv=("cat.json", "--write"), upload=False, db=db, bucket=bucket)
    assert code == 2 and db.commits == []
    assert any("not in the bucket" in line for line in lines)
    assert any("image/jpeg" in line for line in lines)


def test_a_library_over_the_ceiling_is_refused(monkeypatch):
    monkeypatch.setitem(pel.LIMITS, "maxDocumentBytes", 100)
    code, _, db, lines = run(_catalogue(), argv=("cat.json", "--write"))
    assert code == 2 and db.commits == []
    assert "over 100" in lines[-1]


def test_exercises_not_in_the_catalogue_are_listed_and_left_alone():
    db = FakeDb()
    db.docs["exercises/old_move"] = {"exerciseId": "old_move"}
    code, _, db, lines = run(_catalogue(), argv=("cat.json", "--write"), db=db)
    assert code == 0
    assert "left alone (not in the catalogue): old_move" in lines
    assert db.docs["exercises/old_move"] == {"exerciseId": "old_move"}


def test_no_credentials_refuses_before_anything_is_read():
    def no_adc():
        raise SystemExit("refused: no Application Default Credentials.")

    with pytest.raises(SystemExit):
        pel.main(["cat.json"], require_adc=no_adc, read=lambda p: json.dumps(_catalogue()), out=lambda line: None)
