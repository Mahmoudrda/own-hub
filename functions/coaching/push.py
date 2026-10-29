"""The pushes private coaching sends, one generic line per kind.

A lock screen is read by whoever holds the phone, so no text here names a
coach or a client, an amount, a plan or a message. The data payload is the kind
and nothing else; the app opens the right screen from it.
"""

from __future__ import annotations

from typing import Optional

from identity import push as identity_push

TITLE = "Own Hub"
NEW_MESSAGE_TEXT_MODE = "generic"  # "generic" or "first_name" (owner decision 5)

TEXT: dict[str, dict[str, tuple[str, str]]] = {
    "coachDecision": {
        "en": (TITLE, "There is news about your coach application. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن طلب انضمامك كمدربة. افتحي Own Hub وشوفيه."),
    },
    "portfolioDecision": {
        "en": (TITLE, "There is news about the photos in your coach profile. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن الصور في صفحتك كمدربة. افتحي Own Hub وشوفيه."),
    },
    "agreementDecision": {
        "en": (TITLE, "There is news about your signed agreement. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن الاتفاقية الموقّعة بتاعتك. افتحي Own Hub وشوفيه."),
    },
    "coachingRequest": {
        "en": (TITLE, "You have a new coaching request."),
        "ar": (TITLE, "عندك طلب تدريب جديد."),
    },
    "requestAnswered": {
        "en": (TITLE, "Your coaching request has an answer."),
        "ar": (TITLE, "طلب التدريب بتاعك اتردّ عليه."),
    },
    "updateToContinue": {
        "en": (TITLE, "Update Own Hub, then ask your coach again."),
        "ar": (TITLE, "حدّثي Own Hub، وبعدين اطلبي من مدرّبتك تاني."),
    },
    "requestExpired": {
        "en": (TITLE, "Your coaching request ran out of time. You can ask her again or choose another coach."),
        "ar": (TITLE, "طلب التدريب بتاعك خلص وقته. تقدري تطلبي منها تاني أو تختاري مدربة تانية."),
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
    "newMessageFrom": {
        "en": (TITLE, "{name} sent you a message."),
        "ar": (TITLE, "{name} بعتتلك رسالة."),
    },
    "sessionProposed": {
        "en": (TITLE, "A live session has been proposed. Open Own Hub to answer."),
        "ar": (TITLE, "اتقترحت جلسة لايف. افتحي Own Hub وردّي عليها."),
    },
    "endsSoon": {
        "en": (TITLE, "Your coaching ends in a few days."),
        "ar": (TITLE, "التدريب بتاعك هيخلص كمان كام يوم."),
    },
    "checkInDue": {
        "en": (TITLE, "Your weekly check-in is ready. It takes under a minute."),
        "ar": (TITLE, "التشيك إن الأسبوعي جاهز. بياخد أقل من دقيقة."),
    },
    "checkInFollowUp": {
        "en": (TITLE, "No rush. Last week's check-in is still here when you are ready."),
        "ar": (TITLE, "من غير استعجال. التشيك إن بتاع الأسبوع اللي فات لسه موجود وقت ما تحبي."),
    },
    "coachEndsSoon": {
        "en": (TITLE, "The coaching of one of your clients ends in a few days."),
        "ar": (TITLE, "تدريب واحدة من عميلاتك هيخلص كمان كام يوم."),
    },
    "checkInAnswered": {
        "en": (TITLE, "A client answered her weekly check-in."),
        "ar": (TITLE, "عميلة جاوبت على التشيك إن الأسبوعي."),
    },
    "checkInReply": {
        "en": (TITLE, "Your coach replied to your check-in."),
        "ar": (TITLE, "المدربة بتاعتك ردّت على التشيك إن."),
    },
    "promoDecision": {
        "en": (TITLE, "There is news about your video for Own Hub. Open Own Hub to see it."),
        "ar": (TITLE, "فيه خبر عن الفيديو بتاعك لـ Own Hub. افتحي Own Hub وشوفيه."),
    },
    "promoReminder": {
        "en": (TITLE, "A gentle reminder: Own Hub would love your videos for this month. Open Own Hub to add them."),
        "ar": (TITLE, "تذكير لطيف: Own Hub مستني فيديوهاتك للشهر ده. افتحي Own Hub وضيفيها."),
    },
    "coachingEnded": {
        "en": (TITLE, "Your coaching has ended."),
        "ar": (TITLE, "التدريب بتاعك خلص."),
    },
    "coachBack": {
        "en": (TITLE, "Your coach is back. Everything is as you left it."),
        "ar": (TITLE, "المدربة بتاعتك رجعت. كل حاجة زي ما سيبتيها."),
    },
    "payoutRecorded": {
        "en": (TITLE, "A payout has been recorded for you."),
        "ar": (TITLE, "اتسجّلت دفعة ليكي."),
    },
}


def text_for(kind: str, locale: Optional[str], name: str = "") -> tuple[str, str]:
    """Title and body for a kind. Arabic is the fallback, as for every push."""
    by_locale = TEXT[kind]
    title, body = by_locale.get(locale or "", by_locale["ar"])
    return title, body.replace("{name}", name)


def send_kind(
    uid: str, kind: str, *, db, messaging, locale: Optional[str] = None
) -> int:
    """Pushes one kind to each of her phones, in each phone's own language
    (`locale` stands in for a phone that did not say). Returns how many were
    accepted; an unknown kind sends nothing."""
    kind, _, name = kind.partition(":")
    if kind not in TEXT:
        return 0
    return identity_push.send_to_user(
        uid,
        "",
        "",
        {"kind": kind},
        db,
        messaging,
        texts=lambda phone_locale: text_for(kind, phone_locale, name),
        fallback_locale=locale if locale in ("en", "ar") else "ar",
    )
