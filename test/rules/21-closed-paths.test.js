// Paths nothing in the product uses stay closed, the community stays unreadable
// while its switch is off, and a report needs a phone sign-in.

import { test, before, after } from 'node:test';
import {
  getEnv, clearAll, seed, verified, verifiedCoach, otherProvider, uid,
  assertSucceeds, assertFails,
} from './harness.js';
import { doc, setDoc, getDoc, getDocs, collection, serverTimestamp } from 'firebase/firestore';

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

const HER = uid.her;
const COACH = uid.coach;

test('the old coach portfolio, offers and results are unreadable by a verified member', async () => {
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, `coaches/${COACH}/portfolio/v1`), { published: true });
    await setDoc(doc(d, `coaches/${COACH}/offers/o1`), { title: 'x' });
    await setDoc(doc(d, `coaches/${COACH}/results/r1`), { consentState: 'granted' });
  });
  const db = await verified(HER);
  await assertFails(getDoc(doc(db, `coaches/${COACH}/portfolio/v1`)));
  await assertFails(getDoc(doc(db, `coaches/${COACH}/offers/o1`)));
  await assertFails(getDoc(doc(db, `coaches/${COACH}/results/r1`)));
  const own = await verifiedCoach(COACH);
  await assertFails(getDoc(doc(own, `coaches/${COACH}/portfolio/v1`)));
  await assertFails(getDoc(doc(own, `coaches/${COACH}/results/r1`)));
});

test('legal holds (a deleted coach\'s signed agreement) are closed to every client', async () => {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `legalHolds/${COACH}`), { retainUntil: new Date('2032-01-01') });
  });
  for (const db of [await verifiedCoach(COACH), await verified(HER)]) {
    await assertFails(getDoc(doc(db, `legalHolds/${COACH}`)));
    await assertFails(setDoc(doc(db, `legalHolds/${COACH}`), { retainUntil: new Date('2020-01-01') }));
  }
});

test('assessments are closed to read and write, even for the coach they name', async () => {
  await seed(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'assessments/a1'), { coachUid: COACH, clientUid: HER });
    await setDoc(doc(ctx.firestore(), `relationships/${COACH}__${HER}`), { state: 'accepted' });
  });
  const coach = await verifiedCoach(COACH);
  await assertFails(getDoc(doc(coach, 'assessments/a1')));
  await assertFails(setDoc(doc(coach, 'assessments/a2'), { coachUid: COACH, clientUid: HER }));
  const her = await verified(HER);
  await assertFails(getDoc(doc(her, 'assessments/a1')));
});

test('community collections cannot be read while the switch is off', async () => {
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'posts/p1'), { authorUid: uid.other, blurred: true });
    await setDoc(doc(d, 'posts/p1/comments/c1'), { authorUid: uid.other });
    await setDoc(doc(d, `publicProfiles/${uid.other}`), { name: 'x' });
    await setDoc(doc(d, `followGraph/${uid.other}/following/${HER}`), { at: 1 });
    await setDoc(doc(d, 'groups/g1'), { name: 'x' });
  });
  const db = await verified(HER);
  await assertFails(getDoc(doc(db, 'posts/p1')));
  await assertFails(getDocs(collection(db, 'posts')));
  await assertFails(getDoc(doc(db, 'posts/p1/comments/c1')));
  await assertFails(getDoc(doc(db, `publicProfiles/${uid.other}`)));
  await assertFails(getDoc(doc(db, `followGraph/${uid.other}/following/${HER}`)));
  await assertFails(getDoc(doc(db, 'groups/g1')));
});

const report = () => ({
  reporterUid: HER, subjectUid: uid.other, subjectKind: 'user',
  subjectRef: `users/${uid.other}`, reason: 'harassment', note: 'n',
  state: 'submitted', createdAt: serverTimestamp(), locale: 'ar', appVersion: '1.0.0',
});

test('a report needs a phone sign-in', async () => {
  const google = await otherProvider(HER, 'google.com', { verified: true });
  await assertFails(setDoc(doc(google, 'reports/r_g'), report()));
  const phone = await verified(HER);
  await assertSucceeds(setDoc(doc(phone, 'reports/r_p'), report()));
});
