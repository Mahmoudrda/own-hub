// PRIVILEGE ESCALATION probes.
//
// Everything above asks "is the thing that should be denied, denied?". This
// file asks the opposite question, which is the one that actually matters:
// is anything ALLOWED that should not be?
//
// The lead is the interaction between two rules that are each defensible alone:
//
//   match /relationships/{relId} {
//     allow create: if signedIn()
//                   && request.resource.data.clientUid == request.auth.uid
//                   && notBlockedBy(request.resource.data.coachUid);
//   }
//
//   match /plans/{uid}/{document=**} {
//     allow read: if isSelfVerified(uid)
//                 || exists(/databases/$(database)/documents/relationships/$(request.auth.uid + '__' + uid));
//   }
//
// `relId` was never checked against the document's own coachUid/clientUid, and
// `coachUid` was never checked to be a coach. So the caller chose the
// document id, and the plans rule trusted that id.
//
// CLOSED. Both defences are in place and both are asserted below:
//
//   * relationships create now requires `relId == coachUid + '__' + clientUid`,
//     requires `coachUid` to have a coach page, and requires the `verified`
//     claim — so the forged edge cannot be written at all;
//   * plans read now LOADS the relationship and checks its fields instead of
//     asking whether a document sits at a path the caller computed.
//
// Every step below asserts the denial rather than observing it. If any one of
// them turns ALLOWED again, this file fails.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, unverified, verified, verifiedCoach, uid,
  assertSucceeds, assertFails, observe, assert, switchDormantFeaturesOn,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
  serverTimestamp,
} from 'firebase/firestore';

// The rules behind the community and coach switches (APL-16), tested as they
// will be when the features ship. 16-dormant-features covers the switches.
switchDormantFeaturesOn();

