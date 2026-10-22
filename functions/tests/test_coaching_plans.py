"""Coach plans: who may publish, what a body may hold, revisions, the chat card."""

import copy
import datetime as dt
import json

import pytest

from coaching import errors, plans
from tests import fake_firestore
from tests.coaching_helpers import Notes, _txn  # noqa: F401

NOW = dt.datetime(2026, 11, 1, 12, tzinfo=dt.timezone.utc)
IDS = {
    "exercises": frozenset({"squat", "plank", "row"}),
    "recipes": frozenset({"rec1"}),
    "foods": frozenset({"rice"}),
}


def _move(**over):
    move = {
        "exerciseId": "squat", "nameEn": "Squat", "nameAr": "سكوات", "sets": 3, "reps": 12,
        "holdSeconds": None, "restSeconds": 60, "notesEn": "", "notesAr": "",
        "safetyEn": "", "safetyAr": "", "contraindications": ["deep_knee_flexion"],
        "quiet": False, "floorOnly": False, "needsEquipment": False,
    }
    move.update(over)
    return move


def _day(n=1, **over):
    day = {
        "session": {
            "sessionId": f"mine_{n}", "titleEn": "Legs", "titleAr": "رجلين", "minutes": 40,
            "lifeStages": ["none"], "moves": [_move(), _move(exerciseId="plank", reps=None, holdSeconds=30)],
        },
        "kg": [20.0, None],
    }
    day.update(over)
    return day


def workout(days=1):
    return {"revision": 1, "name": "Phase one", "days": [_day(n + 1) for n in range(days)]}


def meal():
    return {
        "days": [
            {
                "label": "Day 1",
                "slots": {
                    "breakfast": [{"kind": "recipe", "recipeId": "rec1", "servings": 1.5, "note": "warm"}],
                    "lunch": [{"kind": "food", "foodId": "rice", "grams": 150}],
                    "snack": [{"kind": "free", "text": "A handful of nuts"}],
                },
            }
        ]
    }


def make_db(status="active", coach="coach1"):
    db = fake_firestore.FakeFirestore()
    db.collection("subscriptions").document("sub1").set(
        {"coachUid": coach, "clientUid": "client1", "relId": "coach1__client1", "status": status}
    )
    db.collection("coachPrivate").document("coach1").set({"payoutState": "confirmed"})
    db.collection("coaches").document("coach1").set(
        {"displayName": "Coach One", "stats": {"clientsCoached": 1, "plansShared": 0, "sessionsDone": 0}}
    )
    return db


def publish(db, data, uid="coach1", live=True, coach_v="active", notes=None):
    notes = notes if notes is not None else Notes()
    out = plans.publish(
        db, uid, data, live=live, coach_v=coach_v, now=NOW, notify=notes, content_ids=IDS
    )
    return out, notes


def req(kind="workout", body=None, **over):
    data = {"subId": "sub1", "kind": kind, "name": "My plan",
            "body": body if body is not None else (workout() if kind == "workout" else meal())}
    data.update(over)
    return data


def refused(db, data, reason, **kw):
    before = copy.deepcopy(db.docs)
    with pytest.raises(errors.CoachingError) as caught:
        publish(db, data, **kw)
    assert caught.value.reason == reason
    assert db.docs == before, "nothing is written on a refusal"
    return caught.value


# ---------------------------------------------------------------- happy path --

def test_a_workout_plan_is_published_with_a_chat_card_and_a_push():
    db = make_db()
    out, notes = publish(db, req())
    assert out["revision"] == 1
    plan = db.docs[f"plans/client1/coachPlans/{out['planId']}"]
    assert plan == {
        "kind": "workout", "coachUid": "coach1", "coachName": "Coach One", "subId": "sub1",
        "name": "My plan", "revision": 1, "body": workout(), "publishedAt": NOW,
    }
    cards = [v for k, v in db.docs.items() if k.startswith("relationships/coach1__client1/messages/")]
    assert cards == [{
        "senderUid": "coach1", "type": "workoutPlan", "planId": out["planId"],
        "planKind": "workout", "planName": "My plan", "createdAt": NOW,
    }]
    assert db.docs["coaches/coach1"]["stats"]["plansShared"] == 1
    assert notes.sent == [("client1", "planShared")]


def test_a_meal_plan_is_published_as_a_meal_card():
    db = make_db()
    out, _ = publish(db, req("meal"))
    card = next(v for k, v in db.docs.items() if "/messages/" in k)
    assert card["type"] == "mealPlan" and card["planKind"] == "meal"
    assert db.docs[f"plans/client1/coachPlans/{out['planId']}"]["kind"] == "meal"


