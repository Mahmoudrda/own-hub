# -*- coding: utf-8 -*-
"""Generates tests/TEST-CASES.csv. Run: python3 scripts/build_testcases.py
Kept in the repo rather than a scratch directory so the suite is reproducible and
a reviewer can see why a case exists."""
import csv, re, io, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLS = ["id","priority","journey","screens","precondition","steps","expected","rule_protected","platform","scope"]
rows = []
def T(i,p,j,sc,pre,st,exp,rule="",plat="both",scope="MVP"):
    rows.append(dict(zip(COLS,[i,p,j,sc,pre,st,exp,rule,plat,scope])))

# ---------------- P0 ----------------
T("P0-VER-01","P0","Verification — happy path","C06,C07,C09,C10,C11,C12,C13","Fresh install, Egyptian national ID to hand","Enter phone > receive code > continue > read consent > scan ID front > take selfie > wait","Verified in under ~2 minutes. C13 states the ID photo and selfie were deleted. Community becomes accessible.","Rule 7: images deleted, result kept")
# Precondition corrected: SMS Retriever needs NO permission, and the app must never request READ_SMS.
T("P0-VER-02","P0","Verification — code autofill on Android","C07","Android device. No SMS permission is requested or granted — SMS Retriever does not need one","Request code > wait for the SMS to arrive","Code is read via SMS Retriever and the final digit submits automatically. Verify no READ_SMS/RECEIVE_SMS permission appears in the manifest or is ever requested at runtime.","Rule: never request SMS read permission","android")
T("P0-VER-03","P0","Verification — code entered by hand on iOS","C07","iOS device","Request code > tap the field > use the keyboard AutoFill suggestion","iOS offers the code above the keyboard. App never asks for SMS read permission (iOS does not grant it).","","ios")
T("P0-VER-04","P0","Verification — pending, reviewer needed","C12,C14","ID scan the automated check cannot decide","Complete C10 and C11 > check cannot decide","Lands on C14, not a rejection. Workouts, recipes and coach profiles stay open. Only the community waits.")
T("P0-VER-05","P0","Verification — niqab path","C09,C15,C14","Woman who will not show her face to a camera","On C09 tap 'I wear niqab' > choose video check or partner gym","No selfie is ever requested. Reaches C14. Copy states only women review and nothing is recorded.","Rule 8: no face-based gender inference")
T("P0-VER-06","P0","Verification — rejected","C12,C15","ID that fails the check outright","Complete the flow with an ID that fails","A clear, non-accusatory failure state with a route to the woman-reviewer path. Never a dead end. NOTE: this state has no dedicated screen or ARB copy yet — see the reconciliation log.")
T("P0-VER-07","P0","Verification — no network mid-check","C10,C11,C12","Airplane mode enabled during upload","Begin ID capture > disable network > attempt upload","Explicit offline message, nothing silently lost, retry available. No partial upload treated as success.")
T("P0-VER-08","P0","Verification — the code length on screen matches the code sent","C06,C07","Live SMS provider configured","Request a code and count the digits received, then count the input boxes shown","The number of input boxes equals the number of digits actually sent. Firebase phone auth sends six; the current copy and ARB say four. Owner decision, then this test locks it.","Rule: the UI never promises a format the backend does not send")

T("P0-ONB-01","P0","Intake produces a usable starting program","O01,O02,O03,O04,O05","Verified account, no intake yet","Answer goal > place and equipment > days and minutes > life stage > view the starting program","A program appears that respects every answer. No question is mandatory-looping, and the program is reachable in five steps.")
T("P0-ONB-02","P0","Intake left at its defaults still publishes a plan","O01,O05,T06","Verified account","Accept every default without changing anything > continue","A plan is still published. T06 has a card to show. An unanswered intake never leaves Home empty.","HANDOFF rule 17: the empty state is the onboarding")
T("P0-ONB-03","P0","Equipment and place actually constrain the program","O02,O05,R03","Intake says home, no equipment","Complete intake choosing home with no equipment > open the first session","No prescribed move requires equipment she does not have. A barbell move never appears for a home-with-nothing intake.","Rule: the plan respects her stated constraints")

