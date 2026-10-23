"""Private coaching: contracts/coaching_contract.json against the server.

The app reads the same file (app/test/contracts/coaching_contract_test.dart).
Neither side changes it alone.
"""

from __future__ import annotations

import ast
import importlib
import json
import os

import coaching
from coaching import common, errors
from tests.test_entrypoints import CALLABLES

_HERE = os.path.dirname(os.path.abspath(__file__))
_FUNCTIONS = os.path.dirname(_HERE)
_ROOT = os.path.dirname(_FUNCTIONS)
_CONTRACT = os.path.join(_ROOT, "contracts", "coaching_contract.json")
_SHIPPED = os.path.join(_FUNCTIONS, "coaching", "coaching_contract.json")
_VECTORS = os.path.join(_ROOT, "contracts", "coaching_price_vectors.json")
_MAIN = os.path.join(_FUNCTIONS, "main.py")


def contract() -> dict:
    with open(_CONTRACT, encoding="utf-8") as handle:
        return json.load(handle)


def test_the_shipped_copy_is_identical():
    # Only functions/ is deployed, so the server reads its own copy.
    with open(_CONTRACT, "rb") as a, open(_SHIPPED, "rb") as b:
        assert a.read() == b.read()


def test_the_region_is_the_project_region():
    from identity import config

    assert contract()["region"] == config.REGION


def test_every_reason_is_an_errors_constant_and_back():
    values = {
        v for k, v in vars(errors).items()
        if k.isupper() and isinstance(v, str) and v not in {
            errors.PRECONDITION, errors.PERMISSION, errors.INVALID,
            errors.NOT_FOUND, errors.EXHAUSTED,
        }
    }
    assert set(contract()["reasons"]) == values


def test_every_callable_is_in_main_and_guarded():
    tree = ast.parse(open(_MAIN, encoding="utf-8").read())
    defined = {n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}
    for name in contract()["callables"]:
        assert name in defined, f"{name} is not defined in main.py"
        assert name in CALLABLES, f"{name} is not in test_entrypoints.CALLABLES"


def test_every_callable_names_a_module_function_that_exists():
    for name, spec in contract()["callables"].items():
        module_name, _, function = spec["module"].rpartition(".")
        module = importlib.import_module(module_name)
        assert callable(getattr(module, function, None)), f"{name}: {spec['module']}"


def test_every_price_vector():
    with open(_VECTORS, encoding="utf-8") as handle:
        vectors = json.load(handle)
    limits = contract()["limits"]
    assert vectors["coachMin"] == limits["coachPriceMinEgp"]
    assert vectors["coachMax"] == limits["coachPriceMaxEgp"]
    for case in vectors["vectors"]:
        assert common.final_price(case["coach"]) == case["final"], case


def test_every_push_kind_has_words_in_both_languages():
    from coaching import push

    for kind in contract()["enums"]["pushKinds"]:
        assert set(push.TEXT[kind]) == {"en", "ar"}, kind


def test_the_coach_side_ships_with_payments_off():
    # Move with the three switch functions in both rules files.
    assert coaching.COACH_PORTFOLIO_LIVE is True
    assert coaching.COACH_CLIENTS_LIVE is True
    assert coaching.COACH_PAYMENTS_LIVE is False