def test_publishing_again_with_the_plan_id_bumps_the_revision_only():
    db = make_db()
    first, _ = publish(db, req())
    second, notes = publish(db, req(planId=first["planId"], name="Renamed"))
    assert second == {"planId": first["planId"], "revision": 2}
    assert db.docs[f"plans/client1/coachPlans/{first['planId']}"]["name"] == "Renamed"
    assert db.docs["coaches/coach1"]["stats"]["plansShared"] == 1
    assert notes.sent == [("client1", "planShared")]
    third, _ = publish(db, req(planId=first["planId"]))
    assert third["revision"] == 3
    assert len([k for k in db.docs if "/messages/" in k]) == 3


def test_the_shipped_content_ids_are_used_by_default():
    db = make_db()
    body = {"days": [{"label": "d", "slots": {"lunch": [{"kind": "food", "foodId": "koshary", "grams": 100}]}}]}
    out = plans.publish(db, "coach1", req("meal", body), live=True, coach_v="active", now=NOW, notify=Notes())
    assert out["revision"] == 1


# -------------------------------------------------------------- who may call --

def test_the_coach_app_must_be_live():
    refused(make_db(), req(), errors.COACH_APP_CLOSED, live=False)


@pytest.mark.parametrize("coach_v,reason", [("suspended", errors.COACH_SUSPENDED), (None, errors.NOT_A_COACH)])
def test_only_an_active_coach_publishes(coach_v, reason):
    refused(make_db(), req(), reason, coach_v=coach_v)


def test_a_subscription_of_another_coach_is_not_found():
    db = make_db(coach="someone_else")
    refused(db, req(), errors.REQUEST_NOT_FOUND)


def test_a_missing_subscription_is_not_found():
    refused(make_db(), req(subId="nope"), errors.REQUEST_NOT_FOUND)


@pytest.mark.parametrize("status", ["requested", "awaiting_payment", "payment_review", "ended", "ended_early", "cancelled"])
def test_only_an_active_subscription_takes_a_plan(status):
    refused(make_db(status), req(), errors.WRONG_STATUS)


# ------------------------------------------------------------------ the shell --

@pytest.mark.parametrize(
    "over",
    [
        {"kind": "diet"}, {"kind": None}, {"name": ""}, {"name": "   "}, {"name": "x" * 61},
        {"name": 5}, {"subId": ""}, {"subId": None}, {"planId": 3}, {"planId": "a/b"},
    ],
)
def test_a_bad_shell_is_refused(over):
    refused(make_db(), req(**over), errors.BAD_REQUEST)


def test_a_plan_id_of_another_subscription_is_not_found():
    db = make_db()
    db.collection("plans").document("client1").collection("coachPlans").document("p9").set(
        {"kind": "workout", "coachUid": "coach1", "subId": "other", "revision": 4}
    )
    refused(db, req(planId="p9"), errors.REQUEST_NOT_FOUND)


def test_a_plan_id_of_another_coach_is_not_found():
    db = make_db()
    db.collection("plans").document("client1").collection("coachPlans").document("p9").set(
        {"kind": "workout", "coachUid": "other", "subId": "sub1", "revision": 4}
    )
    refused(db, req(planId="p9"), errors.REQUEST_NOT_FOUND)


def test_a_revision_cannot_change_the_kind():
    db = make_db()
    first, _ = publish(db, req())
    refused(db, req("meal", planId=first["planId"]), errors.PLAN_INVALID)


# ------------------------------------------------------------------- workout --

def _with_move(**over):
    body = workout()
    body["days"][0]["session"]["moves"][0].update(over)
    return body


@pytest.mark.parametrize(
    "body",
    [
        [], "x", {}, {"days": []}, {"days": "x"},
        {"days": [_day(1)], "extra": 1},
        {"days": [_day(n) for n in range(1, 9)]},
        {"days": [_day(1), _day(1)]},
        {"days": [{"session": _day()["session"], "kg": [], "extra": 1}]},
        {"days": ["x"]},
        {"days": [{"kg": []}]},
        _with_move(exerciseId="not_in_the_library"),
        _with_move(exerciseId=7),
        _with_move(sets=0), _with_move(sets=11), _with_move(sets=True), _with_move(sets=2.5),
        _with_move(reps=0), _with_move(reps=101),
        _with_move(reps=10, holdSeconds=30),
        _with_move(reps=None, holdSeconds=None),
        _with_move(reps=None, holdSeconds=4), _with_move(reps=None, holdSeconds=601),
        _with_move(restSeconds=-1), _with_move(restSeconds=601),
        _with_move(notesEn="x" * 301), _with_move(safetyAr="x" * 301),
        _with_move(nameEn="x" * 81),
        _with_move(contraindications=["made_up"]), _with_move(contraindications="none"),
        _with_move(contraindications=["none"] * 21),
        _with_move(quiet="yes"),
        _with_move(kcal=100),
        _with_move(unknownKey=1),
    ],
)
def test_a_bad_workout_body_is_refused(body):
    refused(make_db(), req("workout", body), errors.PLAN_INVALID)


