// The console reads the library it writes.
//
// `functions/tools/grant_admin.py` sets the `admin` claim and nothing else, and
// the app lets the console past the women-only gate without an ID check. The
// console reads before it writes (the recipe list, `meta/recipes`, a
// programme, `workoutLibrary/v{N}`), so an admin who is not also `verified`
// must be able to read every library document, or publishing fails with
// permission denied on the owner's first try.
//
// What does not change: a member still needs `verified`, a signed-in account
// without either claim reads nothing, and the admin claim opens no woman's own
// documents.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, consoleAdmin,
  uid, assertSucceeds, assertFails,
} from './harness.js';
import { doc, getDoc, setDoc, collection, getDocs } from 'firebase/firestore';

const LIBRARY = [
  'exercises/squat',
  'foods/ful',
  'programs/start',
  'recipes/koshari',
  'recipes/pro-only',
  'recipeIndex/all',
  'meta/recipes',
  'meta/workouts',
  'workoutLibrary/v1',
];

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'exercises/squat'), { name: 'Squat' });
    await setDoc(doc(d, 'foods/ful'), { name: 'Ful' });
    await setDoc(doc(d, 'programs/start'), { name: 'Start' });
    await setDoc(doc(d, 'recipes/koshari'), { tier: 'free' });
    await setDoc(doc(d, 'recipes/pro-only'), { tier: 'pro' });
    await setDoc(doc(d, 'recipeIndex/all'), { rows: [] });
    await setDoc(doc(d, 'meta/recipes'), { version: 1 });
    await setDoc(doc(d, 'meta/workouts'), { version: 1 });
    await setDoc(doc(d, 'workoutLibrary/v1'), { programs: [] });
    await setDoc(doc(d, `users/${uid.her}`), { displayName: 'Her' });
  });
});

after(async () => {
  const env = await getEnv();
  await env.cleanup();
});

describe('an admin without the verified claim runs the console', () => {
  for (const path of LIBRARY) {
    test(`reads ${path}`, async () => {
      const d = await consoleAdmin(uid.admin);
      await assertSucceeds(getDoc(doc(d, path)));
    });
  }

  test('lists a library collection, as the console list screens do', async () => {
    const d = await consoleAdmin(uid.admin);
    await assertSucceeds(getDocs(collection(d, 'exercises')));
    await assertSucceeds(getDocs(collection(d, 'recipes')));
  });

  test('a recipe that does not exist is a normal miss, not an error', async () => {
    const d = await consoleAdmin(uid.admin);
    await assertSucceeds(getDoc(doc(d, 'recipes/not-written-yet')));
  });

  test("still opens no woman's own document", async () => {
    const d = await consoleAdmin(uid.admin);
    await assertFails(getDoc(doc(d, `users/${uid.her}`)));
  });
});

describe('nothing else moved', () => {
  test('a verified member reads the free library, not the pro recipe', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'recipes/koshari')));
    await assertSucceeds(getDoc(doc(d, 'workoutLibrary/v1')));
    await assertFails(getDoc(doc(d, 'recipes/pro-only')));
  });

  test('a signed-in account with neither claim reads none of it', async () => {
    const d = await unverified(uid.her);
    for (const path of LIBRARY) {
      await assertFails(getDoc(doc(d, path)));
    }
  });

  test('a signed-out visitor reads none of it', async () => {
    const d = await anon();
    for (const path of LIBRARY) {
      await assertFails(getDoc(doc(d, path)));
    }
  });
});
