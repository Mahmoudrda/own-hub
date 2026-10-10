# Own Hub launch pack

The documents promised in the "Your steps" tab of `docs/release/OWN-HUB-BEFORE-PROD.xlsx`, where a step
says "I send you" or "I give you". This folder stays on this Mac and is not in git.

**pilot-checklist.xlsx** serves steps 14 and 15. The "Safety tests" sheet holds the 11 adversarial tests
from `MANUAL_QA.md` that testers can run (the two that need a modified app are Mahmoud's), each with how
to set it up, what should happen and what must never happen. The "Pilot" sheet records about 30 women
doing the real check by tester number only, and the "Review calls" sheet times 10 practice calls from
booking to decision. Each sheet starts with a short note on how to run it. Send the filled file back.

**allergen-signoff.xlsx** serves step 16. One row for each of Rahma Mohsen's 39 recipes, with the 16
allergens the app asks women about as tick columns, a draft column showing what the app guessed from the
ingredient text, then "cooked as written", "signed by" and "date". Until a row is signed, women who
declare any allergy do not see that recipe.

**play-app-access.md** serves step 10, item 3 (App access). It explains why Google's reviewer needs a
test path, shows how to add a fictional test number in Firebase, says plainly that a reviewer cannot pass
the ID check so Mahmoud verifies the test account at deploy, and gives the text to paste into Play
Console.

**app-store-privacy-answers.md** serves step 20. It gives the App Privacy answers for App Store Connect,
type by type, matching the iOS privacy manifest and the Play data safety file. It also covers the age
rating questionnaire (set to 18+) and the App Review note with the second test account.

**store-listing-copy.md** serves steps 7, 11 and 20, wherever a store listing is filled in. It has the
name, subtitle, short description, full description, keywords and "what's new" in English and Modern
Standard Arabic, each counted against the store's limit. It describes only what is switched on in the
launch build.
