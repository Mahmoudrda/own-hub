// Proves the harness is actually talking to an evaluator, not to nothing.
//
// If these two fail, every other result in this suite is meaningless.

import { test, before, after } from 'node:test';
import {
  getEnv, clearAll, verified, unverified, uid,
  assertSucceeds, assertFails,
} from './harness.js';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

test('the evaluator denies something the rules deny', async () => {
  const db = await verified(uid.her);
  await assertFails(getDoc(doc(db, 'verificationConfig/thresholds')));
});

test('the evaluator allows something the rules allow', async () => {
  const db = await unverified(uid.fresh);
  await assertSucceeds(
    setDoc(doc(db, `users/${uid.fresh}`), {
      profile: { goal: 'strength' },
      updatedAt: serverTimestamp(),
    }),
  );
});
