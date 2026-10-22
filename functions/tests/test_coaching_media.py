"""Portfolio photos: what a coach adds, what a reviewer decides, and what
becomes public (nothing before an approval)."""

from __future__ import annotations

import datetime as dt

import pytest

from coaching import errors, media
from console import access
from tests import fake_firestore
from tests.coaching_helpers import Pushes, _txn, refusal  # noqa: F401
from tests.fake_blobs import FakeBlobs

NOW = dt.datetime(2026, 10, 22, 12, tzinfo=dt.timezone.utc)
UID = "coach-1"
OTHER = "coach-2"
STAFF = "staff-1"
BASE = f"coach-docs/{UID}/"


class Reencode:
    """Records every image it was asked to clean; the output is marked."""

    def __init__(self, fail_on=None):
        self.calls = []
        self.fail_on = fail_on

    def __call__(self, raw):
        self.calls.append(raw)
        if raw == self.fail_on:
            raise ValueError("not an image")
        return b"clean:" + raw


@pytest.fixture
def db():
    fs = fake_firestore.FakeFirestore()
    for uid, name in ((UID, "Mona"), (OTHER, "Dina")):
        fs.docs[f"coachPrivate/{uid}"] = {"suspended": False}
        fs.docs[f"coaches/{uid}"] = {"displayName": name, "published": True}
    return fs


@pytest.fixture
def blobs():
    b = FakeBlobs()
    for path in (
        BASE + "transformations/b1.jpg", BASE + "transformations/a1.jpg",
        BASE + "testimonials/s1.jpg", BASE + "photo/me.jpg", BASE + "gallery/g1.jpg",
        f"coach-docs/{OTHER}/gallery/g2.jpg",
    ):
        b.put(path, path.encode(), "image/jpeg")
    return b


def transformation(**over):
    data = {
        "kind": "transformation", "beforePath": BASE + "transformations/b1.jpg",
        "afterPath": BASE + "transformations/a1.jpg", "weeks": 12, "note": "Three days a week",
        "clientConsentPublic": True,
    }
    data.update(over)
    return data


def feedback(**over):
    data = {"kind": "feedback", "text": "She changed how I train.", "from": "Salma"}
    data.update(over)
    return data


def photo(**over):
    data = {"kind": "photo", "imagePath": BASE + "gallery/g1.jpg", "caption": "At the studio"}
    data.update(over)
    return data


def add(db, blobs, data, *, uid=UID, live=True, coach_v="active", now=NOW):
    return media.add(db, uid, data, live=live, coach_v=coach_v, blobs=blobs, reencode=Reencode(), now=now)


def doc(db, media_id, uid=UID):
    return db.docs[f"coaches/{uid}/media/{media_id}"]


def decide(db, blobs, media_id, decision="approve", *, coach=UID, actor=STAFF, reason=None, reencode=None, push=None):
    data = {"coachUid": coach, "mediaId": media_id, "decision": decision}
    if reason:
        data["reason"] = reason
    return media.decide(
        db, actor, data, blobs=blobs, reencode=reencode or Reencode(),
        notify=push if push is not None else Pushes(), now=NOW,
    )


# ----------------------------------------------------------------------- add


def test_a_transformation_is_stored_pending_with_the_consent_and_nothing_public(db, blobs):
    out = add(db, blobs, transformation())
    assert out["status"] == "pending"
    row = doc(db, out["mediaId"])
    assert row["status"] == "pending" and row["kind"] == "transformation"
    assert row["beforePath"] == BASE + "transformations/b1.jpg"
    assert row["weeks"] == 12 and row["note"] == "Three days a week"
    assert row["consent"] == {"at": NOW, "termsVersion": 1}
    assert row["createdAt"] == NOW and row["coachUid"] == UID
    assert "publicPaths" not in row
    assert not any(p.startswith("coach-public/") for p in blobs.objects)


def test_a_transformation_without_the_clients_agreement_is_refused(db, blobs):
    for bad in (False, None, "yes", 1):
        assert refusal(lambda: add(db, blobs, transformation(clientConsentPublic=bad))) == (
            errors.INVALID, errors.BAD_REQUEST)
    assert not any(k.startswith(f"coaches/{UID}/media/") for k in db.docs)


