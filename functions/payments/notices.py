"""Pushes for payments. A lock screen is read by whoever holds the phone, so no
text names a person or carries an amount (spec section 8, default).

They go only to phones that said yes to payment alerts (topic "payments", asked
for on the coach's Payments inbox and on a payment's status screen), never to a
phone that only said yes on C14."""

from __future__ import annotations

import re
from typing import Optional

from identity import push as identity_push

TITLE = "Own Hub"

TEXT: dict[str, dict[str, tuple[str, str]]] = {
    # to the client
    "instapayReminder": {"en": (TITLE, "Your payment request is still open. Open Own Hub to finish or cancel."),
                    "ar": (TITLE, "طلب الدفع لسه مفتوح. افتحي Own Hub وكمّلي أو الغي الطلب.")},
    "instapayConfirmed": {"en": (TITLE, "Your coach confirmed your payment."),
                         "ar": (TITLE, "المدربة أكدت إنها استلمت الدفع.")},
    "instapayNotReceived": {"en": (TITLE, "Your coach says the payment has not reached her yet. Open Own Hub to add your proof."),
                         "ar": (TITLE, "المدربة بتقول إن الدفع لسه ماوصلهاش. افتحي Own Hub وضيفي إثبات التحويل.")},
    "instapayDifferentAmount": {"en": (TITLE, "Your coach received a different amount. Open Own Hub to see it."),
                        "ar": (TITLE, "المدربة استلمت مبلغ مختلف. افتحي Own Hub وشوفيه.")},
    "instapayCoachReported": {"en": (TITLE, "Your coach says you paid. Open Own Hub to confirm."),
                      "ar": (TITLE, "المدربة بتقول إنك دفعتي. افتحي Own Hub وأكدي.")},
    "instapayReviewStarted": {"en": (TITLE, "Our team is looking at your payment. You do not need to do anything now."),
                      "ar": (TITLE, "فريقنا بيراجع الدفع. مش مطلوب منك حاجة دلوقتي.")},
    "instapayReviewDecided": {"en": (TITLE, "Your payment review has a decision. Open Own Hub to see it."),
                      "ar": (TITLE, "مراجعة الدفع ليها قرار. افتحي Own Hub وشوفيه.")},
    "instapayCoachReviewDecided": {"en": (TITLE, "Your payment review has a decision. Open Own Hub to see it."),
                                   "ar": (TITLE, "مراجعة الدفع ليها قرار. افتحي Own Hub وشوفيه.")},
    "instapayRefundRecorded": {"en": (TITLE, "A refund was recorded. Open Own Hub to see it."),
                       "ar": (TITLE, "اتسجّل استرداد. افتحي Own Hub وشوفيه.")},
    "instapayAddressChanged": {"en": (TITLE, "Your coach updated her payment details. Open Own Hub before you pay."),
                       "ar": (TITLE, "المدربة غيّرت بيانات الدفع بتاعتها. افتحي Own Hub قبل ما تدفعي.")},
    "instapayAccessEndsSoon": {"en": (TITLE, "Your temporary access ends soon. Open Own Hub to see what is left to do."),
                       "ar": (TITLE, "الفتح المؤقت هيخلص قريب. افتحي Own Hub وشوفي المطلوب.")},
    "instapayPaused": {"en": (TITLE, "InstaPay payments are paused for your account. Open Own Hub for details."),
                       "ar": (TITLE, "الدفع بإنستا باي موقوف لحسابك. افتحي Own Hub للتفاصيل.")},
    # to the coach
    "instapayProofSent": {"en": (TITLE, "A client sent proof of payment. Open Own Hub to check your bank."),
                  "ar": (TITLE, "عميلة بعتت إثبات الدفع. افتحي Own Hub وراجعي حسابك البنكي.")},
    "instapayCoachReminder": {"en": (TITLE, "A payment is waiting for you to check. Please open Own Hub today."),
                        "ar": (TITLE, "فيه دفع مستنيكي تراجعيه. افتحي Own Hub النهارده.")},
    "instapayConfirmedByClient": {"en": (TITLE, "A client confirmed she paid. Open Own Hub to see it."),
                                 "ar": (TITLE, "عميلة أكدت إنها دفعت. افتحي Own Hub وشوفي.")},
    "instapayDisputeOpened": {"en": (TITLE, "A payment needs a second look. Open Own Hub to see what we need."),
                      "ar": (TITLE, "فيه دفع محتاج مراجعة تانية. افتحي Own Hub وشوفي المطلوب.")},
    "instapayRefundRequested": {"en": (TITLE, "A client asked for a refund. Open Own Hub to answer within 3 days."),
                        "ar": (TITLE, "عميلة طلبت استرداد. افتحي Own Hub وردّي خلال 3 أيام.")},
    "instapayAddressChangedCoach": {"en": (TITLE, "Your payment details were changed. If it was not you, contact us now."),
                       "ar": (TITLE, "بيانات الدفع بتاعتك اتغيّرت. لو مش انتي اللي غيّرتيها كلمينا حالًا.")},
    "instapayStatementReady": {"en": (TITLE, "You have a new Own Hub fee to pay. Open Own Hub to see it."),
                       "ar": (TITLE, "عندك رسوم جديدة لـ Own Hub. افتحي Own Hub وشوفيها.")},
    "instapayFeeDueSoon": {"en": (TITLE, "An Own Hub fee is due tomorrow. Open Own Hub to pay it."),
                   "ar": (TITLE, "رسوم Own Hub مستحقة بكرة. افتحي Own Hub وادفعيها.")},
    "instapayFeeDueToday": {"en": (TITLE, "An Own Hub fee is due today. Open Own Hub to pay it."),
                    "ar": (TITLE, "رسوم Own Hub مستحقة النهارده. افتحي Own Hub وادفعيها.")},
    "instapayFeeOverdue": {"en": (TITLE, "Your account is on hold until an Own Hub fee is paid. Open Own Hub to pay it."),
                   "ar": (TITLE, "حسابك واقف لحد ما رسوم Own Hub تتدفع. افتحي Own Hub وادفعيها.")},
    "instapayFeeClaimRejected": {"en": (TITLE, "Please check your Own Hub fee. Open Own Hub to see it."),
                         "ar": (TITLE, "راجعي رسوم Own Hub. افتحي Own Hub وشوفيها.")},
    "instapayAccountActive": {"en": (TITLE, "Your account is active again."),
                      "ar": (TITLE, "حسابك رجع شغال تاني.")},
    "instapaySuspended": {"en": (TITLE, "Taking payments is paused on your account. Open Own Hub for details."),
                          "ar": (TITLE, "استلام الدفع موقوف على حسابك. افتحي Own Hub للتفاصيل.")},
}

