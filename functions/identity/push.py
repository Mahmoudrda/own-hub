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

from typing import Callable, Optional

from . import config

DEVICES = "devices"
"""users/{uid}/devices/{deviceId}: one document per phone that said yes."""

APPROVED_TEXT = {
    "en": ("Own Hub", "Your check is done. You can open Own Hub now."),
    "ar": ("Own Hub", "خلّصنا التحقق. تقدري تفتحي Own Hub دلوقتي."),
}
"""Title and body by the device's locale. Arabic is the fallback: most of the
women this is for read the app in Arabic."""

DATA_KIND = "verificationApproved"
"""The only data key: what the push is about, so the app can open C13."""


def approved_text(locale: Optional[str]) -> tuple[str, str]:
    return APPROVED_TEXT.get(locale or "", APPROVED_TEXT["ar"])


def send_to_user(
    uid: str,
    title: str,
    body: str,
    data: dict,
    db,
    messaging,
    *,
    texts: Optional[Callable[[str], tuple[str, str]]] = None,
    fallback_locale: str = "ar",
) -> int:
    """Sends one push to each of her registered phones. Returns how many were
    accepted. A token the push service says is gone is deleted, so a phone she
    no longer has is not written to again.

    With `texts`, the title and body come from `texts(locale)` for each phone's
    own locale (a phone with none, or one we have no text for, hears
    `fallback_locale`); otherwise every phone gets `title` and `body`."""
    devices = (
        db.collection(config.COL_USERS).document(uid).collection(DEVICES).stream()
    )
    by_locale: dict[str, list[str]] = {}
    refs = {}
    for snapshot in devices:
        row = snapshot.to_dict() or {}
        token = row.get("token")
        if not isinstance(token, str) or not token:
            continue
        locale = row.get("locale") if row.get("locale") in APPROVED_TEXT else fallback_locale
        by_locale.setdefault(locale, []).append(token)
        refs[token] = snapshot.reference

    accepted = 0
    for locale, tokens in by_locale.items():
        shown_title, shown_body = texts(locale) if texts else (title, body)
        response = messaging.send_each_for_multicast(
            messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(
                    title=shown_title, body=shown_body
                ),
                data=dict(data),
            )
        )
        for token, result in zip(tokens, response.responses):
            if result.success:
                accepted += 1
            elif isinstance(result.exception, messaging.UnregisteredError):
                refs[token].delete()
    return accepted


def send_approved(uid: str, db, messaging) -> int:
    """Sends the approval to each of her registered phones. Returns how many
    were accepted."""
    return send_to_user(
        uid, "", "", {"kind": DATA_KIND}, db, messaging, texts=approved_text
    )
