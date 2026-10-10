# Privacy policy changes for usage statistics (Google Analytics for Firebase)

For the agent that owns `site/`. Apply to `site/privacy/index.html` (EN) and
`site/ar/privacy/index.html` (AR, MSA), and to whatever generates them if they
are built from a source (check `site/_build`). Wrap every Latin product name in
the Arabic page in `<bdi>` exactly as the page already does. No em dashes.

What changed in the app (branch feat/analytics-2026-10-07):

- New optional switch "Help improve Own Hub" (C06 under the crash-report switch,
  and Profile > Privacy). Off by default, separate from crash reports and from
  the Terms acceptance. Off again at any time; turning it off stops collection,
  sets analytics storage back to denied and resets the analytics instance ID.
- When on: Google Analytics for Firebase receives screen ids and steps (tour,
  sign-up steps, ID-check step outcomes in one coarse word, first workout and
  meal, weekly target reached, a return after a quiet week, language and kitten
  settings), an app instance ID, device and app details the SDK adds, and an
  approximate location Google derives from the masked IP address.
- Never sent: health, cycle, body, measurements, weight, life stage, pregnancy,
  allergies, name, phone number, ID number, anything typed, recipe or programme
  titles, why a check refused someone, the niqab path. No user ID. No
  advertising ID, no IDFA, no IDFV. Advertising consents always denied.
- Crash reports (unchanged consent) now also carry: the screen id the crash
  happened on (or "private"), the app version and build channel, fixed-word
  breadcrumb lines, and non-fatal reports of a server call that failed with a
  bug's status code. If usage statistics are also on, Crashlytics shows the
  recent usage-statistics events with a crash.

