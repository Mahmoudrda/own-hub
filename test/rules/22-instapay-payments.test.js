// InstaPay payments (docs/plan/INSTAPAY-PAYMENTS-SPEC.md, functions/payments).
//
// The service is the only writer of everything here. The client and the coach of
// a payment read it (a query must say whose it is) and its event timeline;
// nothing else is readable by anyone: not the staff documents with the risk
// score and the notes, not the registries of transaction numbers and picture
// hashes, not the amount locks, replay answers, strikes or alerts. A woman reads
// her own profile and standing; a coach her own fee statements. The kill switch
// is readable by any signed-in account and writable by nobody from a client,
// and no payment rule depends on it, so an open payment stays readable and
// resolvable with the switch off. These rules do not sit behind a dormant
// feature switch, so the file is loaded exactly as it ships.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, verifiedCoach, admin, consoleAdmin, uid,
  assertSucceeds, assertFails,
} from './harness.js';
import {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection, query, where,
} from 'firebase/firestore';

const CLIENT = uid.her;
const CLIENT2 = uid.other;
const COACH = uid.coach;
const COACH2 = uid.coach2;
const PAY = 'pay-1';
const NOW = new Date();

const payment = {
  clientUid: CLIENT,
  coachUid: COACH,
  subId: 'sub-1',
  status: 'proof_submitted',
  statusAt: NOW,
  amountPiasters: 50037,
  baseAmountPiasters: 50000,
  reference: 'OH-4821',
  addressSnapshot: { address: 'rahma@instapay', accountName: 'Rahma Mohsen' },
  proof: { txnNumber: '301234567890123', screenshotCount: 2, screenshotPaths: ['payment-proofs/pay-1/client-a-1.jpg'], imageFlags: [] },
  outcome: 'green',
  hint: null,
  access: { state: 'provisional', until: NOW },
  feePiasters: 7500,
  feeState: 'owed',
};

async function seedAll() {
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, `payments/${PAY}`), payment);
    await setDoc(doc(d, `payments/${PAY}/events/e1`), { at: NOW, from: 'awaiting_payment', to: 'proof_submitted', role: 'client', actor: 'client', code: 'proof_green' });
    await setDoc(doc(d, `payments/${PAY}/staff/review`), { riskScore: 40, reasons: ['amountDiffers'], hashes: ['abc'], uniq: { nearImageOf: 'pay-0' } });
    await setDoc(doc(d, `payments/${PAY}/staff/dispute`), { clientNote: 'private words to staff' });
    await setDoc(doc(d, `payments/${PAY}/staff/statement`), { note: 'I looked at my bank', readable: true });
    await setDoc(doc(d, 'payments/pay-2'), { ...payment, clientUid: CLIENT2, coachUid: COACH2, reference: 'OH-9999' });
    for (const name of ['paymentTxnNumbers', 'paymentImageHashes', 'paymentAmountLocks', 'paymentIdempotency', 'paymentStrikes', 'paymentAlerts']) {
      await setDoc(doc(d, `${name}/x1`), { paymentId: PAY, uid: CLIENT, coachRef: 'ref1' });
    }
    await setDoc(doc(d, `coachPaymentProfiles/${COACH}`), { address: 'rahma@instapay', accountName: 'Rahma Mohsen', status: 'ok', autoConfirmGreen: false });
    await setDoc(doc(d, `coachPaymentProfiles/${COACH2}`), { address: 'other@instapay', accountName: 'Other Coach' });
    await setDoc(doc(d, `paymentStanding/${CLIENT}`), { clientStrikes: 1, senderHandle: 'her@instapay' });
    await setDoc(doc(d, `paymentStanding/${COACH}`), { coachStrikes: 0, feeOverdue: false });
    await setDoc(doc(d, `feeStatements/${COACH}__2026-10`), { coachUid: COACH, year: 2026, month: 10, totalDuePiasters: 7500, lines: [], status: 'open' });
    await setDoc(doc(d, `feeStatements/${COACH2}__2026-10`), { coachUid: COACH2, year: 2026, month: 10, totalDuePiasters: 100, lines: [], status: 'open' });
    await setDoc(doc(d, 'config/payments'), { enabled: true, updatedAt: NOW, updatedBy: 'ref' });
  });
}

