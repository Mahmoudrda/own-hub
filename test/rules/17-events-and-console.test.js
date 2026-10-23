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
//     Pictures, clips, an address and a maps link are named fields with limits;
//     `seatsTaken` can be set to 0 on create and is never changed by a client,
//     the admin included.
//  2b. events/{id}/attendees/{uid} is read by that woman and the admin only,
//     and written by nobody: the register callables are the only writer.
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

  test('an event is cancelled by status, never deleted, even by the admin', async () => {
    const d = await admin(uid.admin);
    await assertFails(deleteDoc(doc(d, 'events/published')));
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

describe('pictures, clips, location and seats', () => {
  const PLACE_FULL = {
    ...IN_PERSON,
    locationAddress: '12 Road 9, Maadi, Cairo',
    locationUrl: 'https://maps.app.goo.gl/abc123',
    imageFiles: ['hall_a1b2c3d4.webp', 'room_a1b2c3d4.jpg'],
    videoFiles: ['tour_a1b2c3d4.mp4'],
    seatsTaken: 0,
  };

  test('an event with pictures, a clip, an address and a maps link', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(setDoc(doc(d, 'events/rich'), PLACE_FULL));
    for (const url of [
      'https://maps.google.com/?q=maadi',
      'https://www.google.com/maps/place/x',
      'https://goo.gl/maps/abc',
    ]) {
      await assertSucceeds(setDoc(doc(d, 'events/rich'), { ...PLACE_FULL, locationUrl: url }));
    }
    await assertSucceeds(setDoc(doc(d, 'events/rich'), {
      ...PLACE_FULL,
      imageFiles: ['a.webp', 'b.webp', 'c.webp', 'd.webp', 'e.webp', 'f.webp'],
      videoFiles: ['a.mp4', 'b.mp4'],
    }));
  });

  const bad = [
    ['seven pictures', { imageFiles: ['a.webp', 'b.webp', 'c.webp', 'd.webp', 'e.webp', 'f.webp', 'g.webp'] }],
    ['three clips', { videoFiles: ['a.mp4', 'b.mp4', 'c.mp4'] }],
    ['a picture that is not an image file', { imageFiles: ['a.mp4'] }],
    ['a path in a file name', { imageFiles: ['../a.webp'] }],
    ['a clip that is not mp4', { videoFiles: ['a.webm'] }],
    ['a file name that is not text', { imageFiles: [7] }],
    ['picture names that are not a list', { imageFiles: 'a.webp' }],
    ['an http maps link', { locationUrl: 'http://maps.google.com/x' }],
    ['a maps link on another host', { locationUrl: 'https://evil.example.com/maps' }],
    ['a maps link that only starts like Google', { locationUrl: 'https://maps.google.com.evil.example/x' }],
    ['a maps link with a login in front', { locationUrl: 'https://goo.gl@evil.example/x' }],
    ['a google.com page that is not maps', { locationUrl: 'https://www.google.com/search?q=x' }],
    ['a goo.gl link that is not under /maps/', { locationUrl: 'https://goo.gl/abc' }],
    ['a goo.gl path that only starts like maps', { locationUrl: 'https://goo.gl/mapsevil' }],
    ['a maps link with a trailing newline', { locationUrl: 'https://maps.google.com/x\n' }],
    ['an address over 300 characters', { locationAddress: 'x'.repeat(301) }],
    ['a negative seatsTaken', { seatsTaken: -1 }],
    ['seats taken on a new event', { seatsTaken: 1 }],
  ];
  for (const [label, change] of bad) {
    test(`refused: ${label}`, async () => {
      const d = await admin(uid.admin);
      await assertFails(setDoc(doc(d, 'events/bad'), { ...PLACE_FULL, ...change }));
    });
  }
});

describe('seatsTaken belongs to the server', () => {
  before(async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, 'events/booked'), { ...IN_PERSON, capacity: 10, seatsTaken: 4 });
      await setDoc(doc(d, 'events/unbooked'), { ...IN_PERSON, capacity: 10 });
    });
  });

  test('the admin edits an event and the count stays', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(updateDoc(doc(d, 'events/booked'), { titleEn: 'Moved to Thursday' }));
    await assertSucceeds(updateDoc(doc(d, 'events/booked'), { seatsTaken: 4 }));
    await assertSucceeds(updateDoc(doc(d, 'events/booked'), { capacity: 4 }));
  });

  test('the admin cannot change the count, up or down', async () => {
    const d = await admin(uid.admin);
    await assertFails(updateDoc(doc(d, 'events/booked'), { seatsTaken: 5 }));
    await assertFails(updateDoc(doc(d, 'events/booked'), { seatsTaken: 0 }));
    await assertFails(updateDoc(doc(d, 'events/unbooked'), { seatsTaken: 1 }));
  });

  test('the admin cannot shrink the room below the seats taken, or remove it', async () => {
    const d = await admin(uid.admin);
    await assertFails(updateDoc(doc(d, 'events/booked'), { capacity: 3 }));
    await assertFails(updateDoc(doc(d, 'events/booked'), { capacity: null }));
  });

  test('a replacing write cannot reset the count either', async () => {
    const d = await admin(uid.admin);
    await assertFails(setDoc(doc(d, 'events/booked'), { ...IN_PERSON, capacity: 10, seatsTaken: 0 }));
  });

  test('a member cannot take or give back a seat by writing the event', async () => {
    const d = await verified(uid.her);
    await assertFails(updateDoc(doc(d, 'events/booked'), { seatsTaken: 5 }));
    await assertFails(updateDoc(doc(d, 'events/booked'), { seatsTaken: 3 }));
  });
});

