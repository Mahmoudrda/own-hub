"""nutrition/: the USDA data and its matcher, the Egyptian dish table, the check
of the model's answer, the photo re-encode and the SDK wiring. Pure, no
network: the SDK call is made against a recording fake."""

from __future__ import annotations

import json
import math
import os
import re

import pytest

from identity import faces, reasons
from nutrition import build_dishes, config, dishes, meal, model, photo, usda

_NUTRITION = os.path.dirname(usda.__file__)
NUTRIENTS = ("kcal", "protein_g", "carbs_g", "fat_g", "fiber_g")


# ------------------------------------------------------------- the USDA data


def _foods():
    with open(os.path.join(_NUTRITION, "usda_foods.json"), encoding="utf-8") as handle:
        return json.load(handle)


def test_the_usda_file_is_compact_and_every_food_has_energy():
    path = os.path.join(_NUTRITION, "usda_foods.json")
    assert os.path.getsize(path) < 5 * 1024 * 1024
    foods = _foods()["foods"]
    assert len(foods) > 8000
    assert {f["dataset"] for f in foods} == {"sr_legacy", "foundation"}
    ids = [f["fdcId"] for f in foods]
    assert len(ids) == len(set(ids))
    for food in foods:
        assert isinstance(food["kcal"], (int, float)) and food["kcal"] >= 0
        for portion in food.get("portions", []):
            grams, label = portion
            assert grams > 0 and isinstance(label, str) and label


def test_the_licence_credits_the_usda():
    with open(os.path.join(_NUTRITION, "LICENCE.md"), encoding="utf-8") as handle:
        text = handle.read()
    assert "U.S. Department of Agriculture, Agricultural Research Service. FoodData Central" in text
    assert "CC0" in text and "SR Legacy" in text and "Foundation Foods" in text


def test_every_everyday_default_is_a_real_food():
    for fdc_id in usda.COMMON:
        assert usda.food(fdc_id) is not None, fdc_id


@pytest.mark.parametrize(
    "term, fdc_id",
    [
        ("rice, white, cooked", 168878),
        ("rice", 168878),
        ("fava beans, cooked", 173753),
        ("chickpeas, cooked", 173757),
        ("oil, olive", 171413),
        ("olive oil", 171413),
        ("eggs, fried", 173423),
        ("egg, boiled", 173424),
        ("tomato, raw", 170457),
        ("bread, pita, white", 174915),
        ("tea, black, brewed", 173227),
        ("cheese, feta", 173420),
        ("chicken, breast, grilled", 171534),
        ("french fries", 170698),
    ],
)
def test_terms_find_the_everyday_food(term, fdc_id):
    found = usda.match_term(term)
    assert found is not None and found.fdc_id == fdc_id, (term, found and found.name)


def test_a_head_word_must_be_in_the_name():
    found = usda.match_term("chicken, breast")
    assert found is not None and "chicken" in found.name.lower()
    assert "chickpea" not in found.name.lower()
    assert usda.match_term("zorblax, cooked") is None
    assert usda.match_term("") is None
    assert usda.match_term(None) is None


def test_a_term_asking_for_raw_gets_raw():
    assert "raw" in usda.match_term("spinach, raw").name.lower()
    assert "cooked" in usda.match_term("spinach, cooked").name.lower()


def test_the_match_is_deterministic():
    first = [usda.match_term(t) for t in ("lentils", "cheese", "beef, cooked", "yogurt")]
    for _ in range(3):
        again = [usda.match_term(t) for t in ("lentils", "cheese", "beef, cooked", "yogurt")]
        assert [f.fdc_id for f in again] == [f.fdc_id for f in first]


def test_the_first_term_that_matches_wins():
    found = usda.match_terms(["zorblax", "rice, white, cooked", "pasta"])
    assert found.fdc_id == 168878


def test_scaling_keeps_a_missing_nutrient_missing():
    assert usda.scaled({"kcal": 100, "protein_g": 2, "carbs_g": None, "fat_g": 1, "fiber_g": None}, 250) == {
        "kcal": 250.0,
        "protein_g": 5.0,
        "carbs_g": None,
        "fat_g": 2.5,
        "fiber_g": None,
    }


# ----------------------------------------------------------- the dish table


def _table():
    with open(os.path.join(_NUTRITION, "egyptian_dishes.json"), encoding="utf-8") as handle:
        return json.load(handle)["dishes"]


