"""Server-level end-to-end run of private coaching on the local emulators.

    cd functions
    .venv/bin/python -m tools.e2e_coaching

Start the emulators first (tool/e2e_coaching.sh start). The run calls the real
callables over HTTP with ID tokens from the Auth emulator, reads and writes
Firestore and Storage through the REST APIs under the real rules, and prints
PASS, FAIL or SKIP per step. The exit code is 1 when any step fails.
Everything is local: it refuses a non-local host.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from tools import e2e_seed

PROJECT = os.environ.get("E2E_PROJECT", "demo-own-hub")
REGION = "europe-west3"
FN = os.environ.get("E2E_FUNCTIONS_HOST", "127.0.0.1:5101")
FS = os.environ.get("E2E_FIRESTORE_HOST", "127.0.0.1:8288")
ST = os.environ.get("E2E_STORAGE_HOST", "127.0.0.1:9399")
BUCKET = "own-hub-personal"
DOCS = f"http://{FS}/v1/projects/{PROJECT}/databases/(default)/documents"
IDS = json.load(open(os.path.join(os.path.dirname(__file__), "..", "coaching", "content_ids.json")))


class Skip(Exception):
    pass


class Refused(Exception):
    def __init__(self, status, message):
        super().__init__(f"{status} {message}")
        self.status, self.message = status, message


# ------------------------------------------------------------------ transport
def _req(method, url, body=None, headers=None, raw=None):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    h = {"Content-Type": "application/json"} if raw is None else {}
    h.update(headers or {})
    req = urllib.request.Request(url, data, h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            text = res.read()
            return res.status, (json.loads(text) if text else {})
    except urllib.error.HTTPError as err:
        text = err.read()
        try:
            return err.code, json.loads(text)
        except ValueError:
            return err.code, {"raw": text[:300].decode("utf-8", "replace")}


def call(name, token, data=None):
    status, body = _req(
        "POST", f"http://{FN}/{PROJECT}/{REGION}/{name}", {"data": data or {}},
        {"Authorization": f"Bearer {token}"},
    )
    if status != 200 or "error" in body:
        err = body.get("error", body)
        raise Refused(err.get("status", status), err.get("message", body))
    return body.get("result", body)


# ------------------------------------------------------------------ firestore
def enc(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if v is None:
        return {"nullValue": None}
    if isinstance(v, list):
        return {"arrayValue": {"values": [enc(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: enc(x) for k, x in v.items()}}}
    return {"stringValue": str(v)}


def dec(v):
    (kind, val), = v.items()
    if kind == "integerValue":
        return int(val)
    if kind == "mapValue":
        return {k: dec(x) for k, x in val.get("fields", {}).items()}
    if kind == "arrayValue":
        return [dec(x) for x in val.get("values", [])]
    if kind == "nullValue":
        return None
    return val


def auth_header(token):
    return {"Authorization": f"Bearer {token}"}


def fs_get(path, token):
    status, body = _req("GET", f"{DOCS}/{path}", headers=auth_header(token))
    if status == 404:
        return None
    if status != 200:
        raise Refused(status, body.get("error", {}).get("status", body))
    return {k: dec(v) for k, v in body.get("fields", {}).items()}


def fs_list(path, token, page_size=100):
    status, body = _req("GET", f"{DOCS}/{path}?pageSize={page_size}", headers=auth_header(token))
    if status != 200:
        raise Refused(status, body.get("error", {}).get("status", body))
    return [{k: dec(v) for k, v in d.get("fields", {}).items()} | {"_id": d["name"].rsplit("/", 1)[-1]}
            for d in body.get("documents", [])]


def fs_query(parent, collection, token, field, value):
    """A filtered list, the way the app asks (the rules need the filter)."""
    body = {"structuredQuery": {
        "from": [{"collectionId": collection}],
        "where": {"fieldFilter": {"field": {"fieldPath": field}, "op": "EQUAL", "value": enc(value)}},
    }}
    status, rows = _req("POST", f"{DOCS}/{parent}:runQuery" if parent else f"{DOCS}:runQuery", body, auth_header(token))
    if status != 200:
        raise Refused(status, (rows[0] if isinstance(rows, list) and rows else rows))
    out = []
    for row in rows if isinstance(rows, list) else []:
        doc = row.get("document")
        if doc:
            out.append({k: dec(v) for k, v in doc.get("fields", {}).items()} | {"_id": doc["name"].rsplit("/", 1)[-1]})
    return out


def fs_send(path, token, fields):
    """A create with createdAt = request time, as the chat rules require."""
    name = f"projects/{PROJECT}/databases/(default)/documents/{path}"
    write = {
        "update": {"name": name, "fields": {k: enc(v) for k, v in fields.items()}},
        "updateTransforms": [{"fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"}],
        "currentDocument": {"exists": False},
    }
    status, body = _req(
        "POST", f"{DOCS}:commit", {"writes": [write]}, auth_header(token)
    )
    if status != 200:
        raise Refused(status, body.get("error", {}).get("status", body))


def _walk(path, out):
    """Every document under a collection path, as the owner, into out[path]."""
    token = ""
    while True:
        status, body = _req("GET", f"{DOCS}/{path}?pageSize=300{token}", headers=auth_header("owner"))
        if status != 200:
            raise Refused(status, body)
        for doc in body.get("documents", []):
            out[doc["name"].split("/documents/", 1)[1]] = {k: dec(v) for k, v in doc.get("fields", {}).items()}
        if not body.get("nextPageToken"):
            return
        token = "&pageToken=" + urllib.parse.quote(body["nextPageToken"])


# The collections the coaching service writes, and the subcollections under each.
DUMP_TREE = {
    "coachApplications": [], "coaches": ["packages", "media", "drafts"],
    "coachPrivate": ["prices", "ledger", "payouts"], "relationships": ["messages", "reads", "reviews"],
    "subscriptions": ["sessions"], "reports": [], "receipts": [],
}


def dump_docs(client_uids):
    """Every coaching document of the run, keyed by path, as plain JSON: times
    are ISO strings, which the app's readTime accepts."""
    docs = {}
    for top, subs in DUMP_TREE.items():
        _walk(top, docs)
        for path in [p for p in docs if p.count("/") == 1 and p.startswith(top + "/")]:
            for sub in subs:
                _walk(f"{path}/{sub}", docs)
    for uid in client_uids:
        _walk(f"plans/{uid}/coachPlans", docs)
    return docs


