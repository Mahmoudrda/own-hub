// Loose ends: claims the rules file makes about itself, guards that are
// stated on `write` (which silently includes delete), and collections that
// carry no field validation at all.

import { test, before, after, describe } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  getEnv, clearAll, seed, unverified, verified, uid, RULES_PATH,
  assertSucceeds, assertFails, observe, assert,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
  serverTimestamp,
} from 'firebase/firestore';

const HER = uid.her;

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe("the file's claim about itself", () => {
  test('there is exactly ONE match /users/{uid} and ONE match /coaches/{...}', () => {
    // The header says "there is exactly ONE `match /users/{uid}` block and ONE
    // for `match /coaches/{coachUid}` in this file, and a test asserts that".
    // No such test existed. This is it.
    const src = readFileSync(RULES_PATH, 'utf8');
    const code = src
      .split('\n')
      .filter((l) => !l.trim().startsWith('//'))
      .join('\n');
    const users = code.match(/match\s+\/users\/\{[A-Za-z]+\}\s*\{/g) ?? [];
    const coaches = code.match(/match\s+\/coaches\/\{[A-Za-z]+\}\s*\{/g) ?? [];
    assert.equal(users.length, 1, `found ${users.length} users match blocks`);
    assert.equal(coaches.length, 1, `found ${coaches.length} coaches match blocks`);
  });

  test('the deny-by-default catch-all is present and last', () => {
    const src = readFileSync(RULES_PATH, 'utf8');
    const idx = src.lastIndexOf('match /{document=**}');
    assert.ok(idx > 0, 'no catch-all found');
    const after = src.slice(idx);
    assert.match(after, /allow read,\s*write:\s*if false;/);
  });
});

describe('`allow write` silently covers delete', () => {
  test('splits: the ownerKind guard no longer eats DELETE', async (t) => {
    // It was `allow write: if isSelfVerified(uid)
    //                      && request.resource.data.ownerKind == 'self'`.
    // `write` covers delete, and on a delete `request.resource` is null — so
    // the field read errored and D7's "the split is hers" was unenforceable in
    // the one direction that lets her change her mind. The three verbs are now
    // stated separately.
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/splits/s1`), {
      ownerKind: 'self', name: 'Upper/Lower',
    }));
    const r = await observe('delete her own split', deleteDoc(doc(db, `users/${HER}/splits/s1`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });

  test('splits: the ownerKind guard still holds on create and update', async () => {
    const db = await verified(HER);
    // A coach-authored split is not hers to write into her own collection.
    await assertFails(setDoc(doc(db, `users/${HER}/splits/s_coach`), {
      ownerKind: 'coach', name: 'PPL',
    }));
    await assertFails(setDoc(doc(db, `users/${HER}/splits/s_none`), { name: 'PPL' }));
    // And the invariants reach it now, which they did not before.
    await assertFails(setDoc(doc(db, `users/${HER}/splits/s_streak`), {
      ownerKind: 'self', name: 'x', streak: 9,
    }));
    await assertFails(setDoc(doc(db, `users/${HER}/splits/s_clock`), {
      ownerKind: 'self', name: 'x', updatedAt: new Date('2099-01-01T00:00:00Z'),
    }));
    // Another woman's splits are not hers to delete.
    const other = await verified(uid.other);
    await assertFails(deleteDoc(doc(other, `users/${HER}/splits/s1`)));
  });

  test('meals, eatPrefs: delete is explicitly false, which is intended', async () => {
    const db = await verified(HER);
    await assertSucceeds(setDoc(doc(db, `users/${HER}/meals/2026-09-25`), {
      slots: {}, totals: { kcal: 0, protein: 0 },
    }));
    await assertFails(deleteDoc(doc(db, `users/${HER}/meals/2026-09-25`)));
    await assertSucceeds(setDoc(doc(db, `users/${HER}/eatPrefs/current`), {
      plates: {}, ramadanMode: 'auto',
    }));
    await assertFails(deleteDoc(doc(db, `users/${HER}/eatPrefs/current`)));
  });

  test('coaches subcollections: the isCoach guard does cover delete', async () => {
    const db = await (await import('./harness.js')).verifiedCoach(uid.coach);
    await assertSucceeds(setDoc(doc(db, `coaches/${uid.coach}`), { name: 'c' }));
    await assertSucceeds(setDoc(doc(db, `coaches/${uid.coach}/offers/o1`), { price: 1 }));
    await assertSucceeds(deleteDoc(doc(db, `coaches/${uid.coach}/offers/o1`)));
  });
});

describe('collections that used to carry no field validation at all', () => {
  test('users/{uid}/devices takes a token registration and nothing else', async (t) => {
    // It was `allow read, write: if isSelf(uid)` — no invariants, no whitelist,
    // no gate — and it sits OUTSIDE the whole-app gate on purpose, because the
    // push token is registered before the camera opens. An unconstrained
    // collection outside the gate is the worst of both.
    const who = 'w_device_0013';
    const db = await unverified(who);
    const r = await observe('devices document carrying a run counter and a hash',
      setDoc(doc(db, `users/${who}/devices/d1`), {
        token: 'tok', streak: 40, idHmac: 'x', anythingAtAll: { nested: true },
      }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');

    // The exception itself is intact: the real registration still works while
    // unverified, which is the whole reason this path is outside the gate.
    const ok = await observe('the token registration the client actually writes',
      setDoc(doc(db, `users/${who}/devices/d1`), {
        token: 'tok', platform: 'ios', appVersion: '1.0.0',
      }));
    t.diagnostic(`  ${ok.outcome.padEnd(8)} ${ok.label}`);
    assert.equal(ok.outcome, 'ALLOWED');
  });

  test('groups/{g}/members: no role, no roster, and not while unverified', async (t) => {
    const who = 'w_member_0014';
    const db = await unverified(who);
    const r = await observe('members document carrying a role and a streak',
      setDoc(doc(db, `groups/g1/members/${who}`), {
        role: 'admin', streak: 99, moderator: true,
      }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');

    const verifiedMember = await verified(who);
    const r2 = await observe('the same document, verified',
      setDoc(doc(verifiedMember, `groups/g1/members/${who}`), {
        role: 'admin', moderator: true,
      }));
    const r3 = await observe('joining, verified',
      setDoc(doc(verifiedMember, `groups/g1/members/${who}`), { joinedAt: new Date() }));
    // The client says in three places that `members` is `allow list: if false`
    // — "4,210 women are not a list to scrape". The rules said `allow read`,
    // which grants list. They now say what the client already believed.
    const r4 = await observe('list the roster',
      getDocs(collection(verifiedMember, 'groups/g1/members')));
    const r5 = await observe('read her own membership',
      getDoc(doc(verifiedMember, `groups/g1/members/${who}`)));
    for (const r of [r2, r3, r4, r5]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r2.outcome, 'DENIED');
    assert.equal(r3.outcome, 'ALLOWED');
    assert.equal(r4.outcome, 'DENIED');
    assert.equal(r5.outcome, 'ALLOWED');
  });

  test('posts can no longer be BORN with server-maintained counts', async (t) => {
    // `allow update` forbids touching `counts`; `allow create` did not, and
    // clientInvariants() was applied nowhere outside users/{uid}.
    const db = await verified(HER);
    const r = await observe('post born with counts.likes = 99999',
      setDoc(doc(db, 'posts/p_inflated'), {
        authorUid: HER, blurred: true, body: 'x',
        counts: { likes: 99999, comments: 99999 },
      }));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'DENIED');
    const r2 = await observe('post born with a run counter',
      setDoc(doc(db, 'posts/p_streak'), {
        authorUid: HER, blurred: true, streak: 40,
      }));
    t.diagnostic(`  ${r2.outcome.padEnd(8)} ${r2.label}`);
    assert.equal(r2.outcome, 'DENIED');

    // And a comment, which had the same gap.
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'posts/p_host'), {
        authorUid: HER, blurred: true,
      });
    });
    const r3 = await observe('comment born with a run counter',
      setDoc(doc(db, 'posts/p_host/comments/c_streak'), {
        authorUid: HER, body: 'x', dayStreak: 12,
      }));
    t.diagnostic(`  ${r3.outcome.padEnd(8)} ${r3.label}`);
    assert.equal(r3.outcome, 'DENIED');

    // The ordinary post still posts.
    await assertSucceeds(setDoc(doc(db, 'posts/p_ordinary'), {
      authorUid: HER, blurred: true, body: 'first session done',
    }));
  });

  test('a post still cannot be forged under someone else\'s name', async () => {
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, 'posts/p_forged'), {
      authorUid: uid.other, blurred: true,
    }));
    await assertFails(setDoc(doc(db, 'posts/p_noblur'), { authorUid: HER }));
    await assertFails(setDoc(doc(db, 'posts/p_blurstr'), {
      authorUid: HER, blurred: 'true',
    }));
  });
});

describe('deletionRequests: the exception the header describes is read-only', () => {
  test('MEASURED: can a woman who was never verified actually ask to leave?', async (t) => {
    const who = 'w_leaving_0015';
    const db = await unverified(who);
    const r1 = await observe('create her own deletion request',
      setDoc(doc(db, `deletionRequests/${who}`), { state: 'requested' }));
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `deletionRequests/${who}`), { state: 'running' });
    });
    const r2 = await observe('read it once the server has written it',
      getDoc(doc(db, `deletionRequests/${who}`)));
    const r3 = await observe('list deletionRequests',
      getDocs(collection(db, 'deletionRequests')));
    const r4 = await observe('mark it done herself',
      updateDoc(doc(db, `deletionRequests/${who}`), { state: 'done' }));
    for (const r of [r1, r2, r3, r4]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    t.diagnostic(
      '  => the exception grants READ only; creating the request must be a callable',
    );
    assert.equal(r2.outcome, 'ALLOWED');
    assert.equal(r4.outcome, 'DENIED');
  });
});

describe('notifications: a client cannot put text in front of a woman', () => {
  test('create and delete are closed; only three fields may be updated', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${HER}/notifications/n1`), {
        body: 'server text', read: false,
      });
    });
    const db = await verified(HER);
    await assertFails(setDoc(doc(db, `users/${HER}/notifications/n_forged`), {
      body: 'anything I like',
    }));
    await assertFails(deleteDoc(doc(db, `users/${HER}/notifications/n1`)));
    await assertFails(updateDoc(doc(db, `users/${HER}/notifications/n1`), {
      body: 'rewritten',
    }));
    await assertFails(updateDoc(doc(db, `users/${HER}/notifications/n1`), {
      outcome: 'something_else',
    }));
    await assertSucceeds(updateDoc(doc(db, `users/${HER}/notifications/n1`), {
      read: true, readAt: new Date(), outcome: 'dismissed',
    }));
  });
});

