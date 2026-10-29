"""Server-level end-to-end run of InstaPay payments on the local emulators.

    app/tool/e2e_payments.sh          (boots the emulators, runs this, shuts down)

Pattern of e2e_coaching.py: real callables over HTTP with ID tokens from the Auth
emulator, Firestore through the REST API. The payments switch (config/payments
.enabled) is written to the EMULATOR database only, and Own Hub's receiving account
is a fake address. Two stand-ins, both emulator-only and stated in the output:
 - Cloud Vision is not in the emulators, so the receipt text the walk drew is handed
   back as the "OCR" (functions/tools/e2e_shim); the checks and the colour are real.
 - The server clock is real, so the time-moved steps call the same Python entry points
   the scheduled functions and the staff callables use (payments.timers.hourly,
   payments.fees.*) with a fake `now`, against the emulator database.
The exit code is 1 when any step fails.
"""

from __future__ import annotations

import base64
import datetime as dt
import os
import re
import sys

from google.cloud import firestore

from coaching import common, errors as coaching_errors
from payments import fees, model, timers
from tools import e2e_coaching as C
from tools import e2e_seed
from tools.e2e_coaching import Refused, call, fs_get, refused, step

PROJECT = C.PROJECT
OCR_FILE = os.environ.get("E2E_OCR_FILE")
ADDRESS = "mona.coach@instapay"
S = C.ctx
FAKE_ACCOUNT = {"instapay": {"address": "ownhub.test@instapay", "holderName": "Own Hub Test Account", "enabled": True},
                "vodafoneCash": {"address": "", "holderName": "", "enabled": False}}
CLIENTS = ("client", "client2", "client3")  # 7.5 percent (invite code), 15, 15


def when(text):
    """An emulator timestamp string as an aware datetime."""
    text = re.sub(r"(\.\d{6})\d+", r"\1", text.replace("Z", "+00:00"))
    return dt.datetime.fromisoformat(text)


def iso(moment):
    return moment.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def png(seed, lines):
    """A phone-shaped picture with the receipt lines drawn on a seeded background."""
    import cv2
    import numpy as np

    rng = np.random.default_rng(seed)
    base = rng.integers(200, 255, (24, 12, 3), dtype=np.uint8)
    image = cv2.resize(base, (600, 1200), interpolation=cv2.INTER_NEAREST)
    for i, line in enumerate(lines):
        cv2.putText(image, line, (20, 60 + 45 * i), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (20, 20, 20), 2)
    ok, out = cv2.imencode(".png", image)
    assert ok
    return out.tobytes()


def receipt_lines(amount, sender, reference, txn, now):
    local = now.astimezone(common.CAIRO).strftime("%d %b %Y %I:%M %p")
    return ["Transfer Successful", "Transfer amount", f"EGP {model.pounds_text(amount)}", "Fees", "0.00 EGP",
            "From", sender, "To", ADDRESS, "Note", reference, "Transaction ID", txn, "Date & Time", local]


