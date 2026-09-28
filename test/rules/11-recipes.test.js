// The recipe library, the entitlement, and the two things the rules enforce
// that no amount of Dart can.
//
// Two clauses are worth stating plainly, because both are the kind of rule that
// looks like belt-and-braces until the day it is the only thing holding:
//
//  1. **Two people sign an allergen review.** A recipe cannot be written with a
//     null `allergenReviewedBy`, and cannot be written with a reviewer who is
//     also its author. It is here rather than in the client because a Dart bug,
//     an admin console regression or somebody's hand-run import script can each
//     bypass a client check, and what is being checked is whether a human
//     actually looked at what is in a dish a woman with an allergy will eat.
//
//  2. **A client cannot mint its own entitlement.** `users/{uid}/private/*` is
//     read-only to her and written by a Cloud Function or an admin. Nothing
//     reads it yet — `Feature.payments` is off and every recipe is free — and
//     that is the point: the shape is settled while nobody is in a hurry.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, admin,
  uid, assertSucceeds, assertFails,
} from './harness.js';
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore';

const FREE = {
  recipeId: 'rahma_lazy_cake',
  titleEn: 'Lazy Cake',
  tier: 'free',
  authoredBy: 'rahma_mohsen',
  allergenReviewedBy: 'qa_reviewer',
  allergensFinal: ['eggs', 'gluten', 'milk'],
};

const PRO = { ...FREE, recipeId: 'rahma_pro_only', tier: 'pro' };

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'recipes/rahma_lazy_cake'), FREE);
    await setDoc(doc(d, 'recipes/rahma_pro_only'), PRO);
    await setDoc(doc(d, 'recipeIndex/ar_v1'), { rows: [] });
    await setDoc(doc(d, 'meta/recipes'), { version: 1 });
    await setDoc(doc(d, `users/${uid.her}/private/entitlement`), {
      tier: 'free', source: 'none', updatedAt: new Date(),
    });
  });
});

after(async () => {
  const env = await getEnv();
  await env.cleanup();
});

describe('reading the library', () => {
  test('a verified woman reads a free recipe', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'recipes/rahma_lazy_cake')));
  });

  test('an unverified account reads nothing of it', async () => {
    // The library is what the product is made of, and it sits behind the same
    // gate as everything else.
    const d = await unverified(uid.her);
    await assertFails(getDoc(doc(d, 'recipes/rahma_lazy_cake')));
    const a = await anon();
    await assertFails(getDoc(doc(a, 'recipes/rahma_lazy_cake')));
  });

  test('the whole list screen is one document, and she may read it', async () => {
    // A query over N recipes on every tab open is N reads per open, which is
    // about $360 a day at 200 recipes and 10,000 women. The index document is
    // one read, and the version check usually makes it zero.
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'recipeIndex/ar_v1')));
    await assertSucceeds(getDoc(doc(d, 'meta/recipes')));
  });

  test('a free account cannot read a pro recipe at all', async () => {
    // A client-side lock is a lie if the document is readable anyway. Nothing
    // in the shipped build is `pro`, so this refuses nothing today; adding the
    // rule afterwards would mean a window in which the lock was decorative.
    const d = await verified(uid.her);
    await assertFails(getDoc(doc(d, 'recipes/rahma_pro_only')));
  });

  test('a pro claim opens it', async () => {
    // A custom claim, not a document read: a `get()` in a rule bills one extra
    // read on every gated operation. The cost is staleness, up to an hour, so a
    // purchase flow must force a token refresh.
    const d = await verified(uid.her, { tier: 'pro' });
    await assertSucceeds(getDoc(doc(d, 'recipes/rahma_pro_only')));
  });
});

describe('writing the library', () => {
  test('a member cannot write a recipe', async () => {
    const d = await verified(uid.her);
    await assertFails(setDoc(doc(d, 'recipes/mine'), FREE));
    await assertFails(setDoc(doc(d, 'recipeIndex/ar_v1'), { rows: [] }));
    await assertFails(setDoc(doc(d, 'meta/recipes'), { version: 99 }));
  });

  test('an admin writes a reviewed recipe', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(
      setDoc(doc(d, 'recipes/rahma_pancakes'), {
        ...FREE, recipeId: 'rahma_pancakes', titleEn: 'Pancakes',
      }),
    );
  });

  test('an unreviewed recipe is refused, even from an admin', async () => {
    // The gate that makes `status: published` mean something. An unsigned
    // allergen set is not a claim anybody is entitled to publish.
    const d = await admin(uid.admin);
    await assertFails(
      setDoc(doc(d, 'recipes/rahma_unreviewed'), {
        ...FREE, recipeId: 'rahma_unreviewed', allergenReviewedBy: null,
      }),
    );
  });

  test('one person cannot review their own work', async () => {
    const d = await admin(uid.admin);
    await assertFails(
      setDoc(doc(d, 'recipes/rahma_self_reviewed'), {
        ...FREE,
        recipeId: 'rahma_self_reviewed',
        authoredBy: 'rahma_mohsen',
        allergenReviewedBy: 'rahma_mohsen',
      }),
    );
  });

  test('an admin may withdraw a recipe', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(deleteDoc(doc(d, 'recipes/rahma_pancakes')));
  });
});

describe('the entitlement is server-minted', () => {
  test('she reads her own', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(
      getDoc(doc(d, `users/${uid.her}/private/entitlement`)),
    );
  });

  test('she cannot write it, and nor can an admin through the client', async () => {
    // Exactly how `verified`, `coachV` and `admin` are already handled. A
    // client-asserted entitlement is a suggestion, not an entitlement.
    const d = await verified(uid.her);
    await assertFails(
      setDoc(doc(d, `users/${uid.her}/private/entitlement`), {
        tier: 'pro', source: 'grant', updatedAt: new Date(),
      }),
    );
    const a = await admin(uid.admin);
    await assertFails(
      setDoc(doc(a, `users/${uid.her}/private/entitlement`), { tier: 'pro' }),
    );
  });

  test('nobody else reads hers', async () => {
    const d = await verified(uid.other);
    await assertFails(
      getDoc(doc(d, `users/${uid.her}/private/entitlement`)),
    );
  });
});
