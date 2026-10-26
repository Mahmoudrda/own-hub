# Implementation guide: order of work

The full plan with reasons is `reference/PRODUCTION-RELEASE-PLAN.md`. This file lists the order. Status: WRITTEN means the work orders exist in work-orders/; each INDEX-NN.md gives the order inside the group. Written work orders are in `work-orders/`. Items marked TO WRITE have a plan paragraph in the production plan but no step-by-step work order yet; do not start them until their work order exists. If you are a strong agent you may write the work order first, following `00-WORK-ORDER-TEMPLATE.md`, from the code.

| Order | Work order | Scope | Status |
|---|---|---|---|
| 1 | WO-01 close-out | the two failing tests, batch A review fixes, two commits | see work-orders/ |
| 2 | WO-02a to 02g chat | photo, video, voice, saved replies, rules, privacy text (see work-orders/INDEX-02.md) | WRITTEN |
| 3 | WO-03a to 03j builders | move fields, day editor, duplicate day, start date, weeks, assign to many, meal builder, client meal plan (INDEX-03.md) | WRITTEN |
| 4 | WO-04a to 04j coach setup | invites and links, check-ins, needs-attention list, health flags, profile honesty, old planner guard, approval steps (INDEX-04.md). Do 04h and 04i before WO-03h and 03i take effect | WRITTEN |
| 5 | WO-05 voice | sentence parser fixes and voice logging | TO WRITE |
| 6 | WO-06 food safety | calorie floors, pregnancy rules, data accuracy tests | TO WRITE |
| 7 | WO-07 batch B | guest first workout, walking session, rewards | TO WRITE |
| 8 | WO-08 sound and motion | synthesised sounds, sound service, moments | TO WRITE |
| 10 | WO-10a to 10k InstaPay payments | governed peer-to-peer payments per reference/INSTAPAY-PAYMENTS-SPEC.md section 11 | TO WRITE |
| 9 | WO-09 release | version 1.1.0, store listings, screenshots, Android first release, test program | TO WRITE |

Owner decisions that block some orders are in `reference/PRODUCTION-RELEASE-PLAN.md` section 3.
