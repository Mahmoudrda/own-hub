# Own Hub: calorie, macro and voice-logging audit (read-only)

Branch feat/motivation-2026-10-13 incl. uncommitted tree. Method: code and data read, plus Python checks I ran on the JSON files.
I did NOT run flutter test or pytest, and did NOT run the Dart parser on real input.
Anything marked [CODE-READ] was inferred by reading, not executed. [RAN] was executed in Python on the data.
graphify: graph exists, but its query returned only test-file noise, so I went to source.

## 0. Headline

- Voice logging does not exist in the shipped app. `SayItView._listen()` only calls `SayItViewModel.refuse()`.
  - No speech package in `app/pubspec.yaml`.
  - No `NSMicrophoneUsageDescription` or `NSSpeechRecognitionUsageDescription` in `app/ios/Runner/Info.plist` (grep empty).
  - `RECORD_AUDIO` is removed on purpose in `AndroidManifest.xml:30`.
  - The screen is reachable (route `E03` in `app_router.dart:3402`) and the transcript is null by design (`say_it_view.dart:93-97`).
  - What does exist and is tested: the state machine plus the shared sentence parser (typed and spoken text go through one parser).
- Barcode: no code, no dependency (grep of `app/lib` and `pubspec`).
- Photo scan: server and client exist and are tested with mocks. I could not verify the live 403 state.

## 1. Food databases

### 1.1 What there is

| File | Count | Role |
|---|---|---|
| `app/assets/content/foods_eg.json` | 251 foods | Client pack, built by `app/tool/build_food_pack.py` |
| `functions/nutrition/usda_foods.json` | (not counted) | USDA FDC SR Legacy/Foundation subset, CC0 |
| `functions/nutrition/egyptian_dishes.json` | dishes (≥150 per test) | Standard recipes summed from USDA, built by `build_dishes.py` |
| `app/assets/content/rahma_recipes.json` | 50 recipes | Book recipes, `macroBasis` = "computed" for all 50 |
| `app/lib/features/eat/presentation/eat_sample_library.dart` | few hand-made foods | Stand-in foods with count sizes ('1','2','3'), allergens null |

### 1.2 Source and review status

- Source for everything is USDA FoodData Central only. No Egyptian or regional composition table is used.
- The file's own `review` text says: "estimated from a standard recipe, pending dietitian review". Allergens are also "pending dietitian review".
- Basis tags per size [RAN]: estimated 505, usda 242, untagged 10.
  - So about two thirds of all portion weights are reference guesses, not USDA household weights.
- Every food lists at least one fdcId, but fdcIds are ingredient ids for dishes, not the dish itself.
- Notes show substitutions: basmati is "counted as cooked long-grain white rice"; laban rayeb is buttermilk because USDA has no entry; turkey deli carries starch.

### 1.3 Units and portions

- `per100g` is per 100 g "as served" (cooked, for dishes).
- Each food has sizes S/M/L with grams, kcal, protein, carbs, fat, fibre and a label. S/M/L factors are 0.6/1.0/1.5.
- Size kcal agrees with per100g × grams within 2% for all 251 foods [RAN] (0 deviations).
- Size macros are rounded integers. Totals are sums of rounded integers times servings (`ParsedItem` in `meal_sentence_parser.dart`).
  - Rounding drift grows with servings. Example: 0.5 g rounded up on each of 5 servings is 2.5 g.
- Weight path: `FoodUnits` (`units.dart`): g, oz (28.35), ml (= g for drinks and soups), cup (240 ml for liquids; fixed grams by kind for solids: main 200, breakfast 180, side 150, salad 100, sweet 150, cheese 110), piece = serving = M size.
  - Cup grams for solids is a single number per kind, so a cup of rice and a cup of koshary are treated the same. The code says "approximate".
  - Max portion 9999 g (`kMaxPortionGrams`).
  - A size id `g150` scales from the weighed size linearly (`Food.sizeForGrams`).

