# Own Hub legal facts: verified values for config.json and the [LAWYER] markers

I read the config, both page builders, the two earlier checklists and the Constitution file. I checked the code. I also read the live Google Cloud project `own-hub`, read-only through gcloud. Nothing was edited.

**Primary sources used**
- **Law 151/2020 (PDPL):** the full English text, cross-checked against the Sharkawy dual Arabic/English text.
- **Executive Regulations:** Ministerial Decree 816/2025, Official Gazette Issue 244 (Supplement A), 1 Nov 2025, in force 2 Nov 2025, English translation. I cite them as "ER" below.
- **Other Egyptian laws:** Consumer Protection Law 181/2018 (CPL), Cybercrime Law 175/2018 and E-Signature Law 15/2004, all as text.
- **Civil Code:** arts 44, 90, 111, 112, 172 and 217.
- **Procedure and courts:** Procedure Code art 62 and Economic Courts Law 120/2008 art 6.
- **PDPC:** its own portal bundle (contact details).
- **Google:** Firebase privacy page, Cloud Logging quotas, Cloud data deletion, Vision data-usage and OCR pages, and the GCP Service Specific Terms.
- **Stores:** Apple's account-deletion page and minimum EULA terms, and Google Play's account-deletion page.

## 0. Findings that change the copy (read first)

1. **Response window is verified.** PDPL **Art. 32**: "The recipient of the request must respond within six (6) working days from the date of submission." The pages' "PDPL Art. 2" pointer is wrong: Art. 2 lists the rights, and Art. 32 sets the deadline.
2. **An individual can only hold a *permit*, never a *licence*.** Art. 1 defines a licence as issued "to a legal entity" for 3 years, and a permit as issued "to a natural or legal person" for up to 1 year, renewable. ER Art. 22, 25, 37 and 38 set out the permit route for natural persons.
3. **The publisher is his own DPO once he holds a permit.** ER Art. 38: "the Permit holder shall be responsible for implementing the provisions of the Law and acting as the Data Protection Officer." Law Art. 8: a natural-person controller is "personally responsible".
4. **No published PDPC postal address.** The PDPC's own portal (portal.pdpc.gov.eg) lists email **info@pdpc.gov.eg** and hotline **17372**, under "Contact Us / Make a complaint".
5. **Crashlytics and App Check are not US-only.** Firebase lists them, along with Firestore, Functions, Storage and Firebase ML, as "global Google infrastructure… could process data at any of the Google Cloud Platform locations". Only Firebase Authentication "processes data exclusively in the United States". The privacy card that says Crashlytics "Where: United States" is wrong.
6. **What the live project shows:**
   - The `_Default` log bucket keeps logs **30 days**. `_Required` keeps 400 days and holds admin audit logs.
   - Both Firestore databases and all 7 deployed functions are in **europe-west3**.
   - Personal media go to bucket `own-hub-personal` in **EUROPE-WEST3**. The default bucket is **US-EAST1** and, per `firebase_boot.dart:248`, holds only the content library.
7. **Live deployment does not yet match the pages.** Each of these needs to be live before the effective date:
   - **No TTL policies are on.** `gcloud firestore fields ttls list` returns 0 items for both `(default)` and `proddb`. Every "deleted automatically after N days" promise is untrue until `firebase/ops/ttl-policies.sh` is run.
   - **`join_waitlist` is not deployed.** The configured endpoint returns 404.
   - **Other functions not deployed:** `delete_account`, `resume_account_deletions`, `record_legal_acceptance`, `record_health_consent`, `request_review` and `get_review_contact`.
8. **AI:** confirmed off. `Feature.assistant: false` (`app/lib/domain/flags/feature_flags.dart:220`). `assistant_provider.dart` ships only `UnavailableAssistantProvider`, and there is no AI SDK in `pubspec.yaml`. The only Google AI-type services that receive data are Cloud Vision OCR (EU endpoint, `config.py:55`) and the on-device ML Kit telemetry.
9. **Crashlytics is correctly consent-gated.** It is off natively in `Info.plist` and `AndroidManifest`, and `crashCollectionFor(release && allowed)` is in `firebase_boot.dart:109-178`. The earlier checklist item TRK-01 is now fixed.

## 1. config.json fields

Confidence key:
- **V** means verified against a primary source.
- **D** means derived from verified law or code, as a policy choice.
- **O** means owner-only. I give neutral wording to print until filled, never a "lawyer" marker.

