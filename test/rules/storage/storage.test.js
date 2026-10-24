// C5: Cloud Storage rules (firebase/storage.rules), against a Storage
// emulator started from test/rules/storage/firebase.json (port 9399, never
// 8088 or 9098):
//
//   cd test/rules && npm run test:storage
//
// which runs `firebase emulators:exec --only storage` on that config. Kept out
// of `npm test` (./*.test.js) so the Firestore suite runs without it.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} from 'firebase/storage';

const here = dirname(fileURLToPath(import.meta.url));
const RULES = readFileSync(resolve(here, '../../../firebase/storage.rules'), 'utf8');

// APL-16: user-media is switched off as it ships (`communityLive()` returns
// false) and so is the money side of coaching (`coachPaymentsLive()` returns
// false); `coachPortfolioLive()` returns true. The tests above the last
// section are about the rules behind those switches, so they load the file
// with community and payments turned on, which is what it will be when the
// features ship. The last section reloads it exactly as it ships.
const SWITCHES = [
  ['function communityLive() {\n      return false;\n    }',
   'function communityLive() {\n      return true;\n    }'],
  ['function coachPaymentsLive() {\n      return false;\n    }',
   'function coachPaymentsLive() {\n      return true;\n    }'],
];
function switchedOn(source) {
  let out = source;
  for (const [off, on] of SWITCHES) {
    if (!out.includes(off)) throw new Error(`storage rules switch not found: ${off}`);
    out = out.replace(off, on);
  }
  return out;
}
const PORT = Number(process.env.OWNHUB_RULES_STORAGE_PORT || 9399);
const BUCKET = 'demo-own-hub.appspot.com';

const HER = 'uid-her';
const OTHER = 'uid-other';
const MB = 1024 * 1024;

let env;

async function load(rules) {
  if (env) await env.cleanup();
  env = await initializeTestEnvironment({
    projectId: 'demo-own-hub',
    storage: { rules, host: '127.0.0.1', port: PORT },
  });
}

before(async () => {
  await load(switchedOn(RULES));
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearStorage();
});

function store(ctx) {
  return ctx.storage(`gs://${BUCKET}`);
}
const her = (claims = { verified: true }) => store(env.authenticatedContext(HER, claims));
const other = (claims = { verified: true }) => store(env.authenticatedContext(OTHER, claims));
const admin = () => store(env.authenticatedContext('uid-admin', { admin: true, verified: true }));
const anon = () => store(env.unauthenticatedContext());

const bytes = (n) => new Uint8Array(n);
const put = (s, path, n, contentType) =>
  uploadBytes(ref(s, path), bytes(n), contentType ? { contentType } : undefined);

async function seed(path, contentType = 'image/jpeg', customMetadata = undefined) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(store(ctx), path), bytes(16), { contentType, customMetadata });
  });
}

// ------------------------------------------------------------ user-media

test('she can upload an image and audio to her own media', async () => {
  await assertSucceeds(put(her(), `user-media/${HER}/posts/p1.jpg`, 1024, 'image/jpeg'));
  await assertSucceeds(put(her(), `user-media/${HER}/voice/v1.m4a`, 1024, 'audio/mp4'));
});

test('her media has size caps: images 10 MB, audio 5 MB', async () => {
  await assertSucceeds(put(her(), `user-media/${HER}/a.jpg`, 10 * MB - 1, 'image/jpeg'));
  await assertFails(put(her(), `user-media/${HER}/b.jpg`, 10 * MB, 'image/jpeg'));
  await assertSucceeds(put(her(), `user-media/${HER}/a.m4a`, 5 * MB - 1, 'audio/mp4'));
  await assertFails(put(her(), `user-media/${HER}/b.m4a`, 5 * MB, 'audio/mp4'));
});

test('her media takes images and audio only', async () => {
  await assertFails(put(her(), `user-media/${HER}/x.mp4`, 1024, 'video/mp4'));
  await assertFails(put(her(), `user-media/${HER}/x.pdf`, 1024, 'application/pdf'));
  await assertFails(put(her(), `user-media/${HER}/x.bin`, 1024, 'application/octet-stream'));
});

