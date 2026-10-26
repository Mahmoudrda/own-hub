# WO-10d-server: Coach InstaPay address: handle-not-phone, fresh phone code, 24 hour delay, alerts and notices
Depends on: WO-10b (it reads `profile.effective`), can run before WO-10b2
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.4, 4.11, 13.1 ("the coach can allow longer"), 13.12 item 7; `functions/coaching/common.py` lines 164-170 (`account_ok`) and `functions/coaching/coaching_contract.json` key `rails.instapay.accountPattern` (`^[a-z0-9._-]{3,40}@instapay$`); `functions/payments/profile.py` (`effective`); `functions/main.py` lines 169-196 (`_require_auth`, `_sign_in_provider`); `functions/coaching/payouts.py` lines 72-139 is NOT a model (it pays coaches; this order is only the address)

## Why
The coach enters the InstaPay address and the account name exactly as her bank shows them; the client sees the name and checks it. An address that is a mobile number would show her phone number on every receipt, so only a handle is accepted (13.12 item 7). The account is the most valuable target: changing the address needs a code sent to her phone just now and takes effect 24 hours later, while payments already started keep the address they were given, clients with an open payment are told, and staff see an alert on every change.

## Final result
No screen. Callables:
- `set_coach_instapay_address` `{address, accountName}` -> `{status: "active"|"pending", effectiveAt}`. The first address ever saved is active at once; a change is `pending` for 24 hours and a second change replaces the pending one and restarts the 24 hours. Needs a phone sign-in that happened in the last 5 minutes (the app asks for a fresh SMS code with Firebase re-authentication before calling).
- `set_coach_payment_options` `{allowLongFirst: bool}` -> `{allowLongFirst}`: the coach lets a new client's first payment be a longer package.

Refusals (codes the app maps): `recent_sign_in_required`, `address_not_handle` (the text is a phone number), `address_format`, `bad_request`, `too_many_requests` (a change within 10 minutes of the last), `not_a_coach`, `coach_suspended`.

`coaches/{uid}.instapayReady` is set to `true` when she has an effective address and is not suspended; it is what makes the pay button appear (4.11).

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/address.py` | create | validation, `set_address`, `set_options` |
| `functions/main.py` | edit | `_recent_sign_in`, two callables |
| `functions/tests/test_entrypoints.py` | edit | two names and a sign-in test |
| `functions/tests/test_payments_address.py` | create | tests |

## Steps
1. File `functions/payments/address.py`, create:
```python
"""The coach's InstaPay address (spec 4.4, 13.12 item 7)."""

from __future__ import annotations

import datetime as dt
import re

from coaching import common

from . import errors, model, profile

DEFAULT_SUFFIXES = ("instapay",)  # UNVERIFIED: other bank suffixes. Ask the owner for three real addresses, then set coachingConfig/instapay.addressSuffixes.
_PHONE = re.compile(r"^\+?[0-9][0-9 \-]{6,}$")
_HANDLE_LOCAL = re.compile(r"^[a-z0-9._-]{3,40}$")
MIN_GAP_MINUTES = 10

DEFAULTS = {"paymentsCreated": 0, "paymentsConfirmed": 0, "cleanConfirmed": 0, "disputesLost": 0,
            "autoConfirmGreen": False, "allowLongFirst": False, "status": "ok"}


def suffixes(db) -> tuple:
    row = db.collection("coachingConfig").document("instapay").get()
    listed = (row.to_dict() or {}).get("addressSuffixes") if row.exists else None
    if isinstance(listed, list) and listed and all(isinstance(s, str) and re.fullmatch(r"[a-z]{3,20}", s) for s in listed):
        return tuple(listed)
    return DEFAULT_SUFFIXES


def check_address(raw, allowed: tuple) -> str:
    """The address as it will be stored (trimmed, lower case), or a refusal.
    A phone number is refused with its own code so the app can explain why."""
    if not isinstance(raw, str):
        raise common.bad()
    text = raw.strip().lower()
    if _PHONE.match(text):
        raise common.refuse(errors.INVALID, errors.ADDRESS_NOT_HANDLE)
    local, at, suffix = text.partition("@")
    if not at or suffix not in allowed or not _HANDLE_LOCAL.match(local):
        raise common.refuse(errors.INVALID, errors.ADDRESS_FORMAT)
    return text


