#!/usr/bin/env python3
"""Draw the Hairline figures the site uses, once, as static SVG files.

    python3 _build/capture_hairline.py            (from the site/ folder)

Hairline (MIT, https://github.com/lucasmarkes/hairline, 0.5.1) builds its
drawings in the browser with JavaScript, and the site runs none. So this
script mounts each figure at rest in headless Chrome, reads back the SVG and
the library's own stylesheet, and saves them under _build/hairline/. build.py
only reads those committed files, so the build needs no browser and stays
the same on every run. Run it by hand when the figure list or the library
changes.

The library is read from admin-web/vendor/hairline/, where the dashboard
keeps the pinned, unmodified copy.

Each SVG is then made fit for a page with no inline style and no script:
  - a style attribute is removed, and the run stops if it set anything that
    shows (only transition and similar timing properties may be dropped);
  - every stroked shape gets pathLength="1", so site.css can draw it in
    with stroke-dasharray and stroke-dashoffset;
  - the svg is aria-hidden and focusable="false": the drawings are decoration.
"""

from __future__ import annotations

import functools
import html
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.dirname(HERE)
REPO = os.path.dirname(SITE)
LIBRARY = os.path.join(REPO, "admin-web", "vendor", "hairline")
OUT = os.path.join(HERE, "hairline")
sys.path.insert(0, HERE)

from make_assets import CHROME  # noqa: E402

# The figures the pages use (build.py fails on a name missing here).
FIGURES = ("lockers", "phone", "vault", "drawer", "query", "basket", "loupe")

# Style properties that only time a change. Dropping them changes nothing
# in a drawing at rest.
HARMLESS = re.compile(r"^(transition(-[a-z-]+)?|will-change)$")

# The shapes the library strokes (its stylesheet: path, polygon, ellipse,
# line), less the ones it fills only (.fo, .dot) and the dotted ones (.dash),
# whose dash pattern a pathLength of 1 would stretch.
STROKED = {"path", "polygon", "ellipse", "line"}
UNSTROKED = {"fo", "dot", "dash"}

# Coordinates come with two decimals in a 400 x 320 box drawn at 240 px or
# less; one decimal is a twentieth of a pixel and keeps the pages lighter.
GEOMETRY = {"d", "points", "cx", "cy", "r", "rx", "ry", "x1", "y1", "x2", "y2"}
_NUMBER = re.compile(r"\d+\.\d+")


def _tenth(match: re.Match) -> str:
    out = f"{float(match.group()):.1f}"
    return out[:-2] if out.endswith(".0") else out

PAGE = """<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>capture</title></head>
<body>
<pre id="out"></pre>
<script type="module">
import * as hl from "./index.js";
const names = %s;
const out = {svg: {}, css: ""};
const figures = names.map((name) => {
  const el = document.createElement("div");
  el.style.width = "400px";
  document.body.appendChild(el);
  return [name, el, hl[name](el, {intensity: 0.5, play: false, theme: "light"})];
});
setTimeout(() => {
  for (const [name, el] of figures) out.svg[name] = el.querySelector("svg").outerHTML;
  out.css = [...document.adoptedStyleSheets]
    .map((s) => [...s.cssRules].map((r) => r.cssText).join("\\n")).join("\\n");
  for (const [, , f] of figures) f.destroy();
  document.getElementById("out").textContent = JSON.stringify(out);
}, 2500);
</script>
</body></html>
"""


def capture(names) -> dict:
    """Mount every figure at rest in headless Chrome and read it back."""
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copy(os.path.join(LIBRARY, "index.js"), os.path.join(tmp, "index.js"))
        with open(os.path.join(tmp, "index.html"), "w", encoding="utf-8") as fh:
            fh.write(PAGE % json.dumps(list(names)))
        handler = functools.partial(_Quiet, directory=tmp)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            url = f"http://127.0.0.1:{server.server_address[1]}/index.html"
            result = subprocess.run(
                [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
                 f"--user-data-dir={os.path.join(tmp, 'profile')}",
                 "--virtual-time-budget=4000", "--dump-dom", url],
                check=True, capture_output=True, text=True, timeout=120,
            )
        finally:
            server.shutdown()
    match = re.search(r'<pre id="out">(.*?)</pre>', result.stdout, re.S)
    if not match or not match.group(1):
        raise SystemExit("the capture page wrote nothing:\n" + result.stderr[-2000:])
    return json.loads(html.unescape(match.group(1)))


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def clean(name: str, markup: str) -> str:
    """The captured svg, with no style attribute, ready to draw in."""
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    root = ET.fromstring(markup)
    for el in root.iter():
        style = el.attrib.pop("style", None)
        if style:
            for decl in filter(None, (d.strip() for d in style.split(";"))):
                prop = decl.split(":", 1)[0].strip().lower()
                if not HARMLESS.match(prop):
                    raise SystemExit(f"{name}: a style attribute sets {decl!r}, which shows")
        if el.get("class") == "":
            del el.attrib["class"]
        for attr in GEOMETRY & el.attrib.keys():
            el.set(attr, _NUMBER.sub(_tenth, el.get(attr)))
        tag = el.tag.rsplit("}", 1)[-1]
        classes = set(el.get("class", "").split())
        if tag in STROKED and not classes & UNSTROKED:
            el.set("pathLength", "1")
    if root.find(".//*[@id]") is not None or "href" in markup:
        raise SystemExit(f"{name}: ids or links inside the drawing would clash on a page")
    root.set("aria-hidden", "true")
    root.set("focusable", "false")
    out = ET.tostring(root, encoding="unicode", short_empty_elements=True)
    # Inline in HTML the svg needs no namespace declaration.
    return out.replace(' xmlns="http://www.w3.org/2000/svg"', "", 1)


def main() -> int:
    data = capture(FIGURES)
    missing = [n for n in FIGURES if not data["svg"].get(n)]
    if missing:
        raise SystemExit(f"no drawing came back for {missing}")
    os.makedirs(OUT, exist_ok=True)
    for name in FIGURES:
        with open(os.path.join(OUT, f"{name}.svg"), "w", encoding="utf-8") as fh:
            fh.write(clean(name, data["svg"][name]) + "\n")
        print(f"  wrote _build/hairline/{name}.svg")
    with open(os.path.join(OUT, "hairline.css"), "w", encoding="utf-8") as fh:
        fh.write(data["css"].strip() + "\n")
    shutil.copy(os.path.join(LIBRARY, "LICENSE"), os.path.join(OUT, "LICENSE"))
    print("  wrote _build/hairline/hairline.css and LICENSE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
