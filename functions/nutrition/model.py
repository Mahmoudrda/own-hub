"""The one model call per scan, and the check of what comes back.

Gemini on Vertex AI names the foods and estimates their grams. It is never
asked for, and never trusted with, energy or macro numbers: the schema has no
field for them and the server computes them from the dish table and USDA.

The client is created once per process, lazily, so the SDK loads only on the
first scan; tests replace it through `set_client`. The SDK's own retries stay
off (no retry_options), so a scan is exactly one call to the model.
"""

from __future__ import annotations

import json
import math
import threading
from dataclasses import dataclass, field
from typing import Any, Optional

from . import config

SYSTEM_PROMPT = """You look at one photo of a meal for a food diary in Egypt. Most meals are Egyptian or Arabic home or street food.
Return JSON only, matching the schema. Never output calories, macros or any nutrition number.
If there is no food or drink in the photo, return {"items": []}.
List each distinct food or drink you can see, at most 8.
- name_en: short English name. name_ar: the name an Egyptian would say, in Egyptian Arabic.
- dish_guess: for a known Egyptian, Levantine or Gulf dish, its usual English spelling (koshary, ful medames, taameya, molokhia, mahshi, fattah, hawawshi, shawarma, kabsa). Leave it out otherwise.
- grams: the edible weight you can see. Estimate it realistically from the plate size, cutlery, bread or hands for scale, the depth of the food and typical Egyptian portions.
- confidence: 0 to 1, how sure you are what the food is.
- usda_terms: 1 to 3 short USDA FoodData Central style terms, the food first, then descriptors, with the cooking state, separated by commas, e.g. "rice, white, cooked", "chicken, breast, grilled", "bread, pita, white".
- For a mixed dish (koshary, ful, molokhia, stews, salads, sandwiches, rice with toppings), also give ingredients: name_en, grams and usda_terms for each, grams adding up to the item's grams. Include the cooking oil, ghee or butter it would usually hold."""

USER_PROMPT = "List the foods in this photo."

_TERMS_SCHEMA = {
    "type": "ARRAY",
    "items": {"type": "STRING"},
    "maxItems": config.MAX_TERMS,
}

RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "items": {
            "type": "ARRAY",
            "maxItems": config.MAX_ITEMS,
            "items": {
                "type": "OBJECT",
                "properties": {
                    "name_en": {"type": "STRING"},
                    "name_ar": {"type": "STRING"},
                    "dish_guess": {"type": "STRING"},
                    "grams": {"type": "NUMBER"},
                    "confidence": {"type": "NUMBER"},
                    "usda_terms": _TERMS_SCHEMA,
                    "ingredients": {
                        "type": "ARRAY",
                        "maxItems": config.MAX_INGREDIENTS,
                        "items": {
                            "type": "OBJECT",
                            "properties": {
                                "name_en": {"type": "STRING"},
                                "grams": {"type": "NUMBER"},
                                "usda_terms": _TERMS_SCHEMA,
                            },
                            "required": ["name_en", "grams", "usda_terms"],
                        },
                    },
                },
                "required": ["name_en", "name_ar", "grams", "confidence", "usda_terms"],
            },
        }
    },
    "required": ["items"],
}


class ServiceUnavailable(Exception):
    """The model could not be reached, timed out or failed. Carries the error's
    status code and name when the service gave one (for example 403 and
    PERMISSION_DENIED), never its message: the message could quote the request."""

    def __init__(self, code: Optional[int] = None, status: Optional[str] = None):
        super().__init__()
        self.code = code
        self.status = status

    @property
    def label(self) -> str:
        """"403 PERMISSION_DENIED", "TimeoutError" or "unknown", for the log."""
        parts = [str(self.code) if self.code is not None else "", self.status or ""]
        return " ".join(p for p in parts if p) or "unknown"


def _error_status(error: BaseException) -> tuple:
    """The status code and name of a failed call, from the SDK's own fields only."""
    code = getattr(error, "code", None)
    status = getattr(error, "status", None)
    code = code if isinstance(code, int) and not isinstance(code, bool) else None
    status = status if isinstance(status, str) and status.isupper() else None
    if code is None and status is None:
        status = type(error).__name__ if type(error).__name__.isidentifier() else None
    return code, status


class Unclear(Exception):
    """The model answered with nothing usable. Carries the token counts of the
    call, when there was one, for the decision log; never the text."""

    def __init__(self, prompt_tokens: Optional[int] = None, output_tokens: Optional[int] = None):
        super().__init__()
        self.prompt_tokens = prompt_tokens
        self.output_tokens = output_tokens


@dataclass
class Ingredient:
    name_en: str
    grams: float
    usda_terms: list


@dataclass
class Item:
    name_en: str
    name_ar: str
    dish_guess: str
    grams: float
    confidence: float
    usda_terms: list
    ingredients: list = field(default_factory=list)


@dataclass
class Result:
    items: list
    prompt_tokens: Optional[int]
    output_tokens: Optional[int]


# ------------------------------------------------------------------ the client

_client = None
_client_lock = threading.Lock()


def set_client(client) -> None:
    """Replace the client (tests), or pass None to go back to the real one."""
    global _client
    _client = client


def _real_client():
    from google import genai
    from google.genai import types

    return genai.Client(
        vertexai=True,
        project=config.PROJECT,
        location=config.LOCATION,
        http_options=types.HttpOptions(timeout=config.TIMEOUT_MS),
    )


