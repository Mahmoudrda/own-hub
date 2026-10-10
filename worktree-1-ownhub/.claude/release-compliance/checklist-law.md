# Own Hub: legal obligations research for Egypt (PDPL, consumer, cybercrime, e-signature, health, women-only, Constitution)

**This is research, not legal advice.** It was put together on 2026-10-06 from official texts where I could reach them and from law-firm summaries where I couldn't. A licensed Egyptian lawyer has to confirm every item before release (list in section J).

**The most urgent point:** the one-year grace period under the PDPL Executive Regulations ends on **31 Oct / 1 Nov 2026, which is 25 days from today.** After that date Own Hub needs a licence or permit from the PDPC (Personal Data Protection Centre) to process sensitive data and another to send data abroad. Its data goes to Frankfurt and to the US.

## How I checked

- **Law texts read in full:**
  - Law 151/2020 (PDPL) and Law 181/2018 (consumer protection), English translations hosted by Andersen Egypt.
  - Law 175/2018 (cybercrime), Andersen translation.
  - The owner's Constitution text: `/Users/mahmoudreda/ownhub/.claude/release-compliance/egypt-constitution-2019.txt`. The PDF extraction drops hamzas ("األ" for "الأ"). I corrected those in the quotes below. Line numbers refer to that file.
- **Code checked** in `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding`, with findings cited as file:line.
- **Sources I could not read directly:**
  - The PDPC's own PDF guidelines on pdpc.gov.eg. The site's certificate doesn't match its hostname and the files come back as an HTML app shell, so I relied on law-firm summaries of them.
  - The Executive Regulations' article numbers. These differ between summaries and must be checked against the Gazette text (Ministerial Decree 816/2025).

---

## A. PDPL Law 151/2020 and its Executive Regulations (Decree 816/2025)

Sources:
- Law text (EN translation): https://eg.andersen.com/wp-content/uploads/2025/06/Law-No.-151-OF-2020.pdf
- Official MCIT scan: https://mcit.gov.eg/Upcont/Documents/Reports%20and%20Documents_1232021000_Law_No_151_2020_Personal_Data_Protection.pdf
- Regulations summaries:
  - https://shalakany.com/wp-content/uploads/2025/12/New-Executive-Regulations-for-Egypts-Personal-Data-Protection-Law-.pdf
  - https://chambers.com/articles/a-first-look-at-egypt-s-personal-data-protection-executive-regulations
  - https://amereller.com/publication/the-egyptian-personal-data-protection-regime-what-you-need-to-know-ahead-of-31-october-2026/
  - https://cms.law/en/int/legal-updates/egypt-s-pdpl-executive-regulations-issued-one-year-compliance-countdown-begins
  - https://connectontech.bakermckenzie.com/egypt-important-data-protection-update/

