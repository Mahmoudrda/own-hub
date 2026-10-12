#!/usr/bin/env python3
"""Pull the 39 recipe cards out of `Rahoma's Recipe Book.pdf`, verbatim.

Run this, then `build_rahma_recipes.py`, then commit the JSON it writes. Nobody
types her Arabic by hand: a transcription is a chance to "improve" a word, and
the whole point of `bodyAr` is that it is hers.

## What the extractor does to the PDF's output, and why each fix is not an edit

`pdftotext` on a Canva-produced right-to-left page gives back Arabic
**presentation forms** (U+FExx) in visual order with bidi control marks around
every Latin or numeric run. Four consequences, and all four are artefacts of the
extractor rather than anything she wrote:

  1. **Presentation forms.** `ﺑﻴﻀﻪ` is five codepoints in the Arabic Presentation
     Forms-B block, which no Arabic keyboard produces and no search would match.
     `unicodedata.normalize('NFKC')` maps each back to its base letter, giving
     `بيضه` - the same word, in the encoding she actually typed.
  2. **Bidi marks.** RLE/PDF/LRM characters (`category == 'Cf'`) are layout
     instructions, not text. Dropped.
  3. **Spaces around a digit run land on the wrong side.** `الفرن  10دقايق` in
     the extract is `الفرن 10 دقايق` on the page: the LTR run's leading space
     went with the run. One space either side of a digit group restores what the
     page shows.
  4. **A digit *range* comes out reversed.** The page prints `25-30 دقيقة`; the
     extractor hands back `30-25`, because the range is one LTR run read
     right-to-left. Swapped back. Same for `C°200`, which is `200°C` on the page,
     and for the mirrored smiley `(:` which she typed as `:)`.

Two deliberate changes beyond de-artefacting, both recorded because neither is
reversible from the JSON alone:

  * **The en dash in a numeric range becomes a plain hyphen.** `25-30` rather
     than `25–30`. Product rule: no en or em dash reaches a woman. A range dash
     is not the machine-written-prose tell that rule exists to catch, so the
     narrowest possible compliance is to change the character and not the words.
  * **Canva's decorative emoji are dropped.** 🍚 🍋 🥗 🧀 sit in the text layer of
     pages 19 to 21 and the extractor drops them at positions that are not where
     they are drawn - 🍋 lands in the middle of a numbered list. They carry no
     instruction. Keeping a misplaced one would be less faithful than removing
     all four.

Everything else is character for character. `steps[]` and `ingredients[]` are
built by `build_rahma_recipes.py` as **slices of these lines**, never as new
sentences, which is what makes the substring test in
`test/features/eat/rahma_seed_test.dart` meaningful.

## Pages 20 and 21 are the same two cards

Identical text; `Btates bel lahma`'s illustration moves. A production error in
the book, so page 21 is dropped and no recipe carries `sourcePage: 21`.
"""

import json
import os
import re
import subprocess
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PDF = os.path.expanduser("~/Downloads/Rahoma's Recipe Book.pdf")
OUT = os.path.join(HERE, "rahma_book_cards.json")

# The English card titles, page by page, exactly as the book prints them.
#
# A title that wraps onto two lines in the book is listed as two lines, because
# that is how the extractor hands it over and matching the wrap is what lets the
# splitter find the boundary between one card and the next.
PAGES = {
    3: [["Lazy Cake"], ["Pancakes"]],
    4: [["Chia Pudding"], ["Coconut apple", "Pudding"]],
    5: [["Overnight", "oats"], ["Simple oat meal"]],
    7: [["Club Sandwich"], ["Yummy Egg", "Sandwich"]],
    8: [["Cottage Freshy", "salad"], ["Lazy Ranch", "Fries"]],
    9: [["Creamy cottage", "cheese"], ["Egg Pizza"]],
    10: [["Shakshoka"], ["Fool & Ta3mya"]],
    11: [["Potato w Eggs"], ["Pizza toast"]],
    13: [["Chicken Pizza"], ["BBQ Burger"]],
    14: [["Hwawshi"], ["Chicken lemon"]],
    15: [["Chicken Ranch", "Salad"], ["Tuna Wrap"]],
    16: [["Shrimp white", "sauce pasta"], ["Steak Meal"]],
    17: [["Oven Tender", "Chicken"], ["Buffalo sweet", "Wings"]],
    18: [["Makrona", "Bashmel"], ["Kebda Meal"]],
    19: [["Fattah"], ["Lahma bel basl"]],
    20: [["shorbt 3ads"], ["Btates bel lahma"]],
    23: [["Cookies with", "shay blabn"], ["Bagel"]],
    24: [["Crepe"], ["Banana", "pudding"]],
    25: [["Cheese cake"], ["French toast"]],
    26: [["Ice cream"]],
}

