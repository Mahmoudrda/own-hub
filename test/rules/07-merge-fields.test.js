// set(data, SetOptions(mergeFields: [...])) AGAINST onlyTouches(...)
//
// cloud_documents.dart writes users/{uid} with
//
//   mergeFields: const <String>['profile', 'privacy', 'notify', 'updatedAt']
//
// and its comment states the load-bearing claim:
//
//   "a plain `set` would delete them, and a plain merge would DEEP-merge the
//    maps — leaving whatever `privacy` used to hold beside what we just wrote,
//    which is exactly what `validPrivacy()`'s `hasOnly` refuses. Naming the
//    paths replaces each map whole and leaves every other field alone."
//
// Documented behaviour, never executed here. The test that settles it is a
// users/{uid} document that ALREADY holds a stale key inside `privacy`: under
// a named-path replace it disappears and the write passes; under a deep merge
// it survives and hasOnly denies the write.

import { test, before, after, describe, beforeEach } from 'node:test';
import {
  getEnv, clearAll, seed, verified, uid,
  assertSucceeds, assertFails, observe, assert,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, serverTimestamp,
} from 'firebase/firestore';

const HER = uid.her;
const MERGE_FIELDS = ['profile', 'privacy', 'notify', 'updatedAt'];

const NEW_PRIVACY = {
  profileVisible: false, showBests: true,
  blurFacesDefault: true, shareLogsWithCoach: true, policyVersion: 4,
};
const NEW_NOTIFY = {
  push: false, mealNudge: true, quietStart: 1380, quietEnd: 360,
};
const CLIENT_WRITE = () => ({
  profile: { goal: 'fat_loss', setupDone: true, language: 'ar' },
  privacy: NEW_PRIVACY,
  notify: NEW_NOTIFY,
  updatedAt: serverTimestamp(),
});