def test_the_dish_file_is_what_the_build_script_writes():
    with open(build_dishes.OUT_PATH, encoding="utf-8") as handle:
        assert handle.read() == build_dishes.render(build_dishes.build())


def test_there_are_at_least_150_dishes_and_every_one_named_is_there():
    keys = {d["key"] for d in _table()}
    assert len(keys) >= 150
    named = {
        "koshary", "ful_medames", "ful_bel_zeit", "ful_bel_tahina", "ful_bel_beid", "taameya",
        "molokhia", "molokhia_chicken", "molokhia_rabbit", "mahshi_vine", "mahshi_peppers",
        "mahshi_zucchini", "fattah", "hawawshi", "feteer", "besara", "roz_shareya",
        "macarona_bechamel", "kofta", "shish_tawook", "kebda_iskandarani", "sayadeya", "bamya",
        "torly", "fasolia", "batates_lahma", "shorbet_ads", "mesh", "gebna_areesh", "gebna_rumi",
        "gebna_domiati", "eggs_pastirma", "shakshuka", "aish_baladi", "aish_shami", "aish_fino",
        "basbousa", "kunafa", "om_ali", "roz_bel_laban", "qatayef", "zalabya", "mahalabeya",
        "shai_bel_laban", "karkadeh", "asab", "sahlab", "tamr_hindi", "hummus", "mutabbal",
        "tabbouleh", "fattoush", "falafel_sandwich", "shawarma_chicken_sandwich",
        "shawarma_beef_sandwich", "shawarma_chicken_plate", "shawarma_beef_plate", "kabsa_chicken",
        "mandi_chicken", "mansaf", "majboos", "kibbeh", "manakish_zaatar", "manakish_cheese", "labneh",
    }
    assert named <= keys, named - keys


def test_every_dish_has_an_arabic_name_and_the_review_note():
    arabic = re.compile(r"[؀-ۿ]")
    for dish in _table():
        assert dish["name_ar"] and arabic.search(dish["name_ar"]), dish["key"]
        assert dish["review"] == "estimated from a standard recipe, pending dietitian review"
        assert dish["aliases"], dish["key"]


def test_every_recipe_fdcid_is_in_the_usda_file():
    for dish in _table():
        for line in dish["recipe"]:
            food = usda.food(line["fdcId"])
            assert food is not None, (dish["key"], line["fdcId"])
            assert line["usdaName"] == food.name
            assert line["grams"] > 0


def test_a_dish_is_the_sum_of_its_ingredients():
    for dish in _table():
        totals = {n: 0.0 for n in NUTRIENTS}
        for line in dish["recipe"]:
            food = usda.food(line["fdcId"])
            for n in NUTRIENTS:
                totals[n] += food.per100g[n] * line["grams"] / 100
        serving = dish["typical_serving_g"]
        for n in NUTRIENTS:
            from_table = dish["per100g"][n] * serving / 100
            assert from_table == pytest.approx(totals[n], abs=0.05), (dish["key"], n)


def test_every_dish_lands_in_a_sane_energy_range():
    for dish in _table():
        assert 30 <= dish["per100g"]["kcal"] <= 600, (dish["key"], dish["per100g"]["kcal"])
        assert 0 < dish["typical_serving_g"] <= 800, dish["key"]


def test_no_name_points_at_two_dishes():
    seen = {}
    for dish in _table():
        names = {dish["key"].replace("_", " "), dish["name_en"], dish["name_ar"], *dish["aliases"]}
        for name in {dishes.normalise(n) for n in names}:
            assert seen.setdefault(name, dish["key"]) == dish["key"], (name, seen[name], dish["key"])


@pytest.mark.parametrize(
    "a, b",
    [
        ("الكُشَرى", "كشري"),
        ("أرز باللبن", "ارز باللبن"),
        ("إسكندراني", "اسكندراني"),
        ("طعمية", "طعميه"),
        ("كبدة", "كبده"),
        ("ملوخـــية", "ملوخيه"),
        ("Ful-Medames", "ful medames"),
        ("  KOSHARI  ", "koshari"),
    ],
)
def test_the_arabic_and_latin_normalisation(a, b):
    assert dishes.normalise(a) == dishes.normalise(b)


