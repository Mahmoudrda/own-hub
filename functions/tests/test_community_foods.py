"""Community foods: a woman offers a confirmed meal, the owner approves it into
meta/communityFoods, and her account's markers go with her."""

from __future__ import annotations

import json

import pytest
from firebase_functions import https_fn

import main
from account import deletion
from identity import reasons, store
from nutrition import community_foods as cf
from tests import fake_firestore
from tests.fake_firestore import FakeFirestore
from tests.test_entrypoints import inner, raises, request

HER, OTHER = "uid-her", "uid-two"
VERIFIED = {"verified": True}
ADMIN = {"admin": True}
PEPPER = b"test-pepper"


def food(**changes):
    row = {
        "nameEn": "Koshary",
        "nameAr": "كشري",
        "items": [{"name": "rice", "grams": 200}, {"name": "lentils", "grams": 100}],
        "kcal": 520,
        "proteinG": 18,
        "carbsG": 90,
        "fatG": 9,
    }
    row.update(changes)
    return row


@pytest.fixture
def db(monkeypatch):
    fake = FakeFirestore()
    monkeypatch.setattr(main.store, "db", lambda: fake)
    monkeypatch.setattr(main.store, "pepper", lambda: PEPPER)
    monkeypatch.setattr(cf.firestore, "transactional", fake_firestore.transactional)
    counts = {}

    def per_uid(uid, field):
        counts[uid] = counts.get(uid, 0) + 1
        return counts[uid]

    monkeypatch.setattr(main.store, "uid_daily_count_and_increment", per_uid)
    return fake


def submit(data, uid=HER, token=VERIFIED, **kw):
    return inner("submit_community_food")(request(data, uid=uid, token=token, **kw))


def candidates(db):
    return {p: d for p, d in db.docs.items() if p.startswith("communityFoodCandidates/") and "/by/" not in p}


def markers(db):
    return [p for p in db.docs if "/by/" in p]


# ------------------------------------------------------------ a woman offers


def test_a_verified_woman_offers_a_food_and_it_is_stored_with_no_uid(db):
    assert submit(food()) == {"ok": True}
    ((path, row),) = candidates(db).items()
    assert row["confirmCount"] == 1 and row["status"] == "pending"
    assert row["kcal"] == 520 and row["items"][0] == {"name": "rice", "grams": 200.0}
    assert HER not in json.dumps(row, default=str) and "uid" not in row
    (marker,) = markers(db)
    assert marker.startswith(path + "/by/") and HER not in marker
    assert db.docs[marker] == {"v": 1}


def test_one_confirmation_per_woman_and_a_second_woman_counts(db):
    submit(food())
    submit(food())
    ((path, row),) = candidates(db).items()
    assert row["confirmCount"] == 1
    submit(food(), uid=OTHER)
    assert db.docs[path]["confirmCount"] == 2
    assert len(markers(db)) == 2


def test_the_same_dish_typed_with_other_case_and_marks_is_one_candidate(db):
    submit(food(nameEn=" KOSHARY "))
    submit(food(nameEn="koshary"), uid=OTHER)
    assert len(candidates(db)) == 1
    assert cf.candidate_key(None, "كُشري") == cf.candidate_key(None, "كشري")


def test_first_macros_are_kept(db):
    submit(food())
    submit(food(kcal=560, proteinG=20), uid=OTHER)
    ((_, row),) = candidates(db).items()
    assert row["kcal"] == 520 and row["confirmCount"] == 2


def test_an_arabic_only_food_is_accepted(db):
    submit(food(nameEn=None))
    ((_, row),) = candidates(db).items()
    assert "nameEn" not in row and row["nameAr"] == "كشري"


@pytest.mark.parametrize(
    "changes",
    [
        {"nameEn": None, "nameAr": None},
        {"nameEn": "x" * 61},
        {"nameEn": "!!!", "nameAr": None},
        {"items": []},
        {"items": [{"name": "rice", "grams": 10}] * 13},
        {"items": [{"name": "rice", "grams": 0}]},
        {"items": [{"name": "rice", "grams": 3001}]},
        {"items": [{"name": "", "grams": 10}]},
        {"items": "rice"},
        {"kcal": 0},
        {"kcal": -5},
        {"kcal": True},
        {"kcal": float("nan")},
        {"proteinG": -1},
        {"fatG": "9"},
        {"kcal": 900},
        {"kcal": 100},
    ],
)
def test_a_food_outside_the_pack_rules_is_refused(db, changes):
    error = raises(lambda: submit(food(**changes)), https_fn.FunctionsErrorCode.INVALID_ARGUMENT)
    assert error.message == reasons.COMMUNITY_FOOD_INVALID
    assert not candidates(db)


def test_atwater_allows_the_pack_tolerance(db):
    submit(food(kcal=520 + 20))
    assert len(candidates(db)) == 1


