// VERIFICATION_SPEC §9.3 requirement 4: "a verified user can use the app."
//
// This is the requirement a suite is most likely to fake, because every other
// test in the file is a denial and a denial is easy. So every collection the
// client writes gets exercised with the EXACT shape
// app/lib/app_state/cloud_documents.dart produces — not a shape invented to
// fit the rule.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, verified, verifiedCoach, uid,
  assertSucceeds, assertFails, observe, assert,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
  serverTimestamp,
} from 'firebase/firestore';

const HER = uid.her;
const DAY = '2026-09-25';
const DAY2 = '2026-09-24';
const WEEK = '2026-W39';
const SCHEMA_V = 1;   // kCloudSchema in cloud_documents.dart

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

describe('her own data — the shapes the client actually writes', () => {
  test('users/{uid} root document', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}`), {
      profile: {
        goal: 'strength', place: 'home', equipment: ['dumbbell'], days: 4,
        minutes: 45, lifeStage: 'none', setupDone: true,
        allergies: null, dietary: null, language: 'ar',
      },
      privacy: {
        profileVisible: true, showBests: false, blurFacesDefault: true,
        shareLogsWithCoach: false, policyVersion: 3,
      },
      notify: { push: true, mealNudge: true, quietStart: 1320, quietEnd: 420, usualMealHour: 14 },
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}`)));
  });

  test('checkins — the six answers, no metadata (as the client writes it)', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/checkins/${DAY}`), {
      energy: 'ok', cramps: 'mild', appetite: 'high',
      sleep: 'good', bloating: 'none', bleeding: 'light',
    }));
    // A partial check-in: unanswered questions are ABSENT keys, never nulls.
    await assertSucceeds(setDoc(doc(db, `users/${HER}/checkins/${DAY2}`), {
      energy: 'low',
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/checkins/${DAY}`)));
    // Rule 9's five-second undo deletes rather than confirms.
    await assertSucceeds(deleteDoc(doc(db, `users/${HER}/checkins/${DAY2}`)));
  });

  test('sessions — a recalled session uploads in ONE write', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/sessions/rec_1`), {
      source: 'recalled', dateKey: DAY, sets: [{ e: 'squat', reps: 8 }],
      loggedSetCount: 1, durationSec: 1800, completed: true,
      schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDocs(collection(db, `users/${HER}/sessions`)));
  });

  test('meals — updatedAt but NO schemaV (as the client writes it)', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/meals/${DAY}`), {
      slots: {
        breakfast: [{ id: 'f1', g: 100 }],
        lunch: [], dinner: [], snack: [],
      },
      totals: { kcal: 1800, protein: 110 },
      firstLogAt: new Date(), tz: 'Africa/Cairo', libVersion: 3,
      skippedAt: ['snack'],
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/meals/${DAY}`)));
  });

  test('eatPrefs — the single `current` document', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/eatPrefs/current`), {
      plates: { hash1: { name: 'koshari', g: 300 } },
      ramadanMode: 'auto', proteinTargetGOverride: 120,
      libVersion: 3, updatedAt: serverTimestamp(),
    }));
  });

  test('mealPlans — the week plan and its grocery list', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/mealPlans/${WEEK}`), {
      dinners: { mon: 'r1', tue: 'r2' },
      groceries: ['rice', 'lentils'], recipeVersion: 2,
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(doc(db, `users/${HER}/mealPlans/${WEEK}`)));
  });

  test('measurements — the one collection that demands full requiredMeta()', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/measurements/${DAY}`), {
      weightKg: 61.4, waistCm: 72, hipsCm: 96,
      takenAt: new Date(), note: 'morning',
      schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/measurements/${DAY}`)));
    await assertSucceeds(deleteDoc(doc(db, `users/${HER}/measurements/${DAY}`)));
  });

  test('cycle — get allowed, list forbidden, and no computed fields', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/cycle/current`), {
      mode: 'datesAndSymptoms', contextFlags: ['postpartum'],
      cycleLengthDays: 28,
      adaptation: { workoutSuggestions: true, mealSuggestions: true, homeCard: true, easierWhenLowEnergy: true },
      sharing: { energyAppetite: false, symptoms: false, datesAndPatterns: false, grantedForRelId: null },
      lastPeriod: { startDate: DAY2, endDate: null },
      recentStarts: [DAY2],
      schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/cycle/current`)));
    // §2.4 at the storage layer.
    await assertFails(getDocs(collection(db, `users/${HER}/cycle`)));
    await assertFails(setDoc(doc(db, `users/${HER}/cycle/current`), {
      mode: 'symptomsOnly', phase: 'luteal',
      schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(doc(db, `users/${HER}/cycle/current`)));
  });

  test('periods — an open period and a closed one', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/periods/${DAY2}`), {
      start: DAY2, end: null, stillBleeding: true,
      schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(doc(db, `users/${HER}/periods/${DAY2}`), {
      start: DAY2, end: DAY, stillBleeding: false,
      schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDocs(collection(db, `users/${HER}/periods`)));
    await assertSucceeds(deleteDoc(doc(db, `users/${HER}/periods/${DAY2}`)));
  });

  test('notices — shown once, never again that week', async () => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}/notices/quietWeek-${WEEK}`), {
        kind: 'quietWeek', forWeek: WEEK, seenAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(doc(db, `users/${HER}/notices/quietWeek-${WEEK}`)));
  });

  test('firstWeek — the arc, with no deadline it can fail against', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/firstWeek/arc`), {
      hasAnyLog: true,
      steps: {
        logSet: true, logMeal: true, finishSession: false,
        joinGroup: false, followUp: false,
      },
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/firstWeek/arc`)));
  });

  test('splits she authored herself', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/splits/sp1`), {
      ownerKind: 'self', name: 'Upper/Lower', days: [],
    }));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/splits/sp1`)));
  });

  test('devices, notifications and her own plans', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/devices/d1`), {
      token: 'tok', platform: 'ios',
    }));
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `users/${HER}/notifications/n1`), { body: 'x', read: false });
      await setDoc(doc(d, `users/${HER}/weeks/${WEEK}`), { points: 30 });
      await setDoc(doc(d, `users/${HER}/bests/squat`), { kg: 60 });
      await setDoc(doc(d, `users/${HER}/awards/a1`), { kind: 'first_week' });
      await setDoc(doc(d, `plans/${HER}/published/current`), { version: 1 });
    });
    await assertSucceeds(getDocs(collection(db, `users/${HER}/notifications`)));
    await assertSucceeds(
      updateDoc(doc(db, `users/${HER}/notifications/n1`), {
        read: true, readAt: new Date(), outcome: 'logged',
      }),
    );
    await assertSucceeds(getDoc(doc(db, `users/${HER}/weeks/${WEEK}`)));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/bests/squat`)));
    await assertSucceeds(getDoc(doc(db, `users/${HER}/awards/a1`)));
    await assertSucceeds(getDoc(doc(db, `plans/${HER}/published/current`)));
  });
});

describe('the community and the library, as a verified woman', () => {
  test('she can browse and post', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, 'posts/p_hers'), {
      authorUid: HER, blurred: true, body: 'first session done',
      createdAt: new Date(),
    }));
    await assertSucceeds(getDoc(doc(db, 'posts/p_hers')));
    await assertSucceeds(getDocs(collection(db, 'posts')));
    await assertSucceeds(updateDoc(doc(db, 'posts/p_hers'), { body: 'edited' }));
    // Counts are server-maintained.
    await assertFails(updateDoc(doc(db, 'posts/p_hers'), { counts: { likes: 999 } }));
    await assertFails(updateDoc(doc(db, 'posts/p_hers'), { authorUid: uid.other }));
    await assertSucceeds(deleteDoc(doc(db, 'posts/p_hers')));
  });

  test('she can comment, follow, join a group and search profiles', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, 'posts/p_other'), { authorUid: uid.other, blurred: true });
      await setDoc(doc(d, `publicProfiles/${uid.other}`), { name: 'someone' });
      await setDoc(doc(d, 'groups/g1'), { name: 'Cairo strength' });
    });
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, 'posts/p_other/comments/c1'), {
      authorUid: HER, body: 'well done', createdAt: new Date(),
    }));
    await assertSucceeds(
      setDoc(doc(db, `followGraph/${HER}/following/${uid.other}`), { at: new Date() }),
    );
    await assertSucceeds(
      deleteDoc(doc(db, `followGraph/${HER}/following/${uid.other}`)),
    );
    await assertSucceeds(getDocs(collection(db, 'publicProfiles')));
    await assertSucceeds(getDoc(doc(db, 'groups/g1')));
    await assertSucceeds(setDoc(doc(db, `groups/g1/members/${HER}`), { at: new Date() }));
  });

  test('she can read the content library', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      for (const c of ['exercises', 'foods', 'recipes', 'programs']) {
        await setDoc(doc(d, `${c}/i1`), { name: 'item' });
      }
    });
    const db = await verified(HER);
    for (const c of ['exercises', 'foods', 'recipes', 'programs']) {
      await assertSucceeds(getDoc(doc(db, `${c}/i1`)));
      await assertSucceeds(getDocs(collection(db, c)));
    }
  });

  test('she can browse coaches, offers, portfolios and consented results', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `coaches/${uid.coach}`), { name: 'Coach', rating: 4.8 });
      await setDoc(doc(d, `coaches/${uid.coach}/offers/o1`), { price: 1000 });
      await setDoc(doc(d, `coaches/${uid.coach}/portfolio/v1`), { published: true });
      await setDoc(doc(d, `coaches/${uid.coach}/portfolio/v2`), { published: false });
      await setDoc(doc(d, `coaches/${uid.coach}/results/r1`), { consentState: 'granted' });
      await setDoc(doc(d, `coaches/${uid.coach}/results/r2`), { consentState: 'withdrawn' });
    });
    const db = await verified(HER);
    await assertSucceeds(getDoc(doc(db, `coaches/${uid.coach}`)));
    await assertSucceeds(getDoc(doc(db, `coaches/${uid.coach}/offers/o1`)));
    await assertSucceeds(getDoc(doc(db, `coaches/${uid.coach}/portfolio/v1`)));
    await assertFails(getDoc(doc(db, `coaches/${uid.coach}/portfolio/v2`)));
    await assertSucceeds(getDoc(doc(db, `coaches/${uid.coach}/results/r1`)));
    await assertFails(getDoc(doc(db, `coaches/${uid.coach}/results/r2`)));
    // She may not edit a coach's page.
    await assertFails(updateDoc(doc(db, `coaches/${uid.coach}`), { rating: 5 }));
  });
});

describe('a verified coach can run her own page', () => {
  test('create, update, and the three fields she may never WRITE', async () => {
    const db = await verifiedCoach(uid.coach2);
    // The three server-written fields are now refused at BIRTH as well as on
    // update, so the create payload no longer carries `coachV`. It never came
    // from the client anyway: `coachV` is a server-minted claim, and grep finds
    // no write of a `coachV` FIELD anywhere in app/lib.
    await assertFails(setDoc(doc(db, `coaches/${uid.coach2}`), {
      name: 'Coach Two', rating: 4.9,
    }));
    await assertFails(setDoc(doc(db, `coaches/${uid.coach2}`), {
      name: 'Coach Two', verifiedCerts: ['NASM'],
    }));
    await assertFails(setDoc(doc(db, `coaches/${uid.coach2}`), {
      name: 'Coach Two', coachV: 'active',
    }));
    await assertSucceeds(setDoc(doc(db, `coaches/${uid.coach2}`), {
      name: 'Coach Two', bio: 'strength',
    }));
    await assertSucceeds(updateDoc(doc(db, `coaches/${uid.coach2}`), { bio: 'new' }));
    await assertFails(updateDoc(doc(db, `coaches/${uid.coach2}`), { rating: 5 }));
    await assertFails(updateDoc(doc(db, `coaches/${uid.coach2}`), { coachV: 'suspended' }));
    await assertFails(updateDoc(doc(db, `coaches/${uid.coach2}`), { verifiedCerts: ['x'] }));
    // A write that does not CHANGE the value is a no-op for diff(), so it is
    // allowed. Correct, and worth stating: the guard is on change, not on
    // presence. The document has no `coachV` to be unchanged, so this uses a
    // field it does hold.
    await assertSucceeds(
      updateDoc(doc(db, `coaches/${uid.coach2}`), { bio: 'new' }),
    );
    await assertSucceeds(setDoc(doc(db, `coaches/${uid.coach2}/offers/o1`), { price: 500 }));
    await assertSucceeds(setDoc(doc(db, `coaches/${uid.coach2}/ads/ad1`), { copy: 'x' }));
    await assertSucceeds(setDoc(doc(db, `coaches/${uid.coach2}/splits/s1`), { name: 'PPL' }));
    // A woman without the coach claim cannot open a coach page.
    const her = await verified(HER);
    await assertFails(setDoc(doc(her, `coaches/${HER}`), { name: 'not a coach' }));
  });

  test("a coach cannot edit another coach's page", async () => {
    const db = await verifiedCoach(uid.coach);
    await assertFails(updateDoc(doc(db, `coaches/${uid.coach2}`), { bio: 'hijacked' }));
    await assertFails(setDoc(doc(db, `coaches/${uid.coach2}/offers/o2`), { price: 0 }));
  });

  test('the three protected fields cannot be present at CREATE time', async (t) => {
    // `allow update` has always named verifiedCerts, coachV and rating.
    // `allow create` was `isSelf(coachUid) && isCoach()` with no field
    // constraint at all, so a coach page could simply be BORN with them — and
    // was: rating=5, verifiedCerts=["NASM","ACE","anything at all"], read back
    // by a verified woman choosing who to train with.
    const who = 'c_born_with_it_0011';
    const db = await verifiedCoach(who);
    const r = await observe('coach page born with rating + verifiedCerts',
      setDoc(doc(db, `coaches/${who}`), {
        name: 'Self-rated', coachV: 'active',
        rating: 5.0, verifiedCerts: ['NASM', 'ACE', 'anything at all'],
      }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');

    const readBack = await verified(uid.her);
    const snap = await getDoc(doc(readBack, `coaches/${who}`));
    t.diagnostic(
      `  a verified woman browsing coaches reads: exists=${snap.exists()}`,
    );
    assert.equal(snap.exists(), false);

    // And the same page without them is accepted, so a coach is not locked out
    // of creating her own profile.
    await assertSucceeds(setDoc(doc(db, `coaches/${who}`), { name: 'Honest' }));
  });
});
