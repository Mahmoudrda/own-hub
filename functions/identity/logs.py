"""Structured log lines (S14). Codes, counts and timings; never a person.

One line per decision, as a Cloud Logging jsonPayload, so log-based metrics and
alerts can match on `jsonPayload.event`. What may appear is an allowlist,
enforced here rather than trusted to every call site:

    NO uid, NO phone, NO national ID or its hash, NO image, NO name.

`jobId` / `flagId` are random document ids with no meaning outside Firestore;
they let an operator find the record without the log line itself linking a
person to an outcome.
"""

from __future__ import annotations

import re
from typing import Any

from . import reasons as _reasons

ALLOWED_KEYS = frozenset(
    {
        "event",
        "callable",
        "outcome",
        "reasons",
        "latencyMs",
        "jobId",
        "flagId",
        "state",
        "count",
        "field",
        "promptTokens",
        "outputTokens",
        "modelError",
    }
)

_DIGITS = re.compile(r"[0-9٠-٩۰-۹]{8,}")


def _clean(fields: dict) -> dict:
    extra = set(fields) - ALLOWED_KEYS
    if extra:
        raise ValueError(f"log field(s) {sorted(extra)} are not on the allowlist")
    out: dict[str, Any] = {}
    for key, value in fields.items():
        if key == "reasons":
            codes = [c for c in (value or []) if c in _reasons.ALL]
            out[key] = codes
        elif isinstance(value, str) and _DIGITS.search(value) and key not in {"jobId", "flagId"}:
            # A long digit run in a free field is how an ID number or a phone
            # number would leak. Refuse to write it rather than redact it.
            raise ValueError(f"log field {key!r} carries a long digit run")
        else:
            out[key] = value
    return out


def _logger():
    from firebase_functions import logger

    return logger


def _emit(level: str, event: str, fields: dict) -> None:
    """Never raises. A refused field is a bug in the caller, reported as a bare
    `log_field_refused` line with nothing of the refused content in it; logging
    must never be the reason a verification fails."""
    try:
        payload = _clean({"event": event, **fields})
    except ValueError:
        try:
            _logger().error("log_field_refused", event="log_field_refused")
        except Exception:
            pass
        return
    try:
        getattr(_logger(), level)(event, **payload)
    except Exception:
        pass


def decision(callable_name: str, **fields) -> None:
    """One line per decision: outcome, internal reason codes, latency."""
    _emit("info", "verification_decision", {"callable": callable_name, **fields})


def warn(event: str, **fields) -> None:
    _emit("warn", event, fields)


def error(event: str, **fields) -> None:
    _emit("error", event, fields)
    _count_error(event)


def _count_error(event: str) -> None:
    """One more under today's opsErrors/{day}, for the console's error log.

    The event code only, never the fields. Best effort and silent, like the
    log line itself: counting an error must never become a second error."""
    try:
        from console import oplog

        from . import store

        oplog.record_error(store.db(), event)
    except Exception:
        pass
