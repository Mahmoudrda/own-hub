#!/usr/bin/env python3
"""Rasterise the app icons from `assets/brand/ownhub-mark.svg`.

Nothing here traces, crops or upscales a bitmap. Every PNG is rendered from
the vector at its final size, so the diagonal is a clean edge at 20 px and at
1024 px alike. Run it after any edit to the master:

    python3 tool/render_brand_icons.py            # from the `app/` directory
    dart run flutter_launcher_icons              # every density and the XML
    python3 tool/render_brand_icons.py --resample   # redraw them from the vector

The third step is the one that matters for the small sizes. The generator
makes them by resizing the 1024 px bitmap, and a 20:1 downsample of a hairline
diagonal is a grey smear however good the filter is; `--resample` redraws each
generated file from the vector at its own pixel size instead.

`--logo` writes the in-app logo instead (see `render_logo`):

    python3 tool/render_brand_icons.py --logo

Without `--resample` or `--logo` it writes two files and only two:

  assets/icon/icon-1024.png        iOS and the Android legacy icon. Opaque,
                                   square, no rounded corners: Apple applies
                                   the mask itself and rejects alpha.
  assets/icon/icon-foreground.png  the Android adaptive foreground, on a
                                   transparent 108 dp canvas with the mark
                                   inside the 66 dp safe circle.

The renderer is headless Chrome, which is already on this machine and uses
Skia, the same rasteriser Flutter draws with.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
MASTER = os.path.join(APP, 'assets', 'brand', 'ownhub-mark.svg')
ICONS = os.path.join(APP, 'assets', 'icon')

# The master's own ink. The icons are drawn in paper on rose, so the renderer
# swaps this for whatever `--ink` asks for; it insists on finding it exactly
# twice, because a quiet miss would ship a rose mark on a rose ground.
MASTER_INK = '#A24661'

ROSE = '#A24661'   # AppTokens.primary, the ground the app icon has always had
PAPER = '#FFF8F9'  # AppTokens.surface

# Geometry of the master, repeated here so the arithmetic below reads:
BOX = 1000.0       # the master's viewBox
TIP = 604.5        # distance from the centre to a blade tip
RING = 390.0       # ring outer radius

# flutter_launcher_icons 0.14.x wraps the adaptive foreground in
# `<inset android:inset="16%">`. The foreground PNG is sized around that, and
# `check_inset()` shouts if a future version changes it.
INSET = 0.16

CHROME = ('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')


def mark_body():
    """The master's drawing, without its <svg> wrapper or its comment."""
    svg = open(MASTER).read()
    inner = svg[svg.index('>', svg.index('<svg')) + 1:svg.rindex('</svg>')]
    return inner


def compose(size, ink, background, ring_fraction):
    """An SVG of `size` px with the mark centred, its ring `ring_fraction`
    of the canvas across."""
    body = mark_body()
    n = body.count(MASTER_INK)
    if n != 2:
        raise SystemExit('expected 2 "%s" in the master, found %d' % (MASTER_INK, n))
    body = body.replace(MASTER_INK, ink)
    scale = (ring_fraction * size) / (2 * RING)
    c = size / 2.0
    bg = ('  <rect width="%d" height="%d" fill="%s"/>\n' % (size, size, background)
          if background else '')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
            'viewBox="0 0 %d %d">\n%s  <g transform="translate(%.4f %.4f) '
            'scale(%.6f) translate(-500 -500)">%s</g>\n</svg>\n'
            % (size, size, size, size, bg, c, c, scale, body))


