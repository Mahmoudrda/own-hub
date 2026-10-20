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

// APL-16: user-media and coach-docs are switched off as they ship
// (`communityLive()` and `coachLive()` return false). The tests above the last
// section are about the rules behind those switches, so they load the file with
// both turned on, which is what it will be when the features ship. The last
// section reloads it exactly as it ships and proves nothing can be written.
const SWITCHES = [
  ['function communityLive() {\n      return false;\n    }',
   'function communityLive() {\n      return true;\n    }'],
  ['function coachLive() {\n      return false;\n    }',
   'function coachLive() {\n      return true;\n    }'],
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

async function seed(path, contentType = 'image/jpeg') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(store(ctx), path), bytes(16), { contentType });
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

test('a coach can upload a PDF or an image certificate up to 10 MB', async () => {
  await assertSucceeds(put(her(), `coach-docs/${HER}/c1`, 1024, 'application/pdf'));
  await assertSucceeds(put(her(), `coach-docs/${HER}/c2`, 1024, 'image/png'));
  await assertFails(put(her(), `coach-docs/${HER}/c3`, 10 * MB, 'application/pdf'));
  await assertFails(put(her(), `coach-docs/${HER}/c4`, 1024, 'audio/mp4'));
  await assertFails(put(other(), `coach-docs/${HER}/c5`, 1024, 'application/pdf'));
});

test('certificates are read by their owner and an admin only', async () => {
  await seed(`coach-docs/${HER}/c1`, 'application/pdf');
  await assertSucceeds(getBytes(ref(her(), `coach-docs/${HER}/c1`)));
  await assertSucceeds(getBytes(ref(admin(), `coach-docs/${HER}/c1`)));
  await assertFails(getBytes(ref(other(), `coach-docs/${HER}/c1`)));
  await assertFails(getBytes(ref(anon(), `coach-docs/${HER}/c1`)));
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

// ------------------------------------------------- as the rules ship (APL-16)

test('as shipped: nothing can be written to her media or to coach-docs', async () => {
  await load(RULES);
  await env.clearStorage();
  await assertFails(put(her(), `user-media/${HER}/posts/p1.jpg`, 1024, 'image/jpeg'));
  await assertFails(put(her(), `user-media/${HER}/voice/v1.m4a`, 1024, 'audio/mp4'));
  await assertFails(put(her(), `coach-docs/${HER}/c1`, 1024, 'application/pdf'));
  await assertFails(put(her(), `coach-docs/${HER}/c2.jpg`, 1024, 'image/jpeg'));
});

test('as shipped: what is already there can still be read and deleted by her', async () => {
  await seed(`user-media/${HER}/p.jpg`);
  await seed(`coach-docs/${HER}/c1`, 'application/pdf');
  await assertSucceeds(getBytes(ref(her(), `user-media/${HER}/p.jpg`)));
  await assertSucceeds(deleteObject(ref(her({}), `user-media/${HER}/p.jpg`)));
  await assertSucceeds(deleteObject(ref(her(), `coach-docs/${HER}/c1`)));
});

test('as shipped: the switches read false', () => {
  for (const name of ['communityLive', 'coachLive']) {
    if (!new RegExp(`function ${name}\\(\\) \\{\\s*return false;\\s*\\}`).test(RULES)) {
      throw new Error(`${name}() must return false in the shipped storage.rules`);
    }
  }
});
