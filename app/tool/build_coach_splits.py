#!/usr/bin/env python3
"""Write the coach's three splits as the starting programmes.

`python3 -I tool/build_coach_splits.py` (standard library only).

Rewrites `assets/content/starting_programmes.json` from scratch: nine
programmes, the 3, 4 and 5 day splits the coach wrote, each in a beginner, an
intermediate and an advanced tier. The three tiers of a split hold the same
moves in the same order; only sets, reps, rest and the load note change.

Every move comes from `6-v2/content/exercise_library/catalogue.json`. Where the
coach's move is not filmed yet the closest filmed move stands in for it; the
list is `MISSING` below and `.claude/handoff-store-pass/splits-to-film.md`.

Each day runs 45 to 60 minutes by the sum the app uses (`estimatedMinutes` in
`programme_week.dart`). A tier starts from its own prescription; when a short
day falls under 46 minutes the script adds sets to the first moves (up to the
tier's cap), then rest, and when a long one goes over 56 it takes sets off the
last moves. It never adds a move the coach did not list.

Cardio is written as timed blocks of 10 minutes, because one hold may not
exceed 600 seconds (`WorkoutLimits.maxHoldSeconds`). The catalogue has no
cardio row, so mountain climbers stand in for the clip.

Each split also carries two gentle sessions for pregnancy and after a birth, the
same in every split and tier, with no move tagged with the floor.
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROGRAMMES = ROOT / "app" / "assets" / "content" / "starting_programmes.json"
CATALOGUE = ROOT / "6-v2" / "content" / "exercise_library" / "catalogue.json"

REVIEW = "drafted 21 Oct 2026 from the coach's three splits, pending Rahma's sign-off"

TIERS = ("beginner", "intermediate", "advanced")
LEVEL_EN = {"beginner": "Beginner", "intermediate": "Intermediate",
            "advanced": "Advanced"}
LEVEL_AR = {"beginner": "مبتدئة", "intermediate": "متوسطة", "advanced": "متقدمة"}

FLOOR_TAGS = {
    "pelvic_floor_load",
    "high_impact",
    "jumping",
    "supine_load",
    "breath_hold_valsalva",
}

# The bounds an ordinary day is held to, and where the fit aims.
MIN_MINUTES = 45
MAX_MINUTES = 60
FIT_LOW = 46
FIT_HIGH = 56

ORDINARY_STAGES = ["none", "pain_injury"]
GENTLE_STAGES = ["pregnant", "postpartum"]

# Tier rules: the sets a move starts on, the most the fit may add, the reps and
# the rest by kind of move, and the hold of a plank-type move.
BIG, ISO, CORE, HOLD, CARDIO = "big", "iso", "core", "hold", "cardio"

TIER = {
    "beginner": {
        "sets": 3, "cap": 4, "floor": 3,
        "reps": {BIG: 12, ISO: 12, CORE: 12},
        "rest": {BIG: 90, ISO: 75, CORE: 60, HOLD: 60},
        "rest_max": {BIG: 120, ISO: 90, CORE: 75, HOLD: 75},
        "hold": 30,
        "note_en": ("Pick a weight that leaves 2 or 3 reps in hand on every "
                    "set. Add a little next time when it feels easy."),
        "note_ar": ("اختاري وزن يسيب لك 2 أو 3 عدّات في إيدك في كل مجموعة. "
                    "زوّدي شوية المرة الجاية لما يبقى سهل."),
    },
    "intermediate": {
        "sets": 4, "cap": 5, "floor": 3,
        "reps": {BIG: 10, ISO: 10, CORE: 15},
        "rest": {BIG: 75, ISO: 60, CORE: 45, HOLD: 45},
        "rest_max": {BIG: 90, ISO: 75, CORE: 60, HOLD: 60},
        "hold": 40,
        "note_en": ("Use a weight that leaves 1 or 2 reps in hand. When every "
                    "set is done, add a rep or a little weight next time."),
        "note_ar": ("استخدمي وزن يسيب لك عدّة أو اتنين في إيدك. لما تخلّصي كل "
                    "المجموعات، زوّدي عدّة أو وزن بسيط المرة الجاية."),
    },
    "advanced": {
        "sets": 4, "cap": 5, "floor": 3,
        "reps": {BIG: 8, ISO: 12, CORE: 20},
        "rest": {BIG: 120, ISO: 50, CORE: 45, HOLD: 45},
        "rest_max": {BIG: 120, ISO: 60, CORE: 60, HOLD: 60},
        "hold": 50,
        "note_en": ("Go heavy on the big lifts with one rep in hand, lighter on "
                    "the small ones. Add weight when the top reps are clean."),
        "note_ar": ("اشتغلي تقيل على التمارين الكبيرة وسيبي عدّة واحدة في إيدك، "
                    "وأخف على الصغيرة. زوّدي الوزن لما أعلى العدّات تبقى نضيفة."),
    },
}

GENTLE_EN = "Go easy and keep a few reps in hand."
GENTLE_AR = "خلّيكي مريحة وسيبي كام عدّة في إيدك."

BLOCK_SECONDS = 600
CARDIO_STAND_IN = "mountain_climbers"
CARDIO_REST = 60


def M(exercise_id, kind):
    return {"id": exercise_id, "kind": kind}


def C(name_en, name_ar, minutes):
    return {"id": CARDIO_STAND_IN, "kind": CARDIO, "name_en": name_en,
            "name_ar": name_ar, "minutes": minutes}


# --- the coach's splits --------------------------------------------------------
# Each day: id, English title, Arabic title, moves in the coach's order, and the
# closing stretch. The comment on a line is the coach's own word where a
# different move stands in for it.

SPLITS = {
    3: [
        ("d1", "Upper", "علوي", [
            M("machine_chest_press", BIG),
            M("lat_pulldown_wide", BIG),
            M("pec_deck_fly", ISO),  # chest butterfly
            M("seated_cable_row", BIG),
            M("dumbbell_lateral_raise", ISO),
            M("reverse_pec_deck", ISO),  # rear delts
            M("standing_dumbbell_biceps_curl", ISO),
            M("cable_rope_triceps_pushdown", ISO),  # cable pulldown, triceps
            M("plank", HOLD),  # high plank
        ], "wall_chest_stretch"),
        ("d2", "Lower", "سفلي", [
            M("pendulum_squat", BIG),  # leg extensions
            M("heel_elevated_goblet_squat", BIG),  # goblet squat
            M("seated_leg_press", BIG),
            M("dumbbell_calf_raise", ISO),  # calf raises
            M("dumbbell_sumo_squat", BIG),  # leg adduction
            M("bodyweight_squat_arm_swing", CORE),  # wall sit
            M("mountain_climbers", CORE),
            M("russian_twist", CORE),
        ], "standing_forward_fold"),
        ("d3", "Lower II", "سفلي 2", [
            M("dumbbell_sumo_squat", BIG),
            M("seated_leg_curl", ISO),
            M("romanian_deadlift", BIG),
            M("side_lying_clamshell", ISO),  # leg abduction
            M("seated_dumbbell_calf_raise", ISO),
            M("dumbbell_reverse_lunge", BIG),  # walking lunges
            M("crunch", CORE),
            M("reach_crunch", CORE),  # toe touches
            M("bicycle_crunch", CORE),
            M("flutter_kicks", HOLD),  # hollow hold
        ], "half_kneeling_hip_flexor_stretch"),
    ],
    4: [
        ("d1", "Upper", "علوي", [
            M("machine_chest_press", BIG),
            M("lat_pulldown_wide", BIG),
            M("pec_deck_fly", ISO),  # butterfly
            M("seated_cable_row", BIG),  # narrow grip
            M("dumbbell_lateral_raise", ISO),
            M("seated_dumbbell_front_raise", ISO),  # front delts
            M("reverse_pec_deck", ISO),  # rear delts
            M("cable_biceps_curl", ISO),  # biceps cable cross
            M("cable_rope_triceps_pushdown", ISO),  # rope pulldown
            M("plank", HOLD),  # high plank
        ], "wall_chest_stretch"),
        ("d2", "Lower", "سفلي", [
            M("barbell_back_squat", BIG),
            M("dumbbell_bulgarian_split_squat", BIG),
            M("pendulum_squat", BIG),  # leg extension
            M("straight_leg_glute_kickback", ISO),  # kickbacks
            M("side_lying_clamshell", ISO),  # side kicks
            M("dumbbell_sumo_squat", BIG),  # adduction machine
            M("dumbbell_calf_raise", ISO),  # calf raises
        ], "standing_forward_fold"),
        ("d3", "Lower II", "سفلي 2", [
            M("dumbbell_sumo_squat", BIG),
            M("kettlebell_glute_bridge", BIG),  # glute bridges
            M("seated_leg_curl", ISO),
            M("dumbbell_reverse_lunge", BIG),  # lunges
            M("side_lying_clamshell", ISO),  # abduction machine
            M("seated_dumbbell_calf_raise", ISO),
        ], "half_kneeling_hip_flexor_stretch"),
        ("d4", "Core and cardio", "كور وكارديو", [
            M("flutter_kicks", HOLD),  # leg raises
            M("russian_twist", CORE),
            M("crunch", CORE),
            M("plank", HOLD),
            C("Treadmill", "تريدميل", {"beginner": 20, "intermediate": 20,
                                       "advanced": 30}),
        ], "childs_pose"),
    ],
    5: [
        ("d1", "Glutes and legs", "رجلين وأرداف", [
            M("seated_leg_press", BIG),  # hack squat
            M("barbell_hip_thrust", BIG),
            M("pendulum_squat", BIG),  # leg extensions
            M("dumbbell_reverse_lunge", BIG),  # walking lunges
            M("dumbbell_sumo_squat", BIG),  # adduction
            M("dumbbell_calf_raise", ISO),  # calf raises
            M("flutter_kicks", HOLD),  # hollow hold
        ], "standing_forward_fold"),
        ("d2", "Upper", "علوي", [
            M("pec_deck_fly", ISO),  # butterfly
            M("lat_pulldown_wide", BIG),
            M("knee_press_up", BIG),
            M("bent_over_row", BIG),
            M("shoulder_press", BIG),
            M("dumbbell_lateral_raise", ISO),
            M("reverse_pec_deck", ISO),  # rear delt
        ], "cross_body_shoulder_stretch"),
        ("d3", "Cardio and arms", "كارديو وإيدين", [
            M("standing_dumbbell_biceps_curl", ISO),
            M("cable_rope_triceps_pushdown", ISO),  # rope extension
            M("cable_face_pull", ISO),
            C("Elliptical", "إليبتيكال", {"beginner": 30, "intermediate": 30,
                                          "advanced": 30}),
        ], "overhead_triceps_stretch"),
        ("d4", "Glutes and legs II", "رجلين وأرداف 2", [
            M("seated_leg_curl", ISO),
            M("barbell_deadlift", BIG),
            M("straight_leg_glute_kickback", ISO),  # kickbacks
            M("donkey_kick", ISO),  # to donkey kicks
            M("kettlebell_glute_bridge", BIG),  # glute bridges, KB
            M("dumbbell_sumo_squat", BIG),  # "(abduction/add)" read as adduction only
            M("seated_dumbbell_calf_raise", ISO),
        ], "half_kneeling_hip_flexor_stretch"),
        ("d5", "Core with cardio", "كور مع كارديو", [
            M("bicycle_crunch", CORE),
            M("reach_crunch", CORE),  # toe touches
            M("lying_bicycle_legs", CORE),  # alternating leg switches
            M("crunch", CORE),
            M("plank", HOLD),  # high plank
            C("Treadmill", "تريدميل", {"beginner": 20, "intermediate": 20,
                                       "advanced": 20}),
        ], "childs_pose"),
    ],
}

# Gentle sessions for pregnancy and after a birth. The same in every split.
GENTLE = [
    ("a-gentle", "Gentle full body A", "الجسم كله بهدوء أ", [
        ("dumbbell_sumo_squat", 3, 10, 90),
        ("machine_chest_press", 3, 10, 90),
        ("lat_pulldown_wide", 3, 10, 90),
        ("dumbbell_reverse_lunge", 3, 10, 90),
        ("seated_leg_curl", 3, 12, 75),
        ("dumbbell_lateral_raise", 3, 12, 60),
        ("cable_rope_triceps_pushdown", 3, 12, 60),
        ("side_lying_clamshell", 3, 12, 60),
    ], "standing_forward_fold"),
    ("b-gentle", "Gentle full body B", "الجسم كله بهدوء ب", [
        ("seated_cable_row", 3, 10, 90),
        ("pec_deck_fly", 3, 12, 75),
        ("dumbbell_sumo_squat", 3, 10, 90),
        ("single_arm_machine_row", 3, 10, 90),
        ("straight_leg_glute_kickback", 3, 12, 60),
        ("cable_biceps_curl", 3, 12, 60),
        ("cable_face_pull", 3, 12, 60),
        ("donkey_kick", 3, 12, 60),
    ], "wall_chest_stretch"),
]

# Every named move of the coach's that is not in the catalogue, and what stands
# in for it. Written into splits-to-film.md; kept here so the file and the
# table cannot drift apart.
MISSING = [
    ("Leg extensions (machine)", "pendulum_squat", "3 day D2, 4 day D2, 5 day D1"),
    ("Hack squat (machine)", "seated_leg_press", "5 day D1"),
    ("Leg adduction, adduction machine", "dumbbell_sumo_squat",
     "3 day D2, 4 day D2, 5 day D1, 5 day D4"),
    ("Leg abduction, abduction machine", "side_lying_clamshell",
     "3 day D3, 4 day D3"),
    ("Side kicks", "side_lying_clamshell", "4 day D2"),
    ("Wall sit", "bodyweight_squat_arm_swing", "3 day D2"),
    ("Walking lunges, lunges", "dumbbell_reverse_lunge",
     "3 day D3, 4 day D3, 5 day D1"),
    ("Toe touches", "reach_crunch", "3 day D3, 5 day D5"),
    ("Hollow hold", "flutter_kicks", "3 day D3, 5 day D1"),
    ("Leg raises", "flutter_kicks", "4 day D4"),
    ("Alternating leg switches", "lying_bicycle_legs", "5 day D5"),
    ("Treadmill", "mountain_climbers", "4 day D4, 5 day D5"),
    ("Elliptical", "mountain_climbers", "5 day D3"),
]


# --- the app's own sum ---------------------------------------------------------

def move_seconds(move):
    """The sum `programme_week.dart` uses: 2.5 s a rep or the hold, the rests
    between sets, and 15 s to set up."""
    effort = move.get("holdSeconds") or move["reps"] * 2.5
    return move["sets"] * effort + (move["sets"] - 1) * move["restSeconds"] + 15


def estimated_minutes(moves):
    return sum(move_seconds(m) for m in moves) / 60


def round5(value):
    return int(round(value / 5.0)) * 5


def load_catalogue():
    rows = json.loads(CATALOGUE.read_text(encoding="utf-8"))["exercises"]
    return {r["exerciseId"]: r for r in rows if r.get("clips")}


# --- building ------------------------------------------------------------------

def authored(row, **fields):
    move = {
        "exerciseId": row["exerciseId"],
        "nameEn": fields.pop("name_en", row["name_en"]),
        "nameAr": fields.pop("name_ar", row["name_ar"]),
        "sets": fields.pop("sets"),
    }
    if "hold" in fields:
        move["holdSeconds"] = fields.pop("hold")
    else:
        move["reps"] = fields.pop("reps")
    move.update({
        "restSeconds": fields.pop("rest"),
        "contraindications": list(row["contraindicationTags"]),
        "quiet": bool(row["quiet"]),
        "floorOnly": bool(row["floorOnly"]),
        "needsEquipment": not set(row["equipment"]) <= {"none", "mat"},
    })
    move.update(fields)
    return move


def base_move(spec, tier, catalogue):
    rule = TIER[tier]
    row = catalogue[spec["id"]]
    kind = spec["kind"]
    if kind == CARDIO:
        blocks = spec["minutes"][tier] * 60 // BLOCK_SECONDS
        move = authored(row, name_en=spec["name_en"], name_ar=spec["name_ar"],
                        sets=blocks, hold=BLOCK_SECONDS, rest=CARDIO_REST)
    elif kind == HOLD:
        move = authored(row, sets=rule["sets"], hold=rule["hold"],
                        rest=rule["rest"][HOLD])
    else:
        move = authored(row, sets=rule["sets"], reps=rule["reps"][kind],
                        rest=rule["rest"][kind])
    move["_kind"] = kind
    return move


def fit_day(moves, tier):
    """Bring the day into FIT_LOW..FIT_HIGH minutes: sets first, then rest, and
    sets off the last moves when it runs long. Cardio blocks never change."""
    rule = TIER[tier]
    work = [m for m in moves if m["_kind"] != CARDIO]
    order = ([m for m in work if m["_kind"] == BIG]
             + [m for m in work if m["_kind"] == ISO]
             + [m for m in work if m["_kind"] in (CORE, HOLD)])
    guard = 0
    while estimated_minutes(moves) < FIT_LOW and guard < 200:
        guard += 1
        grew = False
        for m in order:
            if estimated_minutes(moves) >= FIT_LOW:
                break
            if m["sets"] < rule["cap"]:
                m["sets"] += 1
                grew = True
        if grew:
            continue
        for m in order:
            if estimated_minutes(moves) >= FIT_LOW:
                break
            if m["restSeconds"] < rule["rest_max"][m["_kind"]]:
                m["restSeconds"] += 15
                grew = True
        if not grew:
            break
    guard = 0
    while estimated_minutes(moves) > FIT_HIGH and guard < 200:
        guard += 1
        shrank = False
        for m in reversed(order):
            if estimated_minutes(moves) <= FIT_HIGH:
                break
            if m["sets"] > rule["floor"]:
                m["sets"] -= 1
                shrank = True
        if not shrank:
            break


def build_stretch(row):
    assert row["kind"] == "stretch", row["exerciseId"]
    return {
        "exerciseId": row["exerciseId"],
        "nameEn": row["name_en"],
        "nameAr": row["name_ar"],
        "sets": 1,
        "holdSeconds": 30,
        "restSeconds": 0,
        "contraindications": list(row["contraindicationTags"]),
        "quiet": bool(row["quiet"]),
        "floorOnly": bool(row["floorOnly"]),
        "needsEquipment": not set(row["equipment"]) <= {"none", "mat"},
    }


def build_day(day, tier, catalogue):
    session_id, title_en, title_ar, specs, stretch = day
    seen = set()
    moves = []
    for spec in specs:
        assert spec["id"] not in seen, (session_id, spec["id"])
        seen.add(spec["id"])
        moves.append(base_move(spec, tier, catalogue))
    fit_day(moves, tier)
    first = moves[0]
    first["notesEn"] = TIER[tier]["note_en"]
    first["notesAr"] = TIER[tier]["note_ar"]
    for m in moves:
        del m["_kind"]
    moves.append(build_stretch(catalogue[stretch]))
    minutes = estimated_minutes(moves)
    assert MIN_MINUTES <= minutes <= MAX_MINUTES, (tier, session_id, minutes)
    return {
        "sessionId": session_id,
        "titleEn": title_en,
        "titleAr": title_ar,
        "minutes": max(MIN_MINUTES, min(MAX_MINUTES, round5(minutes))),
        "lifeStages": ORDINARY_STAGES,
        "moves": moves,
    }


def build_gentle(spec, catalogue):
    session_id, title_en, title_ar, rows, stretch = spec
    moves = []
    for exercise_id, sets, reps, rest in rows:
        row = catalogue[exercise_id]
        assert not FLOOR_TAGS & set(row["contraindicationTags"]), exercise_id
        move = authored(row, sets=sets, reps=reps, rest=rest)
        move["notesEn"] = GENTLE_EN
        move["notesAr"] = GENTLE_AR
        moves.append(move)
    stretch_row = catalogue[stretch]
    assert not FLOOR_TAGS & set(stretch_row["contraindicationTags"]), stretch
    moves.append(build_stretch(stretch_row))
    minutes = round5(estimated_minutes(moves))
    return {
        "sessionId": session_id,
        "titleEn": title_en,
        "titleAr": title_ar,
        "minutes": max(30, min(45, minutes)),
        "lifeStages": GENTLE_STAGES,
        "moves": moves,
    }


SUMMARY = {
    3: ("Three days a week: upper, lower, lower.",
        "3 أيام في الأسبوع: علوي، سفلي، سفلي."),
    4: ("Four days a week: upper, lower, lower, then core and cardio.",
        "4 أيام في الأسبوع: علوي، سفلي، سفلي، وبعدين كور وكارديو."),
    5: ("Five days a week: glutes and legs, upper, cardio and arms, glutes and "
        "legs, then core with cardio.",
        "5 أيام في الأسبوع: رجلين وأرداف، علوي، كارديو وإيدين، رجلين وأرداف، "
        "وبعدين كور مع كارديو."),
}


def prescription_line(sessions):
    """What a tier asks, read from the days it wrote: the sets and the rests of
    the strength moves (cardio blocks, holds and the stretch are left out), so
    the sentence can never say more or less than the data holds."""
    moves = [
        m for s in sessions for m in s["moves"][:-1]
        if "reps" in m
    ]
    sets = (min(m["sets"] for m in moves), max(m["sets"] for m in moves))
    rest = (min(m["restSeconds"] for m in moves),
            max(m["restSeconds"] for m in moves))
    sets_en = ("%d sets" % sets[0] if sets[0] == sets[1]
               else "%d to %d sets" % sets)
    sets_ar = ("%d مجموعات" % sets[0] if sets[0] == sets[1]
               else "%d لـ %d مجموعات" % sets)
    return (
        " %s, rests of %d to %d seconds." % (sets_en, rest[0], rest[1]),
        " %s، وراحة من %d لـ %d ثانية." % (sets_ar, rest[0], rest[1]),
    )


def build_programme(days, tier, catalogue):
    programme_id = "split_%dday" % days
    title_en = "%d-day split" % days
    title_ar = "سبليت %d أيام" % days
    if tier != "beginner":
        programme_id += "_" + tier
        title_en += " · " + LEVEL_EN[tier]
        title_ar += " · " + LEVEL_AR[tier]
    sessions = [build_day(d, tier, catalogue) for d in SPLITS[days]]
    gentle = [build_gentle(g, catalogue) for g in GENTLE]
    line_en, line_ar = prescription_line(sessions)
    summary_en = SUMMARY[days][0] + line_en
    summary_ar = SUMMARY[days][1] + line_ar
    quiet = all(m["quiet"] for s in sessions for m in s["moves"])
    return {
        "programId": programme_id,
        "titleEn": title_en,
        "titleAr": title_ar,
        "status": "published",
        "version": 1,
        "weeks": 8,
        "daysPerWeek": days,
        "goals": [],
        "places": [],
        "equipment": [],
        "rank": 0,
        "quiet": quiet,
        "summaryEn": summary_en,
        "summaryAr": summary_ar,
        "tier": tier,
        "sessions": sessions + gentle,
    }


def main():
    catalogue = load_catalogue()
    programmes = [
        build_programme(days, tier, catalogue)
        for days in sorted(SPLITS)
        for tier in TIERS
    ]
    for _, _, where in MISSING:
        assert where
    for stand_in in {s for _, s, _ in MISSING}:
        assert stand_in in catalogue, stand_in
    out = {"version": 1, "review": REVIEW, "programmes": programmes}
    PROGRAMMES.write_text(
        json.dumps(out, indent=1, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    for p in programmes:
        print(p["programId"], [
            (s["sessionId"], round(estimated_minutes(s["moves"]), 1),
             len(s["moves"]) - 1)
            for s in p["sessions"] if "gentle" not in s["sessionId"]
        ])
    print("%d programmes written" % len(programmes))


if __name__ == "__main__":
    main()
