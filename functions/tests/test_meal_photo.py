"""analyze_meal_photo and record_meal_photo_consent, end to end with a fake
Gemini client: the guards, the owner's limits, the image hygiene, the one model
call, the macros the server computes, and the log line.

No network: the fake stands where google-genai's client would be, and
tests/conftest.py fails any test that reaches the real one."""

from __future__ import annotations

import base64
import hashlib
import json
from types import SimpleNamespace

import pytest
from firebase_functions import https_fn

import main
from identity import config, faces, logs, reasons, store
from nutrition import config as meal_config
from nutrition import dishes, model, photo, usda
from tests import fake_firestore
from tests.test_entrypoints import inner, raises
from tests.test_entrypoints import request as _base_request


def request(data, *, uid="uid-1", token=None, app=True):
    """A verified member's request, unless the test says otherwise: scans are
    for verified members only."""
    return _base_request(data, uid=uid, token={"verified": True, **(token or {})}, app=app)

cv2 = faces.cv2
np = faces.np

GPS_MARKER = b"GPS-30.0444N-31.2357E-HOME"


# ------------------------------------------------------------------ helpers


def exif_segment(payload: bytes) -> bytes:
    """An APP1 Exif segment: a big-endian TIFF header, an empty IFD, then the
    payload, which stands in for the GPS block a phone writes."""
    tiff = b"MM\x00\x2a\x00\x00\x00\x08" + b"\x00\x00" + b"\x00\x00\x00\x00" + payload
    body = b"Exif\x00\x00" + tiff
    return b"\xff\xe1" + (len(body) + 2).to_bytes(2, "big") + body


def photo_bytes(width=1600, height=1200, exif=True) -> bytes:
    image = np.zeros((height, width, 3), dtype=np.uint8)
    image[:, : width // 2] = (40, 120, 200)
    image[height // 3 :, :] = (200, 200, 180)
    ok, encoded = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 90])
    assert ok
    data = encoded.tobytes()
    if exif:
        data = data[:2] + exif_segment(GPS_MARKER) + data[2:]
    return data


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


class FakeResponse:
    def __init__(self, text, finish="STOP", prompt_tokens=1290, output_tokens=212):
        self.text = text
        self.candidates = [SimpleNamespace(finish_reason=SimpleNamespace(name=finish))]
        self.usage_metadata = SimpleNamespace(
            prompt_token_count=prompt_tokens, candidates_token_count=output_tokens
        )


class FakeClient:
    """Stands in for google.genai.Client: records every generate_content call."""

    def __init__(self, payload=None, *, text=None, finish="STOP", error=None):
        self.calls = []
        self.error = error
        body = text if text is not None else json.dumps(payload, ensure_ascii=False)
        self.response = FakeResponse(body, finish)
        outer = self

        class _Models:
            def generate_content(self, **kwargs):
                outer.calls.append(kwargs)
                if outer.error is not None:
                    raise outer.error
                return outer.response

        self.models = _Models()


def item(name_en, grams, terms, *, name_ar="", confidence=0.9, dish_guess=None, ingredients=None):
    entry = {
        "name_en": name_en,
        "name_ar": name_ar,
        "grams": grams,
        "confidence": confidence,
        "usda_terms": terms,
    }
    if dish_guess:
        entry["dish_guess"] = dish_guess
    if ingredients is not None:
        entry["ingredients"] = ingredients
    return entry


@pytest.fixture
def wired(monkeypatch):
    """Consent on file, counters in memory, refunds counted."""
    state = {
        "consent": True, "uid": 0, "global": 0, "refunds": 0, "order": [],
        "cache": False, "cached": {}, "puts": 0,
    }

    def per_uid(uid, field):
        state["order"].append("per_uid")
        state["uid"] += 1
        state["uid_field"] = field
        return state["uid"]

    def global_count(field="sessions"):
        state["order"].append("global")
        state["global"] += 1
        state["global_field"] = field
        return state["global"]

    def refund(uid, field):
        state["refunds"] += 1

    monkeypatch.setattr(main.store, "has_meal_photo_consent", lambda uid: state["consent"])
    monkeypatch.setattr(main.store, "uid_daily_count_and_increment", per_uid)
    monkeypatch.setattr(main.store, "daily_count_and_increment", global_count)
    monkeypatch.setattr(main.store, "uid_daily_refund", refund)

    def cache_get(key):
        return state["cached"].get(key) if state["cache"] else None

    def cache_put(key, items):
        state["puts"] += 1
        if state["cache"]:
            state["cached"][key] = items

    monkeypatch.setattr(main, "_scan_cache_get", cache_get)
    monkeypatch.setattr(main, "_scan_cache_put", cache_put)
    return state


