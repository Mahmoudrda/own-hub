"""S14: the committed alert policies match the events the code emits."""

from __future__ import annotations

import json
import os

_OPS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "firebase",
    "ops",
)


def _policy(name):
    with open(os.path.join(_OPS, name), encoding="utf-8") as handle:
        return json.load(handle)


def _filter(policy):
    return policy["conditions"][0]["conditionMatchedLog"]["filter"]


def test_kill_switch_policy_matches_the_warn_event():
    policy = _policy("kill-switch-alert-policy.json")
    assert 'jsonPayload.event="daily_limit_reached"' in _filter(policy)
    assert 'resource.type="cloud_run_revision"' in _filter(policy)
    assert policy["alertStrategy"]["notificationRateLimit"]["period"] == "3600s"


def test_webhook_policy_matches_the_missing_event():
    policy = _policy("webhook-missing-alert-policy.json")
    assert 'jsonPayload.event="flag_webhook_missing"' in _filter(policy)


def test_the_events_are_the_ones_the_code_emits():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    main_src = open(os.path.join(root, "main.py"), encoding="utf-8").read()
    hook_src = open(os.path.join(root, "identity", "webhook.py"), encoding="utf-8").read()
    assert 'logs.warn("daily_limit_reached"' in main_src
    assert 'logs.error("flag_webhook_missing"' in hook_src


def test_no_em_dashes_in_the_policy_text():
    for name in os.listdir(_OPS):
        text = open(os.path.join(_OPS, name), encoding="utf-8").read()
        assert "—" not in text and "–" not in text
