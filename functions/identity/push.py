"""The one push the review loop sends: a woman reviewer approved her.

She waits on C14 with the app closed for up to 72 hours (config.
REVIEW_SLA_HOURS). Without this, the only way to learn the app had opened was
to keep opening it.

Sent only to the tokens on users/{uid}/devices, which the app writes after she
said yes to notifications on C14 (rules: key whitelist token, platform,
appVersion, locale, updatedAt). No token, no push: nothing here asks.

The text names no check, no ID and no result beyond "done", because a lock
screen is read by whoever holds the phone. No reason code, no flag id and no
uid is ever put in the payload.
"""

from __future__ import annotations

from typing import Optional

from . import config

DEVICES = "devices"
"""users/{uid}/devices/{deviceId}: one document per phone that said yes."""

APPROVED_TEXT = {
    "en": ("Own Hub", "Your check is done. You can open Own Hub now."),
    "ar": ("Own Hub", "اكتمل التحقق. يمكنكِ فتح Own Hub الآن."),
}
"""Title and body by the device's locale. Arabic is the fallback: most of the
women this is for read the app in Arabic."""

DATA_KIND = "verificationApproved"
"""The only data key: what the push is about, so the app can open C13."""


def approved_text(locale: Optional[str]) -> tuple[str, str]:
    return APPROVED_TEXT.get(locale or "", APPROVED_TEXT["ar"])


def send_approved(uid: str, db, messaging) -> int:
    """Sends the approval to each of her registered phones. Returns how many
    were accepted. A token the push service says is gone is deleted, so a
    phone she no longer has is not written to again."""
    devices = (
        db.collection(config.COL_USERS).document(uid).collection(DEVICES).stream()
    )
    by_locale: dict[str, list[str]] = {}
    refs = {}
    for snapshot in devices:
        data = snapshot.to_dict() or {}
        token = data.get("token")
        if not isinstance(token, str) or not token:
            continue
        locale = data.get("locale") if data.get("locale") in APPROVED_TEXT else "ar"
        by_locale.setdefault(locale, []).append(token)
        refs[token] = snapshot.reference

    accepted = 0
    for locale, tokens in by_locale.items():
        title, body = approved_text(locale)
        response = messaging.send_each_for_multicast(
            messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=title, body=body),
                data={"kind": DATA_KIND},
            )
        )
        for token, result in zip(tokens, response.responses):
            if result.success:
                accepted += 1
            elif isinstance(result.exception, messaging.UnregisteredError):
                refs[token].delete()
    return accepted
