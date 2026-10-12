// W1: the launch waitlist holds phone numbers and emails of people who are
// not members. Only the join_waitlist Function writes it, with admin
// credentials. No client of any kind may read, list, write or delete either
// the list or its per-IP counter, and the rules say so by name rather than
// leaning on the catch-all.

import { test, before, after, describe } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  getEnv, clearAll, seed, anon, unverified, verified, admin, uid, RULES_PATH,
  assertFails, assert,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
} from 'firebase/firestore';

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

const PATHS = [
  ['waitlist', 'entry_0001', {
    contact: '+201012345678', kind: 'phone', lang: 'ar', consent: true,
  }],
  ['waitlistRate', 'abc123_2026-10-04', { count: 1 }],
];

const CLIENTS = [
  ['a verified admin', () => admin(uid.admin)],
  ['a verified woman', () => verified(uid.her)],
  ['an unverified account', () => unverified(uid.her)],
  ['an anonymous caller', () => anon()],
];

describe('the waitlist is closed to every client', () => {
  for (const [col, id, payload] of PATHS) {
    for (const [who, make] of CLIENTS) {
      test(`${col}: ${who} can neither read nor write`, async () => {
        await seed(async (ctx) => { await setDoc(doc(ctx.firestore(), `${col}/${id}`), payload); });
        const db = await make();
        await assertFails(getDoc(doc(db, `${col}/${id}`)));
        await assertFails(getDocs(collection(db, col)));
        await assertFails(setDoc(doc(db, `${col}/new_one`), payload));
        await assertFails(updateDoc(doc(db, `${col}/${id}`), { count: 2 }));
        await assertFails(deleteDoc(doc(db, `${col}/${id}`)));
      });
    }
  }

  test('the rules name both collections as closed', () => {
    const src = readFileSync(RULES_PATH, 'utf8');
    assert.match(src, /match \/waitlist\/\{[A-Za-z]+\}\s*\{\s*allow read, write: if false; \}/);
    assert.match(src, /match \/waitlistRate\/\{[A-Za-z]+\}\s*\{\s*allow read, write: if false; \}/);
  });
});
