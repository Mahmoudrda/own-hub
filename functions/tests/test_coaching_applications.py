"""Coach applications: what she must send, what a reviewer sees, what an
approval creates, and what stays off the public page."""

from __future__ import annotations

import copy
import datetime as dt

import pytest

from coaching import applications, claims, errors
from console import access
from tests import fake_firestore
from tests.coaching_helpers import Recorder, _txn, refusal  # noqa: F401
from tests.fake_blobs import FakeBlobs

NOW = dt.datetime(2026, 10, 20, 12, tzinfo=dt.timezone.utc)
UID = "coach-1"
STAFF = "staff-1"


def valid(uid=UID, **overrides):
    base = f"coach-docs/{uid}/"
    data = {
        "personal": {
            "fullName": "Mona Hassan Ali",
            "displayName": "Mona",
            "governorate": "cairo",
            "languages": ["ar", "en"],
            "headline": "Strength coach for busy women",
            "photoPath": base + "photo/me.jpg",
        },
        "education": [
            {"degree": "BSc Sports Science", "institution": "Cairo University", "year": 2015, "path": base + "education/deg.jpg"},
            {"degree": "Diploma", "institution": "Nutrition Institute", "year": 2018},
        ],
        "certificates": [
            {"id": "nasm-cpt", "title": "NASM CPT", "issuer": "NASM", "year": 2019, "path": base + "certificates/nasm.pdf", "mime": "application/pdf"},
            {"id": "ces", "title": "Corrective Exercise", "issuer": "NASM", "year": 2021, "path": base + "certificates/ces.jpg", "mime": "image/jpeg"},
        ],
        "specialties": ["strength", "fatLoss"],
        "qualifications": "Eight years training women one to one in Cairo.",
        "yearsExperience": 8,
        "testimonials": [
            {"text": "She changed how I train and eat.", "from": "Salma", "source": "whatsapp", "imagePath": base + "testimonials/s1.jpg"},
            {"text": "Patient, clear and kind to me.", "from": "Nour", "source": "inPerson"},
        ],
        "transformations": [
            {"beforePath": base + "transformations/b1.jpg", "afterPath": base + "transformations/a1.jpg", "weeks": 12, "note": "Three days a week", "clientConsent": True}
        ],
        "approach": {
            "text": "I build every plan around her week, her kitchen and her energy, then adjust it each Sunday.",
            "checkInsPerWeek": 2,
            "replyHours": 12,
            "trainsWhere": ["home", "online"],
        },
        "payout": {"rail": "instapay", "account": "mona.h@instapay", "holderName": "Mona Hassan Ali"},
        "termsVersion": 1,
        "rules": ["accurateInfo", "clientPhotoConsent", "noOffPlatformPayment"],
        "locale": "en",
    }
    data.update(overrides)
    return data


def all_paths(data):
    out = [data["personal"]["photoPath"]]
    out += [r["path"] for r in data["education"] if r.get("path")]
    out += [r["path"] for r in data["certificates"]]
    out += [r["imagePath"] for r in data["testimonials"] if r.get("imagePath")]
    for r in data["transformations"]:
        out += [r["beforePath"], r["afterPath"]]
    return out


@pytest.fixture
def db(monkeypatch):
    fs = fake_firestore.FakeFirestore()
    return fs


@pytest.fixture
def blobs():
    b = FakeBlobs()
    for path in all_paths(valid()):
        b.put(path, b"file", "image/jpeg")
    return b


def submit(db, blobs, data=None, *, uid=UID, live=True, verified=True, coach_v=None, now=NOW, payments_live=True):
    return applications.submit(
        db, uid, valid(uid) if data is None else data,
        live=live, verified=verified, coach_v=coach_v, blobs=blobs, now=now, payments_live=payments_live,
    )


# -------------------------------------------------------------- submit


def test_a_complete_application_is_stored(db, blobs):
    assert submit(db, blobs) == {"status": "submitted", "round": 1}
    doc = db.docs[f"coachApplications/{UID}"]
    assert set(doc) == set(applications.APPLICATION_KEYS)
    assert doc["status"] == "submitted" and doc["round"] == 1
    assert doc["reasons"] == {} and doc["submittedAt"] == NOW
    assert doc["personal"]["fullName"] == "Mona Hassan Ali"
    assert doc["rules"] == ["accurateInfo", "clientPhotoConsent", "noOffPlatformPayment"]
    assert "locale" not in doc


def test_an_application_without_a_payout_account_is_accepted(db, blobs):
    data = valid()
    del data["payout"]
    assert submit(db, blobs, data) == {"status": "submitted", "round": 1}
    assert db.docs[f"coachApplications/{UID}"]["payout"] is None


