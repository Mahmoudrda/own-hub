"""Pushes for payments. A lock screen is read by whoever holds the phone, so no
text names a person or carries an amount (spec section 8, default)."""

from __future__ import annotations

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
    "instapayStatementReady": {"en": (TITLE, "Your fee statement for last month is ready."),
                       "ar": (TITLE, "كشف الرسوم عن الشهر اللي فات جاهز.")},
    "instapayFeeOverdue": {"en": (TITLE, "Your Own Hub fee is late. Open Own Hub to see the statement."),
                   "ar": (TITLE, "رسوم Own Hub متأخرة. افتحي Own Hub وشوفي الكشف.")},
    "instapaySuspended": {"en": (TITLE, "Taking payments is paused on your account. Open Own Hub for details."),
                          "ar": (TITLE, "استلام الدفع موقوف على حسابك. افتحي Own Hub للتفاصيل.")},
}

KINDS = tuple(TEXT)


def text_for(kind: str, locale: Optional[str]) -> tuple[str, str]:
    by_locale = TEXT[kind]
    return by_locale.get(locale or "", by_locale["ar"])


def send_kind(uid: str, kind: str, *, db, messaging, locale: Optional[str] = None) -> int:
    """Same delivery as coaching/push.send_kind; an unknown kind sends nothing."""
    if kind not in TEXT:
        return 0
    return identity_push.send_to_user(
        uid, "", "", {"kind": kind}, db, messaging,
        texts=lambda phone_locale: text_for(kind, phone_locale),
        fallback_locale=locale if locale in ("en", "ar") else "ar",
    )
