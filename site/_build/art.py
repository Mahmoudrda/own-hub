# -*- coding: utf-8 -*-
"""Drawings the site carries as inline SVG or as small SVG files.

Everything here is geometry, so the output is the same on every run and the
generator needs nothing outside the Python standard library.

The kitten is the app's own kitten (app/lib/ui/hand/mascot/kitten_painter.dart),
rebuilt from the same construction values: a 1 x 1 box, the head and body as
superellipses, the same ear curves, eyes and mouth. Flat colour, no outline.
It is decorative everywhere it appears, so every copy is aria-hidden.
"""

from __future__ import annotations

import math

ROSE = "#A24661"
ROSE_FILL = "#F2B6C6"
PAW_EDGE = "#E99BB2"
PAGE = "#FFF8F9"

# ----------------------------------------------------------------- kitten ---

_SCALE = 1000.0


def _n(v: float) -> str:
    """A coordinate in the 1000 box, written short."""
    out = f"{v * _SCALE:.1f}"
    return out[:-2] if out.endswith(".0") else out


def _soft(v: float, n: float) -> float:
    return math.copysign(abs(v) ** (2 / n), v)


def _smooth_closed(points) -> str:
    """The app's smoothPath: a closed Catmull-Rom loop written as cubics."""
    n = len(points)
    at = lambda i: points[i % n]  # noqa: E731
    x0, y0 = points[0]
    d = [f"M{_n(x0)} {_n(y0)}"]
    for i in range(n):
        p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d.append(
            f"C{_n(c1[0])} {_n(c1[1])} {_n(c2[0])} {_n(c2[1])} {_n(p2[0])} {_n(p2[1])}"
        )
    return "".join(d) + "Z"


def _loop(fn, count: int = 48) -> str:
    return _smooth_closed([fn(2 * math.pi * i / count) for i in range(count)])


def _head(a: float):
    ca, sa = math.cos(a), math.sin(a)
    rx = 0.32 * (1 + 0.05 * sa)
    return (0.5 + rx * _soft(ca, 2.15), 0.5 + 0.24 * _soft(sa, 2.15))


def _body(a: float):
    return (
        0.5 + 0.225 * _soft(math.cos(a), 2.25),
        0.83 + 0.165 * _soft(math.sin(a), 2.25),
    )


def _cubic_path(start, curves, close_to=None, mirror=False) -> str:
    def p(x, y):
        return (1 - x if mirror else x, y)

    sx, sy = p(*start)
    d = [f"M{_n(sx)} {_n(sy)}"]
    for c in curves:
        if len(c) == 2:
            x, y = p(*c)
            d.append(f"L{_n(x)} {_n(y)}")
        else:
            (a, b), (c_, d_), (e, f) = p(*c[0]), p(*c[1]), p(*c[2])
            d.append(f"C{_n(a)} {_n(b)} {_n(c_)} {_n(d_)} {_n(e)} {_n(f)}")
    return "".join(d) + "Z"


_EAR = ((0.53, 0.31), [
    ((0.62, 0.22), (0.7, 0.115), (0.775, 0.09)),
    ((0.83, 0.072), (0.862, 0.095), (0.865, 0.14)),
    ((0.88, 0.25), (0.878, 0.38), (0.83, 0.5)),
    (0.6, 0.5),
])
_INNER = ((0.575, 0.335), [
    ((0.64, 0.25), (0.71, 0.16), (0.775, 0.137)),
    ((0.81, 0.125), (0.83, 0.14), (0.835, 0.175)),
    ((0.848, 0.26), (0.846, 0.35), (0.815, 0.44)),
    (0.62, 0.45),
])

_SHOULDER_X, _SHOULDER_Y = 0.14, 0.66
_UPPER, _FORE = 0.125, 0.145
_ARM_W, _PAW_R = 0.086, 0.05
_ARM_REST, _PAW_REST = -0.3, -0.1


