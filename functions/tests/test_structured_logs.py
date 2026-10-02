"""S14: one structured line per decision. Codes, counts and timings only:
no uid, no phone, no NID, no image, no id_hmac."""

from __future__ import annotations

import json

import pytest

import main
from identity import config, decisions, logs, reasons, review, webhook
from tests import test_pipeline as tp
from tests.fake_review_store import FakeReviewStore
from tests.test_decide_hardening import FEMALE_ADULT, MALE_ADULT, privacy_scan
from tests.test_entrypoints import body, inner, request, stubbed  # noqa: F401
from tests.test_verify_gate import writes  # noqa: F401


def lines(capsys):
    captured = capsys.readouterr()
    out = []
    for raw in (captured.out + captured.err).splitlines():
        try:
            out.append(json.loads(raw))
        except ValueError:
            continue
    return out


def decisions_in(entries):
    return [e for e in entries if e.get("event") == "verification_decision"]


def assert_clean(entries, *secrets):
    text = json.dumps(entries)
    for secret in secrets:
        assert secret not in text, f"{secret!r} reached a log line"
    assert not privacy_scan.ASCII_14.search(text)
    for entry in entries:
        keys = set(entry) - {"severity", "message"}
        assert keys <= logs.ALLOWED_KEYS, keys - logs.ALLOWED_KEYS
        assert entry.get("event") != "log_field_refused"


def test_verify_identity_logs_one_line_with_codes_and_latency(monkeypatch, writes, capsys):
    deps, session = tp.build(number=tp.MALE, word="ذكر")
    monkeypatch.setattr(main, "_deps", lambda: deps)
    capsys.readouterr()
    inner("verify_identity")(request(body(liveness={"sessionId": session})))
    entries = lines(capsys)
    found = decisions_in(entries)
    assert len(found) == 1
    line = found[0]
    assert line["callable"] == "verify_identity"
    assert line["outcome"] == decisions.REJECTED_NOT_ELIGIBLE
    assert line["reasons"] == [reasons.SEX_DIGIT_MALE]
    assert isinstance(line["latencyMs"], int)
    assert_clean(entries, "uid-1", tp.MALE)


def test_an_open_review_still_logs_its_decision(writes, capsys):
    writes["gate"] = main.store.Gate(open_flag_id="f-1")
    capsys.readouterr()
    inner("verify_identity")(request(body()))
    found = decisions_in(lines(capsys))
    assert len(found) == 1 and found[0]["outcome"] == decisions.PENDING_REVIEW


def test_request_review_logs_without_the_uid(monkeypatch, stubbed, capsys):
    fake = FakeReviewStore()
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    capsys.readouterr()
    inner("request_review")(request({"path": "niqab"}, uid="w-unique-0001"))
    entries = lines(capsys)
    found = decisions_in(entries)
    assert len(found) == 1
    assert found[0]["reasons"] == [reasons.NIQAB_PATH_REQUESTED]
    assert found[0]["state"] == "pending"
    assert_clean(entries, "w-unique-0001", "+20100")


def test_decide_logs_the_outcome_and_never_the_digits(monkeypatch, stubbed, capsys):
    fake = FakeReviewStore()
    flag_id = review.request(fake, "w-subject-77", "niqab").flag_id
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    capsys.readouterr()
    inner("decide_verification_flag")(
        request(
            {"flagId": flag_id, "approve": True, "nid": FEMALE_ADULT},
            uid="rev",
            token={"womanReviewer": True},
        )
    )
    entries = lines(capsys)
    found = decisions_in(entries)
    assert len(found) == 1 and found[0]["outcome"] == decisions.APPROVED
    assert_clean(entries, FEMALE_ADULT, "w-subject-77")