def scan(client, image=None, **extra):
    model.set_client(client)
    body = {"imageJpeg": b64(image if image is not None else photo_bytes()), "locale": "ar", **extra}
    return inner("analyze_meal_photo")(request(body))


RICE_PLATE = {"items": [item("Rice", 200, ["rice, white, cooked"], name_ar="رز")]}


# ------------------------------------------------------------ the success path


def test_the_macros_are_grams_over_100_times_the_usda_values(wired):
    client = FakeClient(RICE_PLATE)
    answer = scan(client)
    (rice,) = answer["items"]
    food = usda.food(rice["fdcId"])
    assert rice["fdcId"] == 168878 and rice["source"] == "usda" and rice["matched"] is True
    assert food.per100g["kcal"] == 130.0
    assert rice["kcal"] == 260
    assert rice["proteinG"] == round(food.per100g["protein_g"] * 2, 1)
    assert rice["carbsG"] == round(food.per100g["carbs_g"] * 2, 1)
    assert rice["fatG"] == round(food.per100g["fat_g"] * 2, 1)
    assert rice["fiberG"] == round(food.per100g["fiber_g"] * 2, 1)
    assert rice["per100g"] == {
        "kcal": 130.0,
        "proteinG": food.per100g["protein_g"],
        "carbsG": food.per100g["carbs_g"],
        "fatG": food.per100g["fat_g"],
        "fiberG": food.per100g["fiber_g"],
    }
    assert answer["totals"]["kcal"] == 260
    assert answer["estimate"] is True
    assert len(client.calls) == 1


def test_a_known_egyptian_dish_comes_from_the_dish_table(wired):
    client = FakeClient(
        {"items": [item("Koshary", 400, ["pasta, cooked"], name_ar="كشري", dish_guess="koshary")]}
    )
    (koshary,) = scan(client)["items"]
    dish = dishes.match("koshary", "كشري", None)
    assert koshary["source"] == "dish" and koshary["dishKey"] == "koshary"
    assert koshary["review"] == "estimated from a standard recipe, pending dietitian review"
    assert koshary["kcal"] == round(dish.per100g["kcal"] * 4)
    assert koshary["proteinG"] == round(dish.per100g["protein_g"] * 4, 1)
    # The breakdown is the recipe scaled to her 400 g, and adds up to the item.
    parts = koshary["ingredients"]
    assert {p["fdcId"] for p in parts} == {fdc for fdc, _, _, _ in dish.recipe}
    assert sum(p["kcal"] for p in parts) == pytest.approx(koshary["kcal"], abs=len(parts))


def test_a_mixed_dish_sums_its_ingredients(wired):
    ingredients = [
        {"name_en": "grilled chicken", "grams": 120, "usda_terms": ["chicken, breast, grilled"]},
        {"name_en": "lettuce", "grams": 50, "usda_terms": ["lettuce, raw"]},
        {"name_en": "olive oil", "grams": 10, "usda_terms": ["oil, olive"]},
    ]
    client = FakeClient(
        {"items": [item("Chicken salad bowl", 180, ["salad, chicken"], name_ar="سلطة بالفراخ", ingredients=ingredients)]}
    )
    (bowl,) = scan(client)["items"]
    assert bowl["source"] == "ingredients" and bowl["matched"] is True
    assert bowl["grams"] == 180
    expected = 0.0
    for part in bowl["ingredients"]:
        food = usda.food(part["fdcId"])
        expected += food.per100g["kcal"] * part["grams"] / 100
    assert bowl["kcal"] == round(expected)
    assert [p["fdcId"] for p in bowl["ingredients"]] == [171534, 169247, 171413]
    # Editing the bowl's grams in the app scales by the composite per-100 g.
    assert bowl["per100g"]["kcal"] == pytest.approx(expected * 100 / 180, abs=0.01)


