# Work order template (every file in work-orders/ follows this exactly)

File name: `WO-NN-short-name.md` (split a big area into `WO-NNa`, `WO-NNb`; one work order is at most 10 numbered steps and touches at most 8 files).

```
# WO-NN: title
Depends on: WO ids that must be done first (or "none")
Size: S (under 1 hour) / M / L
Reads first: the exact files and line ranges to open before editing (at most 6)

## Why (one paragraph, product reason in plain words)
## Final result (what she sees and what the code does when this is finished; describe each screen top to bottom, with the exact English and Egyptian Arabic text; list the controls in order)
## Files to edit or create (table: path | create or edit | what changes in one line)
## Steps (numbered; each step names ONE file, the exact anchor to find (class, function or unique line of existing code, with the current line number marked "about"), and the exact change as a code block or an exact before and after; no step says "update", "handle", "as needed" or "similar" without showing the code)
## Strings to add (table: key | English | Egyptian Arabic; the command to add them: `python3 app/tool/add_strings.py ...` with the real arguments, then `cd app && flutter gen-l10n`)
## Tests to add or change (table: file | test name | exact arrange, act and assert in words; plus the command to run)
## Verify (exact commands, and the exact output that means success)
## Do not (the things that would break the product: files not to touch, rules from the brief that apply here)
## Done checklist (tick boxes the agent copies into its report)
## If stuck (what to do when an anchor is not found or a test fails twice: stop, write the question to handover/QUESTIONS.md with file:line and what you saw, and move to the next work order that does not depend on this one)
```

Writing rules for work orders: no assumptions, nothing left for the agent to decide; if a fact was not verified in the code, mark it `UNVERIFIED` and give the command that verifies it. Use exact paths from the repo root. Every UI text in English and Egyptian Arabic (feminine address, Western digits, no em dashes). Reuse existing widgets named in handover/01-PRODUCT-BRIEF.md.