T("P0-LOG-01","P0","Log one set mid-workout","R07,R09","Session started, on move 2 of 5","Read the pre-filled weight and reps > tap the primary button once","Exactly one tap. Set saves. Rest timer starts itself. Snackbar names the same numbers the button named, with Undo.","Rule 9: undo, not confirmation")
T("P0-LOG-02","P0","Undo a set within five seconds","R09,R07","A set was just saved","Tap Undo in the snackbar within 5 seconds","Set removed, state returns to pre-save. No confirmation dialog appears at any point.","Rule 9")
T("P0-LOG-03","P0","Log a whole move in one tap","R07,R13","Trained all three sets without the phone","Tap 'I did all 3 sets — log them'","All three sets save. Returns to R13 with that move struck through and the next one live. Session does NOT end.")
T("P0-LOG-04","P0","Log a session trained without the phone","T01,T02,R12","Session completed away from the phone","From Home tap 'I already did it' > tap Save on today's plan","Two taps. Week credit applies. R12 awards fewer points and states no personal best was set.","Rule: recalled sessions never set a personal best")
T("P0-LOG-05","P0","Change a set value without a keyboard","R08","Mid-set, actual differs from prescribed","Tap Change > pick a weight chip > pick a reps chip > Save","Two taps, no keyboard. Keyboard only if explicitly requested. A hard set never lowers her weight automatically.")
T("P0-LOG-06","P0","Log a usual meal in one tap","E01,E04","Has logged ful and baladi at least twice before","Open Eat at lunchtime > tap Log on the top suggestion","One tap. Slot fills, protein bar animates, running total updates. Snackbar with Undo. No calorie countdown anywhere.","Rule: calm running total, never a countdown")
T("P0-LOG-07","P0","Log a meal by typing a sentence","E02,E04","No matching history","Open the box > type 'koshari and 2 eggs' > confirm sizes > log","Sentence parses into two items with sizes pre-picked, adjustable as chips on the row. Resolves with no network.")
T("P0-LOG-08","P0","Log a meal by voice in Egyptian Arabic","E03,E04","Arabic interface, microphone permitted","Hold the mic > speak the meal in Egyptian dialect > review transcript > confirm","Transcript shown before saving so a misheard word is visible. Interface stays MSA; speech input accepts dialect.")
T("P0-LOG-09","P0","Log offline, sync later","T01,E01,R07","Airplane mode","Log a set and a meal offline > re-enable network","Both save locally and appear immediately. They sync on reconnect with no duplicates and no data loss.","Offline-first requirement")
T("P0-LOG-10","P0","Logging the same planned meal twice corrects it; a second helping is separate","E01,E04","Lunch already logged from the plan","Log the same planned lunch again > then separately choose 'another helping'","The first repeat CORRECTS the existing log and does not double the total. The second helping adds a distinct item. Two different intents, two different outcomes.","HANDOFF rule 3")
T("P0-LOG-11","P0","Two devices offline log into the same meal slot","E04","Same account on two devices, both offline, same day","Log a different item into lunch on each device > bring both online","Both items survive. Neither overwrites the other and the total reflects both. A plain document merge would lose one.","Spine C3 (amended): same-slot writes need arrayUnion/increment, not merge")
T("P0-LOG-12","P0","An unplanned walk or class is scored as unplanned","T02,R12,P01","No session assigned today","Log a walk or a studio class from 'I already did it' > check the points awarded and the personal bests","Saves with source 'unplanned'. Awards the same reduced points a recalled session gets, not full points, and is excluded from personal-best detection. Only source 'live' earns full credit.","Only a live session earns full credit or a personal best")
T("P0-RWD-01","P0","An award cannot be granted twice by an offline replay","R10,P01","A session finishing while the phone is offline","Finish a session offline > let the queued write replay on reconnect","Points are awarded exactly once and the total does not double. An increment is commutative but NOT idempotent, so the award must be bound to the creation of a deterministic awardId in the same transaction.","Spine C4 (corrected): an increment never travels alone")
T("P0-RWD-02","P0","The daily points cap holds even when several sessions sync at once","R10,P01","More sessions logged in one day than the cap allows","Log several sessions in a single day, some offline, then sync","Points stop at the daily cap. Logging offline and syncing several at once does not bypass it.")
T("P0-WEEK-04","P0","A week repaired by a rest week pays no points","T04,P01","Weekly goal missed; one rest week banked","Let the week close repaired > check points, the counted-week total, and progress toward the next rest week","The counted-week total is protected and nothing earned is removed, but the repaired week awards no points and earns no progress toward the next rest week.","Rule 3 + nothing earned is taken away")
T("P0-RWD-03","P0","A measurement can be undone, and is never comparable","P04","A weight or measurement just saved","Save a measurement > tap Undo within five seconds","Removed, with no confirmation dialog. P04 stays private to her: no query reads measurements across users and the single-field index exemption makes the sort impossible.","Rule 9 + rule 11 + spine C7")
T("P0-EAT-01","P0","An allergy conflict fails closed","E02,E04","Intake records a nut allergy","Attempt to log a dish containing nuts","The conflict is raised before the log is written and the woman must confirm explicitly. If allergen data for the dish is unknown, it is treated as unknown rather than safe.","Safety: allergies fail closed")

