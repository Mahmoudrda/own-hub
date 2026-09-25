"""Reading the printed النوع (sex) field off the back of the card.

This is the independent second opinion on digit 13, and it is the reason a
single mis-OCR'd Arabic-Indic digit cannot on its own turn a woman away from a
women-only product. Digit 13 says one thing; this says another; when they
disagree, or when this cannot be read at all, a person decides.

Pure module: no I/O, no clock, no Firebase. Same contract as nid.py.

Why the normalisation below is not optional
-------------------------------------------
Arabic text that comes back from OCR is never in the one canonical form a naive
`text == "أنثى"` comparison expects. It carries, in any combination:

  * **Alef variants.** أ (hamza above, U+0623), إ (hamza below, U+0625),
    آ (madda, U+0622), ٱ (wasla, U+0671) all collapse to ا (U+0627) in
    ordinary writing and OCR picks between them essentially at random. The word
    for female is written both أنثى and انثى on real documents.
  * **Final yeh.** ى (alef maksura, U+0649) and ي (yeh, U+064A) are used
    interchangeably at the end of a word across the Arab world, and Egyptian
    printing in particular drops the dots. أنثى and أنثي are the same word.
  * **Teh marbuta.** ة (U+0629) against ه (U+0647) — the same substitution
    habit, at the other end of the alphabet.
  * **Diacritics.** Fatha, damma, kasra, shadda, sukun (U+064B..U+0652) and the
    superscript alef (U+0670). Rare in print, common in OCR hallucination.
  * **Tatweel.** ـ (U+0640), the kashida, a pure typographic stretch character
    with no phonetic value, inserted to justify a line. أنـــثى is أنثى.
  * **Presentation forms.** U+FE70..U+FEFF, the legacy contextual-shape block.
    Some OCR engines still emit these rather than the base letters.

Every one of those is a way for a real woman's card to fail an equality test
written by someone who only ever saw the string in a code editor.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Optional

FEMALE = "female"
MALE = "male"

_DIACRITICS = re.compile(
    "["
    "ً-ْ"  # fathatan .. sukun
    "ٓ-ٕ"  # maddah, hamza above/below
    "ٰ"  # superscript alef
    "ۖ-ۭ"  # Quranic annotation marks
    "]"
)

_TATWEEL = "ـ"

_LETTER_FOLD = str.maketrans(
    {
        "آ": "ا",  # آ -> ا
        "أ": "ا",  # أ -> ا
        "إ": "ا",  # إ -> ا
        "ٱ": "ا",  # ٱ -> ا
        "ى": "ي",  # ى -> ي
        "ة": "ه",  # ة -> ه
        "ؤ": "و",  # ؤ -> و
        "ئ": "ي",  # ئ -> ي
    }
)


def normalise(text: str) -> str:
    """Fold Arabic text to the one form the comparisons below expect.

    NFKC first, which is what converts the presentation-form block back to base
    letters and also normalises any Latin the card carries. Then strip
    diacritics and tatweel, then fold the letter variants, then collapse
    whitespace. Order matters: folding before NFKC would miss the presentation
    forms entirely, because U+FE83 (alef with hamza, isolated) is not U+0623
    until NFKC has run.
    """
    text = unicodedata.normalize("NFKC", text)
    text = _DIACRITICS.sub("", text)
    text = text.replace(_TATWEEL, "")
    text = text.translate(_LETTER_FOLD)
    return re.sub(r"\s+", " ", text).strip()


_FEMALE_FORMS = frozenset(normalise(w) for w in ("أنثى", "انثى", "أنثي", "انثي"))
_MALE_FORMS = frozenset(normalise(w) for w in ("ذكر", "ذكـر"))

_LABEL_FORMS = frozenset(normalise(w) for w in ("النوع", "نوع", "الجنس", "جنس"))
"""The field label itself.

النوع is what the card prints. الجنس is accepted too: it is the word used on
some older cards and on the machine-readable summary, and accepting both costs
nothing.
"""

_WORD = re.compile(r"[^\W\d_]+", re.UNICODE)


def _tokens(text: str) -> list[str]:
    """Split into words, then unglue a label that has fused to its value.

    The fused case is real and was found by a test, not imagined: OCR
    hallucinates a fatha between the label and the value, `normalise` strips the
    diacritic as it must, and "النوعَأنثى" becomes the single token
    "النوعأنثى" — which matches neither the label nor the value and reads as
    "field unreadable" for a card that was perfectly legible.

    The fix is narrow on purpose. Only a KNOWN LABEL is peeled off the front of
    a token. A general substring search would be the obvious alternative and is
    wrong: "ذكر" (male) is a substring of "ذكرى", a common Egyptian given name,
    so substring matching would read a woman's father's name as her sex.
    """
    out: list[str] = []
    for word in _WORD.findall(text):
        for label in _LABEL_FORMS:
            if word != label and word.startswith(label) and len(word) > len(label):
                out.append(label)
                out.append(word[len(label):])
                break
        else:
            out.append(word)
    return out


def read_sex_field(back_text: str) -> Optional[str]:
    """Return FEMALE, MALE, or None when the field could not be read.

    None is a first-class answer here, not a failure to handle later. A card
    photographed at an angle, in a dark room, by a woman who has never had to
    photograph a document before, very often yields a number and no sex word —
    and per the brief, an unreadable النوع routes to a human in BOTH directions,
    including when digit 13 says male. A single misread Arabic-Indic glyph flips
    digit 13, and a woman turned away by one glyph is the worst thing this
    system can do. A man waiting for a reviewer is not a harm.

    Ambiguity is also None: if both words somehow appear, we have not read the
    field, we have read the card badly.
    """
    words = _tokens(normalise(back_text))
    if not words:
        return None

    female_hits = [i for i, w in enumerate(words) if w in _FEMALE_FORMS]
    male_hits = [i for i, w in enumerate(words) if w in _MALE_FORMS]

    if female_hits and male_hits:
        # Both present. Could be a two-sided read, a form template, or noise.
        # Prefer the one that sits immediately after a النوع label, and if
        # neither does, admit we do not know.
        labelled = _after_label(words, female_hits, male_hits)
        return labelled
    if female_hits:
        return FEMALE
    if male_hits:
        return MALE
    return None


def _after_label(
    words: list[str], female_hits: list[int], male_hits: list[int]
) -> Optional[str]:
    """Break a tie by proximity to the field label.

    On a real card the value sits within a word or two of النوع. `ذكر` appearing
    twelve words away, in the middle of the address or a parent's name (Egyptian
    names routinely contain it), is not the sex field.
    """
    label_positions = [i for i, w in enumerate(words) if w in _LABEL_FORMS]
    if not label_positions:
        return None

    def nearest(hits: list[int]) -> int:
        return min(abs(h - lp) for h in hits for lp in label_positions)

    female_distance = nearest(female_hits)
    male_distance = nearest(male_hits)
    if female_distance == male_distance:
        return None
    return FEMALE if female_distance < male_distance else MALE
