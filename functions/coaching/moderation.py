"""Reports about coaching content, and what a reviewer does with them.

A member reports a coach's message, profile or plan by creating a document in
`reports/` (the existing client rule). Staff never read that collection
directly: they go through `list_for_staff`, which shows each report with a
snapshot of what was reported, and `decide`, which records the decision and
does what it says. Every call leaves one line in the staff access log.

`subjectRef` is written by the reporter, so it is only followed when it has
exactly the shape its `subjectKind` allows, and only whitelisted fields of the
subject are returned.

The report only holds a pointer, and the message, plan or page can change or
go (a hidden message loses its text, ending a coaching deletes the thread). So
when a report is created `capture_evidence` copies what was reported to
`reports/{id}/evidence/content`, which no client rule opens. It holds no account
ids, and staff see it through `list_for_staff` when the live subject is gone.
"""

from __future__ import annotations

import datetime as dt
from typing import Any, Callable, Optional

from . import common, errors
from .chat import AUTO_REPORTER

ENUMS = common.ENUMS
PAGE_SIZE = 25
STATES = ("submitted", "decided")
NOTE_MAX = 500
_BATCH = 100
_MAX_BATCHES = 20


def _segments(ref: Any, shape: tuple) -> Optional[list]:
    """The ids in `ref` when it reads like `shape` (a "*" is an id), else None."""
    if not isinstance(ref, str) or len(ref) > 400:
        return None
    parts = ref.split("/")
    if len(parts) != len(shape):
        return None
    ids = []
    for part, want in zip(parts, shape):
        if want == "*":
            if not part or part in (".", ".."):
                return None
            ids.append(part)
        elif part != want:
            return None
    return ids


_SHAPES = {
    "coachMessage": ("relationships", "*", "messages", "*"),
    "coachProfile": ("coaches", "*"),
    "coachPlan": ("plans", "*", "coachPlans", "*"),
}


def _target(report: dict) -> Optional[tuple[str, list]]:
    kind = report.get("subjectKind")
    if kind not in _SHAPES:
        return None
    ids = _segments(report.get("subjectRef"), _SHAPES[kind])
    return None if ids is None else (kind, ids)


def _party(kind: str, ids: list, reporter: Any, row: dict) -> bool:
    """Whether the reporter is one of the people the subject was shared with.
    `row` is the message's relationship or the plan, already read. A coach
    page is public, so anyone may have seen it."""
    if kind == "coachProfile":
        return True
    if not isinstance(reporter, str) or not reporter:
        return False
    if reporter == AUTO_REPORTER:
        return kind == "coachMessage"  # the hidden message holds no words
    if kind == "coachMessage":
        return reporter in (row.get("coachUid"), row.get("clientUid"))
    return reporter in (ids[0], row.get("coachUid"))


def _snapshot(db, kind: str, ids: list, reporter: Any = None) -> dict:
    """What the reviewer needs to see of the subject, and nothing more. What a
    private chat or plan says is shown only when the reporter was part of it."""
    if kind == "coachMessage":
        row = db.document(f"relationships/{ids[0]}/messages/{ids[1]}").get().to_dict()
        if row is None:
            return {"missing": True}
        rel = db.document(f"relationships/{ids[0]}").get().to_dict() or {}
        if not _party(kind, ids, reporter, rel):
            return {"notParty": True}
        out = {"type": row.get("type"), "hidden": row.get("hidden") is True}
        if isinstance(row.get("text"), str):
            out["text"] = row["text"]
        if isinstance(row.get("recipeId"), str):
            out["recipeId"] = row["recipeId"]
        if isinstance(row.get("mediaPath"), str):
            # The file stays where it is (the sender cannot delete it, storage
            # rules); only its name is copied, never the folder that names both.
            out["mediaFile"] = row["mediaPath"].rsplit("/", 1)[-1]
            if isinstance(row.get("durationMs"), int) and not isinstance(row.get("durationMs"), bool):
                out["durationMs"] = row["durationMs"]
        return out
    if kind == "coachProfile":
        row = db.document(f"coaches/{ids[0]}").get().to_dict()
        if row is None:
            return {"missing": True}
        return {"displayName": row.get("displayName"), "headline": row.get("headline")}
    row = db.document(f"plans/{ids[0]}/coachPlans/{ids[1]}").get().to_dict()
    if row is None:
        return {"missing": True}
    if not _party(kind, ids, reporter, row):
        return {"notParty": True}
    return {"name": row.get("name"), "kind": row.get("kind")}


EVIDENCE_PATH = "evidence/content"


_LINKING_KEYS = {"subid", "relid", "relationshipid", "clientid", "coachid"}


