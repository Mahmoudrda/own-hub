// notBlockedBy(), newly wired to four single-document writes and never run.
//
//   1. posts/{postId}/comments               — create
//   2. followGraph/{owner}/{edge}/{other}    — create and update
//   3. relationships/{relId}/messages        — create
//   4. relationships/{relId}                 , create (server-only now)
//
// and DELIBERATELY not attached to:
//
//   * followGraph delete   — or a block traps a stale follow edge forever
//   * reports create       — or a harasser silences his victim by blocking her
//
// Both halves get tested. The second half is the one that protects a woman.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, verified, verifiedCoach, uid,
  assertSucceeds, assertFails, observe, assert, switchDormantFeaturesOn,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
  serverTimestamp,
} from 'firebase/firestore';

// The rules behind the community and coach switches (APL-16), tested as they
// will be when the features ship. 16-dormant-features covers the switches.
switchDormantFeaturesOn();

// BLOCKER has blocked BLOCKED. Nothing the other way round.
const BLOCKER = uid.blocker;
const BLOCKED = uid.blocked;

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    // The block, and its Function-written mirror.
    await setDoc(doc(d, `users/${BLOCKER}/blocks/${BLOCKED}`), {
      createdAt: new Date(), source: 'post',
    });
    await setDoc(doc(d, `users/${BLOCKED}/blockedBy/${BLOCKER}`), {
      createdAt: new Date(),
    });
    // A post by each of them.
    await setDoc(doc(d, 'posts/p_blocker'), { authorUid: BLOCKER, blurred: true });
    await setDoc(doc(d, 'posts/p_blocked'), { authorUid: BLOCKED, blurred: true });
    await setDoc(doc(d, 'posts/p_bystander'), { authorUid: uid.her, blurred: true });
    // A live coaching relationship between the two of them.
    await setDoc(doc(d, `relationships/${BLOCKER}__${BLOCKED}`), {
      coachUid: BLOCKER, clientUid: BLOCKED, status: 'active', chatOpen: true,
    });

    // The coach pages. `relationships` create now requires `coachUid` to be a
    // real coach — the second half of the escalation fix in §03 — so a fixture
    // that calls someone "the coach" has to make him one. BLOCKER already acts
    // as the coach on the relationship above; this is what the seed was
    // missing rather than something the fix demands.
    await setDoc(doc(d, `coaches/${BLOCKER}`), { name: 'Coach Blocker' });
    await setDoc(doc(d, `coachPrivate/${BLOCKER}`), { owedEgp: 0 });
    await setDoc(doc(d, `coaches/${uid.coach}`), { name: 'Coach' });
    await setDoc(doc(d, `coachPrivate/${uid.coach}`), { owedEgp: 0 });
    // A SECOND coach, who has blocked BLOCKED. The relationship between them
    // does not exist yet, so a create against the canonical id is a real
    // create and the block check is genuinely the thing that refuses it.
    await setDoc(doc(d, `coaches/${uid.coach2}`), { name: 'Coach Two' });
    await setDoc(doc(d, `coachPrivate/${uid.coach2}`), { owedEgp: 0 });
    await setDoc(doc(d, `users/${uid.coach2}/blocks/${BLOCKED}`), {
      createdAt: new Date(), source: 'message',
    });
  });
});
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('1. comment create', () => {
  test('the blocked man cannot comment under the blocker\'s post', async () => {
    const db = await verified(BLOCKED);
    await assertFails(
      setDoc(doc(db, 'posts/p_blocker/comments/c_should_not_exist'), {
        authorUid: BLOCKED, body: 'still here', createdAt: new Date(),
      }),
    );
  });

  test('the BLOCKER can still comment under the blocked person\'s post', async () => {
    const db = await verified(BLOCKER);
    await assertSucceeds(
      setDoc(doc(db, 'posts/p_blocked/comments/c_blocker'), {
        authorUid: BLOCKER, body: 'hers to write', createdAt: new Date(),
      }),
    );
  });

  test('a bystander is unaffected, and so is the blocked person elsewhere', async () => {
    const bystander = await verified(uid.her);
    await assertSucceeds(
      setDoc(doc(bystander, 'posts/p_blocker/comments/c_bystander'), {
        authorUid: uid.her, body: 'fine', createdAt: new Date(),
      }),
    );
    const blocked = await verified(BLOCKED);
    await assertSucceeds(
      setDoc(doc(blocked, 'posts/p_bystander/comments/c_elsewhere'), {
        authorUid: BLOCKED, body: 'fine', createdAt: new Date(),
      }),
    );
  });

  test('READING the blocker\'s post and its comments is still allowed', async (t) => {
    // Deliberate: the feed is a list query and a denial would leak the block.
    const db = await verified(BLOCKED);
    const r1 = await observe('read posts/p_blocker', getDoc(doc(db, 'posts/p_blocker')));
    const r2 = await observe('list its comments',
      getDocs(collection(db, 'posts/p_blocker/comments')));
    const r3 = await observe('read the blocker\'s public profile',
      getDoc(doc(db, `publicProfiles/${BLOCKER}`)));
    for (const r of [r1, r2, r3]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'ALLOWED');
  });

  test('a comment on a post that does not exist is denied', async () => {
    const db = await verified(uid.her);
    await assertFails(
      setDoc(doc(db, 'posts/p_nonexistent/comments/c1'), {
        authorUid: uid.her, body: 'x',
      }),
    );
  });
});