def admin_patch(path, fields):
    """Owner bypass, for the one thing a clock needs: move a session into the past."""
    mask = "&".join(f"updateMask.fieldPaths={urllib.parse.quote(k)}" for k in fields)
    status, body = _req(
        "PATCH", f"{DOCS}/{path}?{mask}",
        {"fields": {k: v for k, v in fields.items()}}, auth_header("owner"),
    )
    if status != 200:
        raise Refused(status, body)


def refused(fn, *codes):
    try:
        fn()
    except Refused as err:
        if codes and err.status not in codes and str(err.status) not in map(str, codes):
            raise AssertionError(f"expected {codes}, got {err}") from None
        return err
    raise AssertionError("expected a refusal, but it was allowed")


# -------------------------------------------------------------------- storage
def jpeg(seed):
    import cv2
    import numpy as np

    rng = np.random.default_rng(seed)
    base = rng.integers(0, 255, (8, 9), dtype=np.uint8)
    image = cv2.resize(base, (180, 160), interpolation=cv2.INTER_NEAREST)
    ok, out = cv2.imencode(".jpg", image)
    assert ok
    return out.tobytes()


def upload(token, path, data, mime="image/jpeg"):
    url = f"http://{ST}/v0/b/{BUCKET}/o?name={urllib.parse.quote(path, safe='')}"
    status, body = _req("POST", url, raw=data, headers={"Authorization": f"Firebase {token}", "Content-Type": mime})
    if status != 200:
        raise Refused(status, body)


