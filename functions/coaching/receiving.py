"""Where clients send money, and who the seller is on a receipt.

Both live in coachingConfig/ and are written only here, by an admin. Staff may
read the accounts; a client sees them only as the snapshot copied into her own
subscription when it moves to awaiting_payment.
"""

from __future__ import annotations

import datetime as dt
import re

from . import common, receipts

ACCOUNTS = ("coachingConfig", "receivingAccounts")
SELLER = ("coachingConfig", "seller")

_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

SELLER_REQUIRED = {
    "companyNameEn": (2, 120),
    "companyNameAr": (2, 120),
    "addressEn": (5, 300),
    "addressAr": (5, 300),
    "commercialRegistration": (3, 40),
    "taxCard": (3, 40),
}


def accounts_ref(db):
    return db.collection(ACCOUNTS[0]).document(ACCOUNTS[1])


def seller_ref(db):
    return db.collection(SELLER[0]).document(SELLER[1])


def get(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    common.log_access(db, actor_uid, "receiving.get", "receivingAccounts", now)
    snap = accounts_ref(db).get()
    row = snap.to_dict() if snap.exists else {}
    seller = seller_ref(db).get()
    seller_row = receipts.seller_block(seller.to_dict()) if seller.exists else None
    return {
        "instapay": row.get("instapay"),
        "vodafoneCash": row.get("vodafoneCash"),
        "version": row.get("version", 0),
        "seller": seller_row,
    }


def _account(rail: str, raw) -> dict:
    if not isinstance(raw, dict) or not isinstance(raw.get("enabled"), bool):
        raise common.bad()
    if not raw["enabled"] and raw.get("address") == "" and raw.get("holderName") == "":
        # A rail she switched off and left empty.
        return {"address": "", "holderName": "", "enabled": False}
    if not common.account_ok(rail, raw.get("address")):
        raise common.bad()
    return {
        "address": raw["address"],
        "holderName": common.text(raw.get("holderName"), min_len=3, max_len=80),
        "enabled": raw["enabled"],
    }


def set_accounts(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    accounts = {rail: _account(rail, data.get(rail)) for rail in common.RAILS}
    if not any(account["enabled"] for account in accounts.values()):
        raise common.bad()
    common.log_access(db, actor_uid, "receiving.set", "receivingAccounts", now)
    ref = accounts_ref(db)

    def body(transaction):
        snap = ref.get(transaction=transaction)
        version = (snap.to_dict() or {}).get("version", 0) + 1 if snap.exists else 1
        transaction.set(ref, {**accounts, "version": version, "updatedAt": now})
        return version

    return {"version": common.run(db, body)}


def set_seller(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    row = {key: common.text(data.get(key), min_len=low, max_len=high) for key, (low, high) in SELLER_REQUIRED.items()}
    email = common.text(data.get("supportEmail"), min_len=5, max_len=120)
    if not _EMAIL.match(email):
        raise common.bad()
    row["supportEmail"] = email
    row["vatRatePercent"] = common.whole(data.get("vatRatePercent"), low=0, high=14)
    row["supportPhone"] = common.optional_text(data.get("supportPhone"), max_len=30)
    row["updatedAt"] = now
    common.log_access(db, actor_uid, "receiving.seller", "seller", now)
    seller_ref(db).set(row)
    return {"ok": True}
