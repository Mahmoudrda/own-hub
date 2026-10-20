// VERIFICATION_SPEC §9.3 requirement 1:
//   "a client cannot write any verification field, claim-like field, hash,
//    flag, or config"
//
// and §5: "deny all client writes to verification, consent, hash, flag, and
// config data".
//
// Every server-only collection is probed from the MOST privileged client the
// product can mint — a verified admin coach — because a rule that holds for an
// anonymous caller and folds for a staff account is not a rule.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, admin, uid,
  assertSucceeds, assertFails, observe, assert, SYNTHETIC_NID,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
  serverTimestamp,
} from 'firebase/firestore';

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

// Every server-only path named in the rules, with a plausible payload.
const SERVER_ONLY = [
  ['verificationJobs/job_0001', { uid: uid.her, state: 'approved' }],
  [`nidRegistry/${SYNTHETIC_NID.hash}`, { uid: uid.her, banned: false }],
  ['verification_flags/flag_0001', { uid: uid.her, reason: ['face_mismatch'] }],
  ['verificationSessions/sess_0001', { uid: uid.her, challenge: ['left'] }],
  [`verificationLedger/${uid.her}`, { spentMicroUsd: 0 }],
  [`verificationBehaviour/${SYNTHETIC_NID.hash}`, { attempts: 0 }],
  [`verificationInstalls/${SYNTHETIC_NID.hash}`, { installs: 1 }],
  ['verificationStats/2026-09-25', { sessions: 0 }],
  ['verificationEvidenceAccess/entry_0001', { adminUid: uid.admin }],
  ['verificationConfig/thresholds', { faceMatch: 0.9 }],
  [`assistantQuota/${uid.her}`, { asked: 0 }],
  ['verificationPreapproved/+201001234567', { phone: '+201001234567' }],
  [`verificationReviewers/${uid.admin}`, { listed: true }],
  ['verificationBookings/slot_0001', { uid: uid.her, reviewerId: uid.admin }],
];

describe('server-only collections are closed in both directions', () => {
  for (const [path, payload] of SERVER_ONLY) {
    test(`${path} — denied to a verified admin`, async () => {
      const db = await admin(uid.admin);
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), payload));
      await assertFails(updateDoc(doc(db, path), payload));
      await assertFails(deleteDoc(doc(db, path)));
    });

    test(`${path} — denied to an ordinary verified woman and to anon`, async () => {
      const her = await verified(uid.her);
      const nobody = await anon();
      await assertFails(getDoc(doc(her, path)));
      await assertFails(setDoc(doc(her, path), payload));
      await assertFails(getDoc(doc(nobody, path)));
      await assertFails(setDoc(doc(nobody, path), payload));
    });
  }

  test('server-only collections are not listable either', async () => {
    const db = await admin(uid.admin);
    for (const name of [
      'verificationJobs', 'nidRegistry', 'verification_flags',
      'verificationSessions', 'verificationLedger', 'verificationConfig',
      'verificationEvidenceAccess', 'assistantQuota',
      'verificationPreapproved', 'verificationReviewers',
      'verificationBookings',
    ]) {
      await assertFails(getDocs(collection(db, name)));
    }
  });

  test('a seeded flag stays unreadable — the deny is not just "empty"', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'verification_flags/flag_seeded'), {
        uid: uid.her, reason: ['age_mismatch'], score: 0.41,
      });
    });
    const db = await admin(uid.admin);
    await assertFails(getDoc(doc(db, 'verification_flags/flag_seeded')));
  });
});

describe('the consent record', () => {
  test('a client may READ her own consents (PDPL right of access)', async () => {
    await seed(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${uid.her}/consents/c1`),
        { policyVersion: 3, grantedAt: new Date(), hash: 'server_side_hash' },
      );
    });
    const db = await verified(uid.her);
    await assertSucceeds(getDoc(doc(db, `users/${uid.her}/consents/c1`)));
    await assertSucceeds(getDocs(collection(db, `users/${uid.her}/consents`)));
  });

  test('a client may NOT write, amend or delete a consent record', async () => {
    const db = await verified(uid.her);
    await assertFails(
      setDoc(doc(db, `users/${uid.her}/consents/c2`), { policyVersion: 3 }),
    );
    await assertFails(
      updateDoc(doc(db, `users/${uid.her}/consents/c1`), { policyVersion: 99 }),
    );
    await assertFails(deleteDoc(doc(db, `users/${uid.her}/consents/c1`)));
  });

  test('N7: the review-route consent is hers to read, never to write, even unverified', async () => {
    await seed(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${uid.her}/consents/review-v1`),
        { version: 1, at: new Date(), path: 'declined' },
      );
    });
    const db = await unverified(uid.her);
    await assertSucceeds(getDoc(doc(db, `users/${uid.her}/consents/review-v1`)));
    await assertFails(
      setDoc(doc(db, `users/${uid.her}/consents/review-v1`), { version: 1, path: 'niqab' }),
    );
    await assertFails(
      updateDoc(doc(db, `users/${uid.her}/consents/review-v1`), { path: 'niqab' }),
    );
    await assertFails(deleteDoc(doc(db, `users/${uid.her}/consents/review-v1`)));
    const other = await verified(uid.other);
    await assertFails(getDoc(doc(other, `users/${uid.her}/consents/review-v1`)));
  });

  test("a client may not read or write ANOTHER woman's consents", async () => {
    const db = await verified(uid.other);
    await assertFails(getDoc(doc(db, `users/${uid.her}/consents/c1`)));
    await assertFails(
      setDoc(doc(db, `users/${uid.her}/consents/c3`), { policyVersion: 1 }),
    );
  });
});