| key | Value EN | Value AR | Source | Conf. |
|---|---|---|---|---|
| effectiveDate / effectiveDateAr | keep `24 September 2026` / `24 سبتمبر 2026` | as is | owner | O |
| lastUpdated / lastUpdatedAr | leave empty until a published page is revised | — | — | O |
| brandFounder | Rahma Mohsen | رحمة محسن | owner | O (correct) |
| legalEntity | Mahmoud Reda | محمود رضا | PDPL Art. 1 ("Controller: any natural or legal person…") and Art. 8 | V |
| legalAddress | Keep `Egypt` / `مصر` only until a postal address exists. See section 3, item 4: an address is required by CPL Art. 5, Cybercrime Law Art. 2 (Second) and Apple minimum term 8. Owner to supply a correspondence address, for example an Egypt Post P.O. box, not a home address. | — | CPL 181/2018 Art. 5; Law 175/2018 Art. 2; apple.com/legal/macapps/minterms | O (risky as is) |
| contactPrivacy / contactSupport | mahmoud.reda.acc@gmail.com | — | owner | O |
| commercialRegistration | leave empty: an individual with no commercial register entry has nothing to print | — | CPL Art. 5 requires "registration in the relevant activity register" only where one exists | D |
| dataProtectionOfficer | `Mahmoud Reda acts as data protection officer himself, as the law requires of an individual who holds a permit. Contact: mahmoud.reda.acc@gmail.com` | `يتولى محمود رضا بنفسه مهام مسؤول حماية البيانات، كما يقتضي القانون من الشخص الطبيعي الحاصل على تصريح. للتواصل: mahmoud.reda.acc@gmail.com` | ER Art. 38; Law Art. 8 | V (true once the permit is issued) |
| pdpcContact | `Website portal.pdpc.gov.eg · email info@pdpc.gov.eg · hotline 17372.` | `الموقع portal.pdpc.gov.eg · البريد الإلكتروني info@pdpc.gov.eg · الخط الساخن 17372.` | PDPC portal bundle (`footer.contactPopup.methods`: info@pdpc.gov.eg, 17372); Law Art. 33 (complaints decided within 30 working days) | V |
| pdpcPermit | **O.** Until issued: `Not yet issued. We will publish the permit number and its expiry date here as soon as the Personal Data Protection Centre issues it.` Once issued: `Permit no. [number], valid until [date]` (maximum 1 year, renewable). | `لم يصدر بعد. سننشر رقم التصريح وتاريخ انتهائه هنا فور إصداره من مركز حماية البيانات الشخصية.` / `تصريح رقم [الرقم]، ساري حتى [التاريخ]` | Law Art. 1, 4, 12, 14; ER Art. 20, 38 | O |
| courtVenue | `the competent courts in Cairo, including the Cairo Economic Court for the matters the law assigns to it. This does not take away your right to bring a claim before any other Egyptian court the law allows you to use` | `المحاكم المختصة في القاهرة، ومنها المحكمة الاقتصادية بالقاهرة في المسائل التي يُسندها إليها القانون. ولا يمس ذلك حقك في رفع دعواك أمام أي محكمة مصرية أخرى يتيحها لك القانون` | Procedure Code art. 62; Economic Courts Law 120/2008 art. 6 (lists the consumer, telecom and e-signature laws); CPL issuance Art. 2; PDPL issuance Art. 5 | D |
| liabilityCap | **Recommended: remove the bullet that uses this token** (see marker 24). If the token must stay: `the amount of damage Egyptian law obliges us to make good. Because Own Hub is free, we set no other cap` | `مقدار الضرر الذي يُلزمنا القانون المصري بجبره. ولأن Own Hub مجاني، فلا نضع أي حد آخر` | Civil Code art. 217(2)-(3); CPL Art. 28 | D |
| minimumAge | `18` | `18` | Constitution art. 80 (child = under 18); ER Art. 15 (under-18 data needs a guardian's consent); `MIN_AGE = 18` (`config.py:120`). For the 18 to 20 point, see marker 22. | V |
| rightsResponseWindow | `6 working days` | `ستة أيام عمل` | PDPL Art. 32 | V |
| transferCountries | `Germany and the European Union: Google Cloud in Frankfurt (europe-west3) and the Cloud Vision EU endpoint, where Google stores and processes data only in the EU. The United States: Firebase Authentication, which Google runs only from US data centres. Google data centres worldwide, which include the United States: Firebase App Check, Google ML Kit performance data, and Firebase Crashlytics if you allow it. Google does not let us choose one country for these. Each transfer needs your consent, which we ask for before it happens, and our transfer permit from the Personal Data Protection Centre. Google acts only on our instructions under its data processing terms, encrypts the data in transit and at rest, and may not use it to train AI models. The Centre has not yet published a list of countries it considers adequate.` | `ألمانيا والاتحاد الأوروبي: خدمات Google Cloud في فرانكفورت (europe-west3)، ونقطة الاتصال الأوروبية لخدمة Cloud Vision، حيث تخزّن Google البيانات وتعالجها داخل الاتحاد الأوروبي فقط. الولايات المتحدة: خدمة Firebase Authentication، التي تشغّلها Google من مراكز بيانات أمريكية فقط. مراكز بيانات Google حول العالم، ومنها الولايات المتحدة: Firebase App Check، وبيانات الأداء الخاصة بـ Google ML Kit، وFirebase Crashlytics إن سمحتِ بها، ولا تتيح Google اختيار دولة واحدة لهذه الخدمات. لا يتم أي نقل إلا بموافقتك التي نطلبها قبل حدوثه، وبموجب تصريح النقل الصادر لنا من مركز حماية البيانات الشخصية. وتعالج Google البيانات وفق تعليماتنا فقط بموجب شروط معالجة البيانات لديها، وتشفّرها أثناء النقل والتخزين، ولا يجوز لها استخدامها لتدريب نماذج الذكاء الاصطناعي. ولم يصدر المركز بعد قائمة بالدول التي يعدّها توفر مستوى حماية كافيًا.` | PDPL Art. 14 and 15; ER Art. 16; firebase.google.com/support/privacy; Vision OCR page; GCP Service Terms §18; legal-firm reports of no PDPC adequacy list as of Sept 2026 | V/D |
| providerAuth / Region (unused token) | Google Firebase Authentication · United States | Google Firebase Authentication · الولايات المتحدة | Firebase privacy page | V |
| providerDatabase / Region (unused) | Google Cloud Firestore and Cloud Storage · Frankfurt, Germany (europe-west3) | Google Cloud Firestore وCloud Storage · فرانكفورت، ألمانيا (europe-west3) | live gcloud | V |
| providerIdentity / Region (unused) | Our own server on Google Cloud Functions, with Google Cloud Vision for reading the card · Germany and the EU. Images are never stored, and are not processed in Egypt. | خادمنا الخاص على Google Cloud Functions، مع Google Cloud Vision لقراءة البطاقة · ألمانيا والاتحاد الأوروبي. لا تُخزَّن الصور، ولا تُعالَج داخل مصر. | code plus gcloud | V |
| providerPayment (unused) | leave empty: there are no payments | — | Terms §9 | V |
| retentionCoachMessages fallback | `Nothing is kept, because there is no coaching and no messaging in this version. A period will be set and published before coaching exists.` | `لا يُحتفظ بشيء، إذ لا يوجد تدريب شخصي ولا مراسلة في هذا الإصدار. وستُحدَّد المدة وتُنشر قبل إطلاق التدريب الشخصي.` | removes the "counsel" wording | D |
| retentionSafetyReports fallback | `There are no safety reports in this version, because there is no community. A period will be set and published before the community opens.` | `لا توجد بلاغات سلامة في هذا الإصدار، إذ لا يوجد مجتمع. وستُحدَّد المدة وتُنشر قبل افتتاح المجتمع.` | same | D |
| retentionPaymentRecords fallback | keep the current text (it does not mention counsel) | keep | — | — |
| waitlistEndpoint | value is correct (europe-west3), but it **returns 404 today**: deploy `join_waitlist` | — | curl | V |
| storeUrlIos / storeUrlAndroid | empty until live | — | — | O |
| policyEffectiveDate | **O.** It must not be earlier than the day the PDPC permit is issued and the v3 build is live. Neutral wording until then: `the day this version of the app is released` | `يوم إصدار هذا الإصدار من التطبيق` | PDPL issuance Art. 6 (grace period ends 1 Nov 2026) | O |
| hostingProvider / Region | **O.** Neutral wording: `our website host` / `the host's servers, which may be outside Egypt` | `مزوّد استضافة موقعنا` / `خوادم المزوّد، وقد تكون خارج مصر` | `site/_headers` points to Cloudflare Pages or Netlify; the owner confirms | O |
| chatService / Region | **O.** Neutral wording: `a team chat service` / `the chat service's servers, which may be outside Egypt`. Or drop the alert (`FLAG_WEBHOOK_REQUIRED = True` today, `config.py:657`) | `خدمة محادثة للفريق` / `خوادم خدمة المحادثة، وقد تكون خارج مصر` | — | O |
| emailProvider / Region | `Google (Gmail)` / `Google data centres worldwide, which include the United States`. The address is @gmail.com, so this is determinable. **But see section 3, item 7.** | `Google (Gmail)` / `مراكز بيانات Google حول العالم، ومنها الولايات المتحدة` | the contact value itself | D |
| deletionVerifyMethod | `a one-time code we send by SMS to that number, which you send back to us` | `رمز يُستخدم مرة واحدة نرسله برسالة نصية إلى ذلك الرقم، وتعيدينه إلينا` | Apple account-deletion page: "entering a code from an email or phone number already associated with the account" is allowed; matches the delete page's existing wording | V |
| deletionWindow | `6 working days of your request` | `ستة أيام عمل من تاريخ طلبك` | PDPL Art. 32 | V |
| supportRetention | `1 year` (both uses read correctly: "deleted 1 year after the conversation ends" and the table row) | `سنة واحدة` | No law sets this. PDPL Art. 3 and ER Art. 2 require a period tied to the purpose. A rights request is kept separately as the deletion record. | D |
| deletionRecordRetention | `3 years` | `ثلاث سنوات` | Civil Code art. 172 (3-year limitation for damage claims); ER Art. 3 and 14 (keep records of erasure requests and their execution). Matches the waitlist proof period. | D |
| serverLogRetention | `30 days` (the live `_Default` bucket setting) | `30 يومًا` | gcloud; docs.cloud.google.com/logging/quotas ("_Default bucket has a 30 day default retention period"). **See section 3, item 8 on Law 175/2018.** | V |
| crashReportRetention | `90 days, after which Google starts removing them from its live and backup systems` | `90 يومًا، تبدأ Google بعدها حذفها من أنظمتها الحية والاحتياطية` | firebase.google.com/support/privacy | V |
| exportDelivery | `by email to the address you wrote from, as a password-protected file. We send the password separately, by SMS to the number on the account` | `بالبريد الإلكتروني إلى العنوان الذي راسلتِنا منه، في ملف محمي بكلمة مرور، ونرسل كلمة المرور منفصلة برسالة نصية إلى الرقم المسجّل في الحساب` | Code: "Ask for a copy" is a mailto to the privacy box (`app_router.dart:5235`), and nothing writes `user-exports`. So delivery is manual. The owner must be able to send the SMS. | D |

Google backups line in privacy §6: replace "Removed within Google's own deletion period" with **"Removed within about 6 months (180 days) of deletion"** / **"تُحذف خلال نحو ستة أشهر (180 يومًا) من الحذف"**. Sources: docs.cloud.google.com/docs/security/deletion ("within a maximum period of about six months (180 days)") and the Firebase Auth line ("removed from live and backup systems within 180 days").

## 2. The [LAWYER] markers (28 occurrences, 23 distinct texts)

For every marker: **delete the HTML comment** in both `pages_en.py` and `pages_ar.py`. Make the visible change shown, or none if "keep" is written. Do not ship source comments: put the citations in a local file instead (your no-AI-signs rule).

1. **Privacy §1, "confirm the controller"** (EN:278, AR:269)
   - Keep the text, and add: "He is personally responsible for complying with the law."
   - AR: "وهو مسؤول شخصيًا عن الالتزام بالقانون."
   - Source: PDPL Art. 1 and 8.
2. **Privacy §1, "full postal address… CPL Art. 5"** (EN:280, AR:271)
   - No research answers this; it is an owner fact. No exemption for a free or individual supplier was found in CPL Art. 5. See section 3, item 4.
3. **"confirm that the Arabic version prevails"**: privacy top (EN:308, AR:299), privacy §13 (EN:807, AR:757), terms top (EN:857, AR:806)
   - Keep the text. CPL Art. 5 requires contracts, "including digital and electronic documents", in Arabic, and allows "more than one language, provided Arabic is included".
4. **Privacy §2, "women-only framing"** (EN:355, AR:344). Replace the first paragraph with:
   - EN: "Own Hub is for women aged 18 or over who hold an Egyptian national ID card. It is a women-only space for one reason: so that women in Egypt can train, follow their bodies and their cycles, and look after their health somewhere they feel safe and their privacy is protected. This reflects the Constitution's protection of women, of private life, of health and of everyone's right to sport (Articles 11, 18, 57, 59 and 84). It is not a judgement about anyone else."
   - AR: "Own Hub مخصّص للنساء اللواتي بلغن 18 عامًا فأكثر ويحملن بطاقة رقم قومي مصرية. وهو مساحة للنساء فقط لسبب واحد: أن تتمكّن المرأة في مصر من التمرّن ومتابعة جسدها ودورتها الشهرية والعناية بصحتها في مكان تشعر فيه بالأمان وتُصان فيه خصوصيتها. ويعكس ذلك ما كفله الدستور من حماية المرأة وحرمة الحياة الخاصة والحق في الصحة وحق الجميع في ممارسة الرياضة (المواد 11 و18 و57 و59 و84). وليس في ذلك حكم على أحد."
   - Source: Constitution arts 11, 18, 57, 59, 84 (local file, lines 313-324, 376, 767, 788, 1024). See section 3, item 1 for the criminal-law risk.
5. **Privacy §3, "confirm each legal basis"** (EN:363, AR:352). Add one line under the §3 heading:
   - EN: "Each basis below is one that Egypt's Personal Data Protection Law allows (Law 151/2020, Articles 2, 6 and 12)."
   - AR: "كل أساس قانوني أدناه من الأسس التي يجيزها قانون حماية البيانات الشخصية المصري (القانون 151 لسنة 2020، المواد 2 و6 و12)."
   - Mapping: §3.1 and §3.5 contract, Art. 6(2). §3.2 legal obligation, Art. 6(3). §3.3 and §3.6 written explicit consent, Art. 12. §3.4 and §3.10 consent, Art. 2. §3.7 legitimate rights, Art. 6(4). §3.9 contract or legitimate rights.
6. **Privacy §3.2, "confirm this basis"** (EN:389, AR:374). Replace the basis bullet:
   - EN: "Basis: a legal obligation. The Executive Regulations of the Personal Data Protection Law require us to keep a record of each consent, with its date and form."
   - AR: "الأساس: التزام قانوني، إذ تُلزمنا اللائحة التنفيذية لقانون حماية البيانات الشخصية بالاحتفاظ بسجل لكل موافقة وتاريخها وشكلها."
   - Source: ER Art. 2 (Second, 3); PDPL Art. 6(3).
7. **Privacy §3.3, "sensitive-data licence"** (EN:430, AR:409).
   - Change "Basis: your explicit consent" to "your explicit consent, given in writing on the screen". AR: "موافقتك الصريحة المكتوبة على الشاشة".
   - Add: "Because a face match is sensitive data, the law also requires a permit from the Personal Data Protection Centre. Ours is shown in section 1."
   - AR: "ولأن مطابقة الوجه من البيانات الحساسة، يشترط القانون أيضًا تصريحًا من مركز حماية البيانات الشخصية، وتجدين بياناته في القسم 1."
   - Source: PDPL Art. 1 and 12; ER Art. 14(1)-(2), where electronic written consent is accepted.
8. **Privacy §3.6, "confirm this basis"** (EN:492, AR:466). Basis becomes:
   - EN: "your explicit consent, given in writing in the app, which the law requires for health data, and our permit from the Centre (section 1)."
   - AR: "موافقتك الصريحة المكتوبة داخل التطبيق، وهي ما يشترطه القانون للبيانات الصحية، إضافة إلى تصريحنا من المركز (القسم 1)."
   - Source: Art. 12; ER Art. 14.
9. **Privacy §3.7, "App Check and ML Kit before sign-up"** (EN:525, AR:494). Basis bullet becomes:
   - EN: "Basis: keeping the service secure and working, which the law allows (Law 151/2020, Article 6, point 4), except crash reports, which need your consent. ML Kit runs only on the selfie screen, after you have agreed to the check."
   - AR: "الأساس: الحفاظ على أمان الخدمة وعملها، وهو ما يجيزه القانون (القانون 151 لسنة 2020، المادة 6، البند 4)، باستثناء تقارير الأعطال التي تتطلب موافقتك. ولا يعمل ML Kit إلا في شاشة الصورة الذاتية، بعد موافقتك على التحقق."
   - Verified: the FaceDetector is created lazily in `camera_capture_service.dart:263`. But see section 3, item 3: App Check's data leaves Egypt before any consent.
10. **Privacy §3.8, "no-training term"** (EN:541, AR:508). Keep the text. It is verified:
    - GCP Service Specific Terms §18 "Training Restriction": "Google will not use Customer Data to train or fine-tune any AI/ML models without Customer's prior permission or instruction."
    - Vision data-usage page: online requests are "processed in memory and not persisted to disk", and "Google does not use the content you send to train and improve our Cloud Vision features".
    - Optional sharper line: "Google Cloud Vision reads the card in memory and does not keep the image." AR: "تقرأ Google Cloud Vision البطاقة في الذاكرة ولا تحتفظ بالصورة."
11. **Privacy §3.10, "three-year proof of consent"** (EN:567, AR:531). Change "for 3 years" to:
    - EN: "for 3 years after the last message we send you"
    - AR: "لمدة ثلاث سنوات من تاريخ آخر رسالة نرسلها إليك"
    - Source: PDPL Art. 18 ("three (3) years from the date of the last message sent"). The code sets `expireAt` 3 years from *joining* (`waitlist/join.py:288`), so it needs a fix. See section 3, item 5.
12. **Privacy §4, "processor agreements"** (EN:578, AR:542). Keep the text, and add:
    - EN: "Google processes data for us under the Google Cloud Data Processing Addendum and the Firebase Data Processing and Security Terms."
    - AR: "وتعالج Google البيانات لحسابنا بموجب ملحق معالجة البيانات في Google Cloud وشروط معالجة البيانات وأمنها في Firebase."
    - Source: PDPL Art. 4 and 5 (a processor acts "under a formal agreement"); the Firebase privacy page. The owner must accept both in the consoles.
13. **Privacy §4 cards, "the countries"**: App Check card (EN:600, AR:564) and ML Kit card (EN:604, AR:568). Set "Where" on both cards, and on the **Crashlytics card** (replacing "United States"), to:
    - EN: "Google data centres worldwide, which include the United States." For the App Check card add "Apple servers for App Attest."
    - AR: "مراكز بيانات Google حول العالم، ومنها الولايات المتحدة" (with "وخوادم Apple لخدمة App Attest" on the App Check card).
    - Source: Firebase privacy page global list. Apple publishes no location (derived).
14. **Privacy §4, "disclosure and transfer wording"** (EN:628, AR:590). Replace the last sentence with:
    - EN: "If Own Hub is ever transferred to another publisher, we will tell you in the app before it happens, ask for your consent where the law requires it, and the new publisher will need its own permit from the Personal Data Protection Centre."
    - AR: "وإذا انتقل Own Hub يومًا إلى ناشر آخر، فسنخبرك في التطبيق قبل حدوث ذلك، ونطلب موافقتك حيث يشترط القانون ذلك، وسيحتاج الناشر الجديد إلى تصريح خاص به من مركز حماية البيانات الشخصية."
    - The first sentence is verified (Art. 6(3): "pursuant to an order from competent investigative authorities or a judicial ruling").
    - Source: Art. 29 (a permit cannot be assigned without the Centre's approval).
15. **Privacy §6, "every period in this table"** (EN:676, AR:635)
    - The 180-day, 1-year, 5-minute and 3-year periods match the code (`config.py:554-574`, `join.py:88-91`, `CHALLENGE_TTL_SEC=300`). The law sets no fixed number. It requires a period tied to the purpose, and erasure or de-identification once the purpose ends (PDPL Art. 3, Art. 4; ER Art. 3 First 4). Keep them, but they are only true once TTLs are enabled (section 3, item 6).
    - **The closed ID code** is kept indefinitely today, which is the one period that does not meet "not longer than necessary". Recommended replacement:
      - EN: "The keyed code of your ID number: while your account exists. After you delete your account it is closed for 3 years, linked to no account, so that one card cannot hold two accounts at once or return straight after being closed for misuse. If you deleted your account yourself, you may join again with the same card."
      - AR: "الرمز المشفّر لرقمك القومي: طوال وجود حسابك. وبعد حذف حسابك يُغلق لمدة ثلاث سنوات دون ربطه بأي حساب، كي لا تفتح بطاقة واحدة حسابين معًا أو تعود فورًا بعد إغلاق حساب بسبب إساءة الاستخدام. وإن حذفتِ حسابك بنفسك، يمكنك الانضمام مجددًا بالبطاقة نفسها."
      - This needs a code change: today the closed code blocks rejoin (delete page, "What is kept"). If the owner keeps the current behaviour, the page must say "indefinitely" and "you cannot rejoin with the same card". That is the riskier option under Art. 3.
    - Update the delete page's "a question we have put to counsel" sentence to the same answer.
16. **Privacy §8, "response window and delivery method, PDPL Art. 2"** (EN:741, AR:696). Fill with `rightsResponseWindow` and `exportDelivery` above. Source: Art. 32.
17. **Privacy §9, "breach timings, administrator access"** (EN:765, AR:717)
    - The timings are verified: PDPL Art. 7 and ER Art. 5 (72 hours to the Centre; tell her "within three (3) business days from the date of reporting… by SMS, email, or phone call").
    - Change the end to "…tell you within three working days after that, by SMS or email." AR: "…ونخبرك خلال ثلاثة أيام عمل بعد ذلك، برسالة نصية أو بريد إلكتروني."
    - Add the access line. EN: "The publisher, who runs Own Hub's systems, can technically reach stored data. He opens an individual account's data only to answer your request, to fix a fault, to investigate misuse, or when the law requires it."
    - AR: "يستطيع الناشر، بصفته من يدير أنظمة Own Hub، الوصول تقنيًا إلى البيانات المخزّنة. ولا يطّلع على بيانات حساب بعينه إلا للرد على طلبك، أو لإصلاح عطل، أو للتحقيق في إساءة استخدام، أو حين يقتضي القانون ذلك."
18. **Terms §1, "publisher's address and registration; click-wrap under Law 15/2004"** (EN:874, AR:822)
    - The acceptance text is sound. Civil Code art. 90 says will may be expressed "by taking a position that leaves no doubt", so a tap is valid acceptance. Law 15/2004 Art. 15 and 18 give electronic writing full evidential weight when it is attributable and tamper-evident.
    - Add: "We keep this record securely, so it can show what you accepted and when." AR: "ونحفظ هذا السجل بشكل آمن ليُثبت ما وافقتِ عليه ومتى."
    - The address is an owner fact (section 3, item 4). `record_legal_acceptance` must be deployed (section 0, item 7).
19. **Terms §3, "women-only framing" plus [OWNER] review routes** (EN:909, AR:854)
    - Replace the first bullet with the §2 wording from marker 4.
    - Add a capacity bullet. EN: "If you are 18, 19 or 20: Egyptian civil law gives full contractual capacity at 21. Own Hub is free and asks nothing of you in money, and nothing in these Terms takes away any right the law gives you because of your age."
    - AR: "إن كان عمرك 18 أو 19 أو 20 عامًا: يمنح القانون المدني المصري الأهلية الكاملة للتعاقد عند 21 عامًا. وOwn Hub مجاني لا يطلب منك أي مال، ولا شيء في هذه الشروط ينتقص من أي حق يمنحك إياه القانون بسبب سنّك."
    - Source: Civil Code art. 44 (majority is 21); art. 111 (a discerning minor's acts "between benefit and harm are voidable in the minor's interest", so they are voidable at her option, not void). The 18 minimum stays because PDPL consent is valid from 18 (ER Art. 15) and the Constitution (art. 80) sets childhood at under 18. The [OWNER] review-routes item stays with the owner.
20. **Terms §10, "suspension wording"** (EN:982, AR:925). Replace the second bullet:
    - EN: "We may suspend or close an account that breaks section 3 or section 7. Before we do, we tell you why and give you a chance to reply, unless the law, an order from an authority or someone's safety prevents it. You keep your right to a copy of your data."
    - AR: "يجوز لنا تعليق أو إغلاق حساب يخالف القسم 3 أو القسم 7. وقبل ذلك نخبرك بالسبب ونمنحك فرصة للرد، ما لم يمنع ذلك القانون أو أمر من جهة مختصة أو سلامة أحد. ويبقى حقك في الحصول على نسخة من بياناتك قائمًا."
    - Source: PDPL Art. 2 (rights survive).
21. **Terms §13, "survives CPL Art. 28"** (EN:997, AR:938). Replace the bullets:
    - EN:
      - "We are not responsible for injury, illness or loss that results from exercise you chose to do, food you chose to eat, or following general guidance in the app instead of seeing a doctor."
      - "Because Own Hub is free, we are responsible for harm caused by our fraud or gross negligence, and for anything else Egyptian law makes us responsible for whatever these Terms say."
      - "Nothing in these Terms limits our responsibility for fraud, gross negligence or harm caused outside this agreement, or reduces any right you have under the Consumer Protection Law."
    - AR:
      - "لا نتحمّل المسؤولية عن إصابة أو مرض أو خسارة تنتج عن تمرين اخترتِ أداءه، أو طعام اخترتِ تناوله، أو اتّباع إرشادات عامة في التطبيق بدلًا من مراجعة الطبيب."
      - "ولأن Own Hub مجاني، فنحن مسؤولون عن الضرر الناتج عن غشّنا أو خطئنا الجسيم، وعن أي أمر آخر يُحمّلنا القانون المصري مسؤوليته أيًا كان ما تنص عليه هذه الشروط."
      - "لا شيء في هذه الشروط يحدّ من مسؤوليتنا عن الغش أو الخطأ الجسيم أو الضرر الناشئ خارج هذا الاتفاق، أو ينتقص من أي حق لك بموجب قانون حماية المستهلك."
    - **Delete** the "limited to {{liabilityCap}}" and "indirect or consequential loss" bullets. Civil Code art. 217 voids any exemption for fraud, gross fault and tort ("يقع باطلًا كل شرط يقضي بالإعفاء من المسئولية المترتبة على العمل غير المشروع"). CPL Art. 28 voids any clause that "reduces or exempts the supplier from legal obligations". A cap "where liability cannot be excluded" contradicts both.
22. **Terms §15, "competent court, Arabic prevails"** (EN:1030, AR:968)
    - Fill `courtVenue`. Arabic-prevails is verified (marker 3).
    - Change "Own Hub is offered in Egypt only." to "Own Hub is made for, and offered in, Egypt." AR: "صُمّم Own Hub لمصر ويُتاح فيها." This keeps it true if a store listing is not geo-restricted (owner to confirm).
23. **Terms §16, "Apple's minimum terms"** (EN:1033, AR:971). Add the missing terms:
    - EN:
      - "You get a personal, non-transferable licence to use the app on Apple devices you own or control, as the App Store's Usage Rules allow."
      - "The publisher, not Apple, is responsible for investigating, defending, settling and discharging any claim that the app infringes someone's intellectual property, and for any product liability, legal or regulatory, consumer protection or privacy claim."
      - "Questions, complaints or claims about the app go to the publisher: {{legalEntity}}, {{legalAddress}}, {{mailto:contactSupport}}."
      - "You must follow any third-party terms that apply when you use the app, for example your mobile operator's."
    - AR:
      - "تحصلين على ترخيص شخصي غير قابل للنقل لاستخدام التطبيق على أجهزة Apple التي تملكينها أو تتحكمين فيها، وفق قواعد الاستخدام في App Store."
      - "الناشر، لا Apple، هو المسؤول عن التحقيق في أي ادعاء بأن التطبيق يمس حقوق ملكية فكرية للغير والدفاع عنه وتسويته، وعن أي مطالبة تتعلق بمسؤولية المنتج أو المتطلبات القانونية والتنظيمية أو حماية المستهلك أو الخصوصية."
      - "تُوجَّه الأسئلة والشكاوى والمطالبات المتعلقة بالتطبيق إلى الناشر: {{legalEntity}}، {{legalAddress}}، {{mailto:contactSupport}}."
      - "عليك الالتزام بشروط أي طرف ثالث تنطبق عند استخدام التطبيق، مثل شروط شركة الاتصالات."
    - Source: apple.com/legal/macapps/minterms, items 2, 5, 6, 8 and 9. Item 8 requires a name **and address**.
24. **Terms §17, "transfer clause"** (EN:1067, AR:1000). Replace the last bullet:
    - EN: "You may not transfer your rights under these Terms. We may transfer ours only together with Own Hub, after telling you in the app, and only to a publisher that holds its own permit from the Personal Data Protection Centre."
    - AR: "لا يجوز لك نقل حقوقك بموجب هذه الشروط. ولا يجوز لنا نقل حقوقنا إلا مع Own Hub نفسه، بعد إخبارك في التطبيق، وإلى ناشر حاصل على تصريح خاص به من مركز حماية البيانات الشخصية."
    - Source: PDPL Art. 29.

## 3. Statements that are wrong or risky today, with corrections

1. **The women-only rule has real criminal exposure (Penal Code 161 bis).**
   - The article punishes sex-based discrimination that wastes "equal opportunity" with prison and/or EGP 30,000 to 50,000.
   - In 2026 a Port Said appeal court reversed an acquittal and gave a hotel manager **1 year and EGP 50,000**. The hotel had refused a lone woman, and the court rejected its "safety" justification (EIPR, April 2026).
   - The wording in markers 4 and 19 frames the rule on safety, privacy and the Constitution's protections for women. It never disparages anyone and claims no general right to exclude. It does not remove the risk. This is the top item for the reviewing lawyer.
2. **Crashlytics "United States", and privacy §5 placing device checks, ML Kit and crash data in "The United States".**
   - Firebase lists these as global. Use the marker 13 wording, and restructure §5 as in `transferCountries`.
   - ER Art. 16(4) only allows transfers "to the country or countries specified in the License or Permit". The permit application must name the US plus Google's global locations, or these SDKs must go.
3. **App Check sends data abroad before any consent.**
   - App Check runs at first launch (`firebase_boot.dart` activates it straight after `initializeApp`) and sends an installation identifier to Google's global infrastructure.
   - ER Art. 16 First (2) requires consent for every cross-border transfer. Fix: show the transfer consent on a first-run screen before App Check activates, or activate App Check only after the sign-up consent.
4. **"Address: Egypt" is not enough.**
   - CPL Art. 5 requires the supplier's address on electronic contracts.
   - Cybercrime Law Art. 2 (Second) requires service providers to publish a name and address.
   - Apple minimum term 8 requires a name and address.
   - PDPL Art. 17 requires "a valid and accessible address" on marketing messages.
   - Owner action: a P.O. box or other correspondence address.
5. **The waitlist "we're open" message is direct electronic marketing under PDPL Art. 1 and 17.**
   - It needs prior consent (the code has it), sender identity, a valid address, a statement that it is marketing, and an opt-out link.
   - Under ER Art. 28 and 29, it also needs an e-marketing permit for own purposes. The fee is 10% of the controller fee, so zero below 25,000 records.
   - The proof period runs from the last message, not from joining (marker 11). The function is also not deployed (404).
6. **Firestore TTLs are off in production.** Every "deleted automatically after N days" line in privacy §3.10, §6 and §7 and on the delete page is untrue until `bash firebase/ops/ttl-policies.sh` has run and `--list` shows the 9 policies.
7. **The privacy mailbox is consumer Gmail.**
   - In consumer Gmail, Google is not a processor under a written agreement, as PDPL Art. 4 and 5 require. Support messages and rights requests would sit outside the DPA.
   - Recommend a Google Workspace mailbox on the Own Hub domain, which comes with the Cloud DPA. The `emailProvider` value would then become "Google Workspace".
8. **Server logs: 30 days vs Cybercrime Law 175/2018 Art. 2.**
   - Art. 2 obliges "service providers" ("any natural or legal person who provides information and communication technology services to users, including those who process or store information") to keep logs "for a continuous period of 180 days", including data identifying the user.
   - The breach fine is EGP 5 to 10 million (Art. 33). The definition is broad enough to reach an app operator.
   - Printing "30 days" is true today. Whether Own Hub must instead keep 180 days of identifying logs, which pulls against the privacy design, is a decision for the lawyer, not a wording fix.
9. **Launching without the PDPC permit.**
   - The grace period ends 1 Nov 2026 (PDPL issuance Art. 6, one year from the ER of 1 Nov 2025).
   - Processing sensitive data without a permit carries prison of at least 3 months and/or EGP 500k to 5M (Art. 41). Transfers abroad without a permit carry the same (Art. 42).
   - Below 25,000 records the permit fee is zero (ER Art. 20), but the permit is still required. The PDPC decides within 90 days, and silence counts as refusal (ER Art. 38).
   - The portal (portal.pdpc.gov.eg) is live with company registration and permit management. I could not find a natural-person permit route in its public bundle. `policyEffectiveDate` should not precede the permit.
10. **Privacy §1 row label.** "Personal Data Protection Centre licence or permit" should read **"Personal Data Protection Centre permit"** / **"تصريح مركز حماية البيانات الشخصية"**, because an individual cannot hold a licence (Art. 1).
11. **Code paths the pages describe but production does not run yet.** In-app deletion, the late sweep, recorded acceptance of the Terms, the health-backup consent and the woman-reviewer request are all undeployed (section 0, item 7). The pages must not go live as describing the current product before these deploy. Otherwise they are misleading claims under CPL Art. 9.
12. **Default Storage bucket in US-EAST1.** It holds only library content today, which is accurate. But `storage.rules` is deployed per bucket: if it goes to the default bucket too, the `user-media/{uid}` write rule would let personal media land in the US. Deploy the personal-path rules only to `own-hub-personal`, or deny those paths on the default bucket.

**Sources (primary unless noted)**
- **Law 151/2020 (PDPL):** https://www.sharkawylaw.com/wp-content/uploads/2021/05/Data-Protection-Law-Translation-dual-text.pdf and https://eg.andersen.com/wp-content/uploads/2025/06/Law-No.-151-OF-2020.pdf
- **ER (Decree 816/2025):** Gazette 244A, English translation cached at /tmp/sedona.pdf.
- **PDPC:** https://portal.pdpc.gov.eg (main bundle and assets/i18n).
- **CPL 181/2018:** https://eg.andersen.com/wp-content/uploads/2025/07/Law-No.-181-of-2018.pdf
- **Law 175/2018 and Law 15/2004:** Andersen and Official Journal translations.
- **Civil Code:**
  - art. 217: https://egyls.com
  - art. 44 and art. 111: https://azizavocate.com/2021/02/... (secondary)
  - art. 90: https://ahmedazimelgamel.blogspot.com/2023/12/90.html (secondary)
  - art. 172: https://azizavocate.com/... (secondary)
- **Procedure Code art. 62:** https://ar.jurispedia.org (secondary).
- **Economic Courts Law:** https://www.egyptlawfirm.net/قانون-المحاكم-الاقتصادية-رقم-120-لسنة-2008/ (secondary).
- **Penal Code 161 bis and the Port Said case:** https://eipr.org/press/2026/04/... (secondary).
- **Google:**
  - https://firebase.google.com/support/privacy
  - https://docs.cloud.google.com/logging/quotas
  - https://docs.cloud.google.com/docs/security/deletion
  - https://docs.cloud.google.com/vision/docs/data-usage
  - https://docs.cloud.google.com/vision/docs/ocr
  - https://cloud.google.com/terms/service-terms (§18)
  - https://developers.google.com/ml-kit/android-data-disclosure
- **Stores:**
  - https://developer.apple.com/support/offering-account-deletion-in-your-app/
  - https://www.apple.com/legal/macapps/minterms/
  - https://support.google.com/googleplay/android-developer/answer/13327111
- **Constitution:** /Users/mahmoudreda/ownhub/.claude/release-compliance/egypt-constitution-2019.txt
- **Live project facts:** `gcloud` read-only on project own-hub (log buckets, Firestore locations, TTL list, buckets, functions).

Article numbers in English translations can differ from the Gazette. The lawyer should confirm PDPL Art. 32 and CPL Art. 5 and 28 against the Arabic Gazette text. Art. 32 already matches the Sharkawy Arabic column.

## Usage statistics (Google Analytics for Firebase), added 7 Oct 2026

The app now sends usage statistics only after the separate "Help improve Own Hub" opt-in (off by default). Lawyer to confirm: consent as the basis (PDPL Art. 2, 12 not applicable since no health data), the transfer to Google's global data centres (PDPL Art. 14/15, ER Art. 16: the PDPC permit application must name Google Analytics for Firebase), and the 2-month retention set in the GA property. Full wording applied to the site, with sources, is in ~/ownhub/.claude/feature-briefs/analytics-privacy-changes.md.
