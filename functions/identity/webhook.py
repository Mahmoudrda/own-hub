"""The review-queue notification: a flag id and reason codes, nothing else.

Spec §5. It goes to a third-party chat service, so anything richer would be
identity data sitting in someone else's message history.

REQUIRED IN PRODUCTION (S14, config.FLAG_WEBHOOK_REQUIRED). The URL comes from
the FLAG_WEBHOOK_URL environment variable, or from the Secret Manager secret
`flag-webhook-url`, read at runtime and cached like the pepper. If neither is
set outside the emulator, every flag logs `flag_webhook_missing` at ERROR, which
the alert policy in firebase/ops/webhook-missing-alert-policy.json pages on. A
silent queue is how a flagged woman waits 72 hours for nobody.

Never fails the verification: the flag document is the durable record and the
webhook is only a notification. A failed post logs `flag_webhook_failed` with
the flag id and no payload.
"""

from __future__ import annotations

import json
import os
import threading
import urllib.request
from typing import Optional

from . import config, logs

_url_cache: Optional[str] = None
_url_lock = threading.Lock()


def _secret_url() -> Optional[str]:
    try:
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/own-hub/secrets/{config.SECRET_FLAG_WEBHOOK}/versions/latest"
        value = client.access_secret_version(request={"name": name}).payload.data
        return value.decode("utf-8").strip() or None
    except Exception:
        return None


def url() -> Optional[str]:
    """The webhook URL, or None. A found secret is cached for the instance; a
    missing one is looked up again next time, so adding it needs no redeploy."""
    global _url_cache
    env = os.environ.get("FLAG_WEBHOOK_URL")
    if env:
        return env
    if _url_cache is None:
        with _url_lock:
            if _url_cache is None:
                _url_cache = _secret_url()
    return _url_cache


def _in_emulator() -> bool:
    return os.environ.get("FUNCTIONS_EMULATOR") == "true"


def post_flag(flag_id: str, codes) -> None:
    if _in_emulator() and not os.environ.get("FLAG_WEBHOOK_URL"):
        return
    target = url()
    if not target:
        if config.FLAG_WEBHOOK_REQUIRED:
            logs.error("flag_webhook_missing", flagId=flag_id)
        return
    try:
        body = json.dumps({"flagId": flag_id, "reasons": list(codes)}).encode()
        req = urllib.request.Request(
            target, data=body, headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req, timeout=5).close()
    except Exception:
        logs.error("flag_webhook_failed", flagId=flag_id)
