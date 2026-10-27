/// The deletion manifest — `G7-profile-privacy-safety.md` §7.3, all 37 rows.
///
/// > Deletion touches everything. Firestore does not cascade, so this table *is*
/// > the implementation, and the test asserts the emptiness of every row by path.
///
/// # Why this is data and not a list of calls
///
/// §7.3 (a): "The manifest is a single machine-readable list; the deletion
/// Function iterates it rather than naming paths inline, **so a new collection
/// added without a manifest entry is a visible omission**."
///
/// Inline `delete(path)` calls would make an omission invisible — the code would
/// simply not mention the collection, and nothing would look wrong. As data, the
/// omission is a missing row that a test can enumerate against the deployed
/// security rules. That check is [manifestGapsAgainstRules].
///
/// It found three on its first run — `cycle`, `periods` and `splits`, declared
/// in the rules and enumerated nowhere here, after three separate passes by eye
/// had each concluded the manifest "closes clean". They are now rows 35–37 and
/// the check finds none. G9 §6 R3 had asked for exactly those rows; the request
/// never reached G7, which is the failure mode this check exists to catch.
///
/// # Two rows are deliberately not deletions
///
/// Both await the same legal sign-off (G7 Q5), and **A02's copy must say so**:
///
///   * row 23 `nidRegistry/{nidHash}` — **closed**, not deleted. The hash stays
///     with `state:'closed'` and `uid:null`, so a removed woman cannot
///     re-register while no personal data stays linked.
///   * row 30 `reports/**` — **pseudonymised**, not deleted. The uids are
///     replaced with a salted token and the safety record survives.
///
/// Row 31 `deletionRequests/{uid}` is a third: retained, reduced to state and
/// timestamps, as the proof of erasure.
///
/// # The numbers are enumeration keys, not an order
///
/// Execution order is the state machine in §3.3 — Auth locked **first**, Auth
/// record deleted **last**. See `account_deletion_service.dart`.
library;

import 'package:meta/meta.dart';

/// How a row is cleared. The three non-deleting methods are the point.
enum DeletionMethod {
  /// Recursive delete of the document and every subcollection beneath it.
  recursive,

  /// Storage prefix delete.
  prefixDelete,

  /// Performed by another group's published hook, whose completion G7 asserts.
  groupHook,

  /// Cleaning up the mirror this uid wrote into *other* women's documents.
  reverseCleanup,

  /// A third-party service's own deletion API.
  thirdParty,

  /// The Auth record. Revoked and disabled first; the record deleted last.
  authRecord,

  /// Local to the handset running the deletion — no server delete can reach it.
  localOnly,

  /// **Not deleted — closed.** The row survives with its identity link removed.
  closed,

  /// **Not deleted — pseudonymised.** The record survives; the uids do not.
  pseudonymised,

  /// **Not deleted — retained** as the proof that the erasure happened.
  retained,

  /// **Not deleted by the deletion, expires on its own clock.** Records keyed
  /// on a hash and never linked to her account, so deletion cannot find
  /// them. Every write stamps `expireAt` and the Firestore TTL policy removes
  /// them: 180 days after the last fraud signal, one year after a reviewer's
  /// access.
  ttl;

  /// False for the rows that survive on purpose.
  bool get removesData =>
      this != DeletionMethod.closed &&
      this != DeletionMethod.pseudonymised &&
      this != DeletionMethod.retained &&
      this != DeletionMethod.ttl;
}

/// One row of §7.3.
@immutable
class DeletionRow {
  const DeletionRow({
    required this.number,
    required this.path,
    required this.owner,
    required this.method,
    this.note = '',
  });

  /// The enumeration key from the plan. **Not an execution order.**
  final int number;

  final String path;

  /// The group that owns the data. G7 owns the manifest, not every collection
  /// in it — which is exactly why the list has to be explicit.
  final String owner;

  final DeletionMethod method;
  final String note;

