"""B4: which X-Forwarded-For entry the waitlist rate limit trusts.

A client can send any X-Forwarded-For it likes; Google's front end then APPENDS
what it saw. Everything to the left of what Google appended is the client's
own text. So the address is read from the RIGHT:

  * entries that are not public addresses (private, loopback, link-local,
    carrier-grade NAT, reserved, or not an address at all) are skipped, so an
    internal Google hop can never become the key;
  * then TRUSTED_PUBLIC_HOPS public entries are dropped from the right. 0 for
    the Cloud Run URL the form posts to today, where the front end appends
    only the client; 1 if an external Application Load Balancer is ever put
    in front, which appends "<client>, <load balancer address>";
  * the next entry is the client. Nothing the client prepends can move it.

IPv6 is keyed on its /64, because one home or phone is handed a whole /64 and
can rotate through it at will.
"""

from __future__ import annotations

import datetime as dt

import pytest

from tests.test_waitlist import KEY, FakeStore, req
from waitlist import join

REAL = "197.32.10.20"     # an Egyptian address, the woman's own
LB = "34.120.7.7"         # a load balancer's public address


@pytest.mark.parametrize(
    "header, expected",
    [
        # Cloud Run URL: the front end appends the client, nothing after it.
        (REAL, REAL),
        (f"1.2.3.4, {REAL}", REAL),
        (f"spoofed, 1.2.3.4,{REAL}", REAL),
        (f"{REAL}, {REAL}", REAL),
        # Whatever a spoofer writes on the left, the key does not move.
        (f"8.8.8.8, 9.9.9.9, 41.33.1.1, {REAL}", REAL),
        # An internal hop after the client is never the key.
        (f"6.6.6.6, {REAL}, 169.254.1.1", REAL),
        (f"6.6.6.6, {REAL}, 10.0.0.5", REAL),
        (f"{REAL}, 100.64.1.1", REAL),
        # Ports and brackets, as some proxies write them.
        (f"6.6.6.6, {REAL}:51234", REAL),
        # Junk entries are skipped, not trusted.
        (f"unknown, , {REAL}", REAL),
    ],
)
def test_the_client_is_the_last_public_entry(header, expected):
    assert join.client_ip(header, "203.0.113.9") == expected


def test_behind_a_load_balancer_the_client_is_the_first_entry_google_appended():
    header = f"spoofed, {REAL}, {LB}"
    assert join.client_ip(header, "", trusted_hops=1) == REAL
    assert join.client_ip(f"1.1.1.1, 2.2.2.2, {REAL}, {LB}", "", trusted_hops=1) == REAL


def test_the_form_today_posts_to_the_cloud_run_url_with_no_load_balancer():
    assert join.TRUSTED_PUBLIC_HOPS == 0


def test_with_no_usable_header_the_peer_address_is_used():
    assert join.client_ip("", REAL) == REAL
    assert join.client_ip("10.0.0.1, garbage", REAL) == REAL
    assert join.client_ip(None, REAL) == REAL


def test_ipv6_is_keyed_on_its_slash_64():
    a = join.client_ip("2c0f:fc88:1:2:aaaa:bbbb:cccc:1", "")
    b = join.client_ip("6.6.6.6, [2c0f:fc88:1:2:dddd::9]:443", "")
    assert a == b == "2c0f:fc88:1:2::/64"
    assert join.client_ip("2c0f:fc88:1:3::1", "") != a


def test_an_ambiguous_spelling_is_not_an_address():
    # Leading zeros read as octal by some parsers; skipped, not guessed at.
    assert join.client_ip(f"197.032.010.020", REAL) == REAL
    assert join.client_ip(f" {REAL} ", "") == REAL


def test_spoofing_the_header_does_not_buy_more_attempts():
    store = FakeStore()
    now = dt.datetime(2026, 10, 2, 12, tzinfo=dt.timezone.utc)
    answers = []
    for i in range(join.DAILY_LIMIT_PER_IP + 3):
        ip = join.client_ip(f"10.{i}.0.1, 6.6.{i}.6, {REAL}", "")
        request = req({"contact": f"0101234567{i % 10}"}, ip=ip)
        answers.append(join.handle(request, store, lambda: KEY, now).status)
    assert answers[: join.DAILY_LIMIT_PER_IP] == [200] * join.DAILY_LIMIT_PER_IP
    assert set(answers[join.DAILY_LIMIT_PER_IP :]) == {429}


def test_the_flask_adapter_uses_client_ip(monkeypatch):
    from flask import Request
    from werkzeug.test import EnvironBuilder

    builder = EnvironBuilder(
        method="POST",
        data={"contact": "01012345678", "consent": "yes"},
        headers={"X-Forwarded-For": f"{REAL}, 6.6.6.6, 41.33.1.1, 169.254.8.1"},
    )
    assert join.from_flask(Request(builder.get_environ())).ip == "41.33.1.1"