describe('paths the client code references but the rules never declare', () => {
  test('MEASURED: relationship subcollections the coached feature uses', async (t) => {
    // app/lib/features/coached/** and coachplan/** address these. The rules
    // declare only `messages` and `reviews` under relationships, so everything
    // else lands on the deny-by-default catch-all.
    const rel = `${uid.coach}__${HER}`;
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `relationships/${rel}`), {
        coachUid: uid.coach, clientUid: HER, status: 'active',
      });
      for (const p of [
        `relationships/${rel}/intake/current`,
        `relationships/${rel}/clientView/current`,
        `relationships/${rel}/shared/constraints`,
        `relationships/${rel}/rollups/2026-W39`,
      ]) await setDoc(doc(d, p), { seeded: true });
    });
    const db = await verified(HER);
    for (const [label, path] of [
      ['intake/current', `relationships/${rel}/intake/current`],
      ['clientView/current', `relationships/${rel}/clientView/current`],
      ['shared/constraints', `relationships/${rel}/shared/constraints`],
      ['rollups/2026-W39', `relationships/${rel}/rollups/2026-W39`],
    ]) {
      const r = await observe(`read  ${label}`, getDoc(doc(db, path)));
      const w = await observe(`write ${label}`, setDoc(doc(db, path), { x: 1 }));
      t.diagnostic(`  ${r.outcome.padEnd(8)} read   ${label}`);
      t.diagnostic(`  ${w.outcome.padEnd(8)} write  ${label}`);
    }
  });

  test('MEASURED: the four collections the rules file names as STILL MISSING', async (t) => {
    const db = await verified(HER);
    for (const c of ['planDrafts', 'media', 'enquiries', 'payments']) {
      const r = await observe(`read  ${c}`, getDoc(doc(db, `${c}/x1`)));
      const w = await observe(`write ${c}`, setDoc(doc(db, `${c}/x1`), { x: 1 }));
      t.diagnostic(`  ${r.outcome.padEnd(8)}/${w.outcome.padEnd(8)} read/write ${c}`);
    }
    t.diagnostic('  => all four fall to the catch-all, which is deny — safe but non-functional');
  });
});

