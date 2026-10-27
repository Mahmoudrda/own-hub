"""A coach publishes a workout or meal plan to one of her clients.

The plan lands at `plans/{clientUid}/coachPlans/{planId}`, where the client's
phone shows it on Home, Train and Eat, and a card for it goes into their chat.
Publishing again with the same `planId` is a new revision of the same plan.

The body is checked against the shapes the phone reads. A workout is the
`MyPlan.toJson()` shape (app/lib/features/train/domain/my_plan.dart, the
exercise and its limits in workout_library.dart); a meal plan is days of slots
holding recipes, foods or free text. A meal plan carries no nutrition figures:
the phone works those out from the verified food pack and recipe library.
"""

from __future__ import annotations

import datetime as dt
import functools
import hashlib
import json
import math
import os
import zoneinfo
from typing import Any, Optional

from google.cloud import firestore

from . import common, errors, subscriptions

_HERE = os.path.dirname(os.path.abspath(__file__))
_IDS_PATH = os.path.join(_HERE, "content_ids.json")
_LIBRARY_CONTRACT = os.path.join(os.path.dirname(_HERE), "exercise_library_contract.json")

LIMITS = common.LIMITS
ENUMS = common.ENUMS

# The member app's own bounds (workout_library.dart WorkoutLimits, custom_workout.dart).
MIN_SETS, MAX_SETS = 1, 10
MIN_REPS, MAX_REPS = 1, 100
MIN_HOLD, MAX_HOLD = 5, 600
MAX_REST = 600
MAX_MINUTES = 180
MAX_MOVES = 20
MAX_TEXT = 300
MAX_MOVE_NAME = 80
MAX_DAY_TITLE = 40
MAX_KG = 200
MAX_TAGS = 20

MAX_DAY_LABEL = 40
MAX_ITEMS_PER_SLOT = 12
MAX_ITEM_NOTE = 120
MAX_FREE_TEXT = 80
SERVINGS = (0.25, 6)
GRAMS = (1, 2000)
GOAL_KCAL = (1200, 4000)
GOAL_PROTEIN_G = (30, 250)
# Mirrors TargetSafety in app/lib/domain/nutrition/target_safety.dart. The server
# has no age or body data (D31), so it holds a goal for a pregnant or postpartum
# client until her coach has read her health answers, and keeps it above a
# deficit-sized figure.
MAX_PROTEIN_SHARE = 0.35
STAGE_GOAL_KCAL_FLOOR = 1800
MAX_SWAPS = 3

NUTRITION_KEYS = frozenset(
    {"kcal", "calories", "protein", "carbs", "fat", "fibre", "fiber", "macros"}
)

_PLAN_KEYS = {"source", "name", "revision", "days"}
_DAY_KEYS = {"session", "sourceId", "kg", "week"}
_SESSION_KEYS = {"sessionId", "titleEn", "titleAr", "minutes", "lifeStages", "moves"}
_MOVE_KEYS = {
    "exerciseId", "nameEn", "nameAr", "sets", "reps", "holdSeconds", "restSeconds",
    "notesEn", "notesAr", "safetyEn", "safetyAr", "contraindications", "quiet",
    "floorOnly", "needsEquipment", "supersetWithNext",
}
_LIFE_STAGES = {"none", "postpartum", "pregnant", "pain_injury"}


@functools.lru_cache(maxsize=1)
def _tags() -> frozenset:
    with open(_LIBRARY_CONTRACT, encoding="utf-8") as handle:
        return frozenset(json.load(handle)["contraindicationTags"])


@functools.lru_cache(maxsize=1)
def _shipped_ids() -> dict:
    with open(_IDS_PATH, encoding="utf-8") as handle:
        raw = json.load(handle)
    return {kind: frozenset(raw[kind]) for kind in ("exercises", "recipes", "foods")}


def load_content_ids() -> dict:
    """{"exercises", "recipes", "foods"}: the ids a plan may name, built from
    the app's content by tools/build_coaching_content_ids.py."""
    return _shipped_ids()


def _check(ok: bool) -> None:
    if not ok:
        raise common.bad(errors.PLAN_INVALID)


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def _in_range(value: Any, low, high) -> bool:
    return _is_number(value) and low <= value <= high


def _string(value: Any, *, max_len: int, min_len: int = 0) -> str:
    _check(isinstance(value, str) and min_len <= len(value) <= max_len)
    return value


def _keys_within(row: Any, allowed) -> dict:
    _check(isinstance(row, dict))
    _check(all(isinstance(k, str) and k in allowed for k in row))
    return row


def _has_nutrition_key(node: Any) -> bool:
    stack = [node]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            for key, value in current.items():
                if isinstance(key, str) and key.lower() in NUTRITION_KEYS:
                    return True
                stack.append(value)
        elif isinstance(current, list):
            stack.extend(current)
    return False


