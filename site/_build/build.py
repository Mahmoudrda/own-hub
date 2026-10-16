#!/usr/bin/env python3
"""Own Hub public site — static generator.

Run from the site/ folder:

    python3 _build/build.py                                 # in place
    python3 _build/build.py --base-url https://example.com  # for a domain
    python3 _build/build.py --base-url https://example.com --out /tmp/site

It reads config.json, renders every page in English and Arabic, and writes
sitemap.xml, robots.txt and the web manifest. Nothing here runs in a browser:
the output is plain HTML and CSS with no script of any kind.

The domain comes from --base-url, else the BASE_URL environment variable,
else baseUrl in config.json. It fills the canonical and hreflang links, the
sitemap, robots.txt, og:url and og:image. Once it is a real domain, the
privacy and support addresses become privacy@ and support@ that domain,
unless --keep-contact-emails is given.

--out writes a clean, publishable copy of the site to that folder: the pages,
the assets, _headers and _redirects, and nothing from _build or config.json.
Without it the pages are written into site/ itself, as committed.

Every internal link, image and #anchor is checked after the build. A broken
one stops it.

Every fact only the owner can supply lives in config.json. A value left empty
is rendered as a visible rose-outlined "[to be completed: ...]" marker in both
languages rather than as a plausible-looking invention, because a policy
carrying a wrong email address is worse than one that admits a gap.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import shutil
import sys
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = ROOT  # where pages are written; main() moves it for --out

sys.path.insert(0, HERE)

import art  # noqa: E402

PLACEHOLDER_HOST = "ownhub.example"

# The only hosts a download button may point to.
STORE_HOSTS = {"storeUrlIos": "apps.apple.com", "storeUrlAndroid": "play.google.com"}

# Drafting notes for the owner or a lawyer are never published, not even as
# an HTML comment in the page source.
_DRAFTING_NOTE = re.compile(r"[ \t]*<!--\s*\[(?:LAWYER|OWNER)\b.*?-->[ \t]*\n?", re.S)


def strip_drafting_notes(text: str) -> str:
    """Remove every <!-- [LAWYER] ... --> and <!-- [OWNER] ... --> comment."""
    return _DRAFTING_NOTE.sub("", text)

# Page key -> (english path, arabic path)
PATHS = {
    "index": ("/", "/ar/"),
    "privacy": ("/privacy", "/ar/privacy"),
    "terms": ("/terms", "/ar/terms"),
    "support": ("/support", "/ar/support"),
    "delete-account": ("/delete-account", "/ar/delete-account"),
    "waitlist": ("/waitlist", "/ar/waitlist"),
    "waitlist-joined": ("/waitlist/joined", "/ar/waitlist/joined"),
    "waitlist-check": ("/waitlist/check", "/ar/waitlist/check"),
    "waitlist-later": ("/waitlist/later", "/ar/waitlist/later"),
}

# The pages the waitlist form lands on. Reached only by submitting the form,
# so they are kept out of search results and out of the sitemap.
NOINDEX = {"waitlist-joined", "waitlist-check", "waitlist-later"}

# Cloudflare Pages serves privacy.html at /privacy, the address the stores
# hold, with a 200. A privacy/index.html would be served at /privacy/ instead,
# and /privacy would redirect to it: with the /privacy/ -> /privacy alias in
# _redirects that is a loop, which is exactly what a store reviewer would hit.
# The three waitlist answers stay folders because the function redirects to
# them and other tests read them there; Pages adds the trailing slash.
FILES = {
    "index": ("index.html", "ar/index.html"),
    "privacy": ("privacy.html", "ar/privacy.html"),
    "terms": ("terms.html", "ar/terms.html"),
    "support": ("support.html", "ar/support.html"),
    "delete-account": ("delete-account.html", "ar/delete-account.html"),
    "waitlist": ("waitlist.html", "ar/waitlist.html"),
    "waitlist-joined": ("waitlist/joined/index.html", "ar/waitlist/joined/index.html"),
    "waitlist-check": ("waitlist/check/index.html", "ar/waitlist/check/index.html"),
    "waitlist-later": ("waitlist/later/index.html", "ar/waitlist/later/index.html"),
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
            ("/waitlist", "Waitlist"),
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
        "getApp": "Get the app",
        "download": "Download Own Hub",
        "soon": "Coming soon",
        "soonAlt": "{name}, coming soon",
        "appStoreAlt": "Download on the App Store",
        "playAlt": "Get it on Google Play",
        "trademarks": (
            "Apple and the Apple logo are trademarks of Apple Inc., registered "
            "in the U.S. and other countries. App Store is a service mark of "
            "Apple Inc. Google Play and the Google Play logo are trademarks of "
            "Google LLC."
        ),
        "ogLocale": "en_EG",
        "ogImageAlt": "Own Hub. Your training, your food, your month. Women only.",
    },
    "ar": {
        "dir": "rtl",
        "skip": "روحي للمحتوى الأساسي",
        "brandName": "Own Hub",
        "brandHome": "Own Hub، الصفحة الأولى",
        "switch": "English",
        "switchLabel": "غيّري للإنجليزي",
        "footerNav": "صفحات الموقع ده",
        "nav": [
            ("/ar/", "الصفحة الأولى"),
            ("/ar/waitlist", "قايمة الانتظار"),
            ("/ar/privacy", "الخصوصية"),
            ("/ar/terms", "الشروط"),
            ("/ar/support", "الدعم"),
            ("/ar/delete-account", "حذف بياناتك"),
        ],
        "footerNote": (
            "الموقع ده مبيحطش أي كوكيز، ومبيشغّلش أي سكريبت، ومبيحمّلش حاجة "
            "من أي جهة تانية، ومبيحسبش الزيارات. والخط بيتقدّم من الموقع نفسه: "
            "<a href=\"/assets/fonts/OFL-Rubik.txt\">Rubik، بموجب رخصة "
            "الخطوط المفتوحة SIL 1.1</a>."
        ),
        "footerPublisher": "الناشر لـ Own Hub: {entity}، {address}.",
        "todo": "بانتظار الاستكمال",
        "getApp": "نزّلي التطبيق",
        "download": "نزّلي Own Hub",
        "soon": "قريبًا",
        "soonAlt": "{name}، قريبًا",
        "appStoreAlt": "حمّليه من App Store",
        "playAlt": "حمّليه من Google Play",
        "trademarks": (
            "Apple وشعار Apple علامتين تجاريتين لشركة Apple Inc.، مسجّلتين في "
            "الولايات المتحدة وبلاد تانية. وApp Store علامة خدمة لشركة Apple Inc. "
            "وGoogle Play وشعار Google Play علامتين تجاريتين لشركة Google LLC."
        ),
        "ogLocale": "ar_EG",
        "ogImageAlt": "Own Hub. تمرينك، وأكلك، وشهرك. للستات بس.",
    },
}


# ---------------------------------------------------------------- config ----

class Config:
    def __init__(self, path: str, base_url: str | None = None):
        with open(path, encoding="utf-8") as fh:
            self.raw = json.load(fh)
        self.values = self.raw["values"]
        self.base = check_base_url(base_url or self.raw.get("baseUrl") or "")
        self.missing: list[tuple[str, str]] = []
        self.used_fallback: list[str] = []
        self.email_changes: list[tuple[str, str]] = []

    @property
    def base_is_real(self) -> bool:
        return bool(self.base) and PLACEHOLDER_HOST not in self.base

    @property
    def host(self) -> str:
        return urllib.parse.urlparse(self.base).hostname or PLACEHOLDER_HOST

    def use_domain_emails(self) -> None:
        """privacy@ and support@ the site's own domain, in every value.

        The old address is replaced wherever it appears, so a value that
        quotes it in a sentence (the data protection officer) follows."""
        domain = self.host[4:] if self.host.startswith("www.") else self.host
        for key, local in (("contactPrivacy", "privacy"), ("contactSupport", "support")):
            old = self.plain(key, "en")
            new = f"{local}@{domain}"
            if old == new:
                continue
            # Already a mailbox on the site's own domain (info@, hello@):
            # that is the owner's choice of name, not a stray personal address.
            if old.lower().endswith(f"@{domain.lower()}"):
                continue
            self.email_changes.append((old, new))
            self.values[key]["value"] = new
            if not old:
                continue
            for name, entry in self.values.items():
                if name in ("contactPrivacy", "contactSupport"):
                    continue
                value = entry.get("value")
                if isinstance(value, dict):
                    entry["value"] = {k: v.replace(old, new) for k, v in value.items()}
                elif isinstance(value, str):
                    entry["value"] = value.replace(old, new)

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

    def store_url(self, key: str) -> str:
        """An app store link, or '' when it is not set.

        Only an https link to the store's own host is accepted: a typo here
        would put a wrong download button on the home page, so it stops the
        build instead."""
        url = self.plain(key, "en")
        if not url:
            return ""
        host = STORE_HOSTS[key]
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.hostname != host:
            raise SystemExit(f"config.json {key} must be an https://{host}/ link, not {url!r}")
        return html.escape(url)

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

        if kind == "cap":
            # A value that opens a card title: "our website host" becomes
            # "Our website host". A name ("Cloudflare Pages") or Arabic text
            # is left as it is, and so is a [to be completed] marker.
            out = cfg.resolve(key, lang)
            if not out:
                return ""
            return out[0].upper() + out[1:] if out[0].islower() else out

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


# ---------------------------------------------------- Latin in Arabic -----

# A run of Latin text inside an Arabic sentence ("Google Cloud Firestore",
# "com.ownhub.app", an email address) is wrapped in <bdi> so the browser lays
# it out as one left-to-right island instead of reordering its words and the
# punctuation around it. Text nodes only: never inside a tag, an attribute,
# a comment, or an element that is already isolated or is code.
_LATIN_RUN = re.compile(
    r"(?<![&#A-Za-z0-9_])"
    r"[A-Za-z0-9][A-Za-z0-9.@_+\-/]*"
    r"(?:\s+[A-Za-z0-9][A-Za-z0-9.@_+\-/]*)*"
)
_SKIP_ELEMENTS = {"code", "bdi", "script", "style", "title", "pre", "kbd"}
_TAG = re.compile(r"(<!--.*?-->|<[^>]+>)", re.S)


def _isolate_text(text: str) -> str:
    def wrap(match: re.Match) -> str:
        run = match.group(0)
        if not re.search(r"[A-Za-z]", run):
            return run  # digits alone read the same either way
        trail = ""
        while run and run[-1] in ".-/":
            trail = run[-1] + trail
            run = run[:-1]
        return f"<bdi>{run}</bdi>{trail}" if run else match.group(0)

    return _LATIN_RUN.sub(wrap, text)


def isolate_latin(body: str) -> str:
    """Wrap Latin runs in Arabic text nodes in <bdi>. Idempotent."""
    out = []
    skipping: list[str] = []
    for part in _TAG.split(body):
        if not part:
            continue
        if part.startswith("<"):
            out.append(part)
            if part.startswith("<!--"):
                continue
            m = re.match(r"<(/?)([a-zA-Z0-9]+)", part)
            if m:
                closing, name = m.group(1) == "/", m.group(2).lower()
                if name in _SKIP_ELEMENTS:
                    if closing:
                        if skipping and skipping[-1] == name:
                            skipping.pop()
                    elif not part.endswith("/>"):
                        skipping.append(name)
            continue
        out.append(part if skipping else _isolate_text(part))
    return "".join(out)




# ------------------------------------------------------------- base url ---

def check_base_url(url: str) -> str:
    """https://host with no path, or the build stops. '' is allowed."""
    url = (url or "").strip().rstrip("/")
    if not url:
        return ""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.path or parsed.query:
        raise SystemExit(f"the base URL must look like https://example.com, not {url!r}")
    return f"https://{parsed.netloc.lower()}"


