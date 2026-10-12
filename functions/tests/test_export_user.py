"""M8: the owner's export of one woman's data. Every manifest row is exported
or excluded with a reason, and the copy holds only her data."""

from __future__ import annotations

import datetime as dt
import json

from account import manifest
from tools import export_user

HER = "her-uid"
OTHER = "other-uid"
NOW = dt.datetime(2026, 10, 6, 9, tzinfo=dt.timezone.utc)


class FakeReader:
    def auth_record(self, uid):
        return {"phoneNumber": "+201012345678", "createdAt": NOW, "lastSignInAt": NOW}

    def user_doc(self, uid):
        return {
            "profile": {"goal": "strength", "lifeStage": "pregnant", "allergies": ["nuts"]},
            "verification": {"state": "approved", "decidedAt": NOW},
            "language": "ar",
        }

    def subcollection(self, uid, name):
        assert uid == HER
        return {
            "sessions": {"live-1": {"sets": 3, "at": NOW}},
            "meals": {"2026-10-05": {"slots": {"lunch": ["ful"]}}},
            "consents": {"legal-t3-p3": {"termsVersion": 3, "at": NOW}},
            "checkins": {"2026-10-05": {"energy": 2}},
        }.get(name, {})

    def where_uid(self, collection, uid):
        assert uid == HER
        return {
            "verificationJobs": {"job-1": {"uid": HER, "state": "APPROVED", "reasons": ["match_pass"], "pepper_version": 1, "provider_ids": {"x": "y"}}},
            "verification_flags": {"flag-1": {"uid": HER, "state": "APPROVED"}},
            "nidRegistry": {"hmac-abc": {"uid": HER, "state": "active"}},
        }.get(collection, {})

    def doc(self, collection, doc_id):
        return {
            ("verificationBehaviour", "hmac-abc"): {"failures": 2, "updatedAt": NOW},
            ("verificationLedger", HER): {"ocr_submissions": 1},
        }.get((collection, doc_id))

    def plans(self, uid, name):
        return {}

    def access_for_flags(self, flag_ids):
        assert flag_ids == ["flag-1"]
        return [{"flagId": "flag-1", "reviewerUid": "reviewer-9", "action": "contact", "at": NOW}]


def test_every_manifest_row_is_exported_or_excluded_with_a_reason():
    assert export_user.check_coverage() == []
    for number, reason in export_user.EXPORT_EXCLUSIONS.items():
        assert reason.strip(), number
    numbers = {r.number for r in manifest.ROWS}
    assert set(export_user.SECTIONS) | set(export_user.EXPORT_EXCLUSIONS) == numbers
    assert not set(export_user.SECTIONS) & set(export_user.EXPORT_EXCLUSIONS)


def test_a_new_row_without_a_decision_is_caught():
    rows = list(manifest.ROWS) + [manifest.Row(99, "newCollection/{uid}", "recursive")]
    assert export_user.check_coverage(rows) == [99]


def test_the_export_has_the_promised_shape():
    export = export_user.build_export(HER, FakeReader(), "ar", NOW)
    assert export["schema"] == "ownhub.export/1"
    assert export["language"] == "ar"
    assert export["generatedAt"] == NOW.isoformat()
    for name, body in export["sections"].items():
        assert body["source"], name
        assert body["retention"], name
    assert "labels_ar" in export
    json.dumps(export, ensure_ascii=False)


def test_it_holds_her_data_and_names_no_reviewer_and_no_code():
    export = export_user.build_export(HER, FakeReader(), "en", NOW)
    text = json.dumps(export)
    sections = export["sections"]
    assert sections["account"]["data"]["phoneNumber"] == "+201012345678"
    assert sections["identityCode"]["data"] == {"state": "active"}
    assert "hmac-abc" not in text, "the keyed ID code itself is never exported"
    assert "reviewer-9" not in text, "a reviewer is 'a reviewer'"
    assert sections["reviewAccess"]["data"]["entries"][0]["by"] == "a reviewer"
    assert sections["fraudSignals"]["data"]["failedAttempts"]["failures"] == 2
    assert "pepper_version" not in text and "provider_ids" not in text
    assert sections["healthCloud"]["data"]["profile"]["lifeStage"] == "pregnant"
    assert "lifeStage" not in sections["settings"]["data"]["user"]["profile"]
    assert OTHER not in text


def test_the_summary_is_readable_and_runs_nothing():
    for lang in ("en", "ar"):
        export = export_user.build_export(HER, FakeReader(), lang, NOW)
        page = export_user.summary_html(export)
        assert "<script" not in page.lower()
        assert f'lang="{lang}"' in page
        assert ('dir="rtl"' in page) == (lang == "ar")
        assert "—" not in page


def test_files_are_written_once_and_private(tmp_path):
    export = export_user.build_export(HER, FakeReader(), "en", NOW)
    folder = tmp_path / "case-1"
    data_path, summary_path = export_user.write_files(export, str(folder))
    assert data_path.endswith("ownhub-data-2026-10-06.json")
    assert summary_path.endswith("summary-en.html")
    import os
    import stat

    assert stat.S_IMODE(os.stat(data_path).st_mode) == 0o600
    try:
        export_user.write_files(export, str(folder))
    except FileExistsError:
        pass
    else:
        raise AssertionError("an existing folder must not be reused")