describe('the verification map on users/{uid}', () => {
  test('cannot be born with the document (create)', async () => {
    const db = await unverified(uid.fresh);
    await assertFails(
      setDoc(doc(db, `users/${uid.fresh}`), {
        profile: { goal: 'strength' },
        verification: { status: 'approved', vf: true },
      }),
    );
  });

  test('cannot be added later (update)', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${uid.her}`), { profile: {} });
    });
    const db = await verified(uid.her);
    await assertFails(
      updateDoc(doc(db, `users/${uid.her}`), {
        verification: { status: 'approved' },
      }),
    );
  });

  test('cannot be edited when it already exists', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${uid.her}`), {
        profile: {}, verification: { status: 'pending' },
      });
    });
    const db = await verified(uid.her);
    await assertFails(
      updateDoc(doc(db, `users/${uid.her}`), {
        'verification.status': 'approved',
      }),
    );
  });

  test('rewards and weeklyGoal are equally untouchable', async () => {
    const db = await verified(uid.her);
    await assertFails(updateDoc(doc(db, `users/${uid.her}`), { rewards: { points: 9999 } }));
    await assertFails(updateDoc(doc(db, `users/${uid.her}`), { weeklyGoal: 1 }));
    const fresh = await unverified(uid.fresh);
    await assertFails(
      setDoc(doc(fresh, `users/${uid.fresh}`), { rewards: { points: 9999 } }),
    );
  });

  test('run counters cannot be written anywhere on users/{uid}', async () => {
    const db = await verified(uid.her);
    for (const key of [
      'streak', 'streakDays', 'dayStreak', 'daysStreak', 'dailyStreak',
      'currentStreak', 'consecutiveDays', 'daysInARow', 'missedDays',
    ]) {
      await assertFails(updateDoc(doc(db, `users/${uid.her}`), { [key]: 7 }));
    }
  });
});

// ---------------------------------------------------------------------------
// The part of requirement 1 the rules do NOT cover. Reported, not asserted
// away: these run as observations so the report carries what actually happens.
// ---------------------------------------------------------------------------

describe('OBSERVED: claim-like and hash-like fields on users/{uid}', () => {
  test('what a fresh client can put on users/{uid} at CREATE time', async (t) => {
    const results = [];
    const probes = {
      verified_field: { verified: true },
      vf_field: { vf: true },
      vstatus_field: { vstatus: 'APPROVED' },
      admin_field: { admin: true },
      coachV_field: { coachV: 'active' },
      idHmac_field: { idHmac: SYNTHETIC_NID.hash },
      id_hmac_field: { id_hmac: SYNTHETIC_NID.hash },
      nid_plaintext: { nationalId: SYNTHETIC_NID.female },
      flag_field: { verificationFlagId: 'flag_0001' },
      config_field: { verificationConfig: { faceMatch: 0.0 } },
      ledger_field: { verificationLedger: { spentMicroUsd: 0 } },
    };
    let n = 0;
    for (const [label, payload] of Object.entries(probes)) {
      const who = `w_probe_${n++}`;
      const db = await unverified(who);
      results.push(
        await observe(label, setDoc(doc(db, `users/${who}`), {
          profile: { goal: 'strength' }, ...payload,
        })),
      );
    }
    for (const r of results) t.diagnostic(`  create users/{uid} + ${r.label}: ${r.outcome}`);
    // Recorded, not judged here. The report states the finding.
    assert.equal(results.length, Object.keys(probes).length);
    t.diagnostic(
      `  SUMMARY create-time: ${results.filter(r => r.outcome === 'ALLOWED').length}` +
      ` of ${results.length} claim-like/hash-like payloads ALLOWED`,
    );
  });

  test('what an existing client can ADD to users/{uid} by update', async (t) => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${uid.other}`), { profile: {} });
    });
    const db = await verified(uid.other);
    const results = [];
    for (const [label, payload] of Object.entries({
      verified_field: { verified: true },
      admin_field: { admin: true },
      idHmac_field: { idHmac: SYNTHETIC_NID.hash },
      inside_profile: { 'profile.verified': true },
      inside_profile_hmac: { 'profile.idHmac': SYNTHETIC_NID.hash },
    })) {
      results.push(
        await observe(label, updateDoc(doc(db, `users/${uid.other}`), payload)),
      );
    }
    for (const r of results) t.diagnostic(`  update users/{uid} + ${r.label}: ${r.outcome}`);
    assert.equal(results.length, 5);
  });
});
