// VERIFICATION_SPEC §9.3 requirement 2: "an unverified user cannot read or
// write app data" — and the far more dangerous inverse, the SIGN-UP DEADLOCK.
//
// A gate that locks a woman out of getting verified is the worst bug in this
// file, and it is invisible without an evaluator. So this runs both halves:
//
//   A. she CAN complete sign-up while unverified (no deadlock);
//   B. she CANNOT reach app data while unverified (the gate bites);
//   C. the exception set is no wider than the header comment claims.
//
// Part C is where the surprises are.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, unverified, verified, uid,
  assertSucceeds, assertFails, observe, assert,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
  serverTimestamp,
} from 'firebase/firestore';

const HER = uid.fresh;          // signed in, sign-up in progress, NO claim
const DAY = '2026-09-25';
const WEEK = '2026-W39';

const GOOD_PRIVACY = {
  profileVisible: true, showBests: true,
  blurFacesDefault: true, shareLogsWithCoach: false, policyVersion: 3,
};
const GOOD_NOTIFY = {
  push: true, mealNudge: true, quietStart: 1320, quietEnd: 420,
};

// S17: her health-data backup consent (written by record_health_consent in
// production). These tests are about the gate and the field shapes, so they
// run with consent granted; 12-health-consent covers the refusals.
async function grantHealthConsent(who) {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${who}/consents/health-v1`), {
      version: 1, state: 'granted', at: new Date(), withdrawnAt: null,
    });
  });
}

before(async () => { await getEnv(); await clearAll(); await grantHealthConsent(HER); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

// ---------------------------------------------------------------------------
// A. THE DEADLOCK. Every write the verification flow itself needs.
// ---------------------------------------------------------------------------

describe('A. sign-up completes while unverified (no deadlock)', () => {
  test('she can CREATE her own users/{uid} — the first write the app makes', async () => {
    const db = await unverified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}`), {
        profile: {
          goal: 'strength', place: 'home', equipment: [], days: 3,
          minutes: 30, lifeStage: 'none', setupDone: true,
          allergies: null, dietary: null, language: 'ar',
        },
        privacy: GOOD_PRIVACY,
        notify: GOOD_NOTIFY,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('she can READ her own users/{uid} back', async () => {
    const db = await unverified(HER);
    await assertSucceeds(getDoc(doc(db, `users/${HER}`)));
  });

  test('she can UPDATE the four named maps while still unverified', async () => {
    const db = await unverified(HER);
    await assertSucceeds(
      updateDoc(doc(db, `users/${HER}`), {
        profile: { goal: 'fat_loss', setupDone: true },
        privacy: GOOD_PRIVACY,
        notify: GOOD_NOTIFY,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('she can write the plan keys weekdays, level and minutesCustom, and no foreign key', async () => {
    const db = await unverified(HER);
    await assertSucceeds(
      updateDoc(doc(db, `users/${HER}`), {
        profile: {
          goal: 'strength', weekdays: [1, 3, 5], level: 'beginner', minutesCustom: 40,
        },
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, `users/${HER}`), {
        profile: { goal: 'strength', weekdays: [1, 3, 5], verified: true },
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('she can READ the consent trail she gives before the camera opens', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${HER}/consents/c1`), {
        policyVersion: 3, grantedAt: new Date(),
      });
    });
    const db = await unverified(HER);
    await assertSucceeds(getDoc(doc(db, `users/${HER}/consents/c1`)));
    await assertSucceeds(getDocs(collection(db, `users/${HER}/consents`)));
  });

  test('she can WATCH her own deletion request run', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `deletionRequests/${HER}`), {
        state: 'running',
      });
    });
    const db = await unverified(HER);
    await assertSucceeds(getDoc(doc(db, `deletionRequests/${HER}`)));
  });

  test('safety works before anyone checks her ID: block, unblock, report', async () => {
    const db = await unverified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}/blocks/${uid.other}`), {
        createdAt: serverTimestamp(), source: 'message',
      }),
    );
    await assertSucceeds(getDocs(collection(db, `users/${HER}/blocks`)));
    await assertSucceeds(
      setDoc(doc(db, 'reports/r_signup_1'), {
        reporterUid: HER, subjectUid: uid.other, subjectKind: 'user',
        subjectRef: `users/${uid.other}`, reason: 'harassment',
        note: 'during sign up', state: 'submitted',
        createdAt: serverTimestamp(), locale: 'ar', appVersion: '1.0.0',
      }),
    );
    await assertSucceeds(
      deleteDoc(doc(db, `users/${HER}/blocks/${uid.other}`)),
    );
  });

  test('she can read her own report mirror while unverified', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${HER}/myReports/r1`), {
        state: 'submitted',
      });
    });
    const db = await unverified(HER);
    await assertSucceeds(getDocs(collection(db, `users/${HER}/myReports`)));
  });
});

// ---------------------------------------------------------------------------
// B. THE GATE. Everything the product IS, closed until the claim lands.
// ---------------------------------------------------------------------------

describe('B. the gate bites: unverified cannot reach app data', () => {
  const OWN_APP_DATA = [
    [`users/${HER}/checkins/${DAY}`, { energy: 'ok' }],
    [`users/${HER}/sessions/s1`, { source: 'recalled', loggedSetCount: 2 }],
    [`users/${HER}/meals/${DAY}`, { slots: {}, totals: { kcal: 0, protein: 0 } }],
    [`users/${HER}/eatPrefs/current`, { plates: {}, ramadanMode: 'auto' }],
    [`users/${HER}/mealPlans/${WEEK}`, { dinners: {}, groceries: [] }],
    [`users/${HER}/measurements/${DAY}`, {
      weightKg: 60, takenAt: new Date(), schemaV: 1, updatedAt: serverTimestamp(),
    }],
    [`users/${HER}/cycle/current`, {
      mode: 'symptomsOnly', schemaV: 1, updatedAt: serverTimestamp(),
    }],
    [`users/${HER}/periods/${DAY}`, {
      start: DAY, end: null, stillBleeding: true,
      schemaV: 1, updatedAt: serverTimestamp(),
    }],
    [`users/${HER}/splits/sp1`, { ownerKind: 'self' }],
    [`users/${HER}/firstWeek/arc`, {
      hasAnyLog: true,
      steps: { logSet: true, logMeal: false, finishSession: false, joinGroup: false, followUp: false },
    }],
  ];

  for (const [path, payload] of OWN_APP_DATA) {
    test(`${path.replace(HER, '{uid}')} — read and write both denied`, async () => {
      await seed(async (ctx) => {
        await setDoc(doc(ctx.firestore(), path), payload);
      });
      const db = await unverified(HER);
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), payload));
      await assertFails(deleteDoc(doc(db, path)));
    });
  }

  test('server-written progress is unreadable while unverified', async () => {
    const db = await unverified(HER);
    for (const p of [
      `users/${HER}/weeks/${WEEK}`,
      `users/${HER}/bests/squat`,
      `users/${HER}/awards/a1`,
    ]) {
      await assertFails(getDoc(doc(db, p)));
      await assertFails(setDoc(doc(db, p), { x: 1 }));
    }
  });

  test('the community is closed while unverified', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, 'posts/p1'), { authorUid: uid.other, blurred: true });
      await setDoc(doc(d, 'posts/p1/comments/c1'), { authorUid: uid.other });
      await setDoc(doc(d, `publicProfiles/${uid.other}`), { name: 'x' });
      await setDoc(doc(d, 'groups/g1'), { name: 'g' });
      await setDoc(doc(d, `followGraph/${uid.other}/following/${HER}`), { at: 1 });
    });
    const db = await unverified(HER);
    await assertFails(getDoc(doc(db, 'posts/p1')));
    await assertFails(getDocs(collection(db, 'posts')));
    await assertFails(setDoc(doc(db, 'posts/p2'), { authorUid: HER, blurred: true }));
    await assertFails(getDoc(doc(db, 'posts/p1/comments/c1')));
    await assertFails(
      setDoc(doc(db, 'posts/p1/comments/c2'), { authorUid: HER, body: 'hi' }),
    );
    await assertFails(getDoc(doc(db, `publicProfiles/${uid.other}`)));
    await assertFails(getDoc(doc(db, 'groups/g1')));
    await assertFails(getDoc(doc(db, `followGraph/${uid.other}/following/${HER}`)));
  });

  test('the content library is closed while unverified', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      for (const c of ['exercises', 'foods', 'recipes', 'programs']) {
        await setDoc(doc(d, `${c}/x1`), { name: 'x' });
      }
    });
    const db = await unverified(HER);
    for (const c of ['exercises', 'foods', 'recipes', 'programs']) {
      await assertFails(getDoc(doc(db, `${c}/x1`)));
      await assertFails(setDoc(doc(db, `${c}/x2`), { name: 'y' }));
    }
  });

  test('her plans and another coach\'s page are closed while unverified', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `plans/${HER}/published/current`), { version: 1 });
      await setDoc(doc(d, `coaches/${uid.coach}`), { name: 'coach' });
    });
    const db = await unverified(HER);
    await assertFails(getDoc(doc(db, `plans/${HER}/published/current`)));
    await assertFails(getDoc(doc(db, `coaches/${uid.coach}`)));
  });

  test("another woman's data stays closed to a VERIFIED account too", async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${uid.her}/checkins/${DAY}`), {
        energy: 'low',
      });
    });
    const db = await verified(uid.other);
    await assertFails(getDoc(doc(db, `users/${uid.her}/checkins/${DAY}`)));
    await assertFails(getDoc(doc(db, `users/${uid.her}`)));
    await assertFails(getDoc(doc(db, `users/${uid.her}/cycle/current`)));
    await assertFails(getDoc(doc(db, `users/${uid.her}/measurements/${DAY}`)));
    await assertFails(
      setDoc(doc(db, `users/${uid.her}/checkins/${DAY}`), { energy: 'high' }),
    );
  });

  test('an anonymous caller reaches nothing at all', async () => {
    const db = await (await import('./harness.js')).anon();
    await assertFails(getDoc(doc(db, `users/${HER}`)));
    await assertFails(setDoc(doc(db, `users/${HER}`), { profile: {} }));
    await assertFails(getDoc(doc(db, 'posts/p1')));
    await assertFails(getDoc(doc(db, 'exercises/x1')));
    await assertFails(setDoc(doc(db, 'reports/r_anon'), { reporterUid: 'x' }));
    await assertFails(getDoc(doc(db, `plans/${HER}/published/current`)));
  });

  test('the blockedBy mirror is closed to everyone including its owner', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${HER}/blockedBy/${uid.other}`), {
        at: 1,
      });
    });
    for (const db of [await unverified(HER), await verified(HER)]) {
      await assertFails(getDoc(doc(db, `users/${HER}/blockedBy/${uid.other}`)));
      await assertFails(
        setDoc(doc(db, `users/${HER}/blockedBy/${uid.other}`), { at: 2 }),
      );
      await assertFails(
        deleteDoc(doc(db, `users/${HER}/blockedBy/${uid.other}`)),
      );
    }
  });
});

// ---------------------------------------------------------------------------
// C. IS THE EXCEPTION SET NO WIDER THAN THE HEADER COMMENT CLAIMS?
//
// It was not. The header used to name seven exceptions — users/{uid},
// consents, deletionRequests, blocks, blockedBy, myReports and reports
// creation — and ELEVEN more paths were reachable than it documented.
//
// Each has since been decided. Four moved behind the gate (relationships
// create, notices, groups/members write, followGraph create and update) and
// the rest are now named in the header with the reason they are outside it.
// So this test no longer reports a count: it asserts the exact set, and a new
// reachable path fails the suite rather than printing a number nobody reads.
// ---------------------------------------------------------------------------

describe('C. the width of the gate exceptions', () => {
  test('the set of paths an unverified account can reach is exactly the documented one', async (t) => {
    const probes = [
      // ---- Documented exceptions. Each one has a reason in the header.
      ['users/{uid} update', 'ALLOWED', (db) =>
        updateDoc(doc(db, `users/${HER}`), { updatedAt: serverTimestamp() })],
      ['blocks create', 'ALLOWED', (db) =>
        setDoc(doc(db, `users/${HER}/blocks/${uid.blocked}`), {
          createdAt: serverTimestamp(), source: 'profile',
        })],
      ['reports create', 'ALLOWED', (db) =>
        setDoc(doc(db, 'reports/r_width_1'), {
          reporterUid: HER, subjectUid: uid.other, subjectKind: 'user',
          subjectRef: 'x', reason: 'spam', state: 'submitted',
          createdAt: serverTimestamp(),
        })],
      // The push token: registered before the camera opens, and the
      // verification result is delivered to it.
      ['devices write', 'ALLOWED', (db) =>
        setDoc(doc(db, `users/${HER}/devices/d1`), { token: 'tok', platform: 'ios' })],
      ['devices read', 'ALLOWED', (db) =>
        getDoc(doc(db, `users/${HER}/devices/d1`))],
      // The inbox the verification outcome arrives in. Function-written:
      // create and delete are `false`.
      ['notifications update', 'ALLOWED', (db) =>
        updateDoc(doc(db, `users/${HER}/notifications/n1`), { read: true })],
      ['notifications read', 'ALLOWED', (db) =>
        getDocs(collection(db, `users/${HER}/notifications`))],
      // Unfollowing must never be gated, for the same reason it is exempt from
      // notBlockedBy: a lapsed claim must not trap an edge forever.
      ['followGraph delete', 'ALLOWED', (db) =>
        deleteDoc(doc(db, `followGraph/${HER}/following/${uid.other}`))],
      // Taking her own words or her own photograph down is of the same family
      // as blocking and reporting.
      ['posts delete own', 'ALLOWED', (db) =>
        deleteDoc(doc(db, 'posts/p_own'))],
      ['comments delete own', 'ALLOWED', (db) =>
        deleteDoc(doc(db, 'posts/p1/comments/c_own'))],

      // ---- Moved behind the gate. Each was reachable and undocumented.
      ['notices create', 'DENIED', (db) =>
        setDoc(doc(db, `users/${HER}/notices/quietWeek-${WEEK}`), {
          kind: 'quietWeek', forWeek: WEEK, seenAt: serverTimestamp(),
        })],
      ['notices read', 'DENIED', (db) =>
        getDoc(doc(db, `users/${HER}/notices/quietWeek-${WEEK}`))],
      ['groups/members write', 'DENIED', (db) =>
        setDoc(doc(db, `groups/g1/members/${HER}`), { joinedAt: 1 })],
      ['followGraph create', 'DENIED', (db) =>
        setDoc(doc(db, `followGraph/${HER}/following/${uid.other}`), { at: 1 })],
      // The escalation vector. It must never be reachable from here again.
      ['relationships create', 'DENIED', (db) =>
        setDoc(doc(db, `relationships/${uid.coach}__${HER}`), {
          coachUid: uid.coach, clientUid: HER,
        })],
    ];

    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `users/${HER}/notifications/n1`), {
        body: 'x', read: false,
      });
      await setDoc(doc(d, 'posts/p_own'), { authorUid: HER, blurred: true });
      await setDoc(doc(d, 'posts/p1/comments/c_own'), { authorUid: HER });
      await setDoc(doc(d, `followGraph/${HER}/following/${uid.other}`), { at: 1 });
      // A real coach page, so `relationships create` is refused by the GATE
      // and not merely by the missing coach.
      await setDoc(doc(d, `coaches/${uid.coach}`), { name: 'Coach' });
    });

    const db = await unverified(HER);
    for (const [label, expected, op] of probes) {
      const r = await observe(label, op(db));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${label}`);
      assert.equal(r.outcome, expected,
        `${label}: the gate exception set has changed and the header no longer ` +
        'describes it');
    }
  });

  test('a coach whose own verification is pending can still read her page', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `coaches/${uid.coach}`), { name: 'c' });
    });
    const db = await (await import('./harness.js')).unverifiedCoach(uid.coach);
    await assertSucceeds(getDoc(doc(db, `coaches/${uid.coach}`)));
  });
});
