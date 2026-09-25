#!/usr/bin/env python3
"""Own Hub public site — static generator.

Run from the site/ folder:

    python3 _build/build.py

It reads config.json, renders every page in English and Arabic, and writes
sitemap.xml. Nothing here runs in a browser: the output is plain HTML and CSS
with no script of any kind.

Every fact only the owner can supply lives in config.json. A value left empty
is rendered as a visible rose-outlined "[to be completed: ...]" marker in both
languages rather than as a plausible-looking invention, because a policy
carrying a wrong email address is worse than one that admits a gap.
"""

from __future__ import annotations

import html
import json
import os
import re
import sys
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

sys.path.insert(0, HERE)

PLACEHOLDER_HOST = "ownhub.example"

# Page key -> (english path, arabic path)
PATHS = {
    "index": ("/", "/ar/"),
    "privacy": ("/privacy", "/ar/privacy"),
    "terms": ("/terms", "/ar/terms"),
    "support": ("/support", "/ar/support"),
    "delete-account": ("/delete-account", "/ar/delete-account"),
}

FILES = {
    "index": ("index.html", "ar/index.html"),
    "privacy": ("privacy/index.html", "ar/privacy/index.html"),
    "terms": ("terms/index.html", "ar/terms/index.html"),
    "support": ("support/index.html", "ar/support/index.html"),
    "delete-account": ("delete-account/index.html", "ar/delete-account/index.html"),
}

CHROME = {
    "en": {
        "dir": "ltr",
        "skip": "Skip to the main content",
        "brandName": "Own Hub",
        "brandHome": "Own Hub, home",
        "switch": "العربية",
        "switchLabel": "Switch to Arabic",
        "footerNav": "Pages on this site",
        "nav": [
            ("/", "Home"),
            ("/privacy", "Privacy"),
            ("/terms", "Terms"),
            ("/support", "Support"),
            ("/delete-account", "Delete your data"),
        ],
        "footerNote": (
            "This website sets no cookie, runs no script, loads nothing from "
            "anyone else, and counts no visit. The typeface is served from this "
            "site: <a href=\"/assets/fonts/OFL-Rubik.txt\">Rubik, under the SIL "
            "Open Font Licence 1.1</a>."
        ),
        "footerPublisher": "Own Hub is published by {entity}, {address}.",
        "todo": "to be completed",
    },
    "ar": {
        "dir": "rtl",
        "skip": "انتقلي إلى المحتوى الأساسي",
        "brandName": "Own Hub",
        "brandHome": "Own Hub، الصفحة الأولى",
        "switch": "English",
        "switchLabel": "التبديل إلى الإنجليزية",
        "footerNav": "صفحات هذا الموقع",
        "nav": [
            ("/ar/", "الصفحة الأولى"),
            ("/ar/privacy", "الخصوصية"),
            ("/ar/terms", "الشروط"),
            ("/ar/support", "الدعم"),
            ("/ar/delete-account", "حذف بياناتك"),
        ],
        "footerNote": (
            "هذا الموقع لا يضع أي ملفّ تعريف ارتباط، ولا يشغّل أي سكريبت، ولا "
            "يحمّل شيئًا من أي جهة أخرى، ولا يحصي زيارة. والخط يُقدَّم من هذا "
            "الموقع نفسه: <a href=\"/assets/fonts/OFL-Rubik.txt\">Rubik، بموجب "
            "رخصة الخطوط المفتوحة SIL 1.1</a>."
        ),
        "footerPublisher": "ناشر Own Hub: {entity}، {address}.",
        "todo": "بانتظار الاستكمال",
    },
}


# ---------------------------------------------------------------- config ----

