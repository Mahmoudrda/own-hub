// N1. Email/password, Google and Apple sign-in are enabled in the console, so
// an account with no SMS step behind it can exist. Her own data under
// users/{uid} may be created or updated only by a phone sign-in. Reads and
// deletes stay as they were: export and erasure belong to every account.

import { test, describe, before, after, beforeEach } from 'node:test';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';
import {
  getEnv, clearAll, seed, verified, unverified, otherProvider, uid,
  assertSucceeds, assertFails,
} from './harness.js';

const HER = uid.her;
const DAY = '2026-09-25';
const WEEK = '2026-W39';
const PROVIDERS = ['password', 'google.com', 'apple.com', 'anonymous', 'custom'];

const PROFILE = {
  profile: {
    goal: 'strength', place: 'home', equipment: [], days: 3,
    minutes: 30, setupDone: true, dietary: null, language: 'ar',
  },
  updatedAt: serverTimestamp(),
};

// [label, path, payload, needs the verified claim]
const OWNED_WRITES = [
  ['users/{uid}', `users/${HER}`, PROFILE, false],
  ['devices', `users/${HER}/devices/d1`, { token: 'tok', platform: 'ios' }, false],
  ['blocks', `users/${HER}/blocks/${uid.other}`,
    { createdAt: serverTimestamp(), source: 'profile' }, false],
  ['checkins', `users/${HER}/checkins/${DAY}`, { energy: 'ok' }, true],
  ['sessions', `users/${HER}/sessions/s1`, { source: 'recalled', loggedSetCount: 2 }, true],
  ['meals', `users/${HER}/meals/${DAY}`, { slots: {}, totals: { kcal: 0, protein: 0 } }, true],
  ['eatPrefs', `users/${HER}/eatPrefs/current`, { plates: {}, ramadanMode: 'auto' }, true],
  ['mealPlans', `users/${HER}/mealPlans/${WEEK}`, { dinners: {}, groceries: [] }, true],
  ['measurements', `users/${HER}/measurements/${DAY}`,
    { weightKg: 60, takenAt: new Date(), schemaV: 1, updatedAt: serverTimestamp() }, true],
  ['cycle', `users/${HER}/cycle/current`,
    { mode: 'symptomsOnly', schemaV: 1, updatedAt: serverTimestamp() }, true],
  ['periods', `users/${HER}/periods/${DAY}`,
    { start: DAY, end: null, stillBleeding: true, schemaV: 1, updatedAt: serverTimestamp() }, true],
  ['splits', `users/${HER}/splits/sp1`, { ownerKind: 'self' }, true],
  ['notices', `users/${HER}/notices/quietWeek-${WEEK}`,
    { kind: 'quietWeek', forWeek: WEEK, seenAt: serverTimestamp() }, true],
  ['firstWeek', `users/${HER}/firstWeek/arc`, {
    hasAnyLog: true,
    steps: { logSet: true, logMeal: false, finishSession: false, joinGroup: false, followUp: false },
  }, true],
];

async function grantHealthConsent() {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${HER}/consents/health-v1`), {
      version: 1, state: 'granted', at: new Date(), withdrawnAt: null,
    });
  });
}

async function phone(needsVerified) {
  return needsVerified ? verified(HER) : unverified(HER);
}

async function notPhone(provider, needsVerified) {
  return otherProvider(HER, provider, needsVerified ? { verified: true } : {});
}

before(async () => { await getEnv(); });
beforeEach(async () => { await clearAll(); await grantHealthConsent(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('owned-data writes need a phone sign-in', () => {
  for (const [label, path, payload, needsVerified] of OWNED_WRITES) {
    test(`${label}: a phone account may create it`, async () => {
      const db = await phone(needsVerified);
      await assertSucceeds(setDoc(doc(db, path), payload));
    });

    test(`${label}: a password account may not create it`, async () => {
      const db = await notPhone('password', needsVerified);
      await assertFails(setDoc(doc(db, path), payload));
    });
  }

  for (const provider of PROVIDERS) {
    test(`users/{uid}: ${provider} may neither create nor update`, async () => {
      const db = await notPhone(provider, false);
      await assertFails(setDoc(doc(db, `users/${HER}`), PROFILE));
      await seed(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `users/${HER}`), { profile: PROFILE.profile });
      });
      await assertFails(updateDoc(doc(db, `users/${HER}`), { updatedAt: serverTimestamp() }));
    });
  }

  test('a verified password account may not update her meals', async () => {
    const [, path, payload] = OWNED_WRITES.find(([l]) => l === 'meals');
    await seed(async (ctx) => { await setDoc(doc(ctx.firestore(), path), payload); });
    const db = await notPhone('password', true);
    await assertFails(setDoc(doc(db, path), payload));
  });

  test('notifications: marking one read needs a phone sign-in', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${HER}/notifications/n1`), { body: 'x', read: false });
    });
    const other = await notPhone('password', false);
    await assertFails(updateDoc(doc(other, `users/${HER}/notifications/n1`), { read: true }));
    const db = await phone(false);
    await assertSucceeds(updateDoc(doc(db, `users/${HER}/notifications/n1`), { read: true }));
  });
});

describe('reads and deletes stay open to every provider (export and erasure)', () => {
  test('a password account may read her own documents', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `users/${HER}`), { profile: PROFILE.profile });
      await setDoc(doc(d, `users/${HER}/meals/${DAY}`), { slots: {} });
    });
    const plain = await notPhone('password', false);
    await assertSucceeds(getDoc(doc(plain, `users/${HER}`)));
    await assertSucceeds(getDoc(doc(plain, `users/${HER}/consents/health-v1`)));
    const db = await notPhone('password', true);
    await assertSucceeds(getDoc(doc(db, `users/${HER}/meals/${DAY}`)));
  });

  test('a password account may delete what she could delete before', async () => {
    const deletable = [
      [`users/${HER}/devices/d1`, { token: 'tok', platform: 'ios' }, false],
      [`users/${HER}/blocks/${uid.other}`, { createdAt: new Date(), source: 'profile' }, false],
      [`users/${HER}/mealPlans/${WEEK}`, { dinners: {}, groceries: [] }, true],
      [`users/${HER}/cycle/current`, { mode: 'symptomsOnly' }, true],
      [`users/${HER}/checkins/${DAY}`, { energy: 'ok' }, true],
    ];
    await seed(async (ctx) => {
      for (const [path, payload] of deletable) {
        await setDoc(doc(ctx.firestore(), path), payload);
      }
    });
    for (const [path, , needsVerified] of deletable) {
      const db = await notPhone('google.com', needsVerified);
      await assertSucceeds(deleteDoc(doc(db, path)));
    }
  });
});