# ------------------------------------------------------------------ workout --

def _check_move(move: Any, exercises) -> None:
    _keys_within(move, _MOVE_KEYS)
    _check(isinstance(move.get("exerciseId"), str) and move["exerciseId"] in exercises)
    for key in ("nameEn", "nameAr"):
        if key in move:
            _string(move[key], max_len=MAX_MOVE_NAME)
    for key in ("notesEn", "notesAr", "safetyEn", "safetyAr"):
        if key in move:
            _string(move[key], max_len=MAX_TEXT)
    _check(_is_int(move.get("sets")) and MIN_SETS <= move["sets"] <= MAX_SETS)
    reps, hold = move.get("reps"), move.get("holdSeconds")
    # Exactly one of reps and a hold.
    _check((reps is None) != (hold is None))
    if reps is not None:
        _check(_is_int(reps) and MIN_REPS <= reps <= MAX_REPS)
    else:
        _check(_is_int(hold) and MIN_HOLD <= hold <= MAX_HOLD)
    rest = move.get("restSeconds", 60)
    _check(_is_int(rest) and 0 <= rest <= MAX_REST)
    tags = move.get("contraindications", [])
    _check(isinstance(tags, list) and len(tags) <= MAX_TAGS)
    _check(all(isinstance(t, str) and t in _tags() for t in tags))
    for key in ("quiet", "floorOnly", "needsEquipment", "supersetWithNext"):
        if key in move:
            _check(isinstance(move[key], bool))


def _check_day(day: Any, exercises, seen_sessions: set) -> None:
    _keys_within(day, _DAY_KEYS)
    session = _keys_within(day.get("session"), _SESSION_KEYS)
    session_id = _string(session.get("sessionId"), min_len=1, max_len=40)
    _check(session_id not in seen_sessions)
    seen_sessions.add(session_id)
    for key in ("titleEn", "titleAr"):
        _string(session.get(key, ""), max_len=MAX_DAY_TITLE)
    _check(
        _is_int(session.get("minutes")) and 1 <= session["minutes"] <= MAX_MINUTES
    )
    stages = session.get("lifeStages", [])
    _check(isinstance(stages, list) and all(s in _LIFE_STAGES for s in stages))
    moves = session.get("moves")
    _check(isinstance(moves, list) and 1 <= len(moves) <= MAX_MOVES)
    for move in moves:
        _check_move(move, exercises)
    if "sourceId" in day:
        _string(day["sourceId"], max_len=64)
    kg = day.get("kg", [])
    _check(isinstance(kg, list) and len(kg) <= len(moves))
    _check(all(v is None or _in_range(v, 1, MAX_KG) for v in kg))


def _check_workout(body: dict, ids: dict) -> None:
    _keys_within(body, _PLAN_KEYS)
    if "source" in body:
        _string(body["source"], max_len=64)
    if "name" in body:
        _string(body["name"], max_len=LIMITS["planNameMax"])
    if "revision" in body:
        _check(_is_int(body["revision"]) and body["revision"] > 0)
    days = body.get("days")
    max_days = LIMITS["planMaxDays"] * LIMITS["planMaxWeeks"]
    _check(isinstance(days, list) and 1 <= len(days) <= max_days)
    seen: set = set()
    for day in days:
        _check_day(day, ids["exercises"], seen)
    weeks = [d.get("week", 1) for d in days]
    _check(all(_is_int(w) and 1 <= w <= LIMITS["planMaxWeeks"] for w in weeks))
    # No gaps, and at most a week's worth of days in each.
    _check(set(weeks) == set(range(1, max(weeks) + 1)))
    _check(all(weeks.count(w) <= LIMITS["planMaxDays"] for w in set(weeks)))


# --------------------------------------------------------------------- meal --

def _check_item(item: Any, ids: dict) -> None:
    _check(isinstance(item, dict))
    kind = item.get("kind")
    _check(kind in ENUMS["mealItemKind"])
    if kind == "recipe":
        _keys_within(item, {"kind", "recipeId", "servings", "note", "swaps"})
        _check(isinstance(item.get("recipeId"), str) and item["recipeId"] in ids["recipes"])
        _check(_in_range(item.get("servings"), *SERVINGS))
        swaps = item.get("swaps", [])
        _check(isinstance(swaps, list) and len(swaps) <= MAX_SWAPS)
        _check(all(isinstance(s, str) and s in ids["recipes"] and s != item["recipeId"] for s in swaps))
        _check(len(set(swaps)) == len(swaps))
    elif kind == "food":
        _keys_within(item, {"kind", "foodId", "grams", "note"})
        _check(isinstance(item.get("foodId"), str) and item["foodId"] in ids["foods"])
        _check(_in_range(item.get("grams"), *GRAMS))
    else:
        _keys_within(item, {"kind", "text", "note"})
        text = _string(item.get("text"), min_len=1, max_len=MAX_FREE_TEXT)
        _check(text.strip() != "")
    if "note" in item:
        _string(item["note"], max_len=MAX_ITEM_NOTE)


