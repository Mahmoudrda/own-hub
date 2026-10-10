# Row 01 — Design system

Screenshot: ../3-screenshots/rows/row-01-design-system.png

## All text on this row, in reading order

```text
Row 01
Design system
Every pairing below is one of the validated combinations. Two radii logics: pills for anything tappable-and-inline, 16–20px for cards, 0px for media.
Colour, with its validated pairing
Text and surfaces
ink
#2A2226 — body text on cream, 14.6:1
plum
#5E2F42 — headings on cream, 10.1:1
muted
#6B5C61 — secondary text on cream, 5.9:1
cream
#FCF7F6 — app background
white
#FFFFFF — cards and sheets
line
#EBDCDF — borders, dividers. Never type.
Rose — action
rose-600
#B4526E — primary fill, white text 4.8:1
rose-700
#A8455F — pressed; rose type on cream 5.4:1
rose-400
#C96A85 — decorative fills and rings only
rose-wash
#F8E9ED — chips, selected states, tints
Sage — progress
sage-700
#4F7359 — white text 5.3:1; on cream 5.0:1
sage-400
#6E9478 — progress fills and rings only
sage-wash
#E6EFE8 — secondary tinted surfaces
Status
amber
#D99D55 — coaching accent, ink text 6.6:1
rust
#A84A4A — errors, destructive, white 5.6:1
Type scale — IBM Plex Sans Arabic
34 / 40 / 600
Good morning, Mai
24 / 32 / 600
Today's workout
20 / 28 / 600
Lower body, 30 minutes
16 / 26 / 400
Body copy floor. Nothing she has to read sits below this.
15 / 20 / 500
Labels, chips, list meta — the smallest UI size
12 / 16 / 600
Tab-bar labels only, at 12px. The single deliberate exception, so that five labelled tabs fit 390px. The four-tab concept in Row 03 removes the exception.
Arabic cut, same family
Start today's workout
ابدئي تمرين اليوم
Arabic set 2px larger with 1.5× line-height. Same weight, same colour, same box.
Numerals never flip
٤ أسابيع، 1,800 جنيه في الشهر، +20 100 555 0132
Western Arabic digits, isolated so prices and phone numbers keep their order inside RTL text.
Buttons — 56px tall, pill, full width
Start today's workout
Start today's workout
Start today's workout
Starting
Pick a different day
Skip for now
Delete this post
Default, pressed, disabled, loading, secondary, quiet, destructive. Labels name the outcome; no arrows appended.
Inputs and inline validation
Your phone number
+20
100 000 0000
Your phone number
+20
100 555 0132
Your phone number
+20
100 555
That number looks a bit short. Egyptian mobiles have 10 digits after +20.
Code we sent you
4
1
7
Chips, filters, badges
15 minutes
At home
No equipment
Quiet, no jumping
Filters
3
The count is why the list looks the way it does.
Verified woman
Coach
Free
Included with coaching
Never a padlock. A padlock reads as “you are not allowed”.
Workout card
video still
30 min
At home
Quiet
Lower body, no equipment
Day 2 of 3 this week
Recipe card — duration leads
food photo
22 min
Koshari, portioned
540 kcal
18 g protein
14 EGP a serving
Post card
Mai Farouk
✓
Home workouts group
her photo, face blurred
Four weeks of the postpartum rebuild and I carried both kids up the stairs without stopping.
Like 48
Comment 12
Save
Coach card
coach portrait
Nourhan El-Sayed
Verified
Postpartum strength, gets you back to training safely
Arabic
English
Giza
From 1,800 EGP a month
4.8 out of 5, 126 reviews
Replies in about 2 hours
Client tab bar — five tabs, every icon labelled
Home
Train
Community
Eat
Coaching
Coach tab bar — four tabs, denser, labels at 15px
Today
Clients
Chats
4
Earnings
Toasts — undo lives here, for 5 seconds
Post deleted
Undo
✓
Posted
That code didn't work. Tap here and we'll send a new one.
Send a new code
The verb on the button is the verb in the toast. Post → Posted. Save → Saved.
Bottom sheet — the default for anything short
Swap this exercise
Same muscles, quieter on the floor.
Glute bridge
Step-back lunge
Swap it
Context stays visible behind it, and the whole sheet lands inside the thumb zone. Drag handle plus a labelled action — never drag-only.
Empty states — one visual idea, one action
line drawing
empty mat
No program yet
Answer four quick questions and we'll pick one for you.
Find my program
line drawing
tape measure
Nothing logged yet
Your weight and measurements stay private to you.
Add today's weight
Thumb zones on a 390 × 844 frame
Back
only
Close,
rare
Hard zone
Screen title, back, close. Nothing she needs often.
Stretch zone
Content, cards, secondary actions, filter chips.
Natural zone — bottom 40%
Primary button, tab bar, every bottom sheet, submit bars.
Primary action lives here
Tab bar
Which component is allowed where
Natural
Primary button, fixed submit bar, tab bar, bottom sheets, set-logging button, voice-note button, swipe-deck buttons
Stretch
Cards, filter chips, list rows, inputs, secondary buttons, macro ring, feed media
Hard
Back, close, screen title, Skip on onboarding, post menu, delete, sign out
Skip sits in the hard zone on purpose: reachable when she means it, not when her thumb wanders. It is still a 48px target.
```

## Screen by screen

### Thumb zones on a 390 × 844 frame

![ds-thumb-zones-on-a-390-844-frame](../3-screenshots/screens/ds-thumb-zones-on-a-390-844-frame.png)

Design note:

```text
Thumb zones on a 390 × 844 frame
```

On the screen:

```text
Back
only
Close,
rare
Hard zone
Screen title, back, close. Nothing she needs often.
Stretch zone
Content, cards, secondary actions, filter chips.
Natural zone — bottom 40%
Primary button, tab bar, every bottom sheet, submit bars.
Primary action lives here
Tab bar
```
