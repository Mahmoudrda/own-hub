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

MODEL = "gemini-3.5-flash"
"""Gemini 3.5 Flash, served in europe-west3 with the lowest thinking level (see
`thinking_settings`). Gemini 2.5 Flash retires on 20 October 2026 and
Flash-Lite is not served in this region. Changing this one line is enough: a
gemini-2.x name gets a zero thinking budget instead."""

TIMEOUT_MS = 20_000
"""One scan waits at most this long for the model, then she is told the
service is unavailable. The SDK's own retries stay off (no retry_options), so
a scan is exactly one model call."""

MAX_OUTPUT_TOKENS = 600
"""The model answers with names, grams and search terms only; every number
comes from nutrition/. The largest answer in the test fixtures is about 115
tokens, and a plate of four dishes that each list ingredients is about 430,
which leaves room for the low thinking level."""
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

MEAL_SCANS_GLOBAL_PER_DAY = 300
"""The cost ceiling for the whole app per UTC day, on the sharded
verificationStats/{day}_s{n}.mealScans counter. Past it every scan is refused
with meal_scans_paused and the meal_scans_paused warning is logged once per
refused call, so an alert can match it. Only a call to the model counts: a
photo answered from scanCache costs neither her allowance nor this one."""

SCAN_CACHE_COLLECTION = "scanCache"
SCAN_CACHE_DAYS = 30
"""A scan result is kept for the exact same photo this long. The collection has
a Firestore TTL policy on `expiresAt`; the read also ignores an expired row, so
the policy only has to tidy up."""

COMMUNITY_FOODS_PER_UID_PER_DAY = 10
"""Foods one woman may offer per UTC day (submit_community_food), counted on
verificationLedger/{uid}.daily.communityFoods. It keeps a loop from becoming a
write pump; nobody logs ten new dishes in a day."""
COMMUNITY_COUNTER_FIELD = "communityFoods"

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