| ID | Requirement | Source | Applies to Own Hub because… | How to check | Severity |
|---|---|---|---|---|---|
| PDPL-01 | **Status and deadline.** The Regulations were issued 1 Nov 2025 and took effect 2 Nov 2025. The grace period ends 31 Oct / 1 Nov 2026. Fines and imprisonment apply after that. A law-firm summary (no named source) says that as of 10 Sep 2026 the PDPC's online licence portal was not yet open. | Shalakany PDF; Amereller | Launch falls after the grace period ends. | Check pdpc.gov.eg for the portal before launch, and keep proof of filing. | legal-liability |
| PDPL-02 | **Controller licence or permit.** Processing needs a PDPC licence (3 years) or permit (up to 1 year). The law defines a *licence* as issued to a legal entity and a *permit* as issued to a natural or legal person. The fee is waived below 100,000 records, but the licence itself is still required. | Law Art. 1 definitions, Art. 26; Chambers | The controller is "Mahmoud Reda, an individual". An individual may only be able to hold a permit, renewed every year. | `site/privacy/index.html:107` still shows "[to be completed: … permit number and expiry]". | legal-liability |
| PDPL-03 | **Sensitive-data licence.** No collecting, storing or processing of sensitive data "without a licence from the Center", plus **written and explicit consent** (Art. 12). Sensitive data covers physical or mental health, **biometric** data, and all children's data (Art. 1). | Law Arts. 1, 12; Shalakany | Three things qualify: (1) the selfie face match is biometric processing, even in memory only; (2) the opt-in health backup (cycle, pregnancy, weight); (3) intake life-stage answers, but only if they ever leave the phone. | `functions/identity/faces.py`, `record_health_consent`, `HEALTH_CONSENT_VERSION` (`functions/identity/config.py:639`) | legal-liability (Art. 41: EGP 500k–5M fine and/or ≥3 months' prison) |
| PDPL-04 | **Explicit consent, recorded.** Consent must be explicit, informed, specific and freely given, using a clear affirmative action. Sensitive data needs **written** consent, and electronic form is accepted. Per the PDPC guideline as summarised, the request must be in Arabic, kept separate from the terms and privacy notice, and logged in a consent record. | Law Arts. 2, 6, 12; CMS; consentx summary https://www.consentx.io/compliance/eg-pdpl | ID and selfie consent already exists: C09b `ConsentView` records uid, version and timestamp before the camera opens, and a decline path exists. | `app/lib/features/signup/presentation/consent_view.dart`. `kCaptureConsentVersion` must equal server `CONSENT_VERSION = 1` (`config.py:634`). | legal-liability (largely met) |
| PDPL-05 | **Cross-border transfer.** Transfers abroad are banned unless the destination's protection is at least equal to Egypt's **and** the PDPC has licensed the transfer (Art. 14). Where protection isn't adequate, explicit consent plus a listed ground is needed (Art. 15). The licence fee is 50% of the controller fee. It names each destination country and needs a transfer impact assessment (TIA). | Law Arts. 14–16; Amereller; Shalakany | Account data, verification and training logs go to Frankfurt (`config.py:47`, region `europe-west3`). Cloud Vision uses the EU endpoint (`config.py:55`). The **phone number goes to Firebase Auth in the US** (privacy §4). The review video-call vendor is still to be decided. A Gemini assistant is planned. | Privacy §5 has "[to be completed: the countries … transfer mechanism]" (`site/privacy/index.html:316`). | legal-liability (Art. 42: EGP 500k–5M fine and/or prison) |
| PDPL-06 | **Transfer consent must come before the transfer.** The privacy page promises "We ask for that consent, naming these countries, before your data leaves your phone". | Law Art. 15; privacy §5 | In the new flow (phone, code, consent) the phone number reaches Firebase Auth in the US **before** any consent screen. The phone screen only says "By joining you agree to the Own Hub rules". | `phone_number_view.dart` strings `byJoiningYouAgreeToTheOwn` and `weTextYouASixDigitCode`. Neither mentions the US or links to the policy. | legal-liability |
| PDPL-07 | **Data subject rights.** She can know, access and **obtain** her data; withdraw consent; correct or delete; restrict; object; and be told of a breach (Art. 2). Reported reply deadline: **6 working days**, with silence counting as refusal. Fees are capped at EGP 20,000; better to charge nothing. | Law Art. 2; Regulations as reported by Baker McKenzie (link above) | In-app delete exists. **Export is not built**: the Terms (§6) say so and promise a copy by email. | `site/privacy/index.html:378` still shows "[to be completed: the response window…]". Fill in "6 working days" once counsel confirms. Check that `functions/account/deletion.py` covers every collection in `deletion_manifest.json`. | legal-liability |
| PDPL-08 | **Breach notification.** Notify the PDPC within 72 hours of becoming aware. Within the same 72 hours, send the details listed in Art. 7. Tell affected people within 3 working days of notifying the PDPC. Keep a breach register. | Law Art. 7; Shalakany | Applies to any controller. The privacy page §9 already states this. | No runbook found in the repo. Write one: who decides, the PDPC template, and the Arabic and English message to users. | legal-liability |
| PDPL-09 | **Data protection officer (DPO).** A legal entity's legal representative must appoint and register a qualified DPO. Registration has categories A, B and C, requires an exam, and lasts 2 years. A natural-person controller is "personally responsible" instead. | Law Art. 8; Amereller | Today Mahmoud is an individual, so he is personally liable. If a company is formed, a registered DPO becomes mandatory. | Privacy §1 names a gmail address. Publish the DPO's contact once one is appointed. | legal-liability |
| PDPL-10 | **Purpose, retention and records of processing.** Data must be used only for its declared purpose and deleted when that purpose ends. Keep secure electronic records: consent log, list of processing activities, retention periods. | Law Art. 3; Shalakany | Retention periods are drafted (180 days for verification records, "pending counsel"). | Privacy §6. Build a records-of-processing document. A retention TTL should exist on review cases. | legal-liability |
| PDPL-11 | **Processor terms.** The controller must bind processors (Google, the SMS route, the video-call vendor) by contract to process only on its instructions and to equal protection. | Law Arts. 4–5; Regulations | All processing runs on Google. | Accept the Google Cloud Data Processing Addendum (https://cloud.google.com/terms/data-processing-addendum) in the Cloud console, and keep evidence. | legal-liability |
| PDPL-12 | **Direct electronic marketing.** Needs prior consent, a clear sender identity, a working opt-out, and **consent records kept 3 years after the last message** (Art. 18). The Regulations add a separate marketing licence. | Law Arts. 17–18; Shalakany | The waitlist sends one "we're open" message. Its 180-day auto-delete conflicts with the 3-year consent-record rule. | `functions/waitlist`; privacy §3.7 | legal-liability |
| PDPL-13 | **Children.** Children's data is always sensitive and needs a guardian's consent. | Law Arts. 1, 12 | 18+ only. `MIN_AGE = 18` (`functions/identity/config.py:114`) is read from the national ID number. ID cards are issued from age 16, so the refusal for 16–17-year-olds must hold. | Test: a 17-year-old ID number is refused. Terms §3 and privacy §2 say 18+. | legal-liability (met; keep it tested) |
| PDPL-14 | **AI use of personal data.** The Regulations require that personal data used for AI training cause no harm and stay within its purpose. Any new purpose needs fresh consent. | Shalakany ("training of artificial intelligence systems") | The assistant (`lib/features/assistant`) is planned for Gemini Flash and is not wired yet. See section G. | `assistant_provider.dart:4-64` | legal-liability |

## B. Consumer Protection Law 181/2018

Source: https://eg.andersen.com/wp-content/uploads/2025/07/Law-No.-181-of-2018.pdf. Article numbers differ between translations, so check them against the Gazette.

| ID | Requirement | Source | Applies because… | How to check | Severity |
|---|---|---|---|---|---|
| CPL-01 | Every advertisement, document and contract, **including electronic ones**, must be in Arabic and legible. Other languages may sit alongside. The supplier's identity must appear: address, contact, **commercial or activity registration**. | Art. 5 (Andersen numbering) | The Terms and Privacy pages and app UI are in English and Arabic (`site/ar/*`). Mahmoud publishes as an individual with no registration number shown. | Terms §1 and §17 say only "Mahmoud Reda, Egypt". Add an address and registration, or have counsel confirm whether an individual publisher is exempt. Add a clause that **the Arabic text prevails**. | legal-liability |
| CPL-02 | No misleading claims about a product's features, **expected results**, the provider's identity, or the nature or risks of the service. | Arts. 1 ("deceptive practice"), 9 | Fitness outcomes, "women only", "never stored", "no analytics". | Audit store listing and site copy. Every claim must be true of the shipped build (see I-01). | legal-liability |
| CPL-03 | Any clause that reduces the supplier's legal obligations is **void**. | Art. 28 (Andersen) | Terms §13 limits liability. | Counsel to confirm that §13 survives this rule. | legal-liability |
| CPL-04 | Distance contracts need: information before the contract; confirmation of acceptance with 7 working days to correct; a written confirmation sent electronically; a 14-day withdrawal right with refund within 7 days. | Arts. 37–41 | Not in force while the app is free and payments are off (Terms §9). It applies the day paid coaching ships. | `coachApp` flag off; `lib/features/coach/domain/payments.dart` | rejection-level later / best-practice now |

## C. Anti-Cyber and IT Crimes Law 175/2018

Source: https://eg.andersen.com/wp-content/uploads/2025/06/Law-No.-175-of-2018-Concerning-Information-Technology-Crimes.pdf

| ID | Requirement | Source | Applies because… | How to check | Severity |
|---|---|---|---|---|---|
| CYB-01 | A "service provider" includes anyone who "process[es] or store[s] information… on behalf of others". Such providers must keep service logs for 180 days (user-identifying data and traffic), keep them confidential, and display name, address and contact (Art. 2). | Arts. 1, 2 | This may reach the app operator. It pulls against the "no logs beside an outcome" design. | Counsel to confirm whether Own Hub counts as a service provider (it is usually read as telecom or hosting). Check Cloud Logging retention settings. | legal-liability (uncertain) |
| CYB-02 | Website or account administrators who **negligently** expose the system to a crime by not taking the required security measures: EGP 10k–100k fine and/or ≥6 months' prison. | Art. 29 | Firestore rules, App Check, Secret Manager. | `firebase/firestore.rules`, `ENFORCE_APP_CHECK = True` (`config.py`) | legal-liability |
| CYB-03 | Crimes include invading private life, providing personal data to a system for **promoting goods without consent**, and publishing images that violate privacy (Art. 25). Linking someone's data to immoral content or harming their reputation is also a crime (Art. 26). | Arts. 25–26 | Community, coach portfolios and before/after images later on. | Keep `community` off until moderation, reporting and blocking work. Coach consent: `lib/features/coachbrand/domain/consent.dart`. | legal-liability |
| CYB-04 | Creating a fake account in someone else's name is a crime (Art. 24). | Art. 24 | Supports the ID check and the one-card-one-account rule. | `functions/identity/dedupe.py` | best-practice (supports design) |

## D. E-signature and click-wrap acceptance of the Terms

| ID | Requirement | Source | Applies because… | How to check | Severity |
|---|---|---|---|---|---|
| ESIG-01 | Electronic writing has the same evidential weight as paper if it meets the law's technical conditions on integrity and attribution (Arts. 14–15, Law 15/2004). Click-through acceptance counts as evidence of intent. | https://www.wipo.int/wipolex/en/legislation/details/13546 ; https://www.lexology.com/library/detail.aspx?g=c858df08-939e-429b-900d-4892d45e177d | Terms §1 says "By downloading or using Own Hub you accept". That is browse-wrap, the weakest form. | Phone screen: `byJoiningYouAgreeToTheOwn` has **no link and no record**. `app/lib/config/legal_links.dart:18,21` has `privacyPolicy = ''` and `terms = ''`, so no link renders. **Fix:** link the Terms and Privacy pages on C06 and record `{uid, termsVersion, privacyVersion, locale, timestamp}` on the server, the same way the C09b consent is stored. | legal-liability; empty privacy URL = store **rejection** (preflight already fails) |
| ESIG-02 | Under the consumer law, contracts must be in Arabic, and Terms changes need notice. | CPL Art. 5 | Terms v2.0 exists in both languages. | Accept the Terms in the user's own locale and store which locale she accepted. | legal-liability |

## E. Medical and fitness advice liability, and health advertising

| ID | Requirement | Source | Applies because… | How to check | Severity |
|---|---|---|---|---|---|
| MED-01 | Law 13/2025 on medical liability and patient safety (in force from late 2025) covers healthcare professionals: physicians, nurses, technicians. Whether trainers or nutritionists fall under it is unclear. | https://eg.andersen.com/law-no-13-of-2025/ ; https://sis.gov.eg/en/media-center/news/egypt-s-top-prosecutor-says-new-medical-liability-law-strengthens-patient-safety-and-protects-doctors/ | Coaches give postpartum and pregnancy programmes. Own Hub must not present itself as healthcare. | Terms §4 ("not medical advice") is good. Keep the postpartum gate copy `day1WasNotWrittenForThe`. Coach agreement: coaches warrant their qualifications and must not diagnose. | legal-liability |
| MED-02 | Health advertising: the Supreme Council for Media Regulation's Decision 9/2025 (from 1 Mar 2025) says no ad for a doctor or health service without Ministry of Health approval, no diagnosis or treatment claims, and the licence number must be shown. The Constitution, Art. 18, puts health-related advertising under state supervision. | https://www.tamimi.com/news/what-you-need-to-know-about-egypts-new-advertising-rules/ ; https://practiceguides.chambers.com/practice-guides/advertising-marketing-2025/egypt | Marketing must stay "fitness and wellbeing" and never "treats", "cures" or "medically designed". | Audit the store listing, `site/index.html` and Rahma's social posts. | legal-liability |
| MED-03 | Health claims must be backed by evidence. Paid endorsements must be disclosed ("Paid partnership"; a hashtag alone isn't enough). Before/after images must not mislead. Ads must be in Arabic or include Arabic. | Chambers advertising guide (above) | Coach portfolios, Rahma as the face of the brand. | Marketing checklist. Never present Mahmoud as the coach or Rahma as the data controller (identity rule). | legal-liability |

## F. Women-only service: the Constitution and the discrimination risk

**Constitution articles (text: `egypt-constitution-2019.txt`)**

- **Art. 53 (line 715).** «المواطنون لدى القانون سواء، وهم متساوون فى الحقوق والحريات والواجبات العامة، لا تمييز بينهم بسبب الدين، أو العقيدة، أو **الجنس**… التمييز والحض على الكراهية **جريمة**، يعاقب عليها القانون.»
  - In English: everyone is equal before the law, there is no discrimination by sex, and discrimination is a crime.
  - This is the main risk: a man could argue that being refused membership is discrimination by sex.
- **Penal Code Art. 161 bis.** Any act that discriminates "on account of sex… in violation of equal opportunity or social justice, or disturbing public peace" is punishable by prison and/or a fine of EGP 30,000–50,000.
  - https://www.eipr.org/sites/default/files/reports/pdf/towards_an_equality_and_anti-discrimination_law_in_egypt_criteria_and_guidelines_1.pdf
  - Enforcement is rare: Mada Masr counted 2 verdicts in more than a decade: https://www.madamasr.com/en/2026/04/30/feature/politics/not-a-lack-of-cases-but-a-lack-of-will-just-2-verdicts-in-over-a-decade-of-discrimination-lawsuits/
- **Art. 9 (line 303).** «تلتزم الدولة بتحقيق تكافؤ الفرص بين جميع المواطنين، دون تمييز.»
  - This binds the state. Own Hub's answer is that a men's fitness opportunity is not reduced, because other apps are plentiful.
- **Art. 11 (line 313).** «تكفل الدولة تحقيق المساواة بين المرأة والرجل… وتلتزم الدولة **بحماية المرأة ضد كل أشكال العنف**… كما تلتزم بتوفير الرعاية والحماية للأمومة…»
  - This is the main argument in Own Hub's favour: the service protects women from harassment online and gives postpartum and maternity care.
- **Art. 57 (line 767).** «للحياة الخاصة حرمة، وهى مصونة لا تمس. وللمراسلات… الإلكترونية… حرمة، وسريتها مكفولة…»
  - Privacy is a constitutional right. Women's body, cycle and pregnancy data and their private messages justify a closed space. The same article requires never reading users' messages (community, reviewer calls not recorded).
- **Art. 59 (line 788).** «الحياة الآمنة حق لكل إنسان…»
  - Safety is the stated purpose of the women-only rule.
- **Art. 84 (line 1024).** «ممارسة الرياضة حق للجميع… واتخاذ ما يلزم من تدابير لتشجيع ممارسة الرياضة.»
  - Frame Own Hub as removing a barrier that keeps many Egyptian women from exercising.
- **Art. 18 (line 376).** Everyone has a right to health. Health facilities, products and **«وسائل الدعاية المتعلقة بالصحة»** (health-related advertising) are under state supervision. This ties to MED-02.
- **Art. 31 (line 529).** «أمن الفضاء المعلوماتى جزء أساسى من منظومة الاقتصاد والأمن القومى…»
  - Security duties are real, and the cybercrime law puts them into effect.
- **Art. 80 (line 975).** A child is anyone under 18. This supports the 18+ gate.
- **Art. 92 (line 1084).** Rights inherent to the person cannot be curtailed.
- **Art. 93 (line 1096).** Ratified human-rights treaties have the force of law. That brings in **CEDAW Art. 4(1)**: temporary special measures to speed up de facto equality for women are not discrimination. https://www.ohchr.org/en/instruments-mechanisms/instruments/convention-elimination-all-forms-discrimination-against-women

**How to frame the women-only rule (for counsel to approve)**

- **Purpose:** women's safety from harassment (Art. 11, Art. 59), privacy of body and health data (Art. 57), and access to sport (Art. 84). It is not exclusion for its own sake.
- **Proportionate means:**
  - Sex is read from the ID number, never guessed from the face.
  - Images are never stored.
  - There is a niqab route and a non-camera route with a woman reviewer.
- **No essential service is denied:** men are not deprived of a public service or of equal opportunity, which is the element 161 bis requires.
- **Precedent:** women-only metro cars, taxis and beaches already operate in Egypt. A 2008 suit against women-only metro cars was reportedly dismissed (press report, lawyer to verify): https://www.egyptindependent.com/women-only-will-segregated-transport-system-solve-or-perpetuate-problem/
- **Copy rule:** say "made for women's safety and privacy". Never use language that disparages men.
- **Where to check:** Terms §3, the `weReadYourNationalIdCardThe` string, and the store description.

**Other women-only items**

| ID | Requirement | Source | Applies because… | Severity |
|---|---|---|---|---|
| WOM-01 | Labour Law 14/2025 (in force 1 Sep 2025), Art. 5, bans gender discrimination in hiring, job advertising and terms of work. https://www.loc.gov/item/global-legal-monitor/2025-07-25/egypt-labor-law-updated ; https://eg.andersen.com/wp-content/uploads/2025/05/Translation-of-Labor-law-No.-14-of-2025.pdf | Coaches and reviewers are women only. If they are *employees*, the law is engaged. Terms §12 already calls coaches "independent professionals". | legal-liability. Counsel to decide whether a genuine occupational requirement can be argued: a woman reviewer seeing a woman's face, and female coaches. |
| WOM-02 | Trans and intersex users: sex is read from the civil-status ID digit. That is the only defensible, non-guessing rule, and it matches Terms §3. | Constitution Art. 53; `functions/identity/nid.py` | best-practice |

## G. AI: no training on user data

| ID | Requirement / promise | Source | Check | Severity |
|---|---|---|---|---|
| AI-01 | **The free Gemini API tier uses prompts to improve Google's products, with human review**, and warns against sending personal information. The paid tier does not use prompts for improvement. | https://ai.google.dev/gemini-api/terms | Never ship on a free-tier key. Prefer **Vertex AI in europe-west3**, whose Service Specific Terms carry a "Training Restriction": https://docs.cloud.google.com/vertex-ai/generative-ai/docs/vertex-ai-zero-data-retention . Ask Google for an abuse-logging exception to reach zero data retention. | legal-liability |
| AI-02 | The Gemini API terms ban use "to provide medical advice". | same | The assistant must stay at "pick exercises and recipes from the catalogue". `assistant_wire.dart` returns no numbers and `safety_classifier.dart` escalates. Keep it that way. | rejection (vendor ToS) / legal-liability |
| AI-03 | **What to promise:** "We never use your data to train AI, ours or anyone's. The assistant sees only your question and the catalogue, never your name, number, ID, cycle or health data." | PDPL purpose limitation, Art. 3; Regulations on AI | Already designed: `AssistantRequest` carries no uid (`assistant_provider.dart`, point 3). Add a privacy §3.8 and a consent line before first use. The Gemini call is a new transfer destination, so it needs a TIA. | legal-liability |
| AI-04 | **The vendor contract must say:** (1) Google acts as processor under the Cloud Data Processing Addendum; (2) no training or fine-tuning; (3) prompt logging off, or ZDR; (4) EU processing region; (5) sub-processor list; (6) deletion; (7) breach notice to us fast enough for us to meet the 72-hour deadline. | https://cloud.google.com/terms/data-processing-addendum | Accept the terms in the Cloud console and file evidence with the PDPC transfer licence. | legal-liability |

## H. No trackers before consent

| ID | Finding | Source | Check | Severity |
|---|---|---|---|---|
| TRK-01 | The PDPL bans processing without explicit consent unless the law authorises it (Art. 2). Cybercrime Art. 25 punishes giving personal data to a system for promotion without consent. | Law 151 Art. 2, Art. 6; Law 175 Art. 25 | **Crashlytics is switched on at launch in release builds, before any consent** (`app/lib/app_state/firebase_boot.dart:150`). Its installation ID is personal data and goes to Google systems. Either gate it behind a consent toggle, or have counsel sign off legitimate interest (Art. 6, point 4) and disclose it. It is already disclosed in privacy §3.6. | legal-liability |
| TRK-02 | Analytics: the debug sink is wired only `if (kDebugMode)` (`app/lib/main.dart:43-45`). Release sends nothing. | — | Before any analytics vendor is added: a consent screen, a privacy update, and an update to the "No analytics software" line in privacy §10. | legal-liability if the claim drifts |
| TRK-03 | The website has no cookies and no scripts (footer claim). | — | Keep `site/_headers` CSP strict, and re-check after every site build. | best-practice |

## I. Honest marketing (the policy must match the shipped build)

| ID | Claim | Risk | Check |
|---|---|---|---|
| I-01 | "No access to your … microphone" (privacy §10) | The review is a **video call** through a vendor not yet named. If it runs in-app, the claim is false. | Name the vendor and its region (`site/privacy/index.html:176, 296-299`). Reword §10. |
| I-02 | "Nothing … is kept except a one-way keyed hash" | A keyed hash is still pseudonymous personal data under the PDPL. Review records are kept for 180 days. | The consent copy `ifYourCheckIsApprovedOrRefused` should not imply "no personal data". Counsel to approve wording. |
| I-03 | "Processed in Frankfurt" while the phone number goes to the US | Contradicts the consent screen's "outside Egypt" framing only if the US isn't named. | Privacy §4 and §5 name the US. The phone screen should too (PDPL-06). |
| I-04 | Rahma described as "founder" while Mahmoud is controller and publisher | Must stay consistent everywhere. | Terms §1 and Privacy §1 are consistent now. Keep the two identities separate in the store listing (developer = Mahmoud Reda). |

---

## J. What a licensed Egyptian lawyer must confirm

1. **PDPC licensing status:**
   - Whether an individual controller can obtain the needed sensitive-data and cross-border permits, or whether a company (with a registered DPO) must be formed first.
   - Which filings must be made before 31 Oct / 1 Nov 2026.
   - What to do if the portal is still not live.
2. **Whether in-memory biometric matching with no storage still needs a sensitive-data licence.** It almost certainly counts as "processing".
3. **Lawful basis and consent wording for the US transfer of the phone number** (Firebase Auth), and whether consent on C06 is enough under Art. 15.
4. **The Executive Regulations' exact article numbers** and the official reply deadline for data-subject requests (reported as 6 working days). Also the fee policy.
5. **Whether "obtain a copy" (Art. 2) requires a machine-readable export,** or whether a copy sent by email is enough.
6. **Retention periods:**
   - 180 days for verification and review records.
   - Waitlist deletion vs. Art. 18's 3-year rule for marketing consent records.
   - Keeping the ID hash after account deletion.
   - Whether the 180-day cybercrime log-retention rule applies to Own Hub.
7. **Women-only rule:**
   - The Art. 53 / Penal Code 161 bis risk assessment.
   - The approved framing text in Arabic and English.
   - Whether contracting only women coaches and reviewers is lawful under Labour Law 14/2025, or is safe through independent-contractor status.
8. **Consumer law Art. 5:**
   - Whether a free app published by an unregistered individual must show a commercial or activity registration.
   - An Arabic-prevails clause.
   - Whether Terms §13's liability limits survive Art. 28.
9. **Click-wrap design and evidence record for the Terms** under Law 15/2004.
10. **Crashlytics:** whether it may run before consent on a legitimate-interest basis.
11. **Health and fitness positioning:**
    - That coach postpartum and pregnancy programmes and Rahma's marketing do not trigger Ministry of Health ad approval (SCMR Decision 9/2025).
    - That they do not fall under Law 13/2025.
12. **AI vendor terms:** Vertex AI vs. Gemini API, the Data Processing Addendum, training restriction, ZDR, and PDPC transfer licence coverage.
13. **Governing court** for Terms §15 (currently "[to be completed]"). The Economic Courts may have jurisdiction for consumer, data-protection and cybercrime matters.

**Fix in code now, before counsel:**
- Fill in `app/lib/config/legal_links.dart`, which has four empty URLs. That is a store rejection.
- Add Terms and Privacy links, a US-transfer line and a recorded acceptance on C06.
- Gate Crashlytics on consent, or get it signed off.
- Name the video-call vendor and fix privacy §10's microphone line.
- Fill in the data-request reply window.
- Write the breach runbook.

None of these changes have been made.