# The four section dividers, verbatim. Her spelling of "filling" and the missing
# `PS:` on section three are hers and are not typos to fix.
SECTIONS = [
    {
        "sectionId": "sweet_tooth_breakfast",
        "titleEn": "Sweet Tooth Breakfast",
        "psLineEn": "PS: You may need it on your period girl i got you :)",
        "dividerPage": 2,
        "order": 1,
    },
    {
        "sectionId": "salty_fulling_breakfast",
        "titleEn": "Salty fulling Breakfast",
        "psLineEn": "PS: I am keeping you full until lunch dear",
        "dividerPage": 6,
        "order": 2,
    },
    {
        "sectionId": "lunchy_junky_yum",
        "titleEn": "Lunchy junky yum",
        "psLineEn": "WOW I am eating junky healthy food",
        "dividerPage": 12,
        "order": 3,
    },
    {
        "sectionId": "comfy_dinner",
        "titleEn": "Comfy Dinner",
        "psLineEn": "Eating light to sleep comfy girlie",
        "dividerPage": 22,
        "order": 4,
    },
]

# Page 26 carries the closing letter under `Ice cream`. It starts at her heading
# and runs to her sign-off; the splitter cannot see it, because it has no Latin
# title of its own above the Arabic.
LETTER_FIRST_LINE = "ليه بنحاول ناكل صحي؟"

_EMOJI = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F000-\U0001F2FF️]"
)


AR = "؀-ۿ"

# The one card heading the parenthesis rules below cannot reach: the smiley makes
# the closing bracket part of the face, so a mirror of the brackets alone leaves
# `(A message to you :`. Named rather than pattern-matched, because a pattern
# loose enough to catch it would catch her real brackets too.
_LETTER_HEADING = ("(A message to you :", "A message to you :)")


