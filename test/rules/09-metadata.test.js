// THE METADATA CONTRADICTION.
//
// requiredMeta() in firebase/firestore.rules declares the K3 contract:
//
//   // G8 §6's contract, stated in prose by G6 §1.2: every client write carries
//   // a schema version and a server-stamped `updatedAt` ...
//   function requiredMeta() {
//     return request.resource.data.schemaV is int && freshStamp();
//   }
//
// But the `checkins` whitelist admits NEITHER key, and the `meals` whitelist
// admits `updatedAt` and not `schemaV`. Reading the file, those cannot all be
// true at once. This builds the matrix empirically: for every collection the
// client writes, does the evaluator REQUIRE schemaV, REJECT it, or ignore it —
// and is `updatedAt` required to come from the server's own clock?
//
// "Server-stamped" is the half that matters. freshStamp() exists because a
// client that can backdate a write can lose another device's edit in a merge,
// and one that can postdate it pins itself at the top of a range query forever.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, verified, uid, observe, assert,
} from './harness.js';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';

const HER = uid.her;
const DAY = '2026-09-25';
const WEEK = '2026-W39';
const SCHEMA_V = 1;
const BACKDATED = new Date('2020-01-01T00:00:00Z');
const POSTDATED = new Date('2099-01-01T00:00:00Z');

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

// Each entry: a base document that is otherwise valid for that collection,
// with no schemaV and no updatedAt.
const COLLECTIONS = {
  checkins: {
    path: (n) => `users/${HER}/checkins/${DAY}`,
    base: () => ({ energy: 'ok', cramps: 'mild' }),
  },
  sessions: {
    path: (n) => `users/${HER}/sessions/meta_${n}`,
    base: () => ({ source: 'recalled', dateKey: DAY, sets: [], loggedSetCount: 0 }),
  },
  meals: {
    path: () => `users/${HER}/meals/${DAY}`,
    base: () => ({ slots: {}, totals: { kcal: 100, protein: 10 }, tz: 'Africa/Cairo' }),
  },
  eatPrefs: {
    path: () => `users/${HER}/eatPrefs/current`,
    base: () => ({ plates: {}, ramadanMode: 'auto', libVersion: 1 }),
  },
  mealPlans: {
    path: () => `users/${HER}/mealPlans/${WEEK}`,
    base: () => ({ dinners: { mon: 'r1' }, groceries: [] }),
  },
  measurements: {
    path: () => `users/${HER}/measurements/${DAY}`,
    base: () => ({ weightKg: 60, takenAt: new Date() }),
  },
  cycle: {
    path: () => `users/${HER}/cycle/current`,
    base: () => ({ mode: 'symptomsOnly' }),
  },
  periods: {
    path: () => `users/${HER}/periods/${DAY}`,
    base: () => ({ start: DAY, end: null, stillBleeding: true }),
  },
  firstWeek: {
    path: () => `users/${HER}/firstWeek/arc`,
    base: () => ({
      hasAnyLog: true,
      steps: { logSet: true, logMeal: false, finishSession: false, joinGroup: false, followUp: false },
    }),
  },
  splits: {
    path: (n) => `users/${HER}/splits/meta_${n}`,
    base: () => ({ ownerKind: 'self', name: 'x' }),
  },
};

// The five shapes that pin down the contract.
const SHAPES = {
  'neither key': () => ({}),
  'schemaV only': () => ({ schemaV: SCHEMA_V }),
  'server updatedAt only': () => ({ updatedAt: serverTimestamp() }),
  'both, server stamp': () => ({ schemaV: SCHEMA_V, updatedAt: serverTimestamp() }),
  'both, BACKDATED updatedAt': () => ({ schemaV: SCHEMA_V, updatedAt: BACKDATED }),
  'both, POSTDATED updatedAt': () => ({ schemaV: SCHEMA_V, updatedAt: POSTDATED }),
  'schemaV as a string': () => ({ schemaV: '1', updatedAt: serverTimestamp() }),
  // The decisive pair. Without these, a denial caused by `schemaV` being
  // outside the whitelist is indistinguishable from one caused by the forged
  // clock — which would make the whole matrix misleading.
  'BACKDATED, no schemaV': () => ({ updatedAt: BACKDATED }),
  'POSTDATED, no schemaV': () => ({ updatedAt: POSTDATED }),
};

const matrix = {};