### 1.4 Cooked vs raw

- Raw and cooked are separate foods (`chicken_breast_raw` 120 kcal/100 g vs `chicken_breast_grilled` 165; `lentils_dry` 352; `pasta_dry` 371; `potato_raw` 77).
- Trap: the alias list decides which one she gets.
  - `lentils_dry` has aliases `ads` and `عدس`, the everyday word for cooked lentils.
  - `potato_raw` has the alias `بطاطس`.
  - Saying or typing only "عدس" or "بطاطس" can log the raw weight, with M = 48 g dry lentils (169 kcal), where she probably ate a cooked bowl. [CODE-READ + data; resolver not run on these]
  - Same for "chicken breast": the grilled food owns that alias, the raw one needs "raw chicken breast". That one is fine.
- No `popularity` is set in the pack (`egyptian_food_pack.dart` builds no popularity field). All pack foods tie at 0, so ties go by file order, and the tie-break test only uses fixture foods.

### 1.5 Egyptian foods

- 75 foods in category `egyptianDishes`, plus cheese, ful, taameya, baladi bread etc.
- `kind` is missing on 64 foods. `FoodUnits` only offers cups for kinds in its map, so those foods get no cup unit.
- Known high-variance dishes: koshary M = 441 g, 588 kcal; taameya M = "4 pieces" 97 g; ful M = 211 g; baladi bread M = 90 g, 236 kcal. All "estimated", none checked against an Egyptian table by me.
- Frying oil absorption and ghee/oil variation are baked into a single standard recipe per dish.

### 1.6 Atwater (4/4/9 vs listed kcal)

- Build gate: `app/tool/build_food_pack.py:402` allows |computed − listed| ≤ max(20, 15% of kcal). The server uses the same rule for community foods (`community_foods.py:107`).
- Exceptions are named for kharoub, cocoa and similar (fibre counted below 4 kcal/g).
- I ran a plain 15% check on per100g [RAN]: 15 foods exceed it. All are spices/ingredients or low-kcal vegetables, which the 20 kcal floor passes:
  - dora_mashwi, kharoub, gargeer, broccoli_steamed, green_beans_plain, cocoa_powder (+90%), bell_pepper_red, spinach_raw, tomato_sauce, spices_and_seasoning, curry_powder, zaatar_mix, spice_blend_store, baking_powder (+109%), lemon_juice.
  - Cause: `carbsG` is total carbohydrate including fibre. USDA energy uses specific factors. The check does not subtract fibre, so it is loose.
- Per-size Atwater (>20% off, kcal > 50): kharoub S/M/L, broccoli_steamed M, zucchini_cooked L, green_beans_plain L [RAN].
- Rahma recipes [RAN]: 1 of 50 outside 15% (`rahma_cookies_shay_blabn`: 117 kcal listed vs 144 computed).
- Duplicates [RAN]: no duplicate ids, no alias or name shared between two foods. Duplicate-ish pairs exist by design (raw and cooked, egg_whole vs eggs_boiled vs egg_fried_olive).
- Missing values [RAN]: no missing fibre; zero-kcal foods are karkadeh_unsweetened, salt, water. 10 sizes have no basis tag.

### 1.7 Server side (`functions/nutrition`)

- Photo path: Gemini names foods and grams only. Macros come from `egyptian_dishes.json`, then `usda_foods.json`, never from the model (README).
- Model `gemini-3.5-flash` low thinking, region europe-west3, 5 scans per woman per day, 300 per day app-wide, exact-photo cache 30 days.
- `build_dishes.py` has a `--check` mode for stale output, and a `yield_` factor for dishes that lose water.

## 2. Calorie targets and macro splits (`daily_targets.dart`)