def test_a_payout_account_that_is_given_is_still_checked(db, blobs):
    data = valid()
    data["payout"]["account"] = "mona"
    assert refusal(lambda: submit(db, blobs, data)) == (errors.INVALID, errors.APPLICATION_INCOMPLETE)
    assert db.docs == {}


def test_the_coach_terms_consent_is_recorded(db, blobs):
    submit(db, blobs)
    assert db.docs[f"users/{UID}/consents/coach-terms-v1"] == {"version": 1, "at": NOW, "locale": "en"}


def test_the_consent_locale_defaults_to_arabic(db, blobs):
    data = valid()
    data["locale"] = "fr"
    submit(db, blobs, data)
    assert db.docs[f"users/{UID}/consents/coach-terms-v1"]["locale"] == "ar"


def test_refused_while_closed(db, blobs):
    assert refusal(lambda: submit(db, blobs, live=False)) == (errors.PRECONDITION, errors.COACH_APP_CLOSED)
    assert db.docs == {}


def test_refused_when_not_verified(db, blobs):
    assert refusal(lambda: submit(db, blobs, verified=False)) == (errors.PERMISSION, errors.NOT_VERIFIED)
    assert db.docs == {}


def test_refused_for_an_active_coach(db, blobs):
    assert refusal(lambda: submit(db, blobs, coach_v="active")) == (errors.PRECONDITION, errors.ALREADY_A_COACH)
    assert db.docs == {}


def test_a_second_application_while_one_is_open_is_refused(db, blobs):
    submit(db, blobs)
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: submit(db, blobs)) == (errors.PRECONDITION, errors.APPLICATION_OPEN)
    assert db.docs == before


def test_an_approved_application_cannot_be_sent_again(db, blobs):
    db.docs[f"coachApplications/{UID}"] = {"status": "approved", "round": 1}
    assert refusal(lambda: submit(db, blobs, coach_v="suspended")) == (errors.PRECONDITION, errors.WRONG_STATUS)


def test_changes_requested_lets_her_send_again_and_the_round_counts_up(db, blobs):
    submit(db, blobs)
    db.docs[f"coachApplications/{UID}"].update(status="needs_changes", decidedAt=NOW, decidedBy="abc", note="x", reasons={"personal": "unclear"})
    later = NOW + dt.timedelta(days=1)
    assert submit(db, blobs, now=later) == {"status": "submitted", "round": 2}
    doc = db.docs[f"coachApplications/{UID}"]
    assert doc["reasons"] == {} and doc["decidedAt"] is None and doc["decidedBy"] is None
    assert doc["submittedAt"] == later


def test_a_rejected_applicant_waits_thirty_days(db, blobs):
    db.docs[f"coachApplications/{UID}"] = {"status": "rejected", "round": 1, "decidedAt": NOW}
    day29 = NOW + dt.timedelta(days=29, hours=23)
    assert refusal(lambda: submit(db, blobs, now=day29)) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert db.docs[f"coachApplications/{UID}"]["status"] == "rejected"
    day30 = NOW + dt.timedelta(days=30)
    assert submit(db, blobs, now=day30) == {"status": "submitted", "round": 2}


def mutate(path_fn):
    data = valid()
    path_fn(data)
    return data


