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

ROSE = "#1A5D74"
ROSE_FILL = "#F4BEBB"
PAW_EDGE = "#E8A5A2"
PAGE = "#FCF8F2"

# Three tones of the body rose, the cream of belly and muzzle, the eye dark.
_BASE, _SHADE, _LIGHT = "#F4BEBB", "#E8A5A2", "#F9DEDC"
_INNER = "#D98A87"
_EYE = "#123F50"
_CREAM, _CREAM_SHADE = "#FBEFE0", "#F0DCC6"

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


def _loop(fn, count: int = 64, fit=None) -> str:
    pts = [fn(2 * math.pi * i / count) for i in range(count)]
    if fit:
        pts = [_fit_pt(p, *fit) for p in pts]
    return _smooth_closed(pts)


def _fit_pt(p, cx, cy, sx, sy, dx, dy):
    """The app's _fit: scaled about (cx, cy), then moved by (dx, dy)."""
    return (cx + (p[0] - cx) * sx + dx, cy + (p[1] - cy) * sy + dy)


def _head(a: float):
    ca, sa = math.cos(a), math.sin(a)
    rx = 0.32 * (1 + 0.07 * sa)
    return (0.5 + rx * _soft(ca, 2.1), 0.5 + 0.225 * _soft(sa, 2.1))


def _body(a: float):
    return (
        0.5 + 0.225 * _soft(math.cos(a), 2.25),
        0.83 + 0.165 * _soft(math.sin(a), 2.25),
    )


def _belly(a: float):
    return (
        0.5 + 0.125 * _soft(math.cos(a), 2.2),
        0.875 + 0.1 * _soft(math.sin(a), 2.2),
    )


def _foot(side: float):
    def at(a: float):
        return (
            0.5 + side * 0.115 + 0.075 * _soft(math.cos(a), 2.2),
            0.955 + 0.038 * _soft(math.sin(a), 2.2),
        )

    return at


def _cubic_path(start, curves, fits=(), mirror=False, close=True) -> str:
    def p(pt):
        for f in fits:
            pt = _fit_pt(pt, *f)
        return (1 - pt[0] if mirror else pt[0], pt[1])

    sx, sy = p(start)
    d = [f"M{_n(sx)} {_n(sy)}"]
    for c in curves:
        if len(c) == 2 and isinstance(c[0], float):
            x, y = p(c)
            d.append(f"L{_n(x)} {_n(y)}")
        else:
            (a, b), (c_, d_), (e, f) = p(c[0]), p(c[1]), p(c[2])
            d.append(f"C{_n(a)} {_n(b)} {_n(c_)} {_n(d_)} {_n(e)} {_n(f)}")
    return "".join(d) + ("Z" if close else "")


_EAR = ((0.53, 0.31), [
    ((0.62, 0.22), (0.7, 0.115), (0.775, 0.09)),
    ((0.83, 0.072), (0.862, 0.095), (0.865, 0.14)),
    ((0.88, 0.25), (0.878, 0.38), (0.83, 0.5)),
    (0.6, 0.5),
])
_EAR_SHADE = ((0.865, 0.14), [
    ((0.88, 0.25), (0.878, 0.38), (0.83, 0.5)),
    (0.775, 0.5),
    ((0.812, 0.4), (0.822, 0.27), (0.815, 0.16)),
    ((0.812, 0.115), (0.79, 0.098), (0.775, 0.1)),
    ((0.835, 0.075), (0.862, 0.098), (0.865, 0.14)),
])
_EAR_INNER = ((0.575, 0.335), [
    ((0.64, 0.25), (0.71, 0.16), (0.765, 0.142)),
    ((0.795, 0.132), (0.815, 0.148), (0.82, 0.18)),
    ((0.832, 0.26), (0.83, 0.35), (0.8, 0.44)),
    (0.62, 0.45),
])
_EAR_FIT = (0.7, 0.5, 0.9, 0.82, 0.0, 0.0)
_INNER_FITS = (_EAR_FIT, (0.7, 0.45, 0.88, 0.88, 0.0, 0.0))