@pytest.mark.parametrize("weeks", [0, 105, -1, "12", 12.5, True])
def test_transformation_weeks_are_one_to_one_hundred_four(db, blobs, weeks):
    assert refusal(lambda: add(db, blobs, transformation(weeks=weeks)))[0] == errors.INVALID


def test_transformation_weeks_edges_and_note_limit(db, blobs):
    add(db, blobs, transformation(weeks=1, note=""))
    add(db, blobs, transformation(weeks=104, note="n" * 300))
    assert refusal(lambda: add(db, blobs, transformation(note="n" * 301)))[0] == errors.INVALID


def test_a_transformation_file_must_sit_in_her_transformations_folder_and_exist(db, blobs):
    for path in (
        BASE + "photo/me.jpg",
        f"coach-docs/{OTHER}/transformations/b1.jpg",
        BASE + "transformations/../photo/me.jpg",
        BASE + "transformations/sub/b1.jpg",
        BASE + "transformations/missing.jpg",
        "",
    ):
        got = refusal(lambda: add(db, blobs, transformation(beforePath=path)))
        assert got[0] == errors.INVALID, path
        got = refusal(lambda: add(db, blobs, transformation(afterPath=path)))
        assert got[0] == errors.INVALID, path
    assert refusal(lambda: add(db, blobs, transformation(beforePath=BASE + "transformations/missing.jpg"))) == (
        errors.INVALID, errors.FILE_NOT_UPLOADED)


def test_feedback_with_and_without_a_screenshot(db, blobs):
    plain = add(db, blobs, feedback())
    assert doc(db, plain["mediaId"])["imagePath"] is None
    shot = add(db, blobs, feedback(imagePath=BASE + "testimonials/s1.jpg"))
    row = doc(db, shot["mediaId"])
    assert row["imagePath"] == BASE + "testimonials/s1.jpg" and row["status"] == "pending"
    assert "consent" not in row


@pytest.mark.parametrize("text,sender", [("short", "Salma"), ("x" * 601, "Salma"), ("Long enough text here", ""),
                                         ("Long enough text here", "n" * 41), (None, "Salma"), (5, "Salma")])
def test_feedback_text_and_name_limits(db, blobs, text, sender):
    assert refusal(lambda: add(db, blobs, feedback(text=text, **{"from": sender})))[0] == errors.INVALID


def test_feedback_limit_edges_pass(db, blobs):
    add(db, blobs, feedback(text="x" * 10, **{"from": "a"}))
    add(db, blobs, feedback(text="x" * 600, **{"from": "n" * 40}))


def test_feedback_image_must_be_in_her_testimonials_folder(db, blobs):
    got = refusal(lambda: add(db, blobs, feedback(imagePath=BASE + "gallery/g1.jpg")))
    assert got == (errors.INVALID, errors.FILE_NOT_UPLOADED)


def test_a_gallery_or_profile_photo_is_accepted_with_a_caption(db, blobs):
    one = add(db, blobs, photo())
    assert doc(db, one["mediaId"])["caption"] == "At the studio"
    two = add(db, blobs, photo(imagePath=BASE + "photo/me.jpg", caption=""))
    assert doc(db, two["mediaId"])["kind"] == "photo"


def test_photo_caption_limit_and_folder(db, blobs):
    add(db, blobs, photo(caption="c" * 120))
    assert refusal(lambda: add(db, blobs, photo(caption="c" * 121)))[0] == errors.INVALID
    assert refusal(lambda: add(db, blobs, photo(imagePath=BASE + "transformations/b1.jpg")))[1] == errors.FILE_NOT_UPLOADED
    assert refusal(lambda: add(db, blobs, photo(imagePath=f"coach-docs/{OTHER}/gallery/g2.jpg")))[1] == errors.FILE_NOT_UPLOADED


def test_an_unknown_kind_is_refused(db, blobs):
    for kind in ("video", None, 3, ""):
        assert refusal(lambda: add(db, blobs, {"kind": kind}))[0] == errors.INVALID


