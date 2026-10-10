# Logging friction and rewards — what the evidence says, and what it changed

Research for the redesign of workout and meal logging. Every claim below was checked against the
source named next to it. Where the team's Phase 1 draft made a claim I could not verify, it says so.

## Summary

People do not stop logging because logging is slow. They stop because each entry demands decisions
(which food, which portion, which variant), because apps punish imperfect days, and because the
reward for a perfect log is another empty form tomorrow. The strongest levers are: cut the decisions
rather than the seconds, make the unit of consistency a week instead of a day, let a broken run be
repaired, and reward only behaviour that moves her goal.

## 1. Why logging is abandoned

- **Entry is the problem, not duration.** Cordeiro et al. (CHI 2015) surveyed 141 current and lapsed
  food journalers and analysed 5,526 community-forum posts, and grouped the failures into three
  areas: barriers to reliable food entry, negative nudges inside the apps, and problems with social
  features. Missing or wrong database entries, multi-item home-cooked meals and portion guesswork are
  named entry barriers. (https://homes.cs.washington.edu/~jfogarty/publications/chi2015-barriersandnegativenudges.pdf)
- **Effort falls as the habit forms — if people stay.** In a 24-week behavioural weight-loss trial,
  daily self-monitoring took 23.2 minutes a day in month 1 and 14.6 minutes by month 6, and people
  who lost ≥5% or ≥10% logged in more times per day (2.4 vs 1.6 and 2.7 vs 1.7). Frequency, not
  minutes, tracked success. Harvey et al., *Obesity* 2019, "Log Often, Lose More".
  (https://onlinelibrary.wiley.com/doi/full/10.1002/oby.22382)

**What this changed.** The redesign attacks decisions, not seconds: the app writes the entry from her
plan, her history and the time of day, and she agrees to it. A half-logged day stays a logged day, and
no screen ever asks her to complete one.

## 2. Habits survive a missed day

Lally et al. (2010, *European Journal of Social Psychology*) tracked 96 people forming a daily habit
for 12 weeks: missing one opportunity did not materially affect habit formation — automaticity fell by
less than half a point and recovered quickly — and time to reach 95% of personal automaticity ranged
from 18 to 254 days. (https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.674)

**What this changed.** A missed day is not shown at all. The week is the unit, and the app never
displays a zeroed counter or a red day.

## 3. Streaks: motivating while intact, costly when broken

Silverman & Barasch, "On or Off Track: How (Broken) Streaks Affect Consumer Decisions",
*Journal of Consumer Research* 49(6), 2023: across seven studies, streaks shown as intact increased
subsequent engagement compared with streaks shown as broken — independent of actual past behaviour.
The effect was **amplified when people blamed themselves** for the break, and **attenuated when the
streak could be repaired**. (https://academic.oup.com/jcr/article-abstract/49/6/1095/6623414)

**What this changed.** Three rules: (a) the streak counts weeks, so ordinary life rarely breaks it;
(b) rest weeks repair a shortfall automatically, which is the documented way to remove the sting;
(c) when a week is missed, the copy attributes it outward ("life happened", "a rest week covered it")
and the cumulative total of counted weeks — which never decreases — is the number shown largest.

## 4. Gamification: real but modest, and not a novelty effect

Mazeas et al., "Evaluating the Effectiveness of Gamification on Physical Activity: Systematic Review
and Meta-analysis of Randomized Controlled Trials", *JMIR* 2022;24(1):e26779. Gamified interventions
improved physical activity with Hedges g between 0.33 and 0.48 depending on the model, roughly +500
to +2,183 steps a day across trials, with a larger effect against inactive controls (g=0.58) than
active ones (g=0.23), and effects that persisted at follow-up rather than disappearing as novelty.
(https://www.jmir.org/2022/1/e26779/)

**What this changed.** Points and levels stay, but they are sized as a modest aid, not the product:
every point must come from behaviour that moves her fitness goal (training, personal bests, logging
food, hitting protein, counting a week), with a daily cap so grinding cannot beat showing up, and
nothing at all for opening the app, posting or inviting friends.

## 5. Verdicts on the Phase 1 research panel

| Phase 1 claim | Verdict | Basis |
|---|---|---|
| Passive logging backfires; wearables/photos form weaker habits | **Not verified** as stated | I could not find a source for it. Reframed: keep one deliberate confirming tap as the habit cue, but let the phone *propose* detected walks. |
| Consistency beats completeness | **Supported** | Harvey 2019: logging frequency tracked weight loss; time per day fell over 6 months. |
| Daily streaks cause the dropout | **Partly supported** | Silverman & Barasch 2023: broken streaks lower subsequent engagement vs intact; repair attenuates it. The harm is in the break and the self-blame, not the streak itself. |
| Follow-up questions are friction | **Plausible, unverified specific** | Cordeiro 2015 documents entry burden and negative nudges generally. Kept as a design rule. |
| Search is the friction: decisions, not seconds | **Supported** | Cordeiro 2015: unreliable/ambiguous entry and portion decisions are the named barriers. |
| Gamification fades after ~6 months | **Overstated** | Mazeas 2022 found effects maintained at follow-up. Corrected in the wireframe. |

## 6. Decisions

1. The app writes every log; she confirms it. Confirming and logging are the same tap. (§1)
2. Nothing is ever asked after a log — no clarifying questions, no completion prompts. (§1)
3. Undo for five seconds replaces confirmation dialogs everywhere. (§1)
4. Workout sets carry last time's numbers as a sentence ("12 kg × 10"); steppers appear only behind "Change". (§1)
5. Changing a value uses chips holding the likeliest values; the keyboard is last. (§1)
6. A session done without the phone is logged from history in one or two taps. (§1)
7. Detected walks and classes appear as a proposal with one confirming tap, never silently. (§5 reframe)
8. Meals are offered as the plates she actually eats at this hour and day, ranked by frequency, with the count shown. (§1)
9. Plates she eats together become one item after the second repeat — no "save as meal" step. (§1)
10. One box merges search, typing and voice; results carry portion chips so she never opens a food. (§1)
11. Calories are a calm running total; protein is the one bar. No "kcal left" countdown. (§1, negative nudges)
12. The unit of consistency is the week, not the day. (§2, §3)
13. Rest weeks are earned every four counted weeks, capped at two, and applied automatically. (§3)
14. Counted weeks accumulate and never decrease; the current run is secondary. (§3)
15. Points only for goal-moving behaviour, capped daily; levels never drop. (§4)
16. Tiers reflect recent consistency, slip by at most one step, and return after one counted week; unlocks are never removed. (§3, §4)
17. Challenges are group totals, not leaderboards ranked by weight or body. (§4)

## 7. Deliberately not built

- A daily streak counter (§3).
- Photo calorie scanning as a logging path — accuracy and the "negative nudge" risk outweigh the saved taps at MVP (§1).
- Points or badges for opening the app, completing a profile or inviting friends (§4).
- Post-log clarifying questions (§1).
- Any reward tied to weight lost or body size.

## References

- Cordeiro F. et al., "Barriers and Negative Nudges: Exploring Challenges in Food Journaling", CHI 2015 — https://homes.cs.washington.edu/~jfogarty/publications/chi2015-barriersandnegativenudges.pdf
- Harvey J. et al., "Log Often, Lose More: Electronic Dietary Self-Monitoring for Weight Loss", Obesity 2019 — https://onlinelibrary.wiley.com/doi/full/10.1002/oby.22382
- Lally P. et al., "How are habits formed: Modelling habit formation in the real world", EJSP 2010 — https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.674
- Silverman J., Barasch A., "On or Off Track: How (Broken) Streaks Affect Consumer Decisions", JCR 2023 — https://academic.oup.com/jcr/article-abstract/49/6/1095/6623414
- Mazeas A. et al., "Evaluating the Effectiveness of Gamification on Physical Activity", JMIR 2022 — https://www.jmir.org/2022/1/e26779/