def clean_line(raw):
    """One extracted line, de-artefacted. See the module note."""
    s = unicodedata.normalize("NFKC", raw)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Cf")
    s = _EMOJI.sub("", s)
    # Stripped here rather than only at the end: a bidi mark at the head of the
    # line leaves a space behind it, and every `^`-anchored rule below would miss.
    s = s.strip()
    # `1⁄2` and `1⁄4` (fraction slash) are the glyphs she typed as `½` and `¼`.
    s = s.replace("1⁄2", "½").replace("1⁄4", "¼").replace("⁄2", "/")
    # A reversed LTR run: `C°200` is `200°C` on the page, and `%100` is `100%`.
    s = re.sub(r"C°(\d+)", r"\1°C", s)
    s = re.sub(r"%(\d+)", r"\1%", s)
    # A reversed numeric range, and the en dash out of it in the same pass.
    rng = r"(\d+|½|¼)\s*[–—]\s*(\d+|½|¼)"
    s = re.sub(rng, lambda m: f"{m.group(2)}-{m.group(1)}", s)
    # Any en or em dash left over. None should be; this is the belt.
    s = s.replace("–", "-").replace("—", "-")
    # A mirrored smiley. She typed `:)` and `(:` is what bidi did to it.
    #
    # Held aside as a token across the bracket mirror below, because the closing
    # bracket of a smiley is a face and not an aside: mirroring it turns
    # `بنحبها :)` into `بنحبها :(`, which is the opposite of what she wrote.
    s = s.replace("(:", "\x00SMILE\x00").replace("(;", "\x00WINK\x00")

    # Brackets mirror in an RTL run, so an Arabic aside comes back inside out:
    # `) اختياري (` on the page is `(اختياري)`. Swapped only on a line that
    # actually carries Arabic — or that is nothing but a bracket, which is how a
    # closing bracket left alone on its own line arrives — because a Latin-only
    # line was never reordered. Her letter heading is the one exception: Latin
    # inside an Arabic block.
    if s.strip() == _LETTER_HEADING[0].replace("(", ")"):
        s = _LETTER_HEADING[1]
    elif re.search(f"[{AR}]", s) or re.fullmatch(r"[()\s]+", s):
        s = s.translate(str.maketrans("()", ")("))
        # `( ) Smash it` is `( Smash it )`: the empty pair is the aside and its
        # Latin content was pushed out of it by the same reordering.
        s = re.sub(r"\(\s*\)\s*([A-Za-z][^()]*)$", r"(\1)", s)

    # A digit or Latin group wants one space on each side of the Arabic beside it.
    # `الفرن 10دقايق` and `Steviaونقطتين` are both this defect.
    s = re.sub(f"([{AR}])([\\dA-Za-z])", r"\1 \2", s)
    s = re.sub(f"([\\dA-Za-z])([{AR}])", r"\1 \2", s)
    s = re.sub(f"(%)([{AR}])", r"\1 \2", s)
    # A plus sign between two ingredients, pushed against one of them.
    s = re.sub(f"([{AR}])\\+", r"\1 +", s)
    s = re.sub(f"\\+([{AR}])", r"+ \1", s)
    # An Arabic comma reads `الزيت، ضيفي`; the run gave back `الزيت ،ضيفي`.
    s = re.sub(f"([{AR}]) +،", r"\1،", s)
    s = re.sub(f"،([{AR}])", r"، \1", s)
    # A comma that closes a Latin phrase came back in front of it. The page
    # prints `في طاسة non-stick، سخني الزيت`; the extractor hands over
    # `في طاسة، non-stick سخني الزيت`, because the comma sits at the far end of
    # the LTR run and the run was read the other way round. Same defect as the
    # spaces around a digit group, one line further on. `، fryer` at the head of
    # a line is the same thing split across her line break: `air` ends the line
    # above and the comma closes `air fryer`.
    s = re.sub(r"،\s*([A-Za-z][A-Za-z-]*)", r" \1،", s)
    # A heading's colon: `الطريقة :شوحي` is `الطريقة: شوحي`, and
    # `تتقدم مع ½-1 :رغيف` is `تتقدم مع: ½-1 رغيف` — the LTR run between the
    # word and its colon carried the colon along with it.
    s = re.sub(f"([{AR}]) +([\\d½¼/-]+) +:", r"\1: \2 ", s)
    s = re.sub(f"([{AR}]) +:", r"\1: ", s)
    # A full stop that ended the line came back leading it.
    s = re.sub(f"^\\.\\s*(?=[{AR}])(.*)$", r"\1.", s)
    # `-1بيضه` is her numbering; the marker keeps its own space after it.
    s = re.sub(r"(^|\s)-(\d+)\s*", r"\1-\2 ", s)
    # `20 .11 جم` is `.11 20 جم`, and `15 -2 جرام` is `-2 15 جرام`: the marker
    # and the quantity that follows it are one LTR run, so they came back in the
    # order that run reads rather than the order the page prints.
    s = re.sub(r"^(\d+) +([.\-])(\d+) +", r"\2\3 \1 ", s)
    s = re.sub(r"[ \t]{2,}", " ", s)
    # Restored last: every rule above would have taken the smiley apart, the
    # colon rule most of all.
    s = s.replace("\x00SMILE\x00", ":)").replace("\x00WINK\x00", ";)")
    return s.strip()


_MARKER_ONLY = re.compile(r"^\.\d+$")
_HAS_MARKER = re.compile(r"(^|\s)[.\-]\d+(\s|$)")


def attach_markers(lines):
    """Put a stray `.7` back on the line it numbers.

    An Arabic list marker is an LTR run printed at the right edge of its line —
    the *start* of the line, in reading order. `pdftotext` emits it after the line
    it belongs to, and sometimes on a line of its own. So a solitary marker
    normally prefixes the line **above** it, unless that line already carries a
    marker of its own, in which case it belongs to the line below.

    `Fattah` is the one card this cannot recover: its markers are in a separate
    column and all nine arrive before any text at all, so which of the three
    1-2-3 groups each belongs to is not in the extract. There they are dropped,
    and `steps[].index` carries her numbering instead — which suits that card
    better anyway, because the book prints it as three numbered groups and the
    `components[]` model holds those three separately.
    """
    if lines and _MARKER_ONLY.match(lines[0]):
        return [l for l in lines if not _MARKER_ONLY.match(l)]
    out = list(lines)
    i = 0
    while i < len(out):
        if not _MARKER_ONLY.match(out[i]):
            i += 1
            continue
        marker = out.pop(i)
        if i - 1 >= 0 and not _HAS_MARKER.search(out[i - 1]):
            out[i - 1] = f"{marker} {out[i - 1]}"
        elif i < len(out):
            out[i] = f"{marker} {out[i]}"
        # A marker with nowhere to go is dropped rather than left floating.
    return out