def test_a_refused_nid_logs_nothing_at_all(monkeypatch, stubbed, capsys):
    fake = FakeReviewStore()
    flag_id = review.request(fake, "w-subject-78", "niqab").flag_id
    review.schedule(fake, "rev", flag_id, "video", "2026-10-05T10:00:00+02:00")
    monkeypatch.setattr(main.store, "FirestoreReviewStore", lambda: fake)
    capsys.readouterr()
    with pytest.raises(Exception):
        inner("decide_verification_flag")(
            request({"flagId": flag_id, "approve": True, "nid": MALE_ADULT},
                    uid="rev", token={"womanReviewer": True})
        )
    assert_clean(lines(capsys), MALE_ADULT)


def test_the_kill_switch_logs_its_alert_event(monkeypatch, stubbed, capsys):
    monkeypatch.setattr(
        main.store, "daily_count_and_increment",
        lambda field="sessions": config.DAILY_VERIFICATION_LIMIT + 1,
    )
    capsys.readouterr()
    with pytest.raises(Exception):
        inner("verify_identity")(request(body()))
    entries = [e for e in lines(capsys) if e.get("event") == "daily_limit_reached"]
    assert len(entries) == 1 and entries[0]["field"] == "verifications"
    assert entries[0]["severity"] == "WARNING"


def test_health_consent_logs_its_state(monkeypatch, stubbed, capsys):
    monkeypatch.setattr(main.store, "write_health_consent", lambda uid, g: None)
    monkeypatch.setattr(main.store, "purge_health_data", lambda uid: None)
    capsys.readouterr()
    inner("record_health_consent")(request({"consentVersion": 1, "granted": False}))
    found = decisions_in(lines(capsys))
    assert len(found) == 1 and found[0]["state"] == "withdrawn"


# ----------------------------------------------------------- the guard


def test_a_field_off_the_allowlist_is_refused_without_its_content(capsys):
    logs.decision("x", uid="w-leak-0001")
    entries = lines(capsys)
    assert [e["event"] for e in entries] == ["log_field_refused"]
    assert "w-leak-0001" not in json.dumps(entries)


def test_a_long_digit_run_is_refused(capsys):
    logs.decision("x", outcome="01005550132")
    entries = lines(capsys)
    assert [e["event"] for e in entries] == ["log_field_refused"]
    assert "01005550132" not in json.dumps(entries)


def test_only_reason_codes_survive_in_reasons(capsys):
    logs.decision("x", reasons=[reasons.MATCH_PASS, "a sentence about her"])
    entries = decisions_in(lines(capsys))
    assert entries[0]["reasons"] == [reasons.MATCH_PASS]


# ----------------------------------------------------------- the webhook


def test_a_missing_webhook_logs_an_error_in_production(monkeypatch, capsys):
    monkeypatch.setattr(webhook, "_secret_url", lambda: None)
    webhook.post_flag("flag-abc", [reasons.NIQAB_PATH_REQUESTED])
    entries = lines(capsys)
    assert [(e["event"], e["severity"], e["flagId"]) for e in entries] == [
        ("flag_webhook_missing", "ERROR", "flag-abc")
    ]


def test_the_emulator_stays_quiet(monkeypatch, capsys):
    monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
    webhook.post_flag("flag-abc", [])
    assert lines(capsys) == []


def test_the_secret_supplies_the_url_and_a_failure_is_logged_without_payload(monkeypatch, capsys):
    monkeypatch.setattr(webhook, "_secret_url", lambda: "https://hook.invalid/x")
    posted = {}

    def fail(req, timeout):
        posted["url"] = req.full_url
        raise OSError("down")

    monkeypatch.setattr(webhook.urllib.request, "urlopen", fail)
    webhook.post_flag("flag-abc", [reasons.CAMERA_DECLINED])
    assert posted["url"] == "https://hook.invalid/x"
    entries = lines(capsys)
    assert [e["event"] for e in entries] == ["flag_webhook_failed"]
    assert reasons.CAMERA_DECLINED not in json.dumps(entries)


def test_the_env_var_wins_over_the_secret(monkeypatch):
    monkeypatch.setenv("FLAG_WEBHOOK_URL", "https://env.invalid/")
    assert webhook.url() == "https://env.invalid/"
    assert config.FLAG_WEBHOOK_REQUIRED is True
