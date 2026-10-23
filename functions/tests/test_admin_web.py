"""The reviewer dashboard is a static page: pinned SDK, no blocking dialogs,
one approval call per click, and no secrets in the source."""

from __future__ import annotations

import json
import os
import re

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_WEB = os.path.join(_ROOT, "admin-web")
_SOURCES = ("index.html", "app.js", "logic.js", "styles.css", "config.example.js")


def _read(name):
    with open(os.path.join(_WEB, name), encoding="utf-8") as handle:
        return handle.read()


def _all():
    return {name: _read(name) for name in _SOURCES}


def test_only_pinned_sdk_urls():
    pinned = re.compile(r"^https://www\.gstatic\.com/firebasejs/\d+\.\d+\.\d+/firebase-[a-z-]+\.js$")
    urls = []
    for name, text in _all().items():
        if name.endswith(".css"):
            continue
        urls += re.findall(r"""(?:from\s+|import\s*\(\s*|src=)["'](https?://[^"']+)["']""", text)
    sdk = [u for u in urls if "firebasejs" in u]
    assert sdk, "no Firebase SDK import found"
    assert all(pinned.match(u) for u in sdk), sdk
    foreign = [u for u in urls if "firebasejs" not in u]
    assert foreign == [], foreign
    versions = {re.search(r"firebasejs/([\d.]+)/", u).group(1) for u in sdk}
    assert len(versions) == 1, versions
    assert not re.search(r"firebasejs/(latest|\d+/)", json.dumps(sdk))


def test_no_blocking_dialogs():
    for name, text in _all().items():
        assert not re.search(r"\b(confirm|alert|prompt)\s*\(", text), name


def test_approve_calls_approve_user_once():
    app = _read("app.js")
    assert len(re.findall(r"""["']approve_user["']""", app)) == 1
    assert len(re.findall(r"""["']approve_users["']""", app)) == 1
    body = re.search(r"async function approveOne\(([^)]*)\)\s*\{(.*?)\n\}", app, re.S)
    assert body and body.group(2).count("call(") == 1
    run = re.search(r"async function runApproval\(.*?\n\}", app, re.S).group(0)
    assert run.count("approveOne(") == 1
    assert "state.busy.has(uid)" in run
    for handler, reason in (("onApprove", "approve"), ("onKnown", "knownPerson")):
        text = re.search(rf"async function {handler}\(.*?\n\}}", app, re.S).group(0)
        assert text.count("runApproval(") == 1 and reason in text
    assert app.count("onApprove(row.uid)") == 1
    assert "approve_user" not in re.sub(r"approveOne|approveMany", "", app.replace('"approve_user"', "").replace('"approve_users"', ""))


def test_region_and_app_check():
    config = _read("config.example.js")
    assert 'functionsRegion = "europe-west3"' in config
    app = _read("app.js")
    assert "ReCaptchaEnterpriseProvider" in app and "initializeAppCheck" in app
    assert "signInWithEmailAndPassword" in app


def test_no_inline_secrets():
    for name, text in _all().items():
        assert not re.search(r"AIza[0-9A-Za-z_\-]{30,}", text), name
        assert "PRIVATE KEY" not in text, name
        assert not re.search(r"""(?i)(password|secret|token)\s*[:=]\s*["'][^"']{6,}["']""", text), name
    config = _read("config.example.js")
    assert config.count("REPLACE_WITH") >= 4
    assert "6L" not in re.sub(r"REPLACE_WITH\w+", "", config)


def test_reduced_motion_and_accessibility_hooks():
    css = _read("styles.css")
    assert "prefers-reduced-motion: reduce" in css
    assert ":focus-visible" in css
    html = _read("index.html")
    assert 'name="viewport"' in html and 'role="tablist"' in html
