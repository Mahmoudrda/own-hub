"""tools/classify_exercise_videos.py: three passes per clip, the cache, and no
network. A fake client stands in for Vertex; the clips are tiny synthetic
videos made in a temp folder."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools import classify_exercise_videos as cev

ROW_A = {
    "exerciseId": "glute_bridge",
    "pattern": "hip_thrust_bridge",
    "primaryMuscles": ["glutes"],
    "secondaryMuscles": ["hamstrings"],
    "equipment": ["mat"],
    "level": "beginner",
    "clips": [{"file": "glute_bridge_front_aaaa1111.mp4"}],
}
ROW_B = {
    "exerciseId": "barbell_back_squat",
    "pattern": "squat",
    "primaryMuscles": ["quads", "glutes"],
    "secondaryMuscles": [],
    "equipment": ["barbell", "rack"],
    "level": "intermediate",
    "clips": [{"file": "barbell_back_squat_side_bbbb2222.mp4"}],
}


class Response:
    def __init__(self, payload):
        self.text = json.dumps(payload)
        self.usage_metadata = type("U", (), {"prompt_token_count": 100, "candidates_token_count": 20, "thoughts_token_count": 5})()


class FakeClient:
    """Answers pass 1 or pass 2 by the number of images sent."""

    def __init__(self, pass1=None, pass2=None, log=None):
        self.pass1 = pass1 or {}
        self.pass2 = pass2 or {}
        self.calls = []
        self.log = log

    @property
    def models(self):
        return self

    def generate_content(self, *, model, contents, config):
        images = len(contents) - 1
        self.calls.append(images)
        if self.log is not None:
            self.log.append(f"CALL {images}")
        if images == cev.PASS1_FRAMES:
            payload = {"pattern": "hip_thrust_bridge", "primaryMuscles": ["glutes"], "exerciseId": "glute_bridge", "confidence": 0.95}
            payload.update(self.pass1)
        else:
            win = {"move": "glute_bridge", "fullRepSeen": True, "isRestOrTransition": False, "confidence": 0.9}
            payload = {"windows": [dict(win), dict(win), dict(win)]}
            payload.update(self.pass2)
        return Response(payload)


def make_clip(path: Path, shade: int, frames: int = 30):
    import cv2
    import numpy as np

    path.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), 10, (96, 64))
    for i in range(frames):
        frame = np.full((64, 96, 3), shade, dtype=np.uint8)
        frame[:, : (i * 3) % 96] = 255 - shade
        writer.write(frame)
    writer.release()
    assert path.stat().st_size > 0


@pytest.fixture
def env(tmp_path):
    clips = tmp_path / "upload"
    make_clip(clips / "glute_bridge" / "glute_bridge_front_aaaa1111.mp4", 40)
    make_clip(clips / "barbell_back_squat" / "barbell_back_squat_side_bbbb2222.mp4", 120)
    catalogue = tmp_path / "catalogue.json"
    catalogue.write_text(json.dumps({"tagsReview": "x", "exercises": [ROW_A, ROW_B]}))
    return {"clips": clips, "catalogue": catalogue, "report": tmp_path / "report.json"}


def run(env, client, *extra, lines=None):
    lines = [] if lines is None else lines
    argv = [str(env["clips"]), "--catalogue", str(env["catalogue"]), "--report", str(env["report"]), *extra]
    code = cev.main(argv, clients=lambda: client, out=lines.append)
    return code, lines


def test_passes_run_in_order_and_are_logged(env):
    log = []
    client = FakeClient(log=log)
    code, _ = run(env, client, "--limit", "1", lines=log)
    assert code == 0
    assert client.calls == [cev.PASS1_FRAMES, cev.PASS2_WINDOWS * cev.PASS2_FRAMES_PER_WINDOW]
    marks = [next(m for m in ("pass1:", "pass2:", "pass3:", "CALL 6", "CALL 9") if m in line) for line in log if any(m in line for m in ("pass1:", "pass2:", "pass3:", "CALL"))]
    assert marks == ["CALL 6", "pass1:", "CALL 9", "pass2:", "pass3:"]


def test_consensus_success_writes_final_and_tier(env):
    code, lines = run(env, FakeClient())
    assert code == 0
    report = json.loads(env["report"].read_text())
    entry = next(e for e in report["clips"].values() if e["file"].startswith("glute_bridge"))
    verdict = entry["pass3"]
    assert verdict["needsReview"] is False
    assert verdict["final"] == {
        "exerciseId": "glute_bridge",
        "pattern": "hip_thrust_bridge",
        "primaryMuscles": ["glutes"],
        "tier": "beginner",
    }
    assert any("pass3: glute_bridge" in line for line in lines)


def test_tier_lifts_with_complexity():
    assert cev.tier_for(ROW_B) == "advanced"
    assert cev.tier_for(ROW_A) == "beginner"


def test_low_confidence_needs_review(env):
    client = FakeClient(pass1={"confidence": 0.4})
    code, lines = run(env, client, "--limit", "1")
    assert code == 0
    (entry,) = json.loads(env["report"].read_text())["clips"].values()
    assert entry["pass3"]["needsReview"] is True
    assert "final" not in entry["pass3"]
    assert any("mean confidence" in r for r in entry["pass3"]["reasons"])


def test_disagreeing_id_needs_review(env):
    client = FakeClient(pass1={"exerciseId": "barbell_back_squat", "pattern": "squat", "primaryMuscles": ["quads"]})
    run(env, client, "--limit", "1")
    (entry,) = json.loads(env["report"].read_text())["clips"].values()
    assert entry["pass3"]["needsReview"] is True
    assert any(r.startswith("id disagrees") for r in entry["pass3"]["reasons"])


def test_rest_windows_are_ignored():
    row = ROW_A
    pass1 = {"pattern": "hip_thrust_bridge", "primaryMuscles": ["glutes"], "exerciseId": "glute_bridge", "confidence": 0.9}
    good = {"move": "glute_bridge", "fullRepSeen": True, "isRestOrTransition": False, "confidence": 0.9}
    rest = {"move": "barbell_back_squat", "fullRepSeen": False, "isRestOrTransition": True, "confidence": 0.1}
    verdict = cev.consensus(pass1, {"windows": [dict(good), dict(good), dict(rest)]}, row)
    assert verdict["needsReview"] is False
    assert verdict["meanConfidence"] == 0.9
    only_one = cev.consensus(pass1, {"windows": [dict(good), dict(rest), dict(rest)]}, row)
    assert only_one["needsReview"] is True
    assert "only 1 of 3 windows show movement" in only_one["reasons"]


def test_cache_skips_second_call(env):
    first = FakeClient()
    run(env, first)
    assert len(first.calls) == 4
    second = FakeClient()
    code, lines = run(env, second)
    assert code == 0
    assert second.calls == []
    assert sum("cached" in line and "0 calls" in line for line in lines) == 2
    assert "0 model calls" in lines[-1]


def test_dry_run_makes_no_calls_and_writes_nothing(env):
    class Boom:
        def __getattr__(self, name):
            raise AssertionError("dry run touched the client")

    code, lines = run(env, Boom(), "--dry-run")
    assert code == 0
    assert not env["report"].exists()
    assert sum("frames ok: pass1 6 frames, pass2 3x3 frames" in line for line in lines) == 2
    assert "0 model calls" in lines[-1]


def test_dry_run_never_builds_a_client(env):
    def refuse():
        raise AssertionError("a client was built")

    lines = []
    argv = [str(env["clips"]), "--catalogue", str(env["catalogue"]), "--report", str(env["report"]), "--dry-run"]
    assert cev.main(argv, clients=refuse, out=lines.append) == 0


def test_limit_is_respected(env):
    client = FakeClient()
    run(env, client, "--limit", "1")
    assert len(client.calls) == 2
    assert len(json.loads(env["report"].read_text())["clips"]) == 1


def test_failed_call_is_not_cached(env):
    class Down(FakeClient):
        def generate_content(self, **kwargs):
            raise RuntimeError("down")

    code, lines = run(env, Down(), "--limit", "1")
    assert code == 0
    assert any("failed, not cached" in line for line in lines)
    assert not env["report"].exists()


def test_refuses_bad_input(env, tmp_path):
    assert cev.main([str(tmp_path / "nope")], clients=lambda: None, out=lambda s: None) == 2
    assert run(env, FakeClient(), "--limit", "0")[0] == 2
    env["catalogue"].write_text("not json")
    assert run(env, FakeClient())[0] == 2


def test_refuses_without_a_clips_folder(monkeypatch):
    monkeypatch.delenv("OWNHUB_CLIPS_DIR", raising=False)
    lines = []
    assert cev.main([], clients=lambda: None, out=lines.append) == 2
    assert "OWNHUB_CLIPS_DIR" in lines[0]


def test_clips_folder_can_come_from_the_environment(env, monkeypatch):
    monkeypatch.setenv("OWNHUB_CLIPS_DIR", str(env["clips"]))
    argv = ["--catalogue", str(env["catalogue"]), "--report", str(env["report"]), "--dry-run"]
    assert cev.main(argv, clients=lambda: None, out=lambda s: None) == 0


def test_frames_are_small_jpegs(env):
    clip = next(env["clips"].rglob("*.mp4"))
    one, two = cev.extract_frames(clip)
    assert len(one) == 6 and [len(w) for w in two] == [3, 3, 3]
    assert all(f[:2] == b"\xff\xd8" for f in one)


def test_guard_blocks_the_real_client():
    from google import genai
    from nutrition import model

    with pytest.raises(BaseException):
        genai.Client(vertexai=True)
    with pytest.raises(BaseException):
        model.client().models.generate_content(model="m", contents=[], config=None)