  /// The `users/{uid}/<name>` subcollection this row covers, or null.
  ///
  /// Used by [manifestGapsAgainstRules] to answer "is every subcollection the
  /// rules declare actually enumerated here?".
  String? get userSubcollection {
    final match = RegExp(r'^users/\{uid\}/([A-Za-z]+)').firstMatch(path);
    return match?.group(1);
  }

  @override
  String toString() => '$number. $path (${method.name})';
}

/// All 44 rows: G7 §7.3, plus rows 38-44 added since.
///
/// Rows 10–14 and 23 were added after reading the G1, G3 and G5 plans, and rows
/// 32–34 after G4 and G6 landed. §7.3 is blunt about what that means: "a human
/// reconciling plans by eye missed it on the first pass", which is why check (e)
/// must break the build rather than rely on the next person being more careful.
///
/// Rows 35–37 proved the point: they were found by that check on its first run,
/// not by a fourth reading. Every earlier addition came from someone noticing.
const List<DeletionRow> kDeletionManifest = <DeletionRow>[
  DeletionRow(
    number: 1,
    path: 'users/{uid}',
    owner: 'G1/G2/G6/G7',
    method: DeletionMethod.recursive,
    note:
        'including the maps profile, verification, rewards, weeklyGoal, '
        'privacy and notify',
  ),
  DeletionRow(
    number: 2,
    path: 'users/{uid}/weeks/**',
    owner: 'G6',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 3,
    path: 'users/{uid}/checkins/**',
    owner: 'G3',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 4,
    path: 'users/{uid}/sessions/**',
    owner: 'G4',
    method: DeletionMethod.recursive,
    note: 'sets are embedded (spine C2), so there is no deeper level',
  ),
  DeletionRow(
    number: 5,
    path: 'users/{uid}/meals/**',
    owner: 'G5',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 6,
    path: 'users/{uid}/bests/**',
    owner: 'G6',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 7,
    path: 'users/{uid}/measurements/**',
    owner: 'G6',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 8,
    path: 'users/{uid}/devices/**',
    owner: 'G8',
    method: DeletionMethod.recursive,
    note: 'plus FCM token invalidation',
  ),
  DeletionRow(
    number: 9,
    path: 'users/{uid}/syncQueue/**',
    owner: 'G8',
    method: DeletionMethod.localOnly,
    note:
        'a local sqflite table, not a Firestore path; cleared by '
        'clearPersistence() on the handset',
  ),
  DeletionRow(
    number: 10,
    path: 'users/{uid}/consents/{purpose}_{version}',
    owner: 'G1',
    method: DeletionMethod.groupHook,
    note: "performed by G1's onAccountDelete(uid); G7 asserts completion",
  ),
  DeletionRow(
    number: 11,
    path: 'users/{uid}/notices/{kind}-{yyyy-Www}',
    owner: 'G3',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 12,
    path: 'users/{uid}/firstWeek/arc',
    owner: 'G3',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 13,
    path: 'users/{uid}/eatPrefs/current',
    owner: 'G5',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 14,
    path: 'users/{uid}/mealPlans/{week}',
    owner: 'G5',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 15,
    path: 'users/{uid}/notifications/**',
    owner: 'G7',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 16,
    path: 'users/{uid}/blocks/**',
    owner: 'G7',
    method: DeletionMethod.recursive,
    note: 'after row 17 has read it',
  ),
  DeletionRow(
    number: 17,
    path: 'users/{other}/blockedBy/{uid}',
    owner: 'G7',
    method: DeletionMethod.reverseCleanup,
    note:
        'for every other in her blocks; bounded by her own block count, '
        'never by followers',
  ),
  DeletionRow(
    number: 18,
    path: 'users/{uid}/blockedBy/**',
    owner: 'G7',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 19,
    path: 'users/{uid}/myReports/**',
    owner: 'G7',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 20,
    path: 'plans/{uid}/versions/**',
    owner: 'G2',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 21,
    path: 'plans/{uid}/assignments/**',
    owner: 'G2',
    method: DeletionMethod.recursive,
  ),
  DeletionRow(
    number: 22,
    path: 'verificationJobs where uid == {uid}',
    owner: 'G1',
    method: DeletionMethod.groupHook,
    note: 'images are already gone under rule 7',
  ),
  DeletionRow(
    number: 23,
    path: 'nidRegistry/{nidHash}',
    owner: 'G1',
    method: DeletionMethod.closed,
    note:
        "NOT deleted — closed. state:'closed', uid:null, so a removed woman "
        'cannot re-register while no personal data stays linked. Q5',
  ),
  DeletionRow(
    number: 24,
    path: 'Storage user-media/{uid}/**, coach-docs/{uid}/**, coach-public/{uid}/** and payment-proofs/{uid}/**',
    owner: 'media groups',
    method: DeletionMethod.prefixDelete,
    note:
        'her media, and a coach\'s application files (certificates, education, '
        'feedback, transformations, photo); exports are row 25',
  ),
  DeletionRow(
    number: 25,
    path: 'Storage user-exports/{uid}/**',
    owner: 'G7',
    method: DeletionMethod.prefixDelete,
  ),
  DeletionRow(
    number: 26,
    path: 'G1 onAccountDelete(uid)',
    owner: 'G1, called by G7',
    method: DeletionMethod.groupHook,
    note:
        'runs the community, coach and assistant purge on the server '
        '(purge_group_hook)',
  ),
  DeletionRow(
    number: 27,
    path: 'Amplitude',
    owner: 'G8',
    method: DeletionMethod.thirdParty,
  ),
  DeletionRow(
    number: 28,
    path: 'Crashlytics',
    owner: 'G8',
    method: DeletionMethod.thirdParty,
  ),
  DeletionRow(
    number: 29,
    path: 'Firebase Auth',
    owner: 'G1',
    method: DeletionMethod.authRecord,
    note: 'revoke tokens and disable FIRST; delete the record LAST',
  ),
  DeletionRow(
    number: 30,
    path: 'reports/** where reporterUid == uid or subjectUid == uid',
    owner: 'G7',
    method: DeletionMethod.pseudonymised,
    note:
        'NOT deleted — pseudonymised. The uids become a salted token and the '
        "safety record survives. A02's copy must say this plainly. Q5",
  ),
  DeletionRow(
    number: 31,
    path: 'deletionRequests/{uid}',
    owner: 'G7',
    method: DeletionMethod.retained,
    note: 'retained, reduced to state and timestamps, as the proof of erasure',
  ),
  DeletionRow(
    number: 32,
    path: 'users/{uid}/awards/{awardId}',
    owner: 'G6',
    method: DeletionMethod.recursive,
    note: "G6's append-only points ledger; only an admin delete can clear it",
  ),
  DeletionRow(
    number: 33,
    // Named for what this release has, which is nowhere: there is no capture
    // path, no store and no key. It read "on-device encrypted progress-photo
    // store", which describes a thing the product does not have and reads, in a
    // column of real Firestore paths, as one more real place. The note below
    // said "NOT BUILT" and the path above it said the opposite.
    path: 'progress photos on the phone (no store in this release)',
    owner: 'G6, wiped by G7',
    method: DeletionMethod.localOnly,
    note:
        'MeasurementsRepository.purgeLocal(). The photos have no Storage '
        'object and no Firestore reference, so NO server-side delete can reach '
        'them. NOT BUILT: this release has no capture path and no photo store, '
        'so the step runs and finds nothing. The row stands because the day a '
        'camera lands it must already be enumerated',
  ),
  DeletionRow(
    number: 34,
    path: 'photo store key in Keychain / Android Keystore',
    owner: 'G6, destroyed by G7',
    method: DeletionMethod.localOnly,
    note:
        'wiping ciphertext while leaving the key is not deletion. NOT BUILT: '
        'no key is ever minted in this release, so there is none to destroy',
  ),

  // Rows 35-37 — added after check (e) went executable and immediately caught
  // three collections the manifest had never enumerated. This is the fourth
  // time §7.3 has gained rows it was previously certain it did not need, and
  // the first time a machine found them instead of a person.
  //
  // The method was not invented. All three are plain per-user subcollections
  // declared `allow read, write: if isSelf(uid)` with no retention exception,
  // no server projection and no legal hold — structurally identical to rows
  // 2-7, which are recursive. There is no second candidate.
  DeletionRow(
    number: 35,
    path: 'users/{uid}/cycle/**',
    owner: 'G9',
    method: DeletionMethod.recursive,
    note:
        'her cycle setup and its sharing switches. The most sensitive data '
        'in the product, and it had no row: deletion would have left it on '
        'the server while A02 told her nothing survives',
  ),
  DeletionRow(
    number: 36,
    path: 'users/{uid}/periods/**',
    owner: 'G9',
    method: DeletionMethod.recursive,
    note: 'every period date she recorded, one document per day',
  ),
  DeletionRow(
    number: 37,
    path: 'users/{uid}/splits/**',
    owner: 'G4/G14',
    method: DeletionMethod.recursive,
    note:
        'the splits she authored herself (DECISIONS D7, ownerKind self). A '
        "coach's own splits live under coaches/{coachUid}/splits and are not "
        'hers to delete',
  ),
  DeletionRow(
    number: 38,
    path: 'users/{uid}/private/**',
    owner: 'G7',
    method: DeletionMethod.recursive,
    note:
        'server-minted facts about her that are not hers to write: today that '
        'is the recipe entitlement, {tier, source, expiresAt}. Nothing reads '
        'it yet, and it is enumerated anyway — Firestore does not '
        'cascade-delete a subcollection, so a collection added ahead of its '
        'feature is exactly the kind that gets left behind on the server while '
        'A02 tells her nothing survived',
  ),

  // Rows 39-41: the server's own records of her identity check, added with
  // the real `delete_account` callable. Each is found by her uid and removed
  // by the deletion Function (contracts/deletion_manifest.json). The NID
  // registry is NOT here: that is row 23, closed rather than deleted.
  DeletionRow(
    number: 39,
    path: 'verification_flags where uid == {uid}',
    owner: 'G1',
    method: DeletionMethod.groupHook,
    note:
        'any review flag for her: reason codes and scores only, never an '
        'image or a phone number',
  ),
  DeletionRow(
    number: 40,
    path: 'verificationLedger/{uid}',
    owner: 'G1',
    method: DeletionMethod.groupHook,
    note: 'her check budget, attempt counts and daily counters',
  ),
  DeletionRow(
    number: 41,
    path: 'verificationSessions where uid == {uid}',
    owner: 'G1',
    method: DeletionMethod.groupHook,
    note: 'single-use liveness challenges minted for her',
  ),
  // Rows 42-44: kept after deletion on purpose, never linked to her account,
  // and swept by the TTL policy on `expireAt` (functions/identity/config.py
  // SIGNAL_RETENTION_DAYS and ACCESS_LOG_RETENTION_DAYS). Privacy policy v3
  // sections 6 and 7 name them, and so does the deletion sheet.
  DeletionRow(
    number: 42,
    path: 'verificationBehaviour/{idHmac}',
    owner: 'G1',
    method: DeletionMethod.ttl,
    note:
        'failed attempts per keyed ID code, linked to no account, deleted '
        '180 days after the last attempt',
  ),
  DeletionRow(
    number: 43,
    path: 'verificationInstalls/{installHash}',
    owner: 'G1',
    method: DeletionMethod.ttl,
    note:
        'the last ID codes tried from one hashed installation, linked to no '
        'account, deleted 180 days after the last attempt',
  ),
  DeletionRow(
    number: 44,
    path: 'verificationReviewAccess where flagId in her flags',
    owner: 'G1',
    method: DeletionMethod.ttl,
    note:
        'which reviewer opened her case and when: no photograph, phone '
        'number or ID number, deleted after one year',
  ),
  // Rows 45 to 49 name, one by one, what row 26's purge already removes:
  // the community and coach data that is dormant at launch (the rules refuse
  // every write to it while both are off) and must be erasable before either
  // is switched on.
  DeletionRow(
    number: 45,
    path: 'posts/{postId} where authorUid == uid, with comments and likes',
    owner: 'G1, called by G7',
    method: DeletionMethod.groupHook,
    note: 'her posts and everything under them (purge_group_hook)',
  ),
  DeletionRow(
    number: 46,
    path: 'posts/*/comments where authorUid == uid',
    owner: 'G1, called by G7',
    method: DeletionMethod.groupHook,
    note:
        'her comments on other women\'s posts, replaced by an empty '
        'placeholder with no words and no uid (purge_group_hook)',
  ),
  DeletionRow(
    number: 47,
    path: 'coaches/{uid}/** (profile, offers, portfolio, results, ads, splits, certificates)',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note: 'her coach page and certificate records (purge_group_hook)',
  ),
  DeletionRow(
    number: 48,
    path: 'relationships where coachUid or clientUid == uid, with messages and reviews, and Storage chat-media/{relId}/** (the photos, clips and voice notes of both people in each thread)',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note: 'every coaching she was part of, as client or coach',
  ),
  DeletionRow(
    number: 49,
    path: 'coachInvites where coachUid == uid',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note: 'the invite codes she shared as a coach',
  ),
  DeletionRow(
    number: 50,
    path: 'verificationBookings where uid == {uid}',
    owner: 'G7',
    method: DeletionMethod.groupHook,
    note: 'the review slots she booked',
  ),
  DeletionRow(
    number: 51,
    path:
        'verificationReviewers/{uid} and verificationBookings where '
        'reviewerId == {uid}',
    owner: 'G7',
    method: DeletionMethod.groupHook,
    note: 'her reviewer record and the bookings made with her as reviewer',
  ),
  DeletionRow(
    number: 52,
    path: 'verificationPreapproved/{E.164 phone of her Auth account}',
    owner: 'G7',
    method: DeletionMethod.groupHook,
    note:
        'the pre-approval saved against her phone number; a removed number is '
        'purged by the hourly cleanup once its undo window has passed',
  ),
  DeletionRow(
    number: 53,
    path: 'events/{eventId}/attendees/{uid}',
    owner: 'G7',
    method: DeletionMethod.groupHook,
    note: 'her reserved seats; each event gets the seat back',
  ),
  DeletionRow(
    number: 54,
    path: 'communityFoodCandidates/{key}/by/{HMAC of her uid}',
    owner: 'G7',
    method: DeletionMethod.groupHook,
    note: 'her confirmation marker on shared foods; the count stays',
  ),
  DeletionRow(
    number: 55,
    path: 'coachApplications/{uid}',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note: 'her application to coach, whatever its status (purge_group_hook)',
  ),
  DeletionRow(
    number: 56,
    path: 'coachPrivate/{uid}/** (prices, ledger, payouts)',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note: 'a coach\'s own prices and payout details; no money record exists while payments are off',
  ),
  DeletionRow(
    number: 57,
    path:
        'coaches/{uid}/packages/**, coaches/{uid}/drafts/** and '
        'coaches/{uid}/media/**',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note:
        'a coach\'s packages, unfinished plan drafts and portfolio media '
        'records, deleted with her coach page; the files are row 24',
  ),
  DeletionRow(
    number: 58,
    path:
        'subscriptions where clientUid or coachUid == uid, with '
        'private/terms and sessions',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note:
        'a coaching she joined or gave, with the intake form and health '
        'answers; an open one is ended first, so the coach\'s place is freed',
  ),
  DeletionRow(
    number: 59,
    path: 'receipts and paymentProofs where clientUid or coachUid == uid',
    owner: 'G12, called by G7',
    method: DeletionMethod.pseudonymised,
    note:
        'NOT deleted, pseudonymised. A payment record stays for the books '
        'with her uid replaced by a token and her typed names emptied. None '
        'exists while payments are off',
  ),
  DeletionRow(
    number: 60,
    path:
        'reports/{id}/evidence/content where the report\'s reporterUid or '
        'subjectUid == uid',
    owner: 'G12, called by G7',
    method: DeletionMethod.pseudonymised,
    note:
        'the copy of what was reported (the text of the message, or the '
        'portfolio name and headline), taken when the report was made. Deleted when the reporter deletes her account; kept, '
        'pseudonymised, when the reported side deletes hers, until the '
        'reporter deletes hers or the retention period set with counsel',
  ),
  DeletionRow(
    number: 61,
    path: 'coachPrivate/{uid}/mediaConsents/{id}',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note:
        'a coach\'s evidence that a client agreed in writing to her photos '
        'being shown (the picture of the release), deleted with her coach '
        'space; the release file is row 24',
  ),
  DeletionRow(
    number: 62,
    path: 'relationships/{relId}/checkIns/{weekKey} where the relationship names her as coachUid or clientUid',
    owner: 'G12, called by G7',
    method: DeletionMethod.groupHook,
    note:
        'her weekly check-in answers, deleted with the coaching they belong to',
  ),
];

