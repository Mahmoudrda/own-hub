# WO-04g: coach portfolio, no empty reviews, no price that is not charged (C8)
Depends on: none
Size: S
Reads first: `app/lib/features/private_coaching/presentation/member/coach_portfolio_view.dart` lines 225-250 and 500-535; `app/lib/features/private_coaching/presentation/coach/packages_view.dart` lines 55-100; `app/lib/features/private_coaching/presentation/member/coach_labels.dart` line 12 (`coachingPaymentsOn`); `app/test/features/private_coaching/member/member_browse_test.dart` lines 100-170 (`coach`, `portfolio`, `MemberRepo`) and 416-428

## Why
Checked 26 Oct, most of C8 is already true in code, so this order is small and mostly locks it with tests:
- "What members say" is already hidden when a coach has no testimonials: `coach_portfolio_view.dart:236` is `if (coach.testimonials.isNotEmpty) ...[ _heading(l10n.whatMembersSay) ...`. No code change; a test must hold it.
- The member's package card already shows "Free for now" and "EGP {price} when payments open" while payments are off (`coach_portfolio_view.dart:513-528`, `coachingPaymentsOn` = `Feature.payments`, which is `false` in `feature_flags.dart:495`).
- Her own list of packages (K18, My packages) is the one place that still says "Members see EGP 2,000 · 28 days · Free for members until payments open" (`packages_view.dart:73-79`): it says members see a price and also that it is free. This order makes it say one thing.
- Her profile editing flow already exists: K18 "My portfolio" opens `PortfolioEditView` (photo, headline, approach), "Photos and results" opens `PortfolioMediaView`, "My packages" opens `PackagesView`, "Preview my portfolio" opens H02 in preview. Taps from K18: 1 to open each, 2 to save a change.
The plan also wanted "1 message button" on a coach card: the member portfolio's "Ask to join" is the only action (a woman asks to join first; chat opens after the coach accepts). Not changed; say so in the report.

## Final result
K18 -> My packages, each row, subtitle with payments off: EN "Free for members until payments open · EGP 2,000 when payments open · 28 days" / AR "ببلاش للعضوات لحد ما الدفع يشتغل · 2,000 جنيه لما الدفع يشتغل · 28 يوم". With payments on (later): EN "Members see EGP 2,000 · 28 days" as today.
Member portfolio with zero testimonials: no heading "What members say", no empty card (unchanged, now tested). Member portfolio with testimonials: heading and cards shown.

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/lib/features/private_coaching/presentation/coach/packages_view.dart` | edit | subtitle |
| `app/test/features/private_coaching/member/member_browse_test.dart` | edit | two tests |
| `app/test/features/private_coaching/coach/coach_test.dart` | edit | one test |

## Steps
1. File `packages_view.dart`, the `subtitle: [ ... ].join(' · '),` list (lines 73-79). Replace the whole list with:
```dart
                      subtitle: (coachingPaymentsOn
                              ? <String>[
                                  l10n.membersSeeEgpPrice(
                                    countLabel(p.priceFinalEgp),
                                  ),
                                  l10n.daysPluralOne1DayOtherDays(p.durationDays),
                                ]
                              : <String>[
                                  l10n.freeForMembersUntilPaymentsOpen,
                                  l10n.egpPriceWhenPaymentsOpen(
                                    countLabel(p.priceFinalEgp),
                                  ),
                                  l10n.daysPluralOne1DayOtherDays(p.durationDays),
                                ])
                          .join(' · '),
```
`countLabel` is already imported and used on the line it replaces (`number_label.dart`, Western digits per `coach_test.dart` test `ar: the price line uses Western digits`, line 604). Keep `coachingPaymentsOn` (already imported from `member/coach_labels.dart`).
2. Check the existing tests that assert the old subtitle: `grep -n "Members see EGP\|Free for members until" app/test -r`. In `coach_test.dart` (group `packages`, tests at lines 406-423 and 570-610) change expected strings only where they match the old subtitle, to the new one above. Do not change a test for any other behaviour.
3. Add the tests (table). Run them.

## Strings to add
None. `freeForMembersUntilPaymentsOpen`, `egpPriceWhenPaymentsOpen`, `membersSeeEgpPrice` exist (`app_en.arb` lines 6660, 8045, 8055; Arabic checked above). Note: the Arabic of `egpPriceWhenPaymentsOpen` is "{price} جنيه لما الدفع يشتغل".

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `member_browse_test.dart` | `no testimonials: the reviews block is not drawn` | UNVERIFIED helper shape: `grep -n "Widget portfolio" -A14 app/test/features/private_coaching/member/member_browse_test.dart`. Build the same portfolio as test line 416 but with a coach whose `testimonials` is `const <PublicTestimonial>[]` (copy `coach(...)` into a local `CoachProfile(...)` with that field, or add an optional `testimonials` parameter to the file's `coach` helper, default unchanged). Assert `find.text('What members say')` is `findsNothing` and `find.text('Very patient and clear.')` is `findsNothing` |
| same | `with a testimonial the block is drawn` | default coach: `find.text('What members say')` and `find.text('Very patient and clear.')` each `findsOneWidget` |
| `coach_test.dart` (group `packages`) | `with payments off her list says one thing about price` | open PackagesView with one active package priced 2000 as the neighbouring tests do; expect text containing `Free for members until payments open · EGP 2,000 when payments open · 28 days` (adjust the day count to the fixture) and `find.textContaining('Members see EGP')` `findsNothing` |
Run: `cd app && flutter test test/features/private_coaching/member/member_browse_test.dart test/features/private_coaching/coach/coach_test.dart`

## Verify
- Both files print `All tests passed!`; `flutter analyze` clean.
- Android emulator, coach account: K18 -> My packages: the subtitle reads as in "Final result".

## Do not
- Do not turn `Feature.payments` on. Do not remove the reviews block from the code (it is needed when reviews arrive). Do not change the package editor form (`package_edit_view.dart`): if it still says "Members see EGP price" help text, list the file:line in the report; the commission decision (D63) is owner business.

## Done checklist
- [ ] subtitle edited
- [ ] old expectations updated
- [ ] 3 tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