describe('the K3 metadata matrix, measured', () => {
  for (const [name, spec] of Object.entries(COLLECTIONS)) {
    test(`${name}`, async (t) => {
      const db = await verified(HER);
      matrix[name] = {};
      let n = 0;
      for (const [shape, extra] of Object.entries(SHAPES)) {
        const r = await observe(shape,
          setDoc(doc(db, spec.path(n++)), { ...spec.base(), ...extra() }));
        matrix[name][shape] = r.outcome;
        t.diagnostic(`  ${r.outcome.padEnd(8)} ${shape}`);
      }
    });
  }

  test('THE MATRIX', async (t) => {
    const shapes = Object.keys(SHAPES);
    const w = Math.max(...Object.keys(COLLECTIONS).map((c) => c.length));
    t.diagnostic('');
    t.diagnostic(
      `  ${'collection'.padEnd(w)} | ` +
      shapes.map((s) => s.padEnd(26)).join('| '),
    );
    t.diagnostic(`  ${'-'.repeat(w)}-+-${shapes.map(() => '-'.repeat(26)).join('+-')}`);
    for (const [name, row] of Object.entries(matrix)) {
      t.diagnostic(
        `  ${name.padEnd(w)} | ` +
        shapes.map((s) => (row[s] ?? '?').padEnd(26)).join('| '),
      );
    }
    t.diagnostic('');

    // The three questions the matrix answers.
    const requiresSchemaV = Object.entries(matrix)
      .filter(([, r]) => r['server updatedAt only'] === 'DENIED'
                      && r['both, server stamp'] === 'ALLOWED')
      .map(([n]) => n);
    const rejectsSchemaV = Object.entries(matrix)
      .filter(([, r]) => r['schemaV only'] === 'DENIED'
                      && r['neither key'] === 'ALLOWED')
      .map(([n]) => n);
    // Isolated: compare the no-schemaV clock probes against the shape that
    // differs from them only in the clock.
    const clockBaseline = (r) =>
      r['server updatedAt only'] === 'ALLOWED';
    const requiresServerStamp = Object.entries(matrix)
      .filter(([, r]) => clockBaseline(r) && r['BACKDATED, no schemaV'] === 'DENIED')
      .map(([n]) => n);
    const acceptsBackdating = Object.entries(matrix)
      .filter(([, r]) => r['BACKDATED, no schemaV'] === 'ALLOWED')
      .map(([n]) => n);
    const acceptsPostdating = Object.entries(matrix)
      .filter(([, r]) => r['POSTDATED, no schemaV'] === 'ALLOWED')
      .map(([n]) => n);

    t.diagnostic(`  REQUIRES schemaV:            ${requiresSchemaV.join(', ') || '(none)'}`);
    t.diagnostic(`  REJECTS  schemaV:            ${rejectsSchemaV.join(', ') || '(none)'}`);
    t.diagnostic(`  REQUIRES a server stamp:     ${requiresServerStamp.join(', ') || '(none)'}`);
    t.diagnostic(`  ACCEPTS a BACKDATED clock:   ${acceptsBackdating.join(', ') || '(none)'}`);
    t.diagnostic(`  ACCEPTS a POSTDATED clock:   ${acceptsPostdating.join(', ') || '(none)'}`);
    assert.ok(Object.keys(matrix).length === Object.keys(COLLECTIONS).length);
  });
});

describe('the users/{uid} document, which requiredMeta never reaches', () => {
  test('MEASURED: updatedAt on users/{uid} is not required to be server-stamped', async (t) => {
    const db = await verified(HER);
    const GOOD = {
      profile: { goal: 'strength' },
      privacy: {
        profileVisible: true, showBests: true,
        blurFacesDefault: true, shareLogsWithCoach: false,
      },
      notify: { push: true, mealNudge: true, quietStart: 0, quietEnd: 0 },
    };
    await setDoc(doc(db, `users/${HER}`), { ...GOOD, updatedAt: serverTimestamp() });
    for (const [label, value] of [
      ['server stamp', serverTimestamp()],
      ['BACKDATED to 2020', BACKDATED],
      ['POSTDATED to 2099', POSTDATED],
    ]) {
      const r = await observe(`users/{uid} updatedAt: ${label}`,
        setDoc(doc(db, `users/${HER}`), { ...GOOD, updatedAt: value },
          { mergeFields: ['profile', 'privacy', 'notify', 'updatedAt'] }));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    }
    t.diagnostic(
      '  users/{uid} update calls neither requiredMeta() nor freshStamp()',
    );
  });

  test('MEASURED: schemaV is absent from every users/{uid} path', async (t) => {
    const db = await verified(HER);
    const r = await observe('users/{uid} with a top-level schemaV',
      setDoc(doc(db, `users/${HER}`), { schemaV: 1 },
        { mergeFields: ['schemaV'] }));
    t.diagnostic(
      `  ${r.outcome.padEnd(8)} ${r.label} — ` +
      'schemaV is not in onlyTouches([...]), so the root document can never carry one',
    );
    assert.equal(r.outcome, 'DENIED');
  });
});

describe('notices and blocks use a different stamp helper again', () => {
  test('MEASURED: serverStamped() on blocks.createdAt and notices.seenAt', async (t) => {
    const db = await verified(HER);
    const probes = [
      ['blocks server stamp', `users/${HER}/blocks/${uid.other}`,
        { createdAt: serverTimestamp(), source: 'post' }],
      ['blocks BACKDATED', `users/${HER}/blocks/${uid.blocked}`,
        { createdAt: BACKDATED, source: 'post' }],
      ['notices server stamp', `users/${HER}/notices/quietWeek-${WEEK}`,
        { kind: 'quietWeek', forWeek: WEEK, seenAt: serverTimestamp() }],
      ['notices BACKDATED', `users/${HER}/notices/tierSlip-${WEEK}`,
        { kind: 'tierSlip', forWeek: WEEK, seenAt: BACKDATED }],
    ];
    for (const [label, path, data] of probes) {
      const r = await observe(label, setDoc(doc(db, path), data));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${label}`);
    }
  });
});
