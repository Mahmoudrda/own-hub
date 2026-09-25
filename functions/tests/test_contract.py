"""The wire contract, and the two properties in it that are security controls.

Both of these were wrong in the Flutter worker's first draft of the contract,
and both are the kind of wrong that works perfectly in testing and hands an
attacker the product:

  1. the client sending its own liveness OUTCOME;
  2. the server returning internal reason codes to the handset.

The fixes are "ignore the field" and "map through a many-to-few table". Neither
is visible in a type signature, so neither survives a refactor without a test
holding it in place. That is what this file is.
"""

from __future__ import annotations

import ast
import os

from identity import decisions, reasons

_MAIN = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "main.py"
)


# ------------------------------- 1. the client never decides its own outcome


def test_main_never_reads_an_outcome_from_the_clients_liveness_object():
    """A patched APK sending `liveness.outcome = "pass"` must gain nothing.

    Asserted against the source rather than behaviourally, because the failure
    mode is someone ADDING a read of that field in six months. A behavioural
    test would need the field to already be wired to catch it; this catches the
    wiring itself.
    """
    source = open(_MAIN, encoding="utf-8").read()
    tree = ast.parse(source)

    for node in ast.walk(tree):
        # Any `.get("outcome")` or subscript `["outcome"]` on request data.
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr == "get" and node.args:
                first = node.args[0]
                if isinstance(first, ast.Constant) and first.value == "outcome":
                    raise AssertionError(
                        "main.py reads an 'outcome' key from request data. The "
                        "client must never be the source of truth for a "
                        "verification result (rule of engagement 3)."
                    )
        if isinstance(node, ast.Subscript) and isinstance(node.slice, ast.Constant):
            if node.slice.value == "outcome" and _is_request_data(node.value):
                raise AssertionError("main.py subscripts request data for 'outcome'")


def _is_request_data(node) -> bool:
    return isinstance(node, ast.Name) and node.id in {"data", "liveness"}


def test_only_the_session_id_is_taken_from_the_liveness_object():
    source = open(_MAIN, encoding="utf-8").read()
    assert 'data.get("liveness") or {}).get("sessionId")' in source, (
        "the session id must be the only thing read out of the client's "
        "liveness object"
    )


# ------------------------------ 2. internal reason codes never cross the wire


def test_the_user_safe_vocabulary_is_disjoint_from_the_internal_one():
    # If a code were in both, mapping through the table would be a no-op for it
    # and an internal code would reach the handset while every test still
    # passed.
    assert reasons.USER_SAFE.isdisjoint(reasons.ALL)


def test_every_internal_code_maps_to_a_user_safe_hint_or_to_nothing():
    for code in reasons.ALL:
        hints = reasons.to_user_safe([code])
        assert hints == [] or (len(hints) == 1 and hints[0] in reasons.USER_SAFE)


def test_the_mapping_is_many_to_few_so_it_cannot_be_inverted():
    mapped = {
        hint
        for code in reasons.ALL
        for hint in reasons.to_user_safe([code])
    }
    mappable = [c for c in reasons.ALL if reasons.to_user_safe([c])]
    assert len(mapped) <= 5, "at most five hints"
    assert len(mappable) > 3 * len(mapped), (
        "the mapping must be strongly many-to-one, or a hint identifies the "
        "check that failed and becomes an oracle"
    )


def test_the_sex_gate_leaks_nothing():
    # The single most valuable thing for an attacker to learn is that digit 13
    # is what stopped him, because it tells him to find a woman's card rather
    # than to improve his selfie.
    assert reasons.to_user_safe([reasons.SEX_DIGIT_MALE]) == []
    assert reasons.to_user_safe([reasons.SEX_CONFLICT]) == []


def test_no_flag_signal_leaks():
    for code in (
        reasons.NID_GOVERNORATE_UNKNOWN,
        reasons.BIRTH_DATE_MISMATCH,
        reasons.HMAC_MANY_FAILURES,
        reasons.INSTALL_MANY_IDS,
        reasons.NIQAB_PATH_REQUESTED,
        reasons.LIVENESS_FLAG_BAND,
        reasons.MATCH_FLAG_BAND,
    ):
        assert reasons.to_user_safe([code]) == [], f"{code} must not reach a client"


