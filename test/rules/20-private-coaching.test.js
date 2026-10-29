// Private coaching: who may read and write what, with the coaching switches on.
//
// Almost everything here is server-written, so most of the file proves a
// door is closed: no client creates a coach page, a relationship, a
// subscription, a proof, a receipt or a plan. What a client may write is two
// small things, a chat message (text or a shared recipe) and a read marker,
// plus a coach's own drafts. The switch-off half of the same story is in
// 16-dormant-features.

import { test, before, after, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  getEnv, clearAll, seed, anon, unverified, unverifiedCoach, verified, verifiedCoach, admin, uid,
  assertSucceeds, assertFails, switchDormantFeaturesOn,
} from './harness.js';
import {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection, query, where,
  serverTimestamp,
} from 'firebase/firestore';

switchDormantFeaturesOn();

const HER = uid.her;
const OTHER = uid.other;
const COACH = uid.coach;
const COACH2 = uid.coach2;
const BLOCKER = uid.blocker;
const BLOCKED = uid.blocked;

const REL = `${COACH}__${HER}`;
const REL_ENDED = `${COACH2}__${HER}`;
const REL_BLOCK = `${BLOCKER}__${BLOCKED}`;
const REL_CLOSED = `${COACH}__${OTHER}`;

const OPEN = ['requested', 'awaiting_payment', 'payment_review', 'active'];
const ALL_STATUSES = [...OPEN, 'ended', 'declined', 'cancelled', 'expired', 'payment_failed', 'ended_early'];
const CLOSED = ALL_STATUSES.filter((x) => !OPEN.includes(x));

async function seedAll() {
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, `coaches/${COACH}`), { displayName: 'Salma', published: true, acceptingClients: true });
    await setDoc(doc(d, `coaches/${COACH2}`), { displayName: 'Dina', published: false, acceptingClients: false });
    await setDoc(doc(d, `coaches/${BLOCKER}`), { displayName: 'Blocker', published: false, acceptingClients: false });
    await setDoc(doc(d, `coachPrivate/${BLOCKER}`), { owedEgp: 0 });
    await setDoc(doc(d, `coaches/${COACH}/packages/p_on`), { title: 'Eight weeks', priceFinalEgp: 2000, active: true });
    await setDoc(doc(d, `coaches/${COACH}/packages/p_off`), { title: 'Old', priceFinalEgp: 900, active: false });
    await setDoc(doc(d, `coaches/${COACH}/media/m_ok`), { status: 'approved', kind: 'photo' });
    await setDoc(doc(d, `coaches/${COACH}/media/m_wait`), { status: 'pending', kind: 'photo' });
    await setDoc(doc(d, `coaches/${COACH}/drafts/d_seed`), {
      kind: 'workout', name: 'Legs', body: {}, updatedAt: new Date(),
    });

    await setDoc(doc(d, `relationships/${REL}`), {
      coachUid: COACH, clientUid: HER, status: 'active', chatOpen: true, activeSubId: 's1',
    });
    await setDoc(doc(d, `relationships/${REL_ENDED}`), {
      coachUid: COACH2, clientUid: HER, status: 'ended', chatOpen: false,
    });
    await setDoc(doc(d, `relationships/${REL_BLOCK}`), {
      coachUid: BLOCKER, clientUid: BLOCKED, status: 'active', chatOpen: true,
    });
    await setDoc(doc(d, `relationships/${REL_CLOSED}`), {
      coachUid: COACH, clientUid: OTHER, status: 'active', chatOpen: false,
    });
    await setDoc(doc(d, `users/${BLOCKER}/blocks/${BLOCKED}`), { createdAt: new Date(), source: 'chat' });
    await setDoc(doc(d, `relationships/${REL}/messages/m_seed`), {
      senderUid: COACH, type: 'text', text: 'welcome', createdAt: new Date(),
    });

    await setDoc(doc(d, `plans/${HER}/published/current`), { note: 'private training plan' });
    await setDoc(doc(d, `plans/${HER}/coachPlans/pl_a`), { kind: 'workout', coachUid: COACH, name: 'Week 1' });
    await setDoc(doc(d, `plans/${HER}/coachPlans/pl_b`), { kind: 'meal', coachUid: COACH2, name: 'Meals' });

    await setDoc(doc(d, 'subscriptions/s1'), { clientUid: HER, coachUid: COACH, status: 'active', priceFinalEgp: 2000 });
    await setDoc(doc(d, 'subscriptions/s2'), { clientUid: OTHER, coachUid: COACH2, status: 'requested', priceFinalEgp: 900 });
    for (const st of ALL_STATUSES) {
      await setDoc(doc(d, `subscriptions/st_${st}`), { clientUid: HER, coachUid: COACH, status: st, intake: { health: ['heart'] } });
      await setDoc(doc(d, `subscriptions/st_${st}/sessions/x1`), { status: 'proposed', minutes: 30 });
    }
    await setDoc(doc(d, 'subscriptions/s1/private/terms'), { coachPriceEgp: 1700 });
    await setDoc(doc(d, 'subscriptions/s1/sessions/x1'), { status: 'confirmed', minutes: 45 });

    await setDoc(doc(d, `coachApplications/${COACH}`), { status: 'approved' });
    await setDoc(doc(d, `coachPrivate/${COACH}`), { owedEgp: 1700 });
    await setDoc(doc(d, `coachPrivate/${COACH}/ledger/s1`), { coachAmountEgp: 1700, status: 'pending' });
    await setDoc(doc(d, `coachPrivate/${COACH}/prices/p_on`), { coachPriceEgp: 1700 });

    await setDoc(doc(d, 'coachingConfig/receivingAccounts'), { instapay: { address: 'x', enabled: true }, version: 1 });
    await setDoc(doc(d, 'coachingConfig/seller'), { legalNameEn: 'Own Hub' });
    await setDoc(doc(d, 'coachingConfig/receiptCounter'), { year: 2026, seq: 1 });
    await setDoc(doc(d, 'receipts/s1'), { clientUid: HER, number: 'R-1' });
    await setDoc(doc(d, 'paymentProofs/pp1'), { subId: 's1', clientUid: HER });
    await setDoc(doc(d, 'paymentRefs/instapay_123'), { subId: 's1' });
  });
}