Versioning: this is a material change under section 12 (new purpose, new kind
of provider). Version 3.0 has not been released yet ("the day this version of
the app is released"), so fold it into 3.0 and add the history line below
rather than bumping to 3.1, which would make every tester accept again through
the legal update sheet. If 3.0 acceptances are already recorded for real users,
bump to 3.1 instead and bump the version constant the app checks.

---

## The short version (EN line 88 to 89; AR line 87 to 88)

EN, replace:
> We do not sell your data. There are no adverts, no tracking and no analytics. Crash reports are sent only if you allow them.

with:
> We do not sell your data. There are no adverts and no tracking. Usage statistics and crash reports are each sent only if you allow them, and never include your health information.

AR, replace:
> لا نبيع بياناتك. لا إعلانات، ولا تتبّع، ولا أدوات تحليلات. ولا تُرسل تقارير الأعطال إلا إذا سمحتِ بها.

with:
> لا نبيع بياناتك. لا إعلانات ولا تتبّع. ولا تُرسل إحصاءات الاستخدام ولا تقارير الأعطال إلا إذا سمحتِ بكل منهما، ولا تتضمن أي منهما معلوماتك الصحية.

## 3.6 Your health information stays on your phone

No change. "never sent to any analytics service" stays true and is enforced in
the app by tests (cycle feature has no analytics call site; no event argument
may reference health, body or identity data).

## 3.7 Technical data

### Crash reports item (EN line 281 to 289; AR line 260 to 266)

EN, replace the whole `<li>` with:
> **Crash reports, only if you allow them.** You can allow them on the sign-up screen, or later in Profile, then Privacy. They are off until you do. What Firebase Crashlytics receives when the app crashes: the type of error and where in the code it happened, the screen it happened on (shown as "private" for screens about your body or your cycle), your device model, operating system, app version, free memory and storage, and an installation identifier. It also receives a report when one of our servers fails in a way that is our fault, with only the error's status code. If you have also turned on usage statistics, the last screens and steps you used are shown with the report. What is never attached: your account identifier, your name, your phone number, or the text of any error. If you turn them off, reports waiting on your phone are deleted.

AR, replace with:
> **تقارير الأعطال، فقط إذا سمحتِ بها.** يمكنك السماح بها في شاشة التسجيل، أو لاحقًا من الملف الشخصي ثم الخصوصية، وتبقى متوقفة حتى تفعلي. ما تتلقاه خدمة `<bdi>Firebase Crashlytics</bdi>` إذا تعطّل التطبيق: نوع الخطأ وموضعه في الشيفرة، والشاشة التي حدث فيها (وتظهر بكلمة "خاصة" للشاشات المتعلقة بجسمك أو دورتك)، وطراز الجهاز، ونظام التشغيل، وإصدار التطبيق، والذاكرة والمساحة المتاحتين، ومعرّفًا للتثبيت. وتتلقى كذلك تقريرًا إذا تعطّل أحد خوادمنا بسبب خطأ منّا، يتضمن رمز حالة الخطأ فقط. وإذا كنتِ قد فعّلتِ إحصاءات الاستخدام أيضًا، تظهر مع التقرير آخر الشاشات والخطوات التي استخدمتِها. ما لا يُرفق أبدًا: معرّف حسابك، أو اسمك، أو رقم هاتفك، أو نص أي خطأ. وإذا أوقفتِها تُحذف التقارير المنتظرة على هاتفك.

### New item, insert directly after the crash reports item

EN:
> **Usage statistics ("Help improve Own Hub"), only if you allow them.** A separate switch on the sign-up screen and in Profile, then Privacy. Off until you turn it on. When it is on, Google Analytics for Firebase receives which screens you open (by a short screen code such as "T01") and which steps you reach: the tour, each sign-up step, whether the ID check started, went to a reviewer, asked for new photos, let you in or was refused (one word, never why), your first workout and meal, reaching your weekly target, coming back after a week or more away, and your language and kitten settings. Google adds a random app instance identifier, your device model, operating system and app version, and an approximate location it works out from your IP address. **It never receives your health information, cycle, body measurements, weight, life stage, pregnancy, allergies, name, phone number, ID number, anything you type, or the names of recipes or programmes.** We do not give it your account identifier and do not link what it receives to your account. We never use it for advertising: there is no advertising identifier, and advertising uses are switched off. If you turn it off, collection stops at once and the identifier on your phone is reset, so what was sent before cannot be joined to anything sent later.

AR:
> **إحصاءات الاستخدام ("ساعدينا في تحسين `<bdi>Own Hub</bdi>`")، فقط إذا سمحتِ بها.** مفتاح مستقل في شاشة التسجيل وفي الملف الشخصي ثم الخصوصية، ويبقى متوقفًا حتى تفعّليه. عند تفعيله تتلقى خدمة `<bdi>Google Analytics for Firebase</bdi>` الشاشات التي تفتحينها (برمز قصير للشاشة مثل "T01") والخطوات التي تصلين إليها: الجولة التعريفية، وكل خطوة من خطوات التسجيل، وما إذا بدأ التحقق من الهوية، أو أُحيل إلى مراجِعة، أو طلب صورًا جديدة، أو سمح لك بالدخول، أو رُفض (بكلمة واحدة، دون السبب أبدًا)، وأول تمرين وأول وجبة، وبلوغ هدفك الأسبوعي، وعودتك بعد أسبوع أو أكثر من الغياب، وإعدادات اللغة والقطة. وتضيف `<bdi>Google</bdi>` معرّفًا عشوائيًا لنسخة التطبيق، وطراز جهازك، ونظام التشغيل، وإصدار التطبيق، وموقعًا تقريبيًا تستنتجه من عنوان `<bdi>IP</bdi>`. **ولا تتلقى أبدًا معلوماتك الصحية، أو دورتك، أو قياسات جسمك، أو وزنك، أو مرحلتك الحياتية، أو الحمل، أو حساسيّاتك، أو اسمك، أو رقم هاتفك، أو رقمك القومي، أو أي نص تكتبينه، أو أسماء الوصفات أو البرامج.** ولا نعطيها معرّف حسابك، ولا نربط ما تتلقاه بحسابك. ولا نستخدمها للإعلان أبدًا: لا معرّف إعلاني، وجميع الاستخدامات الإعلانية متوقفة. وإذا أوقفتِها يتوقف الجمع فورًا ويُعاد تعيين المعرّف على هاتفك، فلا يمكن ربط ما أُرسل قبل ذلك بأي شيء يُرسل بعده.

### Basis item (EN line 292 to 295; AR line 269 to 272)

EN, replace:
> except crash reports, which need your consent.

with:
> except crash reports and usage statistics, which each need your consent.

AR, replace:
> باستثناء تقارير الأعطال التي تتطلب موافقتك.

with:
> باستثناء تقارير الأعطال وإحصاءات الاستخدام، إذ تتطلب كل منهما موافقتك.

## 4. Who handles your data, and where

Add a card directly after the Firebase Crashlytics card.

EN:
```html
<li>
  <h4>Google Analytics for Firebase, only if you allow it</h4>
  <dl>
    <div><dt>Handles</dt><dd>Usage statistics (section 3.7)</dd></div>
    <div><dt>Where</dt><dd>Google data centres worldwide, which include the United States</dd></div>
  </dl>
</li>
```

AR:
```html
<li>
  <h4><bdi>Google Analytics for Firebase</bdi>، فقط إذا سمحتِ بها</h4>
  <dl>
    <div><dt>ما يتعامل معه</dt><dd>إحصاءات الاستخدام (القسم ٣.٧)</dd></div>
    <div><dt>أين</dt><dd>مراكز بيانات <bdi>Google</bdi> حول العالم، ومنها الولايات المتحدة</dd></div>
  </dl>
</li>
```

Intro paragraph of section 4 (EN line 344 to 348): append one sentence.

EN, after "...the Firebase Data Processing and Security Terms.":
> Google Analytics processes usage statistics for us under the Google Ads Data Processing Terms, with data sharing with Google, Google signals and advertising links all switched off.

AR, after the matching sentence:
> وتعالج `<bdi>Google Analytics</bdi>` إحصاءات الاستخدام لحسابنا بموجب شروط `<bdi>Google Ads</bdi>` لمعالجة البيانات، مع إيقاف مشاركة البيانات مع `<bdi>Google</bdi>` وإشارات `<bdi>Google</bdi>` وأي ربط إعلاني.

(Only publish this sentence once the owner has accepted those terms and switched
those settings off in the Analytics property: see the console checklist.)

## 5. Transfers outside Egypt

Third bullet (EN line 434 to 437; AR line 404 to 406).

EN, replace:
> the device checks, ML Kit performance data, and crash reports if you allow them.

with:
> the device checks, ML Kit performance data, crash reports if you allow them, and usage statistics if you allow them.

AR, replace:
> فحوص الجهاز، وبيانات أداء `<bdi>ML Kit</bdi>`، وتقارير الأعطال إذا سمحتِ بها.

with:
> فحوص الجهاز، وبيانات أداء `<bdi>ML Kit</bdi>`، وتقارير الأعطال إذا سمحتِ بها، وإحصاءات الاستخدام إذا سمحتِ بها.

Consent paragraph (EN line 439 to 444; AR line 408 to 411). Append:

EN:
> Usage statistics have their own consent, the "Help improve Own Hub" switch, which names Google Analytics and says the data may be processed outside Egypt. Nothing is sent before you turn it on.

AR:
> ولإحصاءات الاستخدام موافقة مستقلة، هي مفتاح "ساعدينا في تحسين `<bdi>Own Hub</bdi>`"، الذي يسمّي `<bdi>Google Analytics</bdi>` ويذكر أن البيانات قد تُعالَج خارج مصر. ولا يُرسل شيء قبل أن تفعّليه.

Safeguards paragraph (EN line 446; AR line 413): this text is the
`transferCountries` legal value. Change in
`.claude/release-compliance/legal-values.md` too.

EN, replace:
> Firebase App Check, Google ML Kit performance data, and Firebase Crashlytics if you allow it.

with:
> Firebase App Check, Google ML Kit performance data, Firebase Crashlytics if you allow it, and Google Analytics for Firebase if you allow it.

AR, replace:
> `<bdi>Firebase App Check</bdi>`، وبيانات الأداء الخاصة بـ `<bdi>Google ML Kit</bdi>`، و`<bdi>Firebase Crashlytics</bdi>` إن سمحتِ بها،

with:
> `<bdi>Firebase App Check</bdi>`، وبيانات الأداء الخاصة بـ `<bdi>Google ML Kit</bdi>`، و`<bdi>Firebase Crashlytics</bdi>` إن سمحتِ بها، و`<bdi>Google Analytics for Firebase</bdi>` إن سمحتِ بها،

PDPL note for the owner: the transfer permit application must name Google
Analytics among the global services (Executive Regulations Art. 16(4): only the
countries in the permit).

## 6. How long we keep it

Insert a row directly after "Crash reports, if you allow them".

EN:
```html
<div><dt>Usage statistics, if you allow them</dt><dd>2 months for anything tied to the app instance identifier, the shortest Google Analytics allows, then deleted automatically. Counts that are not linked to any person, such as how many people finished the tour, are kept.</dd></div>
```

AR:
```html
<div><dt>إحصاءات الاستخدام، إذا سمحتِ بها</dt><dd>شهران لكل ما يرتبط بمعرّف نسخة التطبيق، وهي أقصر مدة تتيحها <bdi>Google Analytics</bdi>، ثم تُحذف تلقائيًا. أما الأعداد غير المرتبطة بأي شخص، مثل عدد من أكملن الجولة التعريفية، فنحتفظ بها.</dd></div>
```

(True only once the owner sets Data retention to 2 months in the GA property.)

## 7. Deleting your account

EN line 492 to 493, replace:
> Crash reports and ML Kit data are never linked to your account. Google deletes them on its own schedule.

with:
> Crash reports, usage statistics and ML Kit data are never linked to your account. Deleting everything also turns usage statistics off and resets the identifier on your phone. Google deletes this data on the schedule in section 6.

AR line 457 to 458, replace:
> أما تقارير الأعطال وبيانات `<bdi>ML Kit</bdi>` فلا ترتبط بحسابك أبدًا، وتحذفها `<bdi>Google</bdi>` وفق جدولها.

with:
> أما تقارير الأعطال وإحصاءات الاستخدام وبيانات `<bdi>ML Kit</bdi>` فلا ترتبط بحسابك أبدًا. ويؤدي حذف كل شيء أيضًا إلى إيقاف إحصاءات الاستخدام وإعادة تعيين المعرّف على هاتفك. وتحذف `<bdi>Google</bdi>` هذه البيانات وفق المدد المذكورة في القسم ٦.

## 8. Your rights

Withdraw-consent bullet.

EN, replace:
> You can turn off crash reports and health backup yourself in Profile, then Privacy;

with:
> You can turn off crash reports, usage statistics and health backup yourself in Profile, then Privacy;

AR, replace:
> ويمكنك بنفسك إيقاف تقارير الأعطال والنسخ الاحتياطي الصحي من الملف الشخصي ثم الخصوصية؛

with:
> ويمكنك بنفسك إيقاف تقارير الأعطال وإحصاءات الاستخدام والنسخ الاحتياطي الصحي من الملف الشخصي ثم الخصوصية؛

## 10. What Own Hub does not do

EN, replace the bullet:
> No analytics software.

with:
> No analytics unless you turn on usage statistics, and never of your health information.

AR, replace:
> لا برامج تحليلات.

with:
> لا إحصاءات استخدام ما لم تفعّليها، ولا أي إحصاءات عن معلوماتك الصحية أبدًا.

The first bullet ("No adverts, no advertising identifiers, and no tracking")
stays true: the advertising ID permission is removed on Android, the IDFA-free
analytics module is used on iOS, and advertising consents are always denied.

## 12. Changes to this policy

Add as the first line of the version history.

EN:
> **3.0, update before release:** usage statistics with Google Analytics for Firebase, only with your separate consent ("Help improve Own Hub"), and more detail on what a crash report carries.

AR:
> **3.0، تحديث قبل الإصدار:** إحصاءات الاستخدام عبر `<bdi>Google Analytics for Firebase</bdi>`، فقط بموافقتك المستقلة ("ساعدينا في تحسين `<bdi>Own Hub</bdi>`")، ومزيد من التفاصيل عمّا يحمله تقرير الأعطال.

## Other pages and values that say "no analytics"

- `.claude/release-compliance/legal-values.md`, `transferCountries` (EN and AR):
  same edit as the Safeguards paragraph above. Add a new value
  `analyticsRetention`: EN "2 months for anything tied to the app instance
  identifier, then deleted automatically", AR "شهران لكل ما يرتبط بمعرّف نسخة
  التطبيق، ثم تُحذف تلقائيًا". Source:
  https://support.google.com/analytics/answer/7667196
- Search the rest of `site/` (EN and AR, including `index.html`, `support/`,
  `terms/`, `delete-account/`) for "analytics", "تحليلات" and "no tracking" and
  align any claim of "no analytics" with the text above.
- `docs/release/review-notes.md` and `docs/release/launch-pack/app-store-privacy-answers.md`
  were updated by the analytics branch (outside `site/`).