def test_an_unmatched_item_is_flagged_without_numbers(wired):
    client = FakeClient(
        {"items": [
            item("Rice", 200, ["rice, white, cooked"]),
            item("Zorblax pudding", 150, ["zorblax, pudding"]),
        ]}
    )
    answer = scan(client)
    rice, mystery = answer["items"]
    assert mystery["matched"] is False and mystery["source"] is None
    assert mystery["per100g"] is None
    assert all(mystery[k] is None for k in ("kcal", "proteinG", "carbsG", "fatG", "fiberG"))
    assert mystery["nameEn"] == "Zorblax pudding" and mystery["grams"] == 150
    # The totals hold what was found and nothing invented.
    assert answer["totals"]["kcal"] == rice["kcal"]


def test_a_low_confidence_item_is_flagged_without_numbers(wired):
    client = FakeClient({"items": [item("Rice", 200, ["rice, white, cooked"], confidence=0.1)]})
    (rice,) = scan(client)["items"]
    assert rice["matched"] is False and rice["kcal"] is None and rice["confidence"] == 0.1


def test_absurd_grams_are_clamped_and_impossible_ones_dropped(wired):
    client = FakeClient(
        {"items": [
            item("Rice", 5000, ["rice, white, cooked"]),
            item("Bread", -40, ["bread, pita"]),
            item("Tea", 0, ["tea"]),
        ]}
    )
    answer = scan(client)
    assert [i["nameEn"] for i in answer["items"]] == ["Rice"]
    assert answer["items"][0]["grams"] == meal_config.MAX_GRAMS
    assert answer["items"][0]["kcal"] == round(130 * meal_config.MAX_GRAMS / 100)


# ------------------------------------------------------------- the refusals


def test_the_sixth_scan_of_the_day_is_refused(wired):
    client = FakeClient(RICE_PLATE)
    for _ in range(meal_config.MEAL_SCANS_PER_UID_PER_DAY):
        scan(client)
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED)
    assert error.message == reasons.MEAL_SCAN_DAILY_LIMIT
    assert len(client.calls) == meal_config.MEAL_SCANS_PER_UID_PER_DAY
    assert wired["uid_field"] == "mealScans"
    # Her own allowance is checked first: the global counter did not move.
    assert wired["global"] == meal_config.MEAL_SCANS_PER_UID_PER_DAY


def test_the_global_cap_pauses_scans_for_everyone(wired, capsys):
    wired["global"] = meal_config.MEAL_SCANS_GLOBAL_PER_DAY
    client = FakeClient(RICE_PLATE)
    capsys.readouterr()
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED)
    assert error.message == reasons.MEAL_SCANS_PAUSED
    assert client.calls == []
    assert wired["global_field"] == "mealScans"
    assert wired["order"] == ["per_uid", "global"]
    assert wired["refunds"] == 1, "the app's pause must not cost her a scan"
    out = capsys.readouterr()
    assert '"event": "meal_scans_paused"' in out.out + out.err


def test_consent_is_required(wired):
    wired["consent"] = False
    client = FakeClient(RICE_PLATE)
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    assert error.message == reasons.CONSENT_MISSING
    assert client.calls == [] and wired["uid"] == 0