def client():
    global _client
    if _client is None:
        with _client_lock:
            if _client is None:
                _client = _real_client()
    return _client


def generation_config():
    from google.genai import types

    return types.GenerateContentConfig(
        system_instruction=SYSTEM_PROMPT,
        temperature=config.TEMPERATURE,
        max_output_tokens=config.MAX_OUTPUT_TOKENS,
        response_mime_type="application/json",
        response_schema=RESPONSE_SCHEMA,
        thinking_config=types.ThinkingConfig(**config.thinking_settings(config.MODEL)),
        media_resolution=types.MediaResolution(config.MEDIA_RESOLUTION),
        # No tools are offered, so nothing is called back automatically.
        automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
    )


def analyse(jpeg: bytes) -> Result:
    """One model call. Raises ServiceUnavailable or Unclear, never with the
    model's text or the exception's message attached: either could quote the
    request."""
    try:
        from google.genai import types

        response = client().models.generate_content(
            model=config.MODEL,
            contents=[
                types.Part.from_bytes(data=jpeg, mime_type="image/jpeg"),
                USER_PROMPT,
            ],
            config=generation_config(),
        )
    except Exception as error:
        raise ServiceUnavailable(*_error_status(error)) from None
    usage = getattr(response, "usage_metadata", None)
    prompt_tokens = _count(getattr(usage, "prompt_token_count", None))
    output_tokens = _count(getattr(usage, "candidates_token_count", None))
    thoughts = _count(getattr(usage, "thoughts_token_count", None))
    if output_tokens is not None and thoughts:
        # Thinking is billed at the output rate: 0 on 2.5 with budget 0, not on 3.x.
        output_tokens += thoughts
    try:
        text = _text(response)
        items = parse(text)
    except Unclear:
        raise Unclear(prompt_tokens, output_tokens) from None
    return Result(items=items, prompt_tokens=prompt_tokens, output_tokens=output_tokens)


def _count(value) -> Optional[int]:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _text(response) -> str:
    candidates = getattr(response, "candidates", None) or []
    if candidates:
        reason = getattr(candidates[0], "finish_reason", None)
        name = getattr(reason, "name", reason)
        if name not in (None, "STOP", "FINISH_REASON_UNSPECIFIED"):
            # MAX_TOKENS cuts the JSON short; SAFETY and the rest leave nothing
            # that can be trusted.
            raise Unclear()
    try:
        text = response.text
    except Exception:
        raise Unclear() from None
    if not isinstance(text, str) or not text.strip():
        raise Unclear()
    return text


# ----------------------------------------------------------------- the check


def _clean_text(value: Any, limit: int) -> str:
    if not isinstance(value, str):
        return ""
    text = "".join(ch for ch in value if ch.isprintable()).strip()
    return " ".join(text.split())[:limit]


def _terms(value: Any) -> list:
    if not isinstance(value, list):
        return []
    out = []
    for term in value:
        cleaned = _clean_text(term, config.MAX_TERM_CHARS)
        if cleaned and cleaned not in out:
            out.append(cleaned)
        if len(out) >= config.MAX_TERMS:
            break
    return out


def _grams(value: Any) -> Optional[float]:
    """A usable weight, or None. Zero, negative, NaN and non-numbers are not
    weights; above MAX_GRAMS is clamped to it."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    if not math.isfinite(value) or value <= 0:
        return None
    return float(min(round(value), config.MAX_GRAMS)) or None


def _confidence(value: Any) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return 0.0
    value = float(value)
    if not math.isfinite(value):
        return 0.0
    return max(0.0, min(1.0, value))


def parse(text: str) -> list:
    """The model's JSON to Items, keeping only well-formed entries.

    Raises Unclear for anything that is not the schema's shape. An empty list
    is returned as it is: no food seen is an answer, not a malfunction."""
    try:
        data = json.loads(text)
    except (TypeError, ValueError):
        raise Unclear() from None
    if not isinstance(data, dict) or not isinstance(data.get("items"), list):
        raise Unclear()
    raw_items = data["items"]
    if not raw_items:
        return []
    items = []
    for raw in raw_items[: config.MAX_ITEMS]:
        if not isinstance(raw, dict):
            continue
        name_en = _clean_text(raw.get("name_en"), config.MAX_NAME_CHARS)
        grams = _grams(raw.get("grams"))
        if not name_en or grams is None:
            continue
        ingredients = []
        raw_ingredients = raw.get("ingredients")
        if isinstance(raw_ingredients, list):
            for part in raw_ingredients[: config.MAX_INGREDIENTS]:
                if not isinstance(part, dict):
                    continue
                part_name = _clean_text(part.get("name_en"), config.MAX_NAME_CHARS)
                part_grams = _grams(part.get("grams"))
                if part_name and part_grams is not None:
                    ingredients.append(
                        Ingredient(part_name, part_grams, _terms(part.get("usda_terms")))
                    )
        items.append(
            Item(
                name_en=name_en,
                name_ar=_clean_text(raw.get("name_ar"), config.MAX_NAME_CHARS),
                dish_guess=_clean_text(raw.get("dish_guess"), config.MAX_NAME_CHARS),
                grams=grams,
                confidence=_confidence(raw.get("confidence")),
                usda_terms=_terms(raw.get("usda_terms")),
                ingredients=ingredients,
            )
        )
    if not items:
        raise Unclear()
    return items
