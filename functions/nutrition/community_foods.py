"""Foods that women confirm in the meal check, and the ones the owner publishes.

A woman who logs a scanned meal can offer it to everyone: the callable stores a
candidate at communityFoodCandidates/{key}, where the key is a hash of the
meal's normalised name, and counts one confirmation per woman. The candidate
holds the name, the items with their grams and the macros she confirmed. It
holds no uid and no photo. The only trace of who confirmed is a marker at
communityFoodCandidates/{key}/by/{hash}, an HMAC of her uid under the server's
pepper, there to stop one woman confirming twice. Deleting her account removes
the markers, and a pending candidate that only she confirmed; the confirmation
count of the others stays, because it names nobody. Her items are for the owner
to read on the candidate and are never copied into the published food.

The owner reads the candidates in the dashboard and approves one with names in
both languages, a category and an explicit allergen list. Approving publishes
it into meta/communityFoods (the whole list, versioned) and bumps
meta/communityFoodsVersion, the pair phones check once a day, the same shape as
the exercise library. Both collections are server-written only.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import math
import re
import unicodedata
from typing import Any, Optional

from google.cloud import firestore

COLLECTION = "communityFoodCandidates"
MARKERS = "by"
LIBRARY_DOC = ("meta", "communityFoods")
VERSION_DOC = ("meta", "communityFoodsVersion")
ID_PREFIX = "community_"

PENDING, APPROVED, REJECTED = "pending", "approved", "rejected"

MAX_NAME_CHARS = 60
MAX_ITEMS = 12
MAX_GRAMS = 3000
MAX_KCAL = 5000
MAX_MACRO_G = 500
MAX_PUBLISHED = 1500
PENDING_LIST_LIMIT = 300

# The FoodCategory enum in app/lib/features/eat/domain/food_library.dart.
CATEGORIES = (
    "egyptianDishes", "proteins", "dairyAndCheese", "grainsAndBreads",
    "vegetablesAndSalads", "fruitsAndNuts", "snacksAndDrinks",
)
# The AllergenTag wire names in app/lib/features/account/domain/dietary_profile.dart,
# the same sixteen app/tool/build_food_pack.py checks a food against.
ALLERGENS = (
    "gluten", "crustaceans", "eggs", "fish", "peanuts", "soy", "milk", "tree_nuts",
    "celery", "mustard", "sesame", "sulphites", "lupin", "molluscs", "fava", "coconut",
)

KEY = re.compile(r"^[0-9a-f]{24}$")
_ARABIC_MARKS = re.compile("[ً-ْـ]")
_NOT_WORD = re.compile(r"[^\w]+", re.UNICODE)


def normalise(name: str) -> str:
    text = unicodedata.normalize("NFKC", name).lower()
    text = _ARABIC_MARKS.sub("", text)
    for source, target in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ى", "ي"), ("ة", "ه")):
        text = text.replace(source, target)
    return " ".join(_NOT_WORD.sub(" ", text).split())


def candidate_key(name_en: Optional[str], name_ar: Optional[str]) -> str:
    """24 hex characters from the English name when there is one, else the
    Arabic one. The same dish typed the same way by two women is one candidate."""
    primary = normalise(name_en or "") or normalise(name_ar or "")
    return hashlib.sha256(primary.encode("utf-8")).hexdigest()[:24]


def marker_id(uid: str, pepper: bytes) -> str:
    return hmac.new(pepper, b"community-food|" + uid.encode("utf-8"), hashlib.sha256).hexdigest()[:40]


# ------------------------------------------------------------------ a woman


def _number(value: Any) -> Optional[float]:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value) if math.isfinite(value) else None


def _name(value: Any, problems: list, label: str) -> Optional[str]:
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        problems.append(f"{label} is not text")
        return None
    text = " ".join("".join(ch for ch in value if ch.isprintable()).split())
    if len(text) > MAX_NAME_CHARS:
        problems.append(f"{label} is over {MAX_NAME_CHARS} characters")
        return None
    return text or None


def atwater_ok(protein: float, carbs: float, fat: float, kcal: float) -> bool:
    return abs(4 * protein + 4 * carbs + 9 * fat - kcal) <= max(20, 0.15 * kcal)


def validate_submission(data: Any) -> tuple[Optional[dict], list]:
    """The row to store, or None and the problems. The same arithmetic the food
    pack is held to (app/tool/build_food_pack.py)."""
    problems: list = []
    if not isinstance(data, dict):
        return None, ["the request is not a food"]
    name_en = _name(data.get("nameEn"), problems, "nameEn")
    name_ar = _name(data.get("nameAr"), problems, "nameAr")
    if not (name_en or name_ar) and not problems:
        problems.append("a food needs a name")
    if not normalise(name_en or "") and not normalise(name_ar or ""):
        problems.append("the name has no letters")
    items: list = []
    raw_items = data.get("items")
    if not isinstance(raw_items, list) or not 1 <= len(raw_items) <= MAX_ITEMS:
        problems.append(f"a food lists 1 to {MAX_ITEMS} items")
    else:
        for raw in raw_items:
            item_name = _name(raw.get("name"), problems, "an item name") if isinstance(raw, dict) else None
            grams = _number(raw.get("grams")) if isinstance(raw, dict) else None
            if not item_name or grams is None or not 0 < grams <= MAX_GRAMS:
                problems.append("an item needs a name and grams above 0")
                break
            items.append({"name": item_name, "grams": round(grams, 1)})
    kcal = _number(data.get("kcal"))
    macros = {key: _number(data.get(key)) for key in ("proteinG", "carbsG", "fatG")}
    if kcal is None or not 0 < kcal <= MAX_KCAL:
        problems.append("kcal must be above 0")
    if any(v is None or not 0 <= v <= MAX_MACRO_G for v in macros.values()):
        problems.append("protein, carbs and fat must be between 0 and 500 g")
    if not problems and not atwater_ok(macros["proteinG"], macros["carbsG"], macros["fatG"], kcal):
        problems.append("the energy does not add up from protein, carbs and fat")
    if problems:
        return None, problems
    row = {
        "items": items,
        "kcal": round(kcal),
        "proteinG": round(macros["proteinG"], 1),
        "carbsG": round(macros["carbsG"], 1),
        "fatG": round(macros["fatG"], 1),
    }
    if name_en:
        row["nameEn"] = name_en
    if name_ar:
        row["nameAr"] = name_ar
    return row, []


def submit(db, marker: str, row: dict) -> None:
    """One confirmation from one woman (her marker). The first confirmation
    creates the candidate with her macros; later ones only count. Once the
    owner has decided, a new confirmation changes nothing."""
    key = candidate_key(row.get("nameEn"), row.get("nameAr"))
    candidate = db.collection(COLLECTION).document(key)
    mark = candidate.collection(MARKERS).document(marker)

    @firestore.transactional
    def txn(transaction):
        existing = candidate.get(transaction=transaction)
        seen = mark.get(transaction=transaction)
        if existing.exists:
            if (existing.to_dict() or {}).get("status") != PENDING or seen.exists:
                return
            transaction.update(
                candidate,
                {"confirmCount": firestore.Increment(1), "updatedAt": firestore.SERVER_TIMESTAMP},
            )
        else:
            transaction.set(
                candidate,
                {
                    **row,
                    "status": PENDING,
                    "confirmCount": 1,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )
        transaction.set(mark, {"v": 1})

    txn(db.transaction())


def forget(db, marker: str) -> None:
    """Account deletion: her marker on every candidate. The counts stay."""
    for snapshot in db.collection(COLLECTION).select([]).stream():
        mark = snapshot.reference.collection(MARKERS).document(marker)
        if not mark.get().exists:
            continue
        mark.delete()
        _drop_if_orphaned(snapshot.reference)


def _drop_if_orphaned(candidate) -> None:
    """A pending candidate nobody else confirmed still holds what she typed, so
    it goes with her. Approved and rejected ones keep only the decision."""
    current = candidate.get().to_dict() or {}
    if current.get("status") != PENDING:
        return
    for _ in candidate.collection(MARKERS).limit(1).stream():
        return
    candidate.delete()


# -------------------------------------------------------------- the owner


def _get(db, path) -> Optional[dict]:
    snapshot = db.collection(path[0]).document(path[1]).get()
    return snapshot.to_dict() if getattr(snapshot, "exists", False) else None


def _published(db) -> list:
    return list((_get(db, LIBRARY_DOC) or {}).get("foods") or [])


def list_all(db) -> dict:
    """Pending candidates, the most confirmed first, the published list and the
    vocabularies the approve form offers."""
    rows = []
    for snapshot in db.collection(COLLECTION).where("status", "==", PENDING).stream():
        data = snapshot.to_dict() or {}
        rows.append(
            {
                "key": snapshot.id,
                "nameEn": data.get("nameEn"),
                "nameAr": data.get("nameAr"),
                "items": list(data.get("items") or []),
                "kcal": data.get("kcal"),
                "proteinG": data.get("proteinG"),
                "carbsG": data.get("carbsG"),
                "fatG": data.get("fatG"),
                "confirmCount": int(data.get("confirmCount") or 0),
            }
        )
    rows.sort(key=lambda r: (-r["confirmCount"], r["key"]))
    return {
        "candidates": rows[:PENDING_LIST_LIMIT],
        "published": _published(db),
        "vocab": {"categories": list(CATEGORIES), "allergens": list(ALLERGENS)},
    }


def review(db, data: Any, now: Optional[dt.datetime] = None) -> dict:
    """`{ok: true}` / `{ok: true, version}` or `{ok: false, problems}`."""
    if not isinstance(data, dict):
        return {"ok": False, "problems": ["the request is not a review"]}
    key = data.get("key")
    action = data.get("action")
    if not isinstance(key, str) or not KEY.match(key) or action not in ("approve", "reject"):
        return {"ok": False, "problems": ["the request names no candidate or action"]}
    reference = db.collection(COLLECTION).document(key)
    if action == "reject":
        snapshot = reference.get()
        candidate = snapshot.to_dict() if snapshot.exists else None
        if candidate is None:
            return {"ok": False, "problems": ["that candidate does not exist"]}
        if candidate.get("status") != PENDING:
            return {"ok": False, "problems": [f"that candidate is already {candidate.get('status')}"]}
        reference.update({"status": REJECTED, "reviewedAt": firestore.SERVER_TIMESTAMP})
        return {"ok": True}

    problems: list = []
    name_en = _name(data.get("nameEn"), problems, "nameEn")
    name_ar = _name(data.get("nameAr"), problems, "nameAr")
    if not name_en or not name_ar:
        problems.append("approving needs a name in English and in Arabic")
    category = data.get("category")
    if category not in CATEGORIES:
        problems.append("pick a category from the list")
    allergens = data.get("allergens")
    if not isinstance(allergens, list) or any(a not in ALLERGENS for a in allergens):
        problems.append("list the allergens from the allergen list")
        allergens = []
    elif not allergens and data.get("allergensNone") is not True:
        problems.append("tick at least one allergen, or confirm there are none")

    library_ref = db.collection(LIBRARY_DOC[0]).document(LIBRARY_DOC[1])
    version_ref = db.collection(VERSION_DOC[0]).document(VERSION_DOC[1])

    @firestore.transactional
    def txn(transaction):
        snapshot = reference.get(transaction=transaction)
        candidate = snapshot.to_dict() if snapshot.exists else None
        if candidate is None:
            return {"ok": False, "problems": ["that candidate does not exist"]}
        if candidate.get("status") != PENDING:
            return {"ok": False, "problems": [f"that candidate is already {candidate.get('status')}"]}
        if problems:
            return {"ok": False, "problems": problems}
        library = library_ref.get(transaction=transaction)
        library_data = (library.to_dict() or {}) if library.exists else {}
        version_snap = version_ref.get(transaction=transaction)
        version_data = (version_snap.to_dict() or {}) if version_snap.exists else {}
        food = {
            "id": ID_PREFIX + key,
            "nameEn": name_en,
            "nameAr": name_ar,
            "category": category,
            "allergens": sorted(set(allergens)),
            "kcal": candidate.get("kcal"),
            "proteinG": candidate.get("proteinG"),
            "carbsG": candidate.get("carbsG"),
            "fatG": candidate.get("fatG"),
        }
        foods = [f for f in (library_data.get("foods") or []) if f.get("id") != food["id"]]
        if len(foods) >= MAX_PUBLISHED:
            return {"ok": False, "problems": [f"the list is full at {MAX_PUBLISHED} foods"]}
        foods.append(food)
        version = max(int(version_data.get("version") or 0), int(library_data.get("version") or 0)) + 1
        transaction.set(library_ref, {"version": version, "foods": foods})
        transaction.set(version_ref, {"version": version})
        transaction.update(
            reference,
            {"status": APPROVED, "reviewedAt": firestore.SERVER_TIMESTAMP, "publishedAs": food["id"]},
        )
        return {"ok": True, "version": version}

    return txn(db.transaction())