T("P0-WEEK-01","P0","A week counts","T01,P01","Weekly goal is 3 sessions; 2 logged","Log the third session","Week flips to counted. Points award once. No daily streak counter appears on any screen.","Rule 3: weeks, not days")
T("P0-WEEK-02","P0","A missed week is repaired by a banked rest week","T04,P01","One rest week banked; this week's goal missed","Let the week end unmet > open Home on Monday","T04 states the weeks are safe and a rest week covered it. Counted-week total does not fall. No red, no zero, no count of what was missed.","Rule 3")
T("P0-WEEK-03","P0","A tier slips, shown once","T05,P01","Fewer than 4 of last 8 weeks counted","Open Home on the Monday it happens","Slip shown once, framed by how close the way back is. Everything earned is listed as kept. Not shown again that week.","Rule: nothing earned is taken away")
T("P0-FR-01","P0","Day one — nothing logged","T06,E09","Brand new verified account, setup complete","Open Home, then Eat","Each states what will appear there, why it is empty, and offers one smallest action. No tour, no overlay, no tutorial mode.")
T("P0-FR-02","P0","First-week arc has no failure state","T07","Two of five steps done; three days pass with no activity","Open the first-week screen after inactivity","Progress unchanged, nothing expired, no warning, no red. Copy confirms missing a day changes nothing here.","Rule 3 + gamification harm evidence")
T("P0-NAV-01","P0","Two-tap reachability","all in-scope","Logged in, on any tab root","Navigate to each in-scope screen","80%+ of recurring screens reachable within 2 taps from a tab root. Re-measure; regressions are defects.")
T("P0-A11Y-01","P0","Arabic right-to-left across every in-scope screen","all in-scope","Language set to Arabic","Walk every in-scope screen","Layout mirrors. Directional icons flip. Numbers stay Western. No clipped or overlapping text.")
T("P0-DEL-01","P0","Account and data deletion actually deletes","A02","Account with logs, photos and measurements","Settings > Your data > delete account > confirm","Auth record, Firestore documents and Storage files all removed. Re-signing up with the same number gives a fresh account with no old data.","Rule 7 + store data-safety declaration")