def test_app_check_is_required(wired):
    model.set_client(FakeClient(RICE_PLATE))
    error = raises(
        lambda: inner("analyze_meal_photo")(request({"imageJpeg": b64(photo_bytes())}, app=False)),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.APP_CHECK_MISSING
    assert wired["uid"] == 0


def test_a_signed_in_phone_account_is_required(wired):
    model.set_client(FakeClient(RICE_PLATE))
    raises(
        lambda: inner("analyze_meal_photo")(request({"imageJpeg": b64(photo_bytes())}, uid=None)),
        https_fn.FunctionsErrorCode.UNAUTHENTICATED,
    )
    error = raises(
        lambda: inner("analyze_meal_photo")(
            request({"imageJpeg": b64(photo_bytes())}, token={"firebase": {"sign_in_provider": "password"}})
        ),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    assert error.message == reasons.PHONE_SIGN_IN_REQUIRED
    assert wired["uid"] == 0


@pytest.mark.parametrize(
    "image, code",
    [
        (None, reasons.IMAGE_UNDECODABLE),
        ("", reasons.IMAGE_UNDECODABLE),
        ("not base64 at all!", reasons.IMAGE_UNDECODABLE),
        (b64(b"this is a text file, not a photo"), reasons.IMAGE_UNDECODABLE),
        (b64(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0dIHDR" + (50_000).to_bytes(4, "big") * 2 + b"\x08\x02\x00\x00\x00"),
         reasons.IMAGE_TOO_LARGE),
    ],
)
def test_a_bad_image_is_refused_before_her_scan_is_counted(wired, image, code):
    model.set_client(FakeClient(RICE_PLATE))
    error = raises(
        lambda: inner("analyze_meal_photo")(request({"imageJpeg": image})),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert error.message == code
    assert wired["uid"] == 0 and wired["global"] == 0


def test_a_photo_that_will_not_re_encode_costs_no_scan(wired, monkeypatch):
    """A header that passes the size check with a body that is not a photo is
    refused by the re-encode, and that happens before either count moves."""
    from nutrition import photo

    def rejected(raw):
        raise photo.PhotoRejected(reasons.IMAGE_UNDECODABLE)

    monkeypatch.setattr(photo, "reencode", rejected)
    client = FakeClient(RICE_PLATE)
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.INVALID_ARGUMENT)
    assert error.message == reasons.IMAGE_UNDECODABLE
    assert wired["uid"] == 0 and wired["global"] == 0
    assert wired["order"] == []
    assert client.calls == []


def test_a_good_photo_is_counted_once_and_sent_once(wired):
    client = FakeClient(RICE_PLATE)
    scan(client)
    assert wired["order"] == ["per_uid", "global"]
    assert wired["uid"] == 1 and wired["global"] == 1
    assert len(client.calls) == 1


def test_an_oversized_image_is_refused_on_its_base64_length(wired, monkeypatch):
    decoded = []
    monkeypatch.setattr(main.base64, "b64decode", lambda *a, **k: decoded.append(1))
    model.set_client(FakeClient(RICE_PLATE))
    too_long = "A" * ((config.MAX_IMAGE_BYTES * 4) // 3 + 8)
    error = raises(
        lambda: inner("analyze_meal_photo")(request({"imageJpeg": too_long})),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )
    assert error.message == reasons.IMAGE_TOO_LARGE
    assert decoded == [] and wired["uid"] == 0


def test_a_body_that_is_not_an_object_is_invalid(wired):
    raises(
        lambda: inner("analyze_meal_photo")(request(["not", "an", "object"])),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


def test_an_unknown_locale_is_invalid(wired):
    model.set_client(FakeClient(RICE_PLATE))
    raises(
        lambda: inner("analyze_meal_photo")(request({"imageJpeg": b64(photo_bytes()), "locale": "fr"})),
        https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    )


def test_wrapped_ints_are_unwrapped_before_the_checks(wired):
    wrapped = {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "1729"}
    client = FakeClient(RICE_PLATE)
    model.set_client(client)
    answer = inner("analyze_meal_photo")(
        request({"imageJpeg": b64(photo_bytes()), "locale": "en", "clientSentAtMs": wrapped})
    )
    assert answer["items"][0]["kcal"] == 260


# ------------------------------------------------------- the model's answer


def test_malformed_json_is_meal_unclear_and_still_one_call(wired):
    client = FakeClient(text='{"items": [{"name_en": "rice", "grams": 2')
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    assert error.message == reasons.MEAL_UNCLEAR
    assert len(client.calls) == 1
    assert wired["refunds"] == 0, "the model answered, so the scan counts"


def test_a_cut_off_answer_is_meal_unclear(wired):
    client = FakeClient(RICE_PLATE, finish="MAX_TOKENS")
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    assert error.message == reasons.MEAL_UNCLEAR


@pytest.mark.parametrize(
    "payload",
    [
        {"foods": []},
        {"items": "rice"},
        {"items": [{"name_en": "", "grams": 100}]},
        {"items": [{"name_en": "rice", "grams": "a lot"}]},
        {"items": [{"name_en": "rice", "grams": True}]},
        {"items": [{"name_en": "rice", "grams": -100}]},
        ["rice"],
    ],
)
def test_an_answer_off_the_schema_is_meal_unclear(wired, payload):
    error = raises(lambda: scan(FakeClient(payload)), https_fn.FunctionsErrorCode.FAILED_PRECONDITION)
    assert error.message == reasons.MEAL_UNCLEAR


def test_no_food_is_said_honestly(wired):
    client = FakeClient({"items": []})
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.NOT_FOUND)
    assert error.message == reasons.NO_FOOD_SEEN
    assert len(client.calls) == 1


def test_an_outage_is_unavailable_and_gives_her_scan_back(wired):
    client = FakeClient(RICE_PLATE, error=RuntimeError("503 from Vertex quoting the request"))
    error = raises(lambda: scan(client), https_fn.FunctionsErrorCode.UNAVAILABLE)
    assert error.message == reasons.MEAL_SERVICE_UNAVAILABLE
    assert wired["refunds"] == 1
    assert len(client.calls) == 1, "no retry: one call per scan"


def test_a_refused_model_call_logs_its_code_not_its_message(wired, capsys):
    class Refused(Exception):
        code = 403
        status = "PERMISSION_DENIED"

    client = FakeClient(RICE_PLATE, error=Refused("rejected, quoting the plate"))
    capsys.readouterr()
    raises(lambda: scan(client), https_fn.FunctionsErrorCode.UNAVAILABLE)
    entries, raw = _lines(capsys)
    (line,) = [e for e in entries if e.get("event") == "verification_decision"]
    assert line["outcome"] == "unavailable"
    assert line["modelError"] == "403 PERMISSION_DENIED"
    assert "quoting" not in raw and "plate" not in raw


# ------------------------------------------------------- the image the model sees


def test_the_model_gets_one_small_jpeg_without_exif(wired):
    original = photo_bytes(width=4000, height=3000)
    assert b"Exif" in original and GPS_MARKER in original
    client = FakeClient(RICE_PLATE)
    scan(client, image=original)
    (call,) = client.calls
    part = call["contents"][0]
    sent = part.inline_data.data
    assert part.inline_data.mime_type == "image/jpeg"
    assert b"Exif" not in sent and GPS_MARKER not in sent
    decoded = cv2.imdecode(np.frombuffer(sent, dtype=np.uint8), cv2.IMREAD_COLOR)
    height, width = decoded.shape[:2]
    assert max(height, width) == meal_config.IMAGE_LONG_SIDE
    assert (width, height) == (768, 576)
    assert len(sent) < len(original)


def test_a_small_photo_is_not_enlarged(wired):
    client = FakeClient(RICE_PLATE)
    scan(client, image=photo_bytes(width=320, height=240))
    sent = client.calls[0]["contents"][0].inline_data.data
    decoded = cv2.imdecode(np.frombuffer(sent, dtype=np.uint8), cv2.IMREAD_COLOR)
    assert decoded.shape[:2] == (240, 320)


# ------------------------------------------------------------ the photo cache


def test_the_same_photo_twice_is_one_model_call_and_one_count(wired):
    wired["cache"] = True
    client = FakeClient(RICE_PLATE)
    first = scan(client)
    second = scan(client)
    assert first["cached"] is False and second["cached"] is True
    assert second["items"] == first["items"] and second["totals"] == first["totals"]
    assert len(client.calls) == 1
    assert wired["uid"] == 1 and wired["global"] == 1


def test_a_cache_hit_is_free_even_when_her_scans_and_the_app_cap_are_used_up(wired):
    wired["cache"] = True
    client = FakeClient(RICE_PLATE)
    scan(client)
    wired["uid"] = meal_config.MEAL_SCANS_PER_UID_PER_DAY
    wired["global"] = meal_config.MEAL_SCANS_GLOBAL_PER_DAY
    assert scan(client)["cached"] is True
    assert len(client.calls) == 1
    assert wired["uid"] == meal_config.MEAL_SCANS_PER_UID_PER_DAY
    assert wired["global"] == meal_config.MEAL_SCANS_GLOBAL_PER_DAY


def test_a_different_photo_is_a_miss(wired):
    wired["cache"] = True
    client = FakeClient(RICE_PLATE)
    scan(client, image=photo_bytes(width=800, height=600))
    scan(client, image=photo_bytes(width=801, height=600))
    assert len(client.calls) == 2 and wired["uid"] == 2


def test_a_refused_or_failed_scan_is_not_cached(wired):
    wired["cache"] = True
    with pytest.raises(https_fn.HttpsError):
        scan(FakeClient({"items": []}))
    with pytest.raises(https_fn.HttpsError):
        scan(FakeClient(RICE_PLATE, error=RuntimeError("down")))
    assert wired["puts"] == 0 and wired["cached"] == {}


def test_the_cache_keys_on_the_re_encoded_bytes_and_a_cache_hit_logs_cached(wired, capsys):
    wired["cache"] = True
    client = FakeClient(RICE_PLATE)
    raw = photo_bytes()
    scan(client, image=raw)
    (key,) = wired["cached"]
    assert len(key) == 64 and int(key, 16) >= 0
    assert key == hashlib.sha256(photo.reencode(raw)).hexdigest()
    assert key != hashlib.sha256(raw).hexdigest()
    capsys.readouterr()
    scan(client)
    entries, _ = _lines(capsys)
    (line,) = [e for e in entries if e.get("event") == "verification_decision"]
    assert line["outcome"] == "cached" and "promptTokens" not in line


def test_the_stored_row_holds_items_and_dates_and_no_uid(monkeypatch):
    import datetime as dt

    from nutrition import cache

    fs = fake_firestore.FakeFirestore()
    now = dt.datetime(2026, 10, 20, 9, tzinfo=dt.timezone.utc)
    items = model.parse(
        json.dumps(
            {"items": [item("Koshary", 400, ["pasta, cooked"], name_ar="كشري", dish_guess="koshary",
                            ingredients=[{"name_en": "rice", "grams": 200, "usda_terms": ["rice, white"]}])]},
            ensure_ascii=False,
        )
    )
    cache.put(fs, "abc", items, now)
    (path,) = fs.docs
    assert path == "scanCache/abc"
    row = fs.docs[path]
    assert set(row) == {"items", "createdAt", "expiresAt"}
    assert row["expiresAt"] == now + dt.timedelta(days=30)
    assert "uid-1" not in json.dumps(row, default=str) and "uid" not in row
    assert cache.get(fs, "abc", now + dt.timedelta(days=29)) == items


def test_an_expired_or_malformed_row_is_a_miss():
    import datetime as dt

    from nutrition import cache

    fs = fake_firestore.FakeFirestore()
    now = dt.datetime(2026, 10, 20, 9, tzinfo=dt.timezone.utc)
    items = model.parse(json.dumps({"items": [item("Rice", 200, ["rice"], name_ar="رز")]}))
    cache.put(fs, "abc", items, now)
    assert cache.get(fs, "abc", now + dt.timedelta(days=30)) is None
    assert cache.get(fs, "abc", now + dt.timedelta(days=31)) is None
    assert cache.get(fs, "missing", now) is None
    fs.docs["scanCache/bad"] = {"items": [{"nope": 1}], "expiresAt": now + dt.timedelta(days=1)}
    assert cache.get(fs, "bad", now) is None


def test_a_cache_that_cannot_be_read_or_written_never_fails_a_scan(wired, monkeypatch, capsys):
    monkeypatch.undo()
    monkeypatch.setattr(main.store, "has_meal_photo_consent", lambda uid: True)
    monkeypatch.setattr(main.store, "uid_daily_count_and_increment", lambda uid, field: 1)
    monkeypatch.setattr(main.store, "daily_count_and_increment", lambda field="sessions": 1)

    def broken():
        raise RuntimeError("firestore down")

    monkeypatch.setattr(main.store, "db", broken)
    answer = scan(FakeClient(RICE_PLATE))
    assert answer["cached"] is False and answer["items"]


# --------------------------------------------------------------- the log line


def _lines(capsys):
    captured = capsys.readouterr()
    out = []
    for raw in (captured.out + captured.err).splitlines():
        try:
            out.append(json.loads(raw))
        except ValueError:
            continue
    return out, captured.out + captured.err


def test_one_decision_line_with_tokens_and_no_image_or_food_name(wired, capsys):
    image = photo_bytes()
    encoded = b64(image)
    client = FakeClient(
        {"items": [item("Koshary", 400, ["pasta, cooked"], name_ar="كشري", dish_guess="koshary")]}
    )
    capsys.readouterr()
    scan(client, image=image)
    entries, text = _lines(capsys)
    decisions = [e for e in entries if e.get("event") == "verification_decision"]
    assert len(decisions) == 1
    line = decisions[0]
    assert line["callable"] == "analyze_meal_photo" and line["outcome"] == "estimated"
    assert line["count"] == 1 and line["promptTokens"] == 1290 and line["outputTokens"] == 212
    assert isinstance(line["latencyMs"], int)
    for entry in entries:
        assert set(entry) - {"severity", "message"} <= logs.ALLOWED_KEYS
        assert entry.get("event") != "log_field_refused"
    assert encoded[:200] not in text and encoded[-200:] not in text
    assert "GPS" not in text
    assert "Koshary" not in text and "كشري" not in text and "uid-1" not in text


def test_an_outage_logs_its_reason_and_nothing_of_the_error(wired, capsys):
    client = FakeClient(RICE_PLATE, error=RuntimeError("secret upstream detail"))
    capsys.readouterr()
    with pytest.raises(https_fn.HttpsError):
        scan(client)
    entries, text = _lines(capsys)
    (line,) = [e for e in entries if e.get("event") == "verification_decision"]
    assert line["reasons"] == [reasons.MEAL_SERVICE_UNAVAILABLE]
    assert "secret upstream detail" not in text


# ----------------------------------------------------------------- consent


@pytest.fixture
def consents(monkeypatch):
    written = []
    monkeypatch.setattr(
        main.store,
        "write_meal_photo_consent",
        lambda uid, locale, app_version: written.append((uid, locale, app_version)),
    )
    return written


def test_recording_the_consent(consents):
    answer = inner("record_meal_photo_consent")(
        request({"consentVersion": config.MEAL_PHOTO_CONSENT_VERSION, "locale": "ar", "appVersion": "1.0.0+12"})
    )
    assert answer == {"ok": True, "consentVersion": 1}
    assert consents == [("uid-1", "ar", "1.0.0+12")]


def test_an_ios_wrapped_version_is_accepted(consents):
    wrapped = {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "1"}
    answer = inner("record_meal_photo_consent")(request({"consentVersion": wrapped}))
    assert answer["ok"] is True and len(consents) == 1


@pytest.mark.parametrize("version", [None, 0, 2, "1", True])
def test_any_other_version_is_refused(consents, version):
    error = raises(
        lambda: inner("record_meal_photo_consent")(request({"consentVersion": version})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
    assert consents == []


@pytest.fixture
def fs(monkeypatch):
    db = fake_firestore.FakeFirestore()
    monkeypatch.setattr(store, "db", lambda: db)
    monkeypatch.setattr(store.firestore, "transactional", fake_firestore.transactional)
    return db


def test_the_consent_record_is_written_once_with_allowed_fields(fs):
    assert store.write_meal_photo_consent("her", "ar", "1.0.0+12") is True
    path = f"{config.COL_USERS}/her/{config.COL_CONSENTS}/meal-photo-v1"
    record = fs.docs[path]
    assert set(record) == {"version", "at", "locale", "appVersion"}
    assert record["version"] == 1 and record["locale"] == "ar"
    assert store.has_meal_photo_consent("her") is True
    assert store.write_meal_photo_consent("her", "en", None) is False
    assert fs.docs[path]["locale"] == "ar"


def test_a_bad_locale_or_app_version_is_left_out(fs):
    store.write_meal_photo_consent("her", "fr", "<script>")
    record = fs.docs[f"{config.COL_USERS}/her/{config.COL_CONSENTS}/meal-photo-v1"]
    assert set(record) == {"version", "at"}


def test_the_refund_gives_back_one_scan_today_and_never_goes_below_zero(fs, monkeypatch):
    monkeypatch.setattr(store, "_today", lambda: "2026-10-17")
    store.uid_daily_count_and_increment("her", "mealScans")
    store.uid_daily_count_and_increment("her", "mealScans")
    store.uid_daily_count_and_increment("her", "verifies")
    store.uid_daily_refund("her", "mealScans")
    daily = fs.docs[f"{config.COL_LEDGER}/her"]["daily"]
    assert daily == {"day": "2026-10-17", "mealScans": 1, "verifies": 1}
    store.uid_daily_refund("her", "mealScans")
    store.uid_daily_refund("her", "mealScans")
    assert fs.docs[f"{config.COL_LEDGER}/her"]["daily"]["mealScans"] == 0


def test_a_refund_after_midnight_leaves_the_new_day_alone(fs, monkeypatch):
    monkeypatch.setattr(store, "_today", lambda: "2026-10-17")
    store.uid_daily_count_and_increment("her", "mealScans")
    monkeypatch.setattr(store, "_today", lambda: "2026-10-18")
    store.uid_daily_refund("her", "mealScans")
    assert fs.docs[f"{config.COL_LEDGER}/her"]["daily"] == {"day": "2026-10-17", "mealScans": 1}


def test_an_unverified_account_cannot_scan():
    error = raises(
        lambda: inner("analyze_meal_photo")(
            request({"imageJpeg": b64(photo_bytes())}, token={"verified": False})
        ),
        https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    )
    assert error.message == reasons.NOT_VERIFIED


# ------------------------------------------------- withdrawal and optional choices


def test_withdrawing_the_meal_photo_consent_blocks_the_scan_until_she_agrees_again(fs):
    path = f"{config.COL_USERS}/her/{config.COL_CONSENTS}/meal-photo-v1"
    assert store.withdraw_meal_photo_consent("her") is False
    store.write_meal_photo_consent("her", "ar", "1.0.0+12")
    assert store.withdraw_meal_photo_consent("her") is True
    assert "withdrawnAt" in fs.docs[path] and fs.docs[path]["locale"] == "ar"
    assert store.has_meal_photo_consent("her") is False
    assert store.withdraw_meal_photo_consent("her") is False
    assert store.write_meal_photo_consent("her", "en", None) is True
    assert store.has_meal_photo_consent("her") is True
    assert "withdrawnAt" not in fs.docs[path] and fs.docs[path]["locale"] == "en"


def test_the_withdraw_callable_reaches_the_store(monkeypatch):
    seen = []
    monkeypatch.setattr(main.store, "withdraw_meal_photo_consent", lambda uid: seen.append(uid))
    assert inner("withdraw_meal_photo_consent")(request({})) == {"ok": True}
    assert seen == ["uid-1"]


def test_a_choice_is_kept_with_its_state_and_every_change_is_stamped(fs):
    path = f"{config.COL_USERS}/her/{config.COL_CONSENTS}/analytics-v2"
    store.write_choice_consent("her", "analytics", True, "ar", "1.1.0+5")
    record = fs.docs[path]
    assert record["state"] == "granted" and record["version"] == 2
    assert {"at", "grantedAt", "locale", "appVersion"} <= set(record) and "withdrawnAt" not in record
    store.write_choice_consent("her", "analytics", False, "ar", "1.1.0+5")
    record = fs.docs[path]
    assert record["state"] == "withdrawn" and {"grantedAt", "withdrawnAt"} <= set(record)


@pytest.mark.parametrize(
    "body",
    [
        {"purpose": "ads", "granted": True, "consentVersion": 1},
        {"purpose": "crash", "granted": "yes", "consentVersion": 1},
        {"purpose": "crash", "granted": True},
    ],
)
def test_a_bad_choice_is_refused(monkeypatch, body):
    seen = []
    monkeypatch.setattr(main.store, "write_choice_consent", lambda *a: seen.append(a))
    with pytest.raises(https_fn.HttpsError):
        inner("record_consent_choice")(request(body))
    assert seen == []


def test_a_choice_with_the_current_version_is_recorded(monkeypatch):
    seen = []
    monkeypatch.setattr(main.store, "write_choice_consent", lambda *a: seen.append(a))
    body = {"purpose": "analytics", "granted": False, "consentVersion": 2, "locale": "en"}
    assert inner("record_consent_choice")(request(body)) == {"ok": True}
    assert seen == [("uid-1", "analytics", False, "en", None)]
    error = raises(
        lambda: inner("record_consent_choice")(request({**body, "consentVersion": 1})),
        https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    )
    assert error.message == reasons.CONSENT_MISSING
