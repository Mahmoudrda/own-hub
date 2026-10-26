# WO-04d: weekly check-in on the server (C3, part 1)
Depends on: none (WO-04g adds the "health flag" input this list also reads; this order works without it)
Size: L
Reads first: `functions/coaching/subscriptions.py` lines 25-35 (`system_message`) and 700-800 (`_warn`, the sweeper); `functions/coaching/push.py` lines 1-25 and 72-110; `functions/coaching/__init__.py` (whole); `functions/main.py` lines 1798-1818 (`create_coach_invite`, the callable pattern), 1865-1875 (`_coaching_notify`) and the sweeper `coaching_sweeper` (`grep -n "def coaching_sweeper" functions/main.py`); `functions/tests/test_coaching_free.py` lines 1-60 (how a test builds a coach, a client and an active subscription)

## Why
Rahma's retention tool is a weekly check-in: short, answered with taps, reviewed in one list. Nothing exists (`checkInsPerWeek` is only a number on a package, `functions/coaching/packages.py:26,57`). The carrier is the thread she already uses: once a week the server writes a card into the chat and sends one push. The client answers in under a minute (WO-04e). The server stores the answers where only the two parties' callables can read them, and builds Rahma's "Needs attention" list.
Honest limit, say it in the report: the server cannot see a client's workout logs (they stay on her phone), so "missed 2 or more sessions" means what the client says in the check-in ("How did your training go?": all / most / some / none; "some" or "none" counts).

## Final result
- Every Friday 09:00 Cairo time, each ACTIVE coaching whose package has `checkInsPerWeek` of 1 or more gets: a document `relationships/{relId}/checkIns/{weekKey}` (state `open`, `weekKey` like `2026-W44`), one system message in the thread (`systemKind: "checkIn"`, with `weekKey`), and one push to the client: EN "Your weekly check-in is ready. It takes under a minute." / AR "التشيك إن الأسبوعي جاهز. بياخد أقل من دقيقة."
- Every Monday 09:00 Cairo time, a check-in from last week still `open` gets ONE follow-up push (never a second): EN "No rush. Last week's check-in is still here when you are ready." / AR "من غير استعجال. التشيك إن بتاع الأسبوع اللي فات لسه موجود وقت ما تحبي." No guilt wording, no streak, no count of misses.
- Callable `submit_check_in` `{relId, weekKey, answers}` -> `{ok: true}`. `answers`: `training` one of `all|most|some|none`; `energy` 1 to 5; `food` 1 to 5; `pain` true/false (any pain or injury this week); `note` text up to 300 characters (may be empty).
- Callable `coach_needs_attention` `{}` -> `{clients: [{subId, relId, clientName, reasons: [...]}]}` for the coach's active clients that have at least one reason: `noCheckIn`, `missedSessions`, `healthFlag`, `unread`. Most reasons first.
- Everything is behind a new switch `CHECK_INS_LIVE = False` in `functions/coaching/__init__.py`. Reason: build 1.0.0 on women's phones does not know `systemKind: "checkIn"` and would show its "This message was hidden" line (`chat_logic.dart:252`, null kind). The owner turns the switch on after the app update is in the stores. The two callables answer `coach_app_closed` while it is False; the two schedulers do nothing.

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `functions/coaching/checkins.py` | create | all the logic |
| `functions/coaching/__init__.py` | edit | `CHECK_INS_LIVE = False` |
| `functions/coaching/push.py` | edit | two push kinds |
| `contracts/coaching_contract.json` and `functions/coaching/coaching_contract.json` | edit (identical copies) | `checkIn` in `systemMessageKinds`, two push kinds, two callable names |
| `functions/main.py` | edit | two callables and two schedulers |
| `firebase/firestore.rules` | edit | `checkIns` subcollection closed to clients |
| `functions/tests/test_coaching_checkins.py` | create | tests |