BAD = {
    "no personal": lambda d: d.pop("personal"),
    "short legal name": lambda d: d["personal"].update(fullName="Mo"),
    "short display name": lambda d: d["personal"].update(displayName="M"),
    "long display name": lambda d: d["personal"].update(displayName="x" * 41),
    "unknown governorate": lambda d: d["personal"].update(governorate="atlantis"),
    "no languages": lambda d: d["personal"].update(languages=[]),
    "three languages": lambda d: d["personal"].update(languages=["ar", "en", "fr"]),
    "short headline": lambda d: d["personal"].update(headline="Coach"),
    "no photo": lambda d: d["personal"].pop("photoPath"),
    "no education": lambda d: d.update(education=[]),
    "seven education": lambda d: d.update(education=[d["education"][1]] * 7),
    "education year too old": lambda d: d["education"][1].update(year=1959),
    "education year in the future": lambda d: d["education"][1].update(year=2027),
    "no certificates": lambda d: d.update(certificates=[]),
    "eleven certificates": lambda d: d.update(certificates=[dict(d["certificates"][0], id=f"c{i}") for i in range(11)]),
    "certificate id not a slug": lambda d: d["certificates"][0].update(id="Bad Id"),
    "certificate id repeated": lambda d: d["certificates"][1].update(id="nasm-cpt"),
    "certificate mime": lambda d: d["certificates"][0].update(mime="image/gif"),
    "certificate year": lambda d: d["certificates"][0].update(year="2019"),
    "no specialties": lambda d: d.update(specialties=[]),
    "six specialties": lambda d: d.update(specialties=["strength", "fatLoss", "muscleGain", "beginners", "homeTraining", "mobility"]),
    "unknown specialty": lambda d: d.update(specialties=["yoga"]),
    "repeated specialty": lambda d: d.update(specialties=["strength", "strength"]),
    "short qualifications": lambda d: d.update(qualifications="Coach"),
    "negative years": lambda d: d.update(yearsExperience=-1),
    "years over 50": lambda d: d.update(yearsExperience=51),
    "years as bool": lambda d: d.update(yearsExperience=True),
    "one testimonial": lambda d: d.update(testimonials=d["testimonials"][:1]),
    "testimonial source": lambda d: d["testimonials"][0].update(source="tv"),
    "short testimonial": lambda d: d["testimonials"][0].update(text="Great"),
    "no transformations": lambda d: d.update(transformations=[]),
    "no client consent": lambda d: d["transformations"][0].update(clientConsent=False),
    "consent missing": lambda d: d["transformations"][0].pop("clientConsent"),
    "weeks zero": lambda d: d["transformations"][0].update(weeks=0),
    "weeks 105": lambda d: d["transformations"][0].update(weeks=105),
    "note too long": lambda d: d["transformations"][0].update(note="x" * 301),
    "short approach": lambda d: d["approach"].update(text="Short"),
    "check-ins 8": lambda d: d["approach"].update(checkInsPerWeek=8),
    "reply hours": lambda d: d["approach"].update(replyHours=6),
    "no trains-where": lambda d: d["approach"].update(trainsWhere=[]),
    "bad rail": lambda d: d["payout"].update(rail="paypal"),
    "bad instapay": lambda d: d["payout"].update(account="mona"),
    "bad wallet": lambda d: d["payout"].update(rail="vodafoneCash", account="0121234567"),
    "short holder": lambda d: d["payout"].update(holderName="Mo"),
    "terms version": lambda d: d.update(termsVersion=2),
    "terms as true": lambda d: d.update(termsVersion=True),
    "missing a rule": lambda d: d.update(rules=["accurateInfo", "clientPhotoConsent"]),
    "extra rule": lambda d: d.update(rules=["accurateInfo", "clientPhotoConsent", "noOffPlatformPayment", "x"]),
    "rules repeated": lambda d: d.update(rules=["accurateInfo", "accurateInfo", "noOffPlatformPayment"]),
    "personal not a map": lambda d: d.update(personal="Mona"),
}


@pytest.mark.parametrize("name", sorted(BAD))
def test_a_bad_section_is_incomplete_and_nothing_is_written(db, blobs, name):
    data = valid()
    BAD[name](data)
    assert refusal(lambda: submit(db, blobs, data)) == (errors.INVALID, errors.APPLICATION_INCOMPLETE)
    assert db.docs == {}


def test_the_limits_themselves_are_accepted(db, blobs):
    data = valid()
    data["personal"].update(displayName="x" * 40, headline="h" * 120)
    data["education"][1]["year"] = 1960
    data["certificates"][0]["year"] = NOW.year
    data["transformations"][0].update(weeks=104, note="")
    data["approach"].update(checkInsPerWeek=0, replyHours=48, trainsWhere=["home", "gym", "online"])
    data["yearsExperience"] = 0
    assert submit(db, blobs, data)["round"] == 1


FILE_CASES = {
    "photo": lambda d, b: d["personal"].update(photoPath=b + "photo/other.jpg"),
    "photo in the wrong folder": lambda d, b: d["personal"].update(photoPath=b + "education/me.jpg"),
    "someone else's prefix": lambda d, b: d["personal"].update(photoPath="coach-docs/other/photo/me.jpg"),
    "certificate in photo folder": lambda d, b: d["certificates"][0].update(path=b + "photo/me.jpg"),
    "traversal": lambda d, b: d["personal"].update(photoPath=b + "photo/../education/deg.jpg"),
    "nested": lambda d, b: d["personal"].update(photoPath=b + "photo/x/me.jpg"),
    "education file": lambda d, b: d["education"][0].update(path=b + "education/missing.jpg"),
    "testimonial image": lambda d, b: d["testimonials"][0].update(imagePath=b + "testimonials/missing.jpg"),
    "before photo": lambda d, b: d["transformations"][0].update(beforePath=b + "transformations/missing.jpg"),
    "after photo": lambda d, b: d["transformations"][0].update(afterPath=b + "certificates/a1.jpg"),
}


