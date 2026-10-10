# Own Hub, personal data breach runbook

Local working document. Not published, not in the repository. A lawyer reviews it with the policy.

**Who runs it:** the publisher, Mahmoud Reda, who is also the data protection officer (Executive
Regulations Art. 38). There is no one to hand it to, so every step below is his.

**The two clocks (privacy policy section 9):**
1. **72 hours** from the moment he becomes aware of a breach, to notify the Personal Data Protection
   Centre (PDPL Art. 7, Executive Regulations Art. 5).
2. **3 working days** after that notification, to tell every affected woman, by SMS or email.

"Aware" means the moment there is a reasonable belief that personal data was accessed, changed,
lost or disclosed without authority. Not the moment the investigation finishes. Start the clock,
write the time in the register, then investigate.

---

## 1. Where a breach shows up

| Source | What it looks like | Where |
|---|---|---|
| Kill switch alert | `kill-switch-alert-policy.json`: the daily verification limit was hit. Can mean a scripted attack on verification | Cloud Monitoring, email alert |
| Webhook missing alert | `webhook-missing-alert-policy.json`: a case was queued and nobody was told | Cloud Monitoring |
| Review access log | `verificationReviewAccess`: a phone number lookup nobody remembers making, or a `reviewerBypass` while no store review is open | Firestore console, `tools/review_queue.py` |
| Cloud audit logs | `_Required` bucket (400 days): IAM changes, new service account keys, Secret Manager access to `nid-hash-pepper` from an unexpected principal | Logs Explorer |
| Firebase Authentication | a spike of sign-ins or SMS sends, or accounts that should not exist | Firebase console, Authentication, Usage |
| App Check | a rise in rejected requests | Firebase console, App Check metrics |
| Billing | spend on Cloud Vision or SMS far above normal | Billing alerts |
| A message | a member, a researcher or Google/Apple writes in about exposed data | the privacy mailbox |
| Your own accounts | a Google account sign-in alert for the owner account, a lost laptop or phone | Google account security page |

## 2. First hour: contain

Do these before anything else. Each one is reversible.

1. **Write the time** you became aware in the register (section 6). That is hour 0.
2. **Close the door that was used:**
   - a leaked credential: disable it (`gcloud iam service-accounts keys disable`, or reset the Google
     account password and sign out all sessions);
   - abuse of a callable: set the kill switch (daily limit) to 0, or remove the function's public
     invoker for the duration;
   - a rules mistake: deploy the last known good `firestore.rules` / `storage.rules` from git.
3. **If the pepper may be exposed** (`nid-hash-pepper`): do not rotate it yet. Rotation without a
   plan breaks the one-card-one-account check. Restrict access to it, note it, and decide with step 3.
4. **Empty the reviewer allow-lists** (`store-reviewer-phones`, `store-reviewer-uids`) if the breach
   touches verification, so nobody is approved without the check.
5. **Preserve evidence:** export the relevant log entries to a file outside the project before any
   retention runs out (`_Default` keeps 30 days).

## 3. First 24 hours: assess

Answer these in the register. They decide what the notice says.

| Question | How to answer it |
|---|---|
| Which data? | Map to the records list in `ropa.md`. Never stored: ID and selfie photos, raw ID numbers. Stored: phone numbers (Firebase Auth), training and meals, health backup if she turned it on, verification results, keyed ID codes |
| Whose? | Count the uids or the waitlist entries affected. Health data or a face match result makes it sensitive data |
| How? | Access, change, loss, or disclosure |
| Still happening? | Confirm the containment from section 2 holds |
| Likely harm? | Sensitive data, phone numbers tied to a women-only app, or anything that reveals a member's identity is high harm. Assume high unless the data was encrypted and the key was not exposed |

## 4. Within 72 hours: notify the Centre

**Personal Data Protection Centre:** portal.pdpc.gov.eg · info@pdpc.gov.eg · hotline 17372.

Send even if the picture is incomplete, and say what is still being checked. Include:
- the publisher's name and contact, and the permit number once issued;
- when the breach happened, if known, and when it was discovered;
- what data and how many people, by category;
- what was done to contain it, and what is planned;
- the likely consequences for the women affected;
- how and when they will be told.

Keep a copy of what was sent and the time it was sent in the register.

## 5. Within 3 working days after that: tell her

By SMS to the number on the account, or by email to the address she wrote from. Plain words, no
jargon, no blame on her. One message per woman. If the breach affects everyone, the same text to all.

### English

> Own Hub: we are writing to tell you about a problem with your data.
>
> On [date], [what happened, in one sentence]. It affected [what data]. It did not affect [what was
> not exposed, for example: your ID card or selfie photos, which we never store].
>
> We have [what we did to stop it]. We reported it to Egypt's Personal Data Protection Centre on
> [date].
>
> What you can do: [one or two practical steps, for example: be careful with calls or messages that
> claim to be from Own Hub. We will never ask you for your sign-in code].
>
> Questions: [privacy email]. You can also complain to the Personal Data Protection Centre:
> portal.pdpc.gov.eg, info@pdpc.gov.eg, hotline 17372.
>
> Mahmoud Reda, publisher of Own Hub

### Arabic

> Own Hub: نكتب إليكِ لنخبرك بمشكلة تخص بياناتك.
>
> في [التاريخ]، [ما حدث في جملة واحدة]. وقد شمل ذلك [البيانات المتأثرة]. ولم يشمل [ما لم يتأثر، مثل:
> صور بطاقتك وصورتك الذاتية، فنحن لا نخزّنها أبدًا].
>
> وقد [ما فعلناه لإيقافه]. وأبلغنا مركز حماية البيانات الشخصية في [التاريخ].
>
> ما يمكنك فعله: [خطوة أو خطوتان عمليتان، مثل: احذري من أي اتصال أو رسالة تدّعي أنها من Own Hub،
> فنحن لن نطلب منك رمز الدخول أبدًا].
>
> للاستفسار: [بريد الخصوصية]. ويمكنك أيضًا تقديم شكوى إلى مركز حماية البيانات الشخصية:
> portal.pdpc.gov.eg، أو info@pdpc.gov.eg، أو الخط الساخن 17372.
>
> محمود رضا، ناشر Own Hub

An SMS is 70 Arabic characters per segment. If the full text is too long for SMS, send a short SMS
that says there is an important message about her data and where to read it, and send the full text
by email or show it in the app.

## 6. Breach register

Keep every incident here, including the ones that turn out not to need a notice, with the reason.
Keep the register for as long as Own Hub runs.

| Field | Example |
|---|---|
| Incident number | 2026-01 |
| Discovered at (date, time, Cairo) | hour 0 |
| How it was discovered | alert, message, own check |
| What happened | one paragraph |
| Data affected | categories from `ropa.md` |
| Number of women affected | count, or an estimate and how it was made |
| Sensitive data involved | yes or no, which |
| Containment steps and times | list |
| Notified the Centre | date, time, channel, reference number |
| Told the women | date, channel, count |
| Not notified, and why | only if no notice was sent |
| Root cause | one paragraph |
| What changed so it does not happen again | commit, rule or setting |
| Closed on | date |