- BMR: Mifflin-St Jeor female, `10w + 6.25h − 5a − 161`. Defaults when body data is missing: 60 kg, 160 cm, age 30 (`usesDefaults` flag).
- Activity factor from weekly training minutes: <60 → 1.2, <150 → 1.375, <300 → 1.55, else 1.725.
- Goal multiplier: loseSteadily ×0.85; stronger and buildMuscle ×1.05; feelBetter and backIntoIt ×1.0.
- Protein per kg: 1.6 default; 1.8 stronger; 1.9 buildMuscle. Fat = 28% of kcal. Carbs = remainder, clamped at 0. Fibre = fixed 25 g.
- NOT present [CODE-READ, grep of `daily_targets.dart` and `eat_state.dart:targets()`]:
  - No kcal floor or ceiling anywhere. Example (my arithmetic, not run in Dart): 40 kg, 140 cm, age 60, loseSteadily, sedentary → about 830 kcal. 45 kg, 150 cm, age 50 → about 996 kcal.
  - No pregnancy, breastfeeding, postpartum or cycle adjustment. `targets()` passes only body, goal, days and minutes.
  - Life stage exists in `domain/safety/life_stage_safety_policy.dart` (pregnant, p0_6w, p6w_1y) but is not read by the targets.
  - The `loseSteadily` ×0.85 applies to pregnant or breastfeeding users too if they chose that goal.
  - No age floor (age under 18 or under 15 would still get a deficit); no protein cap for very high weights.
  - No BMI or minimum-weight check.
- Screen copy says the figures are "an estimate to aim at, never a limit", and nothing counts down (file header). That reduces harm, but the number still shows.
- Tests: `app/test/features/eat/daily_targets_test.dart`, 7 tests: defaults, two worked examples, partial data, activity bands, protein per kg, build muscle. No test for extremes, floors or life stage, because there is no such logic.

## 3. Logging paths

| Path | Where | State |
|---|---|---|
| Search / type-it | `type_it_view.dart`, `type_it_view_model.dart`, `MealSentenceParser`, `FoodLibrary.resolve` | Works; sentence parser is the core |
| Recents / frequent | E02 "Recent, Frequent" (`eat_hub_view.dart` header) | Exists; covered by eat_hub, quick_log, plate_rollup tests (not opened by me) |
| Repeat plate | `plate_rollup.dart` | Exists; 18 tests in `plate_rollup_test.dart` |
| Quick custom food | `quick_custom_sheet.dart`, `custom_food.dart` | Exists |
| Community foods | `community_foods.dart` + `functions/nutrition/community_foods.py` | Exists; Atwater-checked server side |
| Photo scan | `meal_photo_view.dart`, `meal_scan.dart`, `functions/nutrition/photo.py` | Built; live call blocked (Google 403, per task statement; NOT verified by me) |
| Barcode | none | Not present |
| Voice | `say_it_view.dart`, `say_it_view_model.dart` | Shell only, always "refused", routes to type-it |

### 3.1 Sentence parser behaviour [CODE-READ, `meal_sentence_parser.dart`]

- Exact whole-sentence match first, so "molokhia with chicken" stays one dish.
- Split on `,`, `،`, `+`, and whitespace-bounded `and`, `with`, `و`, `مع`. Arabic `و` attached to the next word ("وعيش", no space) does NOT split.
- Quantity: leading Western or Arabic-Indic digits, or a spelled word from a tiny list: a, an, one, two, three, واحد, واحدة, اثنين, بيضتين, ثلاثة, ثلاث.
- Missing from the word list: four and above, Egyptian "اتنين", "تلاتة", "اربعة", half and quarter ("نص", "نصف", "ربع"), "كام", "حبة", "رغيف", "طبق", "معلقة", "كوباية".
  - Units in speech ("200 جرام رز", "كوب لبن", "2 spoons") are not parsed. The number is taken as a count and "جرام رز" becomes the lookup text.