def test_add_needs_the_switch_and_an_active_coach(db, blobs):
    assert refusal(lambda: add(db, blobs, photo(), live=False)) == (errors.PRECONDITION, errors.COACH_APP_CLOSED)
    assert refusal(lambda: add(db, blobs, photo(), coach_v=None)) == (errors.PERMISSION, errors.NOT_A_COACH)
    assert refusal(lambda: add(db, blobs, photo(), coach_v="suspended")) == (errors.PERMISSION, errors.COACH_SUSPENDED)
    db.docs[f"coachPrivate/{UID}"]["suspended"] = True
    assert refusal(lambda: add(db, blobs, photo())) == (errors.PERMISSION, errors.COACH_SUSPENDED)
    del db.docs[f"coachPrivate/{UID}"]
    assert refusal(lambda: add(db, blobs, photo())) == (errors.PERMISSION, errors.NOT_A_COACH)
    assert not any("/media/" in k for k in db.docs)


def test_a_coach_holds_at_most_thirty_items(db, blobs):
    for _ in range(30):
        add(db, blobs, photo())
    assert refusal(lambda: add(db, blobs, photo())) == (errors.EXHAUSTED, "too_many_media")
    # Another coach's count is her own.
    blobs.put(f"coach-docs/{OTHER}/gallery/g2.jpg")
    add(db, blobs, photo(imagePath=f"coach-docs/{OTHER}/gallery/g2.jpg"), uid=OTHER)


def test_add_does_not_clean_or_copy_anything_yet(db, blobs):
    clean = Reencode()
    media.add(db, UID, transformation(), live=True, coach_v="active", blobs=blobs, reencode=clean, now=NOW)
    assert clean.calls == [] and blobs.deleted == []


# -------------------------------------------------------------------- remove


def test_remove_deletes_the_doc_and_the_public_files(db, blobs):
    made = add(db, blobs, transformation())["mediaId"]
    decide(db, blobs, made)
    public = list(doc(db, made)["publicPaths"].values())
    assert public and all(p in blobs.objects for p in public)
    out = media.remove(db, UID, {"mediaId": made}, live=True, coach_v="active", blobs=blobs, now=NOW)
    assert out == {"removed": True}
    assert f"coaches/{UID}/media/{made}" not in db.docs
    assert all(p not in blobs.objects for p in public)