const ATTACKER = uid.attacker;
const VICTIM = uid.victim;

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    // The victim's plans, written by the publishing Function.
    await setDoc(doc(d, `plans/${VICTIM}`), { ownerUid: VICTIM, version: 4 });
    await setDoc(doc(d, `plans/${VICTIM}/published/current`), {
      version: 4,
      weeks: [{ day: 'mon', workoutId: 'w1' }],
      note: 'private training plan',
    });
    await setDoc(doc(d, `plans/${VICTIM}/drafts/d1`), { version: 5 });

    // The legitimate coaching path, so the fix can be shown not to have closed
    // it: a real coach page, and the relationship a Function writes at
    // acceptance. Both are server-written here, which is how they arrive in
    // production too.
    await setDoc(doc(d, `coaches/${uid.coach}`), { name: 'Coach', bio: 'strength' });
    await setDoc(doc(d, `relationships/${uid.coach}__${VICTIM}`), {
      coachUid: uid.coach, clientUid: VICTIM, status: 'active',
    });
  });
});
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe("reading another woman's plans by forging a relationship id", () => {
  test('baseline: the attacker cannot read the victim\'s plans', async () => {
    const db = await verified(ATTACKER);
    await assertFails(getDoc(doc(db, `plans/${VICTIM}/published/current`)));
    await assertFails(getDoc(doc(db, `plans/${VICTIM}`)));
    await assertFails(getDocs(collection(db, `plans/${VICTIM}/published`)));
  });

  test('STEP 1: the attacker creates relationships/{attacker}__{victim}', async (t) => {
    const db = await verified(ATTACKER);
    const r = await observe(
      'forged relationship',
      setDoc(doc(db, `relationships/${ATTACKER}__${VICTIM}`), {
        // clientUid is himself, which is all the rule checks.
        clientUid: ATTACKER,
        // coachUid is himself too — nothing requires it to be a real coach,
        // and notBlockedBy(self) is trivially true.
        coachUid: ATTACKER,
      }),
    );
    t.diagnostic(`  forged relationship create: ${r.outcome}`);
    assert.equal(r.outcome, 'DENIED',
      'THE ESCALATION IS BACK: relationships create accepted a document whose ' +
      'id does not match its own coachUid/clientUid');
  });

  test('STEP 2: the attacker now reads the victim\'s plans', async (t) => {
    const db = await verified(ATTACKER);
    const results = [];
    for (const [label, path] of [
      ['plans/{victim}/published/current', `plans/${VICTIM}/published/current`],
      ['plans/{victim}/drafts/d1', `plans/${VICTIM}/drafts/d1`],
      ['plans/{victim} (root doc)', `plans/${VICTIM}`],
    ]) {
      results.push(await observe(label, getDoc(doc(db, path))));
    }
    const listed = await observe(
      'plans/{victim}/published (list)',
      getDocs(collection(db, `plans/${VICTIM}/published`)),
    );
    results.push(listed);
    for (const r of results) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);

    const leaked = results.filter((r) => r.outcome === 'ALLOWED');
    t.diagnostic(`  SUMMARY: ${leaked.length} of ${results.length} plan reads LEAKED`);
    assert.equal(leaked.length, 0,
      `plan reads leaked again: ${leaked.map((r) => r.label).join(', ')}`);
  });

  test('STEP 2b: the plan text is unreachable, not merely the document', async (t) => {
    // The old finding was that `note: "private training plan"` came back in
    // full. The assertion is now that the read itself never completes.
    const db = await verified(ATTACKER);
    const r = await observe('read the published plan directly',
      getDoc(doc(db, `plans/${VICTIM}/published/current`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
  });

  test('STEP 2c: the SECOND defence holds on its own', async (t) => {
    // Suppose the id constraint were ever relaxed again. The plans rule must
    // still refuse, because it now checks the relationship's FIELDS. So: seed
    // the exact document the attacker used to forge — with rules disabled, the
    // way no client can — and read the plans again.
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `relationships/${ATTACKER}__${VICTIM}`), {
        clientUid: ATTACKER, coachUid: ATTACKER,
      });
    });
    const db = await verified(ATTACKER);
    const r = await observe('plans read with the forged edge PRESENT',
      getDoc(doc(db, `plans/${VICTIM}/published/current`)));
    t.diagnostic(
      `  ${r.outcome.padEnd(8)} ${r.label} — the edge exists at the path the ` +
      'old rule trusted, and its clientUid is not the victim',
    );
    assert.equal(r.outcome, 'DENIED');
  });

  test('STEP 2d: and a coach claim alone is not enough either', async (t) => {
    // A coach account, a relationship document at the trusted path, but the
    // document names someone else as the client.
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `coaches/${uid.coach2}`), { name: 'Coach Two' });
      await setDoc(doc(d, `relationships/${uid.coach2}__${VICTIM}`), {
        coachUid: uid.coach2, clientUid: uid.other, status: 'active',
      });
    });
    const db = await verifiedCoach(uid.coach2);
    const r = await observe('coach reads plans under an edge naming another client',
      getDoc(doc(db, `plans/${VICTIM}/published/current`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
  });

  test('STEP 3: an UNVERIFIED account can do the same thing', async (t) => {
    const db = await unverified('w_unverified_intruder');
    const create = await observe(
      'forged relationship (unverified)',
      setDoc(doc(db, `w_unverified_intruder__${VICTIM}`.replace(/^/, 'relationships/')), {
        clientUid: 'w_unverified_intruder', coachUid: 'w_unverified_intruder',
      }),
    );
    const read = await observe(
      'plans read (unverified)',
      getDoc(doc(db, `plans/${VICTIM}/published/current`)),
    );
    t.diagnostic(`  ${create.outcome.padEnd(8)} ${create.label}`);
    t.diagnostic(`  ${read.outcome.padEnd(8)} ${read.label}`);
    // The whole point of the finding: it worked outside the women-only gate.
    assert.equal(create.outcome, 'DENIED');
    assert.equal(read.outcome, 'DENIED');
  });

  test('STEP 4: the victim cannot see or remove the forged edge', async (t) => {
    const db = await verified(VICTIM);
    const r1 = await observe('victim reads the forged relationship',
      getDoc(doc(db, `relationships/${ATTACKER}__${VICTIM}`)));
    const r2 = await observe('victim lists relationships',
      getDocs(collection(db, 'relationships')));
    const r3 = await observe('victim deletes the forged relationship',
      deleteDoc(doc(db, `relationships/${ATTACKER}__${VICTIM}`)));
    for (const r of [r1, r2, r3]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    // Unchanged by the fix, and deliberately so: a relationship is never
    // client-deletable and the collection is never listable. What HAS changed
    // is that there is nothing for her to find. This still asserts the posture,
    // because "she cannot clean it up" is only acceptable while "he cannot
    // create it" holds.
    assert.equal(r1.outcome, 'DENIED');
    assert.equal(r2.outcome, 'DENIED');
    assert.equal(r3.outcome, 'DENIED');
  });

  test('STEP 5: does blocking him close it?', async (t) => {
    // The victim blocks the attacker. notBlockedBy() reads
    // users/{coachUid}/blocks/{callerUid} — and coachUid is the ATTACKER's own
    // choice, so a block by the victim is never consulted.
    await seed(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${VICTIM}/blocks/${ATTACKER}`),
        { createdAt: new Date(), source: 'safety_centre' },
      );
    });
    const db = await verified(ATTACKER);
    const again = await observe(
      'forge a second edge after being blocked',
      setDoc(doc(db, `relationships/${ATTACKER}__${VICTIM}__2`), {
        clientUid: ATTACKER, coachUid: ATTACKER,
      }),
    );
    const read = await observe(
      'plans read after being blocked',
      getDoc(doc(db, `plans/${VICTIM}/published/current`)),
    );
    t.diagnostic(`  ${again.outcome.padEnd(8)} ${again.label}`);
    t.diagnostic(`  ${read.outcome.padEnd(8)} ${read.label}`);
    assert.equal(again.outcome, 'DENIED');
    assert.equal(read.outcome, 'DENIED');
  });
});

describe('the coaching path the fix must NOT have closed', () => {
  test('a real coach reads her real client\'s plans', async (t) => {
    const coach = await verifiedCoach(uid.coach);
    const results = [];
    for (const [label, path] of [
      ['plans/{client} (root doc)', `plans/${VICTIM}`],
      ['plans/{client}/published/current', `plans/${VICTIM}/published/current`],
      ['plans/{client}/drafts/d1', `plans/${VICTIM}/drafts/d1`],
    ]) results.push(await observe(label, getDoc(doc(coach, path))));
    results.push(await observe('plans/{client}/published (list)',
      getDocs(collection(coach, `plans/${VICTIM}/published`))));
    for (const r of results) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    for (const r of results) {
      assert.equal(r.outcome, 'ALLOWED',
        `the coach can no longer read ${r.label} — the fix broke the feature`);
    }
  });

  test('she reads the content, not an empty shell', async (t) => {
    const coach = await verifiedCoach(uid.coach);
    const snap = await getDoc(doc(coach, `plans/${VICTIM}/published/current`));
    t.diagnostic(`  note=${JSON.stringify(snap.data()?.note)}`);
    assert.equal(snap.data().note, 'private training plan');
  });

  test('a woman with no coach claim cannot, even under the same edge', async (t) => {
    // Same relationship document, same client, but the caller holds no
    // server-minted `coachV`. The claim is checked before any read is billed.
    const notACoach = await verified(uid.coach);
    const r = await observe('same uid, same edge, no coachV claim',
      getDoc(doc(notACoach, `plans/${VICTIM}/published/current`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
  });

  test('the client still reads her own plans', async () => {
    const her = await verified(VICTIM);
    await assertSucceeds(getDoc(doc(her, `plans/${VICTIM}/published/current`)));
    await assertSucceeds(getDocs(collection(her, `plans/${VICTIM}/published`)));
  });

  test('a legitimate relationship can still be opened by the client', async (t) => {
    // The canonical id, a real coach page, the `verified` claim, and none of
    // the three server-written fields. This is the shape the fix permits.
    const her = await verified(uid.her);
    await assertSucceeds(
      setDoc(doc(her, `relationships/${uid.coach}__${uid.her}`), {
        coachUid: uid.coach, clientUid: uid.her,
      }),
    );
    t.diagnostic('  ALLOWED  canonical relId, real coach page, verified client');
  });
});

describe('what the relationships create rule now constrains', () => {
  test('every id and field probe is refused', async (t) => {
    const db = await verified(ATTACKER);
    const probes = [
      ['relId unrelated to the parties', `relationships/totally_made_up_id`,
        { clientUid: ATTACKER, coachUid: uid.coach }],
      ['coachUid is not a coach account', `relationships/${ATTACKER}__${uid.other}`,
        { clientUid: ATTACKER, coachUid: uid.other }],
      ['coachUid does not exist at all', `relationships/${ATTACKER}__ghost`,
        { clientUid: ATTACKER, coachUid: 'no_such_account_at_all' }],
      ['carries a payment map at birth', `relationships/${ATTACKER}__pay`,
        { clientUid: ATTACKER, coachUid: ATTACKER, payment: { paid: true, amount: 0 } }],
      ['carries status at birth', `relationships/${ATTACKER}__st`,
        { clientUid: ATTACKER, coachUid: ATTACKER, status: 'active' }],
      ['carries grantedForRelId at birth', `relationships/${ATTACKER}__gr`,
        { clientUid: ATTACKER, coachUid: ATTACKER, grantedForRelId: 'anything' }],
      ['clientUid is someone else (should be DENIED)', `relationships/${ATTACKER}__no`,
        { clientUid: VICTIM, coachUid: ATTACKER }],
    ];
    for (const [label, path, payload] of probes) {
      const r = await observe(label, setDoc(doc(db, path), payload));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${label}`);
      assert.equal(r.outcome, 'DENIED', label);
    }
  });

  test('a relationship that does not exist unlocks no coaching surface', async (t) => {
    const db = await verified(ATTACKER);
    const r1 = await observe('read a relationship doc that was never created',
      getDoc(doc(db, `relationships/${ATTACKER}__pay`)));
    const r2 = await observe('write a review under it',
      setDoc(doc(db, `relationships/${ATTACKER}__pay/reviews/rev1`), { stars: 5 }));
    const r3 = await observe('write a message under it',
      setDoc(doc(db, `relationships/${ATTACKER}__pay/messages/m1`), {
        senderUid: ATTACKER, body: 'x',
      }));
    for (const r of [r1, r2, r3]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    // isPartyOfParent() loads the parent, so a subcollection under a
    // non-existent relationship is not a writable scratch space.
    for (const r of [r1, r2, r3]) assert.equal(r.outcome, 'DENIED', r.label);
  });
});

