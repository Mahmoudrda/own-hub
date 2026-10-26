# WO-10k2: the manual two-phone transfer script and the fixtures folder
Depends on: WO-10k1; all app orders; server orders deployed to a staging project (not production)
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` sections 7.7, 12.5, 12.6, 13.12, 13.13; `app/tool/e2e_coaching.sh` lines 1-40 (the emulator seeds); `docs/owner/OWNER-TODO.md`; `.claude/CLAUDE.md` (iOS simulator cannot run ML Kit; use the Android emulator `ownhub_pixel8`, and real phones for iPhone)

## Why
No automatic test can move real money or read a real bank app. Before the flag is on, two real phones make one small real InstaPay transfer through every screen, on iPhone and on Android, and the team records what happened. The same pass checks reading speed. The fixtures folder holds the receipts the automatic tests read, and must never hold a real person's name, number or account digits.

## Final result
1. A filled-in results table (this file's section "Results", added by the tester) for iPhone and Android.
2. The fixtures folders created with the manifest, the redaction rule and the first fixtures (the InstaPay result screen and the HSBC sample as the owner supplied them, redacted).
3. The two real samples are NOT committed; only the redacted images and their text.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| handover/work-orders/WO-10k2-manual-script-and-fixtures.md | edit | the tester writes the Results table at the bottom |
| app/test/fixtures/instapay/README.md | create | the layout and rules (step 1) |
| app/test/fixtures/instapay/manifest.json | create | one entry per fixture |
| app/test/fixtures/instapay/texts/*.txt | create | OCR text of each fixture, for the parser tests |
| functions/tests/fixtures/payments/ (images + manifest.json) | create | the images for the server OCR tests (shared layout) |
| functions/tools/redact_fixture.py | create | black-out helper (step 2) |

## Steps
1. File `app/test/fixtures/instapay/README.md` (create). Content, exactly these rules:
   - Layout: `texts/<id>.txt` (what ML Kit or the server OCR reads, as plain text, one line per receipt line), and in `functions/tests/fixtures/payments/images/<id>.png` the picture. `manifest.json` lists every fixture: `{ "id", "kind": "real" | "synthetic", "bank": "instapay-app" | "hsbc" | "cib" | "nbe" | "banque-misr" | "qnb" | "bdc" | "other" | "none", "language": "en" | "ar" | "mixed", "theme": "light" | "dark" | "high-contrast", "expected": { "outcome": "green" | "amber" | "red" | "wrongMessage", "reasons": [ ... ], "amountPiasters": 50037, "txnNumber": "..." | null } }`.
   - Real fixtures: the owner supplies the receipts. Before anything is committed, run `functions/tools/redact_fixture.py` to black out names, phone numbers, account digits and card digits. Replace the amount and the recipient with the synthetic values used by the tests (`500.37`, `rahma.m@instapay`, `Rahma Mohsen`) by drawing them over the redacted spots, so one fixture serves every test. The originals the owner sends stay outside the repository (`~/Documents`, never `git add`). `.gitignore` check: `git check-ignore -v app/test/fixtures/instapay/texts/x.txt` should print nothing (the folder is tracked).
   - Launch minimum (spec 13.13 item 5): the InstaPay app's own result screen and the HSBC sample. More banks are nice to have, never a launch requirement.
   - Synthetic fixtures needed (each one a text file for the parser and an image for the server): `green-en` (receipt), `green-en-details` (More Details open), `green-ar` (Arabic labels and Arabic-Indic digits), `green-dark`, `missing-success`, `missing-amount`, `missing-recipient`, `missing-txn-and-time` (each expected amber), `wrong-amount` (red), `failed-status` (red), `pending-status` (red), `card-alert` (wrongMessage), `sms-only` (never green), `cropped-amount` (amber), `edited-amount` (server tamper score high, never blocks alone), `edited-name`, `reused-image-a` and `reused-image-b` (identical bytes; the second is red), `long-name`, `garbage` (random text; amber, no throw), `huge-1px-wide` (rejected before OCR), `bomb-20000x20000` (a tiny PNG header that declares a huge size; rejected before OCR).
2. File `functions/tools/redact_fixture.py` (create). A small command line tool using Pillow if it is installed (UNVERIFIED: `functions/venv/bin/python -c "import PIL; print(PIL.__version__)"`; if it is missing, write the question to QUESTIONS.md and use `sips`/Preview by hand). Interface: `python3 functions/tools/redact_fixture.py IN.png OUT.png --box x0,y0,x1,y1 [--box ...] [--text x,y,"500.37 EGP"]`: draws solid black boxes, then white text over chosen spots, strips metadata (saves a fresh image with no EXIF), and refuses to write OUT inside a folder that is not `functions/tests/fixtures/payments/images/`. Exit code 2 and a message on a bad box.
3. The manual script. Needs: two phones (an iPhone with the TestFlight or release build, an Android phone with the Play internal or release build), both pointing at the STAGING Firebase project; two women's accounts verified (one approved coach with a package priced at the smallest allowed price and the payments setting reachable; one client); two real bank accounts with InstaPay, each with a small balance; a third bank app for the wrong-amount test; screen recording on. The owner agrees the amount: a package of the minimum price is used so the real transfer is small. The staging server shortens the address delay (UNVERIFIED config name; ask the server agent) or the tester waits 24 hours between steps 3 and 4.
   Run the whole table once with the coach on iPhone and the client on Android, and once the other way round. Write PASS or FAIL and a note in the Results table.

| step | who | do | expected |
|---|---|---|---|
| 1 | coach | Coach space, "My InstaPay address": enter her real `@instapay` handle and her name exactly as her bank shows it; "Send me a code"; enter the SMS code; "Confirm" | the line "Your new address starts working at HH:MM" appears; a phone-number address is refused with the helper text |
| 2 | coach | open Payments: shows the empty note | "Nothing is waiting for you." and no address card |
| 3 | client | find the coach, "Ask to join", send; coach accepts | H05 shows "Your coach accepted you. Pay to start." and "Pay now" |
| 4 | client | "Pay now" | PAY1: amount with extra piasters (for example 100.37 EGP), the coach's name and address, a reference like OH-1234, three steps, a running countdown |
| 5 | client | tap Copy on the amount, then on the address | "Copied" each time; paste into a notes app to check the text is `100.37` and the handle |
| 6 | client | open her bank app, InstaPay, send the exact amount to the copied address, put the reference in the note if the bank has a note field (write down which banks do and which do not); on the bank's result screen take a screenshot; tap "More Details" and take a second screenshot | the transfer succeeds |
| 7 | client | back in Own Hub, "I have paid"; PAY2: "Choose screenshots"; select both | the hide-details step opens for each picture; lines with card or balance words are already boxed |
| 8 | client | draw a black box over a balance line; try to draw over the amount | the amount is refused with "That part is needed to check your payment."; "Use this picture" |
| 9 | client | after both pictures: read the summary | Transaction number filled, hint "Everything matches. Tap send." Time how long it took from choosing to this hint (stopwatch): record seconds (limit 10) |
| 10 | client | enter her own InstaPay handle (first payment), answer the "Help improve receipt reading?" question, "Send to coach" | PAY3: "Proof sent", green access line if the server returned green |
| 11 | coach | the push arrives on the lock screen; read it | generic text, no amount, no name |
| 12 | coach | tap the push | Payments opens and the sheet for the single waiting payment opens by itself |
| 13 | coach | read the sheet: "Look for exactly 100.37", the transaction number | both match her bank app and SMS |
| 14 | coach | "I received it" | snackbar "Confirmed. Your client can start." |
| 15 | client | PAY3 | "Confirmed", "All set. Your coaching is active."; push "Your coach confirmed your payment." |
| 16 | client | menu, "Save payment record" | a picture with amount, date in Cairo time, coach, reference, status and the not-an-invoice line; share sheet opens |
| 17 | client | menu, "Ask for a refund": reason, note, "Send" | PAY3 "Refund asked"; coach sees "Refund requests" |
| 18 | coach | send the money back by InstaPay (the real small amount); "Record refund": amount, transaction number | PAY3 for the client: "Refunded" |
| 19 | coach | after the month starts (or the staging scheduler is run by hand), "Monthly statement" | the payment, the fee and the total; "Mark fee as paid" opens the sheet |
| 20 | both | airplane mode on the client: new payment, choose screenshots, send | "Saved. We will send it when you have signal."; turn airplane mode off, open PAY1: the proof arrives once |
| 21 | client | negative: pay 90.00 instead of 100.37, then send that screenshot | the hint says "This does not match your payment. You can still send it and Own Hub will check."; the server marks RED; staff see it in the Disputes tab |
| 22 | client | negative: send a screenshot of a card purchase SMS | "This looks like a card message..." and Send is off |
| 23 | coach | negative: on a second payment tap "Not received" with a statement that DOES show the payment | "This payment appears in your statement. Please check again." and nothing is sent |
| 24 | staff | Disputes tab: open a case | seven evidence items, pictures, timers, recommended decision; sending without a reason is refused; a suspension shows "Waiting for a second reviewer." |
| 25 | both | repeat steps 4 to 16 in Arabic with text size at maximum | nothing is cut off; digits are Western; no English leaks except the handle and bank words |
| 26 | owner | turn `config/payments.enabled` off | H05 and Coach space show no payment entries; an open payment still opens from a push and from the old PAY3 route |
After each run, restore: turn the switch on, delete test payments in staging (staff tool or the emulator reset).

## Strings to add
None.

## Tests to add or change
| file | test name | what |
|---|---|---|
| manifest check | `every fixture in the manifest has a text file and an image` | a small Python check in `functions/tests/test_payments_fixtures.py`: reads both manifests, asserts each `id` has `texts/<id>.txt` and `images/<id>.png` (or is marked `imageOnly`/`textOnly`), no file is missing, and no file name or text contains a digit run of 10 or more digits other than the allowed `123456789012` and the amount `50037`/`500.37` |
| (manual) | the table above | PASS or FAIL for 26 rows on two phone pairs |
Run: `cd functions && venv/bin/python -m pytest tests/test_payments_fixtures.py -q`

## Verify
- the pytest command ends with `passed`.
- The Results table has 26 rows for each of the two runs, each PASS or FAIL with a one-line note and the measured seconds for step 9.

## Do not
- Do not commit a real receipt, name, phone number, card digit, balance or account digit. Do not commit the owner's original images.
- Do not run the script against production. Do not use large amounts.
- Do not skip the Arabic and maximum-text pass.

## Done checklist
- [ ] README, manifest, redact tool, first fixtures
- [ ] two script runs recorded (iPhone coach with Android client, and the reverse)
- [ ] the seconds measured at step 9 recorded for both phones

## If stuck
If an anchor is not found or a step fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10q).

UNVERIFIED in this order: 2 (Pillow availability; the staging address delay setting name).

## Results
(The tester fills this in: run 1 coach iPhone and client Android; run 2 the reverse; one row per step with PASS or FAIL.)
