# Own Hub handover: start here

Open this folder (the repo root `ownhub/`) in your editor. Read the files in this order, one at a time:

1. `01-PRODUCT-BRIEF.md`: what the product is, colours, fonts, shared widgets, folder map, commands, rules. (Being written; if missing, read `.claude/CLAUDE.md`, `README.md` and `reference/` instead.)
2. `02-IMPLEMENTATION-GUIDE.md`: the ordered list of work orders and what each one needs.
3. `work-orders/WO-NN-*.md`: do these one at a time, in order. Each says exactly which files to edit and how.
4. `reference/`: background and evidence. Read only when a work order points you there.

Rules for every agent:
- Do one work order at a time. Do its steps in order. Run its verify commands. Tick its checklist.
- Never guess. If an anchor, file or fact is not found, stop, write the question in `handover/QUESTIONS.md` (file path, what you saw) and move to the next independent work order.
- Do not commit unless the work order says so. Never push to `main`. No `Co-Authored-By` line. Never stage `.claude/CLAUDE.md`.
- Product text: English and Egyptian Arabic, feminine address, Western digits, no em dashes, no emoji, plain everyday words.
- Never weaken women-only verification, consent records or the 18+ tick. No loss or guilt wording. Payments stay off.
- Screen limits: one filled primary button per screen; at most 5 other controls above the fold. `cd app && flutter test test/qa/screen_budget_test.dart` must stay green.