describe('2. followGraph create, update and delete', () => {
  test('the blocked man cannot create a follow edge towards the blocker', async () => {
    const db = await verified(BLOCKED);
    await assertFails(
      setDoc(doc(db, `followGraph/${BLOCKED}/following/${BLOCKER}`), {
        at: new Date(),
      }),
    );
  });

  test('he cannot update one either', async () => {
    await seed(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `followGraph/${BLOCKED}/following/${BLOCKER}`),
        { at: new Date(), note: 'pre-existing, from before the block' },
      );
    });
    const db = await verified(BLOCKED);
    await assertFails(
      updateDoc(doc(db, `followGraph/${BLOCKED}/following/${BLOCKER}`), {
        note: 'changed',
      }),
    );
  });

  test('DELETE stays open, so the block cannot trap a stale edge', async (t) => {
    const db = await verified(BLOCKED);
    const r = await observe('unfollow someone who has blocked you',
      deleteDoc(doc(db, `followGraph/${BLOCKED}/following/${BLOCKER}`)));
    t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r.outcome, 'ALLOWED');
  });

  test('the BLOCKER can still create an edge towards the blocked person', async () => {
    const db = await verified(BLOCKER);
    await assertSucceeds(
      setDoc(doc(db, `followGraph/${BLOCKER}/following/${BLOCKED}`), {
        at: new Date(),
      }),
    );
  });

  test('nobody can write an edge in someone else\'s graph', async () => {
    const db = await verified(uid.her);
    await assertFails(
      setDoc(doc(db, `followGraph/${BLOCKER}/following/${uid.her}`), { at: new Date() }),
    );
    await assertFails(
      deleteDoc(doc(db, `followGraph/${BLOCKER}/following/${BLOCKED}`)),
    );
  });
});

describe('3. relationship create', () => {
  // A relationship is written by the coaching service only. The block check
  // that used to guard a client create has nothing left to guard, so every
  // shape is refused, including the one that used to be legitimate.
  test('nobody opens a relationship from the app, blocked or not', async () => {
    const blocked = await verified(BLOCKED);
    await assertFails(
      setDoc(doc(blocked, `relationships/${uid.coach2}__${BLOCKED}`), {
        coachUid: uid.coach2, clientUid: BLOCKED,
      }),
    );
    await assertFails(
      setDoc(doc(blocked, `relationships/${BLOCKER}__${BLOCKED}_new`), {
        coachUid: BLOCKER, clientUid: BLOCKED,
      }),
    );
    const her = await verified(uid.her);
    await assertFails(
      setDoc(doc(her, `relationships/${BLOCKER}__${uid.her}`), {
        coachUid: BLOCKER, clientUid: uid.her,
      }),
    );
  });
});

