# WO-10p: The kill switch (config/payments.enabled), the app flag Feature.instapayPayments, and the gating tests
Depends on: WO-10a, WO-10a2, WO-10b through WO-10c (run last of the server orders)
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 10 and 13 (header: "LIVE ... server-side kill switch"), 13.9 (kill switch mid-dispute); `functions/payments/model.py` (`enabled`); `functions/main.py` lines 903-923 (`_require_admin`) and the `_instapay_on` helper from WO-10b; `functions/tools/grant_finance.py` (owner tool style)

## Why
The feature ships live, so the owner needs one instant way to stop new payments if something goes wrong, without a release. The switch is a document, `config/payments`, with `enabled`. Turning it off must do exactly two things: no new payment can start (`create_payment` refuses, and a coach accepting a request starts the coaching free as today, "Free for now"), and nothing else changes: every payment already open stays readable and can still be proved, confirmed, disputed, refunded, resolved by staff and swept by the schedules. A second switch lives in the app (`Feature.instapayPayments`, app order WO-10d0) so a store build can also hide the screens by a release or by `meta/features`.

## Final result
- Callable `set_payments_enabled` `{enabled: bool, reason (5 to 300 characters)}` for the `admin` claim; writes `config/payments = {enabled, updatedAt, updatedBy}` and a line in the access log.
- Owner tool `python -m tools.set_payments_switch on|off` that writes the same document directly (for the owner at a terminal when the app is not an option).
- The app flag `Feature.instapayPayments` (parent `marketplace`, ships on) belongs to the app order WO-10d0; this order only checks it exists.
- Tests proving the behaviour above.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/switch.py` | create | `set_enabled` |
| `functions/tools/set_payments_switch.py` | create | owner tool |
| `functions/main.py` | edit | `set_payments_enabled` callable |
| `functions/tests/test_entrypoints.py` | edit | one name and one claim test |
| `functions/tests/test_payments_gating.py` | create | gating tests |

## Steps
1. File `functions/payments/switch.py`, create:
```python
"""The owner's off button for new InstaPay payments (spec 10, 13 header)."""

from __future__ import annotations

import datetime as dt

from coaching import common


