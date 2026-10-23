"""The pushes private coaching sends, one generic line per kind.

A lock screen is read by whoever holds the phone, so no text here names a
coach or a client, an amount, a plan or a message. The data payload is the kind
and nothing else; the app opens the right screen from it.
"""

from __future__ import annotations

from typing import Optional

from identity import push as identity_push

TITLE = "Own Hub"

TEXT: dict[str, dict[str, tuple[str, str]]] = {
    "coachDecision": {
        "en": (TITLE, "There is news about your coach application. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن طلب انضمامك كمدربة. افتحي Own Hub وشوفيه."),
    },
    "portfolioDecision": {
        "en": (TITLE, "There is news about the photos in your coach profile. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن الصور في صفحتك كمدربة. افتحي Own Hub وشوفيه."),
    },
    "coachingRequest": {
        "en": (TITLE, "You have a new coaching request."),
        "ar": (TITLE, "عندك طلب تدريب جديد."),
    },
    "requestAnswered": {
        "en": (TITLE, "Your coaching request has an answer."),
        "ar": (TITLE, "طلب التدريب بتاعك اتردّ عليه."),
    },
    "paymentApproved": {
        "en": (TITLE, "Your payment is confirmed."),
        "ar": (TITLE, "الدفع بتاعك اتأكد."),
    },
    "paymentRejected": {
        "en": (TITLE, "We could not confirm your payment. Open Own Hub to see why."),
        "ar": (TITLE, "مقدرناش نأكد الدفع. افتحي Own Hub وشوفي السبب."),
    },
    "coachingStarted": {
        "en": (TITLE, "Your coaching has started."),
        "ar": (TITLE, "التدريب بتاعك بدأ."),
    },
    "planShared": {
        "en": (TITLE, "A new plan is waiting for you."),
        "ar": (TITLE, "فيه خطة جديدة مستنياكي."),
    },
    "newMessage": {
        "en": (TITLE, "You have a new message."),
        "ar": (TITLE, "عندك رسالة جديدة."),
    },
    "sessionProposed": {
        "en": (TITLE, "A live session has been proposed. Open Own Hub to answer."),
        "ar": (TITLE, "اتقترحت جلسة لايف. افتحي Own Hub وردّي عليها."),
    },
    "endsSoon": {
        "en": (TITLE, "Your coaching ends in a few days."),
        "ar": (TITLE, "التدريب بتاعك هيخلص كمان كام يوم."),
    },
    "coachingEnded": {
        "en": (TITLE, "Your coaching has ended."),
        "ar": (TITLE, "التدريب بتاعك خلص."),
    },
    "payoutRecorded": {
        "en": (TITLE, "A payout has been recorded for you."),
        "ar": (TITLE, "اتسجّلت دفعة ليكي."),
    },
}


def text_for(kind: str, locale: Optional[str]) -> tuple[str, str]:
    """Title and body for a kind. Arabic is the fallback, as for every push."""
    by_locale = TEXT[kind]
    return by_locale.get(locale or "", by_locale["ar"])


def send_kind(
    uid: str, kind: str, *, db, messaging, locale: Optional[str] = None
) -> int:
    """Pushes one kind to each of her phones, in each phone's own language
    (`locale` stands in for a phone that did not say). Returns how many were
    accepted; an unknown kind sends nothing."""
    if kind not in TEXT:
        return 0
    return identity_push.send_to_user(
        uid,
        "",
        "",
        {"kind": kind},
        db,
        messaging,
        texts=lambda phone_locale: text_for(kind, phone_locale),
        fallback_locale=locale if locale in ("en", "ar") else "ar",
    )
