// S17. Cycle, period, check-in and measurement documents, and the life-stage
// and allergy keys of her profile, reach the cloud only after she has given
// the separate health-data consent. The consent document is server-written
// (record_health_consent); she can read it and never write it.

import { test, describe, before, after, beforeEach } from 'node:test';
import {
  doc, setDoc, getDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';
import {
  getEnv, clearAll, seed, verified, unverified, uid,
  assertSucceeds, assertFails,
} from './harness.js';

const HER = uid.her;
const OTHER = uid.other;
const DAY = '2026-09-25';
const CONSENT = (who) => `users/${who}/consents/health-v1`;

const HEALTH_WRITES = {
  checkins: [`users/${HER}/checkins/${DAY}`, { energy: 'ok', cramps: 'mild' }],
  measurements: [`users/${HER}/measurements/${DAY}`, {
    weightKg: 60, takenAt: new Date(), schemaV: 1, updatedAt: serverTimestamp(),
  }],
  cycle: [`users/${HER}/cycle/current`, {
    mode: 'symptomsOnly', schemaV: 1, updatedAt: serverTimestamp(),
  }],
  periods: [`users/${HER}/periods/${DAY}`, {
    start: DAY, end: null, stillBleeding: true, schemaV: 1, updatedAt: serverTimestamp(),
  }],
};

const PROFILE_BASE = {
  goal: 'strength', place: 'home', equipment: [], days: 3,
  minutes: 30, setupDone: true, dietary: null, language: 'ar',
};

async function consent(state) {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), CONSENT(HER)), {
      version: 1, state, at: new Date(), withdrawnAt: state === 'withdrawn' ? new Date() : null,
    });
  });
}

before(async () => { await getEnv(); });
beforeEach(async () => { await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('health collections need the health consent', () => {
  for (const [name, [path, payload]] of Object.entries(HEALTH_WRITES)) {
    test(`${name}: denied with no consent`, async () => {
      const db = await verified(HER);
      await assertFails(setDoc(doc(db, path), payload));
    });

    test(`${name}: denied when consent was withdrawn`, async () => {
      await consent('withdrawn');
      const db = await verified(HER);
      await assertFails(setDoc(doc(db, path), payload));
    });

    test(`${name}: allowed when consent is granted`, async () => {
      await consent('granted');
      const db = await verified(HER);
      await assertSucceeds(setDoc(doc(db, path), payload));
    });

    test(`${name}: delete still allowed without consent`, async () => {
      await seed(async (ctx) => { await setDoc(doc(ctx.firestore(), path), payload); });
      const db = await verified(HER);
      await assertSucceeds(deleteDoc(doc(db, path)));
    });
  }
});

describe('profile health keys need the health consent', () => {
  test('a profile without lifeStage or allergies needs no consent', async () => {
    const db = await unverified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}`), {
      profile: PROFILE_BASE, updatedAt: serverTimestamp(),
    }));
  });

  test('a profile with lifeStage is denied without consent', async () => {
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, `users/${HER}`), {
      profile: { ...PROFILE_BASE, lifeStage: 'postpartum' }, updatedAt: serverTimestamp(),
    }));
  });

  test('a profile with allergies is denied without consent', async () => {
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, `users/${HER}`), {
      profile: { ...PROFILE_BASE, allergies: ['nuts'] }, updatedAt: serverTimestamp(),
    }));
  });

  test('a profile with both is allowed with consent', async () => {
    await consent('granted');
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}`), {
      profile: { ...PROFILE_BASE, lifeStage: 'none', allergies: null },
      updatedAt: serverTimestamp(),
    }));
  });

  test('a profile with lifeStage is denied after withdrawal', async () => {
    await consent('withdrawn');
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, `users/${HER}`), {
      profile: { ...PROFILE_BASE, lifeStage: 'pregnant' }, updatedAt: serverTimestamp(),
    }));
  });
});

describe('the consent document itself', () => {
  test('she can read her own consent', async () => {
    await consent('granted');
    const db = await verified(HER);
    await assertSucceeds(getDoc(doc(db, CONSENT(HER))));
  });

  test('she cannot write it, granted or withdrawn', async () => {
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, CONSENT(HER)), { version: 1, state: 'granted', at: new Date() }));
    await consent('granted');
    await assertFails(setDoc(doc(db, CONSENT(HER)), { version: 1, state: 'withdrawn' }));
    await assertFails(deleteDoc(doc(db, CONSENT(HER))));
  });

  test('another woman cannot read it', async () => {
    await consent('granted');
    const db = await verified(OTHER);
    await assertFails(getDoc(doc(db, CONSENT(HER))));
  });

  test("another woman's consent does not open her collections", async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), CONSENT(OTHER)), { version: 1, state: 'granted', at: new Date() });
    });
    const db = await verified(HER);
    const [path, payload] = HEALTH_WRITES.cycle;
    await assertFails(setDoc(doc(db, path), payload));
  });
});
