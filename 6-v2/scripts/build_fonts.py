# -*- coding: utf-8 -*-
"""Builds app/assets/fonts/Rubik-{400,500,600,700}.ttf from the woff2 subsets.
Run from the repo root: python3 6-v2/scripts/build_fonts.py

The repo ships Rubik as per-script woff2 subsets of a VARIABLE font (wght axis
300-900, default 300). Flutter cannot load woff2, and a family may declare only
one file per weight -- so each weight's latin + latin-ext + arabic subsets have to
become a single static TTF. The wght axis must be pinned BEFORE merging: merging a
variable font fails with "VarStore has no attribute mergeMap". Skipping the merge
entirely renders the whole Arabic UI as tofu boxes, which no analyzer will catch.
"""
import os, sys, tempfile
from fontTools.ttLib import TTFont
from fontTools.merge import Merger
from fontTools.varLib import instancer

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "6-v2/assets/fonts")
OUT = os.path.join(ROOT, "app/assets/fonts")
WEIGHTS = ["400", "500", "600", "700"]
SUBSETS = ["latin", "latin-ext", "arabic"]
SUBFAMILY = {"400": "Regular", "500": "Medium", "600": "SemiBold", "700": "Bold"}
ARABIC_PROBE = [0x0627, 0x0628, 0x062C, 0x0645]
LATIN_PROBE = [0x0041, 0x0061, 0x0031]


def to_static(src, dst, weight):
    f = TTFont(src)
    if "fvar" in f:
        f = instancer.instantiateVariableFont(f, {"wght": float(weight)}, inplace=False)
    f.flavor = None
    f.save(dst)
    f.close()


def codepoints(path):
    f = TTFont(path)
    cps = set()
    for t in f["cmap"].tables:
        cps |= set(t.cmap.keys())
    f.close()
    return cps


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="rubik-")
    ok = True
    for w in WEIGHTS:
        parts = []
        for s in SUBSETS:
            src = os.path.join(SRC, f"rubik-{s}-{w}.woff2")
            if not os.path.exists(src):
                continue
            dst = os.path.join(tmp, f"{s}-{w}.ttf")
            to_static(src, dst, w)
            parts.append(dst)
        if not parts:
            print(f"weight {w}: no source subsets found", file=sys.stderr)
            ok = False
            continue
        out = os.path.join(OUT, f"Rubik-{w}.ttf")
        if len(parts) == 1:
            os.replace(parts[0], out)
        else:
            merged = Merger().merge(parts)
            merged.save(out)
            merged.close()
        # The merged file inherits the 300-weight name table from its source.
        f = TTFont(out)
        f["OS/2"].usWeightClass = int(w)
        for rec in f["name"].names:
            if rec.nameID == 1:
                rec.string = "Rubik"
            elif rec.nameID == 2:
                rec.string = SUBFAMILY[w]
            elif rec.nameID == 4:
                rec.string = f"Rubik {SUBFAMILY[w]}"
            elif rec.nameID == 6:
                rec.string = f"Rubik-{SUBFAMILY[w]}"
        f.save(out)
        f.close()
        cps = codepoints(out)
        ar = all(c in cps for c in ARABIC_PROBE)
        la = all(c in cps for c in LATIN_PROBE)
        ok = ok and ar and la
        print(f"Rubik-{w}.ttf  {os.path.getsize(out):>7} bytes  {len(cps):>4} glyphs  "
              f"arabic={'YES' if ar else 'NO'}  latin={'YES' if la else 'NO'}")
    print("\nOK: every weight carries both scripts" if ok
          else "\nFAILED: a weight is missing a script -- Arabic would render as tofu")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
