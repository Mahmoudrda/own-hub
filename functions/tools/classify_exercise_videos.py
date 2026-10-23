"""OWNER'S TOOL ONLY: check what each exercise clip shows against the catalogue.

    cd functions
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.classify_exercise_videos CLIPS_DIR --dry-run
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.classify_exercise_videos CLIPS_DIR --limit 3
    GOOGLE_CLOUD_PROJECT=own-hub OWNHUB_CLIPS_DIR=CLIPS_DIR .venv/bin/python -m tools.classify_exercise_videos

CLIPS_DIR is the folder of .mp4 clips. Without it (and without OWNHUB_CLIPS_DIR)
the tool refuses before doing anything.

Every clip goes through three passes and the log shows all of them:

  1. One model call with 6 evenly spaced frames: the movement pattern, the
     primary muscles and the closest catalogue exercise.
  2. One model call with 3 time windows of 3 frames each: what each window
     shows, whether a full repetition is visible, whether it is a rest or a
     transition.
  3. Local, no call: pass 1, the majority of pass 2 (rest windows ignored) and
     the catalogue row must name the same exercise, and the mean confidence
     must reach 0.8. Then the final id, pattern, muscles and tier are written
     out. Anything else is marked needsReview with the reasons.

A clip is looked up by its md5 in the report, so a rerun costs nothing for
clips already answered (pass 3 is recomputed against the catalogue as it is
now). The catalogue is only read, never edited. Frames are JPEG at 384 px, so
an uncached clip costs two calls of about 5k input tokens in total.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Callable, Optional

CLIPS_ENV = "OWNHUB_CLIPS_DIR"
DEFAULT_CATALOGUE = (
    Path(__file__).resolve().parents[2] / "6-v2" / "content" / "exercise_library" / "catalogue.json"
)
DEFAULT_REPORT = Path(__file__).resolve().parent / "out" / "classification_report.json"

FRAME_SIDE = 384
JPEG_QUALITY = 80
PASS1_FRAMES = 6
PASS2_WINDOWS = 3
PASS2_FRAMES_PER_WINDOW = 3
MIN_CONFIDENCE = 0.8
PASS1_MAX_TOKENS = 900
PASS2_MAX_TOKENS = 1600
NO_MOVE = "none"

LEVELS = ["beginner", "intermediate", "advanced"]
COMPOUND_PATTERNS = {
    "squat",
    "hinge",
    "lunge",
    "hip_thrust_bridge",
    "push_horizontal",
    "push_vertical",
    "pull_horizontal",
    "pull_vertical",
    "carry",
}
"""Complexity of a row: one point for a compound pattern, one more for a
barbell or three or more pieces of equipment. Two points lift the tier one
step above the catalogue level, never past advanced."""


class Refused(ValueError):
    """Why the tool stopped before any call."""


# ---------------------------------------------------------------- the catalogue


def load_catalogue(path: Path) -> dict:
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        rows = data["exercises"]
        by_id = {row["exerciseId"]: row for row in rows}
    except (OSError, ValueError, KeyError, TypeError):
        raise Refused("the catalogue could not be read as JSON with an exercises list") from None
    if not by_id:
        raise Refused("the catalogue has no exercises")
    by_file = {clip["file"]: row for row in rows for clip in row.get("clips", [])}
    return {"rows": rows, "by_id": by_id, "by_file": by_file}


def find_row(catalogue: dict, clip: Path) -> Optional[dict]:
    return catalogue["by_file"].get(clip.name) or catalogue["by_id"].get(clip.parent.name)


def complexity(row: dict) -> int:
    points = 1 if row.get("pattern") in COMPOUND_PATTERNS else 0
    equipment = row.get("equipment") or []
    if "barbell" in equipment or len(equipment) >= 3:
        points += 1
    return points


def tier_for(row: dict) -> str:
    base = LEVELS.index(row["level"]) if row.get("level") in LEVELS else 0
    lift = 1 if complexity(row) >= 2 else 0
    return LEVELS[min(base + lift, len(LEVELS) - 1)]


# ----------------------------------------------------------------------- frames


def _jpeg(frame) -> bytes:
    import cv2

    height, width = frame.shape[:2]
    scale = FRAME_SIDE / max(height, width)
    if scale < 1:
        frame = cv2.resize(frame, (max(1, round(width * scale)), max(1, round(height * scale))), interpolation=cv2.INTER_AREA)
    ok, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY])
    if not ok:
        raise Refused("a frame could not be encoded")
    return buffer.tobytes()


def spread(count: int, positions: list[float]) -> list[int]:
    """Frame numbers at these fractions (0 to 1) of a clip of `count` frames."""
    return [min(count - 1, max(0, int(p * count))) for p in positions]


def pass1_positions() -> list[float]:
    return [(i + 0.5) / PASS1_FRAMES for i in range(PASS1_FRAMES)]


def pass2_positions() -> list[list[float]]:
    return [
        [(w + (j + 1) / (PASS2_FRAMES_PER_WINDOW + 1)) / PASS2_WINDOWS for j in range(PASS2_FRAMES_PER_WINDOW)]
        for w in range(PASS2_WINDOWS)
    ]


def extract_frames(clip: Path) -> tuple[list[bytes], list[list[bytes]]]:
    """(pass 1 frames, pass 2 frames by window), each a 384 px JPEG."""
    import cv2

    capture = cv2.VideoCapture(str(clip))
    try:
        count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        if not capture.isOpened() or count <= 0:
            raise Refused("the clip could not be opened")
        windows = pass2_positions()
        wanted = spread(count, pass1_positions()) + [i for w in windows for i in spread(count, w)]
        need = set(wanted)
        got: dict[int, bytes] = {}
        index = 0
        while index <= max(need):
            if not capture.grab():
                break
            if index in need:
                ok, frame = capture.retrieve()
                if ok:
                    got[index] = _jpeg(frame)
            index += 1
    finally:
        capture.release()
    if not got:
        raise Refused("the clip has no readable frames")
    nearest = lambda i: got[i] if i in got else got[min(got, key=lambda g: abs(g - i))]
    one = [nearest(i) for i in spread(count, pass1_positions())]
    two = [[nearest(i) for i in spread(count, w)] for w in windows]
    return one, two


# ------------------------------------------------------------------ model calls


def _schema(ids: list[str], patterns: list[str], muscles: list[str]) -> tuple[dict, dict]:
    pass1 = {
        "type": "OBJECT",
        "properties": {
            "pattern": {"type": "STRING", "enum": patterns},
            "primaryMuscles": {
                "type": "ARRAY",
                "maxItems": 3,
                "items": {"type": "STRING", "enum": muscles},
            },
            "exerciseId": {"type": "STRING", "enum": ids},
            "confidence": {"type": "NUMBER"},
        },
        "required": ["pattern", "primaryMuscles", "exerciseId", "confidence"],
    }
    pass2 = {
        "type": "OBJECT",
        "properties": {
            "windows": {
                "type": "ARRAY",
                "minItems": PASS2_WINDOWS,
                "maxItems": PASS2_WINDOWS,
                "items": {
                    "type": "OBJECT",
                    "properties": {
                        "move": {"type": "STRING", "enum": ids + [NO_MOVE]},
                        "fullRepSeen": {"type": "BOOLEAN"},
                        "isRestOrTransition": {"type": "BOOLEAN"},
                        "confidence": {"type": "NUMBER"},
                    },
                    "required": ["move", "fullRepSeen", "isRestOrTransition", "confidence"],
                },
            }
        },
        "required": ["windows"],
    }
    return pass1, pass2


def _prompt1(ids: list[str]) -> str:
    return (
        f"These {PASS1_FRAMES} frames, in time order, are from one short clip of a woman doing one gym or home exercise. "
        "Return JSON only. pattern: the movement pattern. primaryMuscles: the 1 to 3 muscles that work hardest. "
        "exerciseId: the single best match from this list. confidence: 0 to 1.\n"
        "Exercises: " + ", ".join(ids)
    )


def _prompt2(ids: list[str]) -> str:
    return (
        f"These {PASS2_WINDOWS * PASS2_FRAMES_PER_WINDOW} frames, in time order, are {PASS2_WINDOWS} consecutive windows of one short exercise clip, "
        f"{PASS2_FRAMES_PER_WINDOW} frames per window. Return JSON only, one entry per window in order. move: the best match from the list, "
        f"or {NO_MOVE}. fullRepSeen: a whole repetition is visible in the window. isRestOrTransition: she is resting, walking, setting up or "
        "changing position. confidence: 0 to 1.\n"
        "Exercises: " + ", ".join(ids)
    )


def _call(client, config_types, parts: list[bytes], prompt: str, schema: dict, max_tokens: int):
    from nutrition import config

    response = client.models.generate_content(
        model=config.MODEL,
        contents=[config_types.Part.from_bytes(data=p, mime_type="image/jpeg") for p in parts] + [prompt],
        config=config_types.GenerateContentConfig(
            temperature=config.TEMPERATURE,
            max_output_tokens=max_tokens,
            response_mime_type="application/json",
            response_schema=schema,
            thinking_config=config_types.ThinkingConfig(**config.thinking_settings(config.MODEL)),
        ),
    )
    usage = getattr(response, "usage_metadata", None)
    tokens = {
        "in": _count(getattr(usage, "prompt_token_count", None)),
        "out": (_count(getattr(usage, "candidates_token_count", None)) or 0)
        + (_count(getattr(usage, "thoughts_token_count", None)) or 0),
    }
    return json.loads(response.text), tokens


def _count(value):
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _number(value) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError("not a number")
    return max(0.0, min(1.0, float(value)))


def clean_pass1(data: dict) -> dict:
    return {
        "pattern": str(data["pattern"]),
        "primaryMuscles": [str(m) for m in data["primaryMuscles"]],
        "exerciseId": str(data["exerciseId"]),
        "confidence": _number(data["confidence"]),
    }


def clean_pass2(data: dict) -> dict:
    windows = data["windows"]
    if len(windows) != PASS2_WINDOWS:
        raise ValueError("wrong number of windows")
    return {
        "windows": [
            {
                "move": str(w["move"]),
                "fullRepSeen": bool(w["fullRepSeen"]),
                "isRestOrTransition": bool(w["isRestOrTransition"]),
                "confidence": _number(w["confidence"]),
            }
            for w in windows
        ]
    }


# ------------------------------------------------------------------ consensus


def pass2_majority(pass2: dict) -> tuple[Optional[str], list[dict], list[str]]:
    """(winning move or None, the windows that voted, reasons it failed)."""
    voting = [w for w in pass2["windows"] if not w["isRestOrTransition"] and w["move"] != NO_MOVE]
    if len(voting) < 2:
        return None, voting, [f"only {len(voting)} of {PASS2_WINDOWS} windows show movement"]
    ranked = Counter(w["move"] for w in voting).most_common()
    if ranked[0][1] < 2 or (len(ranked) > 1 and ranked[1][1] == ranked[0][1]):
        return None, voting, ["pass 2 windows disagree: " + ", ".join(w["move"] for w in voting)]
    return ranked[0][0], voting, []


def consensus(pass1: dict, pass2: dict, row: Optional[dict]) -> dict:
    """Pass 3. Final values, or needsReview with every reason found."""
    reasons: list[str] = []
    winner, voting, why = pass2_majority(pass2)
    reasons += why
    if row is None:
        reasons.append("the clip is not in the catalogue")
    catalogue_id = row["exerciseId"] if row else None
    if winner is not None and len({pass1["exerciseId"], winner, catalogue_id}) > 1:
        reasons.append(f"id disagrees: pass1={pass1['exerciseId']} pass2={winner} catalogue={catalogue_id}")
    elif winner is None and row and pass1["exerciseId"] != catalogue_id:
        reasons.append(f"id disagrees: pass1={pass1['exerciseId']} catalogue={catalogue_id}")
    if row:
        if pass1["pattern"] != row["pattern"]:
            reasons.append(f"pattern disagrees: pass1={pass1['pattern']} catalogue={row['pattern']}")
        if not set(pass1["primaryMuscles"]) & set(row["primaryMuscles"]):
            reasons.append(
                f"muscles disagree: pass1={'+'.join(pass1['primaryMuscles'])} catalogue={'+'.join(row['primaryMuscles'])}"
            )
    scores = [pass1["confidence"]] + [w["confidence"] for w in voting if winner is None or w["move"] == winner]
    mean = sum(scores) / len(scores)
    if mean < MIN_CONFIDENCE:
        reasons.append(f"mean confidence {mean:.2f} is under {MIN_CONFIDENCE}")
    result = {
        "meanConfidence": round(mean, 3),
        "pass2Majority": winner,
        "fullRepWindows": sum(1 for w in voting if w["fullRepSeen"]),
    }
    if reasons:
        return {**result, "needsReview": True, "reasons": reasons}
    return {
        **result,
        "needsReview": False,
        "reasons": [],
        "final": {
            "exerciseId": row["exerciseId"],
            "pattern": row["pattern"],
            "primaryMuscles": list(row["primaryMuscles"]),
            "tier": tier_for(row),
        },
    }


# ----------------------------------------------------------------------- report


def read_report(path: Path) -> dict:
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if isinstance(data.get("clips"), dict):
            return data
    except (OSError, ValueError, AttributeError):
        pass
    return {"clips": {}}


def write_report(path: Path, report: dict) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    temp.replace(path)


def md5_of(path: Path) -> str:
    digest = hashlib.md5()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


# ------------------------------------------------------------------------- main


def main(
    argv=None,
    *,
    clients: Optional[Callable] = None,
    require_adc: Optional[Callable] = None,
    out=print,
) -> int:
    parser = argparse.ArgumentParser(prog="classify_exercise_videos")
    parser.add_argument(
        "clips",
        nargs="?",
        default=os.environ.get(CLIPS_ENV),
        help=f"folder of .mp4 clips (or set {CLIPS_ENV})",
    )
    parser.add_argument("--catalogue", default=str(DEFAULT_CATALOGUE))
    parser.add_argument("--report", default=str(DEFAULT_REPORT))
    parser.add_argument("--limit", type=int, help="look at the first N clips only")
    parser.add_argument("--dry-run", action="store_true", help="extract frames only, no model calls, no report")
    args = parser.parse_args(argv)

    if not args.clips:
        out(f"refused: give the clips folder as the first argument or set {CLIPS_ENV}")
        return 2
    if args.limit is not None and args.limit < 1:
        out("refused: --limit must be 1 or more")
        return 2
    folder = Path(args.clips).expanduser()
    if not folder.is_dir():
        out(f"refused: {folder} is not a folder")
        return 2
    try:
        catalogue = load_catalogue(Path(args.catalogue).expanduser())
    except Refused as refused:
        out(f"refused: {refused}")
        return 2
    clips = sorted(folder.rglob("*.mp4"))
    if not clips:
        out(f"refused: no .mp4 clips under {folder}")
        return 2
    if args.limit:
        clips = clips[: args.limit]

    ids = sorted(catalogue["by_id"])
    patterns = sorted({r["pattern"] for r in catalogue["rows"]})
    muscles = sorted({m for r in catalogue["rows"] for m in r["primaryMuscles"] + r.get("secondaryMuscles", [])})
    schema1, schema2 = _schema(ids, patterns, muscles)
    report_path = Path(args.report).expanduser()
    report = read_report(report_path)

    client = types = None
    if not args.dry_run:
        try:
            if clients is None:
                (require_adc or _default_adc)()
            from google.genai import types

            client = (clients or _default_client)()
        except SystemExit as stop:
            out(str(stop))
            return 2

    calls = cached = review = ok = failed = 0
    tokens_in = tokens_out = 0
    out(f"{len(clips)} clips from {folder}{' (dry run, no model calls)' if args.dry_run else ''}")
    for number, clip in enumerate(clips, 1):
        label = f"[{number}/{len(clips)}] {clip.name}"
        row = find_row(catalogue, clip)
        digest = md5_of(clip)
        entry = report["clips"].get(digest)
        try:
            if args.dry_run:
                one, two = extract_frames(clip)
                sizes = [len(f) for f in one] + [len(f) for w in two for f in w]
                out(f"{label} frames ok: pass1 {len(one)} frames, pass2 {len(two)}x{len(two[0])} frames, {sum(sizes)} bytes")
                continue
            if entry and "pass1" in entry and "pass2" in entry:
                cached += 1
                out(f"{label} cached ({digest[:8]}), 0 calls")
                pass1, pass2 = entry["pass1"], entry["pass2"]
            else:
                one, two = extract_frames(clip)
                time.sleep(2)
                pass1, used = _call(client, types, one, _prompt1(ids), schema1, PASS1_MAX_TOKENS)
                calls += 1
                pass1 = clean_pass1(pass1)
                tokens_in += used["in"] or 0
                tokens_out += used["out"]
                out(
                    f"{label} pass1: {pass1['exerciseId']} {pass1['pattern']} "
                    f"{'+'.join(pass1['primaryMuscles'])} conf={pass1['confidence']:.2f}"
                )
                pass2, used = _call(
                    client, types, [f for w in two for f in w], _prompt2(ids), schema2, PASS2_MAX_TOKENS
                )
                calls += 1
                pass2 = clean_pass2(pass2)
                tokens_in += used["in"] or 0
                tokens_out += used["out"]
                out(
                    f"{label} pass2: "
                    + " | ".join(
                        f"{w['move']}{' rest' if w['isRestOrTransition'] else ''}"
                        f"{' rep' if w['fullRepSeen'] else ''} {w['confidence']:.2f}"
                        for w in pass2["windows"]
                    )
                )
        except Refused as refused:
            failed += 1
            out(f"{label} skipped: {refused}")
            continue
        except Exception as error:
            failed += 1
            out(f"{label} failed, not cached: {type(error).__name__}")
            if "429" in str(error) or "RESOURCE_EXHAUSTED" in str(error):
                out("  quota reached, waiting 60 seconds")
                time.sleep(60)
            continue

        verdict = consensus(pass1, pass2, row)
        if verdict["needsReview"]:
            review += 1
            out(f"{label} pass3: needsReview: " + "; ".join(verdict["reasons"]))
        else:
            ok += 1
            final = verdict["final"]
            out(f"{label} pass3: {final['exerciseId']} {final['pattern']} tier={final['tier']} conf={verdict['meanConfidence']:.2f}")
        report["clips"][digest] = {
            "file": clip.name,
            "pass1": pass1,
            "pass2": pass2,
            "pass3": verdict,
        }
        write_report(report_path, report)

    if args.dry_run:
        out(f"dry run done: {len(clips)} clips looked at, 0 model calls")
        return 0
    out(
        f"done: {ok} agreed, {review} need review, {cached} cached, {failed} failed; "
        f"{calls} model calls, {tokens_in} input and {tokens_out} output tokens; report {report_path}"
    )
    return 0


def _default_adc() -> None:
    from tools.upload_media import _require_adc

    _require_adc()


def _default_client():
    from nutrition import model

    return model.client()


if __name__ == "__main__":
    sys.exit(main())
