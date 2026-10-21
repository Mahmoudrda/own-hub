#!/usr/bin/env python3
"""Paint a meal illustration for every food and recipe.

Needs Pillow, so use the tool venv (the standard library has no image codecs):

    python3 -m venv tool/.venv && tool/.venv/bin/pip install pillow
    OWNHUB_IMAGE_KEY=... OWNHUB_IMAGE_ENDPOINT=https://.../gen \\
        tool/.venv/bin/python -I tool/generate_meal_images.py

Reads `assets/content/foods_eg.json`, `assets/content/rahma_recipes.json` and
`tool/meal_image_prompts.json` (a plain description and a vessel per id). Each
prompt is the same locked style sentence around that description, sent to the
image service (FLUX schnell). The 1024 px JPEG that comes back is cut out from
its white ground, trimmed, squared and written as three WebP sizes:

  <out>/<id>.webp          200 px
  <out>/2.0x/<id>.webp     400 px
  <out>/3.0x/<id>.webp     600 px

`<out>/manifest.json` records the prompt hash of every finished id, so a rerun
skips what is done and picks up after a stop. Options:

  --ids a,b        only these ids
  --limit N        at most N of the selected ids
  --out DIR        default build/meal_images_staging (the install script copies
                   finished pictures into assets/art/meals)
  --check          no network. With --out: list ids missing files or a manifest
                   entry. Without: check the pictures installed in the app,
                   exit 1 if an installed id is incomplete or corrupt, exit 0
                   (printing "N of M installed") when only ids not yet painted
                   are missing
  --strict         with --check on the installed pictures: exit 1 too when any
                   id has no picture yet
  --reroll a,b     paint these again as the next variant

Exit codes: 0 done, 1 something failed or is missing, 3 the daily allowance of
the image service ran out (run it again tomorrow, it resumes).
"""
import argparse
import datetime
import hashlib
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
CONTENT = os.path.join(APP, 'assets', 'content')
FOODS = os.path.join(CONTENT, 'foods_eg.json')
RECIPES = os.path.join(CONTENT, 'rahma_recipes.json')
PROMPTS = os.path.join(HERE, 'meal_image_prompts.json')
INSTALLED = os.path.join(APP, 'assets', 'art', 'meals')
DEFAULT_OUT = os.path.join(APP, 'build', 'meal_images_staging')

SOURCE = 'flux-1-schnell via Cloudflare Workers AI'
STEPS = 8
PAUSE = 1.5
TRIES = 4
WHITE = 248
MARGIN = 0.06
SIZES = (('1x', 200, ''), ('2x', 400, '2.0x'), ('3x', 600, '3.0x'))

STYLE = (
    'Hand-painted watercolour and soft gouache food illustration, '
    'three-quarter top-down view, of {description}, {vessel}, '
    'warm natural colours, visible watercolour paper texture and loose brush '
    'edges, a single dish fully inside the frame with empty white space around '
    'it, isolated on a pure plain white background, nothing else in frame, '
    'no side dishes, no fork, no knife, no spoon, no text, no labels, no table, '
    'no shadow'
)
VESSELS = {
    'bowl': 'served in a simple warm cream ceramic bowl with a thin brown rim line',
    'plate': 'served on a simple warm cream ceramic plate with a thin brown rim line',
    'glass': 'served in a glass',
    'cup': 'served in a small cup',
    'none': 'shown on its own',
}
EXHAUSTED = ('allowance', 'neurons', 'exhausted', 'quota', 'daily limit')


class Exhausted(Exception):
    pass