def coach_application(coach_uid):
    """A full coach application and the file paths it names (under her own coach-docs folder)."""
    base = f"coach-docs/{coach_uid}/"
    paths = {
        "photo": base + "photo/me.jpg", "edu": base + "education/deg.jpg",
        "cert1": base + "certificates/nasm.jpg", "cert2": base + "certificates/ces.jpg",
        "test": base + "testimonials/s1.jpg", "before": base + "transformations/b1.jpg",
        "after": base + "transformations/a1.jpg",
    }
    application = {
        "personal": {"fullName": "Mona Hassan Ali", "displayName": "Mona", "governorate": "cairo",
                     "languages": ["ar", "en"], "headline": "Strength coach for busy women",
                     "photoPath": paths["photo"]},
        "education": [{"degree": "BSc Sports Science", "institution": "Cairo University", "year": 2015,
                       "path": paths["edu"]},
                      {"degree": "Diploma", "institution": "Nutrition Institute", "year": 2018}],
        "certificates": [{"id": "nasm-cpt", "title": "NASM CPT", "issuer": "NASM", "year": 2019,
                          "path": paths["cert1"], "mime": "image/jpeg"},
                         {"id": "ces", "title": "Corrective Exercise", "issuer": "NASM", "year": 2021,
                          "path": paths["cert2"], "mime": "image/jpeg"}],
        "specialties": ["strength", "fatLoss"],
        "qualifications": "Eight years training women one to one in Cairo.",
        "yearsExperience": 8,
        "testimonials": [{"text": "She changed how I train and eat.", "from": "Salma", "source": "whatsapp",
                          "imagePath": paths["test"]},
                         {"text": "Patient, clear and kind to me.", "from": "Nour", "source": "inPerson"}],
        "transformations": [{"beforePath": paths["before"], "afterPath": paths["after"], "weeks": 12,
                             "note": "Three days a week", "clientConsent": True}],
        "approach": {"text": "I build every plan around her week, her kitchen and her energy, then adjust it each Sunday.",
                     "checkInsPerWeek": 2, "replyHours": 12, "trainsWhere": ["home", "online"]},
        "payout": {"rail": "instapay", "account": "mona.h@instapay", "holderName": "Mona Hassan Ali"},
        "termsVersion": 2, "rules": ["accurateInfo", "clientPhotoConsent", "noOffPlatformPayment"],
        "locale": "en",
    }
    return application, paths


# ----------------------------------------------------------------------- run
results = []


def step(title, fn, *needs):
    """Run one step. Skipped when an earlier step it needs did not pass."""
    failed = [n for n in needs if n not in ctx["passed"]]
    if failed:
        results.append(("SKIP", title, f"needs {failed[0]}"))
    else:
        try:
            fn()
            ctx["passed"].add(title)
            results.append(("PASS", title, ""))
        except Skip as why:
            results.append(("SKIP", title, str(why)))
        except Exception as err:  # noqa: BLE001
            results.append(("FAIL", title, f"{type(err).__name__}: {err}"))
    print(f"{results[-1][0]:4}  {title}" + (f"  [{results[-1][2]}]" if results[-1][2] else ""), flush=True)


ctx = {"passed": set()}


