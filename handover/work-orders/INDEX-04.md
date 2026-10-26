# INDEX-04: coaching day one, items C1, C3, C8, C9, C10

Finding that changes the plan: the invite callables already exist (`create_coach_invite`, `accept_coach_invite` in `functions/main.py:1798,1820`), C8's two fixes are mostly already in code, and the old planner screens are already dark by feature flags. Orders are small accordingly.

| order | what | depends on |
|---|---|---|
| WO-04a-invite-entry-points | "Invite a client" row on K18 and button on the empty K07 desk (the code existed but no live screen offered it) | none |
| WO-04b-link-routing-in-app | `/c/<code>` invite link and `/p/<uid>` profile link: parse, open, kept code, "Share my profile link", new invite message | 04a |
| WO-04c-app-links-platform-and-site | iOS associated domains, Android intent filter, AASA and assetlinks files, `/join` page for women without the app | 04b |
| WO-04d-checkin-server | weekly check-in card, Friday push, Monday kind follow-up, answer callable, "Needs attention" callable; behind `CHECK_INS_LIVE = False` | none |
| WO-04e-checkin-client-form | card in the thread and the 4-tap form (6 taps total) | 04d |
| WO-04f-needs-attention-list | "Needs attention" section at the top of the coach desk | 04d, 04e |
| WO-04g-portfolio-honesty | zero-review block stays hidden (tested); one honest price line on her packages list | none |
| WO-04h-health-flags-server | pregnancy/postpartum and eating-history flags; plans held until the coach marks answers read | none (04d step 7 edits) |
| WO-04i-health-flags-app | two join questions, flags on K07/details, hold card and disabled share buttons on W02 | 04h |
| WO-04j-old-planner-gate-and-approval-steps | trace and guard tests for W04-W09, K19-K23, K26, K27; tap-by-tap approval of Rahma by a different woman reviewer | run last |

Open items not covered: check-in progress photo (storage rule and moderation path unverified); rate limits on chat, report, upload and the push-text decision (C10 text, not in this assignment); hiding calorie targets for eating-history (F3 reads `intake.eatingHistory`).
