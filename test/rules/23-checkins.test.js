// The weekly check-in: relationships/{relId}/checkIns/{weekKey}.
//
// Written only by the coaching service. The answers (energy, food, pain and a
// free note) are health data that a client sends so her coach can read them,
// so the two parties read; nobody writes from a client, and nobody else reads.
// The coach reads only while the coaching is active; the client always reads
// her own answers.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, verifiedCoach, admin, uid, reloadRules,
  assertSucceeds, assertFails, switchDormantFeaturesOn,
} from './harness.js';
import {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection,
} from 'firebase/firestore';

switchDormantFeaturesOn();

const HER = uid.her;
const OTHER = uid.other;
const COACH = uid.coach;
const COACH2 = uid.coach2;

const REL = `${COACH}__${HER}`;
const REL_ENDED = `${COACH2}__${HER}`;
const REL_OTHER = `${COACH}__${OTHER}`;

const WEEK = '2026-W44';
const answered = (clientUid, coachUid) => ({
  clientUid,
  coachUid,
  weekKey: WEEK,
  state: 'answered',
  createdAt: new Date(),
  answeredAt: new Date(),
  answers: { training: 'some', energy: 2, food: 3, pain: true, note: 'my knee hurts when I squat' },
});

async function seedAll() {
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, `relationships/${REL}`), {
      coachUid: COACH, clientUid: HER, status: 'active', chatOpen: true, activeSubId: 's1',
    });
    await setDoc(doc(d, `relationships/${REL_ENDED}`), {
      coachUid: COACH2, clientUid: HER, status: 'ended', chatOpen: false,
    });
    await setDoc(doc(d, `relationships/${REL_OTHER}`), {
      coachUid: COACH, clientUid: OTHER, status: 'active', chatOpen: true, activeSubId: 's2',
    });
    await setDoc(doc(d, `relationships/${REL}/checkIns/${WEEK}`), answered(HER, COACH));
    await setDoc(doc(d, `relationships/${REL_ENDED}/checkIns/${WEEK}`), answered(HER, COACH2));
    await setDoc(doc(d, `relationships/${REL_OTHER}/checkIns/${WEEK}`), answered(OTHER, COACH));
  });
}

before(async () => { await getEnv(); await seedAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('who reads a check-in', () => {
  test('the client reads her own answers, while the coaching runs and after it ended', async () => {
    const her = await verified(HER);
    await assertSucceeds(getDoc(doc(her, `relationships/${REL}/checkIns/${WEEK}`)));
    await assertSucceeds(getDocs(collection(her, `relationships/${REL}/checkIns`)));
    await assertSucceeds(getDoc(doc(her, `relationships/${REL_ENDED}/checkIns/${WEEK}`)));
  });

  test('the coach of an active coaching reads her client\'s answers, one or all', async () => {
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(coach, `relationships/${REL}/checkIns/${WEEK}`)));
    await assertSucceeds(getDocs(collection(coach, `relationships/${REL}/checkIns`)));
  });

  test('the coach of an ended coaching no longer reads them', async () => {
    const coach = await verifiedCoach(COACH2);
    await assertFails(getDoc(doc(coach, `relationships/${REL_ENDED}/checkIns/${WEEK}`)));
    await assertFails(getDocs(collection(coach, `relationships/${REL_ENDED}/checkIns`)));
  });

  test('nobody else reads them: not another coach, not another client, not staff', async () => {
    const path = `relationships/${REL}/checkIns/${WEEK}`;
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), path)));
    await assertFails(getDoc(doc(await verified(OTHER), path)));
    await assertFails(getDoc(doc(await admin(uid.admin), path)));
    await assertFails(getDoc(doc(await unverified(HER), path)));
    await assertFails(getDoc(doc(await anon(), path)));
    await assertFails(getDocs(collection(await verified(OTHER), `relationships/${REL}/checkIns`)));
  });

  test('a coach reads only her own clients\' check-ins', async () => {
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(coach, `relationships/${REL_OTHER}/checkIns/${WEEK}`)));
    await assertFails(getDoc(doc(coach, `relationships/${REL_ENDED}/checkIns/${WEEK}`)));
  });

  test('a check-in under a relationship that does not exist is not readable', async () => {
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, `relationships/${COACH}__nobody/checkIns/${WEEK}`)));
  });
});

describe('nobody writes a check-in from a client', () => {
  test('neither party creates, updates or deletes, whatever the field', async () => {
    const path = `relationships/${REL}/checkIns/${WEEK}`;
    for (const who of [await verified(HER), await verifiedCoach(COACH)]) {
      await assertFails(setDoc(doc(who, `relationships/${REL}/checkIns/2026-W45`), answered(HER, COACH)));
      await assertFails(updateDoc(doc(who, path), { state: 'open' }));
      await assertFails(updateDoc(doc(who, path), { answers: { training: 'all', energy: 5, food: 5, pain: false, note: '' } }));
      await assertFails(updateDoc(doc(who, path), { followUpAt: new Date() }));
      await assertFails(updateDoc(doc(who, path), { answeredAt: new Date(), clientUid: OTHER }));
      await assertFails(deleteDoc(doc(who, path)));
    }
  });

  test('staff cannot write one either', async () => {
    const ad = await admin(uid.admin);
    await assertFails(setDoc(doc(ad, `relationships/${REL}/checkIns/2026-W46`), answered(HER, COACH)));
    await assertFails(deleteDoc(doc(ad, `relationships/${REL}/checkIns/${WEEK}`)));
  });
});

describe('the clients switch', () => {
  test('with the clients side switched off, nobody reads a check-in', async () => {
    await reloadRules({ coachClients: false });
    try {
      await seedAll();
      await assertFails(getDoc(doc(await verified(HER), `relationships/${REL}/checkIns/${WEEK}`)));
      await assertFails(getDoc(doc(await verifiedCoach(COACH), `relationships/${REL}/checkIns/${WEEK}`)));
    } finally {
      await reloadRules({ community: true, coachPortfolio: true, coachClients: true, coachPayments: true });
    }
  });
});
