// APL-16: the community and the money side of coaching are off in the first
// release, and off on the server too. The coach portfolio (applications, her
// page, packages, drafts) and the clients side (relationships, chat,
// subscriptions, sessions, shared plans) are on. With the rules exactly as they ship, a verified
// account calling the API directly can create nothing the app does not offer:
// no post, comment, follow, membership, coach page, relationship, message or
// report about a post. What stays open is what must never wait on a feature:
// taking her own things down, and reporting a person.

import { test, before, after, describe } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  getEnv, clearAll, seed, anon, verified, verifiedCoach, uid, RULES_PATH, reloadRules,
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
const COACH2 = uid.coach2;

function shipped(src, hasClients) {
  assert.match(src, /function communityLive\(\) \{\s*return false;\s*\}/);
  assert.match(src, /function coachPaymentsLive\(\) \{\s*return false;\s*\}/);
  assert.match(src, /function coachPortfolioLive\(\) \{\s*return true;\s*\}/);
  if (hasClients) assert.match(src, /function coachClientsLive\(\) \{\s*return true;\s*\}/);
  assert.doesNotMatch(src, /coachLive\(/);
}

describe('the rules ship with community and payments off, portfolio and clients on', () => {
  test('the three switches read so in the deployed file', () => {
    shipped(readFileSync(RULES_PATH, 'utf8'), true);
  });

  test('and so does storage.rules', () => {
    shipped(readFileSync(RULES_PATH.replace('firestore.rules', 'storage.rules'), 'utf8'));
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
    for (const [kind, ref] of [
      ['coachMessage', 'relationships/c__w/messages/m1'],
      ['coachProfile', 'coaches/c'],
      ['coachPlan', 'plans/w/coachPlans/p1'],
    ]) {
      await assertSucceeds(setDoc(doc(db, `reports/r_${kind}`), {
        ...base, reason: 'unsafe_advice', subjectKind: kind, subjectRef: ref,
      }));
    }
    await assertSucceeds(setDoc(doc(db, 'reports/r_pay'), {
      ...base, reason: 'off_platform_payment', subjectKind: 'coachMessage', subjectRef: 'x',
    }));
  });
});

describe('the coach portfolio is open, and nothing else of coaching is', () => {
  test('even a coach with the claim cannot create or change her page', async () => {
    const db = await verifiedCoach(COACH);
    await assertFails(setDoc(doc(db, `coaches/${COACH}`), { displayName: 'Salma' }));
    for (const sub of ['portfolio/v1', 'offers/o1', 'results/r1', 'ads/a1', 'splits/s1']) {
      await assertFails(setDoc(doc(db, `coaches/${COACH}/${sub}`), { x: 1 }));
    }
  });

  test('a coach works on her own drafts, nobody else does', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}/drafts/d1`), {
        kind: 'workout', name: 'Legs', body: {}, updatedAt: new Date(),
      });
    });
    const db = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(db, `coaches/${COACH}/drafts/d1`)));
    await assertSucceeds(setDoc(doc(db, `coaches/${COACH}/drafts/d2`), {
      kind: 'package', name: 'Eight weeks', body: {}, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(doc(db, `coaches/${COACH}/drafts/d1`)));
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, `coaches/${COACH}/drafts/d2`)));
  });

  test('a verified member reads a published page and its active packages', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `coaches/${COACH}`), { displayName: 'Salma', published: true });
      await setDoc(doc(f, `coaches/${COACH2}`), { displayName: 'Dina', published: false });
      await setDoc(doc(f, `coaches/${COACH}/packages/on`), { active: true, priceFinalEgp: 2000 });
      await setDoc(doc(f, `coaches/${COACH}/packages/off`), { active: false });
    });
    const her = await verified(HER);
    await assertSucceeds(getDoc(doc(her, `coaches/${COACH}`)));
    await assertFails(getDoc(doc(her, `coaches/${COACH2}`)));
    await assertSucceeds(getDoc(doc(her, `coaches/${COACH}/packages/on`)));
    await assertFails(getDoc(doc(her, `coaches/${COACH}/packages/off`)));
    await assertFails(setDoc(doc(her, `coaches/${COACH}/packages/new`), { active: true }));
  });

  test('portfolio media: members read approved items of a published page, the coach reads her own', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `coaches/${COACH}`), { displayName: 'Salma', published: true });
      await setDoc(doc(f, `coaches/${COACH2}`), { displayName: 'Dina', published: false });
      for (const [id, status] of [['ok', 'approved'], ['wait', 'pending'], ['no', 'rejected'], ['consent', 'needsConsent']]) {
        await setDoc(doc(f, `coaches/${COACH}/media/${id}`), { status, kind: 'photo' });
      }
      await setDoc(doc(f, `coaches/${COACH2}/media/ok`), { status: 'approved', kind: 'photo' });
    });
    const her = await verified(HER);
    await assertSucceeds(getDoc(doc(her, `coaches/${COACH}/media/ok`)));
    for (const id of ['wait', 'no', 'consent']) {
      await assertFails(getDoc(doc(her, `coaches/${COACH}/media/${id}`)));
    }
    await assertFails(getDoc(doc(her, `coaches/${COACH2}/media/ok`)));
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(coach, `coaches/${COACH}/media/wait`)));
    const other = await verifiedCoach(COACH2);
    await assertFails(getDoc(doc(other, `coaches/${COACH}/media/wait`)));
    const unverified = await anon();
    await assertFails(getDoc(doc(unverified, `coaches/${COACH}/media/ok`)));
    await assertFails(setDoc(doc(coach, `coaches/${COACH}/media/new`), { status: 'approved' }));
    await assertFails(updateDoc(doc(coach, `coaches/${COACH}/media/wait`), { status: 'approved' }));
  });

  test('portfolio media closes with the portfolio switch', async () => {
    await reloadRules({ coachPortfolio: false });
    try {
      await seed(async (ctx) => {
        const f = ctx.firestore();
        await setDoc(doc(f, `coaches/${COACH}`), { displayName: 'Salma', published: true });
        await setDoc(doc(f, `coaches/${COACH}/media/ok`), { status: 'approved' });
      });
      await assertFails(getDoc(doc(await verified(HER), `coaches/${COACH}/media/ok`)));
      await assertFails(getDoc(doc(await verifiedCoach(COACH), `coaches/${COACH}/media/ok`)));
    } finally {
      await reloadRules();
    }
  });

  test('her application and private record are readable by her alone', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `coachApplications/${COACH}`), { status: 'submitted' });
      await setDoc(doc(f, `coachPrivate/${COACH}`), { payoutState: 'none' });
    });
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(coach, `coachApplications/${COACH}`)));
    await assertSucceeds(getDoc(doc(coach, `coachPrivate/${COACH}`)));
    await assertFails(setDoc(doc(coach, `coachApplications/${COACH}`), { status: 'approved' }));
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, `coachApplications/${COACH}`)));
    await assertFails(getDoc(doc(her, `coachPrivate/${COACH}`)));
  });

  test('what she already wrote stays as it is: no edit, no delete', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}`), { displayName: 'Salma' });
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}/offers/o1`), { price: 1 });
    });
    const db = await verifiedCoach(COACH);
    await assertFails(updateDoc(doc(db, `coaches/${COACH}`), { displayName: 'S' }));
    await assertFails(updateDoc(doc(db, `coaches/${COACH}/offers/o1`), { price: 2 }));
    await assertFails(deleteDoc(doc(db, `coaches/${COACH}/offers/o1`)));
  });

  test('no client creates or changes a relationship or a review', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `relationships/${COACH}__${OTHER}`), {
        coachUid: COACH, clientUid: OTHER, status: 'active', chatOpen: true,
      });
    });
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, `relationships/${COACH}__${HER}`), { coachUid: COACH, clientUid: HER }));
    const client = await verified(OTHER);
    await assertFails(setDoc(doc(client, `relationships/${COACH}__${OTHER}/reviews/r1`), { stars: 5 }));
    await assertFails(updateDoc(doc(client, `relationships/${COACH}__${OTHER}`), { note: 'x' }));
    await assertFails(updateDoc(doc(client, `relationships/${COACH}__${OTHER}`), { 'unreadFor.w_other_0002': 0 }));
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

describe('the clients side is open for the two parties, the money side is not', () => {
  const SUB = 's_1';
  const REL = `${COACH}__${HER}`;

  async function seedAll() {
    await clearAll();
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, `relationships/${REL}`), {
        coachUid: COACH, clientUid: HER, status: 'active', chatOpen: true,
        lastMessage: { text: 'hi', type: 'text', senderUid: HER, at: new Date() },
        unreadFor: { [COACH]: 1, [HER]: 0 },
      });
      await setDoc(doc(f, `relationships/${REL}/messages/m1`), {
        senderUid: HER, type: 'text', text: 'hi', createdAt: new Date(),
      });
      await setDoc(doc(f, `relationships/${REL}/reads/${HER}`), { at: new Date() });
      await setDoc(doc(f, `subscriptions/${SUB}`), {
        clientUid: HER, coachUid: COACH, status: 'active', free: true,
      });
      await setDoc(doc(f, `subscriptions/${SUB}/sessions/x1`), { startsAt: new Date() });
      await setDoc(doc(f, `plans/${HER}/coachPlans/p1`), { coachUid: COACH, kind: 'workout' });
      await setDoc(doc(f, `receipts/${SUB}`), { clientUid: HER });
      await setDoc(doc(f, 'coachingConfig/receivingAccounts'), { instapay: { enabled: true } });
    });
  }

  const clientReads = async () => {
    const client = await verified(HER);
    const coach = await verifiedCoach(COACH);
    return [
      [client, `relationships/${REL}`],
      [coach, `relationships/${REL}`],
      [client, `relationships/${REL}/messages/m1`],
      [client, `relationships/${REL}/reads/${HER}`],
      [client, `subscriptions/${SUB}`],
      [coach, `subscriptions/${SUB}`],
      [client, `subscriptions/${SUB}/sessions/x1`],
      [coach, `plans/${HER}/coachPlans/p1`],
    ];
  };
  const moneyReads = async () => {
    const client = await verified(HER);
    return [[client, `receipts/${SUB}`], [client, 'coachingConfig/receivingAccounts']];
  };

  test('the two parties read their relationship, chat, subscription, sessions and shared plans', async () => {
    await seedAll();
    for (const [db, path] of await clientReads()) {
      await assertSucceeds(getDoc(doc(db, path)));
    }
    const stranger = await verified(OTHER);
    await assertFails(getDoc(doc(stranger, `relationships/${REL}`)));
    await assertFails(getDoc(doc(stranger, `subscriptions/${SUB}`)));
  });

  test('a party can message and mark a read, but not touch the counters', async () => {
    await seedAll();
    const client = await verified(HER);
    await assertSucceeds(setDoc(doc(client, `relationships/${REL}/messages/m2`), {
      senderUid: HER, type: 'text', text: 'hello', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(doc(client, `relationships/${REL}/reads/${HER}`), {
      at: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(client, `relationships/${REL}`), { [`unreadFor.${HER}`]: 0 }));
    await assertFails(updateDoc(doc(client, `relationships/${REL}`), { lastMessage: { text: 'x' } }));
    await assertFails(setDoc(doc(client, `subscriptions/${SUB}`), { status: 'active' }));
  });

  test('receipts, payment proofs and receiving accounts stay closed', async () => {
    await seedAll();
    for (const [db, path] of await moneyReads()) {
      await assertFails(getDoc(doc(db, path)));
    }
    const client = await verified(HER);
    await assertFails(getDoc(doc(client, 'paymentProofs/pp1')));
  });

  test('flipping the payments switch opens receipts and the accounts', async () => {
    await reloadRules({ coachPayments: true });
    try {
      await seedAll();
      for (const [db, path] of await moneyReads()) {
        await assertSucceeds(getDoc(doc(db, path)));
      }
    } finally {
      await reloadRules();
    }
  });

  test('flipping the clients switch off closes the clients side and leaves money as it was', async () => {
    await reloadRules({ coachClients: false });
    try {
      await seedAll();
      for (const [db, path] of await clientReads()) {
        await assertFails(getDoc(doc(db, path)));
      }
      const client = await verified(HER);
      await assertFails(setDoc(doc(client, `relationships/${REL}/messages/m2`), {
        senderUid: HER, type: 'text', text: 'hello', createdAt: serverTimestamp(),
      }));
      for (const [db, path] of await moneyReads()) {
        await assertFails(getDoc(doc(db, path)));
      }
    } finally {
      await reloadRules();
    }
  });

  test('flipping the portfolio switch off closes the portfolio and leaves the clients side as it was', async () => {
    await reloadRules({ coachPortfolio: false });
    try {
      await seedAll();
      await seed(async (ctx) => {
        const f = ctx.firestore();
        await setDoc(doc(f, `coaches/${COACH}`), { displayName: 'Salma', published: true });
        await setDoc(doc(f, `coaches/${COACH}/packages/on`), { active: true });
        await setDoc(doc(f, `coaches/${COACH}/drafts/d1`), {
          kind: 'workout', name: 'Legs', body: {}, updatedAt: new Date(),
        });
        await setDoc(doc(f, `coachApplications/${COACH}`), { status: 'submitted' });
        await setDoc(doc(f, `coachPrivate/${COACH}`), { payoutState: 'none' });
      });
      const her = await verified(HER);
      const coach = await verifiedCoach(COACH);
      await assertFails(getDoc(doc(her, `coaches/${COACH}`)));
      await assertFails(getDoc(doc(her, `coaches/${COACH}/packages/on`)));
      await assertFails(getDoc(doc(coach, `coaches/${COACH}/drafts/d1`)));
      await assertFails(getDoc(doc(coach, `coachApplications/${COACH}`)));
      await assertFails(getDoc(doc(coach, `coachPrivate/${COACH}`)));
      await assertSucceeds(getDoc(doc(her, `relationships/${REL}`)));
    } finally {
      await reloadRules();
    }
  });
});

describe('payment details stay closed while payments are off', () => {
  test('a verified member cannot read the receiving accounts or the seller', async () => {
    await seed(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, 'coachingConfig/receivingAccounts'), { instapay: { address: 'x', enabled: true } });
      await setDoc(doc(f, 'coachingConfig/seller'), { legalNameEn: 'Own Hub' });
    });
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, 'coachingConfig/receivingAccounts')));
    await assertFails(getDoc(doc(her, 'coachingConfig/seller')));
  });
});