# ---------------------------------------------------------------- assets ---

def asset_version(rel: str) -> str:
    """A short content hash, so a changed file gets a new address."""
    with open(os.path.join(ROOT, rel), "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()[:10]


SHOT_WIDTHS = (320, 480, 640)
SHOT_RATIO = 2868 / 1320  # the store screenshots, 6.9 inch iPhone


def shot(lang: str, name: str, alt: str, *, sizes: str, eager: bool = False,
         width: int = 320) -> str:
    """One app screenshot as a responsive WebP <img>."""
    base = f"/assets/shots/{lang}/{name}"
    srcset = ", ".join(f"{base}-{w}.webp {w}w" for w in SHOT_WIDTHS)
    loading = (
        'fetchpriority="high" decoding="async"' if eager
        else 'loading="lazy" decoding="async"'
    )
    return (
        f'<img src="{base}-{width}.webp" srcset="{srcset}" sizes="{sizes}" '
        f'width="{width}" height="{round(width * SHOT_RATIO)}" alt="{html.escape(alt)}" {loading}>'
    )


# Badge artwork, at the height it is drawn. Apple's is an SVG 119.66 x 40;
# Google's PNG is 564 x 168 once its transparent padding is trimmed. Google
# asks that its badge is never smaller than the App Store badge beside it,
# so both are drawn at the same height.
BADGE_H = 48
BADGES = {
    "storeUrlIos": ("app-store-{lang}.svg", round(BADGE_H * 119.66407 / 40), "appStoreAlt"),
    "storeUrlAndroid": ("google-play-{lang}.png", round(BADGE_H * 564 / 168), "playAlt"),
}


def store_badges(cfg: "Config", lang: str, *, where: str) -> str:
    """The App Store and Google Play badges, App Store first.

    A badge with a link set in config.json is that link. Without one it is
    drawn unchanged, as Apple and Google require, beside a 'Coming soon'
    label, and it is not a link at all: role=link with aria-disabled and no
    href, so nothing can follow it and a screen reader says why."""
    c = CHROME[lang]
    items = []
    for key, (file, width, alt_key) in BADGES.items():
        url = cfg.store_url(key)
        src = "/assets/badges/" + file.format(lang=lang)
        name = c[alt_key]
        if url:
            img = (f'<img src="{src}" width="{width}" height="{BADGE_H}" '
                   f'alt="{html.escape(name)}" loading="lazy">')
            items.append(f'<a class="badge" href="{url}" rel="noopener">{img}</a>')
        else:
            label = c["soonAlt"].format(name=name)
            img = (f'<img src="{src}" width="{width}" height="{BADGE_H}" '
                   f'alt="{html.escape(label)}" loading="lazy">')
            items.append(
                f'<a class="badge is-soon" role="link" aria-disabled="true">{img}'
                f'<span class="soon" aria-hidden="true">{c["soon"]}</span></a>'
            )
    live = " store-links" if any(cfg.store_url(k) for k in BADGES) else ""
    return (
        f'<div class="badges badges-{where}{live}" role="group" '
        f'aria-label="{html.escape(c["download"])}">' + "".join(items) + "</div>"
    )


def stores_live(cfg: "Config") -> bool:
    return all(cfg.store_url(k) for k in BADGES)


# ------------------------------------------------------------------ shell ---

def absolute(cfg: "Config", path: str) -> str:
    return (cfg.base or f"https://{PLACEHOLDER_HOST}") + path


def head_links(cfg: "Config", page: str, lang: str) -> str:
    """hreflang and canonical. Absolute once a real domain is configured."""
    if page == "404" or page in NOINDEX:
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


def social_meta(cfg: "Config", page: str, lang: str, title: str, description: str) -> str:
    c = CHROME[lang]
    other = CHROME["ar" if lang == "en" else "en"]
    image = absolute(cfg, f"/assets/og/og-{lang}.png")
    rows = [
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Own Hub">',
        f'<meta property="og:title" content="{html.escape(title)}">',
        f'<meta property="og:description" content="{html.escape(description)}">',
        f'<meta property="og:locale" content="{c["ogLocale"]}">',
        f'<meta property="og:locale:alternate" content="{other["ogLocale"]}">',
    ]
    if page != "404" and page not in NOINDEX:
        path = PATHS[page][0 if lang == "en" else 1]
        rows.append(f'<meta property="og:url" content="{html.escape(absolute(cfg, path))}">')
    rows += [
        f'<meta property="og:image" content="{image}">',
        '<meta property="og:image:type" content="image/png">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        f'<meta property="og:image:alt" content="{html.escape(c["ogImageAlt"])}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{html.escape(title)}">',
        f'<meta name="twitter:description" content="{html.escape(description)}">',
        f'<meta name="twitter:image" content="{image}">',
        f'<meta name="twitter:image:alt" content="{html.escape(c["ogImageAlt"])}">',
    ]
    return "".join(f"  {r}\n" for r in rows)


def font_preloads(lang: str) -> str:
    """The files the first screen is set in, so text does not reflow when
    they arrive: body and headings, and on an Arabic page the Latin bold of
    the brand name in the header."""
    files = [("latin", 400), ("latin", 600)] if lang == "en" else [
        ("arabic", 400), ("arabic", 600), ("latin", 600)]
    return "".join(
        f'  <link rel="preload" href="/assets/fonts/rubik-{script}-{w}.woff2" '
        'as="font" type="font/woff2" crossorigin>\n'
        for script, w in files
    )


def shell(cfg: "Config", *, page: str, lang: str, title: str, description: str,
          body: str) -> str:
    c = CHROME[lang]
    other = "ar" if lang == "en" else "en"
    if page == "404":
        other_href = "/ar/" if lang == "en" else "/"
    else:
        other_href = PATHS[page][1 if lang == "en" else 0]
    home = c["nav"][0][0]

    nav_items = "\n".join(
        f'          <li><a href="{href}">{label}</a></li>'
        for href, label in c["nav"]
    )

    entity = cfg.resolve("legalEntity", lang) or ""
    address = cfg.resolve("legalAddress", lang) or ""
    publisher = c["footerPublisher"].format(entity=entity, address=address)
    css = f"/assets/site.css?v={asset_version('assets/site.css')}"
    trademarks = isolate_latin(c["trademarks"]) if lang == "ar" else c["trademarks"]
    # Apple allows one App Store badge per layout. The home page carries it
    # at the top, so its footer does not repeat it; every other page has it
    # here, once.
    foot_badges = "" if page == "index" else store_badges(cfg, lang, where="foot")
    get_app = "" if page == "index" else (
        f'\n      <a class="head-cta" href="{home}#download">{c["getApp"]}</a>'
    )

    return f"""<!DOCTYPE html>
<html lang="{lang}" dir="{c['dir']}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <meta name="description" content="{html.escape(description)}">
  <meta name="color-scheme" content="light">
  <meta name="theme-color" content="#FCF8F2">
{font_preloads(lang)}  <link rel="stylesheet" href="{css}">
  <link rel="icon" href="/favicon.ico" sizes="48x48">
  <link rel="icon" href="/assets/favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/assets/icons/apple-touch-icon.png">
  <link rel="manifest" href="/manifest.webmanifest">
{head_links(cfg, page, lang)}{social_meta(cfg, page, lang, title, description)}</head>
<body>
  <a class="skip" href="#main">{c['skip']}</a>

  <header class="site-head">
    <div class="wrap">
      <a class="brand" href="{home}" aria-label="{c['brandHome']}">
        <img class="mark" src="/assets/favicon.svg" width="36" height="36" alt="">
        <span class="name">{c['brandName']}</span>
      </a>{get_app}
      <a class="lang-switch" href="{other_href}" lang="{other}"
         hreflang="{other}" aria-label="{c['switchLabel']}">{c['switch']}</a>
    </div>
  </header>

  <main id="main" tabindex="-1">
{body}
  </main>

  <footer class="site-foot">
    <div class="wrap">
      <div class="foot-top">
        <a class="brand" href="{home}" aria-label="{c['brandHome']}">
          <img class="mark" src="/assets/favicon.svg" width="32" height="32" alt="">
          <span class="name">{c['brandName']}</span>
        </a>
        {foot_badges}
      </div>
      <nav aria-label="{c['footerNav']}">
        <ul>
{nav_items}
          <li><a href="{other_href}" lang="{other}" hreflang="{other}">{c['switch']}</a></li>
        </ul>
      </nav>
      <p>{publisher}</p>
      <p>{c['footerNote']}</p>
      <p class="tm">{trademarks}</p>
    </div>
  </footer>
</body>
</html>
"""


# ------------------------------------------------------------------ write ---

def write(path: str, text: str) -> None:
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full) or ".", exist_ok=True)
    with open(full, "w", encoding="utf-8") as fh:
        fh.write(text)