def set_address(db, uid: str, data: dict, *, coach_v, recent_sign_in: bool, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    if recent_sign_in is not True:
        raise common.refuse(errors.PERMISSION, errors.RECENT_SIGN_IN_REQUIRED)
    address = check_address(data.get("address"), suffixes(db))
    name = common.text(data.get("accountName"), min_len=2, max_len=80)
    prof_ref = profile.profile_ref(db, uid)
    coach_ref = db.collection("coaches").document(uid)
    alert_ref = db.collection("paymentAlerts").document()
    held = {}

    def body(transaction):
        prof = common.read(prof_ref, transaction)
        coach = common.read(coach_ref, transaction)
        standing = common.read(profile.standing_ref(db, uid), transaction)
        last = common.as_utc((prof or {}).get("changedAt"))
        if last is not None and now < last + dt.timedelta(minutes=MIN_GAP_MINUTES):
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_REQUESTS)
        current = profile.effective(prof, now)
        suspended = profile.coach_suspended(standing)
        if current is None:  # the first address: active at once
            transaction.set(prof_ref, {**DEFAULTS, **(prof or {}), "address": address, "accountName": name,
                                       "verifiedAt": now, "changedAt": now, "pending": None})
            status, effective = "active", now
        else:
            if current == (address, name):
                return {"status": "active", "effectiveAt": common.plain(now)}  # nothing changes
            effective = now + model.hours(model.LIMITS["addressDelayHours"])
            # A pending change that has already come due is settled before a new one is stored.
            base = {"address": current[0], "accountName": current[1]}
            transaction.set(prof_ref, {**DEFAULTS, **(prof or {}), **base, "changedAt": now,
                                       "pending": {"address": address, "accountName": name, "requestedAt": now, "effectiveAt": effective}})
            status = "pending"
        if coach is not None:
            transaction.update(coach_ref, {"instapayReady": not suspended})
        transaction.set(alert_ref, {"type": "addressChange", "coachRef": common.staff_ref(uid), "firstTime": current is None,
                                    "at": now, "effectiveAt": effective})
        held["changed"] = current is not None
        return {"status": status, "effectiveAt": common.plain(effective)}

    result = common.run(db, body)
    if held.get("changed"):
        for snap in db.collection("payments").where("coachUid", "==", uid).stream():
            row = snap.to_dict() or {}
            late = common.as_utc(row.get("lateUntil"))
            if row.get("status") in ("awaiting_payment", "expired") and late is not None and now <= late:
                try:
                    notify(row["clientUid"], "instapayAddressChanged")
                except Exception:  # noqa: BLE001
                    pass
    return result


def set_options(db, uid: str, data: dict, *, coach_v, now: dt.datetime) -> dict:
    common.require_active_coach(db, uid, coach_v)
    allow = data.get("allowLongFirst")
    if not isinstance(allow, bool):
        raise common.bad()
    ref = profile.profile_ref(db, uid)

    def body(transaction):
        if common.read(ref, transaction) is None:
            raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
        transaction.update(ref, {"allowLongFirst": allow})
        return {"allowLongFirst": allow}

    return common.run(db, body)
```
2. File `functions/main.py`. (i) Anchor: `_payments_notify`. After it add:
```python
def _recent_sign_in(request: https_fn.CallableRequest, max_age_seconds: int = 300) -> bool:
    """True when this ID token comes from a phone sign-in made in the last five
    minutes. The app gets there by re-authenticating with a fresh SMS code,
    which is the 'one-time code to her phone' of spec 4.4."""
    token = request.auth.token if request.auth is not None else None
    auth_time = token.get("auth_time") if isinstance(token, dict) else None
    if isinstance(auth_time, bool) or not isinstance(auth_time, (int, float)):
        return False
    return _sign_in_provider(request) == "phone" and 0 <= time.time() - auth_time <= max_age_seconds