def _logical_word(raw):
    """One `<word>` from `-bbox-layout`, in the order she typed it.

    Two transformations, in this order and not the other:

      1. **Reverse.** The bbox writer emits the glyphs of a word in the order
         they are *drawn*, which for Arabic is left to right. Plain `pdftotext`
         runs the bidi algorithm and gives logical order; the bbox writer does
         not, so the two disagree until this reverses one of them.
      2. **NFKC.** The same presentation-form fold `clean_line` does.

    Reversing *before* normalising is the whole trick. `ﻻ` (U+FEFB) is one
    drawn glyph that NFKC expands into two letters, ل then ا, already in
    logical order. Normalising first and reversing afterwards turns `الاكل`
    into `-االكل`, and every junction on a page carrying a lam-alef would then
    fail to match.
    """
    for entity, ch in (
        ("&amp;", "&"), ("&apos;", "'"), ("&quot;", '"'),
        ("&lt;", "<"), ("&gt;", ">"),
    ):
        raw = raw.replace(entity, ch)
    if re.search(r"[؀-ۿﭐ-﻿]", raw):
        raw = raw[::-1]
    raw = unicodedata.normalize("NFKC", raw)
    return "".join(ch for ch in raw if unicodedata.category(ch) != "Cf")


_BBOX_LINE = re.compile(r"<line [^>]*>(.*?)</line>", re.S)
_BBOX_WORD = re.compile(r"<word[^>]*>(.*?)</word>")


def page_junctions(pdf):
    """Per page, every place two drawn lines meet, with one word of context.

    `pdftotext` decides on its own where a drawn line ends and the next begins.
    On the closing letter it decides wrong twice and **joins two lines with no
    space at all**, so `دماغنا` at the end of one line and `مركزة` at the start
    of the next come back as `دماغنامركزة`. Those are the only two corrupted
    words in the book, and they are in the one page every woman reads.

    The repair cannot be a list of words, because the same glue would be
    invisible in the next book. So this reads the word boxes, which say exactly
    where each drawn line stops, and hands back the pairs that could have been
    glued. `repair_junctions` then only splits a pair it finds **actually**
    glued in the text.

    The context words on either side are what make it safe. `ونص` ends a line
    on page 17 and `معلقة` starts the next, so the pair (`ونص`, `معلقة`) is a
    real junction — and `ونصمعلقة` also appears, mid-line and unglued, on the
    *other* card on that same page, where it is a word she typed. Anchoring on
    the neighbours tells the two apart: her `ونصمعلقة` is preceded by `باودر`,
    and the junction's is preceded by `اسود`.

    Returns page number -> [(before, last, first, after)], where `before` and
    `after` may be None when the drawn line has only one word.
    """
    out = subprocess.run(
        ["pdftotext", "-bbox-layout", pdf, "-"],
        check=True, capture_output=True, text=True,
    ).stdout
    junctions = {}
    for page_no, page in enumerate(out.split("<page ")[1:], start=1):
        lines = []
        for line in _BBOX_LINE.finditer(page):
            words = [_logical_word(w) for w in _BBOX_WORD.findall(line.group(1))]
            words = [w for w in words if w]
            if not words:
                continue
            # The bbox writer lists words left to right. An Arabic line reads
            # the other way, so its last word is its leftmost.
            if re.search(f"[{AR}]", "".join(words)):
                words = words[::-1]
            lines.append(words)
        junctions[page_no] = [
            (
                above[-2] if len(above) > 1 else None,
                above[-1],
                below[0],
                below[1] if len(below) > 1 else None,
            )
            for above, below in zip(lines, lines[1:])
        ]
    return junctions


_ARABIC_LETTER = "ء-ي"


