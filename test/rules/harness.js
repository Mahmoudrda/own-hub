// Shared harness for the Own Hub Firestore rules suite.
//
// Talks to the ALREADY-RUNNING emulator described in firebase.emulator.json:
// Firestore on 127.0.0.1:8088, Auth on 127.0.0.1:9098, project id `own-hub`.
// The default firebase.json still says 8080; that is deliberate and untouched.
//
// The rules file is loaded verbatim from firebase/firestore.rules. Nothing in
// this directory may modify it.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { setLogLevel } from 'firebase/firestore';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

// The SDK logs every PERMISSION_DENIED at error level. A suite whose job is to
// provoke denials would be unreadable; the assertions record the outcome.
setLogLevel('silent');

const here = dirname(fileURLToPath(import.meta.url));
export const RULES_PATH = resolve(here, '../../firebase/firestore.rules');

export const PROJECT_ID = 'own-hub';
export const FIRESTORE_HOST = '127.0.0.1';
// OWNHUB_RULES_FIRESTORE_PORT lets the suite run against a second emulator
// (firebase.qa-emulator.json, 8288) without touching the one on 8088.
export const FIRESTORE_PORT = Number(process.env.OWNHUB_RULES_FIRESTORE_PORT || 8088);

let env = null;

export async function getEnv() {
  if (env) return env;
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: FIRESTORE_HOST,
      port: FIRESTORE_PORT,
    },
  });
  return env;
}

export async function clearAll() {
  const e = await getEnv();
  await e.clearFirestore();
}

// ---------------------------------------------------------------- contexts
//
// Claims are minted locally by rules-unit-testing and land in
// request.auth.token, which is exactly how the rules read `verified`,
// `coachV` and `admin`.

export const uid = {
  her: 'w_her_0001',
  other: 'w_other_0002',
  blocker: 'w_blocker_0003',
  blocked: 'w_blocked_0004',
  attacker: 'w_attacker_0005',
  victim: 'w_victim_0006',
  coach: 'c_coach_0007',
  coach2: 'c_coach_0008',
  admin: 'a_admin_0009',
  fresh: 'w_fresh_0010',
};

// N1: every account in this product signs in with her phone number, so the
// default token says so. The rules refuse owned-data writes from any other
// provider (email/password, Google, Apple are enabled in the console).
const PHONE = { firebase: { sign_in_provider: 'phone', identities: {} } };

function ctx(e, who, claims) {
  return e.authenticatedContext(who, { ...PHONE, ...claims }).firestore();
}

export async function anon() {
  const e = await getEnv();
  return e.unauthenticatedContext().firestore();
}

/** Signed in, no `verified` claim. The state every woman is in during sign-up. */
export async function unverified(who) {
  const e = await getEnv();
  return ctx(e, who, {});
}

export async function verified(who, extra = {}) {
  const e = await getEnv();
  return ctx(e, who, { verified: true, ...extra });
}

export async function verifiedCoach(who) {
  const e = await getEnv();
  return ctx(e, who, { verified: true, coachV: 'active' });
}

/** A coach account whose own verification has not landed yet. */
export async function unverifiedCoach(who) {
  const e = await getEnv();
  return ctx(e, who, { coachV: 'active' });
}

export async function admin(who) {
  const e = await getEnv();
  return ctx(e, who, { verified: true, admin: true });
}

/**
 * N1: the same claims, signed in with another provider ('password',
 * 'google.com', 'apple.com', ...). No SMS step stood behind this account.
 */
export async function otherProvider(who, provider, claims = {}) {
  const e = await getEnv();
  return ctx(e, who, {
    firebase: { sign_in_provider: provider, identities: {} },
    ...claims,
  });
}

/** Seeds documents with rules bypassed, the way a Cloud Function would. */
export async function seed(fn) {
  const e = await getEnv();
  await e.withSecurityRulesDisabled(fn);
}

// ------------------------------------------------------------- assertions
//
// assertSucceeds / assertFails re-exported so every test states its
// expectation in the same two words.

export { assertSucceeds, assertFails, assert };

/**
 * Runs an operation and reports ALLOWED / DENIED instead of asserting, for the
 * cases where the point of the test is to find out what actually happens.
 */
export async function observe(label, op) {
  try {
    await op;
    return { label, outcome: 'ALLOWED', error: null };
  } catch (e) {
    return { label, outcome: 'DENIED', error: e.code || e.message };
  }
}

/** Synthetic Egyptian national id numbers. Never a real one. */
export const SYNTHETIC_NID = {
  female: '29901012345678',
  male: '29001019876543',
  hash: 'synthetic_hmac_0000000000000000000000000000000000000000000000000000',
};