def _ease(t, a, b):
    x = min(max((t - a) / (b - a), 0.0), 1.0)
    return x * x * x * (x * (6 * x - 15) + 10)


def _arm_points(side: float, upper: float, fore: float):
    s = (0.5 + side * _SHOULDER_X, _SHOULDER_Y)
    ulen = _UPPER + 0.06 * _ease(upper, 1.2, 2.0)
    e = (s[0] + side * math.sin(upper) * ulen, s[1] + math.cos(upper) * ulen)
    p = (e[0] + side * math.sin(fore) * _FORE, e[1] + math.cos(fore) * _FORE)
    return s, e, p


def kitten_svg(*, wave: bool = True, css_class: str = "kitten") -> str:
    """The kitten as one inline <svg>, decorative and hidden from readers.

    wave: the leading paw raised beside the face, the frame the app's
    welcome screen holds at the top of its wave. Otherwise she sits at rest.
    """
    lead = (2.05, 2.6) if wave else (_ARM_REST, _PAW_REST)
    trail = (_ARM_REST, _PAW_REST)

    parts = []
    # Tail, behind everything.
    tail = "M0 0C-140 10-220-60-200-170C-190-220-150-240-120-220"
    parts.append(
        f'<path d="{tail}" transform="translate(360 930)" fill="none" '
        f'stroke="{ROSE_FILL}" stroke-width="62" stroke-linecap="round"/>'
    )

    def arm(side, angles):
        s, e, p = _arm_points(side, *angles)
        return (
            f'<path d="M{_n(s[0])} {_n(s[1])}L{_n(e[0])} {_n(e[1])}L{_n(p[0])} {_n(p[1])}" '
            f'fill="none" stroke="{ROSE_FILL}" stroke-width="{_n(_ARM_W)}" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
        )

    def paw(side, angles):
        s, e, p = _arm_points(side, *angles)
        return (
            f'<circle cx="{_n(p[0])}" cy="{_n(p[1])}" r="{_n(_PAW_R + 0.008)}" fill="{PAW_EDGE}"/>'
            f'<circle cx="{_n(p[0])}" cy="{_n(p[1])}" r="{_n(_PAW_R)}" fill="{ROSE_FILL}"/>'
        )

    parts.append(arm(-1, trail))
    parts.append(arm(1, lead))
    parts.append(f'<path d="{_loop(_body)}" fill="{ROSE_FILL}"/>')
    parts.append(f'<path d="{_cubic_path(*_EAR)}" fill="{ROSE_FILL}"/>')
    parts.append(f'<path d="{_cubic_path(*_INNER)}" fill="{ROSE}"/>')
    parts.append(f'<path d="{_cubic_path(*_EAR, mirror=True)}" fill="{ROSE_FILL}"/>')
    parts.append(f'<path d="{_cubic_path(*_INNER, mirror=True)}" fill="{ROSE}"/>')
    parts.append(f'<path d="{_loop(_head, 64)}" fill="{ROSE_FILL}"/>')

    eye_r, eye_y, spread = 0.066, 0.54, 0.15
    for side in (-1, 1):
        cx = 0.5 + side * spread
        parts.append(f'<circle cx="{_n(cx)}" cy="{_n(eye_y)}" r="{_n(eye_r)}" fill="{ROSE}"/>')
        parts.append(
            f'<circle cx="{_n(cx + eye_r * 0.24)}" cy="{_n(eye_y - eye_r * 0.34)}" '
            f'r="{_n(eye_r * 0.27)}" fill="{PAGE}"/>'
        )
    mouth = "M-34-8C-32 14-6 16 0 0C6 16 32 14 34-8"
    parts.append(
        f'<path d="{mouth}" transform="translate(500 578)" fill="none" stroke="{ROSE}" '
        'stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>'
    )
    parts.append(paw(-1, trail))
    parts.append(paw(1, lead))

    return (
        f'<svg class="{css_class}" viewBox="40 40 920 960" width="230" height="240" '
        'aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">'
        + "".join(parts)
        + "</svg>"
    )


