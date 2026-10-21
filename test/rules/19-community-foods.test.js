// The foods women offer from the meal check, and the list the owner publishes.
//
//  1. scanCache and communityFoodCandidates (with the markers under them) are
//     closed to every client, admin included; 01-server-only.test.js probes
//     the same paths from every account.
//  2. meta/communityFoods and meta/communityFoodsVersion are read by a verified
//     woman (and the admin console) and written by no client at all. The
//     general meta rule lets an admin write other meta documents; these two are
//     carved out because only functions/nutrition/community_foods.py publishes.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, consoleAdmin,
  uid, assertSucceeds, assertFails,
} from './harness.js';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection } from 'firebase/firestore';

const LIST = 'meta/communityFoods';
const VERSION = 'meta/communityFoodsVersion';

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, LIST), { version: 1, foods: [] });
    await setDoc(doc(db, VERSION), { version: 1 });
    await setDoc(doc(db, 'meta/recipes'), { version: 1 });
    await setDoc(doc(db, 'scanCache/abc'), { items: [] });
    await setDoc(doc(db, 'communityFoodCandidates/k1'), { confirmCount: 2 });
    await setDoc(doc(db, 'communityFoodCandidates/k1/by/m1'), { v: 1 });
  });
});
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('the published community foods', () => {
  for (const path of [LIST, VERSION]) {
    test(`${path} is read by a verified woman and the console, not by others`, async () => {
      await assertSucceeds(getDoc(doc(await verified(uid.her), path)));
      await assertSucceeds(getDoc(doc(await consoleAdmin(uid.admin), path)));
      await assertFails(getDoc(doc(await unverified(uid.her), path)));
      await assertFails(getDoc(doc(await anon(), path)));
    });

    test(`${path} is written by no client, the admin included`, async () => {
      for (const db of [await verified(uid.her), await consoleAdmin(uid.admin), await anon()]) {
        await assertFails(setDoc(doc(db, path), { version: 99, foods: [] }));
        await assertFails(updateDoc(doc(db, path), { version: 99 }));
        await assertFails(deleteDoc(doc(db, path)));
      }
    });
  }

  test('the other meta documents keep their admin write', async () => {
    await assertSucceeds(setDoc(doc(await consoleAdmin(uid.admin), 'meta/recipes'), { version: 2 }));
    await assertFails(setDoc(doc(await verified(uid.her), 'meta/recipes'), { version: 3 }));
  });
});

describe('the cache and the candidates', () => {
  const PATHS = ['scanCache/abc', 'communityFoodCandidates/k1', 'communityFoodCandidates/k1/by/m1'];

  test('no client reads or writes them, the admin console included', async () => {
    for (const db of [await verified(uid.her), await consoleAdmin(uid.admin), await anon()]) {
      for (const path of PATHS) {
        await assertFails(getDoc(doc(db, path)));
        await assertFails(setDoc(doc(db, path), { confirmCount: 99 }));
        await assertFails(deleteDoc(doc(db, path)));
      }
      await assertFails(getDocs(collection(db, 'communityFoodCandidates')));
      await assertFails(getDocs(collection(db, 'communityFoodCandidates/k1/by')));
      await assertFails(getDocs(collection(db, 'scanCache')));
    }
  });
});
