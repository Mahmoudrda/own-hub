"""Play's feature graphic, 1024x500: the wordmark on paper, under its own line."""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROSE = (0xB4, 0x52, 0x6E)
PAPER = (0xFF, 0xF8, 0xF9)
INK = (0x24, 0x1C, 0x1F)

APP = ('/Users/mahmoudreda/womens-fitness-app-wireframe/.claude/worktrees/'
       'release-readiness/app')
F600 = os.path.join(APP, 'assets/fonts/Rubik-600.ttf')
F400 = os.path.join(APP, 'assets/fonts/Rubik-400.ttf')
OUT = '/Users/mahmoudreda/.claude/jobs/9eda914b/tmp/captioned-play/feature-graphic.png'

W, H, S = 1024, 500, 3


def ink_underline(draw, x0, x1, y, weight, colour):
    steps, top, bottom = 140, [], []
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        centre = y - math.sin(t * math.pi) * weight * 0.9
        half = weight * (0.18 + 0.82 * math.sin(t ** 0.82 * math.pi)) / 2
        top.append((x, centre - half))
        bottom.append((x, centre + half))
    draw.polygon(top + bottom[::-1], fill=colour)


img = Image.new('RGB', (W * S, H * S), PAPER)
d = ImageDraw.Draw(img)

mark = ImageFont.truetype(F600, int(H * 0.30) * S)
line = ImageFont.truetype(F400, int(H * 0.085) * S)

title = 'Own Hub'
tw = d.textlength(title, font=mark)
x = (W * S - tw) / 2
y = int(H * 0.22) * S
d.text((x, y), title, font=mark, fill=INK)
ink_underline(d, x, x + tw, y + mark.size * 1.12, max(4, int(H * 0.018) * S),
              ROSE)

sub = 'Training, meals and your cycle. Women only.'
sw = d.textlength(sub, font=line)
d.text(((W * S - sw) / 2, y + mark.size * 1.42), sub, font=line,
       fill=(0x6B, 0x5B, 0x60))

img.resize((W, H), Image.LANCZOS).save(OUT)
print(OUT, Image.open(OUT).size)