def test_remove_of_a_pending_item_touches_no_public_file(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    media.remove(db, UID, {"mediaId": made}, live=True, coach_v="active", blobs=blobs, now=NOW)
    assert f"coaches/{UID}/media/{made}" not in db.docs
    assert blobs.deleted == [BASE + "gallery/g1.jpg"]  # her own private original goes with it


def test_remove_is_for_her_own_items_only(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    got = refusal(lambda: media.remove(db, OTHER, {"mediaId": made}, live=True, coach_v="active", blobs=blobs, now=NOW))
    assert got == (errors.NOT_FOUND, "media_not_found")
    assert f"coaches/{UID}/media/{made}" in db.docs
    assert refusal(lambda: media.remove(db, UID, {"mediaId": "nope"}, live=True, coach_v="active", blobs=blobs, now=NOW))[1] == "media_not_found"
    assert refusal(lambda: media.remove(db, UID, {}, live=True, coach_v="active", blobs=blobs, now=NOW))[0] == errors.INVALID


def test_remove_needs_the_switch_and_a_coach_but_a_suspended_one_may_take_photos_down(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    args = dict(blobs=blobs, now=NOW)
    assert refusal(lambda: media.remove(db, UID, {"mediaId": made}, live=False, coach_v="active", **args))[1] == errors.COACH_APP_CLOSED
    assert refusal(lambda: media.remove(db, UID, {"mediaId": made}, live=True, coach_v=None, **args))[1] == errors.NOT_A_COACH
    media.remove(db, UID, {"mediaId": made}, live=True, coach_v="suspended", **args)
    assert f"coaches/{UID}/media/{made}" not in db.docs


def test_a_file_that_cannot_be_deleted_keeps_the_item_so_she_can_retry(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    decide(db, blobs, made)

    def broken(path):
        raise OSError("down")

    blobs.delete = broken
    with pytest.raises(OSError):
        media.remove(db, UID, {"mediaId": made}, live=True, coach_v="active", blobs=blobs, now=NOW)
    assert f"coaches/{UID}/media/{made}" in db.docs


# ------------------------------------------------------------------- consent


def application():
    return {
        "testimonials": [
            {"text": "She changed how I train and eat.", "from": "Salma", "source": "whatsapp",
             "imagePath": BASE + "testimonials/s1.jpg"},
            {"text": "Patient, clear and kind to me.", "from": "Nour", "source": "inPerson", "imagePath": None},
        ],
        "transformations": [
            {"beforePath": BASE + "transformations/b1.jpg", "afterPath": BASE + "transformations/a1.jpg",
             "weeks": 12, "note": "Three days a week", "clientConsent": True},
        ],
    }


def test_seed_makes_a_consent_waiting_transformation_and_pending_feedback_with_an_image(db):
    assert media.seed_from_application(db, UID, application(), now=NOW) == 2
    rows = {k: v for k, v in db.docs.items() if k.startswith(f"coaches/{UID}/media/")}
    assert len(rows) == 2
    t = db.docs[f"coaches/{UID}/media/app-t0"]
    assert t["status"] == "needsConsent" and t["clientConsentPublic"] is False
    assert "consent" not in t and t["weeks"] == 12 and t["coachUid"] == UID
    f = db.docs[f"coaches/{UID}/media/app-f0"]
    assert f["status"] == "pending" and f["imagePath"] == BASE + "testimonials/s1.jpg"
    assert all("publicPaths" not in r for r in rows.values())


def test_seed_twice_changes_nothing_and_keeps_a_decided_item(db, blobs):
    media.seed_from_application(db, UID, application(), now=NOW)
    decide(db, blobs, "app-f0", "reject", reason="unclear")
    assert media.seed_from_application(db, UID, application(), now=NOW + dt.timedelta(days=1)) == 0
    assert db.docs[f"coaches/{UID}/media/app-f0"]["status"] == "rejected"
    assert db.docs[f"coaches/{UID}/media/app-t0"]["createdAt"] == NOW


def test_seed_with_nothing_to_turn_into_media(db):
    assert media.seed_from_application(db, UID, {"testimonials": [{"text": "t" * 12, "from": "A", "imagePath": None}],
                                                 "transformations": []}, now=NOW) == 0


def test_a_waiting_transformation_cannot_be_decided_until_she_confirms(db, blobs):
    media.seed_from_application(db, UID, application(), now=NOW)
    assert refusal(lambda: decide(db, blobs, "app-t0")) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert not any(p.startswith("coach-public/") for p in blobs.objects)
    listed = media.list_for_review(db, STAFF, {}, now=NOW)
    assert [i["mediaId"] for i in listed["items"]] == ["app-f0"]


def confirm(db, media_id, *, uid=UID, live=True, coach_v="active"):
    return media.confirm_consent(db, uid, {"mediaId": media_id}, live=live, coach_v=coach_v, now=NOW)


def test_confirming_consent_stores_the_tick_and_moves_it_to_review(db, blobs):
    media.seed_from_application(db, UID, application(), now=NOW)
    later = NOW + dt.timedelta(days=2)
    media.confirm_consent(db, UID, {"mediaId": "app-t0"}, live=True, coach_v="active", now=later)
    row = doc(db, "app-t0")
    assert row["status"] == "pending" and row["clientConsentPublic"] is True
    assert row["consent"] == {"at": later, "termsVersion": 1}
    assert decide(db, blobs, "app-t0") == {"status": "approved"}


def test_confirm_consent_refusals(db):
    media.seed_from_application(db, UID, application(), now=NOW)
    assert refusal(lambda: confirm(db, "app-t0", uid=OTHER))[1] == "media_not_found"
    assert refusal(lambda: confirm(db, "nope"))[1] == "media_not_found"
    assert refusal(lambda: confirm(db, "app-f0")) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert refusal(lambda: confirm(db, "app-t0", live=False))[1] == errors.COACH_APP_CLOSED
    assert refusal(lambda: confirm(db, "app-t0", coach_v=None))[1] == errors.NOT_A_COACH
    assert refusal(lambda: confirm(db, "app-t0", coach_v="suspended"))[1] == errors.COACH_SUSPENDED
    assert doc(db, "app-t0")["status"] == "needsConsent"
    confirm(db, "app-t0")
    assert refusal(lambda: confirm(db, "app-t0")) == (errors.PRECONDITION, errors.WRONG_STATUS)


# -------------------------------------------------------------------- review


def test_the_queue_is_pending_only_oldest_first_with_the_coach_name_and_one_log_line(db, blobs):
    first = add(db, blobs, photo(), now=NOW)["mediaId"]
    second = add(db, blobs, feedback(), uid=UID, now=NOW + dt.timedelta(minutes=5))["mediaId"]
    blobs.put(f"coach-docs/{OTHER}/gallery/g2.jpg")
    third = add(db, blobs, photo(imagePath=f"coach-docs/{OTHER}/gallery/g2.jpg"), uid=OTHER,
                now=NOW + dt.timedelta(minutes=1))["mediaId"]
    decide(db, blobs, first)
    out = media.list_for_review(db, STAFF, {}, now=NOW)
    assert [i["mediaId"] for i in out["items"]] == [third, second]
    assert [i["coachName"] for i in out["items"]] == ["Dina", "Mona"]
    assert out["items"][0]["createdAt"] == NOW.replace(minute=1).isoformat()
    assert out["next"] is None
    lines = [v for k, v in db.docs.items() if k.startswith(access.COLLECTION + "/") and v["action"] == "coaching.media.list"]
    assert len(lines) == 1
    assert lines[0]["admin"] == access.short_ref(STAFF) and STAFF not in str(lines[0])


def test_the_queue_pages_with_a_cursor(db, blobs):
    ids = [add(db, blobs, photo(), now=NOW + dt.timedelta(minutes=i))["mediaId"] for i in range(27)]
    page1 = media.list_for_review(db, STAFF, {}, now=NOW)
    assert [i["mediaId"] for i in page1["items"]] == ids[:25] and page1["next"] == f"{UID}/{ids[24]}"
    page2 = media.list_for_review(db, STAFF, {"after": page1["next"]}, now=NOW)
    assert [i["mediaId"] for i in page2["items"]] == ids[25:] and page2["next"] is None


def test_the_queue_can_show_decided_items_and_refuses_bad_input(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    decide(db, blobs, made, "reject", reason="unclear")
    out = media.list_for_review(db, STAFF, {"status": "rejected"}, now=NOW)
    assert [i["mediaId"] for i in out["items"]] == [made]
    for data in ({"status": "bogus"}, {"after": "no-slash"}, {"after": "a/b/c"}, {"after": 5}):
        assert refusal(lambda: media.list_for_review(db, STAFF, data, now=NOW))[0] == errors.INVALID
    assert media.list_for_review(db, STAFF, {"after": "gone/gone"}, now=NOW)["items"] == []


# -------------------------------------------------------------------- decide


def test_approval_cleans_every_image_and_publishes_only_the_clean_copies(db, blobs):
    made = add(db, blobs, transformation())["mediaId"]
    clean, push = Reencode(), Pushes()
    out = decide(db, blobs, made, reencode=clean, push=push)
    assert out == {"status": "approved"}
    assert clean.calls == [(BASE + "transformations/b1.jpg").encode(), (BASE + "transformations/a1.jpg").encode()]
    row = doc(db, made)
    assert row["status"] == "approved"
    assert row["publicPaths"] == {
        "before": f"coach-public/{UID}/media/{made}_before.jpg",
        "after": f"coach-public/{UID}/media/{made}_after.jpg",
    }
    assert row["decidedAt"] == NOW and row["decidedBy"] == access.short_ref(STAFF) and STAFF not in str(row)
    assert blobs.read(row["publicPaths"]["before"]) == b"clean:" + (BASE + "transformations/b1.jpg").encode()
    assert blobs.objects[row["publicPaths"]["after"]][1] == "image/jpeg"
    assert push == [(UID, "portfolioDecision")]


def test_feedback_and_photo_publish_an_image_and_a_text_only_feedback_publishes_none(db, blobs):
    shot = add(db, blobs, feedback(imagePath=BASE + "testimonials/s1.jpg"))["mediaId"]
    gal = add(db, blobs, photo())["mediaId"]
    txt = add(db, blobs, feedback())["mediaId"]
    clean = Reencode()
    for made in (shot, gal, txt):
        decide(db, blobs, made, reencode=clean)
    assert len(clean.calls) == 2
    assert doc(db, shot)["publicPaths"] == {"image": f"coach-public/{UID}/media/{shot}_image.jpg"}
    assert doc(db, gal)["publicPaths"] == {"image": f"coach-public/{UID}/media/{gal}_image.jpg"}
    assert doc(db, txt)["publicPaths"] == {} and doc(db, txt)["status"] == "approved"


def test_nothing_is_public_before_an_approval(db, blobs):
    add(db, blobs, transformation())
    add(db, blobs, photo())
    assert not any(p.startswith("coach-public/") for p in blobs.objects)
    assert all("publicPaths" not in v for k, v in db.docs.items() if "/media/" in k)


def test_rejection_leaves_nothing_public_keeps_the_reason_and_tells_the_coach(db, blobs):
    made = add(db, blobs, transformation())["mediaId"]
    clean, push = Reencode(), Pushes()
    out = decide(db, blobs, made, "reject", reason="no_consent", reencode=clean, push=push)
    assert out == {"status": "rejected"}
    row = doc(db, made)
    assert row["status"] == "rejected" and row["reason"] == "no_consent"
    assert "publicPaths" not in row
    assert clean.calls == [] and not any(p.startswith("coach-public/") for p in blobs.objects)
    assert row["decidedBy"] == access.short_ref(STAFF)
    assert push == [(UID, "portfolioDecision")]


def test_a_rejection_needs_one_of_the_listed_reasons(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    for reason in (None, "", "bad", "Unclear", 3):
        data = {"coachUid": UID, "mediaId": made, "decision": "reject", "reason": reason}
        got = refusal(lambda: media.decide(db, STAFF, data, blobs=blobs, reencode=Reencode(), notify=Pushes(), now=NOW))
        assert got[0] == errors.INVALID
    for reason in ("unclear", "not_allowed", "no_consent", "other"):
        blobs.put(BASE + "gallery/g1.jpg", b"again", "image/jpeg")
        item = add(db, blobs, photo())["mediaId"]
        decide(db, blobs, item, "reject", reason=reason)
    assert doc(db, made)["status"] == "pending"


def test_bad_decide_input(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    for data in ({}, {"coachUid": UID, "mediaId": made}, {"coachUid": UID, "mediaId": made, "decision": "maybe"},
                 {"coachUid": UID, "decision": "approve"}, {"mediaId": made, "decision": "approve"}):
        assert refusal(lambda: media.decide(db, STAFF, data, blobs=blobs, reencode=Reencode(), notify=Pushes(), now=NOW))[0] == errors.INVALID
    assert refusal(lambda: decide(db, blobs, "gone"))[1] == "media_not_found"
    assert refusal(lambda: decide(db, blobs, made, coach=OTHER))[1] == "media_not_found"
    assert doc(db, made)["status"] == "pending"


def test_staff_cannot_decide_their_own_items(db, blobs):
    db.docs[f"coachPrivate/{STAFF}"] = {"suspended": False}
    blobs.put(f"coach-docs/{STAFF}/gallery/me.jpg")
    made = add(db, blobs, photo(imagePath=f"coach-docs/{STAFF}/gallery/me.jpg"), uid=STAFF)["mediaId"]
    clean, push = Reencode(), Pushes()
    got = refusal(lambda: decide(db, blobs, made, coach=STAFF, reencode=clean, push=push))
    assert got == (errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    got = refusal(lambda: decide(db, blobs, made, "reject", coach=STAFF, reason="other", push=push))
    assert got == (errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert doc(db, made, STAFF)["status"] == "pending" and clean.calls == [] and push == []
    assert not any(v["action"].startswith("coaching.media") for k, v in db.docs.items() if k.startswith(access.COLLECTION + "/"))


def test_a_decided_item_cannot_be_decided_again(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    decide(db, blobs, made)
    push = Pushes()
    assert refusal(lambda: decide(db, blobs, made, "reject", reason="other", push=push)) == (
        errors.PRECONDITION, errors.WRONG_STATUS)
    assert refusal(lambda: decide(db, blobs, made, push=push))[1] == errors.WRONG_STATUS
    assert doc(db, made)["status"] == "approved" and push == []


def test_an_image_that_cannot_be_cleaned_is_refused_and_leaves_nothing_public(db, blobs):
    made = add(db, blobs, transformation())["mediaId"]
    bad = (BASE + "transformations/a1.jpg").encode()
    push = Pushes()
    got = refusal(lambda: decide(db, blobs, made, reencode=Reencode(fail_on=bad), push=push))
    assert got == (errors.INVALID, errors.IMAGE_INVALID)
    assert doc(db, made)["status"] == "pending" and "publicPaths" not in doc(db, made)
    assert not any(p.startswith("coach-public/") for p in blobs.objects)
    assert push == []


def test_a_decision_that_loses_a_race_leaves_no_public_file(db, blobs):
    made = add(db, blobs, photo())["mediaId"]

    def racing(raw):
        db.docs[f"coaches/{UID}/media/{made}"]["status"] = "rejected"
        return b"clean:" + raw

    got = refusal(lambda: decide(db, blobs, made, reencode=racing))
    assert got == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert not any(p.startswith("coach-public/") for p in blobs.objects)


def test_the_log_line_names_the_action_and_never_a_uid(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    decide(db, blobs, made)
    lines = [v for k, v in db.docs.items() if k.startswith(access.COLLECTION + "/")]
    assert [v["action"] for v in lines] == ["coaching.media.approve"]
    assert UID not in str(lines) and STAFF not in str(lines)


def test_approval_deletes_the_originals_and_their_names(db, blobs):
    # Members can read an approved doc, so it must not name the private files.
    made = add(db, blobs, transformation())["mediaId"]
    decide(db, blobs, made)
    originals = [BASE + "transformations/b1.jpg", BASE + "transformations/a1.jpg"]
    assert all(path not in blobs.objects for path in originals)
    doc = db.document(f"coaches/{UID}/media/{made}").get().to_dict()
    assert doc["beforePath"] is None and doc["afterPath"] is None
    assert doc["publicPaths"]


def test_a_rejection_deletes_the_private_original_she_added(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    decide(db, blobs, made, "reject", reason="unclear")
    assert blobs.deleted == [BASE + "gallery/g1.jpg"]
    assert "imagePath" not in {k: v for k, v in doc(db, made).items() if v}


def test_removing_an_approved_item_deletes_its_public_copy_only(db, blobs):
    made = add(db, blobs, photo())["mediaId"]
    decide(db, blobs, made)
    blobs.deleted.clear()
    media.remove(db, UID, {"mediaId": made}, live=True, coach_v="active", blobs=blobs, now=NOW)
    assert blobs.deleted == [f"coach-public/{UID}/media/{made}_image.jpg"]


def test_files_of_an_item_seeded_from_the_application_survive_every_decision(db, blobs):
    media.seed_from_application(db, UID, application(), now=NOW)
    confirm(db, "app-t0")
    decide(db, blobs, "app-t0")
    decide(db, blobs, "app-f0", "reject", reason="unclear")
    media.remove(db, UID, {"mediaId": "app-f0"}, live=True, coach_v="active", blobs=blobs, now=NOW)
    for path in (BASE + "transformations/b1.jpg", BASE + "transformations/a1.jpg", BASE + "testimonials/s1.jpg"):
        assert path not in blobs.deleted and blobs.exists(path)
