"""What a coaching callable says when it refuses, as codes the app maps to its
own words. No sentence is composed here: the app speaks both languages."""

from __future__ import annotations

COACH_APP_CLOSED = "coach_app_closed"
"""The coach side is switched off (the switch for its group is False)."""

NOT_VERIFIED = "not_verified"
"""She has not passed the women-only check yet."""

NOT_A_COACH = "not_a_coach"
"""Inviting clients needs the server-minted coach claim."""

BAD_REQUEST = "bad_request"
"""A field of the wrong shape. Nothing was written."""

CERTIFICATE_NOT_UPLOADED = "certificate_not_uploaded"
"""The photo she named is not in the bucket under her own prefix."""

TOO_MANY_CERTIFICATES = "too_many_certificates"

INVITE_INVALID = "invite_invalid"
"""No such code, or it cannot be used by her. Deliberately one reason for
every case, so a block or a closed coach page is never signalled."""

INVITE_EXPIRED = "invite_expired"

INVITE_OWN = "invite_own"
"""A coach cannot invite herself."""

ALREADY_A_COACH = "already_a_coach"

APPLICATION_OPEN = "application_open"
"""Her application is already with a reviewer."""

APPLICATION_INCOMPLETE = "application_incomplete"
"""A required section is empty or out of bounds. Nothing was written."""

FILE_NOT_UPLOADED = "file_not_uploaded"
"""A file she named is not in the bucket under her own prefix."""

APPLICATION_NOT_FOUND = "application_not_found"

COACH_SUSPENDED = "coach_suspended"

COACH_UNAVAILABLE = "coach_unavailable"
"""One reason for not published, not accepting, full, or a block either way,
so a block is never signalled."""

PACKAGE_NOT_FOUND = "package_not_found"

TOO_MANY_PACKAGES = "too_many_packages"

PRICE_OUT_OF_RANGE = "price_out_of_range"

ALREADY_REQUESTED = "already_requested"
"""She already has an open subscription with this coach."""

REQUEST_NOT_FOUND = "request_not_found"

WRONG_STATUS = "wrong_status"
"""Not in a status that allows this call. Refresh and try again."""

PAST_PAY_BY = "past_pay_by"

REFERENCE_USED = "reference_used"
"""That transfer reference is already attached to another payment."""

PROOF_NOT_FOUND = "proof_not_found"

ATTEMPTS_EXHAUSTED = "attempts_exhausted"

IMAGE_INVALID = "image_invalid"

CANCEL_WINDOW_CLOSED = "cancel_window_closed"

PAYOUT_ACCOUNT_PENDING = "payout_account_pending"

NOTHING_OWED = "nothing_owed"

ACCOUNTS_NOT_SET = "accounts_not_set"

SELLER_NOT_SET = "seller_not_set"

PLAN_INVALID = "plan_invalid"

PLAN_TOO_LARGE = "plan_too_large"

SESSION_LINK_INVALID = "session_link_invalid"

SESSION_NOT_FOUND = "session_not_found"

SESSION_NOT_STARTED = "session_not_started"

REPORT_NOT_FOUND = "report_not_found"

STAFF_IS_SUBJECT = "staff_is_subject"
"""Staff cannot decide a case about themselves: their own application,
payment, refund, payout or report."""

# Each refusal and the HttpsError code it travels under.
PRECONDITION = "failed_precondition"
PERMISSION = "permission_denied"
INVALID = "invalid_argument"
NOT_FOUND = "not_found"
EXHAUSTED = "resource_exhausted"


class CoachingError(Exception):
    """A refusal with a code (an HttpsError code name) and a reason above."""

    def __init__(self, code: str, reason: str):
        super().__init__(reason)
        self.code = code
        self.reason = reason

MEDIA_NOT_FOUND = "media_not_found"
"""A portfolio photo item that does not exist (or is not hers)."""

TOO_MANY_MEDIA = "too_many_media"
"""She already has the most portfolio items the page holds."""