// The document as sign-up left it: fields this file knows nothing about, plus
// a `privacy` map carrying a key that validPrivacy()'s hasOnly does NOT admit.
async function seedAsSignupLeftIt() {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${HER}`), {
      // Written by sign-up. Must survive.
      createdAt: new Date(),
      signupVersion: 7,
      locale: 'ar-EG',
      // Server-written. Must survive and must not be "touched".
      verification: { status: 'approved', at: new Date() },
      rewards: { points: 120, tier: 'silver' },
      weeklyGoal: 4,
      // The stale key that decides this test.
      privacy: {
        profileVisible: true, showBests: false, blurFacesDefault: false,
        shareLogsWithCoach: false, policyVersion: 2,
        staleLegacyKey: 'left over from an older build',
      },
      notify: { push: true, mealNudge: false, quietStart: 0, quietEnd: 0, legacyToggle: true },
      profile: { goal: 'strength', oldFieldNobodyWritesAnymore: 1 },
    });
  });
}

before(async () => { await getEnv(); await clearAll(); });
beforeEach(seedAsSignupLeftIt);
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('the three ways to write users/{uid}, side by side', () => {
  test('a PLAIN set is denied — it would delete the server-owned fields', async (t) => {
    const db = await verified(HER);
    const r = await observe('setDoc(data) with no options',
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE()));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
  });

  test('a plain MERGE is denied — the stale key survives hasOnly', async (t) => {
    const db = await verified(HER);
    const r = await observe('setDoc(data, {merge: true})',
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { merge: true }));
    t.diagnostic(
      `  ${r.outcome.padEnd(8)} ${r.label} — deep merge leaves ` +
      '`privacy.staleLegacyKey` in place',
    );
    assert.equal(r.outcome, 'DENIED');
  });

  test('NAMED mergeFields is ALLOWED — this is the client\'s claim, proven', async (t) => {
    const db = await verified(HER);
    const r = await observe(
      `setDoc(data, {mergeFields: ${JSON.stringify(MERGE_FIELDS)}})`,
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }),
    );
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });
});

describe('what mergeFields actually did to the document', () => {
  test('named maps are REPLACED WHOLE, not deep-merged', async (t) => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }),
    );
    const after = (await getDoc(doc(db, `users/${HER}`))).data();
    t.diagnostic(`  privacy keys after: ${JSON.stringify(Object.keys(after.privacy).sort())}`);
    t.diagnostic(`  notify  keys after: ${JSON.stringify(Object.keys(after.notify).sort())}`);
    t.diagnostic(`  profile keys after: ${JSON.stringify(Object.keys(after.profile).sort())}`);
    assert.equal(after.privacy.staleLegacyKey, undefined,
      'privacy was deep-merged, not replaced — the client comment is wrong');
    assert.equal(after.notify.legacyToggle, undefined);
    assert.equal(after.profile.oldFieldNobodyWritesAnymore, undefined);
    assert.equal(after.privacy.policyVersion, 4);
  });

  test('every UNNAMED field is left exactly as it was', async (t) => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }),
    );
    const after = (await getDoc(doc(db, `users/${HER}`))).data();
    t.diagnostic(`  top-level keys after: ${JSON.stringify(Object.keys(after).sort())}`);
    assert.equal(after.signupVersion, 7);
    assert.equal(after.locale, 'ar-EG');
    assert.equal(after.weeklyGoal, 4);
    assert.equal(after.verification.status, 'approved');
    assert.equal(after.rewards.points, 120);
  });

  test('the verification map survives untouched — the property that matters', async (t) => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }),
    );
    const after = (await getDoc(doc(db, `users/${HER}`))).data();
    assert.equal(after.verification.status, 'approved');
    t.diagnostic('  a mergeFields write neither reads nor rewrites `verification`');
  });
});

describe('mergeFields cannot be used to widen what a client may write', () => {
  test('naming a field outside the four is denied', async (t) => {
    const db = await verified(HER);
    for (const [label, fields, data] of [
      ['adds `verification`', [...MERGE_FIELDS, 'verification'],
        { ...CLIENT_WRITE(), verification: { status: 'approved' } }],
      ['adds `rewards`', [...MERGE_FIELDS, 'rewards'],
        { ...CLIENT_WRITE(), rewards: { points: 9999 } }],
      ['adds `weeklyGoal`', [...MERGE_FIELDS, 'weeklyGoal'],
        { ...CLIENT_WRITE(), weeklyGoal: 1 }],
      ['adds `streak`', [...MERGE_FIELDS, 'streak'],
        { ...CLIENT_WRITE(), streak: 40 }],
      ['adds an unknown field', [...MERGE_FIELDS, 'nickname'],
        { ...CLIENT_WRITE(), nickname: 'x' }],
    ]) {
      const r = await observe(label,
        setDoc(doc(db, `users/${HER}`), data, { mergeFields: fields }));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${label}`);
      assert.equal(r.outcome, 'DENIED');
    }
  });

  test('a NESTED merge path still has to produce a valid map', async (t) => {
    const db = await verified(HER);
    const r1 = await observe('mergeFields: ["privacy.showBests"] — valid value',
      setDoc(doc(db, `users/${HER}`), { privacy: { showBests: true } },
        { mergeFields: ['privacy.showBests'] }));
    const r2 = await observe('mergeFields: ["privacy.staleLegacyKey"] — keeps the stale key',
      setDoc(doc(db, `users/${HER}`), { privacy: { staleLegacyKey: 'still here' } },
        { mergeFields: ['privacy.staleLegacyKey'] }));
    for (const r of [r1, r2]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    // A nested path deep-merges by definition, so the stale key survives and
    // validPrivacy() refuses. The client naming whole maps is what avoids this.
    assert.equal(r2.outcome, 'DENIED');
  });

  test('mergeFields on a CREATE behaves like a plain create', async (t) => {
    const who = 'w_merge_create_0012';
    const db = await verified(who);
    const r = await observe('mergeFields set on a document that does not exist',
      setDoc(doc(db, `users/${who}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });
});

describe('the invariant mergeFields relies on: changed() on an update', () => {
  test('rewriting a named map with IDENTICAL content is a no-op for diff()', async (t) => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }),
    );
    // Second identical write: affectedKeys() is now just `updatedAt`.
    const r = await observe('identical second write',
      setDoc(doc(db, `users/${HER}`), CLIENT_WRITE(), { mergeFields: MERGE_FIELDS }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });

  test('a mergeFields write that omits `privacy` does not trip validPrivacy', async (t) => {
    const db = await verified(HER);
    const r = await observe('mergeFields: ["profile","updatedAt"] only',
      setDoc(doc(db, `users/${HER}`),
        { profile: { goal: 'maintain' }, updatedAt: serverTimestamp() },
        { mergeFields: ['profile', 'updatedAt'] }));
    t.diagnostic(
      `  ${r.outcome.padEnd(8)} ${r.label} — the stale privacy map is ` +
      'untouched, so !touches([\'privacy\']) short-circuits',
    );
    assert.equal(r.outcome, 'ALLOWED');
  });
});
