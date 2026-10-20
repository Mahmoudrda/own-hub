#!/usr/bin/env python3
"""Turn the nine beginner starting programmes into 27: one per tier.

`python3 -I tool/build_programme_tiers.py` (standard library only).

Reads `assets/content/starting_programmes.json`, keeps the rows whose tier is
beginner (or has none yet), and writes the file back with an intermediate and an
advanced version of each, so running it twice gives the same file.

Every move comes from `6-v2/content/exercise_library/catalogue.json` and only
from an exercise with a filmed clip. The kit of a variant is a hard limit: the
home plans use nothing but the floor and a mat, the dumbbell plans add
dumbbells, the gym plans add the gym's kit.

  beginner      the current sessions, with extra beginner moves after the first
                six so a 45, 60 or 75 minute session has enough to fill it
  intermediate  4 sets, moves in superset pairs, rest 25% shorter, and the
                catalogue's filmed intermediate moves where the kit allows
  advanced      4 to 5 sets, supersets, rest 30 to 45 s, holds 20 s longer

The gentle sessions for pregnancy and after a birth keep the beginner
prescription in every tier: no superset, no shorter rest, no heavier move. Their
extra moves carry none of the five floor tags either.
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROGRAMMES = ROOT / "app" / "assets" / "content" / "starting_programmes.json"
CATALOGUE = ROOT / "6-v2" / "content" / "exercise_library" / "catalogue.json"

TARGET_MOVES = 14

FLOOR_TAGS = {
    "pelvic_floor_load",
    "high_impact",
    "jumping",
    "supine_load",
    "breath_hold_valsalva",
}

KIT = {
    "home": {"none", "mat"},
    "weights": {"none", "mat", "dumbbells"},
    "gym": {
        "none", "mat", "dumbbells", "bands", "bench", "barbell", "cable",
        "smith_machine", "machine",
    },
}

HOLDS = {"plank", "forearm_plank"}

# Intermediate moves swapped in for a beginner one, by variant.
SWAPS = {
    "home": {
        "knee_press_up": "push_up",
        "heel_touches": "flutter_kicks",
        "bicycle_crunch": "russian_twist",
    },
    "weights": {
        "knee_press_up": "push_up",
        "heel_touches": "flutter_kicks",
        "romanian_deadlift": "dumbbell_stiff_leg_deadlift",
    },
    "gym": {
        "heel_touches": "flutter_kicks",
        "seated_leg_press": "barbell_back_squat",
        "machine_chest_press": "barbell_bench_press",
        "smith_machine_hip_thrust": "barbell_hip_thrust",
        "romanian_deadlift": "dumbbell_stiff_leg_deadlift",
    },
}

# What the extra moves of a session favour, first to last.
PATTERNS = {
    "a": ["squat", "lunge", "hinge", "hip_thrust_bridge", "isolation_lower",
          "core_anti_extension", "push_horizontal", "pull_horizontal",
          "core_flexion", "core_rotation", "pull_vertical", "push_vertical",
          "isolation_upper"],
    "b": ["pull_horizontal", "push_vertical", "push_horizontal",
          "pull_vertical", "isolation_upper", "core_rotation",
          "core_anti_extension", "core_flexion", "squat", "lunge", "hinge",
          "hip_thrust_bridge", "isolation_lower"],
    "c": ["hinge", "push_horizontal", "squat", "pull_horizontal",
          "hip_thrust_bridge", "core_rotation", "lunge", "pull_vertical",
          "core_flexion", "push_vertical", "isolation_lower",
          "core_anti_extension", "isolation_upper"],
}

LEVEL_EN = {"beginner": "Beginner", "intermediate": "Intermediate",
            "advanced": "Advanced"}
LEVEL_AR = {"beginner": "مبتدئة", "intermediate": "متوسطة", "advanced": "متقدمة"}

TIER_NOTE_EN = {
    "beginner": "",
    "intermediate": " Four sets, moves in pairs, shorter rests.",
    "advanced": " Four to five sets, paired moves, rests of 30 to 45 seconds.",
}
TIER_NOTE_AR = {
    "beginner": "",
    "intermediate": " 4 مجموعات، تمارين مزدوجة، وراحة أقصر.",
    "advanced": " 4 لـ 5 مجموعات، تمارين مزدوجة، وراحة من 30 لـ 45 ثانية.",
}

PAIR_NOTE_EN = "Superset: go straight to the next move."
PAIR_NOTE_AR = "سوبر سيت: كمّلي على التمرين اللي بعده على طول."


def variant_of(programme_id):
    return programme_id.rsplit("_", 1)[1]


def base_id(programme_id):
    for tier in ("intermediate", "advanced"):
        if programme_id.endswith("_" + tier):
            return programme_id[: -len(tier) - 1]
    return programme_id


def load_catalogue():
    rows = json.loads(CATALOGUE.read_text(encoding="utf-8"))["exercises"]
    return {r["exerciseId"]: r for r in rows if r.get("clips")}


def move_from(row, base_move, sets, rest):
    """A move for catalogue [row], prescribed like [base_move]."""
    move = {
        "exerciseId": row["exerciseId"],
        "nameEn": row["name_en"],
        "nameAr": row["name_ar"],
        "sets": sets,
    }
    if row["exerciseId"] in HOLDS:
        move["holdSeconds"] = base_move.get("holdSeconds", 30)
    else:
        move["reps"] = base_move.get("reps", 10)
    move.update({
        "restSeconds": rest,
        "contraindications": list(row["contraindicationTags"]),
        "quiet": bool(row["quiet"]),
        "floorOnly": bool(row["floorOnly"]),
        "needsEquipment": not set(row["equipment"]) <= {"none", "mat"},
    })
    return move


def round5(value):
    return int(round(value / 5.0)) * 5


def typical(moves):
    reps = sorted(m["reps"] for m in moves if "reps" in m)
    rest = max(m["restSeconds"] for m in moves)
    return {"reps": reps[len(reps) // 2] if reps else 10}, rest


def eligible(row, variant, level, gentle):
    if row["kind"] != "strength":
        return False
    if not set(row["equipment"]) <= KIT[variant]:
        return False
    if variant != "gym" and row["place"] not in ("home", "both"):
        return False
    if level == "beginner" and row["level"] != "beginner":
        return False
    if gentle and FLOOR_TAGS & set(row["contraindicationTags"]):
        return False
    return True


def extend(work, session_key, variant, level, gentle, catalogue, replaced):
    """[work] grown to TARGET_MOVES with moves the kit allows.

    [replaced] are the beginner moves a harder one took the place of; they do
    not come back in as filler.
    """
    base, base_rest = typical(work)
    used = {m["exerciseId"] for m in work} | set(replaced)
    pool = {}
    for exercise_id in sorted(catalogue):
        row = catalogue[exercise_id]
        if exercise_id in used or not eligible(row, variant, level, gentle):
            continue
        pool.setdefault(row["pattern"], []).append(row)
    order = PATTERNS[session_key]
    out = list(work)
    while len(out) < TARGET_MOVES:
        picked = False
        for pattern in order:
            if len(out) >= TARGET_MOVES:
                break
            rows = pool.get(pattern)
            if rows:
                out.append(move_from(rows.pop(0), base, 3, base_rest))
                picked = True
        if not picked:
            break
    return out


def prescribe(work, level):
    """[work] given a tier's sets, rest and pairing."""
    if level == "beginner":
        return work
    out = []
    for index, move in enumerate(work):
        move = dict(move)
        rest = move["restSeconds"]
        if level == "intermediate":
            move["sets"] = 4
            rest = round5(rest * 0.75)
            opener = 15
            hold_extra = 10
        else:
            move["sets"] = 5 if index < 6 else 4
            rest = min(45, max(30, round5(rest * 0.45)))
            opener = 10
            hold_extra = 20
        if "holdSeconds" in move:
            move["holdSeconds"] += hold_extra
        move["restSeconds"] = rest
        if index % 2 == 0 and index + 1 < len(work):
            move["restSeconds"] = opener
            move["notesEn"] = PAIR_NOTE_EN
            move["notesAr"] = PAIR_NOTE_AR
        out.append(move)
    return out