def _check_meal(body: dict, ids: dict) -> None:
    _keys_within(body, {"days", "goal"})
    days = body.get("days")
    _check(isinstance(days, list) and 1 <= len(days) <= LIMITS["planMaxDays"])
    for day in days:
        _keys_within(day, {"label", "slots"})
        _string(day.get("label"), min_len=1, max_len=MAX_DAY_LABEL)
        slots = day.get("slots")
        _keys_within(slots, ENUMS["mealSlots"])
        for items in slots.values():
            _check(isinstance(items, list) and len(items) <= MAX_ITEMS_PER_SLOT)
            for item in items:
                _check_item(item, ids)
    goal = body.get("goal")
    if goal is not None:
        _check(isinstance(goal, dict))
        _keys_within(goal, {"kcalPerDay", "proteinGPerDay"})
        _check(_is_int(goal.get("kcalPerDay")) and GOAL_KCAL[0] <= goal["kcalPerDay"] <= GOAL_KCAL[1])
        _check(_is_int(goal.get("proteinGPerDay")) and GOAL_PROTEIN_G[0] <= goal["proteinGPerDay"] <= GOAL_PROTEIN_G[1])
        _check(goal["proteinGPerDay"] * 4 <= MAX_PROTEIN_SHARE * goal["kcalPerDay"])


def check_body(kind: str, body: Any, ids: dict) -> None:
    """Raises plan_invalid or plan_too_large; returns when the body is fine."""
    _check(isinstance(body, dict))
    try:
        size = len(json.dumps(body))
    except (TypeError, ValueError, RecursionError):
        raise common.bad(errors.PLAN_INVALID)
    if size > LIMITS["planBodyMaxBytes"]:
        raise common.refuse(errors.INVALID, errors.PLAN_TOO_LARGE)
    if kind == "meal":
        _check(not _has_nutrition_key(body))
        _check_meal(body, ids)
    else:
        _check_workout(body, ids)


CAIRO = zoneinfo.ZoneInfo("Africa/Cairo")
MAX_START_DAYS_AHEAD = 60


def start_date(value: Any, now: dt.datetime) -> Optional[str]:
    """None when absent; else a Cairo date string from today to 60 days ahead."""
    if value is None:
        return None
    _check(isinstance(value, str) and len(value) == 10)
    try:
        day = dt.date.fromisoformat(value)
    except ValueError:
        raise common.bad(errors.PLAN_INVALID)
    today = now.astimezone(CAIRO).date()
    _check(today <= day <= today + dt.timedelta(days=MAX_START_DAYS_AHEAD))
    return value


def cairo_today(now: dt.datetime) -> str:
    return now.astimezone(CAIRO).date().isoformat()


def plan_weeks(kind: str, body: dict) -> int:
    """Weeks a checked body spans: a workout's highest `week`, else 1."""
    if kind != "workout":
        return 1
    return max(day.get("week", 1) for day in body["days"])


def replay_id(uid: str, sub_id: str, key: str, now: dt.datetime) -> str:
    """The plan document a `requestKey` always lands on, for one Cairo day: the
    same coach sending the same plan to the same client again (a retry after a
    timeout, or Back and send once more) finds the plan it already made rather
    than making a second one with a second chat card and push."""
    raw = f"{uid}|{sub_id}|{key}|{cairo_today(now)}".encode("utf-8")
    return "k" + hashlib.sha256(raw).hexdigest()[:30]


# ------------------------------------------------------------------ publish --

def health_hold_mandatory(db) -> bool:
    """The owner's switch (coachingConfig/plans.healthHoldMandatory, off when
    missing): once version 1.0.0, which cannot clear the health hold, is gone,
    turning it on makes the hold apply to every send, whatever the app says."""
    snap = db.collection("coachingConfig").document("plans").get()
    return snap.exists and (snap.to_dict() or {}).get("healthHoldMandatory") is True


