#!/usr/bin/env python3
"""Add UI strings (English + Arabic) to the generated dictionary, safely.

The ARB files are generated: English source -> Arabic in
6-v2/i18n/ar-extra.json, merged by 6-v2/src/merge-i18n.mjs, written to
lib/l10n by 6-v2/src/build-flutter.mjs, and compiled by `flutter gen-l10n`.
Several people (or agents) adding strings at once would overwrite each
other, so this takes a lock, merges, regenerates, and prints the getter name
each string got.

Usage:
  python3 tool/add_strings.py strings.json

strings.json:
  {
    "strings": {"Write a post": "اكتبي منشورًا"},
    "parameterised": {
      "{name} joined": {
        "description": "Why the placeholder exists.",
        "placeholders": {"name": {"type": "String", "example": "Mai"}}
      }
    }
  }
Every key in "parameterised" must also appear in "strings".
"""

import json
import os
import subprocess
import sys
import time

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(APP)
V2 = os.path.join(ROOT, "6-v2")
EXTRA = os.path.join(V2, "i18n", "ar-extra.json")
BUILD = os.path.join(V2, "src", "build-flutter.mjs")
LOCK = "/tmp/ownhub-l10n.lock"
FLUTTER = os.path.expanduser("~/development/flutter/bin/flutter")


def acquire():
    for _ in range(600):
        try:
            os.mkdir(LOCK)
            return
        except FileExistsError:
            time.sleep(1)
    sys.exit("could not take the l10n lock after 10 minutes: " + LOCK)


def insert_parameterised(entries):
    if not entries:
        return
    src = open(BUILD, encoding="utf-8").read()
    start = src.index("const PARAMETERISED = {")
    close = src.index("\n  };\n", start)
    body = src[start:close]
    add = ""
    for english, meta in entries.items():
        if json.dumps(english) in body or ("'" + english + "'") in body:
            continue
        add += "\n    " + json.dumps(english, ensure_ascii=False) + ": " + json.dumps(
            meta, ensure_ascii=False
        ) + ","
    if add:
        src = src[:close] + add + src[close:]
        open(BUILD, "w", encoding="utf-8").write(src)


def main():
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    strings = spec.get("strings", {})
    params = spec.get("parameterised", {})
    missing = [k for k in params if k not in strings]
    if missing:
        sys.exit("parameterised strings missing from 'strings': %s" % missing)

    acquire()
    try:
        extra = json.load(open(EXTRA, encoding="utf-8"))
        for en, ar in strings.items():
            extra[en] = ar
        with open(EXTRA, "w", encoding="utf-8") as f:
            json.dump(extra, f, ensure_ascii=False, indent=1)
        insert_parameterised(params)
        subprocess.run(["node", "src/merge-i18n.mjs"], cwd=V2, check=True,
                       stdout=subprocess.DEVNULL)
        subprocess.run(["node", "src/build-flutter.mjs"], cwd=V2, check=True,
                       stdout=subprocess.DEVNULL)
        subprocess.run([FLUTTER, "gen-l10n"], cwd=APP, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        arb = json.load(open(os.path.join(APP, "lib", "l10n", "app_en.arb"),
                             encoding="utf-8"))
        by_value = {}
        for k, v in arb.items():
            if not k.startswith("@") and isinstance(v, str):
                by_value.setdefault(v, k)
        for en in strings:
            print("%-40s l10n.%s" % (en[:40], by_value.get(en, "??")))
    finally:
        os.rmdir(LOCK)


if __name__ == "__main__":
    main()