def set_enabled(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    enabled = data.get("enabled")
    if not isinstance(enabled, bool):
        raise common.bad()
    common.text(data.get("reason"), min_len=5, max_len=300)  # asked for, kept only in the access log line's existence
    common.log_access(db, actor, f"payments.switch.{'on' if enabled else 'off'}", "config", now)
    db.collection("config").document("payments").set(
        {"enabled": enabled, "updatedAt": now, "updatedBy": common.staff_ref(actor)}
    )
    return {"enabled": enabled}
```
2. File `functions/tools/set_payments_switch.py`, create:
```python
"""OWNER'S TOOL ONLY: turn new InstaPay payments on or off.

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch on
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch off
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch status

Off: no new payment can start and coaching requests start free as before. Open
payments keep working. Safe to run twice.
"""

from __future__ import annotations

import datetime as dt
import sys


def main(argv=None, *, db=None, now=None, out=print) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 1 or args[0] not in ("on", "off", "status"):
        out("usage: set_payments_switch on|off|status")
        return 2
    if db is None:
        from google.cloud import firestore

        db = firestore.Client(project="own-hub")
    ref = db.collection("config").document("payments")
    if args[0] == "status":
        snap = ref.get()
        out(f"enabled: {bool(snap.exists and (snap.to_dict() or {}).get('enabled') is True)}")
        return 0
    enabled = args[0] == "on"
    ref.set({"enabled": enabled, "updatedAt": now or dt.datetime.now(dt.timezone.utc), "updatedBy": "owner-tool"})
    out(f"enabled: {enabled}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```
3. File `functions/main.py`. After the payment callables add:
```python
@https_fn.on_call()
def set_payments_enabled(request: https_fn.CallableRequest) -> dict:
    """The owner's off button: {enabled, reason}. Admin claim only."""
    actor = _require_admin(request, USER_PROVIDERS)
    data = _body(request)
    from payments import switch

    return _coaching_call(switch.set_enabled, store.db(), actor, data, now=_coaching_now())
```
4. File `functions/tests/test_entrypoints.py`: add `"set_payments_enabled",` to `CALLABLES`, and
```python
def test_only_an_admin_can_move_the_payments_switch(stubbed):
    fn = inner("set_payments_enabled")
    raises(lambda: fn(request({"enabled": False, "reason": "testing"})), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
    raises(lambda: fn(request({"enabled": False, "reason": "testing"}, token={"womanReviewer": True})), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
    raises(lambda: fn(request({"enabled": False, "reason": "testing"}, token={"finance": True})), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
```
   (`_require_admin` first calls `_require_auth` with phone-only providers, then needs the `admin` claim; the default `token` of `request()` carries a phone sign-in, UNVERIFIED: if these raise `PHONE_SIGN_IN_REQUIRED` instead, pass `token={"firebase": {"sign_in_provider": "phone"}}` as the other tests in the file do.)
5. File `functions/tests/test_payments_gating.py`, create. Imports as in the earlier payment tests plus `import main`, `from tests.test_entrypoints import inner, raises, request`, `from payments import ... switch`, `from tools import set_payments_switch`. The `db` is the fake; for callable-level tests `monkeypatch.setattr("identity.store.db", lambda: db)`.
| test | arrange, act, assert |
|---|---|
| `test_the_switch_is_off_when_the_document_is_missing_false_or_not_exactly_true` | no doc, `{"enabled": False}`, `{"enabled": "true"}`, `{"enabled": 1}` -> `model.enabled(db)` False; `{"enabled": True}` -> True |
| `test_set_enabled_writes_the_document_and_logs_without_a_uid` | `switch.set_enabled(db, "admin-1", {"enabled": True, "reason": "go live"}, now=NOW)`; the doc holds `enabled True`, `updatedBy` equal to `common.staff_ref("admin-1")`; an access-log line `coaching.payments.switch.on` exists and does not contain `admin-1`; again with False flips it |
| `test_set_enabled_validates` | `enabled="yes"` -> `bad_request`; `reason="no"` -> `bad_request`; missing reason -> `bad_request` |
| `test_the_owner_tool_flips_the_same_document` | `set_payments_switch.main(["off"], db=db, now=NOW, out=lines.append)` -> doc False and output `enabled: False`; `["status"]` prints the state; `["maybe"]` returns 2 |
| `test_create_payment_refuses_when_off_and_makes_nothing` | `seed_world(db)`, no switch doc; callable `inner("create_payment")(request({"subId": SUB, "idempotencyKey": "key-0001-abcd"}, uid=CLIENT, token={"verified": True, "firebase": {"sign_in_provider": "phone"}}))` with `store.db` patched -> `HttpsError` code `FAILED_PRECONDITION`, message `payments_off`; zero payment documents, zero locks |
| `test_with_the_switch_off_a_coach_accepting_a_request_starts_the_coaching_free_as_today` | `subscriptions.respond(..., instapay=False, payments_live=False)` produces the same stored fields as a call without the argument (compare the two subscription documents field by field, `free True`, `status active`) |
| `test_with_the_switch_on_the_same_acceptance_waits_for_payment` | `instapay=True` -> `awaiting_payment` (guards against the two modes being swapped) |
| `test_turning_it_off_mid_payment_leaves_everything_open_readable_and_resolvable` | switch ON, `create_payment` works; set the switch OFF; then in order, each must still succeed: `proof.submit` (green), `coach.confirm`, a second payment `make_payment(status="proof_submitted")` for `coach_mark_not_received`, `refund.request` on the confirmed one, `refund.record`, `open_service_dispute` on another, `staff.resolve` on an `in_review` one, `cancel.cancel` on an unpaid one, `sweep.expire_pass`, `escalate.escalate_pass`, `fees.generate`; none raises; the documents are readable (they are plain Firestore documents; the rules do not mention the switch: assert `"config/payments"` does not appear inside the `payments` block of `firebase/firestore.rules` by reading the file and slicing between `match /payments/{paymentId}` and `match /paymentTxnNumbers`) |
| `test_every_callable_except_create_ignores_the_switch` | read `functions/main.py` as text with `ast`; for each payments callable name in the CALLABLES list of WO-10b through WO-10n except `create_payment`, assert its function body contains no call to `_instapay_on`; `create_payment` does contain it (this catches a later edit that gates a resolve path) |
| `test_staff_decisions_continue_while_off` | `in_review` payment, switch off: `staff.resolve(... "resolved_paid")` works and the sweep passes use no switch |
| `test_the_switch_is_read_once_per_call_and_failing_closed` | patch `model.enabled` to raise -> `create_payment` raises (the call fails, nothing is created); no other callable is affected |
6. The app flag `Feature.instapayPayments` is NOT built here. It is built by the app order `WO-10d0-app-data-layer-and-flag.md` (parent `marketplace`, shipped on, the server may turn it off and never on) and tested there (`app/test/domain/flags/feature_flags_test.dart`, test `instapayPayments is on and can open`). Before finishing this order run one check that both halves exist: `grep -n "instapayPayments" app/lib/domain/flags/feature_flags.dart` must print the enum value and the shipped line. If it prints nothing, WO-10d0 has not run yet: write that to `handover/QUESTIONS.md` and finish the server tests anyway.
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_gating.py tests/test_entrypoints.py -q`

## Strings to add
None. Owner copy to put in `docs/owner/LAUNCH-GUIDE.md` by the documentation order: "To stop new payments at once: run `python -m tools.set_payments_switch off` or call `set_payments_enabled` from the dashboard. Open payments keep working. To start: `... on`. At deploy, set it to `on` once, after the real two-phone transfer test."

## Tests to add or change
As above.

## Verify
- `cd functions && venv/bin/python -m pytest tests/test_payments_gating.py tests/test_entrypoints.py -q`: `N passed`, no `failed`.
- Then the whole payments server set: `cd functions && venv/bin/python -m pytest tests -q -k "payments or entrypoints or coaching" ` ends with `passed` and no `failed`.

## Do not
- Do not read `config/payments` anywhere except `create_payment`, `respond`/`request` acceptance (the `instapay` flag) and the sweeper's `payments` flag. Never in a resolve, confirm, refund, dispute, staff or scheduled rule.
- Do not make the missing document mean on.

## Done checklist
- [ ] switch.py, tool, callable done
- [ ] gating tests pass, including the AST test
- [ ] the grep for the app flag printed both lines (or the question was written)

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