def build_sitemap(cfg: Config) -> None:
    base = cfg.base or f"https://{PLACEHOLDER_HOST}"
    lastmod = cfg.plain("lastUpdated", "en") or cfg.plain("effectiveDate", "en")
    iso = to_iso(lastmod)
    rows = []
    for page, (en_path, ar_path) in PATHS.items():
        if page in NOINDEX:
            continue
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
            "<!-- The domain is still the reserved placeholder host\n"
            f"     {PLACEHOLDER_HOST}, which cannot resolve. Build with\n"
            "     --base-url https://your-domain before submitting this file. -->\n"
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
            f"# The domain is still the placeholder host {PLACEHOLDER_HOST}.\n"
            "# Build with --base-url https://your-domain before publishing.\n"
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


def build_manifest() -> None:
    manifest = {
        "name": "Own Hub",
        "short_name": "Own Hub",
        "description": "A free fitness app for women in Egypt, and only for women.",
        "lang": "en",
        "dir": "auto",
        "start_url": "/",
        "scope": "/",
        "display": "browser",
        "background_color": "#FCF8F2",
        "theme_color": "#FCF8F2",
        "icons": [
            {"src": "/assets/icons/icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "/assets/icons/icon-512.png", "sizes": "512x512", "type": "image/png"},
            {"src": "/assets/icons/icon-maskable-512.png", "sizes": "512x512",
             "type": "image/png", "purpose": "maskable"},
            {"src": "/assets/favicon.svg", "sizes": "any", "type": "image/svg+xml"},
        ],
    }
    write("manifest.webmanifest", json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


def build_art() -> None:
    """The small SVG files: icon, mark, hand underline."""
    write("assets/favicon.svg", art.icon_svg(size=64))
    write("assets/brand/mark.svg", art.mark_svg())
    write("assets/hand/underline.svg", art.underline_svg())


# The files, besides the pages, that a host serves. Everything else in
# site/ (the generator, config.json) stays out of a publishable copy.
STATIC = ("assets", "_headers", "_redirects")


def copy_static() -> None:
    for name in STATIC:
        src, dst = os.path.join(ROOT, name), os.path.join(OUT, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dst)


def copy_favicon() -> None:
    shutil.copyfile(os.path.join(ROOT, "assets", "icons", "favicon.ico"),
                    os.path.join(OUT, "favicon.ico"))


def remove_stale_pages(written: set[str]) -> list[str]:
    """Delete any page this build did not write (an old address)."""
    removed = []
    for base, dirs, files in os.walk(OUT):
        rel_base = os.path.relpath(base, OUT)
        dirs[:] = [d for d in dirs if not (rel_base == "." and d in ("_build", "assets"))]
        for name in files:
            rel = os.path.normpath(os.path.join(rel_base, name)).replace(os.sep, "/")
            if name.endswith(".html") and rel not in written:
                os.remove(os.path.join(base, name))
                removed.append(rel)
    for base, dirs, files in sorted(os.walk(OUT), key=lambda w: -len(w[0])):
        if base != OUT and not os.listdir(base) and "_build" not in base:
            os.rmdir(base)
    return removed


# ------------------------------------------------------------- link check ---

_ATTR = re.compile(r'\s(href|src|srcset)="([^"]*)"')
_ID = re.compile(r'\sid="([^"]+)"')


def redirect_sources(root: str) -> set[str]:
    path = os.path.join(root, "_redirects")
    if not os.path.exists(path):
        return set()
    out = set()
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line.split()[0])
    return out


def resolve_path(root: str, path: str) -> str | None:
    """The file Cloudflare Pages would serve for a path, or None."""
    rel = urllib.parse.unquote(path).lstrip("/")
    candidates = []
    if not rel or rel.endswith("/"):
        candidates.append(rel + "index.html")
    else:
        candidates += [rel, rel + ".html", rel + "/index.html"]
    for cand in candidates:
        full = os.path.join(root, cand)
        if os.path.isfile(full):
            return full
    return None


def check_links(root: str) -> list[str]:
    """Every internal href, src, srcset and #anchor in every page resolves."""
    problems = []
    aliases = redirect_sources(root)
    ids_cache: dict[str, set[str]] = {}

    def ids(full: str) -> set[str]:
        if full not in ids_cache:
            ids_cache[full] = set(_ID.findall(open(full, encoding="utf-8").read()))
        return ids_cache[full]

    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in ("_build", "__pycache__")]
        for name in files:
            if not name.endswith(".html"):
                continue
            page = os.path.join(base, name)
            rel_page = os.path.relpath(page, root)
            text = open(page, encoding="utf-8").read()
            for attr, value in _ATTR.findall(text):
                urls = [v.strip().split(" ")[0] for v in value.split(",")] if attr == "srcset" else [value]
                for url in urls:
                    url = html.unescape(url)
                    if not url or re.match(r"^[a-z][a-z0-9+.-]*:", url, re.I):
                        continue  # mailto:, https:, tel:
                    if url.startswith("//"):
                        problems.append(f"{rel_page}: protocol-relative {url}")
                        continue
                    path, _, frag = url.partition("#")
                    path = path.split("?")[0]
                    if not path:
                        target = page
                    elif not path.startswith("/"):
                        problems.append(f"{rel_page}: relative link {url}")
                        continue
                    else:
                        target = resolve_path(root, path)
                        if target is None:
                            if path in aliases:
                                continue
                            problems.append(f"{rel_page}: {url} does not exist")
                            continue
                    if frag and target.endswith(".html") and frag not in ids(target):
                        problems.append(f"{rel_page}: {url} has no #{frag}")
    return problems


