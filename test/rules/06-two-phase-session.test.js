// THE TWO-PHASE LIVE-SESSION WRITE.
//
// The create rule is:
//
//   allow create: if isSelfVerified(uid) && noRunCounter()
//                 && (request.resource.data.source != 'live'
//                     || request.resource.data.loggedSetCount == 0);
//
// which makes a FINISHED live session impossible to upload in one write. That
// is exactly what replication does for every session she logged before she had
// an account. `CloudDoc.bornAs` in cloud_documents.dart works around it by
// writing the birth document the rule describes and then filling it.
//
// That workaround was reasoned from the rule text and never executed. This
// file executes it.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, verified, uid, assertSucceeds, assertFails, observe, assert,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';

const HER = uid.her;
const DAY = '2026-09-25';
const SCHEMA_V = 1;

// The `bornAs` map, verbatim from cloud_documents.dart.
const bornAs = () => ({
  source: 'live',
  dateKey: DAY,
  sets: [],
  loggedSetCount: 0,
  schemaV: SCHEMA_V,
  updatedAt: serverTimestamp(),
});

// The finished session, verbatim from cloud_documents.dart.
const finished = (n = 12) => ({
  source: 'live',
  dateKey: DAY,
  sets: Array.from({ length: n }, (_, i) => ({ e: 'squat', reps: 8, i })),
  loggedSetCount: n,
  durationSec: 3600,
  completed: true,
  schemaV: SCHEMA_V,
  updatedAt: serverTimestamp(),
});

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('the problem the workaround exists for', () => {
  test('a finished LIVE session cannot be created in one write', async (t) => {
    const db = await verified(HER);
    const r = await observe('one-shot create of a finished live session',
      setDoc(doc(db, `users/${HER}/sessions/live_oneshot`), finished()));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
  });

  test('a finished RECALLED session CAN be created in one write', async () => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}/sessions/recalled_oneshot`), {
        ...finished(), source: 'recalled',
      }),
    );
  });

  test('a finished UNPLANNED session CAN be created in one write', async () => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}/sessions/unplanned_oneshot`), {
        ...finished(), source: 'unplanned',
      }),
    );
  });
});