describe('assessments: what a coach account can inject', () => {
  // An assessment is a coach's written record of a woman's body, her injuries
  // and her clearance to train. Create carried no field constraints at all,
  // so it could be attributed to another coach, written about a woman who
  // never hired her, or written by a coach who had not passed the gate.
  test('create is now bound to the coach, the client and their relationship', async (t) => {
    const coach = await verifiedCoach(uid.coach);
    const probes = [
      // The happy path: her own uid, her own client, under the relationship
      // seeded above. This one MUST still work.
      ['own assessment for a real client', 'ALLOWED',
        { coachUid: uid.coach, clientUid: VICTIM, answers: {} }],
      ['assessment attributed to ANOTHER coach', 'DENIED',
        { coachUid: uid.coach2, clientUid: VICTIM, answers: {} }],
      ['assessment for a woman who never hired her', 'DENIED',
        { coachUid: uid.coach, clientUid: uid.other, answers: {} }],
      ['assessment with no coachUid at all', 'DENIED',
        { clientUid: VICTIM, answers: {} }],
    ];
    let n = 0;
    for (const [label, expected, payload] of probes) {
      const r = await observe(label,
        setDoc(doc(coach, `assessments/a_${n++}`), payload));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${label}`);
      assert.equal(r.outcome, expected, label);
    }
    const unverifiedCoachDb =
      await (await import('./harness.js')).unverifiedCoach(uid.coach2);
    const r = await observe('an UNVERIFIED coach creates an assessment',
      setDoc(doc(unverifiedCoachDb, 'assessments/a_unverified'),
        { coachUid: uid.coach2, clientUid: VICTIM }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
  });

  test('P0-ASMT-05: a recorded answer cannot be rewritten, only superseded', async (t) => {
    const coach = await verifiedCoach(uid.coach);
    const r1 = await observe('rewrite the answers',
      updateDoc(doc(coach, 'assessments/a_0'), { answers: { clearance: 'fine' } }));
    const r2 = await observe('flip the status to superseded',
      updateDoc(doc(coach, 'assessments/a_0'), { status: 'superseded' }));
    const r3 = await observe('invent a status',
      updateDoc(doc(coach, 'assessments/a_0'), { status: 'deleted' }));
    const r4 = await observe('delete it',
      deleteDoc(doc(coach, 'assessments/a_0')));
    for (const r of [r1, r2, r3, r4]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'DENIED');
    assert.equal(r2.outcome, 'ALLOWED');
    assert.equal(r3.outcome, 'DENIED');
    assert.equal(r4.outcome, 'DENIED');
  });

  test('both named parties can still read it', async () => {
    const coach = await verifiedCoach(uid.coach);
    const client = await verified(VICTIM);
    const stranger = await verified(uid.other);
    await assertSucceeds(getDoc(doc(coach, 'assessments/a_0')));
    await assertSucceeds(getDoc(doc(client, 'assessments/a_0')));
    await assertFails(getDoc(doc(stranger, 'assessments/a_0')));
  });
});
