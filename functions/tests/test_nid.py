"""Spec §9.1: the ID parser, minimum 40 cases.

Every number in this file is SYNTHETIC (rule of engagement 7). They are
constructed digit by digit from the documented format so that each one exercises
exactly the field under test, and no real person's ID number appears anywhere.

`TODAY` is fixed. A parser test that reads the wall clock starts failing on
somebody's birthday, and the MIN_AGE boundary cases below are meaningless
without a frozen date.
"""

from __future__ import annotations

import datetime as dt

import pytest

from identity import nid

TODAY = dt.date(2026, 9, 25)


def synth(
    century: str = "2",
    yy: str = "95",
    mm: str = "07",
    dd: str = "14",
    gov: str = "21",
    seq: str = "0134",
    check: str = "5",
) -> str:
    """Build a synthetic 14-digit number field by field.

    seq's last digit is digit 13, which carries sex. "0134" ends in 4, even,
    so the default synthetic person is female — which is what most of these
    tests want.
    """
    number = f"{century}{yy}{mm}{dd}{gov}{seq}{check}"
    assert len(number) == 14, number
    return number


def to_arabic_indic(number: str) -> str:
    return "".join(chr(0x0660 + int(d)) for d in number)


def to_persian(number: str) -> str:
    return "".join(chr(0x06F0 + int(d)) for d in number)


# --------------------------------------------------------------- valid reads