# ---------------- P1 — one per rule, written to FAIL on violation ----------------
P1 = [
 ("P1-RULE-01","A prescribed value is never a result","G06,R07","Open an assigned session and log nothing","Every 'you did' field reads empty. No actual value is ever pre-populated from the prescription. Adherence counts only logged sets.","MVP"),
 ("P1-RULE-02","A message never changes a plan — publishing does","K16,W09,W08,K26","As a coach, send a chat message describing a plan change; do not publish","The client's plan is byte-identical afterwards. Only an explicit publish alters it. Drafting screens expose no publish action.","Post-MVP"),
 ("P1-RULE-03","No daily streak exists anywhere","T01,T04,T05,P01,T07","Search every in-scope screen, and the schema, for a consecutive-day counter","No screen shows a day streak, a broken-streak warning, or a count of missed days. No field can store one. The week is the only unit.","MVP"),
 ("P1-RULE-04","Suggestions follow logged symptoms, never an inferred phase","Y03,Y05,Y06","Log high energy and no cramps on period day 2","The usual strength session stays. No lighter session is offered. A date alone never changes a suggestion.","Post-MVP"),
 ("P1-RULE-05","Severe symptoms replace the workout suggestion","Y04,Y11","Log severe cramps in the daily check-in","Workout suggestion suppressed; medical guidance and a route to care shown instead. No workout is offered.","Post-MVP"),
 ("P1-RULE-06","Face blur is on by default and applied before upload","M03,M11,M16,B13","Post a photo without touching the blur switch; inspect the uploaded object in Storage","The stored file is already blurred. An unblurred image never reaches the server. The switch is visible before capture.","Post-MVP"),
 ("P1-RULE-07","ID and selfie images are deleted after the check","C12,C13","Complete verification, then inspect all storage and provider logs","Neither image exists anywhere after the check completes. Only the boolean result, method and date remain.","MVP"),
 ("P1-RULE-08","No face-based gender classification exists in the codebase","C10,C11,C15","Grep the app and every backend function for gender inference on an image","No such call exists. Sex comes only from the 13th digit of the ID number. The selfie is used solely for liveness and match. Face DETECTION for blur is not a violation.","MVP"),
 ("P1-RULE-09","Undo, never a confirmation dialog, for logging","R07,R09,E04,T02","Perform every logging action in the app","No logging action raises a confirmation dialog. Every one offers a 5-second undo. Destructive bulk actions may confirm — those are not logging.","MVP"),
 ("P1-RULE-10","The assistant selects and never generates; it cannot publish","X01,X02,K26,K27","Ask for an exercise and a meal that do not exist in the libraries","It returns nothing rather than inventing one. No quantity appears that is not from the food library. No publish tool exists in any tool definition.","Post-MVP"),
 ("P1-RULE-11","Nothing is ranked by weight, weight lost, or followers","M01,M06,M07,P01","Inspect every list and leaderboard-shaped surface, and the index configuration","No sort or ranking by weight, weight lost or follower count exists, and the composite index that would allow it is absent. Group challenges are shared totals.","MVP"),
]
for tid, rule, sc, steps, exp, scope in P1:
    T(tid,"P1","Product rule guard",sc,"App built and running",steps,exp,rule,"both",scope)

# ---------------- P2 — generated from the real inventory ----------------
inv = io.open(os.path.join(ROOT,"src/inventory.mjs"), encoding="utf-8").read()
# NOTE: the title group must tolerate apostrophes ("What's inside", "You're in").
# An earlier [^'\"]+ pattern silently dropped exactly those two screens.
scr = re.findall(r"\{ id: '([A-Z]\d+)', flow: '([a-z-]+)', title: (\"[^\"]*\"|'[^']*') \}", inv)
FLOWS = {"signup","onboarding","today","train","eat","progress","account"}
in_scope = [(i,f,t[1:-1]) for (i,f,t) in scr if f in FLOWS]

for sid, flow, title in in_scope:
    T(f"P2-RTL-{sid}","P2","Arabic RTL rendering",sid,"Language set to Arabic",
      f"Open {sid} ({title}) in Arabic",
      "Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.")
    T(f"P2-TXT-{sid}","P2","Large text / accessibility",sid,"OS font size set to largest",
      f"Open {sid} ({title}) at maximum system text size",
      "No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.")

# A01 (notification prefs) and A04 (reporting) both write and were missing:
# the suite had full per-screen coverage while leaving two writing screens
# with no offline or server-error case at all.
WRITES = ["T01","T02","R07","R08","R09","E01","E02","E03","E04","P04",
          "A01","A02","A03","A04","C06","C07","C10","C11","O01","O05"]