@pytest.mark.parametrize("name", sorted(FILE_CASES))
def test_a_file_that_is_not_hers_or_not_there_is_refused(db, blobs, name):
    data = valid()
    FILE_CASES[name](data, f"coach-docs/{UID}/")
    assert refusal(lambda: submit(db, blobs, data)) == (errors.INVALID, errors.FILE_NOT_UPLOADED)
    assert db.docs == {}


def test_optional_files_may_be_left_out(db, blobs):
    data = valid()
    for row in data["education"]:
        row.pop("path", None)
    for row in data["testimonials"]:
        row.pop("imagePath", None)
    assert submit(db, blobs, data)["round"] == 1


# -------------------------------------------------------------- list


def seed_applications(db, n, status="submitted"):
    for i in range(n):
        db.docs[f"coachApplications/u{i:03d}"] = {
            "status": status, "round": 1,
            "submittedAt": NOW + dt.timedelta(minutes=n - i),
            "personal": {"fullName": f"Name {i}"},
        }


def access_lines(db):
    return [d for p, d in db.docs.items() if p.startswith(access.COLLECTION + "/")]


def test_the_queue_pages_through_equal_times_without_a_gap_or_a_repeat(db):
    for i in range(60):
        db.docs[f"coachApplications/u{i:03d}"] = {"status": "submitted", "round": 1, "submittedAt": NOW}
    seen, after = [], None
    for _ in range(3):
        page = applications.list_for_review(db, STAFF, {"after": after} if after else {}, now=NOW)
        seen += [item["uid"] for item in page["items"]]
        after = page["next"]
    assert seen == [f"u{i:03d}" for i in range(60)] and after is None


def test_the_queue_reads_one_page_and_one_more_not_the_history(db, monkeypatch):
    seed_applications(db, 80)
    streamed = []
    real = fake_firestore.CollectionRef.stream

    def counting(self, transaction=None):
        rows = list(real(self, transaction))
        if self.path == "coachApplications":
            streamed.append(len(rows))
        return iter(rows)

    monkeypatch.setattr(fake_firestore.CollectionRef, "stream", counting)
    applications.list_for_review(db, STAFF, {}, now=NOW)
    assert streamed == [applications.PAGE_SIZE + 1]


def test_the_queue_is_oldest_first_and_pages_of_25(db):
    seed_applications(db, 30)
    first = applications.list_for_review(db, STAFF, {}, now=NOW)
    assert len(first["items"]) == 25
    assert first["items"][0]["uid"] == "u029"
    assert first["items"][0]["personal"]["fullName"] == "Name 29"
    assert first["next"] == first["items"][-1]["uid"]
    second = applications.list_for_review(db, STAFF, {"after": first["next"]}, now=NOW)
    assert [i["uid"] for i in second["items"]] == [f"u{i:03d}" for i in range(4, -1, -1)]
    assert second["next"] is None


def test_a_page_of_exactly_25_has_no_next(db):
    seed_applications(db, 25)
    assert applications.list_for_review(db, STAFF, {}, now=NOW)["next"] is None


def test_the_status_filter(db):
    seed_applications(db, 2)
    db.docs["coachApplications/z"] = {"status": "needs_changes", "submittedAt": NOW}
    only = applications.list_for_review(db, STAFF, {"status": "needs_changes"}, now=NOW)
    assert [i["uid"] for i in only["items"]] == ["z"]
    assert len(applications.list_for_review(db, STAFF, {}, now=NOW)["items"]) == 2


def test_an_unknown_status_is_refused_without_a_log_line(db):
    assert refusal(lambda: applications.list_for_review(db, STAFF, {"status": "open"}, now=NOW))[1] == errors.BAD_REQUEST
    assert access_lines(db) == []


def test_listing_leaves_one_access_line_with_no_uid(db):
    seed_applications(db, 3)
    applications.list_for_review(db, STAFF, {}, now=NOW)
    lines = access_lines(db)
    assert len(lines) == 1
    assert lines[0]["admin"] == access.short_ref(STAFF)
    assert lines[0]["action"].startswith("coaching.")
    assert STAFF not in str(lines[0])


# -------------------------------------------------------------- decide


def decide(db, blobs, data, rec=None, now=NOW):
    rec = rec or Recorder()
    out = applications.decide(
        db, STAFF, data, merge_claims=rec.merge, blobs=blobs, notify=rec.notify,
        reencode=lambda raw, long_side=None: (b"thumb:" if long_side else b"jpeg:") + raw, now=now,
    )
    return out, rec


