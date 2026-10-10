I've built all 16 MUST items. One sub-part is deviated (M2) and two are partly skipped (M2, M14), all for owner or lawyer reasons. Nothing is committed: your instructions and your memory both say no commit or push without your approval, so there are no commit hashes. `flutter analyze` is clean, the full `flutter test` run passes 4826 with 0 failures (the R1-12a Tuesday test passed this run), and the functions suite passes 955 (893 before). The pages are rebuilt with `site/_build/build.py`.

Three things need a decision from you:
- **Release builds won't start yet.** A release build now refuses to launch until the four `LegalLinks` URLs are filled in. That includes debug-signed QA builds you hand out. Debug builds only print a warning; I didn't add the plan's `assert`, because it would break every debug run while the links are empty.
- **The store-review bypass (M13).** Accounts listed in the Secret Manager secret `store-reviewer-uids` are approved without the ID check. It is empty by default, fails closed if the secret can't be read, and every use is logged. Keep it empty except while a store review is open.
- **Existing testers will see the update sheet once.** Any already signed-in account will see the legal update sheet at launch, because nobody has an acceptance record yet.

## Status by item

| Item | Status | Proof |
|---|---|---|
| M1 Terms and Privacy acceptance at C06 | done | `functions/tests/test_legal_acceptance.py`, `app/test/features/signup/legal_acceptance_test.dart` (no SMS before the tap, acceptance saved before the code is sent, flushed after the code is accepted, a version bump asks again, update sheet blocks), contract tests on both sides, `value_first_signup_test` |
| M2 Legal links | **partly skipped** | Links are added on C06, C09b, the health sheet, Your data and the update sheet, and open the Arabic pages in Arabic. The 4 URLs are not filled: `baseUrl` is still `ownhub.example` (owner). |
| M3 Crash reports only with consent | done | `test/release/crash_consent_test.dart`, `crash_reporting_privacy_test.dart`, a privacy-screen switch test. Native defaults stay off. |
| M4 C09b rewrite, consent version 2 | done | Version moved to 2 on both sides; the record now also stores language and app version. `consent_view_test`, contract tests, `test_entrypoints.py` |
| M5 iOS camera permission text (EN and AR) | done | `Info.plist`, `en.lproj` and `ar.lproj/InfoPlist.strings` |
| M6 "Not a medical device" | done | On Profile, cycle hub, cycle setup, life stage, and "Your week" when pregnant or postpartum. `test/release/compliance_copy_test.dart` |
| M7 Copy fixes (claims rows 1–31) | done | Exceptions: row 19 already resolved (string unused in the app); row 9 banners kept until counsel signs off; row 24 changed on top of review-v1 without a version bump, as the plan says. Covered by updated view tests and the retired-strings guard. |
| M8 Copy of her data by email | done | "Ask for a copy" button (mailto to the privacy mailbox) in Your data, plus `functions/tools/export_user.py` and `tests/test_export_user.py` (every deletion-manifest row is exported or excluded with a reason) |
| M9 Retention periods (TTLs) | done | Fraud signals 180 days, reviewer access log 365 days, manifest rows 42–44, TTL policies declared, `firebase/ops/ttl-policies.sh`. `test_ttl_fields.py`, `test_indexes.py`, manifest tests on both sides |
| M10 Ramadan setting stays on the phone | done | No longer sent to or read from the cloud. `compliance_copy_test.dart` |
| M11 Waitlist consent proof | done | Proof kept 3 years, readable by no client (rule added). `test_waitlist.py` |
| M12 iOS privacy manifest and Play answers | done | Manifest declares the types in plan section 7.1 (Device ID now "linked", as the plan says), and `play-data-safety.txt` is rewritten. `store_disclosures_test.dart`. Xcode privacy report not generated. |
| M13 Store reviewer bypass | done | `tests/test_reviewer_access.py` |
| M14 Site rebuild | done, **config values pending** | Privacy and terms v3 in EN and AR, [LAWYER] notes as HTML comments only, support, delete-account and home page fixes, Latin names isolated on Arabic pages. Real `baseUrl` and mailboxes not set (owner). `test_site_build.py` (28 tests) |
| M15 Preflight checks | done | Fails on site gaps and draft banners, the invalid HealthFitness key, any app/server version mismatch, or empty LegalLinks; the release build now records the app version. Both scripts syntax-checked. |
| M16 Flag-alert chat service | done (placeholder) | Named in privacy §3.4 and §4 as a site setting, `chatService`, for you to fill in |

## Files
- **New, app:**
  - `app/lib/app_state/crash_consent.dart`
  - `app/lib/features/signup/domain/legal_acceptance.dart`
  - `app/lib/features/signup/data/callable_legal_acceptance_store.dart`
  - `app/lib/features/account/presentation/legal_update_sheet.dart`
  - `app/lib/ui/medical_disclaimer.dart`
- **New, other:** `functions/tools/export_user.py`, `firebase/ops/ttl-policies.sh`
- **New tests:**
  - `app/test/features/signup/legal_acceptance_test.dart`
  - `app/test/release/crash_consent_test.dart`
  - `app/test/release/compliance_copy_test.dart`
  - `functions/tests/test_legal_acceptance.py`
  - `functions/tests/test_export_user.py`
  - `functions/tests/test_reviewer_access.py`
- **Changed, app:** `main.dart`, `app_router.dart`, `legal_links.dart`, `firebase_boot.dart`, `crash_reports.dart`, `account_data.dart`, `cloud_documents.dart`, `deletion_manifest.dart`, `capture_consent.dart`, `callable_capture_consent_store.dart`, and the views (phone number, consent, why-we-check, woman reviewer, being checked, privacy, your data, safety centre, profile, cycle hub, cycle setup, life stage, schedule)
- **Changed, platform:** `AndroidManifest.xml` (mail-app query), `PrivacyInfo.xcprivacy`, `Info.plist` and both `InfoPlist.strings`, `play-data-safety.txt`, `build_release.sh`, `release_preflight.sh`
- **Changed, functions:** `functions/identity/config.py`, `store.py`, `main.py`, `account/manifest.py`, `deletion.py`, `waitlist/join.py`
- **Changed, shared:** both copies of `deletion_manifest.json`, `contracts/identity_contract.json`, `firebase/firestore.rules`, `firestore.indexes.json`
- **Changed, site:** `site/_build/build.py`, `pages_en.py`, `pages_ar.py`, `config.json` (new keys and a `release` flag), and the rebuilt HTML
- **Strings:** 40 pairs added with `tool/add_strings.py`; ARB files regenerated, not hand-edited.

## Other issues I noticed
1. Several C15 and C14 lines still promise "a short video call". They are the review-v1 consent wording, which the plan keeps unchanged, so fixing them needs a review-consent version bump.
2. I left the replaced strings in the `6-v2/i18n` dictionary. Removing them would rename other keys and break the 6-v2 mockups, which still use them. They are unused in the app (same clean-up as plan row 32).
3. The release preflight and the site release test will fail until the empty site settings (22 values, including the v3 effective date, response window, retention periods, video, chat and email services, host and court) and `baseUrl` are filled in, and the draft banners are removed after counsel signs off.
4. I haven't generated the Xcode privacy report (APL-05), run anything on a device, or deployed the TTL policies.