def _without_ids(value: Any) -> Any:
    """A copy with every field that names an account or links to one taken out:
    the `*uid` fields, the coaching (`subId`) and the relationship id (which is
    both uids)."""
    if isinstance(value, dict):
        return {
            k: _without_ids(v)
            for k, v in value.items()
            if not str(k).lower().endswith("uid") and str(k).lower() not in _LINKING_KEYS
        }
    if isinstance(value, list):
        return [_without_ids(v) for v in value]
    return value


def capture_evidence(db, report_id: str, report: dict, *, now: dt.datetime) -> bool:
    """Copies what the report points at, as it is now. Returns False when the
    report has no followable subject or the reporter was not part of it. Safe
    to run twice: the first copy stays."""
    target = _target(report)
    if target is None:
        return False
    kind, ids = target
    ref = db.document(f"reports/{report_id}/{EVIDENCE_PATH}")
    if ref.get().exists:
        return True
    subject = _snapshot(db, kind, ids, report.get("reporterUid"))
    if subject.get("notParty") or subject.get("missing"):
        return False
    content: dict = {"subjectKind": kind, "capturedAt": now, "subject": subject}
    if kind == "coachMessage":
        row = _subject_row(db, kind, ids)
        coach = (db.document(f"relationships/{ids[0]}").get().to_dict() or {}).get("coachUid")
        content["sentAt"] = row.get("createdAt")
        content["fromCoach"] = row.get("senderUid") == coach
    elif kind == "coachPlan":
        content["plan"] = _without_ids(_subject_row(db, kind, ids))
    ref.set(content)
    return True


def on_report(db, report_id: str, report: dict, *, now: dt.datetime, per_day: int) -> bool:
    """A report was made: copy what it points at. A reporter past her daily
    limit is marked `throttled`, and her evidence is still copied: a real
    report is never dropped to a flood."""
    if report.get("reporterUid") == AUTO_REPORTER:
        return capture_evidence(db, report_id, report, now=now)
    since = now - dt.timedelta(hours=24)
    mine = db.collection("reports").where("reporterUid", "==", report.get("reporterUid")).where("createdAt", ">=", since)
    if sum(1 for _ in mine.stream()) > per_day:
        db.document(f"reports/{report_id}").update({"throttled": True})
    return capture_evidence(db, report_id, report, now=now)


def _frozen(db, report_id: str) -> Optional[dict]:
    content = db.document(f"reports/{report_id}/{EVIDENCE_PATH}").get().to_dict()
    return content.get("subject") if content else None


