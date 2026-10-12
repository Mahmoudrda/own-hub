"""The Egyptian national ID number: reading it, and proving it could be real.

    ┌─┬──┬──┬──┬──┬────┬─┐
    │2│85│11│03│21│4567│8│
    └┬┘└┬┘└┬┘└┬┘└┬┘└─┬──┘┬
     │  │  │  │  │   │   └─ 14    check digit — NOT validated here, see below
     │  │  │  │  │   └───── 10-13 sequence; digit 13's parity is sex
     │  │  │  │  └───────── 8-9   governorate of birth registration
     │  │  │  └──────────── 6-7   day
     │  │  └─────────────── 4-5   month
     │  └────────────────── 2-3   year within the century
     └───────────────────── 1     century: 2 = 1900s, 3 = 2000s

Counting to fourteen is not validation. A random fourteen-digit string passes a
length check and fails most of the tests in this module, and the difference
matters: this number becomes a deduplication key, so accepting a malformed one
both lets a fake card through and permanently burns a registry slot a real card
might later need.

**Digit 14 is deliberately not validated.** Egypt's Civil Status Organisation
has never published the check-digit algorithm. Open-source implementations
converge on a weighted mod-11 scheme, but "several repositories agree" is not
"verified against the issuing authority", and a scheme we guessed at would turn
real women away from a real product over arithmetic we made up. The digit is
read and carried; nothing is concluded from it. Per the acceptance spec, item 1.

**This module is pure.** No I/O, no clock of its own, no Firebase, no config
object it cannot be tested without — `today` and `min_age` are arguments, not
ambient state. That is what makes the 40-plus cases in tests/test_nid.py cheap
to write and honest to read. Do not import anything into this file that touches
a network, a disk or a global clock.

**Nothing here is stored.** The parsed number, the birth date and the
governorate live in memory for the length of one request. Only a scrypt hash of
the number survives, and only as a document id. See dedupe.py.
"""

from __future__ import annotations

import datetime as _dt
import re
from dataclasses import dataclass
from typing import Optional

# --------------------------------------------------------------- the digits

_ARABIC_INDIC = "٠١٢٣٤٥٦٧٨٩"
"""٠١٢٣٤٥٦٧٨٩ — U+0660 to U+0669.

This is what is actually printed on an Egyptian national ID card. The Latin
digits many developers assume are there are not, which is the first thing a
naive `re.findall(r"[0-9]{14}")` gets wrong.
"""

_EASTERN_ARABIC_INDIC = "۰۱۲۳۴۵۶۷۸۹"
"""۰۱۲۳۴۵۶۷۸۹ — the Persian/Urdu forms, U+06F0 to U+06F9.

Not used on Egyptian cards. Normalised anyway because ٤/۴ and ٦/۶ are visually
near-identical and OCR picks between the two codepoints unpredictably in poor
light. A woman should not be rejected over which Unicode block Google's model
happened to choose for a glyph.
"""

_DIGIT_MAP = str.maketrans(
    {
        **{ch: str(i) for i, ch in enumerate(_ARABIC_INDIC)},
        **{ch: str(i) for i, ch in enumerate(_EASTERN_ARABIC_INDIC)},
    }
)


def normalise_digits(text: str) -> str:
    """Rewrite every Arabic-Indic or Persian digit as its Latin equivalent."""
    return text.translate(_DIGIT_MAP)


_SEPARATORS = re.compile(r"[\s​-‏‪-‮⁦-⁩\-–—_.,:;·/\\|]+")
"""Whitespace, ASCII and Unicode dashes, punctuation, and the bidirectional
control characters Vision sprinkles through right-to-left text.

The number is printed on the card with visual grouping and OCR reproduces the
gaps as whatever it thinks they were. Stripping these before searching is what
turns "٢٨٥١١٠٣ ٢١٤٥٦٧٨" into a match. The bidi controls (U+200E..U+200F,
U+202A..U+202E, U+2066..U+2069) are invisible and are the ones that silently
break a regex written by someone testing only in English.
"""


