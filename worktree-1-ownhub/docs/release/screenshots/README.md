# Store screenshots

Captured 24 September 2026 from the first-release build (the shipped flag set),
on an iPhone 17 Pro Max simulator, which is the 6.9 inch class Apple requires.
Every one of them is the real app. Nothing is mocked up, redrawn or staged.

| Folder | Size | For |
|---|---|---|
| `apple-6.9/` | 1320 x 2868 | App Store Connect. This size covers every iPhone. |
| `play-phone/` | 1080 x 1920 | Play Console phone screenshots, plus `feature-graphic.png` at 1024 x 500. |
| `raw-device/` | 1320 x 2868 | The plain captures, no headline, if you want to lay them out yourself. |

The ten, in the order they tell the story:

1. **Home**, your whole day on one page
2. **Today's session**, fifteen minutes and five moves
3. **Mid-set**, one tap logs the set
4. **Finished**, and the week counts
5. **Eat**, log a meal in the size you serve it
6. **Grocery list**, grouped the way you shop
7. **My cycle**, you choose what to log
8. **How are you feeling**, it asks rather than guesses
9. **A gentler option**, whenever you want one
10. **Your first week**, with no timer

## What is deliberately not here

The community and the coaching side are switched off in the first release, so
they are not in the listing. Showing them would be a claim the build cannot
keep, and both stores treat that as a misrepresentation.

## Regenerating them

With a 6.9 inch simulator booted and the app installed on it:

```sh
bash capture69.sh <simulator-udid> raw-device \
  /today/t01:01-home /train/r03:02-session /train/r07:03-midset \
  /train/r10:04-finished /eat/e01:05-eat /eat/e08:06-grocery \
  /cycle/y03:07-cycle /cycle/y04:08-feeling /cycle/y06:09-choose \
  /today/t07:10-firstweek

python3 store_frames.py raw-device apple-6.9 1320 2868
python3 store_frames.py raw-device play-phone 1080 1920
python3 feature_graphic.py
```

The headlines live in `CAPTIONS` at the top of `store_frames.py`. Square
brackets mark the words set in rose, and the pen line is drawn under the last
word of each headline.
