# Phase 1 — findings from the build

Defects and gaps found while implementing Phase 1, recorded as they were found so
none is lost between the build and QA.

This is **not** the QA report. QA runs `PHASE1-ACCEPTANCE.md` against the finished
build; this list exists so QA can tell a known gap from a new regression.

The first two are systemic, were each found independently by two different builds,
and both bear on whether Phase 1 can honestly be called done.

---

## F1 — The app cannot say anything about her. **Systemic.**

The dictionary has **1,789 messages and zero parameterised strings.** No ICU
placeholders, no metadata entries. Nothing in the product can put her name, her
number, her weight or her choices into a sentence.

The consequence is that mockup sample data is baked into shipping copy. **169
distinct strings** contain data that should be hers:

| what is baked in | strings |
|---|---:|
| a person's name (Mai, Nour, Sara…) | 63 |
| a weight in kg | 41 |
| a weekday list (Monday, Tuesday…) | 27 |
| a price in EGP | 27 |
| a spelled-out count ("Three days") | 11 |
| a duration in seconds | 6 |
| a phone number | 1 |
| **distinct** | **169** |

In Phase 1 specifically, a woman is shown:

- `C07` — *"We sent six digits to +20 100 555 0132."* Not her number.
- `C13` — *"You're in, Mai"* and *"Verified in 74 seconds."* Not her name, not her
  time. This is the first sentence the product ever addresses to her personally.
- `O03` — *"Three sessions a week is your goal."* Whatever she picked.
- `O05` — *"Three days a week, 15 minutes, at home."* On the one screen whose
  entire job is to reflect her answers back to her.

Both builds handled it correctly rather than papering over it: `C13` takes no
`firstName` at all, so "You're in, null" is structurally unreachable, and a test
pins that in both locales. Nothing was hardcoded to make a screen look finished.

**What it needs:** parameterised messages in both languages — with real Arabic
plural categories, since Arabic has more than English and a digit substitution
would be wrong. This is dictionary work plus a change to the ARB generator, which
currently emits no metadata.

**Why it was not fixed during the build:** regenerating the ARB changes the keys
three agents were actively coding against. Scheduled for immediately after the
last builder lands.

## F2 — The app has no words for anything going wrong. **Systemic.**

Searching all 1,789 strings in both languages:

| copy for | strings |
|---|---:|
| offline / no signal | **0** |
| try again / retry | **0** |
| something went wrong | **0** |
| permission / allow access | **0** |

There is no way to tell a woman that her log is waiting for signal, that a code
expired, that a photo failed to upload, or that the app needs her camera.

This is not a small omission. The test suite contains **134 P2-OFF and P2-ERR
cases** — every screen that writes — and they test states the product currently
has no language for. Offline-first is a launch requirement in Egypt: this is the
copy for the normal case on a Cairo microbus, not an edge case.

The builds responded by *withholding* rather than inventing: `C06` gates its
button until the number is valid, `C07` clears the boxes on a bad code, the
capture screens disable the shutter. Nothing invents untranslated English. That is
the right call and it is also why the gap is invisible unless you go looking.

**What it needs:** an error, offline and permission vocabulary written in both
languages. Content work, and it is on the critical path for QA.

---

## F3 — The camera screens cannot be verified here

`C10` and `C11` are real ID and selfie capture. No provider SDK or camera plugin
is in `pubspec.yaml`; the only implementation is `UnavailableCaptureService`, so
the shutter is disabled and tapping it reports nothing. Tests pin that.

The interface returns no bytes or paths and carries no classification result, so
**rules 7 and 8 hold structurally** — there is nowhere for an image to be retained
and nothing that could classify a face. QA reports these as **untested**, never as
passing. They need a physical device and the provider contract.

## F4 — "Pick a different program" leads to the workout library

`O05`'s secondary action goes to `R11`, the workout library — not a programme
picker, which does not exist among the 161 screens. Built as designed, with the
destination exposed so changing it is deliberate. **Owner decision.**

## F5 — The programme catalogue has no content

Only `beginner_foundations` has authored copy; other programmes render nothing
rather than showing an English identifier to an Arabic reader. Setup cannot finish
without programmes, so this is on the critical path.

## F6 — Life stage is collected but nothing acts on it

`O04` records pregnancy, postpartum and injury status and passes it on, but no
filtering is applied. Correct for now — the exclusion list is server-side and has
no clinical sign-off — but **the safety promise on that screen is not yet kept by
anything.** It depends on F7.

## F7 — The libraries still have no safety tags

`exercises` needs `contraindicationTags[]`; `foods` needs `allergens[]` and
`dietTags[]`. Without them the avoid list, every `refer` outcome and the allergy
guard are displayed but unenforceable. Found independently by two planning groups.

## F8 — The niqab reviewer path has no domain representation

`C15` offers a video check or a partner gym; both currently submit the same
`VerificationMethod.niqabFriendly` and the choice is reported only by callback.
Harmless today, but the two paths have different operational costs.

---

## Departures from the prototype, accepted deliberately

Each an improvement rather than a shortfall:

- **Chips and buttons get a 44pt minimum tap target** where the design draws 40.
  The product is used one-handed, mid-set.
- **Equipment chips wrap** instead of clipping, so an item she owns cannot sit
  off-screen.
- **Designer annotations are not drawn as copy.** "logotype" on `C01` and "coach
  demo still" on `O05` mark where an asset goes; the extractor swept them into the
  dictionary, which is how you can tell they were never meant to be read.
- **No fake status bar.** The prototype draws a 9:41 phone frame because it runs
  in a browser; the OS draws the real one.
- **`C12` keeps its Continue button** although the real transition is the state
  listener.
