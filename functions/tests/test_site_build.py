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
    assert "سنراسلك مرة واحدة عند افتتاح Own Hub، ثم نحذف بيانات التواصل الخاصة بك." in _page(
        "ar", "waitlist"
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
def test_the_privacy_page_covers_the_waitlist_and_keeps_the_draft_banner(prefix):
    html = _page(*prefix, "privacy")
    assert 'id="c-waitlist"' in html
    assert "180" in html
    banner = (
        "Draft pending review by a licensed Egyptian lawyer."
        if not prefix
        else 'class="callout" role="note"'
    )
    assert banner in html


def test_forms_may_post_only_to_the_function_and_back_to_the_site():
    headers = open(os.path.join(_SITE, "_headers"), encoding="utf-8").read()
    (csp,) = re.findall(r"Content-Security-Policy: (.*)", headers)
    assert "form-action 'self' https://europe-west3-own-hub.cloudfunctions.net;" in csp
    assert "script-src" not in csp and "default-src 'none'" in csp