def render(svg_text, size, out):
    if not os.path.exists(CHROME):
        raise SystemExit(
            'no rasteriser: expected Chrome at %s. Any renderer that reads SVG '
            'will do (rsvg-convert, Inkscape, resvg); point CHROME at it or '
            'swap the subprocess call below. What must not happen is resizing '
            'a PNG instead.' % CHROME)
    tmp = tempfile.mkdtemp(prefix='ownhub-icon-')
    try:
        src = os.path.join(tmp, 'icon.svg')
        open(src, 'w').write(svg_text)
        shot = os.path.join(tmp, 'shot.png')
        subprocess.run(
            [CHROME, '--headless', '--disable-gpu', '--no-sandbox',
             '--hide-scrollbars', '--force-device-scale-factor=1',
             '--default-background-color=00000000',
             '--screenshot=' + shot, '--window-size=%d,%d' % (size, size), src],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        shutil.move(shot, out)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print('  %s  %d x %d' % (os.path.relpath(out, APP), size, size))


def png_size(path):
    """Width of a PNG, from its IHDR. Saves depending on an image library."""
    with open(path, 'rb') as fh:
        head = fh.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        raise SystemExit('not a PNG: ' + path)
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def check_inset():
    """Does the generated adaptive icon still inset the foreground by 16%?

    If it ever stops, or changes the figure, the foreground PNG is the wrong
    size and nothing else would say so: the icon would simply look too big or
    too small on an Android home screen, which is the sort of thing nobody
    notices until it is in the store.
    """
    xml = os.path.join(APP, 'android', 'app', 'src', 'main', 'res',
                       'mipmap-anydpi-v26', 'ic_launcher.xml')
    if not os.path.isfile(xml):
        return
    found = re.search(r'android:inset="([\d.]+)%"', open(xml).read())
    got = float(found.group(1)) / 100 if found else 0.0
    if abs(got - INSET) > 0.001:
        print('  WARNING: ic_launcher.xml insets the foreground by %.0f%%, not '
              '%.0f%%. Change INSET in this script and re-run, or the mark is '
              'the wrong size on Android.' % (100 * got, 100 * INSET))


def resample(ring_icon, ring_fg, ink, ground):
    """Redraw every icon flutter_launcher_icons generated, from the vector.

    The generator resizes one 1024 px bitmap down to 48 px, and a 20:1
    downsample of a hairline diagonal is a grey smear however good the filter
    is. Each file here is re-rendered from the master at its own pixel size
    instead, which is the only way the 48 px tile has the same clean edge as
    the 1024 px one. The generator still owns the file list, the XML and the
    asset catalogue; this only redraws the pixels inside them.
    """
    targets = []
    ios = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets',
                       'AppIcon.appiconset')
    if os.path.isdir(ios):
        targets += [(os.path.join(ios, f), False)
                    for f in sorted(os.listdir(ios)) if f.endswith('.png')]
    res = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
    for d in sorted(os.listdir(res)) if os.path.isdir(res) else []:
        for f, fg in (('ic_launcher.png', False),
                      ('ic_launcher_foreground.png', True)):
            path = os.path.join(res, d, f)
            if os.path.isfile(path):
                targets.append((path, fg))
    for path, fg in targets:
        w, h = png_size(path)
        if w != h:
            raise SystemExit('not square, so not ours to redraw: ' + path)
        render(compose(w, ink, None if fg else ground,
                       ring_fg if fg else ring_icon), w, path)
    print('  redrew %d generated icons from the vector' % len(targets))


# The in-app logo on C01: the app tile, drawn at the size it is shown, once per
# device pixel ratio Flutter picks assets for. Rendering each density from the
# vector keeps it sharp at 3x without shipping a 1024 px bitmap to scale down.
LOGO = os.path.join(APP, 'assets', 'brand', 'logo')
LOGO_DP = 88
LOGO_RATIOS = (1, 2, 3)


def render_logo(ink, ground, ring):
    for ratio in LOGO_RATIOS:
        folder = LOGO if ratio == 1 else os.path.join(LOGO, '%d.0x' % ratio)
        os.makedirs(folder, exist_ok=True)
        px = LOGO_DP * ratio
        render(compose(px, ink, ground, ring), px,
               os.path.join(folder, 'ownhub-tile.png'))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--size', type=int, default=1024)
    p.add_argument('--resample', action='store_true',
                   help='also redraw what flutter_launcher_icons generated')
    p.add_argument('--logo', action='store_true',
                   help='write only the in-app logo, at 1x, 2x and 3x')
    # The app icon: the ring a little over half the tile, which puts the blade
    # tips about 14% in from the top and bottom edges.
    p.add_argument('--ring', type=float, default=0.56)
    p.add_argument('--ink', default=PAPER)
    p.add_argument('--ground', default=ROSE)
    args = p.parse_args()

    print('rendering from', os.path.relpath(MASTER, APP))
    if args.logo:
        render_logo(args.ink, args.ground, args.ring)
        return
    os.makedirs(ICONS, exist_ok=True)
    render(compose(args.size, args.ink, args.ground, args.ring),
           args.size, os.path.join(ICONS, 'icon-1024.png'))

    # Android adaptive. The layer is 108 dp and a round mask can clip
    # everything outside the centre 66 dp, which is 61.1% of it: the mark's
    # furthest points are the blade tips, so the TIPS are what has to land
    # inside that circle.
    #
    # The sizing is not just that fraction, because flutter_launcher_icons
    # does not use this PNG as the layer. It writes
    # mipmap-anydpi-v26/ic_launcher.xml with the foreground wrapped in
    # `<inset android:inset="16%">`, so what reaches the layer is this image
    # shrunk to the middle 68% of it. Sizing for the safe circle here and
    # letting the inset shrink it again would put the mark at 40% of the tile,
    # a small mark in a big empty circle. So this divides the inset back out,
    # and the arithmetic below is the whole reason the number looks large.
    on_layer = 0.60                    # where the tips should end up (< 0.611)
    tips_here = on_layer / (1 - 2 * INSET)
    ring_fg = tips_here * RING / TIP
    render(compose(args.size, args.ink, None, ring_fg),
           args.size, os.path.join(ICONS, 'icon-foreground.png'))
    print('  foreground: tips at %.1f%% of this PNG, which the generator\'s '
          '%.0f%% inset puts at %.1f%% of the 108 dp layer (safe circle 61.1%%)'
          % (100 * tips_here, 100 * INSET, 100 * on_layer))

    check_inset()
    if args.resample:
        resample(args.ring, ring_fg, args.ink, args.ground)


if __name__ == '__main__':
    main()
