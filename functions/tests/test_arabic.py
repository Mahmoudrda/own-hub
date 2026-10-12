"""Spec §9.1's last two bullets: the back gender word present, absent, or
contradictory.

Every form tested here is one OCR actually produces on a real Egyptian card.
None of these is theoretical: alef variants, a dotless final yeh and an injected
tatweel are what "أنثى" looks like after it has been through a text recogniser
in poor light.
"""

from __future__ import annotations

import pytest

from identity import arabic


@pytest.mark.parametrize(
    "text",
    [
        "النوع أنثى",
        "النوع انثى",  # bare alef, no hamza
        "النوع أنثي",  # dotted final yeh
        "النوع انثي",  # both substitutions at once
        "النوع  أنـــثى",  # tatweel injected by justification
        "النوعَأنثى",  # a hallucinated fatha
        "الجنس أنثى",  # the older label
        "النوع : أنثى\nالديانة : مسلم",
    ],
)
def test_every_real_form_of_female_reads_as_female(text):
    assert arabic.read_sex_field(text) == arabic.FEMALE


@pytest.mark.parametrize("text", ["النوع ذكر", "النوع  ذكـر", "الجنس ذكر"])
def test_male_reads_as_male(text):
    assert arabic.read_sex_field(text) == arabic.MALE


def test_an_absent_field_reads_as_unknown():
    # None is a first-class answer, not a failure to handle later. A card
    # photographed at an angle in a dark room very often yields a number and no
    # sex word, and per spec §3 that routes to a human in BOTH directions.
    assert arabic.read_sex_field("الديانة مسلم\nالحالة الاجتماعية أعزب") is None


def test_empty_text_reads_as_unknown():
    assert arabic.read_sex_field("") is None
    assert arabic.read_sex_field("   \n  ") is None


def test_both_words_present_resolves_by_proximity_to_the_label():
    # ذكر appears in Egyptian given names, so it turns up in the address and
    # parents' names. The value is the one sitting next to النوع.
    text = "محمد ذكرى عبد الله\nالنوع أنثى\nالقاهرة"
    assert arabic.read_sex_field(text) == arabic.FEMALE


def test_both_words_equidistant_from_the_label_is_unknown():
    # If we cannot tell, we have not read the field — we have read the card
    # badly, and that is a different thing from reading it as male.
    assert arabic.read_sex_field("ذكر النوع أنثى") is None


def test_both_words_with_no_label_at_all_is_unknown():
    assert arabic.read_sex_field("ذكر أنثى") is None


def test_normalise_folds_every_alef_variant_to_one():
    folded = {arabic.normalise(w) for w in ("أنثى", "انثى", "آنثى", "إنثى")}
    assert len(folded) == 1, "all four alef forms must collapse to the same string"


def test_normalise_strips_tatweel():
    assert arabic.normalise("أنـــثى") == arabic.normalise("أنثى")


def test_normalise_handles_presentation_forms():
    # Some OCR engines emit the legacy U+FE70..U+FEFF contextual-shape block.
    # NFKC has to run before the letter fold or these are missed entirely.
    presentation = "ﺃﺏﺗﻰ"  # isolated alef-hamza, noon, theh, alef maksura
    assert arabic.normalise(presentation)


def test_a_latin_gender_word_is_not_accepted():
    # The card prints Arabic. Accepting "FEMALE" would accept a forgery that did
    # not bother with the script, and would accept our own English test fixtures
    # as if they were cards.
    assert arabic.read_sex_field("SEX: FEMALE") is None