- Count handling: a number selects a size only if the food has a size with that id.
  - The sample library has size ids '1','2','3' for boiled eggs. "2 eggs" → the '2' size, servings 1.
  - "4 eggs" has no '4' size → default size ('2') × 4 servings = 8 eggs. Likely a real bug [CODE-READ, not run]. Same for any count above 3.
  - Pack foods use S/M/L ids, so "2 aish baladi" = 2 × M (90 g loaf) is right, but "2 eggs" against `egg_whole` (M labelled "2 eggs", 100 g) would be 2 × M = 4 eggs. Which food wins depends on library order and `_covered` in `egyptian_food_pack.dart` (boiled eggs excluded from the pack so the sample food serves). The "egg" alias belongs to `egg_whole` (raw egg per 100 g, M = 100 g labelled "2 eggs"). Unverified which one "egg" hits on a real device.
- No upper bound on the quantity. "500 eggs" gives servings = 500. `kMaxPortionGrams` applies only to the grams route.
- Unresolved fragments become chips, never a guessed food (good design, tested with fixtures).
- Only the first match is used (`matches.first`), and there is no confidence score, no "did you mean". Ambiguity (cooked vs raw, 3 chicken foods) is resolved silently by order.
- Matching: case-insensitive, strips harakat; "hay contains needle or needle contains hay" substring either way. That means a short word like "رز" can sit inside longer names, and "ads" inside other words. Long phrases are preferred but I did not run it. `functions` has a test for short alias vs longer name (`test_a_short_alias_never_matches_inside_a_longer_name`), the Dart side has no equivalent.
- Dialect: only through aliases (e.g. beid, bayda in Franco-Arab; sadr frakh mashwi). Cross-locale matching: the pack carries both ar and en names, so Arabic input works in an English UI. The sample library header says otherwise (that is for the stand-in only).

### 3.2 Voice (when it is built)

- Design intent (`say_it_view_model.dart`): transcript must be shown before anything is saved (P0-LOG-08), enforced by `canLog`. Locale `ar-EG`. Tier 1 is on-device only; cloud STT is blocked on a vendor, a PDPL agreement, consent copy and a data-location decision (G5 §9 Q4).
- If shipped, on-device Egyptian Arabic is weak on iOS and Android. Recogniser quality for ar-EG food words (كشري، طعمية، فول) is unmeasured.
- Permission work still needed: iOS mic + speech usage strings, Android RECORD_AUDIO (currently removed), Play data-safety form, App Store privacy answers, consent screen.

## 4. Existing tests (counts from `grep` of `test(` / `def test_`)

Dart, `app/test/features/eat/`: meal_sentence_parser 24, units 14, say_it_view_model 14, say_it_view 12, type_it_view 10, type_it_view_model 14, daily_targets 7, day_totals 11, plate_rollup 18, meal_log_service 15, meal_repository 12, offline_logging 7, quick_log 10, meal_scan 9, meal_photo_view 14, meal_photo_logging 11, snap_meal_entry 5, community_foods 13, allergy_guard 19, meal_check 19, recipe_nutrition 24, rahma_seed 40, foods_reachable 5, typed_macros 1, eat_more_macros 12, home_eat_macros 5 (today/), eat_budget 1.
Python: `test_nutrition.py` 38, `test_meal_photo.py` 49, `test_community_foods.py` 22.

What those do cover [from test names, not run]:
- Sentence parser with fixture foods (koshari, eggs, molokhia): split, Arabic waw and comma, harakat, Arabic digits, dual, resize, remove, ties.
- Unit conversions: oz, ml, cup, linear scaling of 100 g of 200 g portion, id round trip.
- `recipe_nutrition_test` re-adds ingredients and compares with `recipe.kcal` (rounding).
- Python: dish equals sum of ingredients; every dish in sane energy range; alias lookup; no name points to two dishes; scale to grams; Atwater tolerance for community foods; photo schema refuses invented numbers; EXIF strip; Vertex config.
- Build-time: Atwater gate in `build_food_pack.py`, `build_dishes.py --check`.

