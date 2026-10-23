"""Measure the meal scan on labelled photos: what it finds, how close its grams
are, how often a food reaches the nutrition tables, and what each scan costs in
tokens. The same steps as analyze_meal_photo (re-encode, one model call,
resolve), without auth, consent, counts or the cache.

    cd functions
    .venv/bin/python -I tools/eval_meal_scan.py PHOTOS_DIR [--limit N]

PHOTOS_DIR holds the photos and labels.json:

    {"photos": [
      {"file": "koshary.jpg",
       "expect": [{"match": ["koshary", "koshari", "كشري"], "grams": 400}]},
      {"file": "breakfast.jpg",
       "expect": [{"match": ["ful", "fava"], "grams": 200},
                  {"match": ["bread", "baladi", "عيش"]}]}
    ]}

An expected food counts as found when any of its `match` words appears in an
item's English or Arabic name, dish guess or matched table name. `grams` is
optional; when given, the gram error is measured on the item that matched.
Runs against Vertex AI with this machine's gcloud login, so each photo is one
paid model call.
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from nutrition import config, meal, model, photo  # noqa: E402


def _words(item: dict) -> str:
    fields = [
        item.get("nameEn"),
        item.get("nameAr"),
        item.get("dishGuess"),
        item.get("usdaName"),
        item.get("name_en"),
        item.get("name_ar"),
        item.get("dish_guess"),
    ]
    return " ".join(str(f) for f in fields if f).lower()


def _grams(item: dict):
    for key in ("grams", "estimatedGrams"):
        value = item.get(key)
        if isinstance(value, (int, float)):
            return float(value)
    return None


def evaluate(folder: str, limit: int | None) -> int:
    with open(os.path.join(folder, "labels.json"), encoding="utf-8") as f:
        photos = json.load(f)["photos"]
    if limit:
        photos = photos[:limit]

    found = expected = 0
    gram_errors: list[float] = []
    matched_items = all_items = 0
    prompt_tokens: list[int] = []
    output_tokens: list[int] = []
    latencies: list[float] = []
    failures = 0

    print(f"model {config.MODEL} · {config.LOCATION} · {config.MEDIA_RESOLUTION}")
    for entry in photos:
        path = os.path.join(folder, entry["file"])
        with open(path, "rb") as f:
            jpeg = photo.reencode(f.read())
        started = time.monotonic()
        try:
            result = model.analyse(jpeg)
        except model.ServiceUnavailable as down:
            failures += 1
            print(f"{entry['file']}: model unavailable ({down.label})")
            continue
        except model.Unclear:
            failures += 1
            print(f"{entry['file']}: answer unclear")
            continue
        latencies.append(time.monotonic() - started)
        if result.prompt_tokens is not None:
            prompt_tokens.append(result.prompt_tokens)
        if result.output_tokens is not None:
            output_tokens.append(result.output_tokens)

        answer = meal.resolve(result.items)
        items = answer["items"]
        all_items += len(items)
        matched_items += sum(1 for i in items if i.get("matched"))

        notes = []
        for want in entry["expect"]:
            expected += 1
            words = [w.lower() for w in want["match"]]
            hit = next((i for i in items if any(w in _words(i) for w in words)), None)
            if hit is None:
                notes.append(f"MISSED {want['match'][0]}")
                continue
            found += 1
            got = _grams(hit)
            if want.get("grams") and got is not None:
                error = abs(got - want["grams"]) / want["grams"]
                gram_errors.append(error)
                notes.append(f"{want['match'][0]} {got:.0f} g vs {want['grams']} g")
            else:
                notes.append(f"{want['match'][0]} found")
        names = ", ".join(str(i.get("nameEn") or i.get("name_en")) for i in items)
        print(f"{entry['file']}: [{names}] · {'; '.join(notes)} · "
              f"{result.prompt_tokens} in / {result.output_tokens} out")

    print()
    print(f"photos {len(photos)} · failed {failures}")
    if expected:
        print(f"found {found} of {expected} expected foods ({100 * found / expected:.0f}%)")
    if gram_errors:
        print(f"grams: median error {100 * statistics.median(gram_errors):.0f}%, "
              f"within 25%: {100 * sum(e <= 0.25 for e in gram_errors) / len(gram_errors):.0f}%")
    if all_items:
        print(f"items reaching the nutrition tables {matched_items} of {all_items} "
              f"({100 * matched_items / all_items:.0f}%)")
    if prompt_tokens:
        print(f"tokens per scan: {statistics.mean(prompt_tokens):.0f} in, "
              f"{statistics.mean(output_tokens or [0]):.0f} out (output includes thinking)")
    if latencies:
        print(f"latency: median {statistics.median(latencies):.1f} s")
    return 1 if failures == len(photos) else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("folder")
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    return evaluate(args.folder, args.limit)


if __name__ == "__main__":
    raise SystemExit(main())
