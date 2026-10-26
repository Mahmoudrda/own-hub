# WO-10a: InstaPay payments: Firestore rules, storage rules note, indexes, rules tests
Depends on: none
Size: M
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` sections 2, 4.15, 13.9; `firebase/firestore.rules` lines 26-60 (helpers `signedIn`, `isSelf`, `isVerified`) and 1405-1440 (the `paymentProofs` and `paymentRefs` blocks, about); `firebase/storage.rules` lines 262-270 (`payment-proofs/{uid}/{file}`, about); `test/rules/21-closed-paths.test.js` lines 1-30; `test/rules/storage/storage.test.js` lines 236-252

## Why
Every payment change is made by a server function. The phones may only READ their own payments. This order puts the data model's security in place first: nobody writes `payments` from a phone, a coach never reads another coach's payments, staff-private risk data is closed to both parties, and screenshots in storage cannot be read or written by the two parties directly (they get them through a logged callable, WO-10b3). No Dart or Python code changes here.

## Final result
No screen. In the rules:
- `payments/{paymentId}`: the client or the coach named on the document reads it (get and list) when verified. No client write.
- `payments/{paymentId}/events/{eventId}`: the same two parties read; no write.
- `payments/{paymentId}/staff/{docId}`: closed to everyone (staff use callables).
- Closed to every client, read and write: `paymentTxnNumbers`, `paymentImageHashes`, `paymentAmountLocks`, `paymentIdempotency`, `paymentStrikes`, `paymentAlerts`.
- `coachPaymentProfiles/{uid}`, `paymentStanding/{uid}`: that woman reads her own document (get only). No write.
- `feeStatements/{id}`: the coach named in `coachUid` gets it. No write.
- `config/payments`: any signed-in account may `get` it (the app needs it to show "Free for now"). No list, no write.
- Storage: no rule text changes behaviour. `payment-proofs/{x}/{file}` already denies every client write and denies read to everyone while `coachPaymentsLive()` is false. A comment records that InstaPay screenshots use this prefix with `{x}` = payment id and are read only by the server.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `firebase/firestore.rules` | edit | new `match` blocks after the `paymentRefs` block |
| `firebase/storage.rules` | edit | comment only above `payment-proofs` |
| `firebase/firestore.indexes.json` | edit | 6 composite indexes |
| `test/rules/22-instapay-payments.test.js` | create | Firestore rules tests |
| `test/rules/storage/storage.test.js` | edit | 3 tests for payment-id paths |

## Steps
1. File `firebase/firestore.rules`. Anchor: the line `match /paymentRefs/{refId}     { allow read, write: if false; }` (about line 1438). Insert directly after it:
```
    // ---------------------------------------------------- InstaPay payments
    // docs/plan/INSTAPAY-PAYMENTS-SPEC.md. Own Hub never moves the money; the
    // server (functions/payments) is the only writer of everything here. The
    // two parties read the payment and its event timeline. Risk scores, image
    // hashes and staff notes live under /staff and are closed to everyone.
    // Reads do not depend on the kill switch (config/payments), so an open
    // payment stays readable when the switch is turned off.
    function paymentParty(data) {
      return signedIn()
        && (data.clientUid == request.auth.uid || data.coachUid == request.auth.uid);
    }

    match /payments/{paymentId} {
      allow get, list: if isVerified() && paymentParty(resource.data);
      allow create, update, delete: if false;

      match /events/{eventId} {
        allow read: if isVerified()
                    && paymentParty(get(/databases/$(database)/documents/payments/$(paymentId)).data);
        allow write: if false;
      }

      match /staff/{docId} {
        allow read, write: if false;
      }
    }

    match /paymentTxnNumbers/{id}    { allow read, write: if false; }
    match /paymentImageHashes/{id}   { allow read, write: if false; }
    match /paymentAmountLocks/{id}   { allow read, write: if false; }
    match /paymentIdempotency/{id}   { allow read, write: if false; }
    match /paymentStrikes/{id}       { allow read, write: if false; }
    match /paymentAlerts/{id}        { allow read, write: if false; }

    match /coachPaymentProfiles/{uid} {
      allow get: if isVerified() && isSelf(uid);
      allow list, write: if false;
    }

    match /paymentStanding/{uid} {
      allow get: if isVerified() && isSelf(uid);
      allow list, write: if false;
    }

    match /feeStatements/{statementId} {
      allow get: if isVerified() && resource.data.coachUid == request.auth.uid;
      allow list, write: if false;
    }

    // The kill switch. Only {enabled: bool, updatedAt} lives here, so reading
    // it leaks nothing. The owner flips it with the set_payments_enabled callable.
    match /config/payments {
      allow get: if signedIn();
      allow list, write: if false;
    }
