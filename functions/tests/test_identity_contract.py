"""The shared client/server contract, read from contracts/identity_contract.json.

The Flutter side reads the same file (app/test/contracts/). Neither side may
edit it alone: a change is a joint change with a new hash.
"""

from __future__ import annotations

import ast
import json
import os

from identity import config, reasons

_HERE = os.path.dirname(os.path.abspath(__file__))
_FUNCTIONS = os.path.dirname(_HERE)
_CONTRACT = os.path.join(
    os.path.dirname(_FUNCTIONS), "contracts", "identity_contract.json"
)
_MAIN = os.path.join(_FUNCTIONS, "main.py")


def contract() -> dict:
    with open(_CONTRACT, encoding="utf-8") as handle:
        return json.load(handle)


def _defined_functions() -> set[str]:
    tree = ast.parse(open(_MAIN, encoding="utf-8").read())
    return {n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}


def test_region_matches():
    assert contract()["region"] == config.REGION


def test_record_consent_request_is_the_server_version():
    request = contract()["callables"]["record_consent"]["request"]
    assert request == {"consentVersion": config.CONSENT_VERSION}
    assert isinstance(request["consentVersion"], int)


def test_record_consent_response_is_what_main_returns():
    response = contract()["callables"]["record_consent"]["response"]
    assert response == {"ok": True, "consentVersion": config.CONSENT_VERSION}


def test_the_verification_consent_document_is_the_one_the_store_writes(monkeypatch):
    from identity import store

    written = {}

    class _Doc:
        def __init__(self, path):
            self.path = path

        def collection(self, name):
            return _Col(f"{self.path}/{name}")

        def set(self, payload, merge=False):
            written["path"] = self.path
            written["fields"] = set(payload)

    class _Col:
        def __init__(self, path):
            self.path = path

        def document(self, doc_id):
            return _Doc(f"{self.path}/{doc_id}")

    class _Db:
        def collection(self, name):
            return _Col(name)

    monkeypatch.setattr(store, "db", lambda: _Db())
    store.write_consent("{uid}")

    doc = contract()["documents"]["verificationConsent"]
    assert written["path"] == doc["path"]
    assert written["fields"] == set(doc["fields"])


# Widened as each callable lands; at the end it is every key in the contract.
_LANDED = {"record_consent", "start_verification", "verify_identity", "request_review"}


def test_every_contract_callable_exists_in_main():
    names = set(contract()["callables"]) & _LANDED
    missing = names - _defined_functions()
    assert not missing, f"main.py does not define {sorted(missing)}"


def test_every_error_reason_is_a_reasons_constant():
    values = {
        value
        for name, value in vars(reasons).items()
        if name.isupper() and isinstance(value, str)
    }
    for key, value in contract()["errorReasons"].items():
        assert value in values, f"{key}={value!r} is not in reasons.py"


def test_review_paths_match():
    paths = contract()["callables"]["request_review"]["paths"]
    assert set(config.REVIEW_REQUEST_PATHS) == set(paths)


def test_verification_states_match():
    from identity import review, store

    doc = contract()["documents"]["verificationState"]
    assert store.VERIFICATION_STATES == set(doc["states"])
    assert review.VERIFICATION_STATES == set(doc["states"])
    assert doc["path"] == "users/{uid}" and doc["map"] == "verification"


def test_verification_state_fields_are_within_the_contract(monkeypatch):
    from identity import store

    written = {}

    class _Doc:
        def set(self, payload, merge=False):
            written.update(payload["verification"])

    class _Col:
        def document(self, _):
            return _Doc()

    class _Db:
        def collection(self, _):
            return _Col()

    monkeypatch.setattr(store, "db", lambda: _Db())
    store.set_verification_state(
        "u", "approved", route="video", scheduled_for="t", decided=True
    )
    allowed = set(contract()["documents"]["verificationState"]["fields"])
    assert set(written) <= allowed, set(written) - allowed