describe('cross-relationship message read (the isParty scoping bug, closed)', () => {
  test('a stranger cannot read a message whose fields name her', async (t) => {
    // isParty() inside the messages match used to read the MESSAGE's own
    // coachUid / clientUid, so access was decided by the content of the
    // document being read rather than by the relationship it lives in. A
    // message that happened to carry a stranger's uid was readable by her.
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `relationships/${uid.coach}__${uid.other}`), {
        coachUid: uid.coach, clientUid: uid.other,
      });
      // A message inside a relationship HER is not part of, which happens to
      // carry her uid in a party field.
      await setDoc(
        doc(d, `relationships/${uid.coach}__${uid.other}/messages/m_names_her`),
        { senderUid: uid.coach, body: 'private', clientUid: HER, coachUid: uid.coach },
      );
    });
    const her = await verified(HER);
    const r1 = await observe('read the relationship she is NOT part of',
      getDoc(doc(her, `relationships/${uid.coach}__${uid.other}`)));
    const r2 = await observe('read a message in it that names her in clientUid',
      getDoc(doc(her, `relationships/${uid.coach}__${uid.other}/messages/m_names_her`)));
    const r3 = await observe('list that thread',
      getDocs(collection(her, `relationships/${uid.coach}__${uid.other}/messages`)));
    for (const r of [r1, r2, r3]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    t.diagnostic(
      '  => message access is decided by the PARENT relationship, not by the ' +
      'message document',
    );
    assert.equal(r1.outcome, 'DENIED');
    assert.equal(r2.outcome, 'DENIED');
    assert.equal(r3.outcome, 'DENIED');
  });
});