class Config:
    def __init__(self, path: str):
        with open(path, encoding="utf-8") as fh:
            self.raw = json.load(fh)
        self.values = self.raw["values"]
        self.base = (self.raw.get("baseUrl") or "").rstrip("/")
        self.missing: list[tuple[str, str]] = []
        self.used_fallback: list[str] = []

    @property
    def base_is_real(self) -> bool:
        return bool(self.base) and PLACEHOLDER_HOST not in self.base

    def entry(self, key: str) -> dict:
        try:
            return self.values[key]
        except KeyError:  # pragma: no cover - a typo in a template
            raise SystemExit(f"config.json has no value named {key!r}")

    def plain(self, key: str, lang: str) -> str:
        """The raw string for a key, or '' when it is not set."""
        if key == "effectiveDate" and lang == "ar":
            ar = self.values["effectiveDateAr"]["value"]
            if ar:
                return ar
        if key == "lastUpdated" and lang == "ar":
            ar = self.values["lastUpdatedAr"]["value"]
            if ar:
                return ar
        raw = self.entry(key)["value"]
        if isinstance(raw, dict):
            return (raw.get(lang) or "").strip()
        return (raw or "").strip()

    def resolve(self, key: str, lang: str) -> str | None:
        """The HTML for a key: the value, a fallback, a marker, or None.

        None means an optional value that is not set, and the caller leaves the
        row out entirely rather than drawing an empty one.
        """
        value = self.plain(key, lang)
        if value:
            return html.escape(value)

        entry = self.entry(key)
        fallback = entry.get("fallback")
        if fallback:
            text = (fallback.get(lang) or "").strip()
            if text:
                if key not in self.used_fallback:
                    self.used_fallback.append(key)
                return html.escape(text)

        if entry.get("optional"):
            return None

        if (key, lang) not in self.missing:
            self.missing.append((key, lang))
        label = entry["label"].get(lang) or entry["label"]["en"]
        word = CHROME[lang]["todo"]
        return (
            f'<span class="todo" role="note">[{html.escape(word)}: '
            f"{html.escape(label)}]</span>"
        )


# ------------------------------------------------------------ templating ----

TOKEN = re.compile(r"\{\{([a-zA-Z0-9_:.\-]+)\}\}")


def render_tokens(text: str, cfg: Config, lang: str) -> str:
    def one(match: re.Match) -> str:
        token = match.group(1)
        if ":" in token:
            kind, key = token.split(":", 1)
        else:
            kind, key = "value", token

        if kind == "value":
            out = cfg.resolve(key, lang)
            return "" if out is None else out

        if kind == "mailto":
            addr = cfg.plain(key, lang)
            if not addr:
                out = cfg.resolve(key, lang)
                return "" if out is None else out
            esc = html.escape(addr)
            return f'<a href="mailto:{esc}">{esc}</a>'

        if kind == "mailtoplain":
            addr = cfg.plain(key, lang)
            if not addr:
                out = cfg.resolve(key, lang)
                return "" if out is None else out
            return html.escape(addr)

        raise SystemExit(f"unknown token kind {kind!r} in {{{{{token}}}}}")

    return TOKEN.sub(one, text)


def mailto_link(cfg: Config, lang: str, key: str, subject: str, body: str,
                classes: str, label: str) -> str:
    """A pre-filled mailto: link, or a marker when the address is not set."""
    addr = cfg.plain(key, lang)
    if not addr:
        out = cfg.resolve(key, lang)
        return out or ""
    query = urllib.parse.urlencode(
        {"subject": subject, "body": body}, quote_via=urllib.parse.quote
    )
    # The address itself is left readable: some mail clients mishandle a
    # percent-encoded "@" in the mailto path.
    href = "mailto:" + urllib.parse.quote(addr, safe="@.+-_") + "?" + query
    return f'<a class="{classes}" href="{html.escape(href)}">{label}</a>'


# ------------------------------------------------------------------ shell ---

