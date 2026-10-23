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

    def event_seats(self, uid):
        return {"event-1": {"uid": uid, "joinedAt": NOW, "status": "registered"}}

    def coaching(self, uid):
        return {
            "application": {"status": "approved", "personal": {"fullName": "Her Name"}},
            "coach": {"displayName": "Coach Her"},
            "packages": {"p1": {"title": "Eight weeks"}},
            "drafts": {"d1": {"name": "Plan"}},
            "media": {"m1": {"kind": "photo"}},
            "invites": {"CODE2345": {"coachUid": uid}},
            "asClient": {"sub-1": {"clientUid": uid, "coachUid": "coach-9", "intake": {"goal": "strength"}}},
            "asCoach": {"sub-2": {"coachUid": uid}},
            "messages": {"rel/m1": {"senderUid": uid, "text": "hello"}},
            "private": {"account": {"payoutState": "none"}},
            "receipts": {},
        }

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
    assert sections["events"]["data"]["event-1"]["status"] == "registered"


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


def test_the_coaching_section_holds_her_application_coaching_and_messages():
    export = export_user.build_export(HER, FakeReader(), "en", NOW)
    coaching = export["sections"]["coaching"]
    assert coaching["source"] == [47, 48, 49, 55, 56, 57, 58, 59]
    data = coaching["data"]
    assert data["application"]["status"] == "approved"
    assert data["asClient"]["sub-1"]["intake"] == {"goal": "strength"}
    assert data["messages"]["rel/m1"]["text"] == "hello"
    assert data["packages"]["p1"]["title"] == "Eight weeks"
    assert data["media"]["m1"]["kind"] == "photo"
    assert data["inviteCodes"]["CODE2345"]["coachUid"] == HER
    assert data["asCoach"]["sub-2"] == {"coachUid": HER}


def test_the_live_reader_keeps_a_clients_form_out_of_the_coachs_copy():
    from tests import fake_firestore

    db = fake_firestore.FakeFirestore()
    db.docs.update(
        {
            f"subscriptions/s1": {"clientUid": HER, "coachUid": "coach-9", "intake": {"goal": "strength"}},
            f"subscriptions/s2": {"clientUid": OTHER, "coachUid": HER, "relId": "r2", "intake": {"goal": "x"}, "status": "active"},
            f"relationships/{HER}__{OTHER}": {"coachUid": HER, "clientUid": OTHER},
            f"relationships/{HER}__{OTHER}/messages/m1": {"senderUid": HER, "text": "mine"},
            f"relationships/{HER}__{OTHER}/messages/m2": {"senderUid": OTHER, "text": "hers"},
            f"coachPrivate/{HER}": {"payoutState": "none"},
            f"coachPrivate/{HER}/prices/p1": {"coachPriceEgp": 500},
            f"coachApplications/{HER}": {"status": "approved"},
            f"coaches/{HER}": {"displayName": "H"},
            f"coaches/{HER}/packages/p1": {"title": "T"},
            f"coaches/{HER}/media/m1": {"kind": "photo"},
        }
    )
    got = export_user.FirestoreReader(db).coaching(HER)
    assert got["asClient"]["s1"]["intake"] == {"goal": "strength"}
    assert got["asCoach"]["s2"] == {"coachUid": HER, "status": "active"}
    assert got["messages"] == {f"{HER}__{OTHER}/m1": {"senderUid": HER, "text": "mine"}}
    assert got["private"]["prices/p1"] == {"coachPriceEgp": 500}
    assert got["application"] == {"status": "approved"}
    assert got["packages"] == {"p1": {"title": "T"}}
    assert got["media"] == {"m1": {"kind": "photo"}}