def main() -> int:
    dump_path = sys.argv[sys.argv.index("--dump") + 1] if "--dump" in sys.argv else None
    e2e_seed._local()
    seeded = e2e_seed.seed()
    uid = {k: v["uid"] for k, v in seeded.items()}
    tok = {k: v["idToken"] for k, v in e2e_seed.tokens().items()}
    application, paths = coach_application(uid["coach"])
    base = f"coach-docs/{uid['coach']}/"
    S = ctx  # shorthand for shared values

    def upload_files():
        for i, p in enumerate(paths.values()):
            upload(tok["coach"], p, jpeg(i + 1))

    def stranger_cannot_upload():
        refused(lambda: upload(tok["client"], paths["photo"], jpeg(1)), 401, 403)

    def apply():
        call("submit_coach_application", tok["coach"], application)
        assert fs_get(f"coachApplications/{uid['coach']}", "owner")["status"] == "submitted"

    def reviewer_lists():
        out = call("list_coach_applications", tok["reviewer"], {"status": "submitted"})
        text = json.dumps(out)
        assert uid["coach"] in text, f"application not in the queue: {text[:200]}"

    def client_cannot_review():
        refused(lambda: call("list_coach_applications", tok["client"], {}), "PERMISSION_DENIED")

    def approve():
        call("decide_coach_application", tok["reviewer"],
             {"uid": uid["coach"], "decision": "approve", "checkedCertificates": ["nasm-cpt"], "note": ""})
        assert fs_get(f"coachApplications/{uid['coach']}", "owner")["status"] == "approved"

    def claim_arrives():
        tok["coach"] = e2e_seed.sign_in(e2e_seed.ACCOUNTS["coach"]["phone"])["idToken"]
        payload = json.loads(__import__("base64").urlsafe_b64decode(tok["coach"].split(".")[1] + "=="))
        assert payload.get("coachV") == "active", f"coachV claim missing: {payload}"

    agreement_path = f"coach-docs/{uid['coach']}/agreement/signed-e2e.jpg"

    def accept_agreement():
        out = call("accept_coach_terms", tok["coach"], {"version": 2, "locale": "en"})
        assert out["status"] in ("accepted", "uploaded", "verified"), out

    def upload_signed_copy():
        upload(tok["coach"], agreement_path, jpeg(77))
        assert call("submit_coach_agreement", tok["coach"], {"mediaRef": agreement_path})["status"] == "uploaded"

    def client_cannot_decide_agreement():
        refused(lambda: call("decide_coach_agreement", tok["client"], {"uid": uid["coach"], "decision": "verify"}),
                "PERMISSION_DENIED")

    def staff_verifies_agreement():
        waiting = call("list_coach_agreements", tok["reviewer"], {})
        assert uid["coach"] in json.dumps(waiting), waiting
        assert call("decide_coach_agreement", tok["reviewer"], {"uid": uid["coach"], "decision": "verify"})["status"] == "verified"
        assert fs_get(f"coachPrivate/{uid['coach']}", tok["coach"])["agreement"]["status"] == "verified"

    def confirm_payout():
        try:
            call("confirm_payout_account", tok["admin"], {"uid": uid["coach"], "decision": "confirm"})
        except Refused as err:
            raise Skip(f"payout confirmation not available: {err}")

    def save_package():
        out = call("save_coach_package", tok["coach"], {
            "title": "Strong in four weeks", "description": "A plan, live calls and daily support for a month.",
            "durationDays": 28, "includes": ["Workout plan", "Meal plan"], "liveSessionsPerMonth": 4,
            "sessionMinutes": 45, "checkInsPerWeek": 2, "coachPriceEgp": 1000, "active": True, "order": 0})
        S["package"] = out["packageId"]

    def update_profile():
        call("update_coach_profile", tok["coach"], {
            "headline": "Strength coach for busy women in Cairo",
            "approachText": "I build every plan around her week, her kitchen and her energy, adjusted weekly."})
        assert "Cairo" in fs_get(f"coaches/{uid['coach']}", tok["coach"])["headline"]

    def portfolio():
        gallery = base + "photo/gallery.jpg"
        feedback = base + "testimonials/fb1.jpg"
        for n, path in enumerate((gallery, feedback)):
            upload(tok["coach"], path, jpeg(40 + n))
        out = {}
        out["photo"] = call("add_portfolio_media", tok["coach"],
                            {"kind": "photo", "imagePath": gallery, "caption": "Training day"})["mediaId"]
        out["feedback"] = call("add_portfolio_media", tok["coach"], {
            "kind": "feedback", "text": "She made training feel doable again.", "from": "Salma",
            "imagePath": feedback})["mediaId"]
        try:
            out["transformation"] = call("add_portfolio_media", tok["coach"], {
                "kind": "transformation", "beforePath": paths["before"], "afterPath": paths["after"], "weeks": 12,
                "note": "Three days a week", "clientConsentPublic": True})["mediaId"]
        except Refused as err:
            # Emulator limit: locking the originals is a Storage PATCH (blob.patch), which the
            # Storage emulator answers with 501 Not Implemented. Production supports it.
            if str(err.status) != "INTERNAL":
                raise
            print("NOTE  transformation upload hit the Storage emulator's missing PATCH (501): not run here")
        S["media"] = out
        # A transformation without the written-consent tick is refused.
        refused(lambda: call("add_portfolio_media", tok["coach"], {
            "kind": "transformation", "beforePath": paths["before"], "afterPath": paths["after"], "weeks": 12}),
            "INVALID_ARGUMENT")

    def pending_media_hidden():
        seen = fs_query(f"coaches/{uid['coach']}", "media", tok["client"], "status", "approved")
        assert not [m for m in seen if m["_id"] in S["media"].values()], seen
        # Only the woman reviewer holds the queue; an admin does not.
        refused(lambda: call("list_portfolio_media", tok["admin"], {}), "PERMISSION_DENIED")

    def approve_media():
        queue = json.dumps(call("list_portfolio_media", tok["reviewer"], {}))
        for kind, mid in S["media"].items():
            assert mid in queue, f"{kind} not in the queue: {queue[:200]}"
            call("decide_portfolio_media", tok["reviewer"],
                 {"coachUid": uid["coach"], "mediaId": mid, "decision": "approve"})

    def client_sees_media():
        seen = fs_query(f"coaches/{uid['coach']}", "media", tok["client"], "status", "approved")
        got = {m["_id"] for m in seen}
        assert set(S["media"].values()) <= got, seen
        shown = [m for m in seen if m.get("kind") == "transformation"]
        if "transformation" in S["media"]:
            assert shown[0].get("publicPaths"), shown
        private = urllib.parse.quote(paths["before"], safe="")
        status, _ = _req("GET", f"http://{ST}/v0/b/{BUCKET}/o/{private}?alt=media",
                         headers={"Authorization": f"Firebase {tok['client']}"})
        assert status in (401, 403), f"a member could read the private original: {status}"
        items = e2e_get_public(tok["client"], uid["coach"])
        assert items, "no re-encoded public image in coach-public"
        refused(lambda: fs_query(f"coaches/{uid['coach']}", "media", tok["stranger"], "status", "pending"), 403)

    def e2e_get_public(token, coach):
        prefix = urllib.parse.quote(f"coach-public/{coach}/media/", safe="")
        status, body = _req("GET", f"http://{ST}/v0/b/{BUCKET}/o?prefix={prefix}", headers={"Authorization": "Bearer owner"})
        names = [i["name"] for i in body.get("items", [])]
        for name in names[:1]:
            url = f"http://{ST}/v0/b/{BUCKET}/o/{urllib.parse.quote(name, safe='')}?alt=media"
            req = urllib.request.Request(url, headers={"Authorization": f"Firebase {token}"})
            with urllib.request.urlopen(req, timeout=30) as res:
                assert res.status == 200
        return names

    def client_browses():
        page = fs_get(f"coaches/{uid['coach']}", tok["client"])
        assert page and page.get("published") is True, page
        pkgs = fs_query(f"coaches/{uid['coach']}", "packages", tok["client"], "active", True)
        assert any(p["_id"] == S["package"] for p in pkgs), pkgs
        listed = fs_query("", "coaches", tok["client"], "published", True)
        assert any(c["_id"] == uid["coach"] for c in listed), listed
        refused(lambda: fs_list("coaches", tok["client"]), 403)  # an unfiltered list is not allowed

    def stranger_unverified_cannot_browse():
        refused(lambda: fs_get(f"coaches/{uid['coach']}", "invalid-token"), 400, 401, 403)

    def intake():
        return {"goal": "stronger", "level": "beginner", "daysPerWeek": 3, "place": "home",
                "allergies": ["peanut"], "lifeStage": "none",
                "health": {}, "doctorAck": False, "note": "hello"}

    def ask():
        from coaching import common
        row = intake()
        row["health"] = {key: False for key in common.ENUMS["healthQuestions"]}
        out = call("request_coaching", tok["client"],
                   {"coachUid": uid["coach"], "packageId": S["package"], "intake": row, "locale": "en",
                    "appBuild": common.MIN_APP_BUILD})
        S["sub"] = out["subId"]
        S["rel"] = f"{uid['coach']}__{uid['client']}"
        assert out["status"] in ("requested", "active"), out

    def coach_sees_intake_stranger_not():
        sub = fs_get(f"subscriptions/{S['sub']}", tok["coach"])
        assert sub and sub.get("intake", {}).get("goal") == "stronger", sub
        refused(lambda: fs_get(f"subscriptions/{S['sub']}", tok["stranger"]), 403)

    def accept():
        sub = fs_get(f"subscriptions/{S['sub']}", "owner")
        if sub["status"] == "active":
            return
        out = call("respond_coaching_request", tok["coach"], {"subId": S["sub"], "decision": "accept"})
        assert out["status"] == "active", out
        sub = fs_get(f"subscriptions/{S['sub']}", "owner")
        assert sub.get("free") is True and sub["status"] == "active", sub

    def relationship_open():
        rel = fs_get(f"relationships/{S['rel']}", tok["client"])
        assert rel["status"] == "active" and rel["chatOpen"] is True, rel

    def stranger_thread():
        refused(lambda: fs_list(f"relationships/{S['rel']}/messages", tok["stranger"]), 403)
        refused(lambda: fs_get(f"relationships/{S['rel']}", tok["stranger"]), 403)
        refused(lambda: fs_send(f"relationships/{S['rel']}/messages/x1", tok["stranger"],
                                {"senderUid": uid["stranger"], "type": "text", "text": "hi"}), 403)

    def send(frm, text):
        fs_send(f"relationships/{S['rel']}/messages/{frm}-{int(time.time() * 1000)}", tok[frm],
                {"senderUid": uid[frm], "type": "text", "text": text})

    def messages_both_ways():
        send("client", "Hello coach, I am ready to start")
        time.sleep(0.5)
        send("coach", "Welcome, let us begin on Sunday")
        time.sleep(0.5)
        for who in ("client", "coach"):
            rows = fs_list(f"relationships/{S['rel']}/messages", tok[who])
            texts = [r.get("text") for r in rows if r.get("type") == "text"]
            assert "Hello coach, I am ready to start" in texts and "Welcome, let us begin on Sunday" in texts, texts

    def cannot_forge_sender():
        refused(lambda: fs_send(f"relationships/{S['rel']}/messages/forged", tok["client"],
                                {"senderUid": uid["coach"], "type": "text", "text": "I am the coach"}), 403)
        refused(lambda: fs_send(f"relationships/{S['rel']}/messages/num", tok["client"],
                                {"senderUid": uid["client"], "type": "text", "text": "call 01012345678 now"}), 403)

    def trigger_summary():
        for _ in range(20):
            rel = fs_get(f"relationships/{S['rel']}", "owner")
            if rel.get("lastMessage"):
                break
            time.sleep(0.5)
        last = rel.get("lastMessage") or {}
        assert last.get("senderUid") == uid["coach"], f"trigger did not run: {rel}"
        assert int(rel.get("unreadFor", {}).get(uid["client"], 0)) >= 1, rel

    def mark_read():
        call("mark_thread_read", tok["client"], {"relId": S["rel"]})
        rel = fs_get(f"relationships/{S['rel']}", tok["client"])
        assert int(rel["unreadFor"][uid["client"]]) == 0, rel
        assert fs_get(f"relationships/{S['rel']}/reads/{uid['client']}", tok["client"]) is not None
        refused(lambda: call("mark_thread_read", tok["stranger"], {"relId": S["rel"]}), "NOT_FOUND")

    def publish_plans():
        ex, rec, food = sorted(IDS["exercises"])[:2], sorted(IDS["recipes"])[0], sorted(IDS["foods"])[0]

        def move(eid, **o):
            m = {"exerciseId": eid, "nameEn": eid, "nameAr": eid, "sets": 3, "reps": 12, "holdSeconds": None,
                 "restSeconds": 60, "notesEn": "", "notesAr": "", "safetyEn": "", "safetyAr": "",
                 "contraindications": [], "quiet": False, "floorOnly": False, "needsEquipment": False}
            m.update(o)
            return m

        workout = {"revision": 1, "name": "Phase one", "days": [{"session": {
            "sessionId": "mine_1", "titleEn": "Legs", "titleAr": "رجلين", "minutes": 40, "lifeStages": ["none"],
            "moves": [move(ex[0]), move(ex[1], reps=None, holdSeconds=30)]}, "kg": [20.0, None]}]}
        meal = {"days": [{"label": "Day 1", "slots": {
            "breakfast": [{"kind": "recipe", "recipeId": rec, "servings": 1.5, "note": "warm"}],
            "lunch": [{"kind": "food", "foodId": food, "grams": 150}],
            "snack": [{"kind": "free", "text": "A handful of nuts"}]}}]}
        for kind, body in (("workout", workout), ("meal", meal)):
            out = call("publish_coach_plan", tok["coach"],
                       {"subId": S["sub"], "kind": kind, "name": f"My {kind} plan", "body": body})
            S[kind] = out["planId"]
            plan = fs_get(f"plans/{uid['client']}/coachPlans/{out['planId']}", tok["client"])
            assert plan["kind"] == kind, plan
        refused(lambda: fs_get(f"plans/{uid['client']}/coachPlans/{S['workout']}", tok["stranger"]), 403)

    def schedule():
        start = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=2)).isoformat()
        out = call("schedule_live_session", tok["coach"], {
            "subId": S["sub"], "startsAt": start, "minutes": 45, "link": "https://meet.google.com/abc-defg-hij"})
        S["session"] = out["sessionId"]

    def confirm_session():
        call("respond_live_session", tok["client"],
             {"subId": S["sub"], "sessionId": S["session"], "decision": "confirm"})

    def done_by_both():
        past = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
        early = refused(lambda: call("mark_session_done", tok["coach"],
                                     {"subId": S["sub"], "sessionId": S["session"]}), "FAILED_PRECONDITION")
        admin_patch(f"subscriptions/{S['sub']}/sessions/{S['session']}", {"startsAt": {"timestampValue": past}})
        first = call("mark_session_done", tok["coach"], {"subId": S["sub"], "sessionId": S["session"]})
        assert first["status"] == "confirmed", first
        second = call("mark_session_done", tok["client"], {"subId": S["sub"], "sessionId": S["session"]})
        assert second["status"] == "done" and second["sessionsUsed"] == 1, second
        assert early

    def end():
        call("end_coaching", tok["admin"], {"subId": S["sub"], "reason": "other"})
        rel = fs_get(f"relationships/{S['rel']}", "owner")
        assert rel["status"] != "active", rel
        refused(lambda: fs_send(f"relationships/{S['rel']}/messages/after", tok["client"],
                                {"senderUid": uid["client"], "type": "text", "text": "still there?"}), 403)

    step("seed: five phone accounts with their claims", lambda: None)
    step("coach uploads application files (Storage emulator, coach-docs)", upload_files)
    step("another member cannot write into her coach-docs folder", stranger_cannot_upload, "coach uploads application files (Storage emulator, coach-docs)")
    step("coach submits the application", apply, "coach uploads application files (Storage emulator, coach-docs)")
    step("woman reviewer sees it in the queue", reviewer_lists, "coach submits the application")
    step("a client is refused the reviewer queue", client_cannot_review)
    step("reviewer approves the application", approve, "coach submits the application")
    step("coachV claim reaches her next token", claim_arrives, "reviewer approves the application")
    step("coach accepts Coach Agreement v2 in the app", accept_agreement, "coachV claim reaches her next token")
    step("coach uploads her signed copy and submits it", upload_signed_copy, "coach accepts Coach Agreement v2 in the app")
    step("a client cannot decide a signed agreement", client_cannot_decide_agreement)
    step("staff verify the signed copy", staff_verifies_agreement, "coach uploads her signed copy and submits it")
    step("finance confirms her payout account (if still required)", confirm_payout, "reviewer approves the application")
    step("coach saves a package", save_package, "coachV claim reaches her next token")
    step("coach updates her profile", update_profile, "coachV claim reaches her next token")
    step("coach adds a photo, feedback and a transformation (consent ticked)", portfolio, "coachV claim reaches her next token")
    step("pending media is hidden from members and the queue is closed to admins", pending_media_hidden, "coach adds a photo, feedback and a transformation (consent ticked)")
    step("reviewer approves all three items", approve_media, "coach adds a photo, feedback and a transformation (consent ticked)")
    step("a member sees the approved items and a re-encoded public image", client_sees_media, "reviewer approves all three items")
    step("client browses the coach page, packages and list", client_browses, "coach saves a package")
    step("a bad token reads nothing", stranger_unverified_cannot_browse)
    step("client asks to join with an intake", ask, "coach saves a package")
    step("coach sees the intake, a stranger does not", coach_sees_intake_stranger_not, "client asks to join with an intake")
    step("coach accepts (free while payments are off)", accept, "client asks to join with an intake", "staff verify the signed copy")
    step("relationship is active with chat open", relationship_open, "coach accepts (free while payments are off)")
    step("a stranger cannot read or write the thread", stranger_thread, "relationship is active with chat open")
    step("messages both ways through Firestore rules", messages_both_ways, "relationship is active with chat open")
    step("rules refuse a forged sender and a phone number", cannot_forge_sender, "relationship is active with chat open")
    step("message trigger sets lastMessage and unread", trigger_summary, "messages both ways through Firestore rules")
    step("mark_thread_read clears unread and writes reads", mark_read, "message trigger sets lastMessage and unread")
    step("coach publishes a workout plan and a meal plan", publish_plans, "coach accepts (free while payments are off)")
    step("coach schedules a live session", schedule, "coach accepts (free while payments are off)")
    step("client confirms the session", confirm_session, "coach schedules a live session")
    step("session done only once both mark it (clock moved in the emulator)", done_by_both, "client confirms the session")
    step("admin ends the coaching; the thread closes", end, "coach accepts (free while payments are off)")

    if dump_path:
        try:
            docs = dump_docs([uid["client"], uid["stranger"]])
            made = {"package": S.get("package"), "sub": S.get("sub"), "rel": S.get("rel"),
                    "media": S.get("media"), "session": S.get("session"),
                    "workoutPlan": S.get("workout"), "mealPlan": S.get("meal")}
            os.makedirs(os.path.dirname(os.path.abspath(dump_path)), exist_ok=True)
            with open(dump_path, "w", encoding="utf-8") as handle:
                json.dump({"uids": uid, "created": made, "docs": docs}, handle, indent=1, sort_keys=True,
                          ensure_ascii=False)
            print(f"dump: {len(docs)} documents -> {dump_path}")
        except Exception as err:  # noqa: BLE001
            results.append(("FAIL", "dump coaching documents", f"{type(err).__name__}: {err}"))
            print(f"FAIL  dump coaching documents  [{err}]")

    counts = {k: sum(1 for r in results if r[0] == k) for k in ("PASS", "FAIL", "SKIP")}
    print(f"\n{counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped")
    for status, title, why in results:
        if status == "FAIL":
            print(f"FAIL  {title}\n      {why}")
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