def test_underage_leaks_nothing():
    # There is no honest hint for "you are too young", and "retake the photo"
    # would send a 16-year-old round the loop four times.
    assert reasons.to_user_safe([reasons.UNDERAGE]) == []


def test_duplicate_hints_at_support_not_at_the_reason():
    assert reasons.to_user_safe([reasons.DUPLICATE_ID]) == [reasons.CONTACT_SUPPORT]


def test_hints_are_deduplicated_and_ordered():
    hints = reasons.to_user_safe(
        [reasons.NID_BAD_DATE, reasons.NID_UNREADABLE, reasons.MATCH_FAILED]
    )
    assert hints == [reasons.RETAKE_FRONT, reasons.RETAKE_SELFIE]


# ----------------------------------------------- the rest of the envelope


def test_every_outcome_is_a_string_the_client_can_switch_on():
    for outcome in decisions.OUTCOMES:
        assert outcome.isupper()


def test_the_response_shape_is_the_agreed_one():
    source = open(_MAIN, encoding="utf-8").read()
    tree = ast.parse(source)
    response = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "_response"
    )
    returned = next(
        node for node in ast.walk(response) if isinstance(node, ast.Return)
    )
    keys = {k.value for k in returned.value.keys}
    assert keys == {"outcome", "reasons", "refreshToken"}


def test_the_region_is_the_one_the_flutter_side_expects():
    from identity import config

    # A wrong region does not fail loudly: it degrades every check into a human
    # review, which is the worst failure mode available.
    assert config.REGION == "europe-west3"


def test_the_callables_have_the_agreed_names():
    source = open(_MAIN, encoding="utf-8").read()
    tree = ast.parse(source)
    defined = {n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}
    for name in ("record_consent", "start_verification", "verify_identity"):
        assert name in defined, f"the Flutter side calls {name}"


# --------------------------------------------- no image can reach a response


def _executable_identifiers(path: str) -> set[str]:
    """Every identifier in executable code, ignoring comments and docstrings.

    The distinction matters here: main.py's header explains at length WHY there
    is no evidence path, so a plain substring search over the file finds the
    word "evidence" in prose that exists precisely because the code does not.
    A test that cannot tell an explanation from an implementation would force
    the explanation to be deleted, which is the wrong direction.
    """
    tree = ast.parse(open(path, encoding="utf-8").read())
    names: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Name):
            names.add(node.id)
        elif isinstance(node, ast.Attribute):
            names.add(node.attr)
        elif isinstance(node, (ast.Import, ast.ImportFrom)):
            for alias in node.names:
                names.add(alias.name.split(".")[0])
                if alias.asname:
                    names.add(alias.asname)
    return names


def test_no_callable_returns_a_url_or_an_image():
    identifiers = _executable_identifiers(_MAIN)
    for banned in (
        "signed_url",
        "generate_signed_url",
        "evidence",
        "b64encode",
        "write_bundle",
        "upload_from_string",
    ):
        assert banned not in identifiers, (
            f"main.py CALLS {banned!r}. No image or image URL may leave this "
            f"service, and the evidence path was deleted rather than disabled."
        )


def test_no_module_in_the_package_writes_to_cloud_storage():
    # The strong form of the promise in main.py's header, checked across every
    # module rather than trusted to one file.
    import glob

    package = os.path.join(os.path.dirname(_MAIN), "identity")
    for module in glob.glob(os.path.join(package, "*.py")):
        identifiers = _executable_identifiers(module)
        for banned in ("storage", "upload_from_string", "upload_from_file", "blob"):
            assert banned not in identifiers, (
                f"{os.path.basename(module)} references {banned!r}; nothing in "
                f"this package may touch Cloud Storage"
            )


def test_the_evidence_module_is_gone_not_merely_disabled():
    functions_dir = os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))
    )
    assert not os.path.exists(os.path.join(functions_dir, "identity", "evidence.py"))

    from identity import config

    assert not hasattr(config, "EVIDENCE_BUNDLE_ENABLED"), (
        "a disabled flag is a code path that gets switched on by accident; the "
        "owner asked for deletion, not a switch"
    )
    assert not hasattr(config, "EVIDENCE_BUCKET")