def build_session(session, variant, level, catalogue):
    gentle = "pregnant" in session["lifeStages"]
    key = session["sessionId"][0]
    work = [dict(m) for m in session["moves"][:-1]]
    stretch = dict(session["moves"][-1])
    replaced = set()
    if level != "beginner" and not gentle:
        swaps = SWAPS[variant]
        have = {m["exerciseId"] for m in work}
        for i, move in enumerate(work):
            target = swaps.get(move["exerciseId"])
            if target and target in catalogue and target not in have:
                row = catalogue[target]
                if set(row["equipment"]) <= KIT[variant]:
                    base, _ = typical([move])
                    base = {k: move[k] for k in ("reps", "holdSeconds")
                            if k in move}
                    work[i] = move_from(row, base, move["sets"],
                                        move["restSeconds"])
                    have.add(target)
                    replaced.add(move["exerciseId"])
    work = extend(work, key, variant, "beginner" if gentle else level, gentle,
                  catalogue, replaced)
    if level != "beginner" and not gentle:
        work = prescribe(work, level)
    out = dict(session)
    out["moves"] = work + [stretch]
    return out


def build_tier(programme, level, catalogue):
    variant = variant_of(programme["programId"])
    out = json.loads(json.dumps(programme))
    out["tier"] = level
    if level != "beginner":
        out["programId"] = programme["programId"] + "_" + level
        out["titleEn"] = "%s · %s" % (programme["titleEn"], LEVEL_EN[level])
        out["titleAr"] = "%s · %s" % (programme["titleAr"], LEVEL_AR[level])
        out["summaryEn"] = programme["summaryEn"] + TIER_NOTE_EN[level]
        out["summaryAr"] = programme["summaryAr"] + TIER_NOTE_AR[level]
    out["sessions"] = [
        build_session(s, variant, level, catalogue) for s in programme["sessions"]
    ]
    return out


