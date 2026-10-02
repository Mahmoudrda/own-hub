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

from identity import decisions, providers, reasons

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
    """Exactly one key may be read out of the client's `liveness` block.

    Asserted over the syntax tree rather than by matching a literal line of
    main.py. The string form of this test pinned one spelling of the
    expression, so adding an isinstance guard around it broke the test while
    the property it protects was untouched — and, worse, the same test would
    have passed a SECOND `.get` added on the next line, because the original
    substring was still present. The property is "every key read from the
    liveness block is sessionId", and that is what is checked here.
    """
    tree = ast.parse(open(_MAIN, encoding="utf-8").read())

    # Names bound to the client's liveness block, however it is spelled:
    # `x = data.get("liveness")`, or `x = data.get("liveness") or {}`.
    aliases = {"liveness"}
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and len(node.targets) == 1:
            if isinstance(node.targets[0], ast.Name) and _reads_liveness(node.value):
                aliases.add(node.targets[0].id)

    keys = set()
    for node in ast.walk(tree):
        # `<alias>.get("...")`, and the inline `(data.get("liveness") or
        # {}).get("...")` form that has no alias at all.
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr != "get" or not node.args:
                continue
            target = node.func.value
            named = isinstance(target, ast.Name) and target.id in aliases
            if (named or _reads_liveness(target)) and isinstance(
                node.args[0], ast.Constant
            ):
                keys.add(node.args[0].value)
        # `<alias>["..."]`
        if isinstance(node, ast.Subscript) and isinstance(node.slice, ast.Constant):
            if isinstance(node.value, ast.Name) and node.value.id in aliases:
                keys.add(node.slice.value)

    assert keys == {"sessionId"}, (
        "the session id must be the only thing read out of the client's "
        f"liveness object, but main.py also reads {sorted(keys - {'sessionId'})}"
    )


def _reads_liveness(node) -> bool:
    """Is this expression `data.get("liveness")`, with or without `or {}`?"""
    if isinstance(node, ast.BoolOp) and isinstance(node.op, ast.Or):
        return any(_reads_liveness(value) for value in node.values)
    return (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "get"
        and bool(node.args)
        and isinstance(node.args[0], ast.Constant)
        and node.args[0].value == "liveness"
    )


# ------------------- 3. the live providers and the mocks bill the same way
#
# This section exists because the suite has now been fooled twice by the same
# shape of defect: a live provider whose behaviour differed from the mock every
# test ran against, in a way no test compared.
#
#   * SelfHostedLiveness declared the cosine score scale while the thresholds
#     declared the composite one, so every real verification would have raised
#     ThresholdScaleMismatch in production while the suite stayed green.
#   * VisionOcr reported cost_micro_usd=0 for a response that carried no text,
#     while MockOcr reported the full price. Google bills for both, so the live
#     provider's answer was the wrong one — and because only the mock was ever
#     exercised, the pipeline's "debit what was billed" logic was tested against
#     a provider that never exhibited the bug.
#
# The lesson generalises: assert the LIVE object's declared contract, never the
# fake's. Hand-built inputs cannot catch a disagreement between the two.


def test_the_live_ocr_provider_charges_for_an_answer_that_carries_no_text():
    """Vision bills per image submitted, not per image it manages to read.

    Driven through a stub client rather than the network, but through the REAL
    VisionOcr.read, which is where the cost decision is made.
    """
    from identity import providers_selfhosted

    class _EmptyResponse:
        class error:
            message = ""

        class full_text_annotation:
            text = ""

    class _StubClient:
        def document_text_detection(self, image, image_context):
            return _EmptyResponse()

    result = providers_selfhosted.VisionOcr(client=_StubClient()).read(b"blank-jpeg")

    assert result.ok is False, "no text means the card is unusable"
    assert result.cost_micro_usd == providers.COST_OCR_PER_IMAGE, (
        "but Google counted a unit, so the ledger must be told about it — this "
        "is the blank-image loop that billed us for ever and charged nobody"
    )


def test_the_live_ocr_provider_charges_nothing_when_the_call_never_completed():
    """The other half of spec §9.4, which the fix above must not weaken."""
    from identity import providers_selfhosted

    class _ExplodingClient:
        def document_text_detection(self, image, image_context):
            raise RuntimeError("timeout carrying image bytes in its message")

    result = providers_selfhosted.VisionOcr(client=_ExplodingClient()).read(b"jpeg")

    assert result.ok is False
    assert result.cost_micro_usd == 0, "no unit was counted, so no charge"
    assert result.reason == reasons.INTERNAL_ERROR
    assert "timeout" not in repr(result), "nothing from the exception propagates"


def test_the_mock_and_the_live_ocr_provider_agree_on_when_a_call_is_billed():
    """The assertion that was missing both times.

    MockOcr is what every pipeline test runs against. If it bills on different
    conditions from VisionOcr, every cost assertion in the suite is about a
    provider that does not exist in production.
    """
    from identity import providers_selfhosted

    class _Response:
        def __init__(self, text):
            self.full_text_annotation = type("_", (), {"text": text})()
            self.error = type("_", (), {"message": ""})()

    class _StubClient:
        def __init__(self, text):
            self.text = text

        def document_text_detection(self, image, image_context):
            return _Response(self.text)

    for text in ("", "   ", "some recognised text"):
        live = providers_selfhosted.VisionOcr(client=_StubClient(text)).read(b"j")
        mock = providers.MockOcr(texts=[text]).read(b"j")
        assert live.ok == bool(text.strip()) and mock.ok == bool(text.strip()), (
            f"the two providers disagree on usability for {text!r}"
        )
        assert live.cost_micro_usd == mock.cost_micro_usd, (
            f"the two providers disagree on cost for {text!r}: a completed "
            f"Vision call is billed whatever it returned"
        )


def test_the_live_providers_scales_match_the_active_threshold_set():
    """The first defect of this shape, held in place.

    pipeline.run reads `score_scale` off each live provider and hands it to
    ThresholdSet.for_providers. A provider declaring a scale the active
    thresholds were not calibrated for raises on the first real request and on
    no test, because tests build Signals with matching scales by hand.
    """
    from identity import config, providers_selfhosted

    liveness = providers_selfhosted.SelfHostedLiveness()
    match = providers_selfhosted.SelfHostedFaceMatch()

    config.ACTIVE_THRESHOLDS.for_providers(liveness.score_scale, match.score_scale)


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
    for name in (
        "record_consent",
        "start_verification",
        "verify_identity",
        "request_review",
        "get_review_contact",
        "schedule_verification_review",
        "decide_verification_flag",
    ):
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
