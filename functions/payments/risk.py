"""The outcome of a proof, and a score that only orders staff work (spec 13.3, 13.4, 13.12)."""

from __future__ import annotations

from dataclasses import dataclass, field

from identity import imagesize

GREEN, AMBER, RED = "green", "amber", "red"

WEIGHTS = {
    "editorTag": 30,        # the file names a photo editor
    "cameraExif": 20,       # a camera photo, not a screenshot
    "oddSize": 15,          # not a phone-screen shape
    "tooSmall": 10,
    "clockMismatch": 15,    # the status-bar clock disagrees with the claimed time (WO-10l)
    "doubleCompression": 20,  # reserved: JPEG double compression (UNVERIFIED: no library installed)
    "sameImageOther": 40,
    "nearImageOther": 30,
    "txnReused": 40,
}
_EDITORS = (b"Photoshop", b"Adobe", b"GIMP", b"Canva", b"Snapseed", b"PicsArt", b"Pixelmator", b"Lightroom")


def tamper_flags(raw: bytes) -> list[str]:
    """Cheap signals from the bytes of a screenshot BEFORE it is re-encoded.
    They never reject a picture; they raise the score."""
    flags: list[str] = []
    head = raw[:65536]
    if any(tag in head for tag in _EDITORS):
        flags.append("editorTag")
    if b"Exif\x00\x00" in head and (b"Make" in head or b"Model" in head):
        flags.append("cameraExif")
    size = imagesize.dimensions(raw)
    if size is not None:
        width, height = size
        long_side, short_side = max(width, height), max(1, min(width, height))
        if not (1.6 <= long_side / short_side <= 2.4):
            flags.append("oddSize")
        if short_side < 600:
            flags.append("tooSmall")
    return flags


def score(flags: list[str]) -> int:
    return min(100, sum(WEIGHTS.get(f, 0) for f in set(flags)))


@dataclass(frozen=True)
class Outcome:
    colour: str
    reasons: list[str] = field(default_factory=list)
    score: int = 0
    retry_offered: bool = False


def decide(checks: dict, uniq: dict, flags: list[str], *, retry_used: bool, other_payer_ok: bool = False) -> Outcome:
    """GREEN: amount, success status and recipient all found, and a transaction
    number or a time inside the window, on something that looks like a transfer
    receipt. RED: a deterministic contradiction or a reuse. Everything else is
    AMBER. A card or balance message is AMBER with reason wrongMessage and never
    uses up the retry. Tamper flags change the score only."""
    all_flags = list(flags)
    if uniq.get("sameImageOf"):
        all_flags.append("sameImageOther")
    if uniq.get("nearImageOf"):
        all_flags.append("nearImageOther")
    if uniq.get("txnReusedBy"):
        all_flags.append("txnReused")
    points = score(all_flags)

    if checks.get("wrongMessage"):
        # A card or balance message is not a transfer receipt, so nothing it says
        # (a different amount, an old date) can be a contradiction. Never RED.
        return Outcome(AMBER, ["wrongMessage"], points, True)  # always another try, never counted

    red = []
    if checks.get("amount") == "different":
        red.append("amountDiffers")
    if checks.get("status") == "failed":
        red.append("transferFailed")
    if checks.get("recipient") == "mismatch":
        red.append("recipientDiffers")
    if checks.get("when") == "outside":
        red.append("timeOutsideWindow")
    if uniq.get("txnReusedBy"):
        red.append("txnReused")
    if uniq.get("sameImageOf"):
        red.append("sameImage")
    if uniq.get("nearImageOf"):
        red.append("nearImage")
    if red:
        return Outcome(RED, red, points, False)

    missing = []
    if checks.get("amount") != "match":
        missing.append("amountUnreadable")
    if checks.get("status") != "success":
        missing.append("statusUnknown")
    if checks.get("recipient") != "match":
        missing.append("recipientUnreadable")
    if not (checks.get("txn") or checks.get("when") == "in"):
        missing.append("needDetails")          # the receipt without More Details open (13.12 item 1)
    if not checks.get("transferLike"):
        missing.append("notATransferReceipt")  # an SMS alone is never GREEN (13.13)
    if checks.get("sender") == "different" and not other_payer_ok:
        missing.append("someoneElsePaid")
    if missing:
        offer = (not retry_used) and not checks.get("typedTxn")
        return Outcome(AMBER, missing, points, offer)
    return Outcome(GREEN, [], points, False)