before(async () => { await getEnv(); await seedAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

const ROLES = {
  client: () => verified(CLIENT),
  coach: () => verifiedCoach(COACH),
  stranger: () => verified(uid.attacker),
  admin: () => admin(uid.admin),
  console: () => consoleAdmin(uid.admin),
};

describe('payments: the two parties read, nobody else', () => {
  test('the client reads her payment and a query that names her uid', async () => {
    const db = await verified(CLIENT);
    await assertSucceeds(getDoc(doc(db, `payments/${PAY}`)));
    await assertSucceeds(getDocs(query(collection(db, 'payments'), where('clientUid', '==', CLIENT))));
  });

  test('the coach reads her payment and a query that names her uid', async () => {
    const db = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(db, `payments/${PAY}`)));
    await assertSucceeds(getDocs(query(collection(db, 'payments'), where('coachUid', '==', COACH))));
  });

  test('an unconstrained list is refused, and so is a query that names someone else', async () => {
    const mine = await verified(CLIENT);
    await assertFails(getDocs(collection(mine, 'payments')));
    await assertFails(getDocs(query(collection(mine, 'payments'), where('clientUid', '==', CLIENT2))));
    await assertFails(getDocs(query(collection(mine, 'payments'), where('coachUid', '==', COACH2))));
  });

  test('another woman, the other coach, an unverified account and a visitor read nothing', async () => {
    for (const db of [await verified(uid.attacker), await verifiedCoach(COACH2), await unverified(CLIENT), await anon()]) {
      await assertFails(getDoc(doc(db, `payments/${PAY}`)));
    }
    const other = await verified(CLIENT2);
    await assertFails(getDoc(doc(other, `payments/${PAY}`)));            // not hers: the proof, the txn number and the address are another woman's
    await assertSucceeds(getDoc(doc(other, 'payments/pay-2')));
  });

  test('the admin and the console owner read no woman\'s payment', async () => {
    await assertFails(getDoc(doc(await admin(uid.admin), `payments/${PAY}`)));
    await assertFails(getDoc(doc(await consoleAdmin(uid.admin), `payments/${PAY}`)));
  });

  test('the timeline is read by the two parties only', async () => {
    await assertSucceeds(getDoc(doc(await verified(CLIENT), `payments/${PAY}/events/e1`)));
    await assertSucceeds(getDocs(collection(await verifiedCoach(COACH), `payments/${PAY}/events`)));
    await assertFails(getDoc(doc(await verified(uid.attacker), `payments/${PAY}/events/e1`)));
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), `payments/${PAY}/events/e1`)));
    await assertFails(getDoc(doc(await anon(), `payments/${PAY}/events/e1`)));
  });

  test('the staff documents (risk score, notes, hashes) are closed to everyone, the parties included', async () => {
    for (const make of Object.values(ROLES)) {
      const db = await make();
      for (const name of ['review', 'dispute', 'statement']) {
        await assertFails(getDoc(doc(db, `payments/${PAY}/staff/${name}`)));
      }
      await assertFails(getDocs(collection(db, `payments/${PAY}/staff`)));
    }
  });
});

describe('payments: nothing is written from a client', () => {
  const fields = [
    { status: 'confirmed' },
    { access: { state: 'full', until: null } },
    { amountPiasters: 1 },
    { feeState: 'waived', feePiasters: 0 },
    { outcome: 'green' },
    { 'proof.txnNumber': 'forged' },
    { coachDecision: { confirmedAt: NOW } },
  ];

  test('no role creates, changes or deletes a payment, whatever the field', async () => {
    for (const [name, make] of Object.entries(ROLES)) {
      const db = await make();
      await assertFails(setDoc(doc(db, 'payments/new-1'), { ...payment, status: 'confirmed' }));
      await assertFails(deleteDoc(doc(db, `payments/${PAY}`)));
      for (const change of fields) {
        await assertFails(updateDoc(doc(db, `payments/${PAY}`), change), `${name} ${JSON.stringify(change)}`);
      }
    }
  });

  test('no role writes into the timeline or the staff documents', async () => {
    for (const make of Object.values(ROLES)) {
      const db = await make();
      await assertFails(setDoc(doc(db, `payments/${PAY}/events/e9`), { to: 'confirmed' }));
      await assertFails(updateDoc(doc(db, `payments/${PAY}/events/e1`), { to: 'confirmed' }));
      await assertFails(deleteDoc(doc(db, `payments/${PAY}/events/e1`)));
      await assertFails(setDoc(doc(db, `payments/${PAY}/staff/review`), { riskScore: 0 }));
      await assertFails(deleteDoc(doc(db, `payments/${PAY}/staff/dispute`)));
    }
  });
});

describe('payments: the server-only collections', () => {
  const closed = ['paymentTxnNumbers', 'paymentImageHashes', 'paymentAmountLocks', 'paymentIdempotency', 'paymentStrikes', 'paymentAlerts'];

  test('nobody reads or writes them from a client', async () => {
    for (const make of Object.values(ROLES)) {
      const db = await make();
      for (const name of closed) {
        await assertFails(getDoc(doc(db, `${name}/x1`)));
        await assertFails(getDocs(collection(db, name)));
        await assertFails(setDoc(doc(db, `${name}/x2`), { paymentId: PAY }));
        await assertFails(updateDoc(doc(db, `${name}/x1`), { paymentId: 'other' }));
        await assertFails(deleteDoc(doc(db, `${name}/x1`)));
      }
    }
  });
});

