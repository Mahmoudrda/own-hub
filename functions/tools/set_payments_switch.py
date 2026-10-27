"""OWNER'S TOOL ONLY: turn new InstaPay payments on or off.

    cd functions
    gcloud auth application-default login      # as the owner
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch on
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch off
    GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch status

Off: no new payment can start and coaching requests start free as before. Open
payments keep working. Safe to run twice. A missing document means OFF.
"""

from __future__ import annotations

import datetime as dt
import sys


def main(argv=None, *, db=None, now=None, out=print) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 1 or args[0] not in ("on", "off", "status"):
        out("usage: set_payments_switch on|off|status")
        return 2
    if db is None:
        from google.cloud import firestore

        db = firestore.Client(project="own-hub")
    ref = db.collection("config").document("payments")
    if args[0] == "status":
        snap = ref.get()
        out(f"enabled: {bool(snap.exists and (snap.to_dict() or {}).get('enabled') is True)}")
        return 0
    enabled = args[0] == "on"
    ref.set({"enabled": enabled, "updatedAt": now or dt.datetime.now(dt.timezone.utc), "updatedBy": "owner-tool"})
    out(f"enabled: {enabled}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