## Steps
1. File `functions/coaching/__init__.py`, end of file, add:
```python
# The weekly check-in card, its push and the coach's "Needs attention" list.
# Stays False until the app version that renders `systemKind: "checkIn"` is in
# both stores: older builds show an unknown system line as a hidden message.
CHECK_INS_LIVE = False
```
2. File `functions/coaching/push.py`, inside the `TEXT` dict after the `"endsSoon"` entry (about line 57), add:
```python
    "checkInDue": {
        "en": (TITLE, "Your weekly check-in is ready. It takes under a minute."),
        "ar": (TITLE, "التشيك إن الأسبوعي جاهز. بياخد أقل من دقيقة."),
    },
    "checkInFollowUp": {
        "en": (TITLE, "No rush. Last week's check-in is still here when you are ready."),
        "ar": (TITLE, "من غير استعجال. التشيك إن بتاع الأسبوع اللي فات لسه موجود وقت ما تحبي."),
    },
```
UNVERIFIED: whether `push.py` also keeps a per-kind throttle or a category table that must list the new kinds. Run `sed -n 78,140p functions/coaching/push.py` and `grep -n "newMessage" functions/coaching/push.py functions/coaching/*.json`. If `send_kind` looks the kind up in a second table, add the two kinds there with no throttle.
3. Both contract JSON files (`contracts/coaching_contract.json` and `functions/coaching/coaching_contract.json` are byte-identical today: `diff` printed nothing; keep them identical). In `"systemMessageKinds"` (line 301) add `"checkIn"` before `"hidden"`. In the push kinds list (the one holding `"endsSoon"` at line 401) add `"checkInDue"` and `"checkInFollowUp"` after `"endsSoon"`. Also mirror both in `app/lib/features/private_coaching/domain/coaching_contract.dart`: the `systemMessageKinds` list (line 310) and the push list (about line 398) the same way. (The enum `SystemMessageKind` is changed in WO-04e.) Run `cd app && flutter test test/contracts/coaching_contract_test.dart` after this step; it compares the lists, so it fails until all four places agree.
4. Create `functions/coaching/checkins.py`:
```python
"""C3: the weekly check-in.

`relationships/{relId}/checkIns/{weekKey}` is written only here (firestore.rules
closes it to clients). Each week an ACTIVE coaching gets an `open` card, a system
message in the thread and one push; the client answers once; the coach's
"Needs attention" list reads the answers. The server never sees workout logs,
so "missed sessions" is the client's own answer.
"""

from __future__ import annotations

import datetime as dt
from typing import Callable

from . import common, errors

COLLECTION = "checkIns"
TRAINING = ("all", "most", "some", "none")
NOTE_MAX = 300
LATE_AFTER_DAYS = 3
MAX_LIST = 50
_ANSWER_KEYS = {"training", "energy", "food", "pain", "note"}


def week_key(now: dt.datetime) -> str:
    iso = now.isocalendar()
    return f"{iso[0]}-W{iso[1]:02d}"


def _ref(db, rel_id: str, key: str):
    return db.collection("relationships").document(rel_id).collection(COLLECTION).document(key)


def _answers(raw) -> dict:
    if not isinstance(raw, dict) or set(raw) - _ANSWER_KEYS:
        raise common.bad()
    if not isinstance(raw.get("pain"), bool):
        raise common.bad()
    return {
        "training": common.one_of(raw.get("training"), TRAINING),
        "energy": common.whole(raw.get("energy"), low=1, high=5),
        "food": common.whole(raw.get("food"), low=1, high=5),
        "pain": raw["pain"],
        "note": common.optional_text(raw.get("note"), max_len=NOTE_MAX),
    }


def _open_card(db, row: dict, key: str, now: dt.datetime) -> bool:
    ref = _ref(db, row["relId"], key)
    messages = db.collection("relationships").document(row["relId"]).collection("messages")

    def body(transaction):
        if common.read(ref, transaction) is not None:
            return False  # this week's card already exists: the job is safe to run twice
        transaction.set(
            ref,
            {
                "clientUid": row["clientUid"],
                "coachUid": row["coachUid"],
                "weekKey": key,
                "state": "open",
                "createdAt": now,
            },
        )
        transaction.set(
            messages.document(),
            {"senderUid": "system", "type": "system", "systemKind": "checkIn", "weekKey": key, "createdAt": now},
        )
        return True

    return common.run(db, body)


def _active(db):
    for snap in db.collection("subscriptions").where("status", "==", "active").stream():
        row = snap.to_dict() or {}
        if all(isinstance(row.get(k), str) and row[k] for k in ("relId", "clientUid", "coachUid")):
            yield snap.id, row


def send_cards(db, now: dt.datetime, notify: Callable[[str, str], None]) -> int:
    """Friday job. Returns how many cards it opened."""
    key = week_key(now)
    opened = 0
    for _sub_id, row in _active(db):
        per_week = (row.get("package") or {}).get("checkInsPerWeek")
        if not isinstance(per_week, int) or isinstance(per_week, bool) or per_week < 1:
            continue
        if _open_card(db, row, key, now):
            notify(row["clientUid"], "checkInDue")
            opened += 1
    return opened


def follow_up(db, now: dt.datetime, notify: Callable[[str, str], None]) -> int:
    """Monday job: ONE kind push for last week's card still open."""
    key = week_key(now - dt.timedelta(days=7))
    sent = 0
    for _sub_id, row in _active(db):
        ref = _ref(db, row["relId"], key)

        def body(transaction, ref=ref):
            card = common.read(ref, transaction)
            if card is None or card.get("state") != "open" or card.get("followUpAt"):
                return False
            transaction.update(ref, {"followUpAt": now})
            return True

        if common.run(db, body):
            notify(row["clientUid"], "checkInFollowUp")
            sent += 1
    return sent


def submit(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    """The client answers her open card once."""
    common.require_clients_live(live)
    rel_id = common.text(data.get("relId"), max_len=128)
    key = common.text(data.get("weekKey"), max_len=16)
    answers = _answers(data.get("answers"))
    ref = _ref(db, rel_id, key)

    def body(transaction):
        card = common.read(ref, transaction)
        if card is None or card.get("clientUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if card.get("state") != "open":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, {"state": "answered", "answers": answers, "answeredAt": now})
        return {"ok": True}

    return common.run(db, body)


def needs_attention(db, coach_uid: str, *, live: bool, coach_v, now: dt.datetime) -> dict:
    common.require_clients_live(live)
    common.require_active_coach(db, coach_uid, coach_v)
    this_week = week_key(now)
    last_week = week_key(now - dt.timedelta(days=7))
    out = []
    for snap in db.collection("subscriptions").where("coachUid", "==", coach_uid).stream():
        row = snap.to_dict() or {}
        if row.get("status") != "active" or not row.get("relId"):
            continue
        reasons = []
        rel = db.collection("relationships").document(row["relId"])
        cards = {k: rel.collection(COLLECTION).document(k).get() for k in (this_week, last_week)}
        cards = {k: (s.to_dict() or {}) for k, s in cards.items() if s.exists}
        late = cards.get(last_week, {}).get("state") == "open"
        current = cards.get(this_week, {})
        created = current.get("createdAt")
        if current.get("state") == "open" and isinstance(created, dt.datetime):
            late = late or (now - _aware(created)) > dt.timedelta(days=LATE_AFTER_DAYS)
        if late:
            reasons.append("noCheckIn")
        answered = [c for c in cards.values() if c.get("state") == "answered"]
        latest = max(answered, key=lambda c: _aware(c.get("answeredAt")), default=None) if answered else None
        if latest and (latest.get("answers") or {}).get("training") in ("some", "none"):
            reasons.append("missedSessions")
        intake = row.get("intake") or {}
        if any((intake.get("health") or {}).values()) and not row.get("healthReviewedAt"):
            reasons.append("healthFlag")  # WO-04g sets healthReviewedAt
        elif latest and (latest.get("answers") or {}).get("pain") is True:
            reasons.append("healthFlag")
        unread = ((rel.get().to_dict() or {}).get("unreadFor") or {}).get(coach_uid, 0)
        if isinstance(unread, int) and unread > 0:
            reasons.append("unread")
        if reasons:
            out.append(
                {"subId": snap.id, "relId": row["relId"], "clientName": row.get("clientName", ""), "reasons": reasons}
            )
    out.sort(key=lambda c: (-len(c["reasons"]), c["clientName"]))
    return {"clients": out[:MAX_LIST]}


def _aware(value) -> dt.datetime:
    if not isinstance(value, dt.datetime):
        return dt.datetime.min.replace(tzinfo=dt.timezone.utc)
    return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)
```
UNVERIFIED helper names: `common.require_clients_live`, `common.require_active_coach`, `common.whole`, `common.one_of`, `common.optional_text`, `common.read`, `common.run`, `common.refuse`, `common.bad`, `common.text` are all used in `plans.py`/`subscriptions.py` (read in this session) with these signatures. `errors.REQUEST_NOT_FOUND`, `errors.WRONG_STATUS`, `errors.NOT_FOUND`, `errors.PRECONDITION` are used there too. Confirm with `grep -n "^def \|^[A-Z_]* = " functions/coaching/common.py functions/coaching/errors.py | head -80`. UNVERIFIED: `package.checkInsPerWeek` is copied into the subscription (`PACKAGE_KEYS`, `subscriptions.py:~305` copies `pack[key]` for `PACKAGE_KEYS`). Run `grep -n "PACKAGE_KEYS" functions/coaching/subscriptions.py | head -3` and `grep -n "checkInsPerWeek" functions/coaching/packages.py`; if `checkInsPerWeek` is not in `PACKAGE_KEYS`, stop and ask (QUESTIONS.md).
5. File `functions/main.py`, after `accept_coach_invite` (ends about line 1840) add:
```python
@https_fn.on_call()
def submit_check_in(request: https_fn.CallableRequest) -> dict:
    """C3: the client answers her weekly check-in. `{relId, weekKey, answers}`."""
    uid = _require_auth(request)
    data = _body(request)
    import datetime as dt

    import coaching
    from coaching import checkins

    return _coaching_call(
        checkins.submit,
        store.db(),
        uid,
        data,
        live=coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE,
        now=dt.datetime.now(dt.timezone.utc),
    )


@https_fn.on_call()
def coach_needs_attention(request: https_fn.CallableRequest) -> dict:
    """C3: the coach's clients that need a look. `{}` in, `{clients}` out."""
    uid = _require_auth(request)
    _body(request)
    import datetime as dt

    import coaching
    from coaching import checkins

    return _coaching_call(
        checkins.needs_attention,
        store.db(),
        uid,
        live=coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE,
        coach_v=_claim(request, "coachV"),
        now=dt.datetime.now(dt.timezone.utc),
    )


@scheduler_fn.on_schedule(schedule="0 9 * * 5", timezone="Africa/Cairo", region=config.REGION)
def send_weekly_check_ins(event: scheduler_fn.ScheduledEvent) -> None:
    """Friday 09:00 Cairo: the weekly check-in card and push. Safe to run twice."""
    import datetime as dt

    import coaching
    from coaching import checkins

    if not (coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE):
        return
    count = checkins.send_cards(store.db(), dt.datetime.now(dt.timezone.utc), _coaching_notify)
    logs.decision("send_weekly_check_ins", outcome="sent", count=count)


@scheduler_fn.on_schedule(schedule="0 9 * * 1", timezone="Africa/Cairo", region=config.REGION)
def check_in_follow_up(event: scheduler_fn.ScheduledEvent) -> None:
    """Monday 09:00 Cairo: one kind follow-up for last week's open card."""
    import datetime as dt

    import coaching
    from coaching import checkins

    if not (coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE):
        return
    count = checkins.follow_up(store.db(), dt.datetime.now(dt.timezone.utc), _coaching_notify)
    logs.decision("check_in_follow_up", outcome="sent", count=count)
```
UNVERIFIED: the `timezone=` argument and `logs.decision(name, outcome=..., count=...)` signature (used at `main.py` ~1360 with `outcome=decisions.RETRY_REQUIRED`; a plain string may be refused by a validator). Run `grep -n "def decision" -A12 functions/logs.py` (or the module `logs` in `functions/`) and, if `outcome` must come from `decisions`, use `logs.error`-free alternative: drop the `logs.decision` line. Check the signature: `cd functions && python3 -c "from firebase_functions import scheduler_fn; import inspect; print(inspect.signature(scheduler_fn.on_schedule))"` must list `timezone`.
6. File `firebase/firestore.rules`: UNVERIFIED location: `grep -n "match /relationships/{relId}" firebase/firestore.rules`. Inside that match, next to the existing `messages` match, add:
```
      match /checkIns/{weekKey} {
        allow read, write: if false;
      }
```
7. Create `functions/tests/test_coaching_checkins.py` (see table). Follow `test_coaching_free.py` for building rows with `fake_firestore`; import `_txn` from `tests.coaching_helpers` by name, as that file does.

