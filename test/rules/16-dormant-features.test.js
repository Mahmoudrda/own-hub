// APL-16: the community and the coach app are off in the first release, and
// off on the server too. With the rules exactly as they ship, a verified
// account calling the API directly can create nothing the app does not offer:
// no post, comment, follow, membership, coach page, relationship, message or
// report about a post. What stays open is what must never wait on a feature:
// taking her own things down, and reporting a person.

import { test, before, after, describe } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  getEnv, clearAll, seed, verified, verifiedCoach, uid, RULES_PATH,
  assertSucceeds, assertFails, assert,
} from './harness.js';
import {
  doc, setDoc, updateDoc, deleteDoc, getDoc, serverTimestamp,
} from 'firebase/firestore';

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

const HER = uid.her;
const OTHER = uid.other;
const COACH = uid.coach;

describe('the rules ship with both features switched off', () => {
  test('both switches return false in the deployed file', () => {
    const src = readFileSync(RULES_PATH, 'utf8');
    assert.match(src, /function communityLive\(\) \{\s*return false;\s*\}/);
    assert.match(src, /function coachLive\(\) \{\s*return false;\s*\}/);
  });

  test('and so does storage.rules', () => {
    const src = readFileSync(RULES_PATH.replace('firestore.rules', 'storage.rules'), 'utf8');
    assert.match(src, /function communityLive\(\) \{\s*return false;\s*\}/);
    assert.match(src, /function coachLive\(\) \{\s*return false;\s*\}/);
  });
});

describe('the community refuses every write while it is off', () => {
  test('no post, comment, follow or membership can be created', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'posts/p_other'), { authorUid: OTHER, blurred: true });
    });
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, 'posts/p_new'), { authorUid: HER, blurred: true, body: 'hi' }));
    await assertFails(setDoc(doc(db, 'posts/p_other/comments/c1'), { authorUid: HER, body: 'hi' }));
    await assertFails(setDoc(doc(db, `followGraph/${HER}/following/${OTHER}`), { at: 1 }));
    await assertFails(setDoc(doc(db, `groups/g1/members/${HER}`), { joinedAt: serverTimestamp() }));
  });

  test('a post she already has cannot be edited, and can still be deleted', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'posts/p_hers'), { authorUid: HER, blurred: true, body: 'old' });
      await setDoc(doc(ctx.firestore(), 'posts/p_other/comments/c_hers'), { authorUid: HER, body: 'x' });
      await setDoc(doc(ctx.firestore(), `followGraph/${HER}/following/${OTHER}`), { at: 1 });
    });
    const db = await verified(HER);
    await assertFails(updateDoc(doc(db, 'posts/p_hers'), { body: 'edited' }));
    await assertSucceeds(deleteDoc(doc(db, 'posts/p_other/comments/c_hers')));
    await assertSucceeds(deleteDoc(doc(db, 'posts/p_hers')));
    await assertSucceeds(deleteDoc(doc(db, `followGraph/${HER}/following/${OTHER}`)));
  });

  test('a report about a post waits; a report about a person never does', async () => {
    const db = await verified(HER);
    const base = {
      reporterUid: HER, subjectUid: OTHER, state: 'submitted',
      createdAt: serverTimestamp(), reason: 'harassment',
    };
    await assertFails(setDoc(doc(db, 'reports/r_post'), { ...base, subjectKind: 'post', subjectRef: 'posts/p1' }));
    await assertFails(setDoc(doc(db, 'reports/r_comment'), { ...base, subjectKind: 'comment', subjectRef: 'posts/p1/comments/c1' }));
    await assertSucceeds(setDoc(doc(db, 'reports/r_user'), { ...base, subjectKind: 'user' }));
  });
});

describe('the coach app refuses every write while it is off', () => {
  test('even a coach with the claim cannot create or change her page', async () => {
    const db = await verifiedCoach(COACH);
    await assertFails(setDoc(doc(db, `coaches/${COACH}`), { displayName: 'Salma' }));
    for (const sub of ['portfolio/v1', 'offers/o1', 'results/r1', 'ads/a1', 'splits/s1']) {
      await assertFails(setDoc(doc(db, `coaches/${COACH}/${sub}`), { x: 1 }));
    }
  });

  test('what she already wrote can still be taken down', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}`), { displayName: 'Salma' });
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}/offers/o1`), { price: 1 });
    });
    const db = await verifiedCoach(COACH);
    await assertFails(updateDoc(doc(db, `coaches/${COACH}`), { displayName: 'S' }));
    await assertFails(updateDoc(doc(db, `coaches/${COACH}/offers/o1`), { price: 2 }));
    await assertSucceeds(deleteDoc(doc(db, `coaches/${COACH}/offers/o1`)));
  });

  test('no relationship, message or review can be written', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `coaches/${COACH}`), { displayName: 'Salma' });
      await setDoc(doc(f, `relationships/${COACH}__${OTHER}`), { coachUid: COACH, clientUid: OTHER });
    });
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, `relationships/${COACH}__${HER}`), { coachUid: COACH, clientUid: HER }));
    const client = await verified(OTHER);
    await assertFails(setDoc(doc(client, `relationships/${COACH}__${OTHER}/messages/m1`), {
      senderUid: OTHER, body: 'hello',
    }));
    await assertFails(setDoc(doc(client, `relationships/${COACH}__${OTHER}/reviews/r1`), { stars: 5 }));
    await assertFails(updateDoc(doc(client, `relationships/${COACH}__${OTHER}`), { note: 'x' }));
  });

  test('certificate records and invite codes are server-only', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `coaches/${COACH}/certificates/nasm_cpt-1`), { state: 'uploaded' });
      await setDoc(doc(f, 'coachInvites/ABCD2345'), { coachUid: COACH });
    });
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(coach, `coaches/${COACH}/certificates/nasm_cpt-1`)));
    await assertFails(updateDoc(doc(coach, `coaches/${COACH}/certificates/nasm_cpt-1`), { state: 'verified' }));
    await assertFails(getDoc(doc(coach, 'coachInvites/ABCD2345')));
    await assertFails(setDoc(doc(coach, 'coachInvites/WXYZ2345'), { coachUid: COACH }));
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, `coaches/${COACH}/certificates/nasm_cpt-1`)));
  });
});