/// The two rows A02's copy must explain, because they survive on purpose.
List<DeletionRow> get kRowsThatSurvive =>
    kDeletionManifest.where((r) => !r.method.removesData).toList();

/// The rows that can only run on **the handset executing the deletion**.
///
/// G7 §3.3's honest limit: "If she deletes her account from a second phone, the
/// first phone's encrypted photo store survives until that installation next
/// launches, notices the account is gone, and self-wipes. The server-side
/// guarantee is complete; the on-device guarantee is eventual, and A02's copy
/// must not claim otherwise."
List<DeletionRow> get kHandsetOnlyRows => kDeletionManifest
    .where((r) => r.method == DeletionMethod.localOnly)
    .toList();

/// Every `users/{uid}/<name>` subcollection the manifest enumerates.
Set<String> get kManifestUserSubcollections => kDeletionManifest
    .map((r) => r.userSubcollection)
    .whereType<String>()
    .toSet();

/// §7.3 check (e), executable: **any `users/{uid}/*` subcollection that exists
/// in the deployed security rules without a manifest row.**
///
/// [declaredInRules] is the set of subcollection names parsed out of
/// `firebase/firestore.rules`. Passing it in rather than reading the file here
/// keeps this a pure function — the test owns the I/O.
///
/// A non-empty result means P0-DEL-01 would leave that collection behind.
Set<String> manifestGapsAgainstRules(Set<String> declaredInRules) =>
    declaredInRules.difference(kManifestUserSubcollections);

/// Subcollections knowingly left without a manifest row. **Empty, and it must
/// stay empty.**
///
/// It was `{'cycle', 'periods', 'splits'}` for exactly as long as it took to
/// make check (e) executable. All three were real — declared in
/// `firestore.rules` under `users/{uid}`, enumerated nowhere in §7.3 — so
/// deleting an account would have left her cycle settings, her period dates and
/// her own splits on the server while A02's copy told her nothing survived.
/// They are now rows 35, 36 and 37, and G7 §7.3 has been amended to match.
///
/// This constant is not a to-do list. It exists so that a future omission has to
/// be *written down as an exception* by a person who can be asked why, instead
/// of passing silently. Adding a name here is a decision that needs a reason in
/// `DECISIONS.md`; the empty set is the only state that needs no defence.
const Set<String> kKnownManifestGaps = <String>{};