```
2. File `firebase/storage.rules`. Anchor: the comment `// A member's screenshot of her transfer. The service writes it and deletes` (about line 262). Insert above it:
```
    // InstaPay payments (functions/payments) keep their screenshots under this
    // same prefix, payment-proofs/{paymentId}/{file}. Neither party reads or
    // writes them from a phone; the server returns them to a party or to a
    // woman reviewer through a callable that logs the access.
```
Change nothing else in the file.
3. File `firebase/firestore.indexes.json`. Anchor: the `"indexes": [` array; append these objects before its closing `]` (keep valid JSON, add a comma after the previous last object):
```json
    {"_why":"InstaPay: client lists her payments, and the 3-per-day rate limit.","collectionGroup":"payments","queryScope":"COLLECTION","fields":[{"fieldPath":"clientUid","order":"ASCENDING"},{"fieldPath":"createdAt","order":"DESCENDING"}]},
    {"_why":"InstaPay: coach inbox, newest first.","collectionGroup":"payments","queryScope":"COLLECTION","fields":[{"fieldPath":"coachUid","order":"ASCENDING"},{"fieldPath":"createdAt","order":"DESCENDING"}]},
    {"_why":"InstaPay: expire_payments, awaiting_payment where expiresAt <= now.","collectionGroup":"payments","queryScope":"COLLECTION","fields":[{"fieldPath":"status","order":"ASCENDING"},{"fieldPath":"expiresAt","order":"ASCENDING"}]},
    {"_why":"InstaPay: escalate_silent_payments, status where statusAt <= cutoff (proof_submitted, refund_requested, awaiting_payment with coachReport).","collectionGroup":"payments","queryScope":"COLLECTION","fields":[{"fieldPath":"status","order":"ASCENDING"},{"fieldPath":"statusAt","order":"ASCENDING"}]},
    {"_why":"InstaPay: fee statement of one coach for one month.","collectionGroup":"payments","queryScope":"COLLECTION","fields":[{"fieldPath":"coachUid","order":"ASCENDING"},{"fieldPath":"feeOwedAt","order":"ASCENDING"}]},
    {"_why":"InstaPay: strikes of one woman in one role inside 90 days.","collectionGroup":"paymentStrikes","queryScope":"COLLECTION","fields":[{"fieldPath":"uid","order":"ASCENDING"},{"fieldPath":"role","order":"ASCENDING"},{"fieldPath":"at","order":"DESCENDING"}]}
```
4. File `test/rules/22-instapay-payments.test.js`, create. Header and helpers are copied from `test/rules/21-closed-paths.test.js` (same imports). Full file:
```js
// InstaPay payments rules (docs/plan/INSTAPAY-PAYMENTS-SPEC.md section 2, 7.3).
import { test, before, after } from 'node:test';
import {
  getEnv, clearAll, seed, verified, verifiedCoach, admin, uid,
  assertSucceeds, assertFails,
} from './harness.js';
import { doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc, deleteDoc } from 'firebase/firestore';

before(async () => { await getEnv(); await clearAll(); });
after(async () => { const e = await getEnv(); await e.cleanup(); });

const HER = uid.her;
const COACH = uid.coach;
const OTHER_COACH = uid.coach2;
const OTHER = uid.other;

async function seedPayment() {
  await seed(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'payments/p1'), { clientUid: HER, coachUid: COACH, status: 'awaiting_payment', amountPiasters: 50037 });
    await setDoc(doc(d, 'payments/p1/events/e1'), { to: 'awaiting_payment', role: 'client' });
    await setDoc(doc(d, 'payments/p1/staff/review'), { riskScore: 40, screenshotHashes: ['aa'] });
    await setDoc(doc(d, 'paymentTxnNumbers/t1'), { paymentId: 'p1' });
    await setDoc(doc(d, 'paymentImageHashes/h1'), { paymentId: 'p1' });
    await setDoc(doc(d, 'paymentAmountLocks/l1'), { paymentId: 'p1' });
    await setDoc(doc(d, 'paymentIdempotency/i1'), { paymentId: 'p1' });
    await setDoc(doc(d, 'paymentStrikes/s1'), { uid: COACH, role: 'coach' });
    await setDoc(doc(d, 'paymentAlerts/a1'), { type: 'addressChange' });
    await setDoc(doc(d, `coachPaymentProfiles/${COACH}`), { address: 'rahma@instapay' });
    await setDoc(doc(d, `paymentStanding/${HER}`), { clientStrikes: 1 });
    await setDoc(doc(d, 'feeStatements/s__2026-10'), { coachUid: COACH, totalFeePiasters: 1000 });
    await setDoc(doc(d, 'config/payments'), { enabled: true });
  });
}

test('the client and the coach of a payment read it; anyone else cannot', async () => {
  await clearAll(); await seedPayment();
  await assertSucceeds(getDoc(doc(await verified(HER), 'payments/p1')));
  await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), 'payments/p1')));
  await assertFails(getDoc(doc(await verifiedCoach(OTHER_COACH), 'payments/p1')));
  await assertFails(getDoc(doc(await verified(OTHER), 'payments/p1')));
  await assertFails(getDoc(doc(await admin(uid.admin), 'payments/p1')));
});

test('a list must be constrained to the caller, and nobody lists everything', async () => {
  await clearAll(); await seedPayment();
  const her = await verified(HER);
  await assertSucceeds(getDocs(query(collection(her, 'payments'), where('clientUid', '==', HER))));
  await assertFails(getDocs(collection(her, 'payments')));
  await assertFails(getDocs(query(collection(her, 'payments'), where('clientUid', '==', OTHER))));
  const coach = await verifiedCoach(COACH);
  await assertSucceeds(getDocs(query(collection(coach, 'payments'), where('coachUid', '==', COACH))));
  await assertFails(getDocs(query(collection(coach, 'payments'), where('coachUid', '==', OTHER_COACH))));
});

test('an unverified account reads nothing', async () => {
  await clearAll(); await seedPayment();
  const { unverified } = await import('./harness.js');
  await assertFails(getDoc(doc(await unverified(HER), 'payments/p1')));
});

test('no client or coach can create, change or delete a payment or its events', async () => {
  await clearAll(); await seedPayment();
  for (const db of [await verified(HER), await verifiedCoach(COACH), await admin(uid.admin)]) {
    await assertFails(setDoc(doc(db, 'payments/p2'), { clientUid: HER, coachUid: COACH, status: 'confirmed' }));
    await assertFails(updateDoc(doc(db, 'payments/p1'), { status: 'confirmed' }));
    await assertFails(deleteDoc(doc(db, 'payments/p1')));
    await assertFails(setDoc(doc(db, 'payments/p1/events/e2'), { to: 'confirmed' }));
    await assertFails(updateDoc(doc(db, 'payments/p1/events/e1'), { to: 'confirmed' }));
  }
});

test('the two parties read the event timeline; a stranger cannot', async () => {
  await clearAll(); await seedPayment();
  await assertSucceeds(getDoc(doc(await verified(HER), 'payments/p1/events/e1')));
  await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), 'payments/p1/events/e1')));
  await assertFails(getDoc(doc(await verifiedCoach(OTHER_COACH), 'payments/p1/events/e1')));
});

test('risk scores, hashes and staff notes are closed to both parties and to admin', async () => {
  await clearAll(); await seedPayment();
  for (const db of [await verified(HER), await verifiedCoach(COACH), await admin(uid.admin)]) {
    await assertFails(getDoc(doc(db, 'payments/p1/staff/review')));
    await assertFails(setDoc(doc(db, 'payments/p1/staff/review'), { riskScore: 0 }));
  }
});

test('the registries, locks, strikes and alerts are closed to every client', async () => {
  await clearAll(); await seedPayment();
  const paths = ['paymentTxnNumbers/t1', 'paymentImageHashes/h1', 'paymentAmountLocks/l1',
    'paymentIdempotency/i1', 'paymentStrikes/s1', 'paymentAlerts/a1'];
  for (const db of [await verified(HER), await verifiedCoach(COACH), await admin(uid.admin)]) {
    for (const p of paths) {
      await assertFails(getDoc(doc(db, p)));
      await assertFails(setDoc(doc(db, p), { x: 1 }));
    }
  }
});

test('a woman reads her own profile and standing, never another woman\'s, and cannot write them', async () => {
  await clearAll(); await seedPayment();
  const coach = await verifiedCoach(COACH);
  await assertSucceeds(getDoc(doc(coach, `coachPaymentProfiles/${COACH}`)));
  await assertFails(getDoc(doc(await verifiedCoach(OTHER_COACH), `coachPaymentProfiles/${COACH}`)));
  await assertFails(setDoc(doc(coach, `coachPaymentProfiles/${COACH}`), { address: 'evil@instapay' }));
  await assertSucceeds(getDoc(doc(await verified(HER), `paymentStanding/${HER}`)));
  await assertFails(getDoc(doc(await verified(OTHER), `paymentStanding/${HER}`)));
  await assertFails(setDoc(doc(await verified(HER), `paymentStanding/${HER}`), { clientStrikes: 0 }));
  await assertFails(getDocs(collection(coach, 'coachPaymentProfiles')));
});

test('a fee statement is read by its coach only', async () => {
  await clearAll(); await seedPayment();
  await assertSucceeds(getDoc(doc(await verifiedCoach(COACH), 'feeStatements/s__2026-10')));
  await assertFails(getDoc(doc(await verifiedCoach(OTHER_COACH), 'feeStatements/s__2026-10')));
  await assertFails(getDoc(doc(await verified(HER), 'feeStatements/s__2026-10')));
  await assertFails(setDoc(doc(await verifiedCoach(COACH), 'feeStatements/s__2026-10'), { totalFeePiasters: 0 }));
});

test('config/payments is readable by a signed-in account and writable by nobody', async () => {
  await clearAll(); await seedPayment();
  for (const db of [await verified(HER), await verifiedCoach(COACH), await admin(uid.admin)]) {
    await assertSucceeds(getDoc(doc(db, 'config/payments')));
    await assertFails(setDoc(doc(db, 'config/payments'), { enabled: false }));
    await assertFails(getDocs(collection(db, 'config')));
  }
});
```
5. File `test/rules/storage/storage.test.js`. Anchor: the line `// --------------------------------------------------------- payment-proofs` (about line 240). After the existing test that follows it (it ends with the `put(admin(), ...p2.jpg...)` line, about line 252), add, using the same helpers `seed`, `her`, `other`, `admin`, `finance`, `put`, `anon` and the same test style as that block (copy the exact `test(...)` signature used by the test above it):
```js
test('InstaPay screenshots (payment-proofs/{paymentId}/...) cannot be read or written by either party or a stranger', async () => {
  await seed('payment-proofs/pay_1/client-1.jpg');
  await assertFails(getBytes(ref(her(), 'payment-proofs/pay_1/client-1.jpg')));
  await assertFails(getBytes(ref(other(), 'payment-proofs/pay_1/client-1.jpg')));
  await assertFails(getBytes(ref(anon(), 'payment-proofs/pay_1/client-1.jpg')));
});

test('nobody uploads into payment-proofs/{paymentId}/ from a phone', async () => {
  await assertFails(put(her(), 'payment-proofs/pay_1/client-2.jpg', 1024, 'image/jpeg'));
  await assertFails(put(other(), 'payment-proofs/pay_1/coach-1.jpg', 1024, 'image/jpeg'));
  await assertFails(put(admin(), 'payment-proofs/pay_1/client-3.jpg', 1024, 'image/jpeg'));
});

test('a party cannot delete an InstaPay screenshot', async () => {
  await seed('payment-proofs/pay_1/client-9.jpg');
  await assertFails(deleteObject(ref(her(), 'payment-proofs/pay_1/client-9.jpg')));
});
```
(`getBytes`, `deleteObject`, `ref` are already imported at the top of the file, lines 17-22. If `deleteObject` is not imported, UNVERIFIED: run `grep -n "deleteObject" test/rules/storage/storage.test.js`.)