describe('4. message create — the happy path and the blocked path', () => {
  // isParty() used to read `resource.data.coachUid` from inside the `messages`
  // match, where `resource` is the MESSAGE. A message has no coachUid, so the
  // read errored and the write was denied — for the coach, for the client, and
  // on the happy path for both. Coach messaging was entirely unusable, and
  // notBlockedBy on this rule had therefore never once been reached: the block
  // test below passed because nobody could message at all.
  //
  // Both halves are now asserted, which is the only way this cannot regress
  // into a false pass again.
  test('the happy path works: a client messages her coach, and the coach replies', async (t) => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `relationships/${uid.coach}__${uid.her}`), {
        coachUid: uid.coach, clientUid: uid.her, status: 'active', chatOpen: true,
      });
    });
    const her = await verified(uid.her);
    const coach = await verifiedCoach(uid.coach);
    const r1 = await observe('client messages a coach who never blocked her',
      setDoc(doc(her, `relationships/${uid.coach}__${uid.her}/messages/m_happy`), {
        senderUid: uid.her, type: 'text', text: 'hello coach', createdAt: serverTimestamp(),
      }));
    const r2 = await observe('coach replies',
      setDoc(doc(coach, `relationships/${uid.coach}__${uid.her}/messages/m_reply`), {
        senderUid: uid.coach, type: 'text', text: 'hello', createdAt: serverTimestamp(),
      }));
    for (const r of [r1, r2]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'ALLOWED', 'coach messaging is unusable again');
    assert.equal(r2.outcome, 'ALLOWED', 'coach messaging is unusable again');
  });

  test('the blocked path works: the block now actually refuses a message', async (t) => {
    const rel = `${BLOCKER}__${BLOCKED}`;
    const asCoach = await verified(BLOCKER);
    const asClient = await verified(BLOCKED);

    // The coach blocked the client. He may still write to her — a block is not
    // a mute on yourself — and she may not write to him.
    const r1 = await observe('coach (the blocker) sends a message',
      setDoc(doc(asCoach, `relationships/${rel}/messages/m_coach`), {
        senderUid: BLOCKER, type: 'text', text: 'hello', createdAt: serverTimestamp(),
      }));
    const r2 = await observe('client (the blocked one) sends a message',
      setDoc(doc(asClient, `relationships/${rel}/messages/m_client`), {
        senderUid: BLOCKED, type: 'text', text: 'hello', createdAt: serverTimestamp(),
      }));
    for (const r of [r1, r2]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'ALLOWED');
    assert.equal(r2.outcome, 'DENIED',
      'notBlockedBy is unreachable on message create again');
  });

  test('a sender cannot put someone else\'s name on a message', async () => {
    const her = await verified(uid.her);
    await assertFails(
      setDoc(doc(her, `relationships/${uid.coach}__${uid.her}/messages/m_forged`), {
        senderUid: uid.coach, type: 'text', text: 'from your coach', createdAt: serverTimestamp(),
      }),
    );
  });

  test('both parties can READ the thread', async (t) => {
    const rel = `${uid.coach}__${uid.her}`;
    await seed(async (ctx) => {
      const d = ctx.firestore();
      // A message as the product would store it.
      await setDoc(doc(d, `relationships/${rel}/messages/m_seed`), {
        senderUid: uid.coach, body: 'seeded by the server', createdAt: new Date(),
      });
      // And one that happens to carry the parent's party fields.
      await setDoc(doc(d, `relationships/${rel}/messages/m_with_parties`), {
        senderUid: uid.coach, body: 'x',
        coachUid: uid.coach, clientUid: uid.her,
      });
    });
    const her = await verified(uid.her);
    const r1 = await observe('read the relationship document itself',
      getDoc(doc(her, `relationships/${rel}`)));
    const r2 = await observe('read a plain message document',
      getDoc(doc(her, `relationships/${rel}/messages/m_seed`)));
    const r3 = await observe('read a message that carries coachUid + clientUid',
      getDoc(doc(her, `relationships/${rel}/messages/m_with_parties`)));
    const r4 = await observe('list the thread',
      getDocs(collection(her, `relationships/${rel}/messages`)));
    for (const r of [r1, r2, r3, r4]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    for (const r of [r1, r2, r3, r4]) assert.equal(r.outcome, 'ALLOWED', r.label);
    t.diagnostic(
      '  => access is decided by the PARENT relationship, loaded with get(), ' +
      'not by whatever the message happens to say about itself',
    );
  });

  test('reviews are read by the parties and written by nobody', async (t) => {
    const rel = `${uid.coach}__${uid.her}`;
    const her = await verified(uid.her);
    const r1 = await observe('create a review',
      setDoc(doc(her, `relationships/${rel}/reviews/rev1`), {
        stars: 5, body: 'great coach',
      }));
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `relationships/${rel}/reviews/rev_seed`), {
        stars: 4, coachUid: uid.coach, clientUid: uid.her,
      });
    });
    const r2 = await observe('read a review carrying the party fields',
      getDoc(doc(her, `relationships/${rel}/reviews/rev_seed`)));
    const stranger = await verified(uid.other);
    const r3 = await observe('a stranger writes a review under their relationship',
      setDoc(doc(stranger, `relationships/${rel}/reviews/rev_forged`), { stars: 1 }));
    for (const r of [r1, r2, r3]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'DENIED');
    assert.equal(r2.outcome, 'ALLOWED', 'reviews are unreadable again');
    assert.equal(r3.outcome, 'DENIED');
  });

  test('a message carrying plan fields is refused (rule 2)', async (t) => {
    // Rule 2: a message never changes a plan. Now that create works, this is a
    // test of the field guard rather than of the broken party check.
    const rel = `${uid.coach}__${uid.her}`;
    const her = await verified(uid.her);
    for (const key of ['planVersion', 'assignments', 'published']) {
      const r = await observe(`message carrying \`${key}\``,
        setDoc(doc(her, `relationships/${rel}/messages/m_${key}`), {
          senderUid: uid.her, body: 'x', [key]: 'anything',
        }));
      t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
      assert.equal(r.outcome, 'DENIED');
    }
  });
});