describe('attendees', () => {
  before(async () => {
    await seed(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `events/published/attendees/${uid.her}`), {
        uid: uid.her, joinedAt: START, status: 'registered',
      });
    });
  });

  test('she reads her own record', async () => {
    const d = await verified(uid.her);
    await assertSucceeds(getDoc(doc(d, `events/published/attendees/${uid.her}`)));
  });

  test('she reads no one else, and cannot list the attendees', async () => {
    const d = await verified(uid.other);
    await assertFails(getDoc(doc(d, `events/published/attendees/${uid.her}`)));
    await assertFails(getDocs(collection(d, 'events/published/attendees')));
    const h = await verified(uid.her);
    await assertFails(getDocs(collection(h, 'events/published/attendees')));
  });

  test('a signed-out account reads nothing', async () => {
    const a = await anon();
    await assertFails(getDoc(doc(a, `events/published/attendees/${uid.her}`)));
  });

  test('the admin reads them', async () => {
    const d = await admin(uid.admin);
    await assertSucceeds(getDoc(doc(d, `events/published/attendees/${uid.her}`)));
    await assertSucceeds(getDocs(collection(d, 'events/published/attendees')));
  });

  test('nobody writes one: not her, not another woman, not the admin', async () => {
    const path = `events/published/attendees/${uid.her}`;
    const h = await verified(uid.her);
    await assertFails(setDoc(doc(h, 'events/published/attendees/' + uid.her + 'x'), { uid: uid.her }));
    await assertFails(setDoc(doc(h, path), { uid: uid.her, joinedAt: START, status: 'registered' }));
    await assertFails(deleteDoc(doc(h, path)));
    const o = await verified(uid.other);
    await assertFails(setDoc(doc(o, `events/published/attendees/${uid.other}`), {
      uid: uid.other, joinedAt: START, status: 'registered',
    }));
    const a = await admin(uid.admin);
    await assertFails(setDoc(doc(a, `events/published/attendees/${uid.other}`), { uid: uid.other }));
    await assertFails(deleteDoc(doc(a, path)));
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

  test('the workout library is public: an unverified or signed-out account reads it', async () => {
    const d = await unverified(uid.her);
    await assertSucceeds(getDoc(doc(d, 'workoutLibrary/v1')));
    await assertFails(setDoc(doc(d, 'workoutLibrary/v2'), { version: 2 }));
    const a = await anon();
    await assertSucceeds(getDoc(doc(a, 'workoutLibrary/v1')));
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
