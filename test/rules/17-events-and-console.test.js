// Events (Feature.events), the member-facing switch document, and the
// console's own records.
//
//  1. A verified woman reads a PUBLISHED event and nothing else. A draft is the
//     owner's working copy and a cancelled event is gone from her list. Her
//     query must say `status == 'published'` or it is refused as a whole.
//  2. Only the admin claim writes an event, and only in the shape the app
//     reads: titles in both languages, a start before the end, an https link
//     for an online event or a place name for one in person, and no field the
//     rules do not name (there is no attendee list to smuggle in).
//  3. `meta/features` is read by a verified woman and written by an admin.
//  4. adminAccessLog and opsErrors are server-only, admin included: an audit
//     trail an admin could edit is not an audit trail.

import { test, before, after, describe } from 'node:test';
import {
  getEnv, clearAll, seed, anon, unverified, verified, admin,
  uid, assertSucceeds, assertFails,
} from './harness.js';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
  Timestamp,
} from 'firebase/firestore';

const START = Timestamp.fromDate(new Date('2030-03-01T16:00:00Z'));
const END = Timestamp.fromDate(new Date('2030-03-01T18:00:00Z'));

const ONLINE = {
  titleEn: 'Morning stretch, together',
  titleAr: 'تمدد الصباح معًا',
  descriptionEn: 'Thirty quiet minutes.',
  descriptionAr: 'ثلاثون دقيقة هادئة.',
  startsAt: START,
  endsAt: END,
  timeZone: 'Africa/Cairo',
  mode: 'online',
  link: 'https://meet.example.com/stretch',
  placeName: null,
  audience: 'all',
  capacity: null,
  coverFile: null,
  status: 'published',
};

const IN_PERSON = {
  ...ONLINE,
  mode: 'place',
  link: null,
  placeName: 'Zamalek ladies gym',
  capacity: 20,
};

before(async () => {
  await getEnv();
  await clearAll();
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'events/published'), ONLINE);
    await setDoc(doc(d, 'events/draft'), { ...ONLINE, status: 'draft' });
    await setDoc(doc(d, 'events/cancelled'), { ...ONLINE, status: 'cancelled' });
    await setDoc(doc(d, 'meta/features'), { events: false });
    await setDoc(doc(d, 'adminAccessLog/a1'), { admin: 'abcd1234', action: 'dashboard' });
    await setDoc(doc(d, 'opsErrors/2030-03-01'), { day: '2030-03-01', counts: {} });
  });
});

after(async () => {
  const env = await getEnv();
  await env.cleanup();
});

describe('a member reads published events only', () => {
  test('a verified woman reads a published event', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'events/published')));
  });

  test('she never reads a draft or a cancelled event', async () => {
    const d = await verified(uid.her);
    await assertFails(getDoc(doc(d, 'events/draft')));
    await assertFails(getDoc(doc(d, 'events/cancelled')));
  });

  test('her list query must ask for published events', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(
      getDocs(query(collection(d, 'events'), where('status', '==', 'published'))),
    );
    await assertFails(getDocs(collection(d, 'events')));
  });

  test('an unverified or signed-out account reads nothing', async () => {
    const u = await unverified(uid.her);
    await assertFails(getDoc(doc(u, 'events/published')));
    const a = await anon();
    await assertFails(getDoc(doc(a, 'events/published')));
  });

  test('a member writes nothing', async () => {
    const d = await verified(uid.her);
    await assertFails(setDoc(doc(d, 'events/mine'), ONLINE));
    await assertFails(updateDoc(doc(d, 'events/published'), { titleEn: 'Mine now' }));
    await assertFails(deleteDoc(doc(d, 'events/published')));
  });
});

describe('the admin writes events in the shape the app reads', () => {
  test('an online and an in-person event', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(setDoc(doc(d, 'events/new_online'), { ...ONLINE, status: 'draft' }));
    await assertSucceeds(setDoc(doc(d, 'events/new_place'), IN_PERSON));
  });

  test('she reads drafts and cancels by status', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(getDoc(doc(d, 'events/draft')));
    await assertSucceeds(getDocs(collection(d, 'events')));
    await assertSucceeds(updateDoc(doc(d, 'events/new_place'), { status: 'cancelled' }));
  });

  const bad = [
    ['no Arabic title', { titleAr: '' }],
    ['an end before the start', { startsAt: END, endsAt: START }],
    ['an http link', { link: 'http://meet.example.com/x' }],
    ['an unknown status', { status: 'live' }],
    ['an audience other than all members', { audience: 'verifiedCoaches' }],
    ['a zero capacity', { capacity: 0 }],
    ['an attendee list', { attendees: [uid.her] }],
    ['another time zone', { timeZone: 'Europe/London' }],
  ];
  for (const [label, change] of bad) {
    test(`refused: ${label}`, async () => {
      const d = await admin(uid.admin);
      await assertFails(setDoc(doc(d, 'events/bad'), { ...ONLINE, ...change }));
    });
  }

  test('refused: an in-person event with no place', async () => {
    const d = await admin(uid.admin);
    await assertFails(setDoc(doc(d, 'events/bad'), { ...IN_PERSON, placeName: '' }));
  });
});

describe('the member switch document', () => {
  test('a verified woman reads it and cannot write it', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'meta/features')));
    await assertFails(setDoc(doc(d, 'meta/features'), { events: true }));
  });

  test('an admin switches it', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(setDoc(doc(d, 'meta/features'), { events: true }, { merge: true }));
  });
});

describe('the console records are server-only, admin included', () => {
  for (const path of ['adminAccessLog/a1', 'opsErrors/2030-03-01']) {
    test(path, async () => {
      const d = await admin(uid.admin);
      await assertFails(getDoc(doc(d, path)));
      await assertFails(setDoc(doc(d, path), { tampered: true }));
      await assertFails(deleteDoc(doc(d, path)));
    });
  }
});

describe('the workout library and the media register', () => {
  before(async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, 'workoutLibrary/v1'), { version: 1, programmes: [] });
      await setDoc(doc(d, 'meta/workouts'), { version: 1 });
      await setDoc(doc(d, 'mediaLibrary/recipes__om_ali__om_ali.webp'), {
        path: 'content/recipes/om_ali/om_ali.webp', kind: 'picture',
      });
    });
  });

  test('a verified woman reads the workout library, and writes nothing', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'workoutLibrary/v1')));
    await assertSucceeds(getDoc(doc(d, 'meta/workouts')));
    await assertFails(setDoc(doc(d, 'workoutLibrary/v2'), { version: 2 }));
    await assertFails(setDoc(doc(d, 'meta/workouts'), { version: 9 }));
  });

  test('an unverified account reads none of it', async () => {
    const d = await unverified(uid.her);
    await assertFails(getDoc(doc(d, 'workoutLibrary/v1')));
  });

  test('the admin publishes a new library version', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(setDoc(doc(d, 'workoutLibrary/v2'), { version: 2, programmes: [] }));
    await assertSucceeds(setDoc(doc(d, 'meta/workouts'), { version: 2 }));
  });

  test('the media register: the admin reads it, nobody writes it', async () => {
    const a = await admin(uid.admin);
    await assertSucceeds(getDoc(doc(a, 'mediaLibrary/recipes__om_ali__om_ali.webp')));
    await assertFails(setDoc(doc(a, 'mediaLibrary/fake'), { path: 'content/x' }));
    const v = await verified(uid.her);
    await assertFails(getDoc(doc(v, 'mediaLibrary/recipes__om_ali__om_ali.webp')));
  });
});
