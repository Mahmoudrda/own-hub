"""An in-memory review.ReviewStore, faithful to store.FirestoreReviewStore."""

from __future__ import annotations

import itertools

from identity import dedupe, decisions, ledger, reasons, store


class FakeReviewStore:
    def __init__(self, phone="+201005550132"):
        self.states: dict[str, dict] = {}
        self.daily: dict[tuple, int] = {}
        self.ledgers: dict[str, dict] = {}
        self.flags: dict[str, dict] = {}
        self.jobs: dict[str, dict] = {}
        self.registry: dict[str, dedupe.RegistryEntry] = {}
        self.minted: list[str] = []
        self.access: list[tuple] = []
        self.notified: list[tuple] = []
        self.phones: dict[str, str] = {}
        self.review_consents: dict[str, dict] = {}
        self.verifying: set[str] = set()
        self.approved_pushes: list[str] = []
        self.default_phone = phone
        self._ids = itertools.count(1)

    # state
    def verification_state(self, uid):
        return self.states.get(uid, {}).get("state")

    def set_verification_state(
        self, uid, state, *, route=None, scheduled_for=None, decided=False, reset_booking=False
    ):
        assert state in store.VERIFICATION_STATES
        current = self.states.setdefault(uid, {})
        current["state"] = state
        if reset_booking:
            current["reviewRoute"] = None
            current["reviewScheduledFor"] = None
        if route is not None:
            current["reviewRoute"] = route
        if scheduled_for is not None:
            current["reviewScheduledFor"] = scheduled_for
        if decided:
            current["decidedAt"] = "ts"

    def notify_approved(self, uid):
        self.approved_pushes.append(uid)

    def verify_in_flight(self, uid):
        return uid in self.verifying

    def uid_daily_count_and_increment(self, uid, field):
        key = (uid, field)
        self.daily[key] = self.daily.get(key, 0) + 1
        return self.daily[key]

    def write_review_consent(self, uid, path, flag_id):
        self.review_consents[uid] = {"path": path, "flagId": flag_id}

    def review_consented_flags(self, pairs):
        return {
            flag_id
            for uid, flag_id in pairs
            if self.review_consents.get(uid, {}).get("flagId") == flag_id
        }

    def _ledger(self, uid):
        return self.ledgers.setdefault(uid, {})

    def open_flag_id(self, uid):
        current = self._ledger(uid).get("openFlagId")
        if current and self.flags.get(current, {}).get("state") == decisions.PENDING_REVIEW:
            return current
        return None

    def ocr_submissions(self, uid):
        return int(self._ledger(uid).get("ocr_submissions", 0))

    def new_job_payload(self, uid, decision, attempt):
        return {"uid": uid, "state": decision.outcome, "reasons": list(decision.reasons)}

    def open_flag(self, uid, job_payload, flag_payload, *, job_id=None, mark_duplicate=False):
        current = self.open_flag_id(uid)
        if current:
            return current, False
        new_id = job_id or f"job-{next(self._ids)}"
        if job_payload is not None:
            self.jobs[new_id] = dict(job_payload)
        payload = dict(flag_payload)
        payload["jobId"] = new_id
        payload["createdAt"] = "ts"
        self.flags[new_id] = payload
        self._ledger(uid)["openFlagId"] = new_id
        if mark_duplicate:
            self._ledger(uid)["duplicateFlagRaised"] = True
        return new_id, True

    def get_flag(self, flag_id):
        return dict(self.flags[flag_id]) if flag_id in self.flags else None

    def list_open(self, limit):
        return [
            (k, v) for k, v in self.flags.items() if v["state"] == decisions.PENDING_REVIEW
        ][:limit]

    def mark_scheduled(self, flag_id, route, when, reviewer_uid, sla_expires_at):
        # Faithful to the store's single transaction: check, then write both.
        flag = self.flags.get(flag_id, {})
        if flag.get("state") != decisions.PENDING_REVIEW or not flag.get("uid"):
            return reasons.REVIEW_NOT_PENDING
        flag.update(
            {
                "route": route,
                "scheduledFor": when,
                "reviewerUid": reviewer_uid,
                "slaExpiresAt": sla_expires_at,
            }
        )
        FakeReviewStore.set_verification_state(
            self, flag["uid"], "pending", route=route, scheduled_for=when
        )
        return None

    def close_flag(
        self, flag_id, *, uid, state, reviewer_uid, reviewer_reason, id_hmac=None,
        user_state=None,
    ):
        # Faithful to the store's single transaction: check, then write all.
        if self.flags.get(flag_id, {}).get("state") != decisions.PENDING_REVIEW:
            return reasons.REVIEW_NOT_PENDING
        if id_hmac:
            verdict = dedupe.judge(self.registry.get(id_hmac), uid)
            if not verdict.ok:
                return verdict.reason or reasons.DUPLICATE_ID
            if not verdict.is_reverification:
                self.registry[id_hmac] = dedupe.RegistryEntry(uid, dedupe.STATE_ACTIVE, 1)
        self.flags[flag_id].update(
            {"state": state, "decidedBy": reviewer_uid, "reviewerReason": reviewer_reason}
        )
        if flag_id in self.jobs:
            self.jobs[flag_id]["state"] = state
        if self._ledger(uid).get("openFlagId") == flag_id:
            self._ledger(uid)["openFlagId"] = None
        self.review_consents.pop(uid, None)
        if user_state is not None:
            FakeReviewStore.set_verification_state(self, uid, user_state, decided=True)
        return None

    def stale_flags(self, now, limit):
        return [
            (k, dict(v))
            for k, v in self.flags.items()
            if v["state"] == decisions.PENDING_REVIEW and v["slaExpiresAt"] < now
        ][:limit]

    def expire_flag(self, flag_id, uid, now):
        flag = self.flags.get(flag_id, {})
        if flag.get("state") != decisions.PENDING_REVIEW or not flag["slaExpiresAt"] < now:
            return False
        flag["state"] = decisions.RETRY_REQUIRED
        if flag_id in self.jobs:
            self.jobs[flag_id]["state"] = decisions.RETRY_REQUIRED
        if uid and self._ledger(uid).get("openFlagId") == flag_id:
            self._ledger(uid)["openFlagId"] = None
        if uid:
            self.review_consents.pop(uid, None)
            FakeReviewStore.set_verification_state(self, uid, "retry", reset_booking=True)
        return True

    def grant_bonus(self, uid, flag_id):
        data = self._ledger(uid)
        budget = ledger.Budget(
            spent_micro_usd=int(data.get("spent_micro_usd", 0)),
            bonus_ocr_submissions=int(data.get("bonusOcrSubmissions", 0)),
        )
        granted = tuple(data.get("bonusGrantedFor", ()))
        if not ledger.may_grant_bonus(budget, flag_id, granted):
            return False
        data["bonusOcrSubmissions"] = budget.bonus_ocr_submissions + 1
        data["bonusGrantedFor"] = list(granted + (flag_id,))
        return True

    def mark_mint_pending(self, flag_id):
        self.flags[flag_id]["mintPending"] = True

    def clear_mint_pending(self, flag_id):
        self.flags[flag_id].pop("mintPending", None)

    def clear_mint_pending_for(self, uid):
        for flag in self.flags.values():
            if flag.get("uid") == uid:
                flag.pop("mintPending", None)

    def mint_pending_flags(self, limit):
        return [
            (k, v.get("uid"))
            for k, v in self.flags.items()
            if v.get("mintPending") and v.get("state") == decisions.APPROVED
        ][:limit]

    def claim(self, id_hmac, uid):
        verdict = dedupe.judge(self.registry.get(id_hmac), uid)
        if verdict.ok and not verdict.is_reverification:
            self.registry[id_hmac] = dedupe.RegistryEntry(uid, dedupe.STATE_ACTIVE, 1)
        return verdict

    def mint_verified(self, uid):
        self.minted.append(uid)

    def phone_for(self, uid):
        return self.phones.get(uid, self.default_phone)

    def log_access(self, reviewer_uid, flag_id, action):
        self.access.append((reviewer_uid, flag_id, action))

    def pepper(self):
        return b"test-pepper"

    def notify(self, flag_id, codes):
        self.notified.append((flag_id, tuple(codes)))