def _with_session(**over):
    body = workout()
    body["days"][0]["session"].update(over)
    return body


@pytest.mark.parametrize(
    "body",
    [
        _with_session(minutes=0), _with_session(minutes=181), _with_session(minutes="40"),
        _with_session(moves=[]), _with_session(moves=[_move()] * 21),
        _with_session(sessionId=""), _with_session(sessionId="x" * 41),
        _with_session(titleEn="x" * 41),
        _with_session(lifeStages=["robot"]), _with_session(lifeStages="none"),
        _with_session(extra=1),
        {"days": [dict(_day(), kg=[1, 2, 3])]},
        {"days": [dict(_day(), kg=[0.5, None])]},
        {"days": [dict(_day(), kg=[201, None])]},
        {"days": [dict(_day(), kg=["a", None])]},
        {"days": [dict(_day(), sourceId="x" * 65)]},
        {"revision": 0, "days": [_day()]},
        {"name": "x" * 61, "days": [_day()]},
    ],
)
def test_a_bad_workout_session_is_refused(body):
    refused(make_db(), req("workout", body), errors.PLAN_INVALID)


def test_workout_bounds_are_inclusive():
    db = make_db()
    body = {"days": [_day(n) for n in range(1, 8)]}
    for day in body["days"]:
        day["session"]["moves"] = [
            _move(sets=10, reps=100, restSeconds=600),
            _move(exerciseId="row", sets=1, reps=None, holdSeconds=600, restSeconds=0),
            _move(exerciseId="plank", reps=1, notesEn="x" * 300),
        ]
        day["session"]["minutes"] = 180
        day["kg"] = [200, 1, None]
    publish(db, req("workout", body))


def test_a_minimal_move_is_fine():
    body = {"days": [{"session": {"sessionId": "d1", "minutes": 20, "moves": [
        {"exerciseId": "squat", "sets": 2, "reps": 10}]}}]}
    publish(make_db(), req("workout", body))


# ---------------------------------------------------------------------- meal --

def _meal_item(item, slot="lunch"):
    return {"days": [{"label": "d", "slots": {slot: [item]}}]}


@pytest.mark.parametrize(
    "body",
    [
        {}, {"days": []}, {"days": [meal()["days"][0]] * 8}, {"days": "x"},
        {"days": [{"label": "d", "slots": {}}], "extra": 1},
        {"days": [{"label": "", "slots": {}}]},
        {"days": [{"label": "x" * 41, "slots": {}}]},
        {"days": [{"label": "d"}]},
        {"days": [{"label": "d", "slots": {}, "kcal": 10}]},
        {"days": [{"label": "d", "slots": {"brunch": []}}]},
        {"days": [{"label": "d", "slots": {"lunch": "x"}}]},
        {"days": [{"label": "d", "slots": {"lunch": ["x"]}}]},
        {"days": [{"label": "d", "slots": {"lunch": [{"kind": "food", "foodId": "rice", "grams": 10}] * 13}}]},
        _meal_item({"kind": "drink", "text": "tea"}),
        _meal_item({"kind": "recipe", "recipeId": "ghost", "servings": 1}),
        _meal_item({"kind": "recipe", "recipeId": "rec1", "servings": 0.2}),
        _meal_item({"kind": "recipe", "recipeId": "rec1", "servings": 6.5}),
        _meal_item({"kind": "recipe", "recipeId": "rec1"}),
        _meal_item({"kind": "recipe", "recipeId": "rec1", "servings": True}),
        _meal_item({"kind": "recipe", "recipeId": "rec1", "servings": 1, "grams": 5}),
        _meal_item({"kind": "food", "foodId": "ghost", "grams": 100}),
        _meal_item({"kind": "food", "foodId": "rice", "grams": 0}),
        _meal_item({"kind": "food", "foodId": "rice", "grams": 2001}),
        _meal_item({"kind": "food", "foodId": "rice", "grams": float("nan")}),
        _meal_item({"kind": "food", "foodId": "rice", "grams": 100, "servings": 1}),
        _meal_item({"kind": "free", "text": ""}),
        _meal_item({"kind": "free", "text": "   "}),
        _meal_item({"kind": "free", "text": "x" * 81}),
        _meal_item({"kind": "free", "text": "tea", "foodId": "rice"}),
        _meal_item({"kind": "free", "text": "tea", "note": "x" * 121}),
        _meal_item({"kind": "free", "text": "tea", "note": 5}),
    ],
)
def test_a_bad_meal_body_is_refused(body):
    refused(make_db(), req("meal", body), errors.PLAN_INVALID)


