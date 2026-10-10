# Closed test, recruiting 12 testers for 14 days

**Rewritten 23 September 2026, for the first release.**

## Why this exists

A personal Google Play developer account cannot publish to production until the app has run a
**closed test with at least 12 testers who stay opted in for 14 continuous days**. The clock is
unforgiving in one specific way: it counts testers who are opted in the whole time. If someone opts
in on day 1 and leaves on day 9, the count drops, and you can find yourself on day 14 with 11 testers
and no production access.

So recruit **more than 12**. Fifteen to eighteen is the number that survives two people changing
phones and one losing interest.

| What | Value |
|---|---|
| Testers required | 12 minimum, recruit 15 to 18 |
| Duration | 14 continuous days, opted in throughout |
| Opt-in link | `[OWNER: closed test opt-in URL from Play Console, Testing, Closed testing, Testers]` |
| Feedback form | `[OWNER: feedback form URL, see section 4]` |
| Support contact | `[OWNER: support email or WhatsApp number]` |

**Who to ask.** Women who would actually use this: women who train at home, women who have left a
mixed gym, women who cook the food the app logs. A tester who would never open the app tells you
nothing, and she is the one who drops out on day 9.

**One practical note before you send anything.** Every tester needs the Google account she uses on
her phone, the one in the Play Store. An invitation accepted with a different account looks like an
opt-in and does not count. Say this in the first message, not the third.

---

## 0. Before you send a single invitation

**The thing that used to make this test pointless is fixed.** The app now writes her week to her own
phone and reads it back at launch, so a woman who logs a session on Monday still has it on Tuesday.
That was the one blocker that made a fortnight of testing worthless, and it is gone.

One thing remains, and it decides what you can ask for:

**She cannot choose her language.** Profile, then Language, opens a panel that says the feature is
switched off, and the app is pinned to English. Arabic is complete inside the app and unreachable.
For a test with Egyptian women that is not a detail. Fix it before you invite anyone, or accept that
this round only tests the English build and take the Arabic question out of the messages below.
See `compliance-inventory.md` code blocker 1.

`[OWNER: also decide whether to fix the dead controls in code blocker 2 first. A tester who taps
"Beginners group" on her first day and lands on a panel saying "switched off" learns that the app is
unfinished, and you spend a message explaining it instead of hearing what she thinks of the training.]`

**What the testers are testing** is the whole of the first release: Home, Train, Eat, My cycle,
Progress, and her own data. There is no account, no community and no coaching in this build, so do
not promise any of them.

---

## 1. The message, English

Send this by WhatsApp, one person at a time. Not a broadcast list: a broadcast reads as a forward and
gets ignored, and this needs a yes from a specific person.

```
Hi [name], I'm testing an app I've been building and I'd love you in the first group.

It's called Own Hub. It's a fitness app for women in Egypt: home workouts, meal logging in the food we actually eat, your week and your personal bests, and period tracking that stays private.

There's no sign-up. You open it and it's yours. Nothing you put in it ever leaves your phone, and one button in your profile erases all of it. No ads, and nothing in it is sold.

What I need is a bit particular: Google requires 12 testers to stay in the test for 14 days without leaving. So if you say yes, the ask is that you keep it installed for two weeks and open it a few times. Not that you use it every day.

Two steps:
1. Tap this link with the Google account that's on your phone: [OPT-IN LINK]
2. It'll take you to Play. Install from there, not from a search. The test version only arrives through that link.

Five things I'd really like you to try: [5 THINGS]

And when something annoys you, tell me. That's the whole point of this round. I'd rather hear it now than read it in a review later. There's a short form here whenever you have a minute: [FORM LINK]

Thank you. It means a lot.
```

`[OWNER: replace [name], [OPT-IN LINK] and [FORM LINK], and paste the five items from section 3.]`

---

## 2. The message, Arabic

Modern Standard Arabic. Western digits (1, 2, 3), as everywhere else in this product.