def check(programmes, catalogue):
    for p in programmes:
        for s in p["sessions"]:
            ids = [m["exerciseId"] for m in s["moves"]]
            assert len(ids) == len(set(ids)), (p["programId"], s["sessionId"])
            assert len(s["moves"]) <= 20
            for m in s["moves"]:
                assert m["exerciseId"] in catalogue, m["exerciseId"]
                assert m["contraindications"], m["exerciseId"]
                assert set(catalogue[m["exerciseId"]]["contraindicationTags"]) \
                    == set(m["contraindications"]), m["exerciseId"]
                if "pregnant" in s["lifeStages"]:
                    assert not FLOOR_TAGS & set(m["contraindications"]), (
                        p["programId"], s["sessionId"], m["exerciseId"])
            work = len(s["moves"]) - 1
            if work < TARGET_MOVES:
                print("short: %s %s has %d moves" % (
                    p["programId"], s["sessionId"], work))


def main():
    catalogue = load_catalogue()
    source = json.loads(PROGRAMMES.read_text(encoding="utf-8"))
    beginners = [
        p for p in source["programmes"] if p.get("tier", "beginner") == "beginner"
    ]
    programmes = []
    for level in ("beginner", "intermediate", "advanced"):
        for p in beginners:
            programmes.append(build_tier(p, level, catalogue))
    # Grouped by plan, then tier, so a diff reads plan by plan.
    programmes.sort(key=lambda p: (
        [q["programId"] for q in beginners].index(base_id(p["programId"])),
        ("beginner", "intermediate", "advanced").index(p["tier"]),
    ))
    check(programmes, catalogue)
    source["programmes"] = programmes
    PROGRAMMES.write_text(
        json.dumps(source, indent=1, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print("%d programmes written" % len(programmes))


if __name__ == "__main__":
    main()
