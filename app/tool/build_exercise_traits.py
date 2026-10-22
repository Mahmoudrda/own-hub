#!/usr/bin/env python3
"""Build assets/content/exercise_traits.json: what each move is measured on.

Reads the exercise catalogue (6-v2/content/exercise_library/catalogue.json) and
the starting programmes, and writes one entry per catalogue move:

  metric    load | reps | hold   (what a personal best on the move compares)
  equipment catalogue equipment ids
  nameEn    the move's name, English in every locale

Every move a programme prescribes must be in the catalogue; the build fails
loudly otherwise. The output is deterministic (sorted keys).

  python3 tool/build_exercise_traits.py           write the file
  python3 tool/build_exercise_traits.py --check   exit 1 if the file is stale
"""
import json
import sys
from pathlib import Path

APP = Path(__file__).resolve().parent.parent
CATALOGUE = APP.parent / "6-v2/content/exercise_library/catalogue.json"
PROGRAMMES = APP / "assets/content/starting_programmes.json"
OUT = APP / "assets/content/exercise_traits.json"

LOADED = {"barbell", "smith_machine", "machine", "cable", "dumbbells", "kettlebell"}
# The six moves the first screens name. They are not in the catalogue; their
# metrics match `bundledExerciseMetrics` in lib/features/train/domain/
# exercise_metrics.dart (a test holds the two together).
LEGACY = {
    "glute_bridge": ("reps", "Glute bridge"),
    "goblet_squat": ("load", "Goblet squat"),
    "step_back_lunge": ("reps", "Step-back lunge"),
    "hip_thrust_hold": ("hold", "Hip thrust hold"),
    "plank_hold": ("hold", "Plank hold"),
    "dead_bug": ("reps", "Dead bug"),
}


def build():
    catalogue = {
        e["exerciseId"]: e
        for e in json.loads(CATALOGUE.read_text(encoding="utf-8"))["exercises"]
    }
    held = set()
    split_ids = set()
    for programme in json.loads(PROGRAMMES.read_text(encoding="utf-8"))["programmes"]:
        for session in programme["sessions"]:
            for move in session["moves"]:
                split_ids.add(move["exerciseId"])
                if move.get("holdSeconds") and not move.get("reps"):
                    held.add(move["exerciseId"])

    missing = sorted(split_ids - set(catalogue))
    if missing:
        sys.exit("programme moves missing from the catalogue: " + ", ".join(missing))

    moves = {}
    for move_id, row in sorted(catalogue.items()):
        equipment = list(row.get("equipment", []))
        if move_id == "mountain_climbers":
            metric = "reps"
        elif row.get("kind") == "stretch" or move_id in held:
            metric = "hold"
        elif LOADED & set(equipment):
            metric = "load"
        else:
            metric = "reps"
        moves[move_id] = {
            "metric": metric,
            "equipment": equipment,
            "nameEn": row["name_en"],
        }
    for move_id, (metric, name) in LEGACY.items():
        if move_id in moves:
            sys.exit("legacy move is now in the catalogue: " + move_id)
        moves[move_id] = {"metric": metric, "equipment": [], "nameEn": name}
    return {"version": 1, "moves": moves}


def render(data):
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main():
    data = build()
    text = render(data)
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            sys.exit("exercise_traits.json is stale: run tool/build_exercise_traits.py")
        print("exercise_traits.json is current")
        return
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT} ({len(data['moves'])} moves)")


if __name__ == "__main__":
    main()