def list_for_staff(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    """Coaching reports, oldest first, 25 a page. `after` is the `next` of the
    page before."""
    state = data.get("state", "submitted")
    if state not in STATES:
        raise common.bad()
    after = data.get("after")
    cursor = None
    if after is not None:
        cursor = _parse_cursor(after)
    common.log_access(db, actor_uid, "reports.list", "reports", now)

    picked: list = []
    for kind in ENUMS["reportSubjectKinds"]:
        picked.extend(_collect(db, kind, state, cursor))
    picked.sort(key=lambda row: (row[0], row[1]))

    more = len(picked) > PAGE_SIZE
    page = picked[:PAGE_SIZE]
    items = []
    for created, report_id, report in page:
        target = _target(report)
        items.append(
            {
                "reportId": report_id,
                "subjectKind": report.get("subjectKind"),
                "reason": report.get("reason"),
                **({"subjectRole": report["subjectRole"]} if report.get("subjectRole") in ("coach", "client") else {}),
                "note": report.get("note") if isinstance(report.get("note"), str) else "",
                "state": report.get("state"),
                "createdAt": created.isoformat(),
                "subject": _snapshot(db, *target, report.get("reporterUid")) if target else {"missing": True},
            }
        )
        live = items[-1]["subject"]
        if live.get("missing") or live.get("hidden"):
            frozen = _frozen(db, report_id)
            if frozen:
                items[-1]["atReport"] = frozen
    next_token = None
    if more:
        created, report_id, _ = page[-1]
        next_token = f"{created.isoformat()}|{report_id}"
    return {"items": items, "next": next_token}


def _collect(db, kind: str, state: str, cursor) -> list:
    """Up to PAGE_SIZE + 1 reports of one kind, oldest first, after `cursor`.
    One query per kind uses the (subjectKind, state, createdAt) index."""
    found: list = []
    last = cursor[0] if cursor is not None else None
    op = ">="
    for _ in range(_MAX_BATCHES):
        query = db.collection("reports").where("subjectKind", "==", kind).where("state", "==", state)
        if last is not None:
            query = query.where("createdAt", op, last)
        rows = list(query.order_by("createdAt").limit(_BATCH).stream())
        for row in rows:
            report = row.to_dict() or {}
            created = common.as_utc(report.get("createdAt"))
            if created is None or (cursor is not None and (created, row.id) <= cursor):
                continue
            found.append((created, row.id, report))
        if len(found) > PAGE_SIZE or len(rows) < _BATCH:
            break
        last = common.as_utc((rows[-1].to_dict() or {}).get("createdAt"))
        op = ">"
    return found[: PAGE_SIZE + 1]


def _parse_cursor(token: Any) -> tuple[dt.datetime, str]:
    if not isinstance(token, str) or "|" not in token or len(token) > 200:
        raise common.bad()
    stamp, report_id = token.split("|", 1)
    try:
        moment = dt.datetime.fromisoformat(stamp)
    except ValueError:
        raise common.bad()
    if moment.tzinfo is None or not report_id:
        raise common.bad()
    return moment.astimezone(dt.timezone.utc), report_id


def _not_found() -> errors.CoachingError:
    return common.refuse(errors.NOT_FOUND, errors.REPORT_NOT_FOUND)


def _subject_row(db, kind: str, ids: list) -> dict:
    """The message or plan a report points at (a coach page needs no read)."""
    if kind == "coachMessage":
        return db.document(f"relationships/{ids[0]}/messages/{ids[1]}").get().to_dict() or {}
    if kind == "coachPlan":
        return db.document(f"plans/{ids[0]}/coachPlans/{ids[1]}").get().to_dict() or {}
    return {}


def _relationship_of(db, kind: str, ids: list, row: dict) -> tuple[str, dict]:
    """The relationship the subject belongs to: (relId, its fields)."""
    if kind == "coachMessage":
        rel_id = ids[0]
    elif kind == "coachPlan":
        coach = row.get("coachUid")
        if not isinstance(coach, str) or not coach:
            raise common.bad()
        rel_id = common.rel_id(coach, ids[0])
    else:
        raise common.bad()
    rel = db.collection("relationships").document(rel_id).get().to_dict()
    if rel is None:
        raise common.bad()
    return rel_id, rel


def _coach_of(db, kind: str, ids: list, row: dict) -> str:
    if kind == "coachProfile":
        return ids[0]
    if kind == "coachPlan":
        coach = row.get("coachUid")
    else:
        _, rel = _relationship_of(db, kind, ids, row)
        coach = rel.get("coachUid")
        # A client's message does not put the coach in front of a suspension.
        if row.get("senderUid") != coach:
            raise common.bad()
    if not isinstance(coach, str) or not coach:
        raise common.bad()
    return coach


def _subjects(kind: str, ids: list, row: dict) -> list:
    """The people the subject itself points to, whatever the reporter wrote."""
    if kind == "coachProfile":
        return [ids[0]]
    if kind == "coachPlan":
        return [ids[0], row.get("coachUid")]
    return [row.get("senderUid")]


def decide(
    db,
    actor_uid: str,
    data: dict,
    *,
    now: dt.datetime,
    suspend: Callable[[str], Any],
    end_early: Callable[[str], Any],
) -> dict:
    """Records a reviewer's decision on one report and does what it says."""
    report_id = common.text(data.get("reportId"), max_len=128)
    if "/" in report_id:
        raise common.bad()
    decision = common.one_of(data.get("decision"), ENUMS["reportDecision"])
    common.optional_text(data.get("note"), max_len=NOTE_MAX)  # checked, not kept
    common.log_access(db, actor_uid, "reports.decide", report_id, now)

    report_ref = db.collection("reports").document(report_id)
    report = report_ref.get().to_dict()
    if report is None or report.get("state") == "decided":
        raise _not_found()
    target = _target(report)
    if target is None:
        raise _not_found()
    kind, ids = target
    row = _subject_row(db, kind, ids)
    common.refuse_if_subject(actor_uid, report.get("reporterUid"), report.get("subjectUid"), *_subjects(kind, ids, row))

    hide_ref = None
    if decision == "hide_message":
        if kind != "coachMessage":
            raise common.bad()
        hide_ref = db.document(f"relationships/{ids[0]}/messages/{ids[1]}")
    elif decision == "suspend_coach":
        suspend(_coach_of(db, kind, ids, row))
    elif decision == "end_coaching":
        _, rel = _relationship_of(db, kind, ids, row)
        sub_id = rel.get("activeSubId")
        if not isinstance(sub_id, str) or not sub_id:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        end_early(sub_id)

    def record(transaction):
        # Read again: two reviewers can decide the same report together.
        snapshot = report_ref.get(transaction=transaction)
        current = snapshot.to_dict() if snapshot.exists else None
        if current is None or current.get("state") == "decided":
            raise _not_found()
        message_exists = hide_ref is not None and hide_ref.get(transaction=transaction).exists
        if message_exists:
            transaction.update(hide_ref, {"hidden": True, "text": ""})
        transaction.update(
            report_ref,
            {
                "decision": decision,
                **common.decided_stamp(actor_uid, now),
                "state": "decided",
            },
        )

    common.run(db, record)
    return {"state": "decided"}
