"""C3: a global ceiling of GLOBAL_DAILY_LIMIT new waitlist entries a day.

Past it every valid submission is told "try again later" (the later page),
and nothing is written. The honest option: the form never says "joined" for
something it did not keep, and nothing is queued or slowed in secret.

Past the ceiling a contact already on the list ALSO gets "later", not
"joined", so the endpoint still cannot be used to learn who is on the list.
"""

from __future__ import annotations

import datetime as dt
import os

from tests import fake_firestore
from tests.test_waitlist import KEY, NOW, FakeStore, req
from waitlist import join

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _handle(store, fields, ip):
    return join.handle(req(fields, ip=ip), store, lambda: KEY, NOW)


def _fill(store, n):
    for i in range(n):
        store.entries.append({"contact": f"+2010{i:08d}", "at": NOW})


def test_the_ceiling_is_five_thousand_a_day():
    assert join.GLOBAL_DAILY_LIMIT == 5000


def test_under_the_ceiling_a_new_contact_joins():
    store = FakeStore()
    _fill(store, join.GLOBAL_DAILY_LIMIT - 1)
    response = _handle(store, {"contact": "01112223334"}, "41.33.1.1")
    assert response.status == 200
    assert len(store.entries) == join.GLOBAL_DAILY_LIMIT


def test_past_the_ceiling_nothing_is_written_and_she_is_told_later():
    store = FakeStore()
    _fill(store, join.GLOBAL_DAILY_LIMIT)
    response = _handle(store, {"contact": "01112223334"}, "41.33.1.1")
    assert response.status == 429
    assert len(store.entries) == join.GLOBAL_DAILY_LIMIT
    form = join.handle(req({"contact": "01112223334"}, form=True, ip="41.33.1.2"), store, lambda: KEY, NOW)
    assert form.headers["Location"].endswith("/waitlist/later")


def test_past_the_ceiling_a_duplicate_answers_the_same_as_a_new_contact():
    store = FakeStore()
    _fill(store, join.GLOBAL_DAILY_LIMIT)
    known = store.entries[0]["contact"]
    a = _handle(store, {"contact": "01112223334"}, "41.33.1.1")
    b = _handle(store, {"contact": "0" + known[3:]}, "41.33.1.3")
    assert (a.status, a.body) == (b.status, b.body)


def test_yesterdays_entries_do_not_count_today():
    store = FakeStore()
    for i in range(join.GLOBAL_DAILY_LIMIT):
        store.entries.append({"contact": f"+2010{i:08d}", "at": NOW - dt.timedelta(days=1)})
    assert _handle(store, {"contact": "01112223334"}, "41.33.1.1").status == 200


def test_the_firestore_store_counts_new_entries_per_day():
    db = fake_firestore.FakeFirestore()
    store = join.FirestoreWaitlist(db)
    day = NOW.date().isoformat()
    assert store.new_entries_today(day) == 0
    store.add({"contact": "+201012345678", "at": NOW, "expireAt": NOW})
    store.add({"contact": "+201012345679", "at": NOW, "expireAt": NOW})
    assert store.new_entries_today(day) == 2
    # The counter lives beside the per-IP ones, under their TTL.
    counter = db.docs[f"{join.RATE_COLLECTION}/{join.GLOBAL_COUNTER_PREFIX}{day}"]
    assert counter["count"] == 2 and "expireAt" in counter


def test_the_later_page_says_the_list_may_be_full_for_today():
    en = open(os.path.join(_ROOT, "site", "waitlist", "later", "index.html"), encoding="utf-8").read()
    ar = open(os.path.join(_ROOT, "site", "ar", "waitlist", "later", "index.html"), encoding="utf-8").read()
    assert "full for today" in en
    assert "اكتملت" in ar