```
مرحبًا [الاسم]، أختبر تطبيقًا كنت أبنيه منذ فترة، ويسعدني أن تكوني في المجموعة الأولى.

اسمه Own Hub. تطبيق لياقة بدنية للنساء في مصر: تمارين منزلية، وتسجيل للوجبات من الطعام الذي نأكله فعلًا، وأسبوعك وأفضل أرقامك، وتتبّع للدورة يبقى خاصًا بك.

لا تسجيل فيه. تفتحينه فتجدينه لكِ. ولا يغادر شيء مما تضعينه فيه هاتفك، وفي ملفك زر واحد يمحوه كله. بلا إعلانات، ولا شيء يُباع فيه.

وما أحتاج إليه دقيق بعض الشيء: تشترط Google بقاء 12 مختبِرة في الاختبار 14 يومًا من دون خروج. فإن وافقتِ، فالمطلوب أن يبقى التطبيق مثبّتًا لأسبوعين وأن تفتحيه بين حين وآخر، لا أن تستخدميه كل يوم.

خطوتان:
1. افتحي هذا الرابط بحساب Google الموجود على هاتفك: [رابط الانضمام]
2. سينقلك إلى Play. ثبّتي التطبيق من هناك لا من البحث، فنسخة الاختبار لا تصل إلا عبر هذا الرابط.

خمسة أمور أودّ حقًا أن تجرّبيها: [الأمور الخمسة]

وحين يزعجك شيء، أخبريني. هذا هو الغرض كله من هذه الجولة، وأفضّل أن أسمعه الآن على أن أقرأه في تقييم لاحقًا. وهذه استمارة قصيرة متى تيسّر لك وقت: [رابط الاستمارة]

شكرًا لك. هذا يعني لي الكثير.
```

`[OWNER: استبدلي [الاسم] و[رابط الانضمام] و[رابط الاستمارة]، وألصقي الأمور الخمسة من القسم 3.]`

---

## 3. The five things to try

Each one exercises a decision this product made on purpose, and each produces feedback you can act
on rather than "it's nice". **Every one of them is something this release can actually do.**

### English

```
1. Log something with one tap, then undo it. On Home, count a walk or log one of your usual plates. It saves immediately, with no "are you sure?" You have 5 seconds to undo. Tell me whether 5 seconds is enough, and whether you ever wanted a confirmation instead.

2. Swap a move mid-workout. Start a session in Train and swap an exercise that hurts, bores you, or needs equipment you don't have. The rest timer starts itself between sets. Tell me if the replacement made sense for you.

3. Log a meal two ways. Tap one of your usual plates, then type a sentence like "ful and baladi bread". Tell me which one you'd actually use, and whether it understood the Egyptian dish names.

4. Set up My cycle, then delete just the cycle data. Log a period day and a symptom. Look at what the app offers you on a hard day. Then go to cycle settings and delete the cycle data on its own. The rest should survive untouched. Tell me if anything you expected to be gone is still there, or the reverse.

5. Close it, and come back the next day. Log a few things, then swipe the app away completely and open it the next morning. Everything should be where you left it. Then, when you're ready, go to Profile, Your data, Delete everything, and restart the app: it should be empty and stay empty. Tell me if anything came back that you deleted, or went missing that you didn't.

One more thing: please don't leave the test before it ends. It would drop us below the 12 we need.
```

### Arabic

```
1. سجّلي شيئًا بلمسة واحدة ثم تراجعي عنه. في «اليوم»، احسبي مشية أو سجّلي واحدة من وجباتك المعتادة، فتُحفظ فورًا ومن دون سؤال «هل أنتِ متأكدة؟». ولديك 5 ثوانٍ للتراجع. أخبريني هل تكفي 5 ثوانٍ، وهل تمنّيتِ يومًا رسالة تأكيد بدلًا منها.

2. بدّلي حركة في أثناء التمرين. ابدئي جلسة في «التمرين» وبدّلي حركة تؤلمك أو تملّينها أو تحتاج إلى معدات لا تملكينها. ومؤقّت الراحة يبدأ وحده بين المجموعات. أخبريني هل كان البديل مناسبًا لكِ.

3. سجّلي وجبة بطريقتين. المسي واحدة من وجباتك المعتادة، ثم اكتبي جملة مثل «فول وخبز بلدي». أخبريني أيّهما كنتِ ستستخدمين فعلًا، وهل فهم أسماء الأطباق المصرية.

4. جهّزي «دورتي» ثم احذفي بيانات الدورة وحدها. سجّلي يومًا من الدورة وعرَضًا واحدًا، وانظري ماذا يعرض عليك التطبيق في يوم صعب. ثم ادخلي إلى إعدادات الدورة واحذفي بياناتها وحدها، ويُفترض أن يبقى ما عداها كما هو. أخبريني إن بقي شيء توقّعتِ اختفاءه، أو اختفى شيء توقّعتِ بقاءه.

5. أغلقيه ثم عودي في اليوم التالي. سجّلي بعض الأشياء، ثم أغلقي التطبيق تمامًا وافتحيه في صباح اليوم التالي، ويُفترض أن تجدي كل شيء كما تركتِه. ثم متى شئتِ، ادخلي إلى «ملفي» ثم «بياناتك» ثم «احذفي كل شيء»، وأعيدي تشغيل التطبيق: يُفترض أن يكون فارغًا وأن يبقى فارغًا. أخبريني إن عاد شيء حذفتِه، أو اختفى شيء لم تحذفيه.

وأمر أخير: رجاءً لا تخرجي من الاختبار قبل انتهائه، فذلك ينزل بنا تحت الـ 12 التي نحتاج إليها.
```

