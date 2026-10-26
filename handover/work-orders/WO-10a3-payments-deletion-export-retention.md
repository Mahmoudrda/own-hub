# WO-10a3: InstaPay payments: account deletion keeps a pseudonymised record, screenshots go earlier, export includes her own payments, retention sweep
Depends on: WO-10a2
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.15, 12.4, 13.3 (privacy), 13.13 item 6; `functions/account/deletion.py` lines 424-440 and 499-518 (about); `functions/account/deletion.py` lines 125-140 (`Backend` protocol) and 318-335 (`delete_storage_prefix`); `functions/tools/export_user.py` lines 352-366 and 455-500 (about); `functions/tests/test_deletion_coaching.py` lines 95-110 and 195-210; `functions/main.py` lines 2445-2470 (`coaching_sweeper`)

## Why
A woman's transaction numbers and screenshots are financial data about her (spec 4.15). When she deletes her account the payment record stays, with her id replaced by a token, because the law asks for it for a period (owner and counsel set it; UNVERIFIED, so it is a named constant). Her screenshots are removed earlier than the record. She can download her own payments in her data export. A weekly job removes screenshots of payments that finished long ago.

## Final result
- Deleting an account: every `payments` document where she is `clientUid` or `coachUid` gets her id replaced by `deleted-...` (the same token the other rows use); if she was the coach her `addressSnapshot.accountName` is emptied; her screenshots under `payment-proofs/{paymentId}/` are deleted in the personal bucket; `paymentStrikes` rows naming her get the token; `coachPaymentProfiles/{uid}` and `paymentStanding/{uid}` are deleted; her `paymentIdempotency` rows are deleted by a query on their `uid` field.
- Export: the file has a `payments` section with her payments (as client or coach), events removed, no staff data.
- Weekly job `payments_retention`: deletes screenshots of payments finished more than `SCREENSHOT_RETENTION_DAYS` (90) days ago with no open dispute, and sets `proof.screenshotsDeletedAt`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/account/deletion.py` | edit | `_pseudonymise_coaching_money` also handles payments |
| `functions/tools/export_user.py` | edit | reader and builder carry `payments` |
| `functions/payments/retention.py` | create | `sweep_screenshots`, constants |
| `functions/main.py` | edit | scheduled `payments_retention` |
| `functions/tests/test_deletion_coaching.py` | edit | one test |
| `functions/tests/test_export_user.py` | edit | one test |
| `functions/tests/test_payments_retention.py` | create | retention tests |

## Steps
1. File `functions/payments/retention.py`, create:
```python
"""How long a payment's pictures and record are kept. Counsel confirms both
numbers (spec 12.4); until then these are the defaults and the only place they live."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import model

SCREENSHOT_RETENTION_DAYS = 90      # UNVERIFIED with counsel
RECORD_RETENTION_YEARS = 5          # UNVERIFIED with counsel; nothing deletes the record in this release

FINISHED = ("confirmed", "resolved_paid", "resolved_unpaid", "refunded", "cancelled")


def paths_of(payment_id: str, payment: dict) -> list[str]:
    return list(((payment.get("proof") or {}).get("screenshotPaths")) or []) + list(
        ((payment.get("coachDecision") or {}).get("statementPaths")) or []
    )


def sweep_screenshots(db, *, now: dt.datetime, blobs) -> int:
    """Deletes the pictures of payments finished for longer than the retention
    period. A payment under review keeps them. Returns how many payments were
    cleaned. A failed delete leaves the pointer in place, so the next run retries."""
    cutoff = now - model.days(SCREENSHOT_RETENTION_DAYS)
    cleaned = 0
    for status in FINISHED:
        for snap in list(db.collection("payments").where("status", "==", status).where("statusAt", "<=", cutoff).stream()):
            row = snap.to_dict() or {}
            paths = paths_of(snap.id, row)
            if not paths:
                continue
            try:
                for path in paths:
                    blobs.delete(path)
            except Exception:  # noqa: BLE001
                continue
            snap.reference.update({"proof.screenshotPaths": [], "coachDecision.statementPaths": [], "proof.screenshotsDeletedAt": now})
            cleaned += 1
    return cleaned
```
(This needs the `(status ASC, statusAt ASC)` index added in WO-10a. `blobs` is `coaching.blobs.PersonalBlobs`.)
2. File `functions/account/deletion.py`. Anchor: method `_pseudonymise_coaching_money(self, uid, token)` (about line 499). At the END of that method (after the `for sub in ...` loop that blanks `coachName`), append, with the same 8-space indentation:
```python
        # InstaPay payments (functions/payments): the record stays with her id
        # replaced; her pictures go now; her own standing rows go.
        for field in ("clientUid", "coachUid"):
            for snapshot in db.collection("payments").where(field, "==", uid).stream():
                changes = {field: token}
                if field == "coachUid":
                    changes["addressSnapshot.accountName"] = ""
                snapshot.reference.update(changes)
                self.delete_storage_prefix("own-hub-personal", f"payment-proofs/{snapshot.id}/")
                snapshot.reference.update({"proof.screenshotPaths": [], "coachDecision.statementPaths": []})
        for snapshot in db.collection("paymentStrikes").where("uid", "==", uid).stream():
            snapshot.reference.update({"uid": token})
        for snapshot in db.collection("paymentIdempotency").where("uid", "==", uid).stream():
            snapshot.reference.delete()
        db.collection("coachPaymentProfiles").document(uid).delete()
        db.collection("paymentStanding").document(uid).delete()
```
`paymentIdempotency` documents must therefore carry a `uid` field: this is added to `engine.remember` in the same order (step 3). The bucket name string equals `PERSONAL_BUCKET` defined at the top of this file (line 97); use `PERSONAL_BUCKET` instead of the literal if the method can see it (it can, it is a module constant): write `PERSONAL_BUCKET`.
3. File `functions/payments/engine.py` (from WO-10a2). Anchor: function `remember`. Replace its `transaction.set(...)` call with:
```python
    transaction.set(
        db.collection("paymentIdempotency").document(f"{uid}__{scope}__{key}"),
        {"uid": uid, "result": common.plain(result), "at": now,
         "expireAt": now + model.days(model.LIMITS["idempotencyDays"])},
    )
```
4. File `functions/tools/export_user.py`. Anchor 1: in `class ...Reader` method `coaching` (about line 455), in the returned dict, after the `"receipts": {...},` entry add:
```python
            "payments": {
                s.id: {k: v for k, v in (s.to_dict() or {}).items()}
                for field in ("clientUid", "coachUid")
                for s in db.collection("payments").where(field, "==", uid).stream()
            },
```
Anchor 2: in `build_export`, the line `"receipts": {k: _clean(v) for k, v in (coaching.get("receipts") or {}).items()},` (about line 362). After it add:
```python
            "payments": {k: _clean(v) for k, v in (coaching.get("payments") or {}).items()},
```
(Events and `/staff` documents are subcollections and are never read here, so the export carries no staff data. `check_coverage` works on manifest rows, which did not change.)
5. File `functions/main.py`. Anchor: the function `coaching_sweeper` (about line 2445) and the blank line after its last statement. Insert after it:
```python
@scheduler_fn.on_schedule(schedule="every sunday 03:00", region=config.REGION)
def payments_retention(event: scheduler_fn.ScheduledEvent) -> None:
    """Weekly: removes payment pictures older than the retention period."""
    from payments import retention

    try:
        retention.sweep_screenshots(store.db(), now=_coaching_now(), blobs=_PersonalBlobs())
    except Exception:
        logs.error("payments_retention_failed")
```
(`every sunday 03:00` is the App Engine cron syntax Cloud Scheduler accepts; the other jobs here use `every 1 hours`. UNVERIFIED: if deploy rejects it use `"0 3 * * 0"`.)
6. File `functions/tests/test_payments_retention.py`, create:
```python
from __future__ import annotations

from payments import retention
from tests.fake_blobs import FakeBlobs
from tests.payments_helpers import NOW, _txn, db, later, make_payment, payment_of  # noqa: F401


def test_old_finished_payment_loses_its_pictures_and_keeps_the_record(db):
    make_payment(db, status="confirmed", statusAt=later(days=-100), proof={"screenshotPaths": ["payment-proofs/pay-1/client-1.jpg"], "txnNumber": "T1"})
    blobs = FakeBlobs({"payment-proofs/pay-1/client-1.jpg": (b"x", "image/jpeg")})
    assert retention.sweep_screenshots(db, now=NOW, blobs=blobs) == 1
    assert "payment-proofs/pay-1/client-1.jpg" in blobs.deleted
    row = payment_of(db)
    assert row["proof"]["screenshotPaths"] == [] and row["proof"]["txnNumber"] == "T1"


def test_a_recent_payment_and_one_under_review_keep_their_pictures(db):
    make_payment(db, "p-new", status="confirmed", statusAt=later(days=-10), proof={"screenshotPaths": ["a.jpg"]})
    make_payment(db, "p-rev", status="in_review", statusAt=later(days=-200), proof={"screenshotPaths": ["b.jpg"]})
    blobs = FakeBlobs()
    assert retention.sweep_screenshots(db, now=NOW, blobs=blobs) == 0 and blobs.deleted == []


def test_a_failed_delete_leaves_the_pointer_for_the_next_run(db):
    make_payment(db, status="refunded", statusAt=later(days=-100), proof={"screenshotPaths": ["a.jpg"]})

    class Broken(FakeBlobs):
        def delete(self, path):
            raise RuntimeError("down")

    assert retention.sweep_screenshots(db, now=NOW, blobs=Broken()) == 0
    assert payment_of(db)["proof"]["screenshotPaths"] == ["a.jpg"]
```
7. File `functions/tests/test_deletion_coaching.py`. Anchor: the line `d["paymentProofs/pp3"] = {...}` (about line 105) inside the data builder. Add after it:
```python
    d["payments/pay1"] = {"clientUid": HER, "coachUid": COACH, "status": "confirmed", "addressSnapshot": {"address": "c@instapay", "accountName": "Coach"}, "proof": {"screenshotPaths": ["payment-proofs/pay1/client-1.jpg"], "txnNumber": "T9"}}
    d["payments/pay2"] = {"clientUid": CLIENT, "coachUid": HER, "status": "confirmed", "addressSnapshot": {"address": "h@instapay", "accountName": "Her Name"}, "proof": {"txnNumber": "T8"}}
    d["coachPaymentProfiles/" + HER] = {"address": "h@instapay"}
    d["paymentStanding/" + HER] = {"clientStrikes": 1}
```
Then, next to the assertions at about line 201-206 add a new test (copy how the neighbouring test runs the deletion; the helper is whatever the line-195 test uses, UNVERIFIED name: `sed -n 180,200p functions/tests/test_deletion_coaching.py`):
```python
def test_payments_keep_a_pseudonymised_record_and_lose_pictures_and_standing():
    docs = run_deletion_and_return_docs()   # use the same helper the test above this one uses
    assert docs["payments/pay1"]["clientUid"].startswith("deleted-")
    assert docs["payments/pay1"]["coachUid"] == COACH
    assert docs["payments/pay1"]["proof"]["txnNumber"] == "T9"
    assert docs["payments/pay1"]["proof"]["screenshotPaths"] == []
    assert docs["payments/pay2"]["coachUid"].startswith("deleted-")
    assert docs["payments/pay2"]["addressSnapshot"]["accountName"] == ""
    assert "coachPaymentProfiles/" + HER not in docs and "paymentStanding/" + HER not in docs
```
8. File `functions/tests/test_export_user.py`. In `FakeReader.coaching` (about line 57) add `"payments": {"pay1": {"clientUid": uid, "coachUid": "c9", "amountPiasters": 50037, "status": "confirmed"}},` and add a test:
```python
def test_the_export_carries_her_own_payments():
    out = export_user.build_export(HER, FakeReader())
    assert out["coaching"]["payments"]["pay1"]["amountPiasters"] == 50037
```
(UNVERIFIED key path: confirm the section name holding `receipts` with `grep -n "receipts" functions/tools/export_user.py`; if the dict is not under `out["coaching"]` adjust the assert to match where `receipts` is.)

## Strings to add
None. (Counsel text for the privacy policy is in the privacy order of the app side, not here.)

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `functions/tests/test_payments_retention.py` | the three above | as written |
| `functions/tests/test_deletion_coaching.py` | `test_payments_keep_a_pseudonymised_record_and_lose_pictures_and_standing` | as written |
| `functions/tests/test_export_user.py` | `test_the_export_carries_her_own_payments` | as written |

Command: `cd functions && venv/bin/python -m pytest tests/test_payments_retention.py tests/test_deletion_coaching.py tests/test_export_user.py tests/test_account_deletion.py tests/test_deletion_storage.py -q`

## Verify
The command above ends with `N passed` and no `failed`. `tests/test_deletion_storage.py::test_every_uid_keyed_storage_rule_path_is_purged` must still pass (the storage rule file was not changed in a way that adds a `{uid}` path).

## Do not
- Do not delete the payment record in this release (retention is counsel's number).
- Do not add a row to `contracts/deletion_manifest.json` (Dart and the copy in `functions/account/` would need to change too); row 59 covers money.
- Do not log any transaction number or path.

## Done checklist
- [ ] pseudonymised record test passes
- [ ] export test passes
- [ ] retention tests pass
- [ ] existing deletion tests still pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