What is NOT covered (gaps):
1. The parser has never been tested against the real `foods_eg.json` pack. Tests use 3 hand-built foods. Real aliases, ties and raw/cooked collisions are unexercised.
2. Counts above 3 and unit words in speech (see 3.1). No numeric cap test.
3. No golden table against an independent source; the only reference is USDA through the build.
4. No property tests (macro sum, linearity across all 251 foods, round trips).
5. Daily targets: no extremes, no floor, no pregnancy, postpartum, breastfeeding, cycle or minor tests, because the logic is absent.
6. No test that raw-vs-cooked everyday words ("عدس", "بطاطس", "رز", "فراخ") map to the cooked form.
7. No real recogniser test; no on-device mic/permission test.
8. Photo: all tests use mocks. No accuracy evaluation of Gemini output vs gram truth; live 403 unresolved.
9. Rounding drift across large servings or many items in a day.
10. The 10 untagged-basis sizes and 505 "estimated" sizes have no sample weighing.

## 5. Test plan for a production release

### 5.1 Golden tables (independent source)

Reference sources to cross-check (I did not open them; names only):
- USDA FoodData Central, SR Legacy and Foundation (the pack's own source, so it only checks transcription).
- INFOODS / FAO West Asia food composition table (WAFCT 2020), for regional dishes and breads.
- Egyptian National Nutrition Institute food composition tables (Cairo), for koshary, ful, taameya, baladi bread, molokhia.
- McCance and Widdowson's Composition of Foods (UK), as a second check on raw and cooked meats, dairy, bread.
- Product labels for Egyptian packaged items (Juhayna, Domty, Lamar) for dairy and cheese.
- Bake and weigh 5 dishes in Rahma's kitchen on a scale for the top "estimated" items.

Cases (≥60 foods; tolerance in parentheses):
1. Top 40 Egyptian items by real use: koshary, ful medames, taameya, aish baladi, aish fino, white rice, molokhia, fattah, mahshi, hawawshi, shawarma, grilled chicken, fried chicken, kofta, liver, fish, fried egg, boiled egg, omelette, domiati cheese, labneh, yoghurt, laban rayeb, dates, tea with sugar, juice, basbousa, kunafa, um ali, macaroni bechamel.
2. 10 raw/cooked pairs (rice, lentils, pasta, chicken, beef, potato, oats, beans, fish, spinach): kcal per 100 g must differ in the expected direction and ratio.
3. 10 packaged items against label values (±5% kcal).
- Pass rule: kcal within ±15% of the independent source for single foods, ±25% for composite dishes; protein, carbs, fat within ±20% or ±3 g.
- Output: a CSV of food, our value, reference value, source, diff. Dietitian signs it (the file says "pending dietitian review").

### 5.2 Property tests (run on all 251 foods + 50 recipes + all dishes)

- `4p + 4c + 9f` within max(20, 15% kcal) of listed kcal; stricter pass using carbs minus fibre within 10% for foods over 100 kcal.
- Size kcal equals per100g × grams within 2% (already true now; make it a CI test).
- S < M < L in grams and kcal; ratios 0.6 / 1.0 / 1.5 or documented exception.
- Linearity: `sizeForGrams(2g)` is exactly twice `sizeForGrams(g)` within rounding for random g in 1..9999.
- Unit round trip: g → oz → g within 0.1 g; ml → cup → ml; `sizeIdForGrams` then `gramsOfSizeId` identity.
- Servings: n × item equals sum of n copies (integer). Day total equals sum of meals.
- Non-negative everywhere; kcal 0 only for water, salt, unsweetened tea.
- No duplicate ids or aliases across foods; every alias normalises to non-empty; alias does not equal a different food's name.
- Every food has `kind` or an explicit "no kind" allowlist; every food with grams gets a unit list.
- Server: dish file is up to date (`--check`), every fdcId exists in `usda_foods.json`.

### 5.3 Targets

- Worked table of 20 profiles with hand-computed Mifflin values (ages 18 to 70, 40 to 120 kg, all 5 goals, all activity bands); compare in Dart.
- Floor tests (need a product decision first): minimum kcal (commonly 1,200 for adult women), no deficit under 18, no deficit while pregnant or breastfeeding, extra kcal in lactation and 2nd/3rd trimester per national or WHO guidance, cycle: none unless owner decides. Fail today; this is the decision list for Rahma and a dietitian.
- Protein cap per kg and carbs ≥ 0 and fat share check at extremes.

### 5.4 Voice and typed-sentence corpus (≥60 phrases)

Run each through `MealSentenceParser` against the REAL pack (load `foods_eg.json`), in an `en` and an `ar` locale. Expected output given as foodId, size/servings, unresolved list. Groups:

English (15):
1. "two eggs and a piece of bread" → egg ×2 (2 eggs, NOT 4), aish baladi or toast ×1.
2. "2 eggs" / "4 eggs" / "6 eggs" (counts above 3 must be 4, 6, not 8, 12).
3. "koshari" / "a koshari" / "koshary and a salad".
4. "grilled chicken with rice".
5. "half a chicken breast" (half unsupported; expect chip, not a guess).
6. "200 g rice" / "200 grams of rice" (grams route expected; today a wrong count).
7. "a cup of milk" / "a glass of juice" / "tea with sugar and milk".
8. "three dates", "a banana and an apple", "one orange".
9. "ful and taameya and eggs".
10. "I had cereal and stuff" (partial: chip for "stuff").
11. "ads" (lentils, must be cooked) and "lentils".
12. "potato" (must be cooked if no word raw).

Arabic MSA and Egyptian (30):
13. "بيضتين وعيش" → egg ×2, aish ×1.
14. "اتنين بيض" (اتنين is missing today).
15. "تلات بيضات", "أربع بيضات", "خمس حبات".
16. "نص رغيف عيش", "ربع كيلو لحمة" (unsupported; chip).
17. "طبق كشري", "كشري كبير", "كشري صغير".
18. "فول وطعمية وسلطة", "فول بالزيت", "ساندوتش فول".
19. "ملوخية بالفراخ", "ملوخية مع أرز", "رز وفراخ مشوية".
20. "كوباية شاي بلبن", "كوباية عصير مانجو", "كوب لبن".
21. "٣ بيضات" and "٢ عيش" (Arabic-Indic digits); "3 بيضات" (Western); "ثلاثة عيش".
22. Diacritics: "كُشَرِي", "فُول".
23. Variant spellings: "كشرى", "كشري", "أرز", "ارز", "رز".
24. Dialect food words: "عيش بلدي", "عيش فينو", "جبنة رومي", "جبنة دومياطي", "لبنة", "حواوشي", "كفتة", "ممبار", "فتة", "محشي كرنب", "بطاطس محمرة", "بطاطس مسلوقة".
25. "وعيش" attached waw and "و عيش" spaced (attached form should still split or be a chip).
26. Mixed script: "2 eggs و عيش".
27. Franco: "2 beid w 3eesh", "koshari w roz".
28. Meal words: "فطار: فول", "غدا رز وفراخ" (meal slot words must not become foods).

Edge and error cases (15):
29. Empty, spaces only, "."
30. Noise: "mmm", "اه", "أه كده", "uh, um".
31. Unknown food: "sushi", "pad thai", "سوشي".
32. Huge numbers: "999 eggs", "١٠٠٠٠ عيش", "1e9 rice", negative "-3 eggs", "0 eggs", decimal "2.5 eggs" or "٢,٥".
33. Very long input (10 kB), emoji, RTL marks and zero-width joiners, tatweel "كـشـري".
34. Number only: "3", "٣".
35. Repeated food: "2 eggs and 2 eggs" (merge or two rows; document).
36. Allergy: phrase containing a food her allergy guard refuses → the allergen warning must show (AllergyGuard integration test).
37. Ambiguity: "chicken", "عدس", "رز", "جبنة", "عصير" → expect a pick list or the cooked form, not silent first-match.
- Every phrase has a fixture row: phrase, locale, expected foodIds, expected servings or size, expected kcal. Failures are listed with file:line by the subagent per the global rules.
- Accuracy target for release (suggested): ≥ 90% correct on the 60-phrase typed corpus; 100% with zero silent wrong-food on edge cases (an unresolved chip is acceptable, a wrong log is not).
- Speech corpus (only if voice ships): record 20 Egyptian women on 3 phones in quiet and kitchen noise, 5 phrases each; measure word error rate on food words and end-to-end correct-log rate. Gate: ≥ 85% end-to-end after the confirmation screen, 0 saves without the transcript shown.

### 5.5 Offline

- Airplane mode on a real phone: pack loads from bundle (`rootBundle`), parse works, log saves locally, syncs on reconnect (`offline_logging_test.dart` exists, 7 tests). Add: first launch offline; pack load failure (`_load` swallows errors with `catch (_) {}`, so a failed asset load shows an empty library with no error shown. Add a test).
- Photo scan offline: refusal message, no spinner; scan quota refunded on Vertex outage (server test exists).

### 5.6 On-device checks

iOS (real iPhone, per owner note the simulator cannot run the app: ML Kit has no arm64 sim slice):
- Egyptian Arabic keyboard dictation into the type-it box as a stand-in for voice; check numbers and "و" splitting.
- RTL layout of the parsed card; Dynamic Type large; VoiceOver reads kcal.
- Permissions: camera for photo scan; if voice ships, mic + speech prompts and denial path.
- Photo consent screen; scan with a koshary photo, a salad, an empty plate, a non-food image, a screenshot.
Android (`ownhub_pixel8` emulator plus one low-end real phone):
- Same corpus via Gboard Arabic (Egypt) dictation.
- `RECORD_AUDIO` is stripped now; if voice ships, the manifest, the Play data-safety form and runtime permission must change together.
- Low-RAM phone: pack parse time with 251 foods (decode runs on the main isolate, `jsonDecode`).
- 4 small-phone sizes in EN/AR (already done per handoff for 98 screens; repeat for the parsed card and unit picker).

### 5.7 Release gates (suggested)

1. Dietitian signs the golden CSV and the ~505 "estimated" size weights for the top 60 foods.
2. Fix or accept each item in the risks list (below).
3. Parser corpus ≥ 90% typed, 0 wrong silent logs.
4. Targets: floor and life-stage policy decided and tested.
5. Photo: live scan works on 20 real meals; mean absolute kcal error reported; user always edits grams before logging (already in design).
6. Voice: either hidden behind a flag until tier 1 passes the speech corpus, or the Say-it entry removed from release 1. Check that no copy promises voice logging.

## 6. Unverified items

- Whether the 403 from Google still blocks photo scans, and what the policy is.
- Whether E03 (Say it) is visible in the shipped navigation (route exists; I did not trace entry points).
- Which food "egg" and "2 eggs" resolve to on a real device (depends on library composition).
- Behaviour of `FoodLibrary.resolve` on real pack names (reading only; I did not run Dart).
- Whether `food_pack_singles.json` and `build_food_pack.py` outputs match `foods_eg.json` (I did not run the build check).
- Contents of `usda_foods.json` (size, version of SR Legacy).
- Whether tests in `app/test/features/eat/*` pass today; whole tree has uncommitted edits (`eat_hub_view.dart`, `type_it_view.dart`, `week_plan_view.dart` are modified).
- Accuracy of the listed Egyptian dish values against any Egyptian table.
- Test counts are `grep` counts of test declarations, so parametrised and loop-generated tests are undercounted.
