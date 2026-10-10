#!/usr/bin/env python3
"""Make the binary assets the site serves. Run by hand, not on every build.

    python3 _build/make_assets.py            (from the site/ folder)

Needs: fontTools and brotli (font subsets), Pillow (badge crop, icon .ico),
cwebp (screenshots) and Google Chrome (renders the share image and the PNG
icons from the same SVG the site uses). build.py needs none of these: it only
reads what this script leaves in assets/, and the results are committed.

What it writes, all under assets/:

  fonts/rubik-{latin,arabic}-{400,600}.woff2
      Rubik from app/assets/fonts, cut into a Latin and an Arabic file per
      weight. The CSS gives each a unicode-range, so an English page never
      downloads the Arabic glyphs.

  shots/{en,ar}/<name>-{320,480,640}.webp
      The store screenshots in docs/release/launch-pack/screenshots/apple-6.9.

  badges/
      The store badges, as published by Apple and Google:
        App Store: the black "Download on the App Store" badge, English and
          Arabic, from Apple's marketing toolbox, linked from
          https://developer.apple.com/app-store/marketing/guidelines/
          Rules followed: black badge, App Store badge first, never modified,
          at least 40 px tall on screen, clear space a quarter of its height,
          and the Apple credit line in the footer.
        Google Play: the "Get it on Google Play" badge, English and Arabic, from
          https://play.google.com/intl/en_us/badges/ (rules on the Partner
          Marketing Hub, Google Play > Lockups, icons and badges). Rules
          followed: never smaller than the App Store badge beside it, at
          least 28 px tall, the localized badge on the Arabic page, the Google
          credit line in the footer. The PNG comes with transparent padding;
          only that padding is trimmed, the badge pixels are untouched.

  og/og-{en,ar}.png        1200 x 630 share image, one per language.
  icons/                   favicon.ico, icon-192.png, icon-512.png,
                           icon-maskable-512.png, apple-touch-icon.png
"""

from __future__ import annotations

import io
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.dirname(HERE)
REPO = os.path.dirname(SITE)
ASSETS = os.path.join(SITE, "assets")
sys.path.insert(0, HERE)

import art  # noqa: E402

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SHOTS = os.environ.get(
    "OWNHUB_SHOTS",
    os.path.join(os.path.expanduser("~"), "ownhub/docs/release/launch-pack/screenshots/apple-6.9"),
)
SHOT_NAMES = ["02-home", "03-workout", "07-tour-dinners", "06-progress", "08-tour-cycle"]
SHOT_WIDTHS = [320, 480, 640]

LATIN = (
    "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,"
    "U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD"
)
ARABIC = "U+0600-06FF,U+0750-077F,U+200C-200F,U+2010-2011,U+204F,U+FB50-FDFF,U+FE70-FEFF"

BADGES = {
    "app-store-en.svg": "https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us",
    "app-store-ar.svg": "https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/ar-ar",
    "google-play-en.png": "https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png",
    "google-play-ar.png": "https://play.google.com/intl/en_us/badges/static/images/badges/ar_badge_web_generic.png",
}


def out(*parts: str) -> str:
    path = os.path.join(ASSETS, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def fonts() -> None:
    from fontTools import subset

    for weight in (400, 500, 600):
        src = os.path.join(REPO, "app", "assets", "fonts", f"Rubik-{weight}.ttf")
        for name, ranges in (("latin", LATIN), ("arabic", ARABIC)):
            subset.main([
                src,
                f"--unicodes={ranges}",
                "--flavor=woff2",
                "--layout-features=*",
                "--no-hinting",
                "--desubroutinize",
                f"--output-file={out('fonts', f'rubik-{name}-{weight}.woff2')}",
            ])
    shutil.copy(os.path.join(REPO, "app", "assets", "fonts", "OFL-Rubik.txt"), out("fonts", "OFL-Rubik.txt"))


def shots() -> None:
    for lang in ("en", "ar"):
        for name in SHOT_NAMES:
            src = os.path.join(SHOTS, lang, f"{name}.png")
            for width in SHOT_WIDTHS:
                subprocess.run(
                    ["cwebp", "-quiet", "-q", "78", "-m", "6", "-resize", str(width), "0",
                     src, "-o", out("shots", lang, f"{name}-{width}.webp")],
                    check=True,
                )


def badges() -> None:
    from PIL import Image

    for name, url in BADGES.items():
        data = urllib.request.urlopen(url, timeout=30).read()
        if name.endswith(".png"):
            im = Image.open(io.BytesIO(data)).convert("RGBA")
            im = im.crop(im.getchannel("A").getbbox())
            im.save(out("badges", name), optimize=True)
        else:
            with open(out("badges", name), "wb") as fh:
                fh.write(data)


def chrome_png(html: str, width: int, height: int, dest: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, "p.html")
        with open(page, "w", encoding="utf-8") as fh:
            fh.write(html)
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             "--default-background-color=00000000",
             "--force-device-scale-factor=1", f"--window-size={width},{height}",
             f"--screenshot={dest}", "file://" + page],
            check=True, capture_output=True,
        )