def approve_data(**overrides):
    data = {"uid": UID, "decision": "approve", "checkedCertificates": ["nasm-cpt"], "note": "Looks right"}
    data.update(overrides)
    return data


@pytest.fixture
def submitted(db, blobs):
    submit(db, blobs)
    return db


def test_approving_without_a_payout_leaves_the_state_none_and_no_account(db, blobs):
    data = valid()
    del data["payout"]
    submit(db, blobs, data)
    decide(db, blobs, approve_data())
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["payoutState"] == "none" and "payout" not in private


def test_approving_builds_the_public_page_and_the_private_side(submitted, blobs):
    db = submitted
    db.docs[f"users/{UID}"] = {"profile": {"firstName": "Mona"}, "roles": {"held": ["trainee"], "chosen": "trainee"}}
    out, rec = decide(db, blobs, approve_data())
    assert out == {"status": "approved"}
    assert rec.claims == [(UID, {"coachV": "active"})]
    assert rec.notes == [(UID, "coachDecision")]

    coach = db.docs[f"coaches/{UID}"]
    assert set(coach) == set(applications.COACH_PUBLIC_KEYS)
    assert coach["displayName"] == "Mona" and coach["photoUrl"] == f"coach-public/{UID}/photo.jpg"
    assert coach["certificates"] == [{"title": "NASM CPT", "issuer": "NASM", "year": 2019}]
    assert coach["testimonials"] == [{"text": "She changed how I train and eat.", "from": "Salma"}, {"text": "Patient, clear and kind to me.", "from": "Nour"}]
    assert coach["badges"] == ["verifiedCoach", "certificatesChecked", "yearsCoaching"]
    assert coach["stats"] == {"clientsCoached": 0, "plansShared": 0, "sessionsDone": 0}
    assert coach["fromPriceEgp"] is None and coach["fromMonthlyEgp"] is None and coach["published"] is False
    assert coach["acceptingClients"] is True and coach["autoAccept"] is True
    assert coach["maxActiveClients"] == 15 and coach["activeClients"] == 0
    assert coach["replyHours"] == 12 and coach["trainsWhere"] == ["home", "online"]
    assert coach["approach"]["checkInsPerWeek"] == 2 and coach["approach"]["text"].startswith("I build")

    private = db.docs[f"coachPrivate/{UID}"]
    assert private["fullName"] == "Mona Hassan Ali"
    assert private["payout"] == {"rail": "instapay", "account": "mona.h@instapay", "holderName": "Mona Hassan Ali"}
    assert private["payoutState"] == "pending" and private["owedEgp"] == 0 and private["paidEgp"] == 0

    assert db.docs[f"users/{UID}"]["roles"]["held"] == ["trainee", "coach"]
    assert db.docs[f"users/{UID}"]["roles"]["chosen"] == "trainee"
    assert db.docs[f"users/{UID}"]["profile"] == {"firstName": "Mona"}

    app = db.docs[f"coachApplications/{UID}"]
    assert app["status"] == "approved" and app["decidedAt"] == NOW
    assert app["decidedBy"] == access.short_ref(STAFF) and UID not in app["decidedBy"]
    assert blobs.objects[f"coach-public/{UID}/photo.jpg"] == (b"jpeg:file", "image/jpeg")
    assert blobs.objects[f"coach-public/{UID}/photo_s.jpg"] == (b"thumb:file", "image/jpeg")


def test_the_public_page_never_holds_private_fields(submitted, blobs):
    decide(submitted, blobs, approve_data(checkedCertificates=["nasm-cpt", "ces"]))
    public = repr(submitted.docs[f"coaches/{UID}"])
    for secret in ("Mona Hassan Ali", "mona.h@instapay", "payout", "fullName", "coachPrice",
                   "transformations", "b1.jpg", "s1.jpg", "coach-docs", "nasm.pdf", "imagePath", "source"):
        assert secret not in public


def test_only_checked_certificates_go_public(submitted, blobs):
    decide(submitted, blobs, approve_data(checkedCertificates=["ces"]))
    assert [c["title"] for c in submitted.docs[f"coaches/{UID}"]["certificates"]] == ["Corrective Exercise"]


def test_no_years_badge_for_a_newcomer(db, blobs):
    data = valid()
    data["yearsExperience"] = 0
    submit(db, blobs, data)
    decide(db, blobs, approve_data())
    assert db.docs[f"coaches/{UID}"]["badges"] == ["verifiedCoach", "certificatesChecked"]