describe('5. THE ONE THAT MUST NOT BE GATED: reports', () => {
  test('a blocked woman can still report the man who blocked her', async () => {
    const db = await verified(BLOCKED);
    await assertSucceeds(
      setDoc(doc(db, 'reports/r_victim_of_blocker'), {
        reporterUid: BLOCKED, subjectUid: BLOCKER, subjectKind: 'user',
        subjectRef: `users/${BLOCKER}`, reason: 'harassment',
        note: 'he blocked me after sending these',
        state: 'submitted', createdAt: serverTimestamp(),
        locale: 'ar', appVersion: '1.0.0',
      }),
    );
  });

  test('she can report his post and his comment too', async () => {
    const db = await verified(BLOCKED);
    for (const [id, ref] of [
      ['r_post', 'posts/p_blocker'],
      ['r_comment', 'posts/p_blocker/comments/c_blocker'],
    ]) {
      await assertSucceeds(
        setDoc(doc(db, `reports/${id}`), {
          reporterUid: BLOCKED, subjectUid: BLOCKER, subjectKind: 'post',
          subjectRef: ref, reason: 'harassment', state: 'submitted',
          createdAt: serverTimestamp(),
        }),
      );
    }
  });

  test('she can block him back while he has her blocked', async () => {
    const db = await verified(BLOCKED);
    await assertSucceeds(
      setDoc(doc(db, `users/${BLOCKED}/blocks/${BLOCKER}`), {
        createdAt: serverTimestamp(), source: 'safety_centre',
      }),
    );
  });

  test('the report rule still validates: forged clock, self-report, free text', async () => {
    const db = await verified(BLOCKED);
    const base = {
      reporterUid: BLOCKED, subjectUid: BLOCKER, subjectKind: 'user',
      subjectRef: 'x', reason: 'harassment', state: 'submitted',
      createdAt: serverTimestamp(),
    };
    // A forgeable createdAt is a forgeable one-hour first-response deadline.
    await assertFails(setDoc(doc(db, 'reports/r_backdated'), {
      ...base, createdAt: new Date('2020-01-01'),
    }));
    await assertFails(setDoc(doc(db, 'reports/r_self'), {
      ...base, subjectUid: BLOCKED,
    }));
    await assertFails(setDoc(doc(db, 'reports/r_reason'), {
      ...base, reason: 'whatever the client felt like',
    }));
    await assertFails(setDoc(doc(db, 'reports/r_state'), {
      ...base, state: 'resolved',
    }));
    await assertFails(setDoc(doc(db, 'reports/r_longnote'), {
      ...base, note: 'x'.repeat(1001),
    }));
    await assertFails(setDoc(doc(db, 'reports/r_forged_reporter'), {
      ...base, reporterUid: uid.her,
    }));
    await assertFails(setDoc(doc(db, 'reports/r_extra_key'), {
      ...base, extraKey: 'not in the whitelist',
    }));
  });
});

describe('6. the cost note: notBlockedBy must not sit on a list query', () => {
  test('feed reads and profile search stay open to a blocked account', async (t) => {
    const db = await verified(BLOCKED);
    const r1 = await observe('list posts', getDocs(collection(db, 'posts')));
    const r2 = await observe('list publicProfiles',
      getDocs(collection(db, 'publicProfiles')));
    const r3 = await observe('list followGraph edges',
      getDocs(collection(db, `followGraph/${BLOCKER}/following`)));
    for (const r of [r1, r2, r3]) t.diagnostic(`  ${r.outcome.padEnd(8)} ${r.label}`);
    assert.equal(r1.outcome, 'ALLOWED');
    assert.equal(r2.outcome, 'ALLOWED');
  });
});
