You are working in the folder I opened: the Own Hub repository (a Flutter app in `app/`, Python Firebase functions in `functions/`, a staff dashboard in `admin-web/`). It is a women-only fitness and coaching app for Egypt, in English and Egyptian Arabic. A real coach, Rahma, will use it with clients from day one, so correctness matters more than speed.

Do not scan the whole repository. Read only these, in order:
1. `handover/00-START-HERE.md`
2. `handover/01-PRODUCT-BRIEF.md`
3. `handover/02-IMPLEMENTATION-GUIDE.md`

Then do the work orders in `handover/work-orders/` one at a time, in this exact order:
WO-02a to WO-02g (chat), then WO-03a to WO-03g (builders), then WO-04a to WO-04j (coach setup), then WO-03h to WO-03j (meals; they need the health flag from WO-04h and WO-04i). Each group has an `INDEX-NN.md` that confirms the order. Orders not in this list are not written yet: do not start them.

How to work:
- Open only the files the work order names. Follow its steps exactly, in order. Run its verify commands and compare with the expected output. Tick its checklist and report it to me.
- Never guess. If an anchor, file or fact differs from what the order says, or an UNVERIFIED item cannot be verified, stop, write the question in `handover/QUESTIONS.md` (file path, what you saw), and take the next order that does not depend on it.
- The working tree already has uncommitted changes from earlier work. Do not revert them, do not reformat unrelated files, do not commit, do not push.

Hard rules: never push to main; no Co-Authored-By line; never stage `.claude/CLAUDE.md`; all UI text in English and Egyptian Arabic with feminine address, Western digits and no em dashes; one filled primary button per screen; never weaken women-only verification, consent records or the 18+ tick; payments stay off.

Before you edit anything, tell me which work order you are starting and list the files it will change.
