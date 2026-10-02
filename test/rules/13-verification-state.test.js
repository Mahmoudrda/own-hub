// S8. users/{uid}.verification is server-written and hers to read. The review
// queue, the ledger and the deletion record stay closed to every client.

import { test, describe, before, after, beforeEach } from 'node:test';
import {
  doc, setDoc, getDoc, updateDoc, serverTimestamp,
} from 'firebase/firestore';
import {
  getEnv, clearAll, seed, verified, unverified, admin, uid,
  assertSucceeds, assertFails, assert,
} from './harness.js';

const HER = uid.her;
const OTHER = uid.other;

async function seedState(state) {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${HER}`), {
      verification: {
        state, updatedAt: new Date(), reviewRoute: 'video',
        reviewScheduledFor: new Date('2026-10-05T08:00:00Z'),
      },
    });
  });
}

before(async () => { await getEnv(); });
beforeEach(async () => { await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('her verification state', () => {
  test('she can read it while unverified (C14 needs it)', async () => {
    await seedState('pending');
    const db = await unverified(HER);
    const snap = await assertSucceeds(getDoc(doc(db, `users/${HER}`)));
    assert.equal(snap.data().verification.state, 'pending');
    assert.equal(snap.data().verification.reviewRoute, 'video');
  });

  test('she cannot write it, on create or update', async () => {
    const fresh = await unverified(uid.fresh);
    await assertFails(setDoc(doc(fresh, `users/${uid.fresh}`), {
      verification: { state: 'approved' }, updatedAt: serverTimestamp(),
    }));
    await seedState('pending');
    const db = await unverified(HER);
    await assertFails(updateDoc(doc(db, `users/${HER}`), { 'verification.state': 'approved' }));
    await assertFails(setDoc(doc(db, `users/${HER}`), {
      verification: { state: 'approved' },
    }, { merge: true }));
  });

  test('a verified woman cannot rewrite it either', async () => {
    await seedState('rejected');
    const db = await verified(HER);
    await assertFails(updateDoc(doc(db, `users/${HER}`), { 'verification.state': 'retry' }));
  });

  test('another woman cannot read it', async () => {
    await seedState('rejected');
    const db = await verified(OTHER);
    await assertFails(getDoc(doc(db, `users/${HER}`)));
  });
});

describe('the server-only collections stay closed', () => {
  const CLOSED = [
    ['verification_flags/f1', { uid: HER, state: 'PENDING_REVIEW' }],
    [`verificationLedger/${HER}`, { openFlagId: null, bonusOcrSubmissions: 9 }],
    [`deletionRequests/${HER}`, { state: 'done' }],
    ['verificationReviewAccess/a1', { flagId: 'f1', action: 'contact' }],
    ['verificationStats/2026-10-02_s3', { verifications: 0 }],
  ];

  for (const [path, payload] of CLOSED) {
    test(`${path}: no client write, even an admin`, async () => {
      for (const db of [await unverified(HER), await verified(HER), await admin(uid.admin)]) {
        await assertFails(setDoc(doc(db, path), payload));
      }
    });
  }

  test('flags and the ledger are not readable by her', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'verification_flags/f1'), { uid: HER });
      await setDoc(doc(ctx.firestore(), `verificationLedger/${HER}`), { openFlagId: 'f1' });
    });
    const db = await verified(HER);
    await assertFails(getDoc(doc(db, 'verification_flags/f1')));
    await assertFails(getDoc(doc(db, `verificationLedger/${HER}`)));
  });

  test('she may watch her own deletion record, not another', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `deletionRequests/${HER}`), { state: 'purgingFirestore' });
    });
    await assertSucceeds(getDoc(doc(await unverified(HER), `deletionRequests/${HER}`)));
    await assertFails(getDoc(doc(await verified(OTHER), `deletionRequests/${HER}`)));
  });
});