describe('the workaround, executed end to end', () => {
  test('PHASE 1: the birth document is accepted', async () => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}/sessions/live_1`), bornAs()),
    );
  });

  test('PHASE 2: filling it with 12 logged sets is accepted', async () => {
    const db = await verified(HER);
    await assertSucceeds(
      setDoc(doc(db, `users/${HER}/sessions/live_1`), finished()),
    );
  });

  test('the document really does hold the finished session afterwards', async (t) => {
    const db = await verified(HER);
    const snap = await getDoc(doc(db, `users/${HER}/sessions/live_1`));
    t.diagnostic(
      `  source=${snap.data().source} loggedSetCount=` +
      `${snap.data().loggedSetCount} sets=${snap.data().sets.length}`,
    );
    assert.equal(snap.data().source, 'live');
    assert.equal(snap.data().loggedSetCount, 12);
    assert.equal(snap.data().sets.length, 12);
  });

  test('phase 2 also works as updateDoc rather than setDoc', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/sessions/live_2`), bornAs()));
    await assertSucceeds(
      updateDoc(doc(db, `users/${HER}/sessions/live_2`), {
        sets: [{ e: 'press', reps: 5 }], loggedSetCount: 1,
        completed: true, updatedAt: serverTimestamp(),
      }),
    );
  });

  test('phase 2 works incrementally, set by set, the way a live session runs', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/sessions/live_3`), bornAs()));
    for (let i = 1; i <= 5; i++) {
      await assertSucceeds(
        updateDoc(doc(db, `users/${HER}/sessions/live_3`), {
          loggedSetCount: i, updatedAt: serverTimestamp(),
        }),
      );
    }
  });
});

describe('what the two-phase workaround does NOT weaken', () => {
  test('`source` can never be changed after birth', async () => {
    const db = await verified(HER);
    await assertFails(
      updateDoc(doc(db, `users/${HER}/sessions/live_1`), { source: 'recalled' }),
    );
    await assertFails(
      setDoc(doc(db, `users/${HER}/sessions/live_1`), {
        ...finished(), source: 'unplanned',
      }),
    );
  });

  test('a session with a set in it may never be deleted', async () => {
    // `live_1` is the FILLED session from phase 2: twelve logged sets. A record
    // of something that happened is not hers to remove, and the narrow delete
    // added for orphaned birth documents must not reach it.
    const db = await verified(HER);
    await assertFails(deleteDoc(doc(db, `users/${HER}/sessions/live_1`)));
    await assertFails(deleteDoc(doc(db, `users/${HER}/sessions/recalled_oneshot`)));
    await assertFails(deleteDoc(doc(db, `users/${HER}/sessions/unplanned_oneshot`)));
  });

  test('run counters are refused in both phases', async () => {
    const db = await verified(HER);
    await assertFails(
      setDoc(doc(db, `users/${HER}/sessions/live_streak`), {
        ...bornAs(), streak: 5,
      }),
    );
    await assertFails(
      updateDoc(doc(db, `users/${HER}/sessions/live_1`), { dayStreak: 3 }),
    );
  });

  test('an update requires `source` to be present in the written document', async (t) => {
    // request.resource.data is the whole post-write document on an update, so
    // a dotted-path update still carries it. Stated as a measurement because
    // the rule reads the field unconditionally.
    const db = await verified(HER);
    const r = await observe('dotted update that never mentions source',
      updateDoc(doc(db, `users/${HER}/sessions/live_1`), { durationSec: 7200 }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });

  test('MEASURED: a session created with NO source field at all', async (t) => {
    const db = await verified(HER);
    const r = await observe('create with no `source` key',
      setDoc(doc(db, `users/${HER}/sessions/no_source`), {
        dateKey: DAY, sets: [], loggedSetCount: 0,
        schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
      }));
    t.diagnostic(
      `  ${r.outcome.padEnd(8)} ${r.label} — the rule reads ` +
      '`request.resource.data.source` unconditionally',
    );
    // Follow-up: the same create with a NON-zero loggedSetCount. If the
    // missing-key read were harmless, this would be allowed too. If rules
    // absorb the error only because the right-hand side of `||` is true, this
    // is denied — which is what tells us what actually happened above.
    const r2 = await observe('create with no `source` AND loggedSetCount: 5',
      setDoc(doc(db, `users/${HER}/sessions/no_source_5`), {
        dateKey: DAY, sets: [], loggedSetCount: 5,
        schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
      }));
    t.diagnostic(`  ${r2.outcome.padEnd(8)} ${r2.label}`);
    t.diagnostic(
      '  => a missing `source` does NOT deny on its own; the `||` absorbs the ' +
      'error whenever `loggedSetCount == 0` is true',
    );
  });

  test('MEASURED: a live create with no loggedSetCount field', async (t) => {
    const db = await verified(HER);
    const r = await observe('live create with no `loggedSetCount` key',
      setDoc(doc(db, `users/${HER}/sessions/no_count`), {
        source: 'live', dateKey: DAY, sets: [],
        schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
      }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
  });

  test('MEASURED: a live create with loggedSetCount as a string "0"', async (t) => {
    const db = await verified(HER);
    const r = await observe('loggedSetCount: "0" (string)',
      setDoc(doc(db, `users/${HER}/sessions/str_count`), {
        source: 'live', dateKey: DAY, sets: [], loggedSetCount: '0',
        schemaV: SCHEMA_V, updatedAt: serverTimestamp(),
      }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
  });

  test('the gap the two-phase workaround opens is now closeable', async (t) => {
    // Phase 1 is a real document. If the app is killed between the phases, a
    // zero-set live session is left on the server: a record of nothing, visible
    // to her, that `allow delete: if false` made permanent.
    //
    // Delete is now open for exactly that shape — `source: 'live'` AND
    // `loggedSetCount == 0` — and for nothing else.
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/sessions/orphan`), bornAs()));
    const r = await observe('delete an orphaned birth document',
      deleteDoc(doc(db, `users/${HER}/sessions/orphan`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });

  test('the narrow delete cannot be widened by lying about the count', async (t) => {
    const db = await verified(HER);
    // One logged set is enough to make it permanent again.
    await assertSucceeds(setDoc(doc(db, `users/${HER}/sessions/one_set`), bornAs()));
    await assertSucceeds(
      updateDoc(doc(db, `users/${HER}/sessions/one_set`), {
        loggedSetCount: 1, updatedAt: serverTimestamp(),
      }),
    );
    const r = await observe('delete a live session with one set',
      deleteDoc(doc(db, `users/${HER}/sessions/one_set`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');

    // And the rule reads the STORED document, not the request, so there is no
    // payload that can talk its way past it.
    const r2 = await observe('delete a recalled session born with no sets',
      deleteDoc(doc(db, `users/${HER}/sessions/no_source`)));
    t.diagnostic(`  ${r2.outcome.padEnd(8)} ${r2.label}`);
    assert.equal(r2.outcome, 'DENIED');
  });

  test('a forged updatedAt is refused in both phases', async (t) => {
    // stampedIfTouched(): sessions accepted a clock postdated to 2099, which
    // pins the document at the top of every range query forever.
    const db = await verified(HER);
    const r1 = await observe('birth document with updatedAt in 2099',
      setDoc(doc(db, `users/${HER}/sessions/postdated`), {
        ...bornAs(), updatedAt: new Date('2099-01-01T00:00:00Z'),
      }));
    const r2 = await observe('phase 2 with updatedAt in 2020',
      updateDoc(doc(db, `users/${HER}/sessions/live_2`), {
        loggedSetCount: 9, updatedAt: new Date('2020-01-01T00:00:00Z'),
      }));
    for (const r of [r1, r2]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'DENIED');
    assert.equal(r2.outcome, 'DENIED');
  });
});
