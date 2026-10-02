"""The review-queue notification: a flag id and reason codes, nothing else.

Spec §5. It goes to a third-party chat service, so anything richer would be
identity data sitting in someone else's message history. Best effort: a chat
webhook being down must never fail a verification that has already been
decided, so every failure here is swallowed. The flag document is the durable
record and the webhook is only a notification.
"""

from __future__ import annotations

import json
import os
import urllib.request


def post_flag(flag_id: str, codes) -> None:
    url = os.environ.get("FLAG_WEBHOOK_URL")
    if not url:
        return
    try:
        body = json.dumps({"flagId": flag_id, "reasons": list(codes)}).encode()
        req = urllib.request.Request(
            url, data=body, headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req, timeout=5).close()
    except Exception:
        pass