@pytest.mark.parametrize(
    "dish_guess, name_ar, name_en, key",
    [
        (None, "كشري", None, "koshary"),
        (None, "كُشَرى", None, "koshary"),
        ("koshari", None, None, "koshary"),
        (None, None, "Kushari", "koshary"),
        (None, "طبق كشري", "Koshary bowl", "koshary"),
        ("ful medames", "فول بالزيت", "Ful with oil", "ful_bel_zeit"),
        ("ta3meya", None, None, "taameya"),
        (None, "ملوخية بالأرانب", None, "molokhia_rabbit"),
        (None, "شاورما فراخ", None, "shawarma_chicken_sandwich"),
        (None, "عيش بلدي", None, "aish_baladi"),
        (None, "رز بلبن", None, "roz_bel_laban"),
    ],
)
def test_aliases_find_the_dish(dish_guess, name_ar, name_en, key):
    found = dishes.match(dish_guess, name_ar, name_en)
    assert found is not None and found.key == key


def test_a_plain_english_description_is_not_claimed_by_a_dish():
    assert dishes.match(None, None, "Grilled chicken breast") is None
    assert dishes.match(None, "صدر فراخ مشوي", "Grilled chicken breast") is None
    assert dishes.match(None, None, "pizza") is None


def test_a_short_alias_never_matches_inside_a_longer_name():
    # "فول" is ful_medames exactly, but not inside an unrelated longer name.
    assert dishes.match(None, "فول", None).key == "ful_medames"
    assert dishes.match(None, "فول سوداني محمص", None) is None


def test_a_dish_item_scales_its_recipe_to_her_grams():
    item = model.Item("Hummus", "حمص بالطحينة", "hummus", 326.0, 0.9, ["hummus"])
    resolved = meal.resolve_item(item)
    dish = dishes.match("hummus", None, None)
    assert resolved["source"] == "dish" and resolved["grams"] == 326.0
    assert sum(p["grams"] for p in resolved["ingredients"]) == pytest.approx(
        sum(g for _, g, _, _ in dish.recipe) * 326.0 / dish.typical_serving_g, abs=0.5
    )


# ------------------------------------------------------- the model's answer


def test_parse_keeps_well_formed_items_and_cleans_them():
    text = json.dumps(
        {
            "items": [
                {
                    "name_en": "  Koshary\n",
                    "name_ar": "كشري",
                    "dish_guess": "koshary",
                    "grams": 412.6,
                    "confidence": 1.7,
                    "usda_terms": ["pasta, cooked", "pasta, cooked", "", 7],
                    "ingredients": [
                        {"name_en": "rice", "grams": 100, "usda_terms": ["rice, white, cooked"]},
                        {"name_en": "oil", "grams": -5, "usda_terms": ["oil"]},
                        "not an object",
                    ],
                },
                {"name_en": "Tea", "name_ar": "شاي", "grams": 9000, "confidence": "high", "usda_terms": "tea"},
            ]
        }
    )
    koshary, tea = model.parse(text)
    assert koshary.name_en == "Koshary" and koshary.grams == 413.0 and koshary.confidence == 1.0
    assert koshary.usda_terms == ["pasta, cooked"]
    assert [i.name_en for i in koshary.ingredients] == ["rice"]
    assert tea.grams == config.MAX_GRAMS and tea.confidence == 0.0 and tea.usda_terms == []


@pytest.mark.parametrize("text", ["", "not json", "[]", '{"items": {}}', '{"items": [1, 2]}', "null"])
def test_parse_refuses_what_is_not_the_schema(text):
    with pytest.raises(model.Unclear):
        model.parse(text)


def test_parse_returns_an_empty_list_for_no_food():
    assert model.parse('{"items": []}') == []


@pytest.mark.parametrize("grams", [0, -1, float("nan"), float("inf"), True, None, "200", 0.2])
def test_impossible_grams_drop_the_item(grams):
    payload = {"items": [{"name_en": "rice", "grams": grams}, {"name_en": "bread", "grams": 80}]}
    if isinstance(grams, float) and not math.isfinite(grams):
        text = json.dumps(payload, allow_nan=True)
    else:
        text = json.dumps(payload)
    items = model.parse(text)
    assert [i.name_en for i in items] == ["bread"]


def test_no_more_than_the_item_cap_is_kept():
    text = json.dumps({"items": [{"name_en": f"food {n}", "grams": 10} for n in range(20)]})
    assert len(model.parse(text)) == config.MAX_ITEMS


def test_the_schema_has_no_field_for_numbers_the_server_computes():
    text = json.dumps(model.RESPONSE_SCHEMA).lower()
    for word in ("kcal", "calorie", "protein", "carb", "fat", "fiber", "fibre"):
        assert word not in text
    assert "never output calories" in model.SYSTEM_PROMPT.lower()