## Strings to add
Server push texts only (step 2, EN and AR given). No app strings here.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `functions/tests/test_coaching_checkins.py` | `friday_opens_one_card_a_message_and_a_push_per_active_coaching` | Arrange: two active subscriptions with `package.checkInsPerWeek` 1 and one ended, one active with 0. Act: `checkins.send_cards(db, FRIDAY, pushes)`. Assert: returns 2; each relationship has `checkIns/2026-W44` with state `open`; each thread has one message with `systemKind == "checkIn"`; `pushes == [(client1,"checkInDue"), (client2,"checkInDue")]` |
| same | `running_friday_twice_adds_nothing` | call `send_cards` twice; second returns 0; one message only |
| same | `monday_follow_up_is_sent_once_and_only_for_an_open_card` | Friday cards, one answered; Monday `follow_up` returns 1; a second Monday call returns 0 |
| same | `the_client_answers_once_with_checked_values` | `submit` ok; state `answered`; second `submit` refused (`refusal(...)` helper from `coaching_helpers`) with `(errors.PRECONDITION, errors.WRONG_STATUS)`; another uid refused NOT_FOUND; `energy: 6`, `training: "x"`, `pain: "no"`, an extra key, a 301 character note each raise `common.bad()` |
| same | `needs_attention_lists_reasons` | one client with training `none`, one with an open card created 4 days ago, one with `unreadFor.{coach}` 2, one with `intake.health.heart` true and no `healthReviewedAt`, one clean. Assert exact reasons per client, the clean one absent, order most reasons first |
| same | `switch_off_refuses_and_schedulers_do_nothing` | `submit(..., live=False)` raises coach_app_closed; assert `CHECK_INS_LIVE is False` in `coaching/__init__.py` |
Run: `cd functions && python3 -m pytest tests/test_coaching_checkins.py tests/test_coaching_contract.py tests/test_coaching_push.py -q`

## Verify
- That command prints `passed` with no failures.
- `cd app && flutter test test/contracts/coaching_contract_test.dart` passes.
- `cd firebase && ` the Firestore rules test command used in the repo (UNVERIFIED: `grep -n "rules" package.json firebase/package.json 2>/dev/null`) passes with the new match.

## Do not
- Do not set `CHECK_INS_LIVE = True`. Do not add a streak, a miss count or the word "missed" to any push or card text. Do not deploy.
- Do not store the check-in answers anywhere the client SDK can read; rules stay closed.
- Do not change the throttle of `newMessage` pushes.

## Done checklist
- [ ] module, switch, push texts, both contract copies and the Dart lists agree
- [ ] two callables and two schedulers in `main.py`
- [ ] rules match added
- [ ] tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