def publish(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    coach_v: Any,
    now: dt.datetime,
    notify: common.Notify,
    content_ids: Optional[dict] = None,
) -> dict:
    """Publishes a plan (or a new revision of one) to the client of one of her
    active subscriptions. Returns {"planId", "revision"}."""
    common.require_clients_live(live)
    common.require_active_coach(db, uid, coach_v)

    sub_id = common.text(data.get("subId"), max_len=128)
    kind = common.one_of(data.get("kind"), ENUMS["planKind"])
    name = common.text(data.get("name"), max_len=LIMITS["planNameMax"])
    plan_id = data.get("planId")
    if plan_id is not None:
        plan_id = common.text(plan_id, max_len=128)
        if "/" in plan_id:
            raise common.bad()
    body = data.get("body")
    check_body(kind, body, content_ids if content_ids is not None else load_content_ids())
    starts_on = start_date(data.get("startsOn"), now)
    # A plan of several weeks needs a day one, or week two never arrives.
    if starts_on is None and plan_id is None and plan_weeks(kind, body) > 1:
        starts_on = cairo_today(now)
    request_key = data.get("requestKey")
    if request_key is not None:
        request_key = common.text(request_key, min_len=8, max_len=64)
    # Sent only by builds that can clear the health hold (review_client_health).
    # Older builds cannot, so holding their coach here would strand her.
    reviews_health = data.get("reviewsHealth") is True or health_hold_mandatory(db)

    sub_ref = db.collection("subscriptions").document(sub_id)
    coach_ref = db.collection("coaches").document(uid)

    def txn(transaction):
        sub = common.read(sub_ref, transaction)
        if sub is None or sub.get("coachUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if sub.get("status") != "active":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        intake = sub.get("intake") or {}
        if (
            reviews_health
            and subscriptions.intake_flagged(intake)
            and not sub.get("healthReviewedAt")
        ):
            raise common.refuse(errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)
        client_uid = sub.get("clientUid")
        if subscriptions.blocked_either(transaction, db, uid, client_uid):
            raise common.refuse(errors.PRECONDITION, errors.COACH_UNAVAILABLE)
        if kind == "meal" and body.get("goal") is not None:
            intake = sub.get("intake") or {}
            health = intake.get("health") or {}
            eating = intake.get("eatingHistory") is True or (
                isinstance(health, dict) and health.get("eatingHistory") is True
            )
            if eating:
                raise common.refuse(errors.PRECONDITION, errors.EATING_HISTORY_HOLD)
            if intake.get("lifeStage") in subscriptions.FLAGGED_STAGES:
                if not sub.get("healthReviewedAt"):
                    raise common.refuse(errors.PRECONDITION, errors.HEALTH_NOT_REVIEWED)
                if body["goal"]["kcalPerDay"] < STAGE_GOAL_KCAL_FLOOR:
                    raise common.bad(errors.PLAN_INVALID)
        plans = db.collection("plans").document(client_uid).collection("coachPlans")

        if plan_id is None:
            if request_key is None:
                plan_ref = plans.document()
            else:
                plan_ref = plans.document(replay_id(uid, sub_id, request_key, now))
                made = common.read(plan_ref, transaction)
                if made is not None:
                    if made.get("coachUid") != uid or made.get("subId") != sub_id:
                        raise common.bad(errors.PLAN_INVALID)
                    return plan_ref.id, int(made.get("revision") or 1), client_uid, True
            revision, new, starts = 1, True, starts_on
        else:
            plan_ref = plans.document(plan_id)
            current = common.read(plan_ref, transaction)
            if (
                current is None
                or current.get("subId") != sub_id
                or current.get("coachUid") != uid
            ):
                raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
            if current.get("kind") != kind:
                raise common.bad(errors.PLAN_INVALID)
            revision, new = int(current.get("revision") or 0) + 1, False
            # Sending again without a date keeps the one the plan started on.
            starts = starts_on or current.get("startsOn")

        coach = common.read(coach_ref, transaction)
        coach_name = coach.get("displayName") if coach is not None else ""

        transaction.set(
            plan_ref,
            {
                "kind": kind,
                "coachUid": uid,
                "coachName": coach_name if isinstance(coach_name, str) else "",
                "subId": sub_id,
                "name": name,
                "revision": revision,
                "body": body,
                "publishedAt": now,
                **({"startsOn": starts} if starts else {}),
            },
        )
        transaction.set(
            db.collection("relationships").document(sub["relId"]).collection("messages").document(),
            {
                "senderUid": uid,
                "type": "workoutPlan" if kind == "workout" else "mealPlan",
                "planId": plan_ref.id,
                "planKind": kind,
                "planName": name,
                "createdAt": now,
            },
        )
        if new and coach is not None:
            transaction.update(coach_ref, {"stats.plansShared": firestore.Increment(1)})
        return plan_ref.id, revision, client_uid, False

    plan_id_out, revision_out, client_uid, replayed = common.run(db, txn)
    if not replayed:
        notify(client_uid, "planShared")
    return {"planId": plan_id_out, "revision": revision_out}
