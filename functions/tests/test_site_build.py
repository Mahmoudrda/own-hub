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


def _page(*parts):
    return open(os.path.join(_SITE, *parts, "index.html"), encoding="utf-8").read()


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
    assert "We will message you once when Own Hub opens, then delete your contact." in _page(
        "waitlist"
    )
    # The brand name is isolated left to right inside the Arabic sentence.
    assert (
        "سنراسلك مرة واحدة عند افتتاح <bdi>Own Hub</bdi>، ثم نحذف بيانات التواصل الخاصة بك."
        in _page("ar", "waitlist")
    )


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
    page = copy / "privacy" / "index.html"
    page.write_text(page.read_text(encoding="utf-8") + marker, encoding="utf-8")
    assert ("privacy/index.html", marker) in [
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
    assert "«خذيني في جولة»" in _page("ar")


def test_the_home_page_does_not_say_she_reads_the_support_mailbox():
    # The support page says the publisher reads it himself.
    assert "when she reads" not in _page()
    assert "the hours messages are read" in _page()


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


def test_no_download_button_while_the_store_links_are_empty():
    assert _config()["values"]["storeUrlIos"]["value"] == ""
    for prefix in ((), ("ar",)):
        html = open(os.path.join(_SITE, *prefix, "index.html"), encoding="utf-8").read()
        assert "store-links" not in html
        assert "apps.apple.com" not in html and "play.google.com" not in html


def test_download_buttons_appear_once_the_store_links_are_set(tmp_path):
    ios = "https://apps.apple.com/eg/app/own-hub/id1234567890"
    android = "https://play.google.com/store/apps/details?id=com.ownhub.app"
    folder, result = _build_with(tmp_path, storeUrlIos=ios, storeUrlAndroid=android)
    assert result.returncode == 0, result.stderr[-2000:]
    en = (folder / "index.html").read_text(encoding="utf-8")
    ar = (folder / "ar" / "index.html").read_text(encoding="utf-8")
    assert f'href="{ios}"' in en and "Download on the App Store" in en
    assert 'href="https://play.google.com/store/apps/details?id=com.ownhub.app"' in en
    assert "Get it on Google Play" in en
    assert f'href="{ios}"' in ar and "حمّليه من" in ar
    assert "play.google.com" in ar


def test_only_one_store_link_draws_only_its_button(tmp_path):
    android = "https://play.google.com/store/apps/details?id=com.ownhub.app"
    folder, result = _build_with(tmp_path, storeUrlAndroid=android)
    assert result.returncode == 0, result.stderr[-2000:]
    en = (folder / "index.html").read_text(encoding="utf-8")
    assert "Get it on Google Play" in en and "App Store" not in en


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