def repair_junctions(lines, junctions):
    """Put back the space `pdftotext` ate where it joined two drawn lines.

    Conservative on purpose: a pair is split only where the text shows it glued
    **and** both neighbouring words match. Anything less certain is left alone,
    because the cost of a wrong split is a word of hers that she did not write
    that way, and the cost of a missed one is a word that is already wrong.
    """
    out = list(lines)
    for before, last, first, after in junctions:
        pattern = ""
        if before:
            pattern += re.escape(before) + r"\s+"
        pattern += (
            f"(?<![{_ARABIC_LETTER}])"
            + re.escape(last + first)
            + f"(?![{_ARABIC_LETTER}])"
        )
        if after:
            pattern += r"\s+" + re.escape(after)
        replacement = ""
        if before:
            replacement += before + " "
        replacement += last + " " + first
        if after:
            replacement += " " + after
        for i, line in enumerate(out):
            out[i] = re.sub(pattern, replacement.replace("\\", "\\\\"), line)
    return out


def page_lines(pdf):
    """Every page of the book as a list of cleaned, non-empty lines."""
    out = subprocess.run(
        ["pdftotext", pdf, "-"], check=True, capture_output=True, text=True
    ).stdout
    junctions = page_junctions(pdf)
    pages = out.split("\f")
    return [
        repair_junctions(
            [clean_line(l) for l in p.split("\n") if clean_line(l)],
            junctions.get(n, []),
        )
        for n, p in enumerate(pages, start=1)
    ]


def split_page(lines, titles):
    """Cut one page's lines into one block per card, keyed by the joined title."""
    starts = []
    for title in titles:
        head = title[0]
        idx = next(
            (i for i, l in enumerate(lines) if l == head and i not in starts), None
        )
        if idx is None:
            sys.exit(f"title not found on page: {head!r}\n{lines}")
        starts.append(idx)
    blocks = {}
    for n, (title, start) in enumerate(zip(titles, starts)):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        name = " ".join(title)
        blocks[name] = apply_override(name, attach_markers(lines[start + len(title) : end]))
    return blocks


# The one block in the book that bidi extraction cannot recover, and why.
#
# `Fattah`'s assembly is a single line of five nouns joined by arrows, laid out
# as its own row on the page. `pdftotext` returns the nouns and the arrows as
# separate fragments in an order that is neither the reading order nor the
# drawing order, so there is nothing to un-reverse. It is typed here from the
# page render at `pdftoppm -f 19`, and the arrow is turned round: U+2192 points
# right, and in a right-to-left line that points backwards through her sequence.
#
# This is the only text in the book not produced mechanically, which is why it
# is a named constant rather than a rule.
OVERRIDES = {
    "Fattah": {
        "from": [
            "رز → عيش محمص →",
            "التجميع:",
            "صوص الطماطم",
            "فراخ",
            "→",
            "→",
            "صوص الزبادي",
        ],
        "to": [
            "التجميع:",
            "رز ← عيش محمص ← فراخ ← صوص الطماطم ← صوص الزبادي",
        ],
    }
}


def apply_override(title, lines):
    spec = OVERRIDES.get(title)
    if not spec:
        return lines
    src, dst = spec["from"], spec["to"]
    for i in range(len(lines) - len(src) + 1):
        if lines[i : i + len(src)] == src:
            return lines[:i] + dst + lines[i + len(src) :]
    sys.exit(f"override for {title} no longer matches the extract: {lines}")


def main():
    pdf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PDF
    pages = page_lines(pdf)
    cards = {}
    for page, titles in PAGES.items():
        blocks = split_page(pages[page - 1], titles)
        for title, body in blocks.items():
            # The closing letter is not part of `Ice cream`. It begins at her own
            # heading, which is the only Latin line inside the Arabic block.
            if LETTER_FIRST_LINE in body:
                cut = next(
                    i for i, l in enumerate(body) if l.startswith("A message to you")
                )
                cards["__letter__"] = body[cut:]
                body = body[:cut]
            cards[title] = body
    payload = {
        "sourcePdf": os.path.basename(pdf),
        "sections": SECTIONS,
        "cards": {k: "\n".join(v) for k, v in cards.items()},
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"{len(cards) - 1} cards + the closing letter -> {OUT}")


if __name__ == "__main__":
    main()
