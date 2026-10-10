"""Compose store screenshots: a headline on paper, the real screen beneath it.

The device capture is never repainted or cropped into: it sits on the brand's
paper with one line of Rubik above it and the same tapered pen underline the
product draws, so the listing looks like the app rather than like a template.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROSE = (0xB4, 0x52, 0x6E)
PAPER = (0xFF, 0xF8, 0xF9)
INK = (0x24, 0x1C, 0x1F)
LINE = (0xE7, 0xD8, 0xDC)

APP = ('/Users/mahmoudreda/womens-fitness-app-wireframe/.claude/worktrees/'
       'release-readiness/app')
F600 = os.path.join(APP, 'assets/fonts/Rubik-600.ttf')

# One line each, in the product's own voice. Square brackets mark the words set
# in rose; the pen line is drawn under the last word of the headline.
CAPTIONS = {
    '01-home': 'Your whole [day], on one page.',
    '02-session': 'Fifteen minutes. [Five moves].',
    '03-midset': '[One tap] logs the set.',
    '04-finished': 'And the week [counts].',
    '05-eat': 'Log a meal in the [size you serve it].',
    '06-grocery': 'Grouped the way [you shop].',
    '07-cycle': '[You choose] what to log.',
    '08-feeling': 'It asks [how you feel].',
    '09-choose': 'A [gentler option], whenever you want one.',
    '10-firstweek': 'A first week with [no timer].',
}


def parse(caption):
    """Split into (word, emphasised) pairs, dropping the brackets."""
    out, rose = [], False
    for token in caption.split():
        word, opens, closes = token, token.startswith('['), ']' in token
        if opens:
            rose = True
        word = word.replace('[', '').replace(']', '')
        out.append((word, rose))
        if closes:
            rose = False
    return out


def ink_underline(draw, x0, x1, y, weight, colour):
    steps = 120
    top, bottom = [], []
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        centre = y - math.sin(t * math.pi) * weight * 0.9
        half = weight * (0.18 + 0.82 * math.sin(t ** 0.82 * math.pi)) / 2
        top.append((x, centre - half))
        bottom.append((x, centre + half))
    draw.polygon(top + bottom[::-1], fill=colour)


def compose(shot, caption, size):
    W, H = size
    S = 2  # supersample, so the pen line keeps its taper
    card = Image.new('RGB', (W * S, H * S), PAPER)
    d = ImageDraw.Draw(card)

    margin = int(W * 0.085) * S
    font = ImageFont.truetype(F600, int(W * 0.062) * S)
    words = parse(caption)

    # Laid out word by word, because the colour changes mid-line.
    lines, line = [], []
    for word, rose in words:
        trial = ' '.join([w for w, _ in line] + [word])
        if line and d.textlength(trial, font=font) > W * S - margin * 2:
            lines.append(line)
            line = [(word, rose)]
        else:
            line.append((word, rose))
    if line:
        lines.append(line)

    y = int(H * 0.055) * S
    lh = int(font.size * 1.26)
    for row in lines:
        x = margin
        for word, rose in row:
            d.text((x, y), word, font=font, fill=ROSE if rose else INK)
            x += d.textlength(word + ' ', font=font)
        y += lh

    tail = lines[-1]
    end = margin + d.textlength(' '.join(w for w, _ in tail), font=font)
    start = end - d.textlength(tail[-1][0], font=font)
    ink_underline(d, start, end, y - lh + font.size * 1.12,
                  max(3, int(W * 0.0055) * S), ROSE)

    # The screen itself, full width, bleeding off the bottom edge.
    top = y + int(H * 0.022) * S
    shot_w = W * S - margin * 2
    shot_h = int(shot.height * shot_w / shot.width)
    card.paste(shot.resize((shot_w, shot_h), Image.LANCZOS), (margin, top))
    d.rectangle([margin, top, margin + shot_w, min(top + shot_h, H * S - 1)],
                outline=LINE, width=max(1, S))

    return card.resize((W, H), Image.LANCZOS)


src, out = sys.argv[1], sys.argv[2]
W, H = int(sys.argv[3]), int(sys.argv[4])
os.makedirs(out, exist_ok=True)
for name, caption in CAPTIONS.items():
    path = os.path.join(src, name + '.png')
    if not os.path.exists(path):
        print('  MISSING', name)
        continue
    compose(Image.open(path).convert('RGB'), caption,
            (W, H)).save(os.path.join(out, name + '.png'))
    print(' ', name, '->', f'{W}x{H}')