def test_valid_female_number_parses():
    result = nid.parse(synth(), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.sex_from_digit == "female"
    assert result.birth_date == dt.date(1995, 7, 14)
    assert result.governorate_code == "21"
    assert result.governorate_name == "Giza"


def test_valid_male_number_parses_and_is_reported_as_male():
    result = nid.parse(synth(seq="0133"), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.sex_from_digit == "male", "digit 13 odd is male"


def test_century_three_is_the_two_thousands():
    result = nid.parse(synth(century="3", yy="05"), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.birth_date.year == 2005


def test_check_digit_is_carried_and_never_judged():
    # Rule of engagement 5: the 14th digit's algorithm is not public and must
    # not be validated. Two numbers differing ONLY in digit 14 must both parse.
    for check in "0123456789":
        result = nid.parse(synth(check=check), today=TODAY)
        assert isinstance(result, nid.ParsedNid), f"check digit {check} rejected"
        assert result.check_digit == int(check)


def test_parser_module_contains_no_checksum_implementation():
    # A regression guard with teeth: the earlier draft of this module shipped a
    # weighted mod-11 scheme. Rule 5 says any such code must be removed, and a
    # test that only checks behaviour would pass against a dormant helper that
    # someone later re-wires.
    import inspect

    source = inspect.getsource(nid)
    for banned in ("mod 11", "% 11", "checksum_digit", "_CHECKSUM_WEIGHTS"):
        assert banned not in source, f"checksum implementation found: {banned}"


# --------------------------------------------------------------- digit forms


def test_eastern_arabic_indic_digits_normalise():
    result = nid.parse(to_arabic_indic(synth()), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.number == synth()


def test_persian_digits_normalise():
    result = nid.parse(to_persian(synth()), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.number == synth()


def test_mixed_latin_and_arabic_indic_digits_normalise():
    number = synth()
    mixed = to_arabic_indic(number[:7]) + number[7:]
    result = nid.parse(mixed, today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.number == number


def test_normalise_digits_leaves_non_digits_alone():
    assert nid.normalise_digits("النوع ٢٨") == "النوع 28"


# ------------------------------------------------------------------- length


def test_thirteen_digits_is_bad_length():
    result = nid.parse(synth()[:13], today=TODAY)
    assert isinstance(result, nid.NidFailure)
    assert result.code == nid.BAD_LENGTH


def test_fifteen_digits_is_bad_length():
    result = nid.parse(synth() + "7", today=TODAY)
    assert isinstance(result, nid.NidFailure)
    assert result.code == nid.BAD_LENGTH


def test_empty_string_is_bad_length():
    assert nid.parse("", today=TODAY).code == nid.BAD_LENGTH


def test_fourteen_non_digits_is_bad_length():
    assert nid.parse("abcdefghijklmn", today=TODAY).code == nid.BAD_LENGTH


# ------------------------------------------------------------------ century


def test_century_one_is_rejected():
    result = nid.parse(synth(century="1"), today=TODAY)
    assert isinstance(result, nid.NidFailure)
    assert result.code == nid.BAD_CENTURY


def test_century_four_is_rejected():
    result = nid.parse(synth(century="4"), today=TODAY)
    assert isinstance(result, nid.NidFailure)
    assert result.code == nid.BAD_CENTURY


def test_century_zero_is_rejected():
    assert nid.parse(synth(century="0"), today=TODAY).code == nid.BAD_CENTURY


# --------------------------------------------------------------------- date


def test_month_zero_is_bad_date():
    result = nid.parse(synth(mm="00"), today=TODAY)
    assert isinstance(result, nid.NidFailure)
    assert result.code == nid.BAD_DATE


def test_month_thirteen_is_bad_date():
    assert nid.parse(synth(mm="13"), today=TODAY).code == nid.BAD_DATE


def test_day_zero_is_bad_date():
    assert nid.parse(synth(dd="00"), today=TODAY).code == nid.BAD_DATE


def test_day_thirty_two_is_bad_date():
    assert nid.parse(synth(dd="32"), today=TODAY).code == nid.BAD_DATE


def test_thirty_first_of_april_is_bad_date():
    # The case a hand-rolled "month <= 12 and day <= 31" check always accepts.
    assert nid.parse(synth(mm="04", dd="31"), today=TODAY).code == nid.BAD_DATE


def test_twenty_ninth_of_february_in_a_leap_year_is_valid():
    result = nid.parse(synth(yy="96", mm="02", dd="29"), today=TODAY)
    assert isinstance(result, nid.ParsedNid), "1996 was a leap year"
    assert result.birth_date == dt.date(1996, 2, 29)


def test_twenty_ninth_of_february_in_a_common_year_is_bad_date():
    assert nid.parse(synth(yy="95", mm="02", dd="29"), today=TODAY).code == nid.BAD_DATE


def test_year_two_thousand_is_a_leap_year():
    # 2000 is divisible by 400, so it IS a leap year. The century rule that
    # catches people out.
    result = nid.parse(synth(century="3", yy="00", mm="02", dd="29"), today=TODAY)
    assert isinstance(result, nid.ParsedNid)


def test_year_nineteen_hundred_was_not_a_leap_year():
    # 1900 is divisible by 100 but not 400. Python's date() knows; a hand-rolled
    # "yy % 4 == 0" check does not.
    assert (
        nid.parse(synth(century="2", yy="00", mm="02", dd="29"), today=TODAY).code
        == nid.BAD_DATE
    )


def test_a_future_birth_date_is_rejected():
    result = nid.parse(synth(century="3", yy="30", mm="01", dd="01"), today=TODAY)
    assert isinstance(result, nid.NidFailure)
    assert result.code == nid.FUTURE_DATE


def test_a_birth_date_of_today_is_not_in_the_future():
    result = nid.parse(synth(century="3", yy="26", mm="09", dd="25"), today=TODAY)
    assert isinstance(result, nid.ParsedNid), "born today is not born tomorrow"


def test_a_birth_date_of_tomorrow_is_in_the_future():
    assert (
        nid.parse(synth(century="3", yy="26", mm="09", dd="26"), today=TODAY).code
        == nid.FUTURE_DATE
    )


# ----------------------------------------------------------------- governorate


def test_governorate_eighty_eight_is_born_abroad_and_valid():
    # Egyptian women born in the Gulf carry 88 and there are a great many of
    # them. Omitting it would reject a large legitimate group invisibly.
    result = nid.parse(synth(gov="88"), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.governorate_name == "Born abroad"
    assert result.governorate_unknown is False


def test_governorate_twenty_is_unknown_but_still_parses():
    # Spec §1 item 2: an unknown code is a FLAG, not a rejection. 20 sits inside
    # the numeric range and was never issued, which is exactly what a naive
    # range check would wave through.
    result = nid.parse(synth(gov="20"), today=TODAY)
    assert isinstance(result, nid.ParsedNid), "unknown governorate must not reject"
    assert result.governorate_unknown is True
    assert result.governorate_name is None


def test_governorate_ninety_nine_is_unknown_but_still_parses():
    result = nid.parse(synth(gov="99"), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.governorate_unknown is True


def test_governorate_codes_are_not_contiguous():
    # Guards the table itself. If someone "tidies" it into a range, these gaps
    # disappear and codes that were never issued start being accepted as known.
    for absent in ("05", "06", "07", "08", "09", "10", "20", "30", "36"):
        assert absent not in nid.GOVERNORATES, f"{absent} was never issued"
    assert len(nid.GOVERNORATES) == 28, "27 governorates plus 88"


def test_luxor_and_qena_both_exist():
    # Luxor became a governorate in 2009; a woman born there before then carries
    # 27. Both codes are correct and there is no date-vs-code rule to enforce.
    assert nid.GOVERNORATES["29"] == "Luxor"
    assert nid.GOVERNORATES["27"] == "Qena"


# ---------------------------------------------------------------- MIN_AGE


def age_case(birth: dt.date, seq: str = "0134") -> str:
    century = "2" if birth.year < 2000 else "3"
    return synth(
        century=century,
        yy=f"{birth.year % 100:02d}",
        mm=f"{birth.month:02d}",
        dd=f"{birth.day:02d}",
        seq=seq,
    )


def test_age_on_exact_eighteenth_birthday_is_eighteen():
    born = dt.date(TODAY.year - 18, TODAY.month, TODAY.day)
    result = nid.parse(age_case(born), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.age_on(TODAY) == 18, "her birthday is today; she is 18 today"


def test_age_the_day_before_the_eighteenth_birthday_is_seventeen():
    born = dt.date(TODAY.year - 18, TODAY.month, TODAY.day) + dt.timedelta(days=1)
    result = nid.parse(age_case(born), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.age_on(TODAY) == 17, "one day short of 18"


def test_age_the_day_after_the_eighteenth_birthday_is_eighteen():
    born = dt.date(TODAY.year - 18, TODAY.month, TODAY.day) - dt.timedelta(days=1)
    result = nid.parse(age_case(born), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.age_on(TODAY) == 18


def test_age_is_computed_from_the_passed_date_not_the_wall_clock():
    result = nid.parse(synth(), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.age_on(dt.date(2030, 1, 1)) == 34
    assert result.age_on(dt.date(2020, 1, 1)) == 24


# ---------------------------------------------------- extraction from OCR text


def test_spaces_inside_the_number_are_stripped():
    number = synth()
    blob = f"{number[:7]} {number[7:]}"
    parsed, failure = nid.first_valid(blob, today=TODAY)
    assert failure is None
    assert parsed.number == number


def test_line_breaks_inside_the_number_are_stripped():
    number = synth()
    parsed, failure = nid.first_valid(f"{number[:4]}\n{number[4:]}", today=TODAY)
    assert failure is None and parsed.number == number


def test_bidi_control_characters_inside_the_number_are_stripped():
    # The invisible ones Vision emits around right-to-left text. A regex written
    # by someone testing only in English never sees these.
    number = synth()
    blob = f"‫{number[:6]}‏{number[6:]}‬"
    parsed, failure = nid.first_valid(blob, today=TODAY)
    assert failure is None and parsed.number == number


def test_dashes_inside_the_number_are_stripped():
    number = synth()
    parsed, _ = nid.first_valid(f"{number[:3]}-{number[3:9]}-{number[9:]}", today=TODAY)
    assert parsed is not None and parsed.number == number


def test_arabic_indic_number_embedded_in_arabic_text():
    number = synth()
    blob = f"جمهورية مصر العربية الرقم القومي {to_arabic_indic(number)} القاهرة"
    parsed, failure = nid.first_valid(blob, today=TODAY)
    assert failure is None
    assert parsed.number == number


def test_two_fourteen_digit_sequences_prefers_the_valid_one():
    # A card photograph legitimately contains other long digit runs. The card
    # serial here starts with 9, which no real ID can, so the ordering in
    # candidate_numbers must try the real number first.
    real = synth()
    serial = "91234567890123"
    parsed, failure = nid.first_valid(f"{serial}\n{real}", today=TODAY)
    assert failure is None
    assert parsed.number == real


def test_two_valid_looking_sequences_returns_the_first_that_parses():
    good = synth()
    bad_century = synth(century="1")
    parsed, failure = nid.first_valid(f"{bad_century} {good}", today=TODAY)
    assert failure is None
    assert parsed.number == good


def test_overlapping_windows_are_considered():
    # A single spurious OCR digit in front of the real number. A non-overlapping
    # scan locks onto the wrong 14-digit window and never sees the right one.
    number = synth()
    parsed, failure = nid.first_valid("7" + number, today=TODAY)
    assert failure is None, "the real number is the second window, not the first"
    assert parsed.number == number


def test_no_digits_at_all_is_unreadable():
    parsed, failure = nid.first_valid("النوع أنثى", today=TODAY)
    assert parsed is None
    assert failure == nid.UNREADABLE


def test_short_digit_run_is_unreadable():
    parsed, failure = nid.first_valid("1234567", today=TODAY)
    assert parsed is None and failure == nid.UNREADABLE


def test_failure_code_comes_from_the_most_plausible_candidate():
    # Both candidates fail. The one starting with 2 is the plausible ID and its
    # failure (a bad date) is more actionable for support than "unreadable".
    parsed, failure = nid.first_valid(
        f"91234567890123 {synth(mm='13')}", today=TODAY
    )
    assert parsed is None
    assert failure == nid.BAD_DATE


def test_candidate_numbers_deduplicates():
    number = synth()
    assert nid.candidate_numbers(f"{number} {number}").count(number) == 1


def test_parsed_nid_has_no_serialisation_helpers():
    # The most dangerous thing anyone could do with this object is write it
    # somewhere. Nothing should make that easy.
    result = nid.parse(synth(), today=TODAY)
    for attr in ("to_dict", "to_json", "asdict", "json"):
        assert not hasattr(result, attr), f"ParsedNid must not expose {attr}"


@pytest.mark.parametrize("gov", sorted(nid.GOVERNORATES))
def test_every_published_governorate_code_parses(gov):
    result = nid.parse(synth(gov=gov), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.governorate_unknown is False


@pytest.mark.parametrize(
    "seq,expected",
    [
        ("0001", "male"),
        ("0002", "female"),
        ("0010", "female"),
        ("0019", "male"),
        ("9998", "female"),
        ("9997", "male"),
    ],
)
def test_digit_thirteen_parity_decides_sex(seq, expected):
    result = nid.parse(synth(seq=seq), today=TODAY)
    assert isinstance(result, nid.ParsedNid)
    assert result.sex_from_digit == expected