test('nobody else can write to her media, and an unverified account cannot either', async () => {
  await assertFails(put(other(), `user-media/${HER}/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(anon(), `user-media/${HER}/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her({}), `user-media/${HER}/x.jpg`, 1024, 'image/jpeg'));
});

test('only she can read her media', async () => {
  await seed(`user-media/${HER}/p.jpg`);
  await assertSucceeds(getBytes(ref(her(), `user-media/${HER}/p.jpg`)));
  await assertFails(getBytes(ref(other(), `user-media/${HER}/p.jpg`)));
  await assertFails(getBytes(ref(admin(), `user-media/${HER}/p.jpg`)));
  await assertFails(getBytes(ref(anon(), `user-media/${HER}/p.jpg`)));
});

test('she can delete her own media even without the verified claim', async () => {
  await seed(`user-media/${HER}/p.jpg`);
  await assertFails(deleteObject(ref(other(), `user-media/${HER}/p.jpg`)));
  await assertSucceeds(deleteObject(ref(her({}), `user-media/${HER}/p.jpg`)));
});

// ------------------------------------------------------------ coach-docs

const FOLDERS = ['photo', 'education', 'certificates', 'testimonials', 'transformations'];
const reviewer = () => store(env.authenticatedContext('uid-reviewer', { womanReviewer: true, verified: true }));
const finance = () => store(env.authenticatedContext('uid-finance', { finance: true }));

test('a coach uploads images to all five folders, and PDFs to education and certificates only', async () => {
  for (const f of FOLDERS) {
    await assertSucceeds(put(her(), `coach-docs/${HER}/${f}/a.jpg`, 1024, 'image/jpeg'));
    await assertSucceeds(put(her(), `coach-docs/${HER}/${f}/b.png`, 1024, 'image/png'));
    await assertSucceeds(put(her(), `coach-docs/${HER}/${f}/c.webp`, 1024, 'image/webp'));
  }
  for (const f of ['education', 'certificates']) {
    await assertSucceeds(put(her(), `coach-docs/${HER}/${f}/d.pdf`, 1024, 'application/pdf'));
  }
  for (const f of ['photo', 'testimonials', 'transformations']) {
    await assertFails(put(her(), `coach-docs/${HER}/${f}/d.pdf`, 1024, 'application/pdf'));
  }
});