before(async () => { await getEnv(); await seedAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

describe('coach pages: published to verified members, never client-written', () => {
  test('a verified member reads a published coach and her active packages', async () => {
    const her = await verified(HER);
    await assertSucceeds(getDoc(doc(her, `coaches/${COACH}`)));
    await assertSucceeds(getDoc(doc(her, `coaches/${COACH}/packages/p_on`)));
    await assertSucceeds(getDocs(query(collection(her, 'coaches'), where('published', '==', true))));
  });

  test('an unpublished coach is invisible to members and visible to herself', async () => {
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, `coaches/${COACH2}`)));
    await assertFails(getDocs(collection(her, 'coaches')));
    const own = await verifiedCoach(COACH2);
    await assertSucceeds(getDoc(doc(own, `coaches/${COACH2}`)));
  });

  test('an inactive package is hidden from members and shown to its coach', async () => {
    const her = await verified(HER);
    await assertFails(getDoc(doc(her, `coaches/${COACH}/packages/p_off`)));
    const own = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(own, `coaches/${COACH}/packages/p_off`)));
  });

  test('a member lists a published page\'s approved media only when she asks for approved', async () => {
    const her = await verified(HER);
    const media = collection(her, `coaches/${COACH}/media`);
    await assertSucceeds(getDocs(query(media, where('status', '==', 'approved'))));
    await assertFails(getDocs(media));
    await assertFails(getDocs(query(media, where('status', '==', 'pending'))));
    const own = await verifiedCoach(COACH);
    await assertSucceeds(getDocs(collection(own, `coaches/${COACH}/media`)));
  });

  test('a signed-out or unverified account reads nothing', async () => {
    await assertFails(getDoc(doc(await anon(), `coaches/${COACH}`)));
    await assertFails(getDoc(doc(await unverified(HER), `coaches/${COACH}`)));
    await assertFails(getDoc(doc(await unverified(HER), `coaches/${COACH}/packages/p_on`)));
  });

  test('nobody writes a coach page or a package from a client, the coach included', async () => {
    const own = await verifiedCoach(COACH);
    await assertFails(updateDoc(doc(own, `coaches/${COACH}`), { published: true, fromPriceEgp: 1 }));
    await assertFails(setDoc(doc(own, `coaches/${COACH}`), { displayName: 'New' }));
    await assertFails(deleteDoc(doc(own, `coaches/${COACH}`)));
    await assertFails(setDoc(doc(own, `coaches/${COACH}/packages/p_new`), { title: 'x', priceFinalEgp: 1, active: true }));
    await assertFails(updateDoc(doc(own, `coaches/${COACH}/packages/p_on`), { priceFinalEgp: 1 }));
    const ad = await admin('a_admin_0009');
    await assertFails(updateDoc(doc(ad, `coaches/${COACH}`), { published: false }));
  });

  test('the old portfolio, offers, results, ads, splits and reviews paths are closed to writes', async () => {
    const own = await verifiedCoach(COACH);
    for (const sub of ['portfolio/v1', 'offers/o1', 'results/r1', 'ads/a1', 'splits/s1']) {
      await assertFails(setDoc(doc(own, `coaches/${COACH}/${sub}`), { x: 1 }));
    }
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}/offers/o_old`), { price: 1 });
      await setDoc(doc(ctx.firestore(), `coaches/${COACH}/ads/a_old`), { copy: 'x' });
      await setDoc(doc(ctx.firestore(), `relationships/${REL}/reviews/rev_old`), { stars: 5 });
    });
    await assertFails(deleteDoc(doc(own, `coaches/${COACH}/offers/o_old`)));
    await assertFails(deleteDoc(doc(own, `coaches/${COACH}/ads/a_old`)));
    const her = await verified(HER);
    await assertFails(setDoc(doc(her, `relationships/${REL}/reviews/rev_new`), { stars: 5 }));
    await assertFails(deleteDoc(doc(her, `relationships/${REL}/reviews/rev_old`)));
    await assertSucceeds(getDoc(doc(her, `relationships/${REL}/reviews/rev_old`)));
  });
});

describe('coach drafts: hers alone, bounded', () => {
  const good = () => ({ kind: 'workout', name: 'Legs', body: { days: [] }, updatedAt: serverTimestamp() });

  test('a coach creates, reads, updates and deletes her own draft', async () => {
    const own = await verifiedCoach(COACH);
    await assertSucceeds(setDoc(doc(own, `coaches/${COACH}/drafts/d1`), good()));
    await assertSucceeds(getDoc(doc(own, `coaches/${COACH}/drafts/d1`)));
    await assertSucceeds(updateDoc(doc(own, `coaches/${COACH}/drafts/d1`), { name: 'Legs 2', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(own, `coaches/${COACH}/drafts/d1`)));
    for (const kind of ['meal', 'package']) {
      await assertSucceeds(setDoc(doc(own, `coaches/${COACH}/drafts/d_${kind}`), { ...good(), kind }));
    }
  });

  test('the shape is bounded', async () => {
    const own = await verifiedCoach(COACH);
    const at = (id) => doc(own, `coaches/${COACH}/drafts/${id}`);
    await assertFails(setDoc(at('b1'), { ...good(), kind: 'plan' }));
    await assertFails(setDoc(at('b2'), { ...good(), name: '' }));
    await assertFails(setDoc(at('b3'), { ...good(), name: 'x'.repeat(61) }));
    await assertSucceeds(setDoc(at('b3ok'), { ...good(), name: 'x'.repeat(60) }));
    await assertFails(setDoc(at('b4'), { ...good(), name: 5 }));
    await assertFails(setDoc(at('b5'), { ...good(), body: 'text' }));
    await assertFails(setDoc(at('b6'), { ...good(), body: Array.from({ length: 3 }, () => 1) }));
    const many = Object.fromEntries(Array.from({ length: 41 }, (_, i) => [`k${i}`, i]));
    await assertFails(setDoc(at('b7'), { ...good(), body: many }));
    const forty = Object.fromEntries(Array.from({ length: 40 }, (_, i) => [`k${i}`, i]));
    await assertSucceeds(setDoc(at('b7ok'), { ...good(), body: forty }));
    await assertFails(setDoc(at('b8'), { ...good(), extra: 1 }));
    await assertFails(setDoc(at('b9'), { ...good(), updatedAt: new Date(Date.now() - 60000) }));
    const { updatedAt, ...noStamp } = good();
    await assertFails(setDoc(at('b10'), noStamp));
  });

  test('an unverified coach token cannot touch drafts', async () => {
    const un = await unverifiedCoach(COACH);
    await assertFails(getDoc(doc(un, `coaches/${COACH}/drafts/d_seed`)));
    await assertFails(setDoc(doc(un, `coaches/${COACH}/drafts/d_u`), good()));
    await assertFails(deleteDoc(doc(un, `coaches/${COACH}/drafts/d_seed`)));
  });

  test('nobody else reads or writes them: a client, another coach, a non-coach, staff', async () => {
    const path = `coaches/${COACH}/drafts/d_seed`;
    await assertFails(getDoc(doc(await verified(HER), path)));
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), path)));
    await assertFails(setDoc(doc(await verifiedCoach(COACH2), `coaches/${COACH}/drafts/d_x`), good()));
    await assertFails(setDoc(doc(await verified(COACH), `coaches/${COACH}/drafts/d_y`), good()));
    await assertFails(getDoc(doc(await admin('a_admin_0009'), path)));
  });
});

describe('relationships: read by the two parties, written by the server', () => {
  test('both parties read it, a stranger does not', async () => {
    await assertSucceeds(getDoc(doc(await verified(HER), `relationships/${REL}`)));
    await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), `relationships/${REL}`)));
    await assertFails(getDoc(doc(await verified(OTHER), `relationships/${REL}`)));
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), `relationships/${REL}`)));
    await assertFails(getDoc(doc(await anon(), `relationships/${REL}`)));
  });

  test('no one creates, changes or deletes one', async () => {
    const her = await verified(HER);
    const coach = await verifiedCoach(COACH);
    await assertFails(setDoc(doc(her, `relationships/${COACH2}__${HER}x`), { coachUid: COACH2, clientUid: HER }));
    await assertFails(setDoc(doc(await verified(OTHER), `relationships/${COACH}__${OTHER}z`), { coachUid: COACH, clientUid: OTHER }));
    await assertFails(updateDoc(doc(her, `relationships/${REL}`), { chatOpen: false }));
    await assertFails(updateDoc(doc(coach, `relationships/${REL}`), { status: 'ended' }));
    await assertFails(deleteDoc(doc(coach, `relationships/${REL}`)));
    await assertFails(deleteDoc(doc(her, `relationships/${REL}`)));
  });
});

describe('chat messages', () => {
  const text = (sender, t = 'hello') => ({ senderUid: sender, type: 'text', text: t, createdAt: serverTimestamp() });
  const at = (db, rel, id) => doc(db, `relationships/${rel}/messages/${id}`);

  test('the client and the coach can each send text, and share a recipe', async () => {
    const her = await verified(HER);
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(setDoc(at(her, REL, 'm1'), text(HER)));
    await assertSucceeds(setDoc(at(coach, REL, 'm2'), text(COACH, 'good morning')));
    await assertSucceeds(setDoc(at(coach, REL, 'm3'), {
      senderUid: COACH, type: 'recipe', recipeId: 'koshari_light-2', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(at(coach, REL, 'm4'), {
      senderUid: COACH, type: 'recipe', recipeId: 'koshari_light-2', text: 'try this', createdAt: serverTimestamp(),
    }));
  });

  test('a stranger, a client of someone else and a signed-out caller cannot send or read', async () => {
    await assertFails(setDoc(at(await verified(OTHER), REL, 'x1'), text(OTHER)));
    await assertFails(setDoc(at(await verifiedCoach(COACH2), REL, 'x2'), text(COACH2)));
    await assertFails(setDoc(at(await anon(), REL, 'x3'), text(HER)));
    await assertFails(getDoc(at(await verified(OTHER), REL, 'm_seed')));
    await assertFails(getDocs(collection(await verified(OTHER), `relationships/${REL}/messages`)));
    await assertSucceeds(getDocs(collection(await verified(HER), `relationships/${REL}/messages`)));
    await assertSucceeds(getDoc(at(await verifiedCoach(COACH), REL, 'm_seed')));
  });

  test('a forged type or a server-only field is refused', async () => {
    const coach = await verifiedCoach(COACH);
    for (const type of ['workoutPlan', 'mealPlan', 'session', 'system']) {
      await assertFails(setDoc(at(coach, REL, `f_${type}`), { ...text(COACH), type }));
    }
    await assertFails(setDoc(at(coach, REL, 'f_plan'), { ...text(COACH), planId: 'p1' }));
    await assertFails(setDoc(at(coach, REL, 'f_hidden'), { ...text(COACH), hidden: true }));
    await assertFails(setDoc(at(coach, REL, 'f_pub'), { ...text(COACH), published: true }));
    await assertFails(setDoc(at(coach, REL, 'f_who'), text(HER)));
    await assertFails(setDoc(at(coach, REL, 'f_time'), { ...text(COACH), createdAt: new Date(Date.now() - 60000) }));
    const { createdAt, ...noTime } = text(COACH);
    await assertFails(setDoc(at(coach, REL, 'f_notime'), noTime));
  });

  test('text is 1 to 2000 characters, and a recipe needs a plain id', async () => {
    const her = await verified(HER);
    await assertFails(setDoc(at(her, REL, 't_empty'), text(HER, '')));
    await assertFails(setDoc(at(her, REL, 't_long'), text(HER, 'a'.repeat(2001))));
    await assertSucceeds(setDoc(at(her, REL, 't_max'), text(HER, 'a'.repeat(2000))));
    await assertFails(setDoc(at(her, REL, 't_num'), { ...text(HER), text: 12 }));
    await assertFails(setDoc(at(her, REL, 't_none'), { senderUid: HER, type: 'text', createdAt: serverTimestamp() }));
    await assertFails(setDoc(at(her, REL, 't_withrecipe'), { ...text(HER), recipeId: 'abc' }));
    const recipe = (recipeId) => ({ senderUid: HER, type: 'recipe', recipeId, createdAt: serverTimestamp() });
    await assertFails(setDoc(at(her, REL, 'r_none'), { senderUid: HER, type: 'recipe', createdAt: serverTimestamp() }));
    await assertFails(setDoc(at(her, REL, 'r_upper'), recipe('Koshari')));
    await assertFails(setDoc(at(her, REL, 'r_path'), recipe('a/b')));
    await assertFails(setDoc(at(her, REL, 'r_long'), recipe('a'.repeat(81))));
    await assertFails(setDoc(at(her, REL, 'r_empty'), recipe('')));
    await assertSucceeds(setDoc(at(her, REL, 'r_ok'), recipe('a'.repeat(80))));
    await assertFails(setDoc(at(her, REL, 'r_text'), { ...recipe('abc'), text: 'a'.repeat(2001) }));
  });

  test('a run of ten digits is refused, Western or Arabic-Indic, even after a line break', async () => {
    const her = await verified(HER);
    await assertFails(setDoc(at(her, REL, 'n1'), text(HER, 'call 01012345678 now')));
    await assertFails(setDoc(at(her, REL, 'n2'), text(HER, 'رقمي ٠١٠١٢٣٤٥٦٧٨')));
    await assertFails(setDoc(at(her, REL, 'n3'), text(HER, 'hi\nthere\n01012345678')));
    await assertFails(setDoc(at(her, REL, 'n4'), text(HER, '0101234٥٦٧٨٩')));
    await assertFails(setDoc(at(her, REL, 'n5'), {
      senderUid: HER, type: 'recipe', recipeId: 'abc', text: '01012345678', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(at(her, REL, 'n6'), text(HER, 'I did 123456789 steps')));
    await assertSucceeds(setDoc(at(her, REL, 'n7'), text(HER, '100 200 300 400')));
  });

  test('separated mobile numbers, emails and outside links are refused; workout numbers pass', async () => {
    const her = await verified(HER);
    const refused = [
      '010,1234,5678', '(010) 1234 5678', '010/1234/5678', '+20 10 1234 5678',
      '0020 10 1234 5678', '۰۱۰۱۲۳۴۵۶۷۸', 'mona@gmail.com', 'see wa.me/201012345678',
      'T.me/monafit', 'instagram.com/mona',
    ];
    for (const [i, t] of refused.entries()) {
      await assertFails(setDoc(at(her, REL, `s${i}`), text(HER, t)));
    }
    const fine = [
      '3 x 12', '4 sets of 10 reps', '60 kg', 'rest 90 sec', '2026-10-28', '1,200 kcal',
      '10:30', 'week 3 day 2', 'drink 2 litres', 'squat 3x8 @ 40kg', '24/10/2026 18:30',
    ];
    for (const [i, t] of fine.entries()) {
      await assertSucceeds(setDoc(at(her, REL, `f${i}`), text(HER, t)));
    }
  });

  test('the hidden-attempts counter is closed to both parties', async () => {
    const her = await verified(HER);
    const ref = doc(her, 'relationships', REL, 'private', 'contact');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, { [HER]: { count: 0 } }));
  });

  test('contact_sharing is an accepted report reason', async () => {
    const her = await verified(HER);
    await assertSucceeds(setDoc(doc(her, 'reports', 'cs1'), {
      reporterUid: HER, subjectUid: COACH, subjectKind: 'coachMessage',
      subjectRef: `relationships/${REL}/messages/m_seed`, reason: 'contact_sharing',
      state: 'submitted', createdAt: serverTimestamp(),
    }));
  });

  const media = (sender, type, extra = {}) => ({
    senderUid: sender, type, bytes: 1000,
    mediaPath: `chat-media/${REL}/${sender}/a1.jpg`,
    ...(type === 'image' ? {} : { durationMs: 5000 }),
    createdAt: serverTimestamp(), ...extra,
  });

  test('both parties can send image, video and voice lines', async () => {
    const her = await verified(HER);
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(setDoc(at(her, REL, 'med_i'), media(HER, 'image')));
    await assertSucceeds(setDoc(at(her, REL, 'med_v'), media(HER, 'video')));
    await assertSucceeds(setDoc(at(coach, REL, 'med_a'), media(COACH, 'audio')));
  });

  test('media needs its own folder, a size and a duration', async () => {
    const her = await verified(HER);
    await assertFails(setDoc(at(her, REL, 'med_other'), media(HER, 'image', { mediaPath: `chat-media/${REL}/${COACH}/a1.jpg` })));
    await assertFails(setDoc(at(her, REL, 'med_rel'), media(HER, 'image', { mediaPath: `chat-media/other__rel/${HER}/a1.jpg` })));
    const { bytes, ...noBytes } = media(HER, 'image');
    await assertFails(setDoc(at(her, REL, 'med_nobytes'), noBytes));
    await assertFails(setDoc(at(her, REL, 'med_big'), media(HER, 'image', { bytes: 26000000 })));
    const { durationMs, ...noDur } = media(HER, 'video');
    await assertFails(setDoc(at(her, REL, 'med_nodur'), noDur));
    await assertFails(setDoc(at(her, REL, 'med_short'), media(HER, 'video', { durationMs: 100 })));
    await assertFails(setDoc(at(her, REL, 'med_imgdur'), media(HER, 'image', { durationMs: 1000 })));
  });

  test('media cannot carry text, a recipe id or an unknown key', async () => {
    const her = await verified(HER);
    await assertFails(setDoc(at(her, REL, 'med_txt'), media(HER, 'image', { text: 'hi' })));
    await assertFails(setDoc(at(her, REL, 'med_rec'), media(HER, 'image', { recipeId: 'abc' })));
    await assertFails(setDoc(at(her, REL, 'med_hid'), media(HER, 'image', { hidden: true })));
    await assertFails(setDoc(at(her, REL, 'med_thb'), media(HER, 'image', { thumbPath: 'x' })));
  });

  test('text and recipe cannot carry a media path', async () => {
    const her = await verified(HER);
    await assertFails(setDoc(at(her, REL, 'txt_med'), { ...text(HER), mediaPath: 'x' }));
    await assertFails(setDoc(at(her, REL, 'rec_med'), {
      senderUid: HER, type: 'recipe', recipeId: 'abc', mediaPath: 'x', createdAt: serverTimestamp(),
    }));
  });

  test('media obeys the open, active and block rules', async () => {
    await assertFails(setDoc(at(await verified(HER), REL_ENDED, 'me1'), media(HER, 'image', { mediaPath: `chat-media/${REL_ENDED}/${HER}/a1.jpg` })));
    await assertFails(setDoc(at(await verified(OTHER), REL_CLOSED, 'mc1'), media(OTHER, 'image', { mediaPath: `chat-media/${REL_CLOSED}/${OTHER}/a1.jpg` })));
    await assertFails(setDoc(at(await verified(BLOCKED), REL_BLOCK, 'mb1'), media(BLOCKED, 'image', { mediaPath: `chat-media/${REL_BLOCK}/${BLOCKED}/a1.jpg` })));
  });

  test('messages cannot be edited or deleted by either party', async () => {
    await assertFails(updateDoc(at(await verifiedCoach(COACH), REL, 'm_seed'), { text: 'edited' }));
    await assertFails(deleteDoc(at(await verifiedCoach(COACH), REL, 'm_seed')));
    await assertFails(deleteDoc(at(await verified(HER), REL, 'm_seed')));
  });

  test('the thread must be active and open', async () => {
    // Coaching ended: the coach cannot write, and the client cannot either.
    await assertFails(setDoc(at(await verified(HER), REL_ENDED, 'e1'), text(HER)));
    await assertFails(setDoc(at(await verifiedCoach(COACH2), REL_ENDED, 'e2'), text(COACH2)));
    // Active but chat closed.
    await assertFails(setDoc(at(await verified(OTHER), REL_CLOSED, 'c1'), text(OTHER)));
    await assertFails(setDoc(at(await verifiedCoach(COACH), REL_CLOSED, 'c2'), text(COACH)));
    // Both can still read an ended thread.
    await assertSucceeds(getDoc(doc(await verified(HER), `relationships/${REL_ENDED}`)));
  });

  test('a coach on hold cannot send; her client can still send and read, and sees the away flag', async () => {
    const as = async (fn) => (await getEnv()).withSecurityRulesDisabled((c) => fn(c.firestore()));
    await as((d) => setDoc(doc(d, `coachPrivate/${COACH}`), { owedEgp: 1700, hold: { reason: 'fee', since: new Date() } }));
    await as((d) => updateDoc(doc(d, `relationships/${REL}`), { coachAway: true }));
    try {
      await assertFails(setDoc(at(await verifiedCoach(COACH), REL, 'h1'), text(COACH)));
      await assertSucceeds(setDoc(at(await verified(HER), REL, 'h2'), text(HER)));
      await assertSucceeds(getDocs(collection(await verifiedCoach(COACH), `relationships/${REL}/messages`)));
      const rel = await assertSucceeds(getDoc(doc(await verified(HER), `relationships/${REL}`)));
      assert.equal(rel.data().coachAway, true);
      await assertFails(updateDoc(doc(await verified(HER), `relationships/${REL}`), { coachAway: false }));
      await as((d) => setDoc(doc(d, `coachPrivate/${COACH}`), { owedEgp: 1700, hold: null }));
      await assertFails(getDoc(doc(await verified(HER), `coachPrivate/${COACH}`)));        // members cannot read why
      await assertSucceeds(setDoc(at(await verifiedCoach(COACH), REL, 'h3'), text(COACH)));
    } finally {
      await as((d) => setDoc(doc(d, `coachPrivate/${COACH}`), { owedEgp: 1700 }));
      await as((d) => updateDoc(doc(d, `relationships/${REL}`), { coachAway: false }));
    }
  });

  test('a blocked party cannot write; the one who blocked still can', async () => {
    await assertFails(setDoc(at(await verified(BLOCKED), REL_BLOCK, 'b1'), text(BLOCKED)));
    await assertSucceeds(setDoc(at(await verifiedCoach(BLOCKER), REL_BLOCK, 'b2'), text(BLOCKER)));
  });

  test('an unverified account cannot send even as a named party', async () => {
    await assertFails(setDoc(at(await unverified(HER), REL, 'u1'), text(HER)));
  });
});

describe('read markers', () => {
  const mark = (db, rel, who) => doc(db, `relationships/${rel}/reads/${who}`);

  test('each party writes only her own marker, with the server clock', async () => {
    const her = await verified(HER);
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(setDoc(mark(her, REL, HER), { at: serverTimestamp() }));
    await assertSucceeds(setDoc(mark(coach, REL, COACH), { at: serverTimestamp() }));
    await assertSucceeds(updateDoc(mark(her, REL, HER), { at: serverTimestamp() }));
    await assertFails(setDoc(mark(her, REL, COACH), { at: serverTimestamp() }));
    await assertFails(setDoc(mark(her, REL, HER), { at: new Date(Date.now() - 60000) }));
    await assertFails(setDoc(mark(her, REL, HER), { at: serverTimestamp(), extra: 1 }));
    await assertFails(deleteDoc(mark(her, REL, HER)));
  });

  test('the parties read them, a stranger neither reads nor writes', async () => {
    await assertSucceeds(getDoc(mark(await verified(HER), REL, COACH)));
    await assertSucceeds(getDoc(mark(await verifiedCoach(COACH), REL, HER)));
    const other = await verified(OTHER);
    await assertFails(getDoc(mark(other, REL, HER)));
    await assertFails(setDoc(mark(other, REL, OTHER), { at: serverTimestamp() }));
  });
});

describe('plans a coach shares', () => {
  test('the client reads all of hers', async () => {
    const her = await verified(HER);
    await assertSucceeds(getDoc(doc(her, `plans/${HER}/coachPlans/pl_a`)));
    await assertSucceeds(getDoc(doc(her, `plans/${HER}/coachPlans/pl_b`)));
    await assertSucceeds(getDocs(collection(her, `plans/${HER}/coachPlans`)));
  });

  test('the coach reads the plan she authored, and nothing else of the client', async () => {
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(coach, `plans/${HER}/coachPlans/pl_a`)));
    await assertFails(getDoc(doc(coach, `plans/${HER}/coachPlans/pl_b`)));
    await assertFails(getDoc(doc(coach, `plans/${HER}/published/current`)));
    await assertFails(getDoc(doc(coach, `plans/${HER}`)));
    await assertFails(getDocs(collection(coach, `plans/${HER}/published`)));
    await assertFails(getDocs(collection(coach, `plans/${HER}/coachPlans`)));
  });

  test('a coach whose relationship ended reads nothing of hers', async () => {
    const gone = await verifiedCoach(COACH2);
    await assertFails(getDoc(doc(gone, `plans/${HER}/coachPlans/pl_b`)));
    await assertFails(getDoc(doc(gone, `plans/${HER}/published/current`)));
  });

  test('the same coach loses her plan the moment the relationship ends', async () => {
    const coach = await verifiedCoach(COACH);
    await seed(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), `relationships/${REL}`), { status: 'ended' });
    });
    await assertFails(getDoc(doc(coach, `plans/${HER}/coachPlans/pl_a`)));
    await seed(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), `relationships/${REL}`), { status: 'active' });
    });
    await assertSucceeds(getDoc(doc(coach, `plans/${HER}/coachPlans/pl_a`)));
  });

  test('a stranger, another client and a non-coach read nothing, and nobody writes', async () => {
    await assertFails(getDoc(doc(await verified(OTHER), `plans/${HER}/coachPlans/pl_a`)));
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), `plans/${HER}/coachPlans/pl_a`)));
    await assertFails(getDoc(doc(await verified(COACH), `plans/${HER}/coachPlans/pl_a`)));
    await assertFails(getDoc(doc(await anon(), `plans/${HER}/coachPlans/pl_a`)));
    await assertFails(setDoc(doc(await verifiedCoach(COACH), `plans/${HER}/coachPlans/pl_new`), { coachUid: COACH }));
    await assertFails(setDoc(doc(await verified(HER), `plans/${HER}/coachPlans/pl_mine`), { coachUid: COACH }));
    await assertFails(updateDoc(doc(await verified(HER), `plans/${HER}/coachPlans/pl_a`), { name: 'x' }));
    await assertFails(deleteDoc(doc(await verified(HER), `plans/${HER}/coachPlans/pl_a`)));
  });
});

describe('subscriptions, sessions and the private terms', () => {
  test('the client and the coach read their subscription, no one else', async () => {
    await assertSucceeds(getDoc(doc(await verified(HER), 'subscriptions/s1')));
    await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), 'subscriptions/s1')));
    await assertFails(getDoc(doc(await verified(OTHER), 'subscriptions/s1')));
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), 'subscriptions/s1')));
    await assertFails(getDoc(doc(await admin('a_admin_0009'), 'subscriptions/s1')));
    await assertFails(getDoc(doc(await unverified(HER), 'subscriptions/s1')));
    await assertFails(getDoc(doc(await anon(), 'subscriptions/s1')));
  });

  test('a list must be constrained to the caller', async () => {
    const her = await verified(HER);
    await assertSucceeds(getDocs(query(collection(her, 'subscriptions'), where('clientUid', '==', HER))));
    await assertFails(getDocs(query(collection(her, 'subscriptions'), where('clientUid', '==', OTHER))));
    await assertFails(getDocs(collection(her, 'subscriptions')));
    const coach = await verifiedCoach(COACH);
    await assertSucceeds(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH), where('status', 'in', OPEN))));
    await assertFails(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH2), where('status', 'in', OPEN))));
  });

  test('the coach list without the open-status filter is refused', async () => {
    const coach = await verifiedCoach(COACH);
    await assertFails(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH))));
    await assertFails(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH), where('status', '==', 'ended'))));
    await assertFails(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH), where('status', 'in', ['active', 'ended']))));
    await assertSucceeds(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH), where('status', '==', 'active'))));
  });

  test('the coach reads a subscription and its sessions only while it is open (get and list)', async () => {
    const coach = await verifiedCoach(COACH);
    for (const st of OPEN) {
      await assertSucceeds(getDoc(doc(coach, `subscriptions/st_${st}`)));
      await assertSucceeds(getDoc(doc(coach, `subscriptions/st_${st}/sessions/x1`)));
      await assertSucceeds(getDocs(collection(coach, `subscriptions/st_${st}/sessions`)));
    }
    for (const st of CLOSED) {
      await assertFails(getDoc(doc(coach, `subscriptions/st_${st}`)));
      await assertFails(getDoc(doc(coach, `subscriptions/st_${st}/sessions/x1`)));
      await assertFails(getDocs(collection(coach, `subscriptions/st_${st}/sessions`)));
      await assertFails(getDocs(query(collection(coach, 'subscriptions'), where('coachUid', '==', COACH), where('status', '==', st))));
    }
  });

  test('the client reads hers in every status (get and list)', async () => {
    const her = await verified(HER);
    for (const st of ALL_STATUSES) {
      await assertSucceeds(getDoc(doc(her, `subscriptions/st_${st}`)));
      await assertSucceeds(getDoc(doc(her, `subscriptions/st_${st}/sessions/x1`)));
      await assertSucceeds(getDocs(query(collection(her, 'subscriptions'), where('clientUid', '==', HER), where('status', '==', st))));
    }
  });

  test("another client's subscription is not readable", async () => {
    await assertFails(getDoc(doc(await verified(HER), 'subscriptions/s2')));
    await assertFails(getDoc(doc(await verifiedCoach(COACH), 'subscriptions/s2')));
  });

  test('the private terms are closed to everyone, even the two parties', async () => {
    await assertFails(getDoc(doc(await verified(HER), 'subscriptions/s1/private/terms')));
    await assertFails(getDoc(doc(await verifiedCoach(COACH), 'subscriptions/s1/private/terms')));
    await assertFails(getDoc(doc(await admin('a_admin_0009'), 'subscriptions/s1/private/terms')));
    await assertFails(setDoc(doc(await verified(HER), 'subscriptions/s1/private/terms'), { coachPriceEgp: 1 }));
  });

  test('sessions are read by the two parties of the parent only', async () => {
    await assertSucceeds(getDoc(doc(await verified(HER), 'subscriptions/s1/sessions/x1')));
    await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), 'subscriptions/s1/sessions/x1')));
    await assertSucceeds(getDocs(collection(await verified(HER), 'subscriptions/s1/sessions')));
    await assertFails(getDoc(doc(await verified(OTHER), 'subscriptions/s1/sessions/x1')));
    await assertFails(getDoc(doc(await verifiedCoach(COACH2), 'subscriptions/s1/sessions/x1')));
  });

  test('nothing about a subscription is client-written', async () => {
    const her = await verified(HER);
    const coach = await verifiedCoach(COACH);
    await assertFails(setDoc(doc(her, 'subscriptions/s_new'), { clientUid: HER, coachUid: COACH, status: 'active' }));
    await assertFails(updateDoc(doc(her, 'subscriptions/s1'), { status: 'ended' }));
    await assertFails(updateDoc(doc(coach, 'subscriptions/s1'), { status: 'active', priceFinalEgp: 1 }));
    await assertFails(deleteDoc(doc(her, 'subscriptions/s1')));
    await assertFails(setDoc(doc(coach, 'subscriptions/s1/sessions/x2'), { status: 'confirmed' }));
    await assertFails(updateDoc(doc(coach, 'subscriptions/s1/sessions/x1'), { status: 'done' }));
  });
});

describe('applications, the coach ledger and the payout account', () => {
  test('a coach reads her own application and private records, nobody else does', async () => {
    const own = await verifiedCoach(COACH);
    await assertSucceeds(getDoc(doc(own, `coachApplications/${COACH}`)));
    await assertSucceeds(getDoc(doc(own, `coachPrivate/${COACH}`)));
    await assertSucceeds(getDoc(doc(own, `coachPrivate/${COACH}/ledger/s1`)));
    await assertSucceeds(getDoc(doc(own, `coachPrivate/${COACH}/prices/p_on`)));
    await assertSucceeds(getDocs(collection(own, `coachPrivate/${COACH}/ledger`)));
    for (const who of [await verified(HER), await verifiedCoach(COACH2), await admin('a_admin_0009'), await anon()]) {
      await assertFails(getDoc(doc(who, `coachApplications/${COACH}`)));
      await assertFails(getDoc(doc(who, `coachPrivate/${COACH}`)));
      await assertFails(getDoc(doc(who, `coachPrivate/${COACH}/ledger/s1`)));
      await assertFails(getDoc(doc(who, `coachPrivate/${COACH}/prices/p_on`)));
    }
  });

  test('an applicant who is not yet a coach still reads her own application', async () => {
    await seed(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `coachApplications/${HER}`), { status: 'submitted' });
    });
    await assertSucceeds(getDoc(doc(await verified(HER), `coachApplications/${HER}`)));
    await assertFails(getDoc(doc(await verified(OTHER), `coachApplications/${HER}`)));
  });

  test('nothing in them is client-written', async () => {
    const own = await verifiedCoach(COACH);
    await assertFails(setDoc(doc(own, `coachApplications/${COACH}`), { status: 'approved' }));
    await assertFails(updateDoc(doc(own, `coachApplications/${COACH}`), { status: 'approved' }));
    await assertFails(setDoc(doc(own, `coachPrivate/${COACH}`), { owedEgp: 999999 }));
    await assertFails(updateDoc(doc(own, `coachPrivate/${COACH}`), { agreement: { version: 2, status: 'verified' } }));
    await assertFails(setDoc(doc(own, `users/${COACH}/consents/coach-terms-v2`), { version: 2, textHash: 'x' }));
    await assertFails(updateDoc(doc(own, `coachPrivate/${COACH}/ledger/s1`), { status: 'paid' }));
    await assertFails(setDoc(doc(own, `coachPrivate/${COACH}/payouts/po1`), { amountEgp: 1 }));
    await assertFails(setDoc(doc(own, `coachPrivate/${COACH}/prices/p_new`), { coachPriceEgp: 1 }));
    await assertFails(deleteDoc(doc(own, `coachPrivate/${COACH}/ledger/s1`)));
    await assertFails(setDoc(doc(await verified(HER), `coachApplications/${HER}`), { status: 'approved' }));
  });
});

describe('coaching configuration, receipts and payment records', () => {
  test('a verified member reads the receiving accounts and the seller, and nothing else in config', async () => {
    const her = await verified(HER);
    await assertSucceeds(getDoc(doc(her, 'coachingConfig/receivingAccounts')));
    await assertSucceeds(getDoc(doc(her, 'coachingConfig/seller')));
    await assertFails(getDoc(doc(her, 'coachingConfig/receiptCounter')));
    await assertFails(getDocs(collection(her, 'coachingConfig')));
    await assertFails(getDoc(doc(await unverified(HER), 'coachingConfig/receivingAccounts')));
    await assertFails(getDoc(doc(await anon(), 'coachingConfig/seller')));
  });

  test('no client writes config, the admin included, and meta cannot hold it', async () => {
    const ad = await admin('a_admin_0009');
    for (const db of [await verified(HER), await verifiedCoach(COACH), ad]) {
      await assertFails(setDoc(doc(db, 'coachingConfig/receivingAccounts'), { instapay: { address: 'mine' } }));
      await assertFails(updateDoc(doc(db, 'coachingConfig/seller'), { taxCard: 'x' }));
      await assertFails(setDoc(doc(db, 'coachingConfig/receiptCounter'), { seq: 0 }));
    }
  });

  test('a receipt is read by its client alone and only by id', async () => {
    await assertSucceeds(getDoc(doc(await verified(HER), 'receipts/s1')));
    await assertFails(getDoc(doc(await verified(OTHER), 'receipts/s1')));
    await assertFails(getDoc(doc(await verifiedCoach(COACH), 'receipts/s1')));
    await assertFails(getDoc(doc(await admin('a_admin_0009'), 'receipts/s1')));
    await assertFails(getDocs(collection(await verified(HER), 'receipts')));
    await assertFails(setDoc(doc(await verified(HER), 'receipts/s_forged'), { clientUid: HER }));
    await assertFails(updateDoc(doc(await verified(HER), 'receipts/s1'), { priceFinalEgp: 1 }));
    await assertFails(deleteDoc(doc(await verified(HER), 'receipts/s1')));
  });

  test('payment proofs and references are closed to every client', async () => {
    for (const db of [await verified(HER), await verifiedCoach(COACH), await admin('a_admin_0009')]) {
      await assertFails(getDoc(doc(db, 'paymentProofs/pp1')));
      await assertFails(getDocs(collection(db, 'paymentProofs')));
      await assertFails(setDoc(doc(db, 'paymentProofs/pp2'), { subId: 's1' }));
      await assertFails(getDoc(doc(db, 'paymentRefs/instapay_123')));
      await assertFails(setDoc(doc(db, 'paymentRefs/instapay_999'), { subId: 's1' }));
    }
  });
});

describe('reports about coaching', () => {
  const report = (extra) => ({
    reporterUid: HER, subjectUid: COACH, subjectKind: 'coachMessage',
    subjectRef: `relationships/${REL}/messages/m_seed`, reason: 'off_platform_payment',
    state: 'submitted', createdAt: serverTimestamp(), ...extra,
  });

  test('the new reasons and the three coaching subjects are accepted', async () => {
    const her = await verified(HER);
    let n = 0;
    for (const [subjectKind, subjectRef] of [
      ['coachMessage', `relationships/${REL}/messages/m_seed`],
      ['coachProfile', `coaches/${COACH}`],
      ['coachPlan', `plans/${HER}/coachPlans/pl_a`],
    ]) {
      for (const reason of ['off_platform_payment', 'unsafe_advice']) {
        await assertSucceeds(setDoc(doc(her, `reports/r_coach_${n++}`), report({ subjectKind, subjectRef, reason })));
      }
    }
  });

  test('an unknown reason, a forged clock and a self-report are still refused', async () => {
    const her = await verified(HER);
    await assertFails(setDoc(doc(her, 'reports/r_bad_reason'), report({ reason: 'scam' })));
    await assertFails(setDoc(doc(her, 'reports/r_bad_clock'), report({ createdAt: new Date(Date.now() - 60000) })));
    await assertFails(setDoc(doc(her, 'reports/r_self'), report({ subjectUid: HER })));
    await assertFails(getDoc(doc(her, 'reports/r_coach_0')));
  });
});