def head_links(cfg: Config, page: str, lang: str) -> str:
    """hreflang and canonical. Absolute once a real domain is configured."""
    if page == "404":
        return '  <meta name="robots" content="noindex, follow">\n'

    en_path, ar_path = PATHS[page]
    self_path = en_path if lang == "en" else ar_path

    def url(path: str) -> str:
        return cfg.base + path if cfg.base_is_real else path

    return (
        f'  <link rel="canonical" href="{html.escape(url(self_path))}">\n'
        f'  <link rel="alternate" hreflang="en" href="{html.escape(url(en_path))}">\n'
        f'  <link rel="alternate" hreflang="ar" href="{html.escape(url(ar_path))}">\n'
        f'  <link rel="alternate" hreflang="x-default" href="{html.escape(url(en_path))}">\n'
    )


def shell(cfg: Config, *, page: str, lang: str, title: str, description: str,
          body: str) -> str:
    c = CHROME[lang]
    other = "ar" if lang == "en" else "en"
    if page == "404":
        other_href = "/ar/" if lang == "en" else "/"
    else:
        other_href = PATHS[page][1 if lang == "en" else 0]

    nav_items = "\n".join(
        f'        <li><a href="{href}">{label}</a></li>'
        for href, label in c["nav"]
    )

    entity = cfg.resolve("legalEntity", lang) or ""
    address = cfg.resolve("legalAddress", lang) or ""
    publisher = c["footerPublisher"].format(entity=entity, address=address)

    return f"""<!DOCTYPE html>
<html lang="{lang}" dir="{c['dir']}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <meta name="description" content="{html.escape(description)}">
  <meta name="color-scheme" content="light dark">
  <meta name="theme-color" content="#FFF8F9" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#1A1316" media="(prefers-color-scheme: dark)">
  <link rel="stylesheet" href="/assets/site.css">
  <link rel="icon" href="/assets/favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/assets/favicon.svg">
{head_links(cfg, page, lang)}</head>
<body>
  <a class="skip" href="#main">{c['skip']}</a>

  <header class="site-head">
    <div class="wrap">
      <a class="brand" href="{c['nav'][0][0]}" aria-label="{c['brandHome']}">
        <span class="mark" aria-hidden="true">OH</span>
        <span class="name">{c['brandName']}</span>
      </a>
      <a class="lang-switch" href="{other_href}" lang="{other}"
         hreflang="{other}" aria-label="{c['switchLabel']}">{c['switch']}</a>
    </div>
  </header>

  <main id="main" tabindex="-1">
{body}
  </main>

  <footer class="site-foot">
    <div class="wrap">
      <nav aria-label="{c['footerNav']}">
        <ul>
{nav_items}
          <li><a href="{other_href}" lang="{other}" hreflang="{other}">{c['switch']}</a></li>
        </ul>
      </nav>
      <p>{publisher}</p>
      <p>{c['footerNote']}</p>
    </div>
  </footer>
</body>
</html>
"""


# ------------------------------------------------------------------ write ---

def write(path: str, text: str) -> None:
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full) or ".", exist_ok=True)
    with open(full, "w", encoding="utf-8") as fh:
        fh.write(text)


def build_sitemap(cfg: Config) -> None:
    base = cfg.base or f"https://{PLACEHOLDER_HOST}"
    lastmod = cfg.plain("lastUpdated", "en") or cfg.plain("effectiveDate", "en")
    iso = to_iso(lastmod)
    rows = []
    for page, (en_path, ar_path) in PATHS.items():
        for path, lang, alt, alt_lang in (
            (en_path, "en", ar_path, "ar"),
            (ar_path, "ar", en_path, "en"),
        ):
            rows.append(
                "  <url>\n"
                f"    <loc>{base}{path}</loc>\n"
                + (f"    <lastmod>{iso}</lastmod>\n" if iso else "")
                + f'    <xhtml:link rel="alternate" hreflang="{lang}" href="{base}{path}"/>\n'
                f'    <xhtml:link rel="alternate" hreflang="{alt_lang}" href="{base}{alt}"/>\n'
                f'    <xhtml:link rel="alternate" hreflang="x-default" href="{base}{en_path}"/>\n'
                "  </url>"
            )
    note = ""
    if not cfg.base_is_real:
        note = (
            "<!-- baseUrl in config.json is still the reserved placeholder host\n"
            f"     {PLACEHOLDER_HOST}, which cannot resolve. Set the real domain and\n"
            "     run  python3 _build/build.py  again before submitting this file. -->\n"
        )
    write(
        "sitemap.xml",
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        + note
        + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n'
        '        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
        + "\n".join(rows)
        + "\n</urlset>\n",
    )


MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11,
    "december": 12,
}


def to_iso(text: str) -> str:
    m = re.match(r"\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\s*$", text or "")
    if not m:
        return ""
    month = MONTHS.get(m.group(2).lower())
    if not month:
        return ""
    return f"{m.group(3)}-{month:02d}-{int(m.group(1)):02d}"


def build_robots(cfg: Config) -> None:
    base = cfg.base or f"https://{PLACEHOLDER_HOST}"
    note = ""
    if not cfg.base_is_real:
        note = (
            f"# baseUrl in config.json is still the placeholder host {PLACEHOLDER_HOST}.\n"
            "# Set the real domain and run  python3 _build/build.py  again.\n"
        )
    write(
        "robots.txt",
        "# Own Hub. Everything here is meant to be read, by anyone, with no\n"
        "# login, no geo-block and no cookie wall.\n"
        + note
        + "User-agent: *\n"
        "Allow: /\n"
        "Disallow: /_build/\n"
        "\n"
        f"Sitemap: {base}/sitemap.xml\n",
    )


def build_favicon() -> None:
    write(
        "assets/favicon.svg",
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" '
        'role="img" aria-label="Own Hub">\n'
        '  <rect width="64" height="64" rx="16" fill="#B4526E"/>\n'
        '  <path d="M32 47.5c-.9 0-1.7-.3-2.4-.9C24.9 42.5 17 35.8 17 28.6'
        'c0-4.8 3.6-8.6 8.2-8.6 2.7 0 5.2 1.3 6.8 3.4 1.6-2.1 4.1-3.4 6.8-3.4'
        ' 4.6 0 8.2 3.8 8.2 8.6 0 7.2-7.9 13.9-12.6 18-.7.6-1.5.9-2.4.9z" '
        'fill="#FFF8F9"/>\n'
        "</svg>\n",
    )


# ------------------------------------------------------------------- main ---

def main() -> int:
    cfg = Config(os.path.join(ROOT, "config.json"))

    import pages_ar
    import pages_en

    modules = {"en": pages_en, "ar": pages_ar}

    for lang, module in modules.items():
        pages = module.build(cfg, lang, mailto_link)
        for key, page in pages.items():
            body = render_tokens(page["body"], cfg, lang)
            out = shell(
                cfg,
                page=key,
                lang=lang,
                title=page["title"],
                description=page["description"],
                body=body,
            )
            if key == "404":
                path = "404.html" if lang == "en" else "ar/404.html"
            else:
                path = FILES[key][0 if lang == "en" else 1]
            write(path, out)
            print("  wrote", path)

    build_favicon()
    build_sitemap(cfg)
    build_robots(cfg)
    print("  wrote assets/favicon.svg")
    print("  wrote sitemap.xml")
    print("  wrote robots.txt")

    # ---- report ----
    print()
    if cfg.used_fallback:
        print("Answered from the fallback in config.json (no marker drawn):")
        for key in sorted(cfg.used_fallback):
            print("  -", key)
        print()

    if cfg.missing:
        keys = sorted({k for k, _ in cfg.missing})
        print(f"{len(keys)} config value(s) still empty. Each is drawn on the")
        print("page as a visible [to be completed: ...] marker:")
        for key in keys:
            note = cfg.entry(key).get("note", "")
            print(f"  - {key}: {note}")
    else:
        print("Every config value is filled. No [to be completed] marker was drawn.")

    if not cfg.base_is_real:
        print()
        print(f"baseUrl is still the placeholder host {PLACEHOLDER_HOST}.")
        print("sitemap.xml carries it; canonical and hreflang stay relative")
        print("until a real domain is set.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