def test_a_body_that_is_not_an_object_is_refused(db):
    raises(lambda: submit([1]), https_fn.FunctionsErrorCode.INVALID_ARGUMENT)


def test_an_unverified_account_and_a_missing_app_check_are_refused(db):
    error = raises(lambda: submit(food(), token={}), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
    assert error.message == reasons.NOT_VERIFIED
    raises(lambda: submit(food(), app=False), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    raises(lambda: submit(food(), uid=None), https_fn.FunctionsErrorCode.UNAUTHENTICATED)
    assert not candidates(db)


def test_the_eleventh_food_of_the_day_is_refused(db):
    for n in range(10):
        submit(food(nameEn=f"dish {n}"))
    error = raises(lambda: submit(food(nameEn="dish 10")), https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED)
    assert error.message == reasons.COMMUNITY_FOOD_DAILY_LIMIT
    assert len(candidates(db)) == 10


def test_a_decided_candidate_is_not_counted_again(db):
    submit(food())
    ((path, _),) = candidates(db).items()
    db.docs[path]["status"] = "rejected"
    submit(food(), uid=OTHER)
    assert db.docs[path]["confirmCount"] == 1 and len(markers(db)) == 1


# --------------------------------------------------------------- the owner


def review(data, token=ADMIN, **kw):
    return inner("review_community_food")(request(data, uid="uOwner", token=token, **kw))


def listing(token=ADMIN, **kw):
    return inner("list_community_foods")(request({}, uid="uOwner", token=token, **kw))


APPROVE = {
    "action": "approve",
    "nameEn": "Koshary",
    "nameAr": "كشري",
    "category": "egyptianDishes",
    "allergens": ["gluten"],
}


def one_candidate(db, **changes):
    submit(food(**changes))
    return next(iter(candidates(db)))[len("communityFoodCandidates/"):]


def test_the_list_orders_by_confirmations_and_carries_the_vocabularies(db):
    submit(food(nameEn="Fatta"))
    submit(food(nameEn="Koshary"))
    submit(food(nameEn="Koshary"), uid=OTHER)
    answer = listing()
    assert [c["nameEn"] for c in answer["candidates"]] == ["Koshary", "Fatta"]
    assert answer["candidates"][0]["confirmCount"] == 2
    assert answer["published"] == []
    assert "egyptianDishes" in answer["vocab"]["categories"] and "tree_nuts" in answer["vocab"]["allergens"]
    assert "uid" not in json.dumps(answer)


def test_approving_publishes_the_food_and_bumps_the_version(db):
    key = one_candidate(db)
    assert review({"key": key, **APPROVE}) == {"ok": True, "version": 1}
    library = db.docs["meta/communityFoods"]
    assert library["version"] == 1
    (published,) = library["foods"]
    assert published == {
        "id": "community_" + key, "nameEn": "Koshary", "nameAr": "كشري",
        "category": "egyptianDishes", "allergens": ["gluten"], "kcal": 520,
        "proteinG": 18.0, "carbsG": 90.0, "fatG": 9.0,
    }
    assert "items" not in published
    assert db.docs["communityFoodCandidates/" + key]["items"][0] == {"name": "rice", "grams": 200.0}
    assert db.docs["meta/communityFoodsVersion"] == {"version": 1}
    assert db.docs["communityFoodCandidates/" + key]["status"] == "approved"
    assert listing()["candidates"] == [] and listing()["published"] == [published]


def test_a_second_approval_adds_to_the_list_and_bumps_again(db):
    first = one_candidate(db)
    submit(food(nameEn="Fatta", nameAr="فتة"))
    second = next(k for k in (p.split("/")[1] for p in candidates(db)) if k != first)
    review({"key": first, **APPROVE})
    answer = review({"key": second, **APPROVE, "nameEn": "Fatta", "nameAr": "فتة", "allergens": [], "allergensNone": True})
    assert answer == {"ok": True, "version": 2}
    assert [f["nameEn"] for f in db.docs["meta/communityFoods"]["foods"]] == ["Koshary", "Fatta"]
    assert db.docs["meta/communityFoodsVersion"]["version"] == 2


def test_two_approvals_that_overlap_keep_both_foods(db, monkeypatch):
    first = one_candidate(db)
    submit(food(nameEn="Fatta", nameAr="فتة"))
    second = next(k for k in (p.split("/")[1] for p in candidates(db)) if k != first)
    fatta = {"nameEn": "Fatta", "nameAr": "فتة", "allergens": [], "allergensNone": True}
    rival = {"done": False}

    def racing(fn):
        def run(transaction, *args, **kwargs):
            result = fn(transaction, *args, **kwargs)
            if not rival["done"]:
                rival["done"] = True
                review({"key": second, **APPROVE, **fatta})
                transaction = db.transaction()
                result = fn(transaction, *args, **kwargs)
            transaction.commit()
            return result

        return run

    monkeypatch.setattr(cf.firestore, "transactional", racing)
    answer = review({"key": first, **APPROVE})
    assert answer["ok"] is True
    assert sorted(f["nameEn"] for f in db.docs["meta/communityFoods"]["foods"]) == ["Fatta", "Koshary"]
    assert db.docs["meta/communityFoods"]["version"] == db.docs["meta/communityFoodsVersion"]["version"] == 2


@pytest.mark.parametrize(
    "changes",
    [
        {"nameEn": ""},
        {"nameAr": None},
        {"category": "desserts"},
        {"category": None},
        {"allergens": None},
        {"allergens": ["peanut"]},
        {"allergens": []},
        {"allergens": [], "allergensNone": "yes"},
        {"nameEn": "x" * 61},
    ],
)
def test_approving_needs_both_names_a_category_and_an_explicit_allergen_list(db, changes):
    key = one_candidate(db)
    answer = review({"key": key, **APPROVE, **changes})
    assert answer["ok"] is False and answer["problems"]
    assert "meta/communityFoods" not in db.docs
    assert db.docs["communityFoodCandidates/" + key]["status"] == "pending"


def test_rejecting_marks_the_candidate_and_publishes_nothing(db):
    key = one_candidate(db)
    assert review({"key": key, "action": "reject"}) == {"ok": True}
    assert db.docs["communityFoodCandidates/" + key]["status"] == "rejected"
    assert "meta/communityFoods" not in db.docs
    assert listing()["candidates"] == []
    again = review({"key": key, "action": "approve", **{k: v for k, v in APPROVE.items() if k != "action"}})
    assert again["ok"] is False


@pytest.mark.parametrize("data", [{}, {"key": "nope", "action": "approve"}, {"key": "0" * 24, "action": "approve"}, {"key": "0" * 24, "action": "burn"}])
def test_a_review_of_nothing_is_a_problem_not_a_crash(db, data):
    assert review(data)["ok"] is False


@pytest.mark.parametrize("name", ["list_community_foods", "review_community_food"])
def test_only_an_admin_with_app_check_reaches_the_owner_callables(db, name):
    fn = inner(name)
    raises(lambda: fn(request({}, uid="u", token=VERIFIED)), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
    raises(lambda: fn(request({}, uid="u", token=ADMIN, app=False)), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    password = {**ADMIN, "firebase": {"sign_in_provider": "password"}}
    assert fn(request({}, uid="u", token=password)) is not None


# ------------------------------------------------------- account deletion


def test_deleting_her_account_removes_her_markers_and_keeps_the_count_of_the_others(db, monkeypatch):
    from identity import store as identity_store

    monkeypatch.setattr(identity_store, "db", lambda: db)
    monkeypatch.setattr(identity_store, "pepper", lambda: PEPPER)
    monkeypatch.setattr(identity_store.firestore, "transactional", fake_firestore.transactional)
    submit(food())
    submit(food(), uid=OTHER)
    submit(food(nameEn="Fatta"))
    assert len(markers(db)) == 3

    assert deletion.FirebaseBackend().purge_group_hook(HER) is True

    left = markers(db)
    assert len(left) == 1 and cf.marker_id(OTHER, PEPPER) in left[0]
    assert all(cf.marker_id(HER, PEPPER) not in p for p in left)
    assert [d["confirmCount"] for d in candidates(db).values()] == [2]


def test_a_pending_candidate_only_she_confirmed_goes_with_her(db, monkeypatch):
    from identity import store as identity_store

    monkeypatch.setattr(identity_store, "db", lambda: db)
    monkeypatch.setattr(identity_store, "pepper", lambda: PEPPER)
    monkeypatch.setattr(identity_store.firestore, "transactional", fake_firestore.transactional)
    submit(food(nameEn="Fatta", nameAr="فتة"))
    submit(food())
    submit(food(), uid=OTHER)
    submit(food(nameEn="Hawawshi", nameAr="حواوشي"))
    approved = next(p for p, d in candidates(db).items() if d["nameEn"] == "Hawawshi")
    key = approved.split("/")[1]
    review({"key": key, **APPROVE, "nameEn": "Hawawshi", "nameAr": "حواوشي"})

    assert deletion.FirebaseBackend().purge_group_hook(HER) is True

    names = sorted(d["nameEn"] for d in candidates(db).values())
    assert names == ["Hawawshi", "Koshary"]
    assert db.docs[approved]["status"] == "approved"


def test_a_marker_is_a_keyed_hash_that_differs_by_woman_and_by_pepper():
    assert cf.marker_id(HER, PEPPER) != cf.marker_id(OTHER, PEPPER)
    assert cf.marker_id(HER, PEPPER) != cf.marker_id(HER, b"other")
    assert HER not in cf.marker_id(HER, PEPPER)