@pytest.mark.parametrize("checked", [None, [], "nasm-cpt", ["unknown"], ["nasm-cpt", "nasm-cpt"], [["nasm-cpt"]]])
def test_approval_needs_real_checked_certificates(submitted, blobs, checked):
    before = copy.deepcopy(submitted.docs)
    rec = Recorder()
    assert refusal(lambda: decide(submitted, blobs, approve_data(checkedCertificates=checked), rec))[1] == errors.BAD_REQUEST
    assert submitted.docs == before and rec.claims == [] and rec.notes == []


@pytest.mark.parametrize("decision, status", [("needs_changes", "needs_changes"), ("reject", "rejected")])
def test_changes_and_rejection_keep_the_application_and_tell_her(submitted, blobs, decision, status):
    data = {"uid": UID, "decision": decision, "reasons": {"certificates": "unverifiable", "personal": "unclear"}, "note": "Send clearer photos"}
    out, rec = decide(submitted, blobs, data)
    assert out == {"status": status}
    app = submitted.docs[f"coachApplications/{UID}"]
    assert app["status"] == status and app["reasons"] == data["reasons"] and app["note"] == "Send clearer photos"
    assert app["decidedAt"] == NOW and app["decidedBy"] == access.short_ref(STAFF)
    assert rec.notes == [(UID, "coachDecision")] and rec.claims == []
    assert f"coaches/{UID}" not in submitted.docs and f"coachPrivate/{UID}" not in submitted.docs


@pytest.mark.parametrize("decision", ["needs_changes", "reject"])
@pytest.mark.parametrize("reasons", [None, {}, {"nowhere": "unclear"}, {"personal": "bad"}, ["personal"]])
def test_those_need_a_section_and_a_reason(submitted, blobs, decision, reasons):
    before = copy.deepcopy(submitted.docs)
    assert refusal(lambda: decide(submitted, blobs, {"uid": UID, "decision": decision, "reasons": reasons}))[1] == errors.BAD_REQUEST
    assert submitted.docs == before


def test_other_bad_requests(submitted, blobs):
    before = copy.deepcopy(submitted.docs)
    for data in ({"uid": UID, "decision": "maybe"}, {"decision": "approve"}, approve_data(note="x" * 501), approve_data(uid="")):
        assert refusal(lambda: decide(submitted, blobs, data))[1] == errors.BAD_REQUEST
    assert submitted.docs == before


def test_a_missing_application(db, blobs):
    assert refusal(lambda: decide(db, blobs, approve_data())) == (errors.NOT_FOUND, errors.APPLICATION_NOT_FOUND)


@pytest.mark.parametrize("status", ["approved", "rejected", "needs_changes"])
def test_only_a_submitted_application_can_be_decided(submitted, blobs, status):
    submitted.docs[f"coachApplications/{UID}"]["status"] = status
    before = copy.deepcopy(submitted.docs)
    rec = Recorder()
    assert refusal(lambda: decide(submitted, blobs, approve_data(), rec)) == (errors.PRECONDITION, errors.WRONG_STATUS)
    assert submitted.docs == before and rec.claims == [] and rec.notes == []


def test_a_decision_leaves_one_access_line(submitted, blobs):
    decide(submitted, blobs, approve_data())
    lines = access_lines(submitted)
    assert len(lines) == 1 and lines[0]["admin"] == access.short_ref(STAFF)
    assert UID not in str(lines[0]) and STAFF not in str(lines[0])


def test_approving_again_after_a_new_round_keeps_her_numbers(submitted, blobs):
    decide(submitted, blobs, approve_data())
    submitted.docs[f"coaches/{UID}"].update(stats={"clientsCoached": 4, "plansShared": 9, "sessionsDone": 7}, activeClients=2, published=True, fromPriceEgp=575, fromMonthlyEgp=191)
    submitted.docs[f"coachPrivate/{UID}"].update(owedEgp=500, paidEgp=1000)
    submitted.docs[f"coachApplications/{UID}"]["status"] = "submitted"
    decide(submitted, blobs, approve_data())
    coach = submitted.docs[f"coaches/{UID}"]
    assert coach["stats"]["clientsCoached"] == 4 and coach["activeClients"] == 2
    assert coach["published"] is True and coach["fromPriceEgp"] == 575
    assert coach["fromMonthlyEgp"] == 191
    assert submitted.docs[f"coachPrivate/{UID}"]["owedEgp"] == 500


# -------------------------------------------------------------- claims


class FakeAuth:
    def __init__(self, claims):
        self.claims = dict(claims)
        self.writes = []

    def get_user(self, uid):
        from types import SimpleNamespace
        return SimpleNamespace(custom_claims=dict(self.claims))

    def set_custom_user_claims(self, uid, claims):
        self.writes.append((uid, dict(claims)))
        self.claims = dict(claims)