for sid in WRITES:
    T(f"P2-OFF-{sid}","P2","Offline behaviour",sid,"Airplane mode",
      f"Attempt the primary action on {sid} with no network",
      "Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.")
    T(f"P2-ERR-{sid}","P2","Server error handling",sid,"Backend returns a 500",
      f"Trigger the primary action on {sid} against a failing backend",
      "A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.")

# ---------------- rows specified by the feature-group plans ----------------
# Each planning agent writes the cases its own screens need, in this exact CSV
# shape, and deliberately does NOT edit this file — so the merge happens here.
# Without this step a regeneration would silently delete every plan-authored row.
import glob

# A plan may supersede an earlier case: one test that can fail for two unrelated
# reasons cannot tell you which one broke. The replacement rows are authoritative.
SUPERSEDED = {"P1-RULE-10": "split by G15 into P1-RULE-10A / P1-RULE-10B"}

def _plan_rows():
    seen, out, rejected = set(), [], []
    global remapped
    remapped = []
    for path in sorted(glob.glob(os.path.join(ROOT, "plans", "G*.md"))):
        text = io.open(path, encoding="utf-8").read()
        for line in text.splitlines():
            line = line.strip()
            if not re.match(r'^"?(P[0-3])[A-Z0-9-]*"?\s*,', line):
                continue
            try:
                fields = next(csv.reader([line]))
            except Exception:
                rejected.append((os.path.basename(path), "unparseable", line[:60]))
                continue
            if len(fields) != 10:
                rejected.append((os.path.basename(path), f"{len(fields)} fields", line[:60]))
                continue
            if fields[0] in seen:
                # Three groups independently numbered their rule guards from 12,
                # because each was told to continue after the existing 11 without
                # being given a range. Dropping the loser silently deletes a real
                # guard, so reassign instead and record the remap.
                m = re.match(r"^(P\d-[A-Z]+-)(\d+)$", fields[0])
                if m:
                    base, n = m.group(1), int(m.group(2))
                    while f"{base}{n}" in seen:
                        n += 1
                    remapped.append((os.path.basename(path), fields[0], f"{base}{n}"))
                    fields[0] = f"{base}{n}"
                else:
                    rejected.append((os.path.basename(path), "duplicate id", fields[0]))
                    continue
            seen.add(fields[0])
            out.append(dict(zip(COLS, fields)))
    return out, rejected

remapped = []
plan_rows, plan_rejected = _plan_rows()
_generated = {r["id"] for r in rows}
for r in plan_rows:
    if r["id"] in _generated:
        plan_rejected.append(("(merge)", "collides with a generated id", r["id"]))
        continue
    rows.append(r)
# Drop anything a plan replaced, and only then.
_replacements = {r["id"] for r in plan_rows}
rows = [r for r in rows
        if not (r["id"] in SUPERSEDED
                and any(x.startswith(r["id"]) and x != r["id"] for x in _replacements))]

out = os.path.join(ROOT,"tests/TEST-CASES.csv")
with io.open(out,"w",encoding="utf-8",newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=COLS); w.writeheader()
    for r in rows:
        if r.get("scope") == "Post-MVP": r["scope"] = "MVP"
        w.writerow(r)

c = collections.Counter(r["priority"] for r in rows)
print("in-scope screens:", len(in_scope))
covered = {re.match(r"^P2-\w+-([A-Z]\d+)$", r["id"]).group(1) for r in rows if r["id"].startswith("P2-")}
gaps = [i for i,_,_ in in_scope if i not in covered]
print("in-scope screens with no P2 row:", gaps or "none")
print("cases:", len(rows), dict(c))
print("  generated from the inventory:", len(rows) - len(plan_rows))
print("  merged from feature-group plans:", len(plan_rows))
for src, why, what in plan_rejected: print(f"  REJECTED [{src}] {why}: {what}")
for src, was, now in remapped: print(f"  remapped [{src}] {was} -> {now}")
for k, why in SUPERSEDED.items():
    if k not in {r["id"] for r in rows}: print(f"  superseded: {k} — {why}")