# ------------------------------------------------------------------- main ---

def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Own Hub website.")
    parser.add_argument("--base-url", default=os.environ.get("BASE_URL") or None,
                        help="https://your-domain (default: $BASE_URL, then baseUrl in config.json)")
    parser.add_argument("--out", default=None,
                        help="write a clean publishable copy here instead of into site/")
    parser.add_argument("--keep-contact-emails", action="store_true",
                        help="keep the email addresses in config.json on a real domain")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    global OUT
    args = parse_args(sys.argv[1:] if argv is None else argv)
    cfg = Config(os.path.join(ROOT, "config.json"), args.base_url)

    if args.out:
        OUT = os.path.abspath(args.out)
        if OUT == ROOT or OUT.startswith(ROOT + os.sep):
            raise SystemExit("--out must be a folder outside site/")
        if os.path.exists(OUT):
            shutil.rmtree(OUT)
        os.makedirs(OUT)

    if cfg.base_is_real and not args.keep_contact_emails:
        cfg.use_domain_emails()

    import pages_ar
    import pages_en

    modules = {"en": pages_en, "ar": pages_ar}
    build_art()
    written: set[str] = set()

    for lang, module in modules.items():
        pages = module.build(cfg, lang, mailto_link, store_badges, shot)
        for key, page in pages.items():
            body = strip_drafting_notes(render_tokens(page["body"], cfg, lang))
            if lang == "ar":
                body = isolate_latin(body)
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
            written.add(path)
            print("  wrote", path)

    build_sitemap(cfg)
    build_robots(cfg)
    build_manifest()
    if OUT != ROOT:
        copy_static()
    copy_favicon()
    print("  wrote sitemap.xml, robots.txt, manifest.webmanifest, favicon.ico")
    for rel in remove_stale_pages(written):
        print("  removed old page", rel)

    problems = check_links(OUT)
    if problems:
        for line in problems:
            print("  BROKEN", line, file=sys.stderr)
        raise SystemExit(f"{len(problems)} broken internal link(s)")
    print("  link check: every internal link, image and anchor resolves")

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

    if cfg.email_changes:
        print()
        print("Contact addresses now on the pages (they must reach a monitored inbox):")
        for old, new in cfg.email_changes:
            print(f"  - {new}" + (f"   (was {old})" if old else ""))

    print()
    if cfg.base_is_real:
        print(f"Built for {cfg.base}.")
    else:
        print(f"The domain is still the placeholder host {PLACEHOLDER_HOST}.")
        print("sitemap.xml and the share tags carry it; canonical and hreflang")
        print("stay relative until a real domain is given with --base-url.")
    if OUT != ROOT:
        print(f"Publishable copy: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
