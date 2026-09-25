// VERIFICATION_SPEC §9.3 requirement 3: "a non-admin cannot read flags or
// evidence."
//
// And the stronger posture the rules actually take, which the spec's §5 review
// flow depends on: NOBODY reads the flag queue through Firestore, admin
// included, because the review screen goes through an Admin-SDK callable that
// writes an access-log entry. A directly readable queue is a way to read
// evidence without leaving a trace.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, verifiedCoach, admin,
  uid, assertSucceeds, assertFails, observe, assert, SYNTHETIC_NID,
} from './harness.js';
import {
  doc, getDoc, setDoc, deleteDoc, collection, getDocs, query, where,
} from 'firebase/firestore';

const FLAG_PATHS = [
  'verification_flags/flag_0001',
  'verificationEvidenceAccess/entry_0001',
  'verificationJobs/job_0001',
  `nidRegistry/${SYNTHETIC_NID.hash}`,
];

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'verification_flags/flag_0001'), {
      uid: uid.her, reason: ['face_mismatch', 'age_mismatch'], score: 0.44,
      createdAt: new Date(),
    });
    await setDoc(doc(d, 'verificationEvidenceAccess/entry_0001'), {
      adminUid: uid.admin, flagId: 'flag_0001', at: new Date(),
    });
    await setDoc(doc(d, 'verificationJobs/job_0001'), { uid: uid.her });
    await setDoc(doc(d, `nidRegistry/${SYNTHETIC_NID.hash}`), { uid: uid.her });
  });
});
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('non-admins cannot read flags or evidence', () => {
  const callers = [
    ['anonymous', anon, null],
    ['unverified woman', unverified, uid.her],
    ['verified woman', verified, uid.her],
    ['verified coach', verifiedCoach, uid.coach],
  ];

  for (const [label, make, who] of callers) {
    test(`${label} — every flag and evidence path denied`, async () => {
      const db = who ? await make(who) : await make();
      for (const p of FLAG_PATHS) {
        await assertFails(getDoc(doc(db, p)));
        await assertFails(setDoc(doc(db, p), { tampered: true }));
        await assertFails(deleteDoc(doc(db, p)));
      }
      await assertFails(getDocs(collection(db, 'verification_flags')));
      await assertFails(
        getDocs(query(collection(db, 'verification_flags'),
          where('uid', '==', uid.her))),
      );
    });
  }

  test('a forged `admin` FIELD cannot be written, and would grant nothing anyway', async (t) => {
    // Two separate properties, and the second is the one that must never rely
    // on the first.
    //
    // §01 used to show that a client could write a top-level `admin: true` at
    // create time. It no longer can: `users/{uid}` create now carries the same
    // four-map whitelist as update. That is the fix for the DATA problem.
    //
    // The PRIVILEGE problem was always separate — the rules read
    // request.auth.token.admin, never a document — and it is still asserted
    // here against a document that holds the field, seeded past the rules the
    // way no client can. If the whitelist were ever relaxed, this half would
    // still hold the line.
    const who = 'w_selfstyled_admin';
    const db = await unverified(who);
    await assertFails(
      setDoc(doc(db, `users/${who}`), { profile: {}, admin: true }),
    );
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${who}`), {
        profile: {}, admin: true, verified: true, coachV: 'active',
      });
    });
    for (const p of FLAG_PATHS) await assertFails(getDoc(doc(db, p)));
    t.diagnostic(
      '  the create is refused, and a document field named `admin` confers no ' +
      'rules privilege even when the server put it there',
    );
  });
});

describe('the admin claim itself', () => {
  test('an admin CANNOT read the flag queue directly either (by design)', async (t) => {
    const db = await admin(uid.admin);
    const results = [];
    for (const p of FLAG_PATHS) {
      results.push(await observe(p, getDoc(doc(db, p))));
    }
    results.push(await observe('verification_flags (list)',
      getDocs(collection(db, 'verification_flags'))));
    for (const r of results) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.ok(results.every((r) => r.outcome === 'DENIED'));
    t.diagnostic('  review must go through the Admin-SDK callable, as §5 requires');
  });

  test('the admin claim opens the content library and nothing else', async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `users/${uid.her}`), { profile: { goal: 'x' } });
      await setDoc(doc(d, `users/${uid.her}/cycle/current`), { mode: 'symptomsOnly' });
      await setDoc(doc(d, `plans/${uid.her}/published/current`), { version: 1 });
    });
    const db = await admin(uid.admin);
    // Opens:
    for (const c of ['exercises', 'foods', 'recipes', 'programs']) {
      await assertSucceeds(setDoc(doc(db, `${c}/lib_1`), { name: 'lunge' }));
      await assertSucceeds(getDoc(doc(db, `${c}/lib_1`)));
    }
    // Does not open:
    await assertFails(getDoc(doc(db, `users/${uid.her}`)));
    await assertFails(getDoc(doc(db, `users/${uid.her}/cycle/current`)));
    await assertFails(getDoc(doc(db, `plans/${uid.her}/published/current`)));
    await assertFails(getDoc(doc(db, `deletionRequests/${uid.her}`)));
  });

  test('a verified non-admin cannot write the content library', async () => {
    const db = await verified(uid.her);
    for (const c of ['exercises', 'foods', 'recipes', 'programs']) {
      await assertSucceeds(getDoc(doc(db, `${c}/lib_1`)));   // read is hers
      await assertFails(setDoc(doc(db, `${c}/lib_2`), { name: 'forged' }));
      await assertFails(deleteDoc(doc(db, `${c}/lib_1`)));
    }
  });
});

describe('the moderation queue', () => {
  test('nobody reads reports, at any privilege level', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'reports/r_seeded'), {
        reporterUid: uid.her, subjectUid: uid.other, state: 'submitted',
      });
    });
    for (const db of [
      await verified(uid.her), await verified(uid.other),
      await admin(uid.admin), await verifiedCoach(uid.coach),
    ]) {
      await assertFails(getDoc(doc(db, 'reports/r_seeded')));
      await assertFails(getDocs(collection(db, 'reports')));
    }
  });

  test('a report cannot be edited or withdrawn once filed', async () => {
    const db = await verified(uid.her);
    await assertFails(setDoc(doc(db, 'reports/r_seeded'), { state: 'closed' }));
    await assertFails(deleteDoc(doc(db, 'reports/r_seeded')));
  });
});
