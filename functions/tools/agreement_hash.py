#!/usr/bin/env python3
"""SHA-256 of the published Coach Agreement text, one per language.

    functions/.venv/bin/python functions/tools/agreement_hash.py          # rewrite
    functions/.venv/bin/python functions/tools/agreement_hash.py --check  # compare

The hash covers the page body as the site build renders it (tokens filled,
drafting notes stripped), not the page shell, so a change of menu or footer
does not move it. `accept_coach_terms` stores the hash of the language she read
beside her consent. Run it whenever the agreement text changes; a test fails
until the committed file matches the site source.
"""

import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(ROOT, "site", "_build")
OUT = os.path.join(ROOT, "functions", "coaching", "agreement_hashes.json")
VERSION = 2


def compute() -> dict:
    sys.path.insert(0, BUILD)
    import build as site
    import pages_ar
    import pages_en

    cfg = site.Config(os.path.join(ROOT, "site", "config.json"), None)
    out = {"version": VERSION}
    for lang, module in (("en", pages_en), ("ar", pages_ar)):
        page = module.build(cfg, lang, site.mailto_link, site.store_badges, site.shot)["coach-agreement"]
        body = site.strip_drafting_notes(site.render_tokens(page["body"], cfg, lang))
        out[lang] = hashlib.sha256(body.encode("utf-8")).hexdigest()
    return out


if __name__ == "__main__":
    fresh = compute()
    if "--check" in sys.argv:
        same = json.load(open(OUT, encoding="utf-8")) == fresh
        print("agreement hashes match" if same else "agreement hashes are stale")
        sys.exit(0 if same else 1)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(fresh, fh, indent=2)
        fh.write("\n")
    print(fresh)