def share_images() -> None:
    fonts_dir = os.path.join(ASSETS, "fonts")
    face = "".join(
        f'@font-face{{font-family:R;src:url("file://{fonts_dir}/rubik-{s}-{w}.woff2");'
        f"font-weight:{w};unicode-range:{r}}}"
        for w in (400, 600)
        for s, r in (("latin", LATIN), ("arabic", ARABIC))
    )
    copy = {
        "en": ("Your training, your food, your cycle.", "Women only.",
               "A free fitness app for women in Egypt"),
        "ar": ("تدريبكِ، وطعامكِ، ودورتكِ.", "للنساء فقط.",
               "تطبيق لياقة مجاني للنساء في مصر"),
    }
    mark = art.icon_svg(size=88)
    underline = art.underline_svg().replace("\n", "")
    import base64
    under_uri = "data:image/svg+xml;base64," + base64.b64encode(underline.encode()).decode()
    for lang, (one, two, sub) in copy.items():
        rtl = lang == "ar"
        html = f"""<!doctype html><html lang="{lang}" dir="{'rtl' if rtl else 'ltr'}"><meta charset="utf-8">
<style>{face}
html,body{{margin:0;width:1200px;height:630px;overflow:hidden;background:#FFF8F9;font-family:R,sans-serif;color:#241A1E}}
.b{{position:absolute;inset:0;padding:70px 84px;box-sizing:border-box}}
.top{{display:flex;align-items:center;gap:22px;font-weight:600;font-size:40px;color:#A24661}}
h1{{margin:64px 0 0;font-weight:600;font-size:{62 if rtl else 64}px;line-height:{1.35 if rtl else 1.12};letter-spacing:{0 if rtl else -1}px;max-width:720px}}
h1 span{{display:inline-block;padding-bottom:14px;background:url("{under_uri}") no-repeat bottom/100% 18px}}
p{{margin:28px 0 0;font-size:30px;color:#6B5C61}}
.k{{position:absolute;bottom:-14px;{'left' if rtl else 'right'}:70px;width:380px;height:auto}}
.blob{{position:absolute;bottom:-160px;{'left' if rtl else 'right'}:-30px;width:540px;height:540px;border-radius:50%;background:#DDEDE1}}
</style><div class="blob"></div>
{art.kitten_svg(css_class="k") if not rtl else art.kitten_svg(css_class="k").replace('<svg ', '<svg style="transform:scaleX(-1)" ')}
<div class="b"><div class="top">{mark}<span dir="ltr">Own Hub</span></div>
<h1>{one}<br><span>{two}</span></h1><p>{sub}</p></div></html>"""
        chrome_png(html, 1200, 630, out("og", f"og-{lang}.png"))


def icons() -> None:
    from PIL import Image

    def render(svg: str, size: int, dest: str) -> None:
        html = (
            "<!doctype html><style>html,body{margin:0;background:transparent}"
            f"svg{{display:block;width:{size}px;height:{size}px}}</style>{svg}"
        )
        chrome_png(html, size, size, dest)

    render(art.icon_svg(size=192), 192, out("icons", "icon-192.png"))
    render(art.icon_svg(size=512), 512, out("icons", "icon-512.png"))
    render(art.icon_svg(size=512, full_bleed=True, safe=0.8), 512, out("icons", "icon-maskable-512.png"))
    render(art.icon_svg(size=180, full_bleed=True), 180, out("icons", "apple-touch-icon.png"))
    render(art.icon_svg(size=256), 256, os.path.join(tempfile.gettempdir(), "ownhub-ico.png"))
    ico = Image.open(os.path.join(tempfile.gettempdir(), "ownhub-ico.png")).convert("RGBA")
    ico.save(out("icons", "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
    for name in ("icon-192.png", "icon-512.png", "icon-maskable-512.png", "apple-touch-icon.png"):
        path = out("icons", name)
        Image.open(path).convert("RGBA").save(path, optimize=True)


def main(argv: list[str]) -> int:
    steps = {"fonts": fonts, "shots": shots, "badges": badges,
             "share": share_images, "icons": icons}
    chosen = argv or list(steps)
    for name in chosen:
        print("  making", name)
        steps[name]()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