_SHOULDER_X, _SHOULDER_Y = 0.14, 0.66
_UPPER, _FORE = 0.125, 0.145
_ARM_W, _PAW_R = 0.086, 0.05
_ARM_REST, _PAW_REST = -0.3, -0.1
_EDGE = 0.008


def _ease(t, a, b):
    x = min(max((t - a) / (b - a), 0.0), 1.0)
    return x * x * x * (x * (6 * x - 15) + 10)


def _arm_points(side: float, upper: float, fore: float):
    s = (0.5 + side * _SHOULDER_X, _SHOULDER_Y)
    ulen = _UPPER + 0.06 * _ease(upper, 1.2, 2.0)
    e = (s[0] + side * math.sin(upper) * ulen, s[1] + math.cos(upper) * ulen)
    p = (e[0] + side * math.sin(fore) * _FORE, e[1] + math.cos(fore) * _FORE)
    return s, e, p


def _bez(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(
        u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * d
        for a, b, c, d in zip(p0, p1, p2, p3)
    )


def _split(p0, p1, p2, p3, t):
    """De Casteljau: the cubic cut at t, as (left, right) control lists."""
    lerp = lambda a, b: tuple(x + (y - x) * t for x, y in zip(a, b))  # noqa: E731
    a, b, c = lerp(p0, p1), lerp(p1, p2), lerp(p2, p3)
    d, e = lerp(a, b), lerp(b, c)
    m = lerp(d, e)
    return (p0, a, d, m), (m, e, c, p3)


def _tail_paths():
    """The tail's S curve from the hip, cut where the cream tip starts."""
    segs = [
        ((0, 0), (-0.15, 0.015), (-0.25, -0.07), (-0.22, -0.18)),
        ((-0.22, -0.18), (-0.19, -0.24), (-0.22, -0.3), (-0.31, -0.31)),
    ]
    steps = 200
    pts, owner = [], []
    for si, s in enumerate(segs):
        for i in range(steps):
            pts.append(_bez(*s, i / steps))
            owner.append((si, i / steps))
    pts.append(segs[-1][3])
    owner.append((1, 1.0))
    lens = [0.0]
    for a, b in zip(pts, pts[1:]):
        lens.append(lens[-1] + math.dist(a, b))
    goal = lens[-1] * 0.8
    k = next(i for i, v in enumerate(lens) if v >= goal)
    si, t = owner[k]
    left, right = _split(*segs[si], t)
    root = [segs[0]] if si == 1 else []
    root += [left]
    tip = [right] + (segs[1:] if si == 0 else [])

    def write(cubics):
        d = f"M{_n(cubics[0][0][0])} {_n(cubics[0][0][1])}"
        for _, a, b, c in cubics:
            d += f"C{_n(a[0])} {_n(a[1])} {_n(b[0])} {_n(b[1])} {_n(c[0])} {_n(c[1])}"
        return d

    return write(root), write(tip)


def _g(content: str, transform: str = "") -> str:
    return f"<g{(' transform=' + chr(34) + transform + chr(34)) if transform else ''}>{content}</g>"


def kitten_svg(*, wave: bool = True, css_class: str = "kitten") -> str:
    """The kitten as one inline <svg>, decorative and hidden from readers.

    wave: the leading paw raised beside the face, the frame the app's
    welcome screen holds at the top of its wave. Otherwise she sits at rest.
    """
    lead = (2.05, 2.6) if wave else (_ARM_REST, _PAW_REST)
    trail = (_ARM_REST, _PAW_REST)
    parts = []

    def stroke(d, colour, width):
        return (
            f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{_n(width)}" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
        )

    def fill(d, colour, extra=""):
        return f'<path d="{d}" fill="{colour}"{extra}/>'

    def circle(cx, cy, r, colour):
        return f'<circle cx="{_n(cx)}" cy="{_n(cy)}" r="{_n(r)}" fill="{colour}"/>'

    def oval(cx, cy, w, h, colour, extra=""):
        return (
            f'<ellipse cx="{_n(cx)}" cy="{_n(cy)}" rx="{_n(w / 2)}" ry="{_n(h / 2)}" '
            f'fill="{colour}"{extra}/>'
        )

    def line(a, b):
        return f"M{_n(a[0])} {_n(a[1])}L{_n(b[0])} {_n(b[1])}"

    # Tail, behind everything: shade under, base over, the tip in cream.
    root, tip = _tail_paths()
    tail = (
        stroke(root, _SHADE, 0.07) + stroke(tip, _SHADE, 0.07)
        + stroke(root, _BASE, 0.058) + stroke(tip, _CREAM, 0.058)
    )
    parts.append(_g(tail, f"translate({_n(0.4)} {_n(0.92)})"))

    def arm(side, angles):
        s, e, p = _arm_points(side, *angles)
        out = stroke(line(s, e) + line(e, p), _SHADE, _ARM_W)
        nx, ny = -side * 0.003, -0.004
        sh = lambda q: (q[0] + nx, q[1] + ny)  # noqa: E731
        return out + stroke(line(sh(s), sh(e)) + line(sh(e), sh(p)), _BASE, _ARM_W - 0.014)

    def paw(side, angles):
        s, e, p = _arm_points(side, *angles)
        out = circle(p[0], p[1], _PAW_R + _EDGE, _SHADE)
        wrist = (e[0] + (p[0] - e[0]) * 0.45, e[1] + (p[1] - e[1]) * 0.45)
        out += stroke(line(wrist, p), _BASE, _ARM_W - 0.014)
        top = (p[0] - side * 0.003, p[1] - 0.004)
        out += circle(top[0], top[1], _PAW_R - 0.002, _BASE)
        out += circle(top[0] - 0.012, top[1] - 0.014, _PAW_R * 0.22, _LIGHT)
        for x in (-0.011, 0.011):
            out += stroke(
                line((top[0] + x, top[1] + 0.012), (top[0] + x, top[1] + 0.031)),
                _SHADE, 0.005,
            )
        return out

    parts.append(arm(-1, trail))
    parts.append(arm(1, lead))

    # Body: shade, the lit body a little up and left, the soft cast shade
    # under the head, then the cream belly in two tones, then the hind feet.
    parts.append(fill(_loop(_body), _SHADE))
    parts.append(fill(_loop(_body, fit=(0.5, 0.83, 0.94, 0.93, -0.01, -0.014)), _BASE))
    parts.append(
        oval(0.5, 0.735, 0.34, 0.08, _SHADE, ' fill-opacity="0.18" filter="url(#kcast)"')
    )
    parts.append(fill(_loop(_belly), _CREAM_SHADE))
    parts.append(fill(_loop(_belly, fit=(0.5, 0.875, 0.93, 0.9, -0.004, -0.007)), _CREAM))
    for side in (-1.0, 1.0):
        parts.append(fill(_loop(_foot(side), 24), _SHADE))
        parts.append(
            fill(_loop(_foot(side), 24,
                       fit=(0.5 + side * 0.115, 0.955, 0.92, 0.88, -0.004, -0.005)), _BASE)
        )
        for toe in (-0.014, 0.014):
            x = 0.5 + side * 0.115 + toe
            parts.append(stroke(line((x, 0.948), (x, 0.966)), _SHADE, 0.006))

    # Ears, base then the shade band down the outer side, then the inner ear;
    # the head goes over them.
    for mirror in (False, True):
        parts.append(fill(_cubic_path(*_EAR, fits=(_EAR_FIT,), mirror=mirror), _BASE))
        parts.append(fill(_cubic_path(*_EAR_SHADE, fits=(_EAR_FIT,), mirror=mirror), _SHADE))
        parts.append(fill(_cubic_path(*_EAR_INNER, fits=_INNER_FITS, mirror=mirror), _INNER))

    parts.append(fill(_loop(_head), _BASE))
    # The soft crescent along the top left of the head: the head fitted up and
    # left, minus the head fitted down and right.
    parts.append(
        '<g mask="url(#kglow)">'
        + fill(_loop(_head, fit=(0.5, 0.5, 0.9, 0.86, -0.012, -0.02)), "#FFFFFF", ' fill-opacity="0.18"')
        + "</g>"
    )

    for side in (-1, 1):
        parts.append(oval(0.5 + side * 0.225, 0.605, 0.1, 0.06, _SHADE, ' fill-opacity="0.85"'))
    for side in (-1, 1):
        parts.append(oval(0.5 + side * 0.046, 0.6, 0.106, 0.086, _CREAM_SHADE))
    for side in (-1, 1):
        parts.append(oval(0.5 + side * 0.046, 0.597, 0.1, 0.08, _CREAM))

    almond = "M-0.95 0.14C-0.6 -0.95 0.6 -1 1 -0.02C0.6 0.9 -0.4 1 -0.95 0.14Z"
    eye_r, eye_y, spread = 0.066, 0.54, 0.14
    for side in (-1, 1):
        cx = 0.5 + side * spread
        parts.append(
            f'<path d="{almond}" fill="{_EYE}" transform="translate({_n(cx)} {_n(eye_y)}) '
            f'scale({side * eye_r * 1.08 * _SCALE:.2f} {eye_r * 0.96 * _SCALE:.2f})"/>'
        )
        parts.append(circle(cx + eye_r * 0.2, eye_y - eye_r * 0.3, eye_r * 0.27, PAGE))

    nose = "M-21-7C-12-12 12-12 21-7C19 4 8 12 0 14C-8 12-19 4-21-7Z"
    parts.append(_g(f'<path d="{nose}" fill="{_INNER}"/>', f"translate({_n(0.5)} {_n(0.556)})"))
    mouth = "M-34-8C-32 14-6 16 0 0C6 16 32 14 34-8"
    parts.append(
        f'<path d="{mouth}" transform="translate({_n(0.5)} {_n(0.578)})" fill="none" '
        f'stroke="{_EYE}" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>'
    )

    # Paws last, so a raised paw is in front of the cheek.
    parts.append(paw(-1, trail))
    parts.append(paw(1, lead))

    head_fit = (0.5, 0.5, 0.9, 0.86, 0.02, 0.026)
    defs = (
        "<defs>"
        '<filter id="kcast" x="-40%" y="-120%" width="180%" height="340%">'
        '<feGaussianBlur stdDeviation="30"/></filter>'
        '<mask id="kglow" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000">'
        '<rect width="1000" height="1000" fill="#000"/>'
        + fill(_loop(_head, fit=(0.5, 0.5, 0.9, 0.86, -0.012, -0.02)), "#FFF")
        + fill(_loop(_head, fit=head_fit), "#000")
        + "</mask></defs>"
    )

    return (
        f'<svg class="{css_class}" viewBox="40 40 920 960" width="230" height="240" '
        'aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">'
        + defs + "".join(parts) + "</svg>"
    )


# ------------------------------------------------------------ brand mark ---

_BLADE = (
    "M153.27 995.18Q585.19 559.65 846.73 4.82Q414.81 440.35 153.27 995.18Z"
)


def mark_svg(colour: str = ROSE, *, tile: str | None = None, mask_id: str = "c") -> str:
    """The Own Hub mark (app/assets/brand/ownhub-mark.svg), as a file.

    tile: when set, the mark sits on a rounded tile of that colour, the
    way the app shows it on its welcome screen and as its icon."""
    if tile:
        ink, back = ROSE, (
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
    """The app icon: the petrol mark on the Pale Pink tile.

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
        f'height="{1000 + 2 * pad:.1f}" rx="{rx:.1f}" fill="{ROSE_FILL}"/>'
        f'<circle cx="500" cy="500" r="327.5" fill="none" stroke="{ROSE}" '
        'stroke-width="125" mask="url(#c)"/>'
        f'<path d="{_BLADE}" fill="{ROSE}"/>'
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
