"""tools/review_queue.py: refuses without the claim, and uses the shared code."""

from __future__ import annotations

from identity import reasons, review
from tools import review_queue
from tests.fake_review_store import FakeReviewStore

FEMALE_ADULT = "29901012345628"


def _run(argv, fake, reviewer=True, nid=None):
    lines = []
    code = review_queue.main(
        argv,
        store=fake,
        is_reviewer=lambda uid: reviewer,
        read_nid=(lambda: nid) if nid else None,
        out=lines.append,
    )
    return code, lines


def test_refuses_without_the_claim():
    fake = FakeReviewStore()
    review.request(fake, "her", "niqab")
    code, lines = _run(["--reviewer-uid", "rev", "list"], fake, reviewer=False)
    assert code == 3 and "refused" in lines[0]
    assert fake.access == []


def test_the_whole_loop_on_a_niqab_flag():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "niqab").flag_id
    assert _run(["--reviewer-uid", "rev", "list"], fake)[0] == 0
    code, lines = _run(["--reviewer-uid", "rev", "contact", "--flag", flag_id], fake)
    assert code == 0 and lines == ["+201005550132"]
    _run(
        ["--reviewer-uid", "rev", "schedule", "--flag", flag_id, "--route", "video",
         "--at", "2026-10-05T10:00:00+02:00"],
        fake,
    )
    code, lines = _run(
        ["--reviewer-uid", "rev", "decide", "--flag", flag_id, "--approve"],
        fake,
        nid=FEMALE_ADULT,
    )
    assert code == 0, lines
    assert fake.minted == ["her"]
    assert FEMALE_ADULT not in " ".join(lines)
    actions = [a for _, _, a in fake.access]
    assert actions == ["list", "contact", "schedule:video", "decide"]


def test_a_duplicate_flag_says_escalate():
    fake = FakeReviewStore()
    flag_id = review.request(fake, "her", "error").flag_id
    fake.flags[flag_id]["flags"] = [reasons.DUPLICATE_ID]
    code, lines = _run(["--reviewer-uid", "rev", "list"], fake)
    assert "escalate to the owner" in lines[0]
