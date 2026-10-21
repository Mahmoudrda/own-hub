#!/usr/bin/env python3
"""Copy painted meal images from a staging folder into the app.

    python3 -I tool/install_meal_images.py --from STAGING_DIR

Foods ship only `<id>.webp` (200 px, enough for a 64 pt thumbnail at 3x).
Recipes ship `<id>.webp`, `2.0x/<id>.webp` and `3.0x/<id>.webp` (the 180 pt
hero needs the larger sizes). An id is installed only when every file it needs
is in the staging folder and the manifest has an entry for it.

`assets/art/meals/index.json` lists every installed id with its kind and source
line; the app reads it at start to know which images exist. `manifest.json`
beside it maps every installed id to the hash of the prompt that painted it and
the files installed for it ({id: {prompt_hash, files}}). A rerun copies only what
changed, and removes nothing it did not install.
"""
import argparse
import filecmp
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
FOODS = os.path.join(APP, 'assets', 'content', 'foods_eg.json')
RECIPES = os.path.join(APP, 'assets', 'content', 'rahma_recipes.json')
DEFAULT_OUT = os.path.join(APP, 'assets', 'art', 'meals')
FOLDERS = {'food': ('',), 'recipe': ('', '2.0x', '3.0x')}


def load_json(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def kinds():
    found = {f['id']: 'food' for f in load_json(FOODS)['foods']}
    found.update({r['recipeId']: 'recipe' for r in load_json(RECIPES)['recipes']})
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--from', dest='staging', required=True)
    parser.add_argument('--out', default=DEFAULT_OUT)
    args = parser.parse_args()

    staging = os.path.abspath(args.staging)
    out = os.path.abspath(args.out)
    manifest_path = os.path.join(staging, 'manifest.json')
    manifest = load_json(manifest_path) if os.path.isfile(manifest_path) else {}
    known = kinds()
    index_path = os.path.join(out, 'index.json')
    kept_path = os.path.join(out, 'manifest.json')
    kept = load_json(kept_path) if os.path.isfile(kept_path) else {}
    index = {}
    if os.path.isfile(index_path):
        index = {row['id']: row for row in load_json(index_path)}

    copied = 0
    for item, kind in sorted(known.items()):
        if item not in manifest:
            continue
        sources = [os.path.join(staging, f, item + '.webp') for f in FOLDERS[kind]]
        if not all(os.path.isfile(s) for s in sources):
            continue
        for folder, source in zip(FOLDERS[kind], sources):
            target = os.path.join(out, folder, item + '.webp')
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if not (os.path.isfile(target) and filecmp.cmp(source, target, False)):
                shutil.copyfile(source, target)
                copied += 1
        index[item] = {
            'id': item,
            'kind': kind,
            'source': manifest[item].get('source', ''),
        }
        kept[item] = {
            'prompt_hash': manifest[item].get('prompt_hash', ''),
            'files': [
                (folder + '/' if folder else '') + item + '.webp'
                for folder in FOLDERS[kind]
            ],
        }

    # Flutter will not bundle a folder that does not exist, and the recipe
    # sizes are empty until the first recipe is painted.
    for folder in ('2.0x', '3.0x'):
        keep = os.path.join(out, folder, '.gitkeep')
        os.makedirs(os.path.dirname(keep), exist_ok=True)
        open(keep, 'a').close()
    rows = [index[i] for i in sorted(index)]
    with open(index_path, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, indent=2, ensure_ascii=False)
        handle.write('\n')
    with open(kept_path, 'w', encoding='utf-8') as handle:
        json.dump({i: kept[i] for i in sorted(index) if i in kept}, handle,
                  indent=2, ensure_ascii=False)
        handle.write('\n')
    foods = sum(1 for r in rows if r['kind'] == 'food')
    print('installed %d (%d foods, %d recipes), copied %d files'
          % (len(rows), foods, len(rows) - foods, copied))
    return 0


if __name__ == '__main__':
    sys.exit(main())