# ------------------------------------------------------------ brand mark ---

_BLADE = (
    "M153.27 995.18Q585.19 559.65 846.73 4.82Q414.81 440.35 153.27 995.18Z"
)


def mark_svg(colour: str = ROSE, *, tile: str | None = None, mask_id: str = "c") -> str:
    """The Own Hub mark (app/assets/brand/ownhub-mark.svg), as a file.

    tile: when set, the mark sits light on a rounded tile of that colour, the
    way the app shows it on its welcome screen and as its icon."""
    if tile:
        ink, back = PAGE, (
            f'<rect x="-250" y="-250" width="1500" height="1500" rx="330" fill="{tile}"/>'
        )
        view = "-250 -250 1500 1500"
    else:
        ink, back, view = colour, "", "0 0 1000 1000"
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}">'
        f'<defs><mask id="{mask_id}" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000">'
        '<rect width="1000" height="1000" fill="#fff"/>'
        f'<path d="{_BLADE}" stroke="#000" stroke-width="60" stroke-linejoin="round"/>'
        "</mask></defs>"
        + back
        + f'<circle cx="500" cy="500" r="327.5" fill="none" stroke="{ink}" '
        f'stroke-width="125" mask="url(#{mask_id})"/>'
        f'<path d="{_BLADE}" fill="{ink}"/>'
        "</svg>\n"
    )


def icon_svg(*, size: int = 64, full_bleed: bool = False, safe: float = 1.0) -> str:
    """The app icon: the light mark on the rose tile.

    full_bleed: a square with no rounding, for a platform that rounds it
    itself. safe: how much of the tile the mark may fill (a maskable icon
    keeps it inside the middle 80 per cent)."""
    pad = 250 / safe + (1000 / safe - 1000) / 2
    view = f"{-pad:.1f} {-pad:.1f} {1000 + 2 * pad:.1f} {1000 + 2 * pad:.1f}"
    rx = 0 if full_bleed else (1000 + 2 * pad) * 0.22
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" width="{size}" height="{size}">'
        '<defs><mask id="c" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000">'
        '<rect width="1000" height="1000" fill="#fff"/>'
        f'<path d="{_BLADE}" stroke="#000" stroke-width="60" stroke-linejoin="round"/>'
        "</mask></defs>"
        f'<rect x="{-pad:.1f}" y="{-pad:.1f}" width="{1000 + 2 * pad:.1f}" '
        f'height="{1000 + 2 * pad:.1f}" rx="{rx:.1f}" fill="{ROSE}"/>'
        f'<circle cx="500" cy="500" r="327.5" fill="none" stroke="{PAGE}" '
        'stroke-width="125" mask="url(#c)"/>'
        f'<path d="{_BLADE}" fill="{PAGE}"/>'
        "</svg>\n"
    )


# ------------------------------------------------------------- hand marks ---

def underline_svg() -> str:
    """The app's hand underline: one long pen stroke and a shorter second
    pass, as drawn under 'Today's workout'. Stretched to the word it sits
    under, with the line weight held."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 16" '
        'preserveAspectRatio="none">'
        f'<path d="M2 7C60 4 150 5 298 3" fill="none" stroke="{ROSE}" '
        'stroke-width="2.2" stroke-linecap="round" vector-effect="non-scaling-stroke"/>'
        f'<path d="M50 12C120 9 200 9 262 8" fill="none" stroke="{ROSE}" '
        'stroke-width="1.6" stroke-linecap="round" vector-effect="non-scaling-stroke"/>'
        "</svg>\n"
    )


def arrow_svg() -> str:
    """The app's 'Up next' arrow: a loose pen curve ending in an open head."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 90 70">'
        f'<path d="M6 4C4 30 20 56 78 60" fill="none" stroke="{ROSE}" '
        'stroke-width="2" stroke-linecap="round"/>'
        f'<path d="M66 50L80 60L64 67" fill="none" stroke="{ROSE}" '
        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
        "</svg>\n"
    )
