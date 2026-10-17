"""Meal photo settings. Compiled in, like identity/config.py: never Remote
Config, never client code.

The meal-photo consent version lives in identity/config.py beside every other
consent version, because the record sits under users/{uid}/consents with them.
"""

from __future__ import annotations

# ------------------------------------------------------------------ the model

PROJECT = "own-hub"

LOCATION = "europe-west3"
"""Frankfurt, the region the rest of her data already lives in. Vertex AI
processes the request in this region; the privacy policy names it."""

MODEL = "gemini-3.8-flash"
"""Gemini Flash, the owner's choice (17 October 2026). gemini-2.5-flash
retires on Vertex AI on 20 October 2026 and names this as its replacement;
3.8 Flash is served in europe-west3 and supported until at least September
2027. Gemini 3.5 Flash-Lite is the cheaper switch if cost ever matters more
than accuracy: change this one line and `thinking_settings` follows."""

TIMEOUT_MS = 20_000
"""One scan waits at most this long for the model, then she is told the
service is unavailable. The SDK's own retries stay off (no retry_options), so
a scan is exactly one model call."""

MAX_OUTPUT_TOKENS = 600
TEMPERATURE = 0.1


def thinking_settings(model: str) -> dict:
    """The ThinkingConfig fields for this model family.

    Gemini 2.5 turns thinking off with thinking_budget=0. Gemini 3 and later
    take thinking_level only: thinking_budget is deprecated there and can
    answer 400 INVALID_ARGUMENT. 3.8 Flash has no MINIMAL level, so LOW is
    the cheapest level every 3.x Flash accepts."""
    if model.startswith("gemini-2."):
        return {"thinking_budget": 0}
    return {"thinking_level": "LOW"}


# -------------------------------------------------------------------- limits

MEAL_SCANS_PER_UID_PER_DAY = 5
"""The owner's rule: five photo scans per woman per UTC day. Counted on
verificationLedger/{uid}.daily.mealScans by store.uid_daily_count_and_increment,
before the global cap, so one account cannot spend everyone's allowance."""

MEAL_SCANS_GLOBAL_PER_DAY = 500
"""The cost ceiling for the whole app per UTC day, on the sharded
verificationStats/{day}_s{n}.mealScans counter. Past it every scan is refused
with meal_scans_paused and the meal_scans_paused warning is logged once per
refused call, so an alert can match it."""

UID_COUNTER_FIELD = "mealScans"
GLOBAL_COUNTER_FIELD = "mealScans"

# --------------------------------------------------------------------- image

IMAGE_LONG_SIDE = 768
"""Longest edge of the JPEG the model sees. One 768 px tile is the cheapest
image a Gemini model can be sent above 384 px, and a plate is still clearly
readable at it."""

JPEG_QUALITY = 80

# ------------------------------------------------------- what the model sends

MAX_ITEMS = 8
MAX_INGREDIENTS = 8
MAX_TERMS = 3
MAX_NAME_CHARS = 60
MAX_TERM_CHARS = 60

MAX_GRAMS = 3000
"""Grams above this on one item or ingredient are clamped to it: no single food
on a photographed plate weighs three kilograms, and she corrects the number on
the check screen. Zero, negative or non-numeric grams drop the entry."""

MIN_CONFIDENCE = 0.3
"""Below this the model is guessing what the food is, so the item is returned
with matched=false and no numbers rather than with a confident-looking
estimate built on a guess."""