# ----------------------------------------------------------- the SDK wiring


class _RecordingModels:
    def __init__(self):
        self.calls = []

    def generate_content(self, **kwargs):
        from types import SimpleNamespace

        self.calls.append(kwargs)
        return SimpleNamespace(
            text='{"items": []}',
            candidates=[SimpleNamespace(finish_reason=SimpleNamespace(name="STOP"))],
            usage_metadata=SimpleNamespace(prompt_token_count=1100, candidates_token_count=9),
        )


def test_the_call_carries_the_owners_settings():
    from types import SimpleNamespace

    models = _RecordingModels()
    model.set_client(SimpleNamespace(models=models))
    result = model.analyse(b"\xff\xd8\xff\xe0fake jpeg")
    assert result.items == [] and result.prompt_tokens == 1100 and result.output_tokens == 9
    (call,) = models.calls
    assert call["model"] == "gemini-3.8-flash"
    settings = call["config"]
    assert settings.temperature == 0.1
    assert settings.max_output_tokens == 600
    assert settings.response_mime_type == "application/json"
    assert settings.response_schema == model.RESPONSE_SCHEMA
    # Gemini 3 takes a thinking level, not a budget; LOW is the cheapest
    # level every 3.x Flash accepts.
    assert settings.thinking_config.thinking_budget is None
    assert str(settings.thinking_config.thinking_level).upper().endswith("LOW")
    assert settings.system_instruction == model.SYSTEM_PROMPT
    image, prompt = call["contents"]
    assert image.inline_data.mime_type == "image/jpeg"
    assert prompt == model.USER_PROMPT


def test_the_schema_is_one_the_sdk_accepts():
    from google.genai import types

    schema = types.Schema.model_validate(model.RESPONSE_SCHEMA)
    assert schema.properties["items"].max_items == config.MAX_ITEMS


def test_gemini_3_gets_a_thinking_level_not_a_budget():
    assert config.thinking_settings("gemini-2.5-flash") == {"thinking_budget": 0}
    assert config.thinking_settings("gemini-3.5-flash") == {"thinking_level": "LOW"}
    assert config.thinking_settings("gemini-3.8-flash") == {"thinking_level": "LOW"}


def test_the_real_client_is_vertex_in_frankfurt_with_a_timeout_and_no_retries(monkeypatch):
    from google import genai

    made = {}

    class _Client:
        def __init__(self, **kwargs):
            made.update(kwargs)

    monkeypatch.setattr(genai, "Client", _Client)
    model._real_client()
    assert made["vertexai"] is True
    assert made["project"] == "own-hub"
    assert made["location"] == "europe-west3"
    assert made["http_options"].timeout == 20_000
    assert made["http_options"].retry_options is None


# ------------------------------------------------------------- the photo


def _jpeg(width, height, exif=b""):
    cv2, np = faces.cv2, faces.np
    image = np.full((height, width, 3), 120, dtype=np.uint8)
    ok, encoded = cv2.imencode(".jpg", image)
    data = encoded.tobytes()
    return data[:2] + exif + data[2:]


def test_the_re_encode_strips_exif_and_shrinks():
    payload = b"MM\x00\x2a\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00GPS-SECRET-PLACE"
    body = b"Exif\x00\x00" + payload
    exif = b"\xff\xe1" + (len(body) + 2).to_bytes(2, "big") + body
    original = _jpeg(3000, 1000, exif)
    assert b"GPS-SECRET-PLACE" in original
    out = photo.reencode(original)
    assert b"Exif" not in out and b"GPS-SECRET-PLACE" not in out
    decoded = faces.cv2.imdecode(faces.np.frombuffer(out, dtype=faces.np.uint8), faces.cv2.IMREAD_COLOR)
    assert decoded.shape[:2] == (256, 768)


@pytest.mark.parametrize(
    "raw, code",
    [
        (b"", reasons.IMAGE_UNDECODABLE),
        (b"GIF89a not a photo", reasons.IMAGE_UNDECODABLE),
        (b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR" + (60_000).to_bytes(4, "big") * 2, reasons.IMAGE_TOO_LARGE),
    ],
)
def test_the_re_encode_refuses_what_is_not_a_photo(raw, code):
    with pytest.raises(photo.PhotoRejected) as caught:
        photo.reencode(raw)
    assert caught.value.code == code
