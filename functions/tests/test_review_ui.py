import pytest

from tools import review_queue as rq
from tools import review_ui as ui


class FakeClient:
    def __init__(self, rows):
        self.rows, self.calls = rows, []

    def call(self, name, data):
        self.calls.append((name, data))
        if name == "list_verification_flags":
            return {"flags": self.rows}
        if name == "get_review_contact":
            return {"phone": "+201000000001"}
        return {"outcome": "approved"}


@pytest.fixture(autouse=True)
def _reset():
    yield
    ui._state["client"] = None


def test_needs_sign_in_first():
    with pytest.raises(rq.CallError):
        ui.handle("/api/list", {})


def test_phone_hidden_until_she_asked_for_the_call():
    ui._state["client"] = FakeClient([{"flagId": "f1", "consentGiven": False}])
    with pytest.raises(rq.CallError) as error:
        ui.handle("/api/contact", {"flagId": "f1"})
    assert error.value.reason == rq.REVIEW_CONSENT_MISSING


def test_booking_uses_cairo_offset():
    client = FakeClient([])
    ui._state["client"] = client
    ui.handle("/api/schedule", {"flagId": "f1", "route": "video", "at": "2026-12-20T18:00"})
    assert client.calls[-1][1]["scheduledFor"] == "2026-12-20T18:00:00+02:00"


def test_only_a_real_boolean_approves():
    client = FakeClient([])
    ui._state["client"] = client
    ui.handle("/api/decide", {"flagId": "f1", "approve": "true", "nid": "1" * 14})
    assert client.calls[-1][1] == {"flagId": "f1", "approve": False}