describe('payments: a woman reads her own profile, standing and fee statements', () => {
  test('the coach reads her own payment profile; nobody lists them; nobody writes them', async () => {
    const db = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(db, `coachPaymentProfiles/${COACH}`)));
    await assertFails(getDoc(doc(db, `coachPaymentProfiles/${COACH2}`)));
    await assertFails(getDocs(collection(db, 'coachPaymentProfiles')));
    await assertFails(updateDoc(doc(db, `coachPaymentProfiles/${COACH}`), { autoConfirmGreen: true }));
    await assertFails(updateDoc(doc(db, `coachPaymentProfiles/${COACH}`), { address: 'thief@instapay' }));
    await assertFails(setDoc(doc(db, `coachPaymentProfiles/${COACH}`), { address: 'thief@instapay' }));
    await assertFails(getDoc(doc(await admin(uid.admin), `coachPaymentProfiles/${COACH}`)));
  });

  test('a woman reads her own standing only, and cannot clear a strike or a suspension', async () => {
    const db = await verified(CLIENT);
    await assertSucceeds(getDoc(doc(db, `paymentStanding/${CLIENT}`)));
    await assertFails(getDoc(doc(db, `paymentStanding/${COACH}`)));
    await assertFails(getDocs(collection(db, 'paymentStanding')));
    await assertFails(updateDoc(doc(db, `paymentStanding/${CLIENT}`), { clientStrikes: 0, clientSuspended: false }));
    await assertFails(deleteDoc(doc(db, `paymentStanding/${CLIENT}`)));
    await assertFails(setDoc(doc(db, 'paymentStanding/new-woman'), { clientStrikes: 0 }));
  });

  test('a coach reads her own statements, by id or by a query that names her; not another coach\'s; not a client', async () => {
    const db = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(db, `feeStatements/${COACH}__2026-10`)));
    await assertSucceeds(getDocs(query(collection(db, 'feeStatements'), where('coachUid', '==', COACH))));
    await assertFails(getDoc(doc(db, `feeStatements/${COACH2}__2026-10`)));
    await assertFails(getDocs(collection(db, 'feeStatements')));
    await assertFails(getDocs(query(collection(db, 'feeStatements'), where('coachUid', '==', COACH2))));
    await assertFails(getDoc(doc(await verified(CLIENT), `feeStatements/${COACH}__2026-10`)));
    await assertFails(getDoc(doc(await admin(uid.admin), `feeStatements/${COACH}__2026-10`)));
  });

  test('nobody writes a statement: not to mark it paid, not to change the total', async () => {
    for (const make of Object.values(ROLES)) {
      const db = await make();
      await assertFails(updateDoc(doc(db, `feeStatements/${COACH}__2026-10`), { status: 'paid', totalDuePiasters: 0 }));
      await assertFails(setDoc(doc(db, `feeStatements/${COACH}__2026-11`), { coachUid: COACH, totalDuePiasters: 0 }));
      await assertFails(deleteDoc(doc(db, `feeStatements/${COACH}__2026-10`)));
    }
  });
});

describe('payments: the kill switch', () => {
  test('any signed-in account reads it; a visitor does not; nobody lists or writes it', async () => {
    await assertSucceeds(getDoc(doc(await verified(CLIENT), 'config/payments')));
    await assertSucceeds(getDoc(doc(await unverified(CLIENT), 'config/payments')));
    await assertFails(getDoc(doc(await anon(), 'config/payments')));
    for (const make of Object.values(ROLES)) {
      const db = await make();
      await assertFails(setDoc(doc(db, 'config/payments'), { enabled: false }));
      await assertFails(updateDoc(doc(db, 'config/payments'), { enabled: false }));
      await assertFails(deleteDoc(doc(db, 'config/payments')));
      await assertFails(getDocs(collection(db, 'config')));
    }
  });

  test('with the switch off, an open payment is still readable by its parties and by nobody else', async () => {
    await seed(async (ctx) => { await setDoc(doc(ctx.firestore(), 'config/payments'), { enabled: false, updatedAt: NOW }); });
    try {
      await assertSucceeds(getDoc(doc(await verified(CLIENT), `payments/${PAY}`)));
      await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), `payments/${PAY}`)));
      await assertSucceeds(getDoc(doc(await verified(CLIENT), `payments/${PAY}/events/e1`)));
      await assertFails(getDoc(doc(await verified(uid.attacker), `payments/${PAY}`)));
    } finally {
      await seed(async (ctx) => { await setDoc(doc(ctx.firestore(), 'config/payments'), { enabled: true, updatedAt: NOW }); });
    }
  });

  test('with the document missing the payments stay readable too (a missing switch means off for NEW payments only)', async () => {
    await seed(async (ctx) => { await deleteDoc(doc(ctx.firestore(), 'config/payments')); });
    try {
      await assertSucceeds(getDoc(doc(await verified(CLIENT), `payments/${PAY}`)));
    } finally {
      await seed(async (ctx) => { await setDoc(doc(ctx.firestore(), 'config/payments'), { enabled: true, updatedAt: NOW }); });
    }
  });
});