test('coach files: 10 MB is allowed, one byte more is not, and only listed types and folders', async () => {
  await assertSucceeds(put(her(), `coach-docs/${HER}/certificates/big.jpg`, 10 * MB, 'image/jpeg'));
  await assertFails(put(her(), `coach-docs/${HER}/certificates/toobig.jpg`, 10 * MB + 1, 'image/jpeg'));
  await assertFails(put(her(), `coach-docs/${HER}/certificates/x.gif`, 1024, 'image/gif'));
  await assertFails(put(her(), `coach-docs/${HER}/certificates/x.mp4`, 1024, 'video/mp4'));
  await assertFails(put(her(), `coach-docs/${HER}/certificates/x.m4a`, 1024, 'audio/mp4'));
  await assertFails(put(her(), `coach-docs/${HER}/certificates/x.bin`, 1024, 'application/octet-stream'));
  await assertFails(put(her(), `coach-docs/${HER}/other/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her(), `coach-docs/${HER}/c1`, 1024, 'application/pdf'));
  await assertFails(put(her(), `coach-docs/${HER}/certificates/deep/x.jpg`, 1024, 'image/jpeg'));
});

test('only the owner writes, and she must be verified', async () => {
  await assertFails(put(other(), `coach-docs/${HER}/certificates/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(anon(), `coach-docs/${HER}/certificates/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her({}), `coach-docs/${HER}/certificates/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(admin(), `coach-docs/${HER}/certificates/x.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(reviewer(), `coach-docs/${HER}/certificates/x.jpg`, 1024, 'image/jpeg'));
});

test('photo, education and certificates are read by the owner, an admin and a woman reviewer', async () => {
  for (const f of ['photo', 'education', 'certificates']) {
    await seed(`coach-docs/${HER}/${f}/a.jpg`);
    await assertSucceeds(getBytes(ref(her(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertSucceeds(getBytes(ref(admin(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertSucceeds(getBytes(ref(reviewer(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(other(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(finance(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(anon(), `coach-docs/${HER}/${f}/a.jpg`)));
  }
});

test('testimonials and transformations are read by the owner and a woman reviewer, never the admin', async () => {
  for (const f of ['testimonials', 'transformations']) {
    await seed(`coach-docs/${HER}/${f}/a.jpg`);
    await assertSucceeds(getBytes(ref(her(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertSucceeds(getBytes(ref(reviewer(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(admin(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(finance(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(other(), `coach-docs/${HER}/${f}/a.jpg`)));
    await assertFails(getBytes(ref(anon(), `coach-docs/${HER}/${f}/a.jpg`)));
  }
});

test('an admin who is also a woman reviewer still reads them as a reviewer', async () => {
  await seed(`coach-docs/${HER}/transformations/a.jpg`);
  const both = store(env.authenticatedContext('uid-both', { admin: true, womanReviewer: true }));
  await assertSucceeds(getBytes(ref(both, `coach-docs/${HER}/transformations/a.jpg`)));
});

test('only the owner deletes a coach file', async () => {
  await seed(`coach-docs/${HER}/certificates/a.jpg`);
  await assertFails(deleteObject(ref(other(), `coach-docs/${HER}/certificates/a.jpg`)));
  await assertFails(deleteObject(ref(admin(), `coach-docs/${HER}/certificates/a.jpg`)));
  await assertFails(deleteObject(ref(reviewer(), `coach-docs/${HER}/certificates/a.jpg`)));
  await assertSucceeds(deleteObject(ref(her({}), `coach-docs/${HER}/certificates/a.jpg`)));
});

test('a coach file the service locked (attached to a portfolio item) cannot be deleted or replaced, a draft can', async () => {
  const locked = `coach-docs/${HER}/transformations/release.jpg`;
  const draft = `coach-docs/${HER}/transformations/draft.jpg`;
  await seed(locked, 'image/jpeg', { locked: 'true' });
  await seed(draft);
  await assertFails(deleteObject(ref(her(), locked)));
  await assertFails(put(her(), locked, 1024, 'image/jpeg'));
  await assertSucceeds(getBytes(ref(her(), locked)));
  await assertSucceeds(put(her(), draft, 1024, 'image/jpeg'));
  await assertSucceeds(deleteObject(ref(her(), draft)));
  await assertSucceeds(put(her(), `coach-docs/${HER}/transformations/new.jpg`, 1024, 'image/jpeg'));
});

// ----------------------------------------------------------- coach-public

test('the public coach photo is read by verified members and written by nobody', async () => {
  await seed(`coach-public/${HER}/photo.jpg`);
  await assertSucceeds(getBytes(ref(other(), `coach-public/${HER}/photo.jpg`)));
  await assertSucceeds(getBytes(ref(her(), `coach-public/${HER}/photo.jpg`)));
  await assertFails(getBytes(ref(other({}), `coach-public/${HER}/photo.jpg`)));
  await assertFails(getBytes(ref(anon(), `coach-public/${HER}/photo.jpg`)));
  await assertFails(put(her(), `coach-public/${HER}/new.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(admin(), `coach-public/${HER}/new.jpg`, 1024, 'image/jpeg'));
  await assertFails(deleteObject(ref(her(), `coach-public/${HER}/photo.jpg`)));
});

// --------------------------------------------------------- payment-proofs

test('payment proofs are read by an admin or finance and written by nobody', async () => {
  await seed(`payment-proofs/${HER}/p1.jpg`);
  await assertSucceeds(getBytes(ref(admin(), `payment-proofs/${HER}/p1.jpg`)));
  await assertSucceeds(getBytes(ref(finance(), `payment-proofs/${HER}/p1.jpg`)));
  await assertFails(getBytes(ref(her(), `payment-proofs/${HER}/p1.jpg`)));
  await assertFails(getBytes(ref(other(), `payment-proofs/${HER}/p1.jpg`)));
  await assertFails(getBytes(ref(reviewer(), `payment-proofs/${HER}/p1.jpg`)));
  await assertFails(getBytes(ref(anon(), `payment-proofs/${HER}/p1.jpg`)));
  await assertFails(put(her(), `payment-proofs/${HER}/p2.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(admin(), `payment-proofs/${HER}/p2.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(finance(), `payment-proofs/${HER}/p2.jpg`, 1024, 'image/jpeg'));
  await assertFails(deleteObject(ref(her(), `payment-proofs/${HER}/p1.jpg`)));
  await assertFails(deleteObject(ref(admin(), `payment-proofs/${HER}/p1.jpg`)));
});

// ---------------------------------------------------------- user-exports

test('her export is read by her only and written by nobody', async () => {
  await seed(`user-exports/${HER}/export.zip`, 'application/zip');
  await assertSucceeds(getBytes(ref(her(), `user-exports/${HER}/export.zip`)));
  await assertFails(getBytes(ref(other(), `user-exports/${HER}/export.zip`)));
  await assertFails(getBytes(ref(admin(), `user-exports/${HER}/export.zip`)));
  await assertFails(put(her(), `user-exports/${HER}/forged.zip`, 16, 'application/zip'));
});

// --------------------------------------------------------------- default

test('everything else is denied', async () => {
  await seed('somewhere/else.jpg');
  await assertFails(getBytes(ref(her(), 'somewhere/else.jpg')));
  await assertFails(put(her(), 'somewhere/new.jpg', 16, 'image/jpeg'));
  await assertFails(put(her(), `users/${HER}/photos/body.jpg`, 16, 'image/jpeg'));
  await assertFails(put(admin(), `user-media/${HER}/x.jpg`, 16, 'image/jpeg'));
});

test('the content library is unchanged: read when signed in, written by admin', async () => {
  await seed('content/recipes/r1/a.jpg');
  await assertSucceeds(getBytes(ref(her({}), 'content/recipes/r1/a.jpg')));
  await assertFails(getBytes(ref(anon(), 'content/recipes/r1/a.jpg')));
  await assertSucceeds(put(admin(), 'content/recipes/r1/b.jpg', 16, 'image/jpeg'));
  await assertFails(put(her(), 'content/recipes/r1/c.jpg', 16, 'image/jpeg'));
});

test('exercise demonstrations are public; any other content path needs a sign-in', async () => {
  await seed('content/exercises/squat/clip.mp4', 'video/mp4');
  await seed('content/recipes/r1/a.jpg');
  await assertSucceeds(getBytes(ref(anon(), 'content/exercises/squat/clip.mp4')));
  await assertFails(getBytes(ref(anon(), 'content/recipes/r1/a.jpg')));
  await assertFails(put(anon(), 'content/exercises/squat/new.mp4', 16, 'video/mp4'));
});

// ---------------------------------------------------------------- events

test('event pictures and clips: the admin writes them, within the limits', async () => {
  await assertSucceeds(put(admin(), 'content/events/e1/a.webp', MB, 'image/webp'));
  await assertSucceeds(put(admin(), 'content/events/e1/b.jpg', 1024, 'image/jpeg'));
  await assertSucceeds(put(admin(), 'content/events/e1/c.mp4', 10 * MB, 'video/mp4'));
  await assertFails(put(admin(), 'content/events/e1/big.webp', MB + 1, 'image/webp'));
  await assertFails(put(admin(), 'content/events/e1/big.mp4', 10 * MB + 1, 'video/mp4'));
  await assertFails(put(admin(), 'content/events/e1/x.png', 1024, 'image/png'));
  await assertFails(put(admin(), 'content/events/e1/x.webm', 1024, 'video/webm'));
  await assertFails(put(admin(), 'content/events/e1/x.pdf', 1024, 'application/pdf'));
});

test('event media: a member cannot write or delete it', async () => {
  await seed('content/events/e1/a.webp', 'image/webp');
  await assertFails(put(her(), 'content/events/e1/new.webp', 1024, 'image/webp'));
  await assertFails(put(anon(), 'content/events/e1/new.webp', 1024, 'image/webp'));
  await assertFails(deleteObject(ref(her(), 'content/events/e1/a.webp')));
  await assertSucceeds(deleteObject(ref(admin(), 'content/events/e1/a.webp')));
});

test('event media is read by verified members and the admin, not by the rest', async () => {
  await seed('content/events/e1/a.webp', 'image/webp');
  await assertSucceeds(getBytes(ref(her(), 'content/events/e1/a.webp')));
  await assertSucceeds(getBytes(ref(admin(), 'content/events/e1/a.webp')));
  await assertFails(getBytes(ref(her({}), 'content/events/e1/a.webp')));
  await assertFails(getBytes(ref(anon(), 'content/events/e1/a.webp')));
});

// ------------------------------------------------- as the rules ship (APL-16)

test('as shipped: user-media is closed and coach-docs takes her application files', async () => {
  await load(RULES);
  await env.clearStorage();
  await assertFails(put(her(), `user-media/${HER}/posts/p1.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her(), `user-media/${HER}/voice/v1.m4a`, 1024, 'audio/mp4'));
  for (const f of FOLDERS) {
    await assertSucceeds(put(her(), `coach-docs/${HER}/${f}/c1.jpg`, 1024, 'image/jpeg'));
  }
  await assertSucceeds(put(her(), `coach-docs/${HER}/certificates/c2.pdf`, 1024, 'application/pdf'));
  await assertFails(put(her({}), `coach-docs/${HER}/certificates/c3.pdf`, 1024, 'application/pdf'));
});

test('as shipped: what is already there can still be read and deleted by her', async () => {
  await seed(`user-media/${HER}/p.jpg`);
  await seed(`coach-docs/${HER}/certificates/c1.pdf`, 'application/pdf');
  await assertSucceeds(getBytes(ref(her(), `user-media/${HER}/p.jpg`)));
  await assertSucceeds(deleteObject(ref(her({}), `user-media/${HER}/p.jpg`)));
  await assertSucceeds(deleteObject(ref(her(), `coach-docs/${HER}/certificates/c1.pdf`)));
});

test('as shipped: the portfolio is open, user-media and payment proofs are closed', async () => {
  await load(RULES);
  await env.clearStorage();
  await assertFails(put(her(), `user-media/${HER}/posts/p1.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her(), `user-media/${HER}/voice/v1.m4a`, 1024, 'audio/mp4'));
  await assertSucceeds(put(her(), `coach-docs/${HER}/certificates/c1.pdf`, 1024, 'application/pdf'));
  await seed(`coach-public/${HER}/photo.jpg`);
  await assertSucceeds(getBytes(ref(other(), `coach-public/${HER}/photo.jpg`)));
  await seed(`payment-proofs/${HER}/p.jpg`);
  await assertFails(getBytes(ref(admin(), `payment-proofs/${HER}/p.jpg`)));
});

test('portfolio switch off: coach-docs and coach-public close', async () => {
  await load(RULES.replace(
    'function coachPortfolioLive() {\n      return true;\n    }',
    'function coachPortfolioLive() {\n      return false;\n    }',
  ));
  await env.clearStorage();
  await seed(`coach-public/${HER}/photo.jpg`);
  await seed(`coach-docs/${HER}/photo/p.jpg`);
  await assertFails(put(her(), `coach-docs/${HER}/certificates/c1.pdf`, 1024, 'application/pdf'));
  await assertFails(getBytes(ref(her(), `coach-docs/${HER}/photo/p.jpg`)));
  await assertFails(getBytes(ref(other(), `coach-public/${HER}/photo.jpg`)));
});

test('payments switch on: finance and the admin read payment proofs', async () => {
  await load(RULES.replace(
    'function coachPaymentsLive() {\n      return false;\n    }',
    'function coachPaymentsLive() {\n      return true;\n    }',
  ));
  await env.clearStorage();
  await seed(`payment-proofs/${HER}/p.jpg`);
  await assertSucceeds(getBytes(ref(admin(), `payment-proofs/${HER}/p.jpg`)));
  await assertFails(getBytes(ref(her(), `payment-proofs/${HER}/p.jpg`)));
});

test('community switch on, others as shipped: coach-docs stays open', async () => {
  await load(RULES.replace(
    'function communityLive() {\n      return false;\n    }',
    'function communityLive() {\n      return true;\n    }',
  ));
  await env.clearStorage();
  await assertSucceeds(put(her(), `user-media/${HER}/posts/p1.jpg`, 1024, 'image/jpeg'));
  await assertSucceeds(put(her(), `coach-docs/${HER}/certificates/c1.pdf`, 1024, 'application/pdf'));
});

test('as shipped: the switches read community false, payments false, portfolio true', () => {
  for (const [name, value] of [['communityLive', 'false'], ['coachPaymentsLive', 'false'], ['coachPortfolioLive', 'true']]) {
    if (!new RegExp(`function ${name}\\(\\) \\{\\s*return ${value};\\s*\\}`).test(RULES)) {
      throw new Error(`${name}() must return ${value} in the shipped storage.rules`);
    }
  }
});

test('gallery: she uploads images only, a reviewer reads, the admin does not', async () => {
  const reviewer = () => store(env.authenticatedContext('uid-rev', { womanReviewer: true, verified: true }));
  await assertSucceeds(put(her(), `coach-docs/${HER}/gallery/g1.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her(), `coach-docs/${HER}/gallery/g2.pdf`, 1024, 'application/pdf'));
  await assertFails(put(her(), `coach-docs/${HER}/gallery/g3.jpg`, 10 * MB + 1, 'image/jpeg'));
  await assertFails(put(other(), `coach-docs/${HER}/gallery/g4.jpg`, 1024, 'image/jpeg'));
  await seed(`coach-docs/${HER}/gallery/g1.jpg`);
  await assertSucceeds(getBytes(ref(her(), `coach-docs/${HER}/gallery/g1.jpg`)));
  await assertSucceeds(getBytes(ref(reviewer(), `coach-docs/${HER}/gallery/g1.jpg`)));
  await assertFails(getBytes(ref(admin(), `coach-docs/${HER}/gallery/g1.jpg`)));
  await assertFails(getBytes(ref(other(), `coach-docs/${HER}/gallery/g1.jpg`)));
});

test('coach-public media: verified members read, nobody writes', async () => {
  await seed(`coach-public/${HER}/media/m1_image.jpg`);
  await assertSucceeds(getBytes(ref(other(), `coach-public/${HER}/media/m1_image.jpg`)));
  await assertFails(getBytes(ref(other({}), `coach-public/${HER}/media/m1_image.jpg`)));
  await assertFails(getBytes(ref(anon(), `coach-public/${HER}/media/m1_image.jpg`)));
  await assertFails(put(her(), `coach-public/${HER}/media/new.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(admin(), `coach-public/${HER}/media/new.jpg`, 1024, 'image/jpeg'));
});

test('admin content uploads take jpeg, png, webp, gif and video, never SVG', async () => {
  await assertSucceeds(put(admin(), 'content/recipes/r1/ok.png', 16, 'image/png'));
  await assertSucceeds(put(admin(), 'content/recipes/r1/ok.webp', 16, 'image/webp'));
  await assertSucceeds(put(admin(), 'content/exercises/e1/clip.mp4', 16, 'video/mp4'));
  await assertFails(put(admin(), 'content/recipes/r1/bad.svg', 16, 'image/svg+xml'));
  await assertFails(put(admin(), 'content/exercises/e1/bad.svg', 16, 'image/svg+xml'));
});
