# Verifying that every member is a woman — recommendation for Egypt

## Summary

Verify **the document, not the face**. Egypt's National ID number carries the holder's sex, so the
gate is a document check by a licensed Egyptian provider, with a selfie used only to prove the card
belongs to the person holding it. Never classify gender from a face: a court has already found that
excluding someone on "gender-related appearance" is direct discrimination, and face-based gender
classifiers are the least accurate part of any identity stack. A woman-reviewer path exists for women
who will not present their face to a camera.

## 1. The Egyptian National ID carries sex in the number

The Egyptian national identification number is 14 digits: century of birth, birth date, governorate
code, birth order, then a **13th digit that indicates sex (odd = male, even = female)**, and a final
check digit. Date of birth is in the same number, which also gives age.
(https://en.wikipedia.org/wiki/Egyptian_National_Identity_Card, developer reference:
https://api.signme.it/blog/egyptian-id-fields-explained)

Consequence: sex and age come from a government record, are machine-readable, and require no
judgement about appearance. Non-Egyptian residents are handled with a passport, where the MRZ carries
a sex field.

## 2. Never gate on appearance or AI gender classification

In *Tickle v Giggle*, an Australian women-only app removed a member and lost. The Federal Court found
discrimination at first instance in August 2024, and in May 2026 the Full Federal Court dismissed the
appeal, upgraded the finding to **direct** discrimination — because the exclusion rested on the
member's "gender-related appearance" — and doubled damages to AUD 20,000 plus costs.
(https://humanrights.gov.au/about-us/media-centre/media-releases/sex-and-gender-rights/full-federal-court-finds-two-acts-of-direct-discrimination-in-giggle-v-tickle-appeal,
https://en.wikipedia.org/wiki/Tickle_v_Giggle)

Australian law does not govern Egypt, but the design lesson transfers: an appearance-based gate is
both legally exposed wherever the app is distributed and unreliable in practice. The document is the
authority; the selfie only answers "is this your card?".

## 3. Vendors that actually cover the Egyptian ID

- **Valify** (Egyptian): eKYC, document verification and digital identity, licensed in Egypt, with
  verification against the National Registry as its root of trust. Local data handling is the main
  advantage under the PDPL. (https://valify.me/)
- **uqudo** (MEA): Egyptian National ID, passport and driving licence scanning, face match between the
  ID photo and the selfie, and passive liveness detection. (https://uqudo.com/egypt-kyc-aml-services/)
- Alternatives that list Egypt coverage: Shufti Pro (https://shuftipro.com/supported-countries/egypt/),
  Didit (https://didit.me/solutions/countries/egypt/), Smile ID (https://usesmileid.com/countries/egypt/).

Recommendation: **Valify first** (local licence, National Registry check, data stays in Egypt),
**uqudo** as the fallback and for non-Egyptian documents. Pricing is not published by either; treat
per-check cost as a contract negotiation and budget a manual-review queue on top.

## 4. The law you must satisfy before launch

Egypt's Personal Data Protection Law No. 151 of 2020 became fully operational when its Executive
Regulations were issued by Prime Ministerial Decree No. 816 on 1 November 2025, with a one-year
transition — so **full enforcement lands around October 2026**. Biometric data (a face template is
biometric) cannot be processed without explicit consent **and** a licence/permit from the Personal
Data Protection Centre; cross-border transfer and retention rules apply.
(https://www.clydeco.com/en/insights/2026/01/egypt-regulatory-update-on-data-privacy,
https://www.glaco.com/blog/a-first-look-at-egypts-personal-data-protection-executive-regulations/,
https://www.dlapiperdataprotection.com/?t=law&c=EG)

Design consequences, all built into the flow:
- Explicit, separate consent before the ID step, in plain Arabic and English, stating who processes it.
- The provider performs the match; **we store only the outcome**, a provider reference, the sex and
  age derived from the document, and the date. No ID images, no face templates on our side.
- Images deleted after the check; retention stated on screen before she starts.
- Licensing/registration with the PDPC and a data-processing agreement with the provider are launch
  blockers, not launch tasks.

## 5. The recommended flow

| Step | Screen | What happens | Why |
|---|---|---|---|
| 1 | Phone + code | Number, four-digit code | Cheap account binding, no password |
| 2 | Client or coach | One tap | Coaches get the certificate path too |
| 3 | Why we check | What is asked, who reads it, what is kept, ~90 seconds; explicit consent | PDPL consent; drop-off falls when the reason is stated |
| 4 | Scan your ID | Auto-capture of the card front; number read, sex and age derived | The gate: a government record, not a guess |
| 5 | Quick selfie | Passive liveness + match to the ID photo | Proves the card is hers; no gender inference |
| 6 | Checking | Usually seconds; otherwise a review queue | Manual review catches edge cases |
| 7a | You're in | Verified badge, community unlocked | — |
| 7b | Waiting for a reviewer | Under 2 hours target; she can train, cook and browse coaches meanwhile | Never a dead end |
| 7c | Woman reviewer | Video check with a woman reviewer, or in person at a partner ladies-only gym | Niqab path |

**Niqab-friendly path, stated plainly on screen:** no face photo is required or stored; a woman
reviewer conducts a short live check, or a partner gym confirms in person. Only a woman reviews it,
and the recording is not kept.

**What an unverified visitor may see:** workouts, exercise videos, recipes and coach profiles.
**Never:** member posts, photos, groups, chats, member profiles, or the challenge boards.

**Re-verification triggers:** a new device, a report upheld by moderation, or 12 months elapsed.

## 6. Owner decisions (I cannot make these for you)

1. **Minimum age** — the ID gives date of birth. Recommendation: 16+, with under-18s excluded from
   coaching purchases. Needs a legal sign-off.
2. **Trans women** — the document-marker gate follows what the ID says. Whatever policy you choose
   must be written down, applied consistently, and reviewed by an Egyptian lawyer; the Australian
   ruling shows appearance-based exclusion is the expensive path.
3. **Non-Egyptian residents** — passport-only sign-up, yes or no.
4. **Partner gyms** for in-person verification — which chains, and who pays the reviewer's time.
5. **Manual review staffing** — a women-only review team, hours of cover, and the response-time
   promise shown on screen.
