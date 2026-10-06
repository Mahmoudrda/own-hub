"""OWNER'S TOOL ONLY: a copy of one woman's data, for a request she made (M8).

Until the app can download it, a copy of her data is asked for by email (Your
data > Ask for a copy). Once the owner has confirmed that the request comes
from the owner of the number on the account, this builds the copy from the
deletion manifest, so nothing the server holds about her can be left out
without a written reason:

    ownhub-data-<date>.json   every section, machine readable
    summary-<lang>.html       the same, in plain words, in her language

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.export_user <uid> \
        --lang ar --out ~/exports/<case>

Deliver it as the privacy policy says (pending counsel: a password-protected
file by email, the password by SMS). Do not save an export inside this
repository, and delete it once it is delivered.

Every manifest row is either exported (SECTIONS) or excluded with a reason
(EXPORT_EXCLUSIONS); tests/test_export_user.py fails if a row is neither.
Raw scores, images, the raw ID number and the keyed ID code itself are never
in an export, because none of them is stored, or because the code is a
security control rather than data about her.
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
from typing import Any, Optional, Protocol

from account import manifest

SCHEMA = "ownhub.export/1"

# Manifest row -> export section.
SECTIONS: dict[int, str] = {
    29: "account",
    1: "settings",
    10: "agreements",
    22: "verification",
    39: "verification",
    23: "identityCode",
    42: "fraudSignals",
    43: "fraudSignals",
    44: "reviewAccess",
    40: "attempts",
    2: "training",
    4: "training",
    6: "training",
    11: "training",
    12: "training",
    32: "training",
    37: "training",
    5: "food",
    13: "food",
    14: "food",
    3: "healthCloud",
    7: "healthCloud",
    35: "healthCloud",
    36: "healthCloud",
    15: "notifications",
    16: "safety",
    18: "safety",
    19: "safety",
    38: "settings",
    8: "devices",
    20: "plans",
    21: "plans",
}

# Manifest row -> why it is not in the copy.
EXPORT_EXCLUSIONS: dict[int, str] = {
    9: "The sync queue exists only on her phone. Nothing is held on the server.",
    17: "Records in other women's accounts. They are about the other women.",
    24: "No photos or coach documents are stored in this release.",
    25: "Earlier copies of her data. They are the export itself.",
    26: "Community, coaching and the assistant are off in this release; nothing exists.",
    27: "No analytics service is used, so nothing is held there.",
    28: "Crash reports are never linked to her account, so they cannot be found for her.",
    30: "Reports are pseudonymised and are about safety cases, not her account.",
    31: "The deletion record exists only after she deletes her account.",
    33: "Progress photos are kept only on her phone.",
    34: "The photo key lives only on her phone.",
    41: "Single-use selfie sessions, deleted after five minutes.",
    # APL-16: the rows naming row 26's data one by one. The rules refuse every
    # write to them while community and coaching are off, so nothing exists.
    # Each moves to SECTIONS in the release that switches its feature on.
    45: "The community is off in this release; there are no posts.",
    46: "The community is off in this release; there are no comments.",
    47: "Coaching is off in this release; there is no coach page or certificate.",
    48: "Coaching is off in this release; there is no coaching relationship.",
    49: "Coaching is off in this release; there are no invite codes.",
}

RETENTION = {
    "account": {
        "en": "Until you delete your account.",
        "ar": "حتى تحذفي حسابكِ.",
    },
    "settings": {"en": "Until you delete them or your account.", "ar": "حتى تحذفيها أو تحذفي حسابكِ."},
    "agreements": {"en": "Until you delete your account.", "ar": "حتى تحذفي حسابكِ."},
    "verification": {
        "en": "180 days after the case is decided, or earlier if you delete your account.",
        "ar": "180 يومًا بعد البتّ في الحالة، أو قبل ذلك إذا حذفتِ حسابكِ.",
    },
    "identityCode": {
        "en": "While your account exists. After deletion it is closed, not deleted.",
        "ar": "ما دام حسابكِ قائمًا. وبعد الحذف يُغلق ولا يُحذف.",
    },
    "fraudSignals": {
        "en": "180 days after the last attempt. Not linked to your account.",
        "ar": "180 يومًا بعد آخر محاولة، دون ربط بحسابكِ.",
    },
    "reviewAccess": {"en": "One year.", "ar": "سنة واحدة."},
    "attempts": {"en": "Until you delete your account.", "ar": "حتى تحذفي حسابكِ."},
    "training": {"en": "Until you delete it or your account.", "ar": "حتى تحذفيه أو تحذفي حسابكِ."},
    "food": {"en": "Until you delete it or your account.", "ar": "حتى تحذفيه أو تحذفي حسابكِ."},
    "healthCloud": {
        "en": "Only while health backup is on. Turning it off deletes this copy.",
        "ar": "ما دام النسخ الاحتياطي الصحي مفعّلًا فقط، وإيقافه يحذف هذه النسخة.",
    },
    "notifications": {"en": "Until you delete your account.", "ar": "حتى تحذفي حسابكِ."},
    "safety": {"en": "Until you delete your account.", "ar": "حتى تحذفي حسابكِ."},
    "devices": {"en": "Until you delete your account.", "ar": "حتى تحذفي حسابكِ."},
    "plans": {"en": "Until you delete your account.", "ar": "حتى تحذفي حسابكِ."},
}

LABELS = {
    "account": ("Your account", "حسابكِ"),
    "settings": ("Your settings and setup answers", "إعداداتكِ وإجاباتكِ عند الإعداد"),
    "agreements": ("Your agreements", "موافقاتكِ"),
    "verification": ("Your check", "التحقق"),
    "identityCode": ("The keyed code of your ID number", "الرمز المشفّر لرقمكِ القومي"),
    "fraudSignals": ("Failed check attempts", "المحاولات الفاشلة للتحقق"),
    "reviewAccess": ("When a reviewer opened your case", "متى فتحت مراجِعة حالتكِ"),
    "attempts": ("How many checks you used", "عدد محاولات التحقق"),
    "training": ("Your training", "تدريبكِ"),
    "food": ("Your meals", "وجباتكِ"),
    "healthCloud": ("Your health backup", "نسختكِ الصحية الاحتياطية"),
    "notifications": ("Your notifications", "إشعاراتكِ"),
    "safety": ("Blocks and reports", "الحظر والبلاغات"),
    "devices": ("Your devices", "أجهزتكِ"),
    "plans": ("Plans from a coach", "خطط من مدرّبة"),
    "phoneOnly": ("On your phone only", "على هاتفكِ فقط"),
}

PHONE_ONLY = {
    "en": (
        "Your cycle, check-ins, measurements, weight, life stage and allergies "
        "are on your phone unless you turned on health backup. We do not hold "
        "them, and you can see them in the app."
    ),
    "ar": (
        "دورتكِ ومتابعاتكِ اليومية وقياساتكِ ووزنكِ ومرحلتكِ وحساسيتكِ الغذائية "
        "موجودة على هاتفكِ ما لم تفعّلي النسخ الاحتياطي الصحي. لا نحتفظ بها، "
        "ويمكنكِ رؤيتها في التطبيق."
    ),
}

USER_SUBCOLLECTIONS = {
    2: "weeks",
    3: "checkins",
    4: "sessions",
    5: "meals",
    6: "bests",
    7: "measurements",
    8: "devices",
    10: "consents",
    11: "notices",
    12: "firstWeek",
    13: "eatPrefs",
    14: "mealPlans",
    15: "notifications",
    16: "blocks",
    18: "blockedBy",
    19: "myReports",
    32: "awards",
    35: "cycle",
    36: "periods",
    37: "splits",
    38: "private",
}


class Reader(Protocol):
    def auth_record(self, uid: str) -> Optional[dict]: ...
    def user_doc(self, uid: str) -> Optional[dict]: ...
    def subcollection(self, uid: str, name: str) -> dict: ...
    def where_uid(self, collection: str, uid: str) -> dict: ...
    def doc(self, collection: str, doc_id: str) -> Optional[dict]: ...
    def plans(self, uid: str, name: str) -> dict: ...
    def access_for_flags(self, flag_ids: list) -> list: ...


def _plain(value: Any) -> Any:
    """JSON-safe: dates as ISO-8601, everything else as itself."""
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=dt.timezone.utc)
        return value.isoformat()
    if isinstance(value, dt.date):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(k): _plain(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_plain(v) for v in value]
    if isinstance(value, (bytes, bytearray)):
        return None
    return value


# Fields kept off the copy because they are security controls or raw
# identifiers, not data about her. Pending counsel on reason codes.
_DROPPED_FIELDS = {"pepper_version", "schemaV", "provider_ids", "spent_micro_usd"}


def _clean(doc: Optional[dict]) -> Optional[dict]:
    if doc is None:
        return None
    return {k: _plain(v) for k, v in doc.items() if k not in _DROPPED_FIELDS}


def check_coverage(rows=None) -> list[int]:
    """Manifest rows that are neither exported nor excluded. Empty is right."""
    rows = rows if rows is not None else manifest.ROWS
    return [r.number for r in rows if r.number not in SECTIONS and r.number not in EXPORT_EXCLUSIONS]


def build_export(uid: str, reader: Reader, language: str = "en", now: Optional[dt.datetime] = None) -> dict:
    """The whole copy, as one JSON-ready dict."""
    missing = check_coverage()
    if missing:
        raise RuntimeError(f"manifest rows {missing} are neither exported nor excluded")
    lang = "ar" if language == "ar" else "en"
    now = now or dt.datetime.now(dt.timezone.utc)

    sections: dict[str, dict] = {}

    def section(name: str) -> dict:
        if name not in sections:
            sections[name] = {
                "source": sorted(n for n, s in SECTIONS.items() if s == name),
                "retention": RETENTION[name][lang],
                "data": {},
            }
        return sections[name]["data"]

    auth = reader.auth_record(uid) or {}
    section("account").update(
        {
            "uid": uid,
            "phoneNumber": auth.get("phoneNumber"),
            "createdAt": _plain(auth.get("createdAt")),
            "lastSignInAt": _plain(auth.get("lastSignInAt")),
        }
    )

    user = _clean(reader.user_doc(uid)) or {}
    profile = dict(user.get("profile") or {})
    health_profile = {k: profile.pop(k) for k in ("lifeStage", "allergies") if k in profile}
    verification_map = user.pop("verification", None)
    user["profile"] = profile
    section("settings").update({"user": user, "private": {}})

    subs = {number: reader.subcollection(uid, name) for number, name in USER_SUBCOLLECTIONS.items()}
    section("settings")["private"] = {k: _clean(v) for k, v in subs[38].items()}
    section("agreements").update({k: _clean(v) for k, v in subs[10].items()})

    jobs = reader.where_uid("verificationJobs", uid)
    flags = reader.where_uid("verification_flags", uid)
    section("verification").update(
        {
            "state": _plain(verification_map),
            "checks": {k: _clean(v) for k, v in jobs.items()},
            "reviews": {k: _clean(v) for k, v in flags.items()},
        }
    )

    registry = reader.where_uid("nidRegistry", uid)
    section("identityCode").update(
        {"state": next((v.get("state") for v in registry.values()), None) if registry else None}
    )

    behaviour = {}
    for id_hmac in registry:
        doc = reader.doc("verificationBehaviour", id_hmac)
        if doc is not None:
            behaviour = {"failures": doc.get("failures", 0), "updatedAt": _plain(doc.get("updatedAt"))}
    section("fraudSignals").update(
        {
            "failedAttempts": behaviour or None,
            "installation": "Exported only when you give us your installation code.",
        }
    )

    access = reader.access_for_flags(sorted(flags))
    section("reviewAccess").update(
        {"entries": [{"by": "a reviewer", "action": a.get("action"), "at": _plain(a.get("at"))} for a in access]}
    )

    section("attempts").update(_clean(reader.doc("verificationLedger", uid)) or {})

    for number, name in USER_SUBCOLLECTIONS.items():
        target = SECTIONS.get(number)
        if target in ("training", "food", "healthCloud", "notifications", "safety", "devices"):
            section(target)[name] = {k: _clean(v) for k, v in subs[number].items()}
    if health_profile:
        section("healthCloud")["profile"] = _plain(health_profile)

    section("plans").update(
        {
            "versions": {k: _clean(v) for k, v in reader.plans(uid, "versions").items()},
            "assignments": {k: _clean(v) for k, v in reader.plans(uid, "assignments").items()},
        }
    )

    return {
        "schema": SCHEMA,
        "generatedAt": now.isoformat(),
        "language": lang,
        "sections": sections,
        "phoneOnly": PHONE_ONLY[lang],
        "excluded": {str(n): reason for n, reason in sorted(EXPORT_EXCLUSIONS.items())},
        "labels_ar": {k: v[1] for k, v in LABELS.items()},
    }


def summary_html(export: dict) -> str:
    """The readable summary: one heading per section, no script of any kind."""
    lang = export["language"]
    rtl = lang == "ar"
    title = "نسخة من بياناتكِ في Own Hub" if rtl else "A copy of your Own Hub data"
    count_word = "عدد السجلات" if rtl else "records"
    keep_word = "مدة الاحتفاظ" if rtl else "Kept"
    parts = [
        "<!DOCTYPE html>",
        f'<html lang="{lang}" dir="{"rtl" if rtl else "ltr"}">',
        '<head><meta charset="utf-8">',
        f"<title>{html.escape(title)}</title></head>",
        "<body>",
        f"<h1>{html.escape(title)}</h1>",
        f"<p>{html.escape(export['generatedAt'])}</p>",
    ]
    for name, body in export["sections"].items():
        label = LABELS.get(name, (name, name))[1 if rtl else 0]
        data = body["data"]
        records = sum(len(v) if isinstance(v, (dict, list)) else 1 for v in data.values() if v)
        parts.append(f"<h2>{html.escape(label)}</h2>")
        parts.append(f"<p>{html.escape(keep_word)}: {html.escape(body['retention'])}</p>")
        parts.append(f"<p>{records} {html.escape(count_word)}</p>")
    parts.append(f"<h2>{html.escape(LABELS['phoneOnly'][1 if rtl else 0])}</h2>")
    parts.append(f"<p>{html.escape(export['phoneOnly'])}</p>")
    parts.append("</body></html>")
    return "\n".join(parts) + "\n"


class FirestoreReader:
    """The live reader, over the Admin SDK."""

    def __init__(self, db):
        self.db = db

    def auth_record(self, uid):
        from firebase_admin import auth

        try:
            user = auth.get_user(uid)
        except Exception:
            return None
        meta = user.user_metadata
        to_dt = lambda ms: dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc) if ms else None  # noqa: E731
        return {
            "phoneNumber": user.phone_number,
            "createdAt": to_dt(meta.creation_timestamp),
            "lastSignInAt": to_dt(meta.last_sign_in_timestamp),
        }

    def user_doc(self, uid):
        snap = self.db.collection("users").document(uid).get()
        return snap.to_dict() if snap.exists else None

    def subcollection(self, uid, name):
        ref = self.db.collection("users").document(uid).collection(name)
        return {s.id: s.to_dict() or {} for s in ref.stream()}

    def where_uid(self, collection, uid):
        query = self.db.collection(collection).where("uid", "==", uid)
        return {s.id: s.to_dict() or {} for s in query.stream()}

    def doc(self, collection, doc_id):
        snap = self.db.collection(collection).document(doc_id).get()
        return snap.to_dict() if snap.exists else None

    def plans(self, uid, name):
        ref = self.db.collection("plans").document(uid).collection(name)
        return {s.id: s.to_dict() or {} for s in ref.stream()}

    def access_for_flags(self, flag_ids):
        out = []
        for i in range(0, len(flag_ids), 10):
            chunk = flag_ids[i : i + 10]
            if not chunk:
                continue
            query = self.db.collection("verificationReviewAccess").where("flagId", "in", chunk)
            out.extend(s.to_dict() or {} for s in query.stream())
        return out


def write_files(export: dict, folder: str) -> tuple[str, str]:
    """Both files into a NEW folder, readable only by the owner."""
    os.makedirs(folder, mode=0o700, exist_ok=False)
    day = export["generatedAt"][:10]
    data_path = os.path.join(folder, f"ownhub-data-{day}.json")
    summary_path = os.path.join(folder, f"summary-{export['language']}.html")
    for path, text in (
        (data_path, json.dumps(export, ensure_ascii=False, indent=2) + "\n"),
        (summary_path, summary_html(export)),
    ):
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(text)
    return data_path, summary_path


def main(argv=None, *, reader=None, out=print) -> int:
    parser = argparse.ArgumentParser(prog="export_user")
    parser.add_argument("uid")
    parser.add_argument("--lang", choices=("en", "ar"), default="en")
    parser.add_argument("--out", required=True, help="a NEW folder outside this repository")
    args = parser.parse_args(argv)

    if reader is None:
        from tools.export_waitlist import _require_adc

        _require_adc()
        import firebase_admin
        from google.cloud import firestore

        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        reader = FirestoreReader(
            firestore.Client(project=os.environ.get("GOOGLE_CLOUD_PROJECT", "own-hub"))
        )

    export = build_export(args.uid, reader, args.lang)
    data_path, summary_path = write_files(export, os.path.expanduser(args.out))
    out(f"written {data_path} and {summary_path}; delete them once delivered")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