def load_json(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def all_ids():
    foods = [food['id'] for food in load_json(FOODS)['foods']]
    recipes = [r['recipeId'] for r in load_json(RECIPES)['recipes']]
    # Recipes first: their pictures are the large ones on E05 and E06.
    return recipes + foods


def build_prompt(entry, variant):
    prompt = STYLE.format(
        description=entry['description'],
        vessel=VESSELS[entry.get('vessel', 'none')],
    )
    if variant > 0:
        prompt += ', painting variation %d' % variant
    return prompt


def prompt_hash(prompt):
    return hashlib.sha256(prompt.encode('utf-8')).hexdigest()


def file_path(out, tag, item):
    folder = dict((t, d) for t, _, d in SIZES)[tag]
    return os.path.join(out, folder, item + '.webp')


def has_files(out, item):
    return all(os.path.isfile(file_path(out, tag, item)) for tag, _, _ in SIZES)


def read_manifest(out):
    path = os.path.join(out, 'manifest.json')
    if not os.path.isfile(path):
        return {}
    return load_json(path)


def write_manifest(out, manifest):
    path = os.path.join(out, 'manifest.json')
    temp = path + '.tmp'
    with open(temp, 'w', encoding='utf-8') as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write('\n')
    os.replace(temp, path)


def check(out, ids):
    manifest = read_manifest(out)
    prompts = load_json(PROMPTS)
    missing = []
    for item in ids:
        problems = []
        if item not in prompts:
            problems.append('no prompt')
        if item not in manifest:
            problems.append('no manifest entry')
        for tag, _, _ in SIZES:
            if not os.path.isfile(file_path(out, tag, item)):
                problems.append('no ' + tag)
        if problems:
            missing.append('%s: %s' % (item, ', '.join(problems)))
    if missing:
        print('%d of %d missing' % (len(missing), len(ids)))
        print('\n'.join(missing))
        return 1
    print('all %d present' % len(ids))
    return 0


def corrupt(path):
    """Why the file is not a whole WebP, or None. Reads the RIFF header only:
    a stop in the middle of a copy leaves a file that is short of its length."""
    size = os.path.getsize(path)
    with open(path, 'rb') as handle:
        head = handle.read(12)
    if size < 12 or head[:4] != b'RIFF' or head[8:12] != b'WEBP':
        return 'not a WebP'
    if int.from_bytes(head[4:8], 'little') + 8 != size:
        return 'cut short'
    return None


def check_installed(strict=False):
    """Exit 1 when an installed id is incomplete or corrupt (a file missing or
    not a whole WebP, or no manifest.json entry). Ids not yet painted only
    count when [strict]."""
    foods = set(f['id'] for f in load_json(FOODS)['foods'])
    recipes = set(r['recipeId'] for r in load_json(RECIPES)['recipes'])
    with open(os.path.join(INSTALLED, 'index.json'), encoding='utf-8') as handle:
        listed = json.load(handle)
    manifest_path = os.path.join(INSTALLED, 'manifest.json')
    kept = load_json(manifest_path) if os.path.isfile(manifest_path) else None
    problems = []
    for row in listed:
        item, kind = row['id'], row['kind']
        if item not in (foods if kind == 'food' else recipes):
            problems.append('%s: listed as a %s and is not one' % (item, kind))
            continue
        if kept is None or item not in kept:
            problems.append('%s: no manifest.json entry' % item)
        tags = ('1x',) if kind == 'food' else tuple(t for t, _, _ in SIZES)
        for tag in tags:
            path = file_path(INSTALLED, tag, item)
            if not os.path.isfile(path):
                problems.append('%s: no %s' % (item, tag))
                continue
            why = corrupt(path)
            if why:
                problems.append('%s: %s is %s' % (item, tag, why))
    total = len(foods) + len(recipes)
    broken = len(set(p.split(':')[0] for p in problems))
    done = len(listed) - broken
    left = sorted((foods | recipes) - set(row['id'] for row in listed))
    print('%d of %d installed, %d missing' % (done, total, len(left)))
    if left:
        print('not yet painted: ' + ', '.join(left))
    if problems:
        print('\n'.join(problems))
        return 1
    if strict and left:
        print('strict: %d ids have no picture' % len(left))
        return 1
    return 0


def request_image(prompt, endpoint, key):
    body = json.dumps({'prompt': prompt, 'steps': STEPS}).encode('utf-8')
    headers = {
        'x-key': key,
        'content-type': 'application/json',
        'user-agent': 'ownhub-meal-images/1',
    }
    last = 'no attempt'
    for attempt in range(TRIES):
        if attempt:
            time.sleep(2 ** attempt)
        req = urllib.request.Request(
            endpoint, data=body, headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=90) as response:
                data = response.read()
            return data
        except urllib.error.HTTPError as error:
            text = error.read().decode('utf-8', 'replace')[:300]
            if error.code == 429 or any(w in text.lower() for w in EXHAUSTED):
                raise Exhausted(text)
            if error.code < 500:
                raise RuntimeError('HTTP %d: %s' % (error.code, text))
            last = 'HTTP %d: %s' % (error.code, text)
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last = 'network: %s' % error
    raise RuntimeError(last)


def cut_out(image):
    """Make the white ground transparent, trim, square and return RGBA."""
    from PIL import Image, ImageChops, ImageDraw, ImageFilter

    rgb = image.convert('RGB')
    width, height = rgb.size
    near = rgb.point(lambda v: 255 if v >= WHITE else 0)
    r, g, b = near.split()
    mask = ImageChops.multiply(ImageChops.multiply(r, g), b)
    seeds = [
        (0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1),
        (width // 2, 0), (width // 2, height - 1),
        (0, height // 2), (width - 1, height // 2),
    ]
    for seed in seeds:
        if mask.getpixel(seed) == 255:
            ImageDraw.floodfill(mask, seed, 128)
    alpha = mask.point(lambda v: 0 if v == 128 else 255)
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(
        ImageFilter.GaussianBlur(0.8))
    rgba = rgb.convert('RGBA')
    rgba.putalpha(alpha)
    box = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if not box:
        raise RuntimeError('image is empty after cut-out')
    rgba = rgba.crop(box)
    side = max(rgba.size)
    side = int(round(side * (1 + 2 * MARGIN)))
    square = Image.new('RGBA', (side, side), (255, 255, 255, 0))
    square.paste(rgba, ((side - rgba.width) // 2, (side - rgba.height) // 2))
    return square


def save_sizes(out, item, square):
    from PIL import Image

    for tag, size, _ in SIZES:
        path = file_path(out, tag, item)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        square.resize((size, size), Image.LANCZOS).save(
            path, 'WEBP', quality=82, method=6)


def paint(out, item, entry, variant, endpoint, key, manifest):
    from PIL import Image

    prompt = build_prompt(entry, variant)
    data = request_image(prompt, endpoint, key)
    try:
        image = Image.open(io.BytesIO(data))
        image.load()
    except Exception:
        raise RuntimeError('response is not an image: %r' % data[:120])
    raw = os.path.join(out, 'raw', item + '.jpg')
    os.makedirs(os.path.dirname(raw), exist_ok=True)
    with open(raw, 'wb') as handle:
        handle.write(data)
    save_sizes(out, item, cut_out(image))
    manifest[item] = {
        'prompt_hash': prompt_hash(prompt),
        'variant': variant,
        'files': [tag for tag, _, _ in SIZES],
        'source': SOURCE,
        'generatedAt': datetime.datetime.now(datetime.timezone.utc)
        .strftime('%Y-%m-%dT%H:%M:%SZ'),
    }
    write_manifest(out, manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--ids')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--out')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--reroll')
    args = parser.parse_args()

    ids = all_ids()
    if args.strict and not args.check:
        print('--strict goes with --check', file=sys.stderr)
        return 1
    if args.check and not args.out:
        return check_installed(args.strict)
    out = os.path.abspath(args.out or DEFAULT_OUT)
    if args.check:
        return check(out, ids)

    reroll = set(args.reroll.split(',')) if args.reroll else set()
    if args.ids:
        wanted = args.ids.split(',')
    elif reroll:
        wanted = [i for i in ids if i in reroll]
    else:
        wanted = ids
    unknown = [i for i in wanted + sorted(reroll) if i not in ids]
    if unknown:
        print('unknown ids: ' + ', '.join(unknown), file=sys.stderr)
        return 1
    if args.limit is not None:
        wanted = wanted[:args.limit]

    key = os.environ.get('OWNHUB_IMAGE_KEY')
    endpoint = os.environ.get('OWNHUB_IMAGE_ENDPOINT')
    if not key or not endpoint:
        print('set OWNHUB_IMAGE_KEY and OWNHUB_IMAGE_ENDPOINT', file=sys.stderr)
        return 1

    prompts = load_json(PROMPTS)
    os.makedirs(out, exist_ok=True)
    manifest = read_manifest(out)
    made = skipped = failed = 0
    last_call = 0.0
    for index, item in enumerate(wanted):
        if item not in prompts:
            print('%s failed (no prompt)' % item)
            failed += 1
            continue
        variant = manifest.get(item, {}).get('variant', 0)
        if item in reroll:
            variant += 1
        if item not in reroll and has_files(out, item):
            print('%s skipped' % item)
            skipped += 1
            continue
        wait = PAUSE - (time.time() - last_call)
        if wait > 0:
            time.sleep(wait)
        try:
            paint(out, item, prompts[item], variant, endpoint, key, manifest)
            print('%s made' % item)
            made += 1
        except Exhausted as error:
            remaining = len(wanted) - index
            print('%s stopped (allowance used up: %s)' % (item, error))
            print('made %d, skipped %d, failed %d, remaining %d'
                  % (made, skipped, failed, remaining))
            return 3
        except Exception as error:
            print('%s failed (%s)' % (item, error))
            failed += 1
        last_call = time.time()
    print('made %d, skipped %d, failed %d' % (made, skipped, failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