### What used to be on this list and is not any more

| Removed | Why |
|---|---|
| "Post something, and use the report and block controls" | The community is switched off in this release. There is nothing to post to |
| "Say a meal out loud" | No speech recogniser is attached. Tapping the microphone offers the keyboard instead |
| "Turn on airplane mode and log a set, it should save anyway" | It does save, and it always would: there is no network in the app at all, so airplane mode changes nothing and tests nothing |
| "Try Export in the Privacy Centre and tell me if the file makes sense" | There is no export. The deletion sheet says so |
| "Please use it in Arabic for at least a day" | She cannot switch languages yet. Put this back the day the language row works, because it is the single most valuable thing an Egyptian tester can check |

Put each one back the day it works.

---

## 4. The feedback form

Keep it short. A long form gets one response on day 2 and nothing afterwards. A Google Form with
these questions, **in both languages on the same form**, takes about three minutes.

| # | Question | Type |
|---|---|---|
| 1 | Which phone are you using? | Short text |
| 2 | Did anything crash, freeze, or show empty when it shouldn't? What were you doing? | Long text |
| 3 | **Did anything you logged ever disappear, or come back after you deleted it?** | Long text |
| 4 | The 5-second undo after logging: too short, about right, or too long? | Multiple choice |
| 5 | Did the app understand the meals you typed? | Every time, mostly, rarely, I didn't try it |
| 6 | Was there a moment you expected something to happen and it didn't? | Long text |
| 7 | Did anything make you uncomfortable about your privacy? | Long text |
| 8 | If you could change one thing, what? | Long text |
| 9 | Anything else | Long text |

Question 3 is new and it is the one that matters most this round, because persistence is the newest
thing in the build and the hardest to test any other way.

Do two things with the form, not one: send the link in the first message **and** again on day 7. The
day 7 message is where most of the real feedback comes from. By then she has used it, and the novelty
that makes everything seem fine has worn off.

**On Play Console feedback.** Testers can also send feedback through the Play Store listing, and that
channel reaches you privately without affecting your public rating. Mention it, but do not rely on
it. Most people reply on WhatsApp, and that is fine.

---

## 5. Tracking the 14 days

| Day | Do this |
|---|---|
| 0 | Send the invitations. Chase anyone who does not answer within a day, with a one-line nudge, not a second full message |
| 1 | Confirm the opt-in count in Play Console. Anyone who says "I clicked it" but is not showing up used the wrong Google account. Fix it now, not on day 12 |
| 3 | Short check-in: "did it install okay?" This catches the silent failures |
| 7 | Send the feedback form again |
| 10 | Count the testers. If you are near 12, recruit two more now. A new tester still has time to complete a full stretch before the deadline |
| 14 | Confirm the count held, then apply for production access |

`[OWNER: the opt-in count and the days remaining are both visible in Play Console, Testing, Closed
testing. Check them weekly rather than trusting replies. People say yes and forget.]`

---

## 6. Applying for production access

After 14 continuous days with 12 or more opted in, the Play Console dashboard offers "Apply for
production access". You answer questions about how you recruited testers, what feedback you got, what
you changed, and why the app is ready.

**Write real answers with specifics.** Name the bugs the testers found, the version numbers you
shipped during the test, and what each one fixed. Generic answers get denied, and Google usually
responds within 7 days either way.

Keep a running note during the fortnight so you are not reconstructing it on day 14.

---

## What only you can do

| # | What |
|---|---|
| 1 | Decide whether to fix the language row before inviting anyone, and whether to fix the dead controls first |
| 2 | The opt-in link, the feedback form and the support contact |
| 3 | Recruit 15 to 18 women who would actually use this |