def test_merge_claims_keeps_the_others():
    auth = FakeAuth({"verified": True, "womanReviewer": True})
    claims.merge_claims(auth, "u1", {"coachV": "active"})
    assert auth.writes == [("u1", {"verified": True, "womanReviewer": True, "coachV": "active"})]


def test_merge_claims_on_an_account_with_no_claims():
    auth = FakeAuth({})
    claims.merge_claims(auth, "u1", {"coachV": "active"})
    assert auth.writes == [("u1", {"coachV": "active"})]


def test_suspend_hides_the_coach_and_flips_the_claim(db):
    db.docs[f"coaches/{UID}"] = {"published": True, "acceptingClients": True, "displayName": "Mona"}
    rec = Recorder()
    out = claims.suspend(db, STAFF, {"uid": UID, "reason": "Reported twice"}, merge_claims=rec.merge, now=NOW)
    assert out == {"coachV": "suspended"}
    assert rec.claims == [(UID, {"coachV": "suspended"})]
    coach = db.docs[f"coaches/{UID}"]
    assert coach["published"] is False and coach["acceptingClients"] is False and coach["displayName"] == "Mona"
    private = db.docs[f"coachPrivate/{UID}"]
    assert private["suspendReason"] == "Reported twice" and private["suspendedAt"] == NOW
    assert private["suspended"] is True
    assert len(access_lines(db)) == 1