```
   (`time` is already imported at the top of `main.py`, line 86.) (ii) After the payment callables add:
```python
@https_fn.on_call()
def set_coach_instapay_address(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import address

    return _coaching_call(
        address.set_address, store.db(), uid, data, coach_v=_claim(request, "coachV"),
        recent_sign_in=_recent_sign_in(request), now=_coaching_now(), notify=_payments_notify,
    )


@https_fn.on_call()
def set_coach_payment_options(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import address

    return _coaching_call(address.set_options, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now())
```
3. File `functions/tests/test_entrypoints.py`: add `"set_coach_instapay_address", "set_coach_payment_options",` to `CALLABLES`, and
```python
def test_the_address_change_needs_a_sign_in_from_the_last_five_minutes():
    import time
    fresh = request({}, token={"auth_time": time.time() - 60, "firebase": {"sign_in_provider": "phone"}})
    stale = request({}, token={"auth_time": time.time() - 3600, "firebase": {"sign_in_provider": "phone"}})
    assert main._recent_sign_in(fresh) is True
    assert main._recent_sign_in(stale) is False
    assert main._recent_sign_in(request({}, token={"firebase": {"sign_in_provider": "phone"}})) is False
    assert main._recent_sign_in(request({}, token={"auth_time": time.time(), "firebase": {"sign_in_provider": "password"}})) is False
```
   (UNVERIFIED: the signature of this file's `request(...)` helper accepts `token=`; it does in the existing calls, for example `request({...}, token={"admin": True})` near line 300.)
4. File `functions/tests/test_payments_address.py`, create. `seed_world(db)` then delete the profile's address when the test needs a first-time coach: `db.document("coachPaymentProfiles/coach-uid-1").delete()`. Helper `go(db, notes, address="rahma@instapay", name="Rahma M.", recent=True, now=NOW)` = `address_mod.set_address(db, COACH, {"address": address, "accountName": name}, coach_v="active", recent_sign_in=recent, now=now, notify=notes)`.
| test | arrange, act, assert |
|---|---|
| `test_the_first_address_is_active_at_once_and_makes_the_coach_ready` | no profile -> `status active`; profile has the address, name, defaults (`allowLongFirst False`, `autoConfirmGreen False`); `coaches/COACH.instapayReady True`; an alert doc `type addressChange, firstTime True`; no push |
| `test_a_change_is_pending_for_24_hours_and_old_payments_keep_the_old_address` | existing address; change at NOW -> `pending`, `effectiveAt == NOW+24h`; `profile.effective(prof, NOW+23h)` is the old pair, at `NOW+25h` the new pair; an existing payment document is untouched |
| `test_clients_with_an_open_payment_are_told_and_others_are_not` | payments `awaiting_payment` (client A), `expired` within 7 days (client B), `confirmed` (client C), `awaiting_payment` of another coach -> pushes `instapayAddressChanged` to A and B only |
| `test_a_second_change_replaces_the_pending_one_and_restarts_the_delay` | change at NOW, another at NOW+30 minutes -> pending holds the second, `effectiveAt == NOW+30m+24h`; a change 5 minutes after the last -> `(EXHAUSTED, TOO_MANY_REQUESTS)` |
| `test_the_same_address_again_changes_nothing` | same pair -> `active`, no alert doc added |
| `test_a_stale_sign_in_is_refused_and_nothing_is_written` | `recent=False` -> `(PERMISSION, RECENT_SIGN_IN_REQUIRED)`; no alert, profile unchanged |
| `test_a_phone_number_is_not_an_address` | `"01012345678"`, `"+201012345678"`, `"010 1234 5678"` -> `(INVALID, ADDRESS_NOT_HANDLE)` |
| `test_format_rules` | `"nobody"`, `"a@instapay"` (too short), `"RAHMA@InstaPay"` (accepted, stored lower case), `"rahma@cib"` (refused with the default suffix list), `"rah ma@instapay"`, `""`, `None`, `5` -> `ADDRESS_FORMAT` or `bad_request` as coded; with `coachingConfig/instapay.addressSuffixes = ["instapay", "cib"]` `"rahma@cib"` is accepted |
| `test_the_name_is_required` | `accountName=""`, `"A"`, 81 characters -> `bad_request` |
| `test_only_an_active_coach_can_save` | `coach_v=None` -> `not_a_coach`; `coach_v="suspended"` -> `coach_suspended` |
| `test_a_suspended_coach_who_changes_her_address_stays_not_ready` | `paymentStanding.coachSuspended` -> `coaches/COACH.instapayReady False` after the change |
| `test_options_toggle_allow_long_first` | true/false stored; non-bool -> `bad_request`; no profile -> `coach_not_ready` |
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_address.py tests/test_entrypoints.py tests/test_payments_create.py -q`

## Strings to add
None here. The app shows the rule in words (owner-facing screen order PAY7), the server only returns codes. Suggested text for that screen, for the app order: EN "Use your InstaPay address, not your phone number. A phone number would show on every receipt." AR "استخدمي عنوان إنستا باي بتاعك مش رقم موبايلك. رقم الموبايل هيظهر في كل إيصال."; EN "Changes take effect after 24 hours. Payments already started keep the old details." AR "التغيير بيشتغل بعد 24 ساعة. الدفعات اللي بدأت بتفضل بالبيانات القديمة."

## Tests to add or change
As above.

## Verify
The command ends with `N passed`, no `failed`. UNVERIFIED on a real device: that Firebase re-authentication with a fresh SMS code gives a new `auth_time` claim in the next ID token. Verify with the Auth emulator or a test phone: after re-authentication call `getIdTokenResult(true)` and read `claims.auth_time`.

## Do not
- Do not accept a phone number as an address.
- Do not apply a changed address before its 24 hours, and do not touch any existing payment's `addressSnapshot`.
- Do not skip the staff alert, also for the first address.
- Do not log the address.

## Done checklist
- [ ] address.py created, main edited, names listed
- [ ] all tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