## Strings to add
None.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `test/rules/22-instapay-payments.test.js` | the nine tests in step 4 | seed with rules off, act as each account, `assertSucceeds` or `assertFails` as written |
| `test/rules/storage/storage.test.js` | the three tests in step 5 | as written |

Commands (Firestore emulator on 8088 must be running, see `test/rules/harness.js` header; start it exactly as the other rules suites are started in this repo, UNVERIFIED command to check: `grep -rn "8088" firebase.emulator.json HOW-TO-RUN.md | head`):
`cd test/rules && node --test --test-concurrency=1 ./22-instapay-payments.test.js ./21-closed-paths.test.js ./16-dormant-features.test.js`
`cd test/rules && npm run test:storage`

## Verify
- `cd test/rules && node --test --test-concurrency=1 ./22-instapay-payments.test.js`: ends with `# fail 0` and `# pass 9`.
- `cd test/rules && npm run test:storage`: ends with `# fail 0`.
- `python3 -c "import json;json.load(open('firebase/firestore.indexes.json'))"`: prints nothing (valid JSON).
- `cd app && flutter test test/firestore_rules_test.dart test/features/coaching/coaching_rules_guard_test.dart`: `All tests passed!` (these assert text of the rules file; if one fails because it counts `match` blocks, stop and write the question).

## Do not
- Do not turn `coachPaymentsLive()` on. InstaPay does not use it.
- Do not add a rule that lets a phone write any `payments` field, including `status`.
- Do not make reads depend on `config/payments`.
- Do not put staff-only data (risk, hashes, notes) in the `payments/{id}` document itself.
- Do not edit `contracts/coaching_contract.json`.

## Done checklist
- [ ] rules block added after `paymentRefs`
- [ ] storage comment added, no rule behaviour changed
- [ ] 6 indexes added, JSON valid
- [ ] 22-instapay-payments: 9 pass
- [ ] storage suite passes
- [ ] Dart rules text tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