def test_meal_bounds_are_inclusive():
    body = {"days": [{"label": "x" * 40, "slots": {
        "breakfast": [{"kind": "recipe", "recipeId": "rec1", "servings": 0.25, "note": "n" * 120}],
        "dinner": [{"kind": "recipe", "recipeId": "rec1", "servings": 6}],
        "lunch": [{"kind": "food", "foodId": "rice", "grams": 1}, {"kind": "food", "foodId": "rice", "grams": 2000}],
        "snack": [{"kind": "free", "text": "x" * 80}],
    }}] * 7}
    publish(make_db(), req("meal", body))


@pytest.mark.parametrize("key", ["kcal", "calories", "protein", "carbs", "fat", "fibre", "fiber", "macros", "Calories", "KCAL"])
def test_nutrition_keys_are_refused_at_any_depth(key):
    top = meal()
    top[key] = 1
    deep = meal()
    deep["days"][0]["slots"]["lunch"][0][key] = {"x": 1}
    deeper = meal()
    deeper["days"][0]["slots"]["lunch"][0]["note"] = "ok"
    deeper["days"][0]["slots"]["snack"][0]["extra"] = [{"inner": {key: 1}}]
    for body in (top, deep, deeper):
        refused(make_db(), req("meal", body), errors.PLAN_INVALID)


def test_nutrition_words_in_free_text_are_only_text():
    body = _meal_item({"kind": "free", "text": "high protein yoghurt"})
    publish(make_db(), req("meal", body))


# ---------------------------------------------------------------------- size --

def test_a_body_over_the_size_limit_is_too_large():
    body = workout()
    body["days"][0]["session"]["moves"] = [_move(notesEn="x" * 300, notesAr="y" * 300)] * 20
    body["days"] = [copy.deepcopy(body["days"][0]) for _ in range(7)]
    for n, day in enumerate(body["days"]):
        day["session"]["sessionId"] = f"d{n}"
    assert len(json.dumps(body)) > 60000
    refused(make_db(), req("workout", body), errors.PLAN_TOO_LARGE)


def test_a_non_json_body_is_invalid_not_a_crash():
    body = workout()
    body["name"] = object()
    refused(make_db(), req("workout", body), errors.PLAN_INVALID)


def test_a_deeply_nested_body_is_invalid_not_a_crash():
    body = current = {}
    for _ in range(5000):
        current["a"] = {}
        current = current["a"]
    refused(make_db(), req("workout", body), errors.PLAN_INVALID)


def test_a_missing_body_is_invalid():
    data = req()
    del data["body"]
    refused(make_db(), data, errors.PLAN_INVALID)


def test_size_is_measured_as_escaped_json_so_arabic_counts_six_per_letter():
    body = workout()
    body["days"][0]["session"]["moves"] = [_move(notesAr="س" * 300)] * 20
    body["days"] = [copy.deepcopy(body["days"][0]) for _ in range(2)]
    for n, day in enumerate(body["days"]):
        day["session"]["sessionId"] = f"d{n}"
    assert len(json.dumps(body, ensure_ascii=False).encode("utf-8")) < 60000 < len(json.dumps(body))
    refused(make_db(), req("workout", body), errors.PLAN_TOO_LARGE)


def test_a_suspended_coach_with_a_valid_claim_cannot_publish():
    db = make_db()
    db.collection("coachPrivate").document("coach1").update({"suspended": True})
    refused(db, req(), errors.COACH_SUSPENDED)


@pytest.mark.parametrize("blocker, blocked", [("client1", "coach1"), ("coach1", "client1")])
def test_a_block_either_way_stops_a_plan(blocker, blocked):
    db = make_db()
    db.collection("users").document(blocker).collection("blocks").document(blocked).set({})
    refused(db, req(), "coach_unavailable")
