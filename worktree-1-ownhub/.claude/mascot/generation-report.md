# Own Hub kitten mascot: generation report

Generated 6 Oct 2026, one batch, one draw per variant, every result delivered as-is (ip-as-logo skill).

## Model and settings
- Provider: Higgsfield MCP connector (owner's Plus trial, paid from credits, not unlim).
- Model: `gpt_image_2_5` (GPT Image 2.5, variant `flare`), the GPT Image 2 line the skill prefers.
- Settings: aspect 1:1, quality `high`, resolution `2k`.
- Constraint delivery mode: main-prompt constraints (the `Constraints:` line inside the prompt, no negative-prompt payload).
- Cost: 2.75 credits per image, 16.5 total. Balance 110 before, 93.5 after.
- Dimensions: every file is 2048 x 2048 PNG, native output, not resampled. (The skill asks for about 1536; 2k was the closest native size above it, 1k was too small.)

## Prompts
Each prompt is copied character for character from the matching section of `prompts.md`, with no changes.

## Results

| Label | Corner | Background | Kitten base | Accent (ears, eyes, marks) | File | Higgsfield job |
|---|---|---|---|---|---|---|
| A1 | lower-left | sage #DDEDE1 | soft rose #F2B6C6 | deep rose #A24661 | A1.png | 163c55b5-3e88-4d3a-8c92-0ef9469d92c9 |
| A2 | lower-right | sage #DDEDE1 | soft rose #F2B6C6 | deep rose #A24661 | A2.png | a25f7fdf-dd8c-4d5d-8237-44ca0506a120 |
| A3 | lower-left | blush #FBDCE4 | cream #F7E7D4 | deep rose #A24661 (with cheeks) | A3.png | 13cc5d63-adaa-447c-b14a-5307b8dbeb4f |
| A4 | lower-right | blush #FBDCE4 | cream #F7E7D4 | deep rose #A24661 (with cheeks) | A4.png | 0d85c707-cc28-44b5-bea8-e96a0bac5b3c |
| A5 | lower-left | lilac #E8D6E3 | sand #E9C9A0 (Mau) | deep plum #6E3356 (with spots) | A5.png | 0703419c-8c40-4e9b-b03b-a827e5d0b1bb |
| A6 | lower-right | lilac #E8D6E3 | sand #E9C9A0 (Mau) | deep plum #6E3356 (with spots) | A6.png | 0e9adaca-fb90-4c84-add8-7223f37961c9 |

What came back:
- A1: rose kitten, ":3" mouth, one paw raised at the lower-left edge.
- A2: rose kitten, ":3" mouth, two paw bumps at the bottom.
- A3: cream kitten, round deep-rose cheeks, ":3" mouth.
- A4: cream kitten, round deep-rose cheeks, small smile.
- A5: sand kitten, ":3" mouth, plum Mau spots on the shoulder.
- A6: sand kitten, ":3" mouth, plum Mau spots on the body.

## Style check against the app (asked for by the owner during the run)
Sources read: `app/lib/ui/hand/art_palette.dart`, `art_marks.dart`, `assets/art/LICENCE.md`, the brand mark `assets/brand/ownhub-mark.svg`, the app icon, and the store screenshots in `docs/release/launch-pack/screenshots/`.

- The app's illustrations are drawn in code. Each mark is a two-colour tone: a solid fill plus a deeper line drawn round it. Rose is #F2B6C6 fill with a #A24661 line, and everything is mixed to sit on the #FFF8F9 page.
- The brand colour is #A24661, used for the logo tile, primary buttons and links. The logo is a flat geometric ring and blade.
- The webp files still in `assets/art/` are leftovers from the removed licensed pack and are not the app's style.
- Palette fit: every kitten colour comes from ArtTones (rose, blush, cream, plum fills and lines). Sand #E9C9A0 is the only colour outside the twelve, sitting between `amber` and `cream`.
- Rose figures: in the app, rose is the tone for "her". A1 and A2 put an animal in that tone too. That is fine for a mascot, but it is a choice.
- Line: the kittens are edgeless flat shapes, while the app's marks carry a deeper hand-drawn outline. The handoff already says the chosen kitten gets rebuilt as Flutter vectors, so the rebuild should add the tone's line colour (#A24661, or #866A48 for cream, or #6E3356 for plum) as a hand stroke round the body. That gives it the same look as the other marks without spending more credits.
- Background: the backgrounds only exist in these test images. In the app the kitten sits on #FFF8F9, so the rebuild paints no backdrop.

## Owner's choice
A1 (rose kitten, lower-left, paw raised), chosen 7 Oct 2026: "the first pink ones". Owner asked for it animated and used in the app.