def main() -> int:
    if not OCR_FILE:
        sys.exit("E2E_OCR_FILE is not set: run this through app/tool/e2e_payments.sh")
    e2e_seed.ACCOUNTS["client3"] = {"phone": "+201000000006", "claims": {"verified": True}}
    e2e_seed._local()
    seeded = e2e_seed.seed()
    uid = {k: v["uid"] for k, v in seeded.items()}
    tok = {k: v["idToken"] for k, v in e2e_seed.tokens().items()}
    uid["client2"], tok["client2"] = uid["stranger"], tok["stranger"]  # the seeded fifth account is the second client
    db = firestore.Client(project=PROJECT)
    pushes: list = []

    def rec(who, kind, ref=None):
        pushes.append((who, kind, ref))

    def sent(kind, who=None):
        return [p for p in pushes if p[1] == kind and (who is None or p[0] == who)]

    application, paths = C.coach_application(uid["coach"])
    agreement_path = f"coach-docs/{uid['coach']}/agreement/signed-e2e.jpg"
    rel = {n: f"{uid['coach']}__{uid[n]}" for n in CLIENTS}
    sub, pay, bill = {}, {}, {}
    clock = {}
    owner = "owner"

    def payment(name):
        return fs_get(f"payments/{pay[name]}", owner)

    def bill_of(name):
        return fs_get(f"feeStatements/{bill[name]}", owner)

    # ------------------------------------------------------------------ setup
    def switch_on():
        C.admin_patch("config/payments", {"enabled": {"booleanValue": True}})
        assert fs_get("config/payments", owner)["enabled"] is True

    def receiving_account():
        call("set_receiving_accounts", tok["admin"], FAKE_ACCOUNT)
        assert fs_get("coachingConfig/receivingAccounts", owner)["instapay"]["address"] == "ownhub.test@instapay"

    def onboard():
        for i, path in enumerate(paths.values()):
            C.upload(tok["coach"], path, C.jpeg(i + 1))
        call("submit_coach_application", tok["coach"], application)
        call("decide_coach_application", tok["reviewer"],
             {"uid": uid["coach"], "decision": "approve", "checkedCertificates": ["nasm-cpt"], "note": ""})
        tok["coach"] = e2e_seed.sign_in(e2e_seed.ACCOUNTS["coach"]["phone"])["idToken"]

    def agreement():
        assert call("accept_coach_terms", tok["coach"], {"version": 2, "locale": "en"})["status"] in ("accepted", "uploaded", "verified")
        C.upload(tok["coach"], agreement_path, C.jpeg(77))
        assert call("submit_coach_agreement", tok["coach"], {"mediaRef": agreement_path})["status"] == "uploaded"
        assert call("decide_coach_agreement", tok["reviewer"], {"uid": uid["coach"], "decision": "verify"})["status"] == "verified"

    def coach_address():
        tok["coach"] = e2e_seed.sign_in(e2e_seed.ACCOUNTS["coach"]["phone"])["idToken"]  # a fresh phone sign-in
        refused(lambda: call("set_coach_instapay_address", tok["coach"], {"address": "01012345678", "accountName": "Mona"}), "INVALID_ARGUMENT")
        out = call("set_coach_instapay_address", tok["coach"], {"address": ADDRESS, "accountName": "Mona Hassan Ali"})
        assert out["status"] == "active", out
        assert fs_get(f"coaches/{uid['coach']}", owner)["instapayReady"] is True

    def package():
        out = call("save_coach_package", tok["coach"], {
            "title": "Strong in four weeks", "description": "A plan, two live sessions and daily support for a month.",
            "durationDays": 28, "includes": ["Workout plan", "Meal plan"], "liveSessionsPerMonth": 2,
            "sessionMinutes": 45, "checkInsPerWeek": 2, "coachPriceEgp": 1000, "active": True, "order": 0})
        S["package"], S["price"] = out["packageId"], out["priceFinalEgp"]
        assert fs_get(f"coaches/{uid['coach']}/packages/{S['package']}", owner)["liveSessionsPerMonth"] == 2

    def invite():
        S["code"] = call("create_coach_invite", tok["coach"], {})["code"]

    def request(name, code=None, auto=False, source="app"):
        row = {key: False for key in common.ENUMS["healthQuestions"]}
        data = {"coachUid": uid["coach"], "packageId": S["package"], "locale": "en", "appBuild": common.MIN_APP_BUILD,
                "intake": {"goal": "stronger", "level": "beginner", "daysPerWeek": 3, "place": "home", "allergies": [],
                           "lifeStage": "none", "health": row, "doctorAck": False, "note": "hello"}}
        if code:
            data["inviteCode"] = code
        out = call("request_coaching", tok[name], data)
        sub[name] = out["subId"]
        assert out["status"] == ("awaiting_payment" if auto else "requested"), out
        assert fs_get(f"subscriptions/{sub[name]}", owner)["source"] == source

    def requests():
        call("update_coach_profile", tok["coach"], {"autoAccept": False})
        request("client", S["code"], source="invite")
        request("client2")
        call("update_coach_profile", tok["coach"], {"autoAccept": True})  # the third is accepted for her
        request("client3", "ZZZZZZZZ", auto=True)  # a code that is not hers counts as none

    def accept_all():
        for name in CLIENTS[:2]:
            out = call("respond_coaching_request", tok["coach"], {"subId": sub[name], "decision": "accept"})
            assert out["status"] == "awaiting_payment", out
            row = fs_get(f"subscriptions/{sub[name]}", owner)
            assert row["status"] == "awaiting_payment" and row.get("free") is not True, row
        assert fs_get(f"subscriptions/{sub['client3']}", owner)["status"] == "awaiting_payment"

    def create_payments():
        amounts = set()
        for n, name in enumerate(CLIENTS):
            out = call("create_payment", tok[name], {"subId": sub[name], "idempotencyKey": f"create-{name}-0001"})
            again = call("create_payment", tok[name], {"subId": sub[name], "idempotencyKey": f"create-{name}-0001"})
            assert again["paymentId"] == out["paymentId"], "the same key must replay"
            pay[name] = out["paymentId"]
            row = payment(name)
            base = S["price"] * 100
            assert row["baseAmountPiasters"] == base, row
            assert 1 <= out["amountPiasters"] - base <= 99, out
            assert out["address"] == ADDRESS and re.fullmatch(r"OH-[A-Z0-9]{6}", out["reference"]), out
            amounts.add(out["amountPiasters"])
        assert len(amounts) == 3, f"amounts must be unique: {amounts}"

    def submit_proofs():
        for n, name in enumerate(CLIENTS):
            row = payment(name)
            now = dt.datetime.now(dt.timezone.utc)
            txn = f"3012345678{n}9{n}{n}"
            lines = receipt_lines(row["amountPiasters"], f"{name}@instapay", row["reference"], txn, now)
            with open(OCR_FILE, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))
            out = call("submit_instapay_proof", tok[name], {
                "paymentId": pay[name], "idempotencyKey": f"proof-{name}-0001", "amountPiasters": row["amountPiasters"],
                "senderHandle": f"{name}@instapay", "images": [base64.b64encode(png(10 + n, lines)).decode()]})
            assert out["outcome"] == "green" and out["status"] == "proof_submitted", out

    def coaching_starts_and_fee_owed():
        for name, bps in (("client", 750), ("client2", 1500), ("client3", 1500)):
            row = payment(name)
            assert row["status"] == "proof_submitted" and row["access"]["state"] == "provisional", row
            assert row["feeBps"] == bps, (name, row["feeBps"])
            assert row["feePiasters"] == row["baseAmountPiasters"] * bps // 10000, row
            assert row["feeState"] == "owed", row
            sub_row = fs_get(f"subscriptions/{sub[name]}", owner)
            assert sub_row["status"] == "active", f"coaching did not start: {sub_row['status']}"
            relation = fs_get(f"relationships/{rel[name]}", tok[name])
            assert relation["status"] == "active" and relation["chatOpen"] is True, relation
            bill[name] = row["feeStatementId"]
            b = bill_of(name)
            owed = when(row["feeOwedAt"])
            assert b["status"] == "open" and b["coachUid"] == uid["coach"] and b["paymentId"] == pay[name], b
            assert when(b["dueAt"]) - owed == dt.timedelta(days=3), (b["dueAt"], row["feeOwedAt"])
            assert when(b["holdAt"]) - owed == dt.timedelta(days=7), (b["holdAt"], row["feeOwedAt"])
            assert b["totalDuePiasters"] == row["feePiasters"], b
            assert b["payTo"]["address"] == "ownhub.test@instapay", b["payTo"]

    def coach_confirms_two():
        for name in ("client", "client2"):
            assert call("coach_confirm_payment", tok["coach"], {"paymentId": pay[name]})["status"] == "confirmed"
            row = payment(name)
            assert row["status"] == "confirmed" and row["access"]["state"] == "full", row

    # -------------------------------------------------------------- time moved
    def hourly_at(offset, label):
        before = len(pushes)
        counts = timers.hourly(db, clock["t0"] + offset, rec)
        return counts, pushes[before:]

    def keep_client3_waiting():
        # Her proof waits for the coach (the 72 hour silence rule would send it to staff
        # before day 7). Push that one clock out so the hold step can test a confirmation on hold.
        far = {"escalateAt": {"timestampValue": iso(dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=60))}}
        C.admin_patch(f"payments/{pay['client3']}", far)

    def statement_ready():
        clock["t0"] = max(when(payment(n)["feeOwedAt"]) for n in CLIENTS)
        keep_client3_waiting()
        counts, got = hourly_at(dt.timedelta(hours=1), "ready")
        assert len(sent("instapayStatementReady", uid["coach"])) == 3, (counts, got)
        assert not sent("instapayFeeOverdue"), got

    def coach_reminded():
        got = timers.half_hourly(db, clock["t0"] + dt.timedelta(hours=49), rec)
        assert got["coachReminded"] == 1 and sent("instapayCoachReminder", uid["coach"]), (got, pushes)

    def due_soon():
        counts, got = hourly_at(dt.timedelta(days=2, hours=12), "dueSoon")
        assert len(sent("instapayFeeDueSoon", uid["coach"])) == 3, (counts, got)

    def due_today():
        counts, got = hourly_at(dt.timedelta(days=3, hours=1), "dueToday")
        assert len(sent("instapayFeeDueToday", uid["coach"])) == 3, (counts, got)
        assert not sent("instapayFeeOverdue"), "no hold before day 7"
        assert fs_get(f"coachPrivate/{uid['coach']}", owner).get("hold") is None

    def hold_at_day_seven():
        clock["held"] = clock["t0"] + dt.timedelta(days=7, hours=1)
        counts, got = hourly_at(dt.timedelta(days=7, hours=1), "hold")
        assert counts["feesOverdue"] == 3, counts
        assert len(sent("instapayFeeOverdue", uid["coach"])) == 3, got
        priv = fs_get(f"coachPrivate/{uid['coach']}", owner)
        assert priv["hold"]["reason"] == "fee" and abs((when(priv["hold"]["since"]) - clock["held"]).total_seconds()) < 2, priv
        assert fs_get(f"coaches/{uid['coach']}", owner)["acceptingClients"] is False
        S["ends_before"] = {n: when(fs_get(f"subscriptions/{sub[n]}", owner)["endsAt"]) for n in CLIENTS}

    def client_sees_coach_away():
        for name in CLIENTS:
            assert fs_get(f"relationships/{rel[name]}", tok[name])["coachAway"] is True

    def hold_blocks_the_coach():
        err = refused(lambda: call("respond_coaching_request", tok["coach"], {"subId": sub["client"], "decision": "accept"}))
        assert coaching_errors.COACH_ON_HOLD in str(err), err
        refused(lambda: C.fs_send(f"relationships/{rel['client']}/messages/held-1", tok["coach"],
                                  {"senderUid": uid["coach"], "type": "text", "text": "hello from a held coach"}), 403)
        err = refused(lambda: call("create_coach_invite", tok["coach"], {}))
        assert coaching_errors.COACH_ON_HOLD in str(err), err
        err = refused(lambda: call("schedule_live_session", tok["coach"], {
            "subId": sub["client"], "startsAt": iso(dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=2)), "minutes": 45,
            "link": "https://meet.google.com/abc-defg-hij"}))
        assert coaching_errors.COACH_ON_HOLD in str(err), err
        # The client is not blocked: she can still write in the thread.
        C.fs_send(f"relationships/{rel['client']}/messages/held-2", tok["client"],
                  {"senderUid": uid["client"], "type": "text", "text": "I am still here"})

    def coach_confirms_on_hold():
        assert call("coach_confirm_payment", tok["coach"], {"paymentId": pay["client3"]})["status"] == "confirmed"
        assert payment("client3")["status"] == "confirmed"
        # Her confirmation (re)starts that coaching now; the extension is measured from here.
        S["ends_before"]["client3"] = when(fs_get(f"subscriptions/{sub['client3']}", owner)["endsAt"])
        # Full confirmation moves her end date from the bounded week to the whole package; the hold's extension counts from there.
        S["ends_before"]["client3"] = when(fs_get(f"subscriptions/{sub['client3']}", owner)["endsAt"])

    def coach_records_fee_and_staff_rejects_one():
        t = clock["held"] + dt.timedelta(hours=12)
        for n, name in enumerate(CLIENTS):
            out = fees.record_payment(db, uid["coach"], {"statementId": bill[name], "txnNumber": f"FEE-100{n}-AAA"}, coach_v="active", now=t)
            assert out["status"] == "paid_claimed", out
            assert bill_of(name)["status"] == "paid_claimed"
        assert fs_get(f"coachPrivate/{uid['coach']}", owner)["hold"], "her own 'I paid' must not end the hold"
        # Staff reject one claim: back to open with the reason; she records it again with a real number.
        fees.reject_claim(db, uid["admin"], {"statementId": bill["client3"], "reason": "No such transfer in the account"}, now=t, notify=rec)
        row = bill_of("client3")
        assert row["status"] == "open" and row["claimRejected"]["reason"].startswith("No such"), row
        assert sent("instapayFeeClaimRejected", uid["coach"])
        out = fees.record_payment(db, uid["coach"], {"statementId": bill["client3"], "txnNumber": "FEE-1003-BBB"}, coach_v="active", now=t)
        assert out["status"] == "paid_claimed"

    def staff_confirms_and_hold_releases():
        t = clock["held"] + dt.timedelta(days=1, hours=23)
        before = len(pushes)
        for name in ("client", "client2"):
            assert fees.confirm_payment(db, uid["admin"], {"statementId": bill[name]}, now=t, notify=rec, notify_client=rec)["status"] == "paid"
            assert fs_get(f"coachPrivate/{uid['coach']}", owner)["hold"], "a hold ends only when the last bill is confirmed"
        assert fees.confirm_payment(db, uid["admin"], {"statementId": bill["client3"]}, now=t, notify=rec, notify_client=rec)["status"] == "paid"
        assert fs_get(f"coachPrivate/{uid['coach']}", owner).get("hold") is None
        assert fs_get(f"coaches/{uid['coach']}", owner)["acceptingClients"] is True
        gap = t - clock["held"]
        for name in CLIENTS:
            assert fs_get(f"relationships/{rel[name]}", tok[name])["coachAway"] is False
            row = fs_get(f"subscriptions/{sub[name]}", owner)
            moved = when(row["endsAt"]) - S["ends_before"][name]
            assert abs((moved - gap).total_seconds()) < 2, (name, moved, gap)
            assert int(row["holdCreditSeconds"]) == int(gap.total_seconds()), row
            assert payment(name)["feeState"] == "settled"
        got = pushes[before:]
        assert [p for p in got if p[1] == "instapayAccountActive" and p[0] == uid["coach"]], got
        assert {p[0] for p in got if p[1] == "coachBack"} == {uid[n] for n in CLIENTS}, got

    def coach_works_again():
        err = refused(lambda: call("respond_coaching_request", tok["coach"], {"subId": "nosuchsub0001", "decision": "accept"}))
        assert coaching_errors.COACH_ON_HOLD not in str(err), err
        assert call("create_coach_invite", tok["coach"], {})["code"]

    # ------------------------------------------------------------------ refunds
    def refund_and_answer():
        assert call("request_refund", tok["client"], {"paymentId": pay["client"]})["status"] == "refund_requested"
        row = payment("client")
        out = call("record_instapay_refund", tok["coach"], {
            "paymentId": pay["client"], "txnNumber": "40123456789012", "amountPiasters": row["amountPiasters"],
            "kind": "refund", "paidAt": iso(dt.datetime.now(dt.timezone.utc))})
        assert out["status"] == "refunded", out
        assert payment("client")["status"] == "refunded"
        assert fs_get(f"subscriptions/{sub['client']}", owner)["status"] != "active", "a recorded refund ends the package"

    def refund_denied():
        assert call("request_refund", tok["client2"], {"paymentId": pay["client2"]})["status"] == "refund_requested"
        out = call("deny_refund", tok["coach"], {"paymentId": pay["client2"], "reasonCode": "sessions_delivered"})
        assert out["status"] == "refund_denied", out
        assert fs_get(f"subscriptions/{sub['client2']}", owner)["status"] == "active"

    def stranger_cannot_touch_payment():
        refused(lambda: call("request_refund", tok["client3"], {"paymentId": pay["client2"]}), "NOT_FOUND", "PERMISSION_DENIED")
        refused(lambda: call("coach_confirm_payment", tok["client"], {"paymentId": pay["client3"]}), "PERMISSION_DENIED")

    N = "coach onboards (application, approval, claim)"
    A = "coach accepts and uploads the signed Coach Agreement v2; staff verify"
    step("seed: six phone accounts (coach, three clients, reviewer, admin)", lambda: None)
    step("emulator only: config/payments.enabled = true", switch_on)
    step("admin sets Own Hub's fake receiving account", receiving_account)
    step(N, onboard)
    step(A, agreement, N)
    step("coach sets her InstaPay address (a phone number is refused)", coach_address, A)
    step("coach saves a package with 2 live sessions", package, A)
    step("coach makes her invite code", invite, A)
    step("three clients ask: her code, no code, a wrong code (last one auto-accepted)", requests, "coach saves a package with 2 live sessions",
         "coach makes her invite code", "coach sets her InstaPay address (a phone number is refused)")
    step("coach accepts two by hand: awaiting payment", accept_all, "three clients ask: her code, no code, a wrong code (last one auto-accepted)")
    step("each client creates a payment: unique amount, address, reference, replay-safe", create_payments, "coach accepts two by hand: awaiting payment")
    step("each client uploads a synthetic receipt: judged GREEN (OCR stand-in)", submit_proofs, "each client creates a payment: unique amount, address, reference, replay-safe")
    step("coaching starts; fee owed at 750 bps (invite) and 1500 bps; bill due +3 days, hold +7", coaching_starts_and_fee_owed, "each client uploads a synthetic receipt: judged GREEN (OCR stand-in)")
    step("coach confirms two payments received: access full", coach_confirms_two, "coaching starts; fee owed at 750 bps (invite) and 1500 bps; bill due +3 days, hold +7")
    T = "coach confirms two payments received: access full"
    step("clock +1h: statement-ready push per bill", statement_ready, T)
    step("clock +49h: coach reminded about the unanswered proof", coach_reminded, "clock +1h: statement-ready push per bill")
    step("clock +2.5 days: fee due-soon push per bill", due_soon, "clock +1h: statement-ready push per bill")
    step("clock +3 days: fee due-today push per bill, no hold yet", due_today, "clock +2.5 days: fee due-soon push per bill")
    step("clock +7 days: account on hold, no new clients, fee-overdue pushes", hold_at_day_seven, "clock +3 days: fee due-today push per bill, no hold yet")
    step("clients see coachAway on their relationship", client_sees_coach_away, "clock +7 days: account on hold, no new clients, fee-overdue pushes")
    step("held coach cannot accept, message, share (invite) or schedule; client can still write", hold_blocks_the_coach, "clock +7 days: account on hold, no new clients, fee-overdue pushes")
    step("held coach can still confirm a payment received", coach_confirms_on_hold, "clock +7 days: account on hold, no new clients, fee-overdue pushes")
    step("coach records her fee payments (hold stays); staff reject one claim; she records again", coach_records_fee_and_staff_rejects_one, "held coach can still confirm a payment received")
    step("staff confirm the bills: hold released, end dates extended, pushes sent", staff_confirms_and_hold_releases, "coach records her fee payments (hold stays); staff reject one claim; she records again")
    step("released coach accepts, shares and works again", coach_works_again, "staff confirm the bills: hold released, end dates extended, pushes sent")
    step("refund: client requests, coach records the refund, package ends", refund_and_answer, "staff confirm the bills: hold released, end dates extended, pushes sent")
    step("refund: client requests, coach denies, coaching continues", refund_denied, "staff confirm the bills: hold released, end dates extended, pushes sent")
    step("another client and a client acting as coach are refused", stranger_cannot_touch_payment, "each client creates a payment: unique amount, address, reference, replay-safe")

    counts = {k: sum(1 for r in C.results if r[0] == k) for k in ("PASS", "FAIL", "SKIP")}
    print(f"\n{counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped")
    for status, title, why in C.results:
        if status == "FAIL":
            print(f"FAIL  {title}\n      {why}")
    print("pushes seen (clock-driven steps):", sorted({p[1] for p in pushes}))
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