KINDS = tuple(TEXT)

STATEMENT_KINDS = frozenset({"instapayStatementReady", "instapayFeeDueSoon", "instapayFeeDueToday", "instapayFeeOverdue", "instapayFeeClaimRejected"})
"""Their tap opens a fee statement, named by its month: the statement's own id
holds the coach's uid, and no uid goes in a payload."""


def data_for(kind: str, ref: Optional[str]) -> dict:
    """What a tap needs to open the right screen: the kind, plus `paymentId`
    (an auto id) or, for a fee bill, `statementMonth` ("2026-10") or, for one
    made for a payment, `billId` (that payment's auto id). No name, no amount."""
    data = {"kind": kind}
    if ref:
        if kind not in STATEMENT_KINDS:
            data["paymentId"] = ref
        else:
            data["statementMonth" if re.fullmatch(r"\d{4}-\d{2}", ref) else "billId"] = ref
    return data


def text_for(kind: str, locale: Optional[str]) -> tuple[str, str]:
    by_locale = TEXT[kind]
    return by_locale.get(locale or "", by_locale["ar"])


def send_kind(uid: str, kind: str, *, db, messaging, locale: Optional[str] = None, ref: Optional[str] = None) -> int:
    """Same delivery as coaching/push.send_kind; an unknown kind sends nothing.
    `ref` is the payment id, or the statement month for the two fee kinds."""
    if kind not in TEXT:
        return 0
    return identity_push.send_to_user(
        uid, "", "", data_for(kind, ref), db, messaging,
        texts=lambda phone_locale: text_for(kind, phone_locale),
        fallback_locale=locale if locale in ("en", "ar") else "ar",
        topic=identity_push.TOPIC_PAYMENTS,
    )
