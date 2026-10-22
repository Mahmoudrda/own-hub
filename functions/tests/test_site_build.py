"""W1: the public site is generated, the generator is reproducible, and the
waitlist pages say and do what the backend expects.

The site is copied to a temporary folder and built there twice, so the test
never writes into the repository.
"""

from __future__ import annotations

import filecmp
import os
import re
import shutil
import subprocess
import sys

import pytest

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SITE = os.path.join(_ROOT, "site")


def _build(folder):
    result = subprocess.run(
        [sys.executable, os.path.join("_build", "build.py")],
        cwd=folder,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert result.returncode == 0, result.stderr[-2000:]


def _outputs(folder):
    out = {}
    for base, dirs, files in os.walk(folder):
        dirs[:] = [d for d in dirs if d not in {"_build", "__pycache__"}]
        for name in files:
            full = os.path.join(base, name)
            out[os.path.relpath(full, folder)] = full
    return out


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    folder = tmp_path_factory.mktemp("site") / "site"
    shutil.copytree(_SITE, folder, ignore=shutil.ignore_patterns("__pycache__"))
    _build(folder)
    first = {rel: open(path, "rb").read() for rel, path in _outputs(folder).items()}
    _build(folder)
    return folder, first


def test_building_twice_changes_nothing(built):
    folder, first = built
    second = {rel: open(path, "rb").read() for rel, path in _outputs(folder).items()}
    assert first == second


def test_the_committed_site_is_what_the_generator_writes(built):
    folder, _ = built
    mine, theirs = _outputs(folder), _outputs(_SITE)
    assert set(mine) == set(theirs)
    stale = [rel for rel in mine if not filecmp.cmp(mine[rel], theirs[rel], shallow=False)]
    assert stale == [], f"run python3 _build/build.py in site/: {stale}"


def _page_path(root, *parts):
    """The file Cloudflare Pages serves for /<parts>: a flat page (privacy.html
    at /privacy) or a folder's index.html (the home pages, the waitlist
    answers)."""
    if parts:
        flat = os.path.join(root, *parts[:-1], parts[-1] + ".html")
        if os.path.isfile(flat):
            return flat
    return os.path.join(root, *parts, "index.html")


def _page(*parts):
    return open(_page_path(_SITE, *parts), encoding="utf-8").read()


@pytest.mark.parametrize("prefix,lang", [((), "en"), (("ar",), "ar")])
def test_the_waitlist_form_matches_the_function(prefix, lang):
    page = _page(*prefix, "waitlist")
    assert 'action="https://europe-west3-own-hub.cloudfunctions.net/join_waitlist"' in page
    assert 'method="post"' in page
    assert f'<input type="hidden" name="lang" value="{lang}">' in page
    assert re.search(r'<input id="contact" name="contact" type="text"[^>]*required', page)
    assert re.search(r'name="consent" type="checkbox" value="yes" required', page)
    assert 'class="hp" aria-hidden="true"' in page and 'name="website"' in page
    assert "<script" not in page


def test_the_consent_sentence_is_plain():
    # Wording version 2 (functions/waitlist/join.py CONSENT_WORDING_VERSION).
    assert (
        "We will message you once: an early invite if you are among the first "
        "100, or the day Own Hub opens. Then we delete your contact."
    ) in _page("waitlist")
    # The brand name is isolated left to right inside the Arabic sentence.
    assert (
        "هنراسلك مرة واحدة: بدعوة بدري لو كنتِ من أول 100، أو يوم افتتاح "
        "<bdi>Own Hub</bdi>. وبعدين هنمسح بيانات التواصل بتاعتك."
    ) in _page("ar", "waitlist")


@pytest.mark.parametrize("page", ["joined", "check", "later"])
@pytest.mark.parametrize("prefix", [(), ("ar",)])
def test_every_page_the_function_redirects_to_exists_and_is_not_indexed(prefix, page):
    html = _page(*prefix, "waitlist", page)
    assert '<meta name="robots" content="noindex, follow">' in html
    sitemap = open(os.path.join(_SITE, "sitemap.xml"), encoding="utf-8").read()
    assert f"/waitlist/{page}" not in sitemap


def test_no_waitlist_page_carries_an_em_dash():
    for prefix in ((), ("ar",)):
        for page in ((), ("joined",), ("check",), ("later",)):
            assert "—" not in _page(*prefix, "waitlist", *page)


@pytest.mark.parametrize("prefix", [(), ("ar",)])
def test_the_privacy_page_covers_the_waitlist_and_carries_no_draft_banner(prefix):
    html = _page(*prefix, "privacy")
    assert 'id="c-waitlist"' in html
    assert "180" in html
    assert "Draft pending" not in html
    assert "مسودة بانتظار" not in html


def test_forms_may_post_only_to_the_function_and_back_to_the_site():
    headers = open(os.path.join(_SITE, "_headers"), encoding="utf-8").read()
    (csp,) = re.findall(r"Content-Security-Policy: (.*)", headers)
    assert "form-action 'self' https://europe-west3-own-hub.cloudfunctions.net;" in csp
    assert "script-src" not in csp and "default-src 'none'" in csp


# ------------------------------------------- M14: privacy and terms v3.0


def _config():
    import json

    with open(os.path.join(_SITE, "config.json"), encoding="utf-8") as handle:
        return json.load(handle)


_GAP_MARKERS = ('class="todo"', "Draft pending", "مسودة بانتظار", "بانتظار الاستكمال")


def _release_problems(folder):
    problems = []
    for rel, path in _outputs(folder).items():
        if not rel.endswith(".html"):
            continue
        text = open(path, encoding="utf-8").read()
        for marker in _GAP_MARKERS:
            if marker in text:
                problems.append((rel, marker))
    return problems


def test_the_site_carries_no_gap_and_no_draft_banner():
    problems = _release_problems(_SITE)
    assert problems == [], problems


@pytest.mark.parametrize("marker", _GAP_MARKERS)
def test_the_release_gate_refuses_every_marker(tmp_path, marker):
    # Prove the scan itself: a copy of the site with one marker slipped into a
    # page must be refused, so a gap can never reach a release unnoticed.
    copy = tmp_path / "site"
    shutil.copytree(_SITE, copy)
    page = copy / "privacy.html"
    page.write_text(page.read_text(encoding="utf-8") + marker, encoding="utf-8")
    assert ("privacy.html", marker) in [
        (rel.replace(os.sep, "/"), m) for rel, m in _release_problems(str(copy))
    ]


@pytest.mark.parametrize("prefix", [(), ("ar",)])
@pytest.mark.parametrize("page", ["privacy", "terms"])
def test_the_policy_and_terms_are_version_3(prefix, page):
    html = _page(*prefix, page)
    assert "<b>Version:</b> 3.0" in html or "<b>الإصدار:</b> 3.0" in html
    assert "—" not in html


def test_no_drafting_note_is_published_anywhere():
    # R2-G3 / M14: not on the page and not in the page source either.
    for rel, path in _outputs(_SITE).items():
        if not rel.endswith(".html"):
            continue
        text = open(path, encoding="utf-8").read()
        assert "[LAWYER" not in text and "[OWNER" not in text, rel


def test_the_page_sources_carry_no_drafting_note():
    for name in ("pages_en.py", "pages_ar.py"):
        source = open(os.path.join(_SITE, "_build", name), encoding="utf-8").read()
        assert "[LAWYER" not in source and "[OWNER" not in source, name


def _build_module():
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "site_build", os.path.join(_SITE, "_build", "build.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_the_generator_strips_a_drafting_note_that_slips_in():
    build = _build_module()
    text = (
        "<p>Kept.</p>\n"
        "        <!-- [LAWYER] confirm this. -->\n"
        "<p>Also kept.<!-- [OWNER] a note\n over two lines. --></p>\n"
        "<!-- an ordinary comment -->\n"
    )
    out = build.strip_drafting_notes(text)
    assert "[LAWYER" not in out and "[OWNER" not in out
    assert "<p>Kept.</p>" in out and "<p>Also kept.</p>" in out
    assert "<!-- an ordinary comment -->" in out


@pytest.mark.parametrize("prefix", [(), ("ar",)])
def test_the_legal_values_are_filled_in(prefix):
    privacy, terms = _page(*prefix, "privacy"), _page(*prefix, "terms")
    for page in (privacy, terms):
        assert 'class="todo"' not in page
    assert "info@pdpc.gov.eg" in privacy and "17372" in privacy
    if not prefix:
        assert "within 6 working days" in privacy
        assert "Personal Data Protection Centre permit" in privacy
        assert "licence or permit" not in privacy
        assert "Cairo Economic Court" in terms
        assert "limited to" not in terms, "no liability cap (Civil Code art. 217)"
        assert "about 6 months (180 days)" in privacy
    else:
        assert "ستة أيام عمل" in privacy
        assert "المحكمة الاقتصادية بالقاهرة" in terms


def test_the_home_page_offers_the_tour_in_both_languages():
    assert "Show me around" in _page()
    assert "«خديني في جولة»" in _page("ar")


def test_the_home_page_does_not_say_she_reads_the_support_mailbox():
    # The support page says the publisher reads it himself.
    assert "when she reads" not in _page()
    assert "when messages get read" in _page()


def _build_with(tmp_path, **values):
    import json

    folder = tmp_path / "site"
    shutil.copytree(_SITE, folder, ignore=shutil.ignore_patterns("__pycache__"))
    path = folder / "config.json"
    config = json.loads(path.read_text(encoding="utf-8"))
    for key, value in values.items():
        config["values"][key]["value"] = value
    path.write_text(json.dumps(config, ensure_ascii=False), encoding="utf-8")
    return folder, subprocess.run(
        [sys.executable, os.path.join("_build", "build.py")],
        cwd=folder, capture_output=True, text=True, timeout=120,
    )


def _home(folder, lang):
    path = os.path.join(str(folder), "index.html") if lang == "en" else os.path.join(str(folder), "ar", "index.html")
    return open(path, encoding="utf-8").read()


def test_the_badges_wait_calmly_while_the_store_links_are_empty():
    assert _config()["values"]["storeUrlIos"]["value"] == ""
    assert _config()["values"]["storeUrlAndroid"]["value"] == ""
    for lang, soon in (("en", "Coming soon"), ("ar", "قريبًا")):
        html = _home(_SITE, lang)
        assert "apps.apple.com" not in html and "play.google.com" not in html
        # Drawn, but not a link: no href, and a screen reader is told why.
        badges = re.findall(r'<a class="badge is-soon" role="link" aria-disabled="true">', html)
        assert len(badges) == 2, lang
        assert soon in html
        assert re.search(r'<a class="badge[^"]*" href=', html) is None
        # The waitlist stands in for them.
        assert 'action="https://europe-west3-own-hub.cloudfunctions.net/join_waitlist"' in html


@pytest.mark.parametrize("prefix", [(), ("ar",)])
@pytest.mark.parametrize("page", ["privacy", "terms", "support", "delete-account", "waitlist"])
def test_every_other_page_carries_the_badges_once_in_its_footer(prefix, page):
    html = _page(*prefix, page)
    assert html.count('src="/assets/badges/app-store-') == 1
    assert html.count('src="/assets/badges/google-play-') == 1


def test_the_home_page_carries_one_app_store_badge():
    # Apple: "Use one App Store badge per layout".
    for lang in ("en", "ar"):
        assert _home(_SITE, lang).count('src="/assets/badges/app-store-') == 1


def test_download_buttons_appear_once_the_store_links_are_set(tmp_path):
    ios = "https://apps.apple.com/eg/app/own-hub/id1234567890"
    android = "https://play.google.com/store/apps/details?id=com.ownhub.app"
    folder, result = _build_with(tmp_path, storeUrlIos=ios, storeUrlAndroid=android)
    assert result.returncode == 0, result.stderr[-2000:]
    en = (folder / "index.html").read_text(encoding="utf-8")
    ar = (folder / "ar" / "index.html").read_text(encoding="utf-8")
    assert f'<a class="badge" href="{ios}" rel="noopener">' in en
    assert 'alt="Download on the App Store"' in en
    assert 'href="https://play.google.com/store/apps/details?id=com.ownhub.app"' in en
    assert 'alt="Get it on Google Play"' in en
    assert "aria-disabled" not in en and "Coming soon" not in en
    assert f'href="{ios}"' in ar and "حمّليه من" in ar
    assert "play.google.com" in ar and 'src="/assets/badges/google-play-ar.png"' in ar
    # Once both stores are live the waitlist form leaves the home page.
    assert "join_waitlist" not in en
    privacy = (folder / "privacy.html").read_text(encoding="utf-8")
    assert f'href="{ios}"' in privacy, "the footer badges follow the config too"


def test_only_one_store_link_draws_only_its_button(tmp_path):
    android = "https://play.google.com/store/apps/details?id=com.ownhub.app"
    folder, result = _build_with(tmp_path, storeUrlAndroid=android)
    assert result.returncode == 0, result.stderr[-2000:]
    en = (folder / "index.html").read_text(encoding="utf-8")
    assert f'<a class="badge" href="{android}"' in en
    assert "apps.apple.com" not in en
    assert 'alt="Download on the App Store, coming soon"' in en


@pytest.mark.parametrize(
    "key,url",
    [
        ("storeUrlIos", "http://apps.apple.com/eg/app/own-hub/id1"),
        ("storeUrlIos", "https://example.com/own-hub"),
        ("storeUrlAndroid", "javascript:alert(1)"),
    ],
)
def test_a_wrong_store_link_stops_the_build(tmp_path, key, url):
    _, result = _build_with(tmp_path, **{key: url})
    assert result.returncode != 0
    assert key in result.stderr


@pytest.mark.parametrize("prefix", [(), ("ar",)])
def test_the_privacy_page_says_what_v3_promises(prefix):
    html = _page(*prefix, "privacy")
    for anchor in ("c-agreements", "c-ai", "c-messages", "children", "language"):
        assert f'id="{anchor}"' in html, anchor
    assert "Only you can read" not in html


def test_arabic_pages_isolate_latin_runs():
    html = _page("ar", "privacy")
    assert "<bdi>Google Cloud Vision</bdi>" in html
    assert "<code>com.ownhub.app</code>" in html, "code is left alone"
    assert 'href="mailto:' in html and "<bdi>mailto" not in html
    assert "<bdi>" not in _page("privacy"), "English pages are not touched"


def test_the_deletion_page_uses_a_code_not_a_phone_call():
    for prefix in ((), ("ar",)):
        html = _page(*prefix, "delete-account")
        assert "we will phone that number" not in html
        assert "نتصل بهذا الرقم" not in html


# ------------------------------------------- the deployable site, any domain


def _run_build(folder, *args, env=None):
    return subprocess.run(
        [sys.executable, os.path.join("_build", "build.py"), *args],
        cwd=folder, capture_output=True, text=True, timeout=120,
        env={**os.environ, **(env or {})},
    )


def _copy_site(tmp_path):
    folder = tmp_path / "site"
    shutil.copytree(_SITE, folder, ignore=shutil.ignore_patterns("__pycache__"))
    return folder


def test_every_internal_link_on_the_committed_site_resolves():
    assert _build_module().check_links(_SITE) == []


def test_the_link_check_catches_a_broken_link_and_a_missing_anchor(tmp_path):
    folder = _copy_site(tmp_path)
    page = folder / "support.html"
    page.write_text(
        page.read_text(encoding="utf-8").replace(
            "</main>", '<a href="/no-such-page">x</a><a href="/privacy#no-such-part">y</a></main>'
        ),
        encoding="utf-8",
    )
    problems = _build_module().check_links(str(folder))
    assert any("/no-such-page does not exist" in p for p in problems)
    assert any("#no-such-part" in p for p in problems)


def test_the_store_addresses_are_served_without_a_redirect():
    # Cloudflare Pages serves privacy.html at /privacy. A privacy/index.html
    # would make /privacy redirect to /privacy/, which _redirects sends back.
    for prefix in ((), ("ar",)):
        for page in ("privacy", "terms", "support", "delete-account"):
            assert os.path.isfile(os.path.join(_SITE, *prefix, page + ".html"))
            assert not os.path.exists(os.path.join(_SITE, *prefix, page, "index.html"))


def test_no_redirect_points_at_an_address_that_redirects_again():
    build = _build_module()
    for line in open(os.path.join(_SITE, "_redirects"), encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or ":splat" in line or "*" in line:
            continue
        source, target, _status = line.split()
        if target.endswith(".html"):
            assert os.path.isfile(os.path.join(_SITE, target.lstrip("/"))), line
            continue
        rel = target.lstrip("/")
        served = rel + "index.html" if (not rel or rel.endswith("/")) else rel + ".html"
        assert os.path.isfile(os.path.join(_SITE, served)), line
        assert build.resolve_path(_SITE, target) is not None


def test_a_real_domain_fills_every_absolute_address(tmp_path):
    folder = _copy_site(tmp_path)
    out = tmp_path / "out"
    result = _run_build(folder, "--base-url", "https://ownhub.app/", "--out", str(out))
    assert result.returncode == 0, result.stderr[-2000:]
    en, ar = (out / "index.html").read_text(encoding="utf-8"), (out / "ar" / "privacy.html").read_text(encoding="utf-8")
    assert '<link rel="canonical" href="https://ownhub.app/">' in en
    assert '<link rel="alternate" hreflang="ar" href="https://ownhub.app/ar/">' in en
    assert '<meta property="og:url" content="https://ownhub.app/">' in en
    assert '<meta property="og:image" content="https://ownhub.app/assets/og/og-en.png">' in en
    assert '<meta name="twitter:card" content="summary_large_image">' in en
    assert '<link rel="canonical" href="https://ownhub.app/ar/privacy">' in ar
    assert '<meta property="og:image" content="https://ownhub.app/assets/og/og-ar.png">' in ar
    sitemap = (out / "sitemap.xml").read_text(encoding="utf-8")
    assert "<loc>https://ownhub.app/privacy</loc>" in sitemap and "ownhub.example" not in sitemap
    assert "Sitemap: https://ownhub.app/sitemap.xml" in (out / "robots.txt").read_text(encoding="utf-8")
    # The contact addresses follow the domain, everywhere they appear.
    privacy = (out / "privacy.html").read_text(encoding="utf-8")
    support = (out / "support.html").read_text(encoding="utf-8")
    assert 'href="mailto:privacy@ownhub.app"' in privacy
    assert "support@ownhub.app" in support
    for path in out.rglob("*.html"):
        text = path.read_text(encoding="utf-8")
        assert "gmail.com" not in text.replace("Google (Gmail)", ""), path
        assert "ownhub.example" not in text, path


def test_a_mailbox_already_on_the_domain_is_kept(tmp_path):
    """info@ or hello@ on the site's own domain is the owner's choice of
    mailbox, so it is published as is rather than renamed to privacy@."""
    import json

    folder = _copy_site(tmp_path)
    path = folder / "config.json"
    config = json.loads(path.read_text(encoding="utf-8"))
    config["values"]["contactPrivacy"]["value"] = "hello@example.org"
    config["values"]["contactSupport"]["value"] = "help@example.org"
    path.write_text(json.dumps(config, ensure_ascii=False), encoding="utf-8")
    out = tmp_path / "out"
    result = _run_build(folder, "--base-url", "https://example.org/", "--out", str(out))
    assert result.returncode == 0, result.stderr[-2000:]
    privacy = (out / "privacy.html").read_text(encoding="utf-8")
    support = (out / "support.html").read_text(encoding="utf-8")
    assert 'href="mailto:hello@example.org"' in privacy
    assert "help@example.org" in support
    assert "privacy@example.org" not in privacy
    assert "support@example.org" not in support


def test_the_domain_can_come_from_the_environment(tmp_path):
    folder = _copy_site(tmp_path)
    out = tmp_path / "out"
    result = _run_build(folder, "--out", str(out), env={"BASE_URL": "https://example.com"})
    assert result.returncode == 0, result.stderr[-2000:]
    assert '<link rel="canonical" href="https://example.com/privacy">' in (out / "privacy.html").read_text(encoding="utf-8")


def test_keep_contact_emails_keeps_the_configured_mailbox(tmp_path):
    folder = _copy_site(tmp_path)
    out = tmp_path / "out"
    result = _run_build(folder, "--base-url", "https://example.com", "--out", str(out), "--keep-contact-emails")
    assert result.returncode == 0, result.stderr[-2000:]
    configured = _config()["values"]["contactPrivacy"]["value"]
    assert configured in (out / "privacy.html").read_text(encoding="utf-8")


@pytest.mark.parametrize("url", ["http://example.com", "example.com", "https://example.com/site", "https://"])
def test_a_wrong_base_url_stops_the_build(tmp_path, url):
    folder = _copy_site(tmp_path)
    result = _run_build(folder, "--base-url", url, "--out", str(tmp_path / "out"))
    assert result.returncode != 0
    assert "base URL" in result.stderr


def test_the_output_folder_holds_only_publishable_files(tmp_path):
    folder = _copy_site(tmp_path)
    out = tmp_path / "out"
    result = _run_build(folder, "--base-url", "https://example.com", "--out", str(out))
    assert result.returncode == 0, result.stderr[-2000:]
    files = {p.relative_to(out).as_posix() for p in out.rglob("*") if p.is_file()}
    assert not any(f.startswith("_build/") for f in files)
    assert "config.json" not in files
    assert not [f for f in files if f.endswith((".py", ".md", ".sh", ".pyc"))]
    for needed in ("index.html", "ar/index.html", "privacy.html", "ar/delete-account.html",
                   "404.html", "ar/404.html", "_headers", "_redirects", "sitemap.xml",
                   "robots.txt", "manifest.webmanifest", "favicon.ico",
                   "assets/site.css", "assets/og/og-en.png", "assets/badges/app-store-ar.svg"):
        assert needed in files, needed
    assert _build_module().check_links(str(out)) == []


def test_the_output_folder_must_be_outside_the_site(tmp_path):
    folder = _copy_site(tmp_path)
    result = _run_build(folder, "--out", str(folder / "dist"))
    assert result.returncode != 0


def test_the_headers_keep_the_site_locked_down():
    headers = open(os.path.join(_SITE, "_headers"), encoding="utf-8").read()
    (csp,) = re.findall(r"Content-Security-Policy: (.*)", headers)
    for rule in ("default-src 'none'", "style-src 'self'", "font-src 'self'", "img-src 'self'",
                 "manifest-src 'self'", "frame-ancestors 'none'", "object-src 'none'", "base-uri 'none'"):
        assert rule in csp, rule
    assert "script-src" not in csp and "unsafe-inline" not in csp and "data:" not in csp
    for header in ("Strict-Transport-Security: max-age=", "Referrer-Policy: no-referrer",
                   "Permissions-Policy: ", "X-Content-Type-Options: nosniff"):
        assert header in headers, header
    assert "/assets/fonts/*\n  Cache-Control: public, max-age=31536000, immutable" in headers


def test_no_page_loads_anything_from_anyone_else():
    for rel, path in _outputs(_SITE).items():
        if not rel.endswith((".html", ".css", ".webmanifest")):
            continue
        text = open(path, encoding="utf-8").read()
        assert "<script" not in text, rel
        assert "fonts.googleapis" not in text and "fonts.gstatic" not in text, rel
        assert 'style="' not in text, f"{rel}: an inline style would break the CSP"
        for attr, url in re.findall(r'\s(src|srcset)="([^"]+)"', text):
            assert url.startswith("/"), f"{rel}: {url}"
        own = _config()["baseUrl"].rstrip("/") + "/"
        for url in re.findall(r'<link [^>]*href="([^"]+)"', text):
            # Relative, or this site's own address (canonical, hreflang).
            assert url.startswith("/") or url.startswith(own), f"{rel}: {url}"


@pytest.mark.parametrize("prefix", [(), ("ar",)])
def test_every_page_has_share_tags_and_icons(prefix):
    for page in ((), ("privacy",), ("support",), ("waitlist",)):
        html = _page(*prefix, *page)
        assert '<meta property="og:image" content="' in html
        assert '<meta property="og:image:width" content="1200">' in html
        assert '<meta name="twitter:card" content="summary_large_image">' in html
        assert '<link rel="apple-touch-icon" href="/assets/icons/apple-touch-icon.png">' in html
        assert '<link rel="manifest" href="/manifest.webmanifest">' in html
        assert 'rel="preload" href="/assets/fonts/rubik-' in html


def test_every_image_has_its_size_and_an_alt():
    for rel, path in _outputs(_SITE).items():
        if not rel.endswith(".html"):
            continue
        for tag in re.findall(r"<img [^>]*>", open(path, encoding="utf-8").read()):
            assert re.search(r'\swidth="\d+"', tag) and re.search(r'\sheight="\d+"', tag), (rel, tag)
            assert ' alt="' in tag, (rel, tag)


def test_the_kitten_is_decoration_only():
    for lang in ("en", "ar"):
        html = _home(_SITE, lang)
        (svg,) = re.findall(r'<svg class="kitten"[^>]*>', html)
        assert 'aria-hidden="true"' in svg and 'focusable="false"' in svg
        assert "stroke=\"#241A1E\"" not in html, "flat colour, no dark outline"


def test_the_home_pages_promise_only_what_this_version_does():
    for lang in ("en", "ar"):
        html = _home(_SITE, lang)
        assert "—" not in html
    en = _home(_SITE, "en").lower()
    for claim in ("video call", "gym", "marketplace", "ai assistant", "artificial intelligence",
                  "join the community", "book a coach", "chat with"):
        assert claim not in en, claim
    assert "no community, coaching or assistant" in " ".join(en.split())


def test_before_launch_the_waitlist_is_the_first_thing_on_the_home_page():
    for lang, offer in (("en", "The first 100 women on the list"), ("ar", "أول 100 ست في القايمة")):
        html = _home(_SITE, lang)
        form = html.index('class="waitlist"')
        assert html.index('<h1>') < html.index(offer) < form < html.index('id="inside"')
        assert html.count('class="waitlist"') == 1


def test_the_launch_is_free_and_nothing_promises_a_paid_plan():
    # Everything ships free. A paid plan may come later, and the site says
    # nothing about one until it exists.
    for lang in ("en", "ar"):
        for page in ("index.html", "waitlist.html"):
            folder = _SITE if lang == "en" else os.path.join(_SITE, "ar")
            with open(os.path.join(folder, page), encoding="utf-8") as f:
                text = " ".join(f.read().split())
            assert not re.search(r"\bPro\b", text), (lang, page)
    assert "Free, all of it." in _home(_SITE, "en")
    assert "مجاني بالكامل" in _home(_SITE, "ar")


def test_the_policy_does_not_promise_a_phone_backup_forgets_the_profile_photo():
    # The photo is deleted from the phone; a backup of the whole phone made
    # earlier can still hold it, and the policy says so.
    for folder, needle in (
        (_SITE, "a copy made earlier stays in that backup"),
        (os.path.join(_SITE, "ar"), "أي نسخة اتعملت قبل كده بتفضل في النسخة الاحتياطية دي"),
    ):
        with open(os.path.join(folder, "privacy.html"), encoding="utf-8") as f:
            text = " ".join(f.read().split())
        assert needle in text, folder