def candidate_numbers(ocr_text: str) -> list[str]:
    """Every 14-digit run in the OCR output, most plausible first.

    A list rather than one answer, because a card photograph legitimately
    contains other long digit runs — the card serial, the issuing office code —
    and because OCR sometimes splits the real number across two text blocks that
    only join after separators are stripped. Handing the caller an ordered list
    to try in turn beats trusting whatever looked numeric first.

    Matches OVERLAP on purpose. A 15-digit run (one spurious OCR digit) contains
    two valid 14-digit windows and the real number may be either; a
    non-overlapping scan would see only the first and miss it half the time.

    Ordering: candidates whose first digit is 2 or 3 come first. That is the
    only shape a living person's number can have, and it is a free filter.
    """
    flat = _SEPARATORS.sub("", normalise_digits(ocr_text))
    found: list[str] = []
    seen: set[str] = set()
    for match in re.finditer(r"(?=([0-9]{14}))", flat):
        number = match.group(1)
        if number not in seen:
            seen.add(number)
            found.append(number)
    found.sort(key=lambda n: n[0] not in "23")
    return found


# --------------------------------------------------------- the governorates

GOVERNORATES: dict[str, str] = {
    "01": "Cairo",
    "02": "Alexandria",
    "03": "Port Said",
    "04": "Suez",
    "11": "Damietta",
    "12": "Dakahlia",
    "13": "Sharqia",
    "14": "Qalyubia",
    "15": "Kafr El Sheikh",
    "16": "Gharbia",
    "17": "Monufia",
    "18": "Beheira",
    "19": "Ismailia",
    "21": "Giza",
    "22": "Beni Suef",
    "23": "Faiyum",
    "24": "Minya",
    "25": "Asyut",
    "26": "Sohag",
    "27": "Qena",
    "28": "Aswan",
    "29": "Luxor",
    "31": "Red Sea",
    "32": "New Valley",
    "33": "Matrouh",
    "34": "North Sinai",
    "35": "South Sinai",
    "88": "Born abroad",
}
"""The 27 governorates plus 88, exactly as the acceptance spec lists them.

Four things about this table that are easy to get wrong:

  * The codes are NOT contiguous. There is no 05-10, no 20, no 30. A range test
    (`"01" <= code <= "35"`) would accept codes that were never issued — the
    sort of "close enough" validation a hand-crafted number walks straight
    through.

  * 88 is "born abroad" and it is common. Egyptian women born in the Gulf to
    expatriate parents carry it, and there are a great many of them. Omitting 88
    would reject a large and entirely legitimate group, invisibly, because
    nobody testing in Cairo would ever hit it.

  * 29 is Luxor, which only became a governorate in 2009. A woman born in Luxor
    before then carries 27 (Qena): the code records where the birth was
    registered under the administrative geography of the day, not where the
    place sits today. Both are correct, and there is no "code must agree with
    the date" rule to write.

  * **An unknown code is a flag, not a rejection** (acceptance spec item 2).
    This list is our best reading of a published table, and a published table
    can be out of date or wrong. If the state issues a code we have not heard
    of, the woman holding that card is not a forger — she is the first person
    to show us a gap in our data. She goes to a human.

The names are for tests and for debugging without logging her number. They are
never written to Firestore: a governorate is her place of birth and is nobody's
business once the number has been validated.
"""


# --------------------------------------------------------------- the result


