"""What a coaching callable says when it refuses, as codes the app maps to its
own words. No sentence is composed here: the app speaks both languages."""

from __future__ import annotations

COACH_APP_CLOSED = "coach_app_closed"
"""The coach side is switched off (COACH_APP_LIVE is False)."""

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