def test_staff_cannot_suspend_themselves(db):
    db.docs[f"coaches/{UID}"] = {"published": True}
    rec = Recorder()
    before = copy.deepcopy(db.docs)
    assert refusal(lambda: claims.suspend(db, UID, {"uid": UID, "reason": "myself"}, merge_claims=rec.merge, now=NOW)) == (
        errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert db.docs == before and rec.claims == []


def test_the_verification_revoke_unpublishes_and_suspends_a_coach(db):
    db.docs[f"coaches/{UID}"] = {"published": True, "acceptingClients": True, "displayName": "Mona"}
    claims.on_verification_revoked(db, UID, NOW)
    assert db.docs[f"coaches/{UID}"]["published"] is False and db.docs[f"coaches/{UID}"]["acceptingClients"] is False
    assert db.docs[f"coachPrivate/{UID}"] == {
        "suspended": True, "suspendReason": "verification_revoked", "suspendedAt": NOW, "updatedAt": NOW}


def test_the_verification_revoke_does_nothing_for_a_non_coach_and_never_raises(db):
    claims.on_verification_revoked(db, "nobody", NOW)
    assert db.docs == {}

    class Broken:
        def collection(self, name):
            raise RuntimeError("down")

    claims.on_verification_revoked(Broken(), UID, NOW)


@pytest.mark.parametrize("data", [{"uid": UID, "reason": "x"}, {"uid": UID}, {"reason": "enough"}, {"uid": UID, "reason": "y" * 201}])
def test_suspend_needs_a_reason(db, data):
    db.docs[f"coaches/{UID}"] = {"published": True}
    rec = Recorder()
    assert refusal(lambda: claims.suspend(db, STAFF, data, merge_claims=rec.merge, now=NOW))[1] == errors.BAD_REQUEST
    assert db.docs[f"coaches/{UID}"] == {"published": True} and rec.claims == []


def test_suspending_someone_who_is_not_a_coach(db):
    rec = Recorder()
    assert refusal(lambda: claims.suspend(db, STAFF, {"uid": "x", "reason": "because"}, merge_claims=rec.merge, now=NOW)) == (errors.NOT_FOUND, errors.NOT_A_COACH)
    assert rec.claims == [] and db.docs == {}


# ------------------------------------------------- claim after commit, self-decisions


def test_the_claim_is_minted_only_after_the_approval_has_committed(submitted, blobs):
    seen = {}

    class Watching(Recorder):
        def merge(self, uid, changes):
            seen["application"] = submitted.docs[f"coachApplications/{UID}"]["status"]
            seen["pending"] = submitted.docs[f"coachPrivate/{UID}"]["claimPending"]
            super().merge(uid, changes)

    out, rec = decide(submitted, blobs, approve_data(), Watching())
    assert seen == {"application": "approved", "pending": True}
    assert rec.claims == [(UID, {"coachV": "active"})]
    private = submitted.docs[f"coachPrivate/{UID}"]
    assert private["claimPending"] is False and private["suspended"] is False


def test_a_failed_mint_keeps_the_approval_and_the_sweeper_finishes_it(submitted, blobs):
    class Failing(Recorder):
        def merge(self, uid, changes):
            raise RuntimeError("auth outage")

    out, rec = decide(submitted, blobs, approve_data(), Failing())
    assert out == {"status": "approved"}
    assert submitted.docs[f"coachApplications/{UID}"]["status"] == "approved"
    assert submitted.docs[f"coachPrivate/{UID}"]["claimPending"] is True
    retry = Recorder()
    assert applications.retry_claims(submitted, merge_claims=retry.merge) == 1
    assert retry.claims == [(UID, {"coachV": "active"})]
    assert submitted.docs[f"coachPrivate/{UID}"]["claimPending"] is False
    assert applications.retry_claims(submitted, merge_claims=retry.merge) == 0
    assert len(retry.claims) == 1


def test_the_retry_leaves_a_suspended_coach_and_an_unapproved_application_alone(db):
    db.docs["coachPrivate/s1"] = {"claimPending": True, "suspended": True}
    db.docs["coachApplications/s1"] = {"status": "approved"}
    db.docs["coachPrivate/r1"] = {"claimPending": True, "suspended": False}
    db.docs["coachApplications/r1"] = {"status": "rejected"}
    db.docs["coachPrivate/n1"] = {"claimPending": True}
    rec = Recorder()
    assert applications.retry_claims(db, merge_claims=rec.merge) == 0
    assert rec.claims == []
    assert db.docs["coachPrivate/s1"]["claimPending"] is True


def test_a_reject_that_commits_during_the_approval_means_no_claim_is_ever_minted(submitted, blobs):
    rec = Recorder()

    def reject_in_between(raw, long_side=None):
        # The reviewer's reject lands while the approval is preparing its photo.
        if long_side:
            return b"jpeg"
        applications.decide(
            submitted, "staff-2", {"uid": UID, "decision": "reject", "reasons": {"personal": "unclear"}},
            merge_claims=rec.merge, blobs=blobs, notify=rec.notify, reencode=None, now=NOW,
        )
        return b"jpeg"

    with pytest.raises(errors.CoachingError) as caught:
        applications.decide(
            submitted, STAFF, approve_data(), merge_claims=rec.merge, blobs=blobs,
            notify=rec.notify, reencode=reject_in_between, now=NOW,
        )
    assert caught.value.reason == errors.WRONG_STATUS
    assert rec.claims == []
    assert submitted.docs[f"coachApplications/{UID}"]["status"] == "rejected"
    assert f"coachPrivate/{UID}" not in submitted.docs


def test_a_reject_after_the_approval_is_refused_and_the_claim_stands(submitted, blobs):
    out, rec = decide(submitted, blobs, approve_data())
    with pytest.raises(errors.CoachingError) as caught:
        decide(submitted, blobs, {"uid": UID, "decision": "reject", "reasons": {"personal": "unclear"}}, rec)
    assert caught.value.reason == errors.WRONG_STATUS
    assert rec.claims == [(UID, {"coachV": "active"})]


@pytest.mark.parametrize("decision", ["approve", "reject", "needs_changes"])
def test_staff_never_decide_their_own_application(submitted, blobs, decision):
    before = copy.deepcopy(submitted.docs)
    rec = Recorder()
    data = approve_data() if decision == "approve" else {"uid": UID, "decision": decision, "reasons": {"personal": "unclear"}}
    with pytest.raises(errors.CoachingError) as caught:
        applications.decide(
            submitted, UID, data, merge_claims=rec.merge, blobs=blobs, notify=rec.notify,
            reencode=lambda raw: raw, now=NOW,
        )
    assert (caught.value.code, caught.value.reason) == (errors.PERMISSION, errors.STAFF_IS_SUBJECT)
    assert submitted.docs == before and rec.claims == [] and rec.notes == []


def test_approving_again_reinstates_a_suspended_coach(submitted, blobs):
    decide(submitted, blobs, approve_data())
    submitted.docs[f"coachPrivate/{UID}"].update(suspended=True, suspendReason="report")
    submitted.docs[f"coachApplications/{UID}"]["status"] = "submitted"
    decide(submitted, blobs, approve_data())
    assert submitted.docs[f"coachPrivate/{UID}"]["suspended"] is False


def test_a_webp_certificate_is_accepted(db, blobs):
    data = valid()
    data["certificates"][1]["mime"] = "image/webp"
    assert submit(db, blobs, data)["status"] == "submitted"


def test_while_payments_are_off_a_payout_account_is_dropped_and_never_kept(db, blobs):
    submit(db, blobs, payments_live=False)
    assert db.docs[f"coachApplications/{UID}"]["payout"] is None