@dataclass(frozen=True)
class ParsedNid:
    """A national ID number that survived every structural test.

    Held in memory for one request. Deliberately NOT serialisable: there is no
    `to_dict` and no `__str__` override, because the single most dangerous thing
    anyone could do with this object is write it somewhere or log it.
    """

    number: str
    birth_date: _dt.date
    governorate_code: str
    governorate_name: Optional[str]
    """None when the code is not in GOVERNORATES. Not an error — see
    `governorate_unknown`, which routes to a human."""
    sex_from_digit: str
    """"female" | "male", from digit 13's parity. Read off the printed NUMBER.

    Never inferred from her face. There is no code path in this project that
    could infer it from a face: product rule 8 bans face-based sex
    classification outright, and the test that enforces it greps for the very
    function names such a thing would need. A face classifier would misgender
    real women at a rate no tuning fixes, and would do it silently.
    """
    check_digit: int
    """Digit 14, carried and never judged. See the module docstring."""

    @property
    def governorate_unknown(self) -> bool:
        return self.governorate_name is None

    def age_on(self, today: _dt.date) -> int:
        """Completed years on `today`. Explicit date in, no ambient clock."""
        return (
            today.year
            - self.birth_date.year
            - ((today.month, today.day) < (self.birth_date.month, self.birth_date.day))
        )


@dataclass(frozen=True)
class NidFailure:
    """A structural rejection, carrying a reason code from reasons.py.

    A code, never a sentence: this value reaches a job document that support
    staff can read, and a free-text field is how a description of a woman ends
    up in a database.
    """

    code: str


# Reason codes are duplicated as module-level strings rather than imported, to
# keep this module dependency-free as the spec requires (item 13). reasons.py
# re-exports the same literals and tests/test_reasons_sync.py asserts the two
# lists cannot drift apart.
BAD_LENGTH = "nid_bad_length"
BAD_CENTURY = "nid_bad_century"
BAD_DATE = "nid_bad_date"
FUTURE_DATE = "nid_future_date"
UNREADABLE = "nid_unreadable"


def parse(number: str, *, today: _dt.date) -> "ParsedNid | NidFailure":
    """Validate the structure of one 14-digit candidate.

    `today` is a required keyword argument, not a default of `date.today()`.
    A parser that reads the wall clock cannot be tested against a MIN_AGE
    boundary without either freezing time globally or writing a test that
    starts failing on somebody's birthday.
    """
    number = normalise_digits(number).strip()

    if len(number) != 14 or not number.isdigit():
        return NidFailure(BAD_LENGTH)

    century_digit = number[0]
    if century_digit == "2":
        century = 1900
    elif century_digit == "3":
        century = 2000
    else:
        # 1 exists historically (1800s) and cannot belong to a living adult.
        # 4 would be the 2100s. Anything else is not a national ID number.
        return NidFailure(BAD_CENTURY)

    year = century + int(number[1:3])
    month = int(number[3:5])
    day = int(number[5:7])
    try:
        birth = _dt.date(year, month, day)
    except ValueError:
        # Catches month 00 and 13, day 00 and 32, 31 April, and 29 February in
        # a common year — the last being the one a hand-rolled
        # "month <= 12 and day <= 31" check always misses.
        return NidFailure(BAD_DATE)

    if birth > today:
        return NidFailure(FUTURE_DATE)

    gov_code = number[7:9]

    return ParsedNid(
        number=number,
        birth_date=birth,
        governorate_code=gov_code,
        governorate_name=GOVERNORATES.get(gov_code),
        sex_from_digit="male" if int(number[12]) % 2 == 1 else "female",
        check_digit=int(number[13]),
    )


def first_valid(
    ocr_text: str, *, today: _dt.date
) -> tuple[Optional[ParsedNid], Optional[str]]:
    """Pick the one candidate in the OCR output that survives every rule.

    Returns `(parsed, None)` on success or `(None, reason_code)` on failure.

    When several candidates fail, the reported code comes from the FIRST
    candidate tried — which, thanks to the ordering in `candidate_numbers`, is
    the one whose century digit was plausible. "The date on your card did not
    read correctly" is a far more actionable thing for support to see than "we
    found no fourteen-digit number", when in fact we found one and it was the
    card serial on the reverse.
    """
    candidates = candidate_numbers(ocr_text)
    if not candidates:
        return None, UNREADABLE

    first_failure: Optional[str] = None
    for candidate in candidates:
        result = parse(candidate, today=today)
        if isinstance(result, ParsedNid):
            return result, None
        if first_failure is None:
            first_failure = result.code
    return None, first_failure or UNREADABLE
