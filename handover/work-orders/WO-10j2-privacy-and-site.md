# WO-10j2: privacy policy, terms and coach terms on the website (English and Egyptian Arabic)
Depends on: none (text only). Do NOT deploy: the owner deploys after counsel signs (spec section 12). DRAFT FOR COUNSEL: every `<!-- [LAWYER] ... -->` comment below is stripped from the published page by `strip_drafting_notes` (`site/_build/build.py` line 61), so counsel's questions can stay in the source.
Size: L
Reads first: `site/_build/pages_en.py` lines 311-345 (short version), 845-855 (3.15), 929-935 (3.16), 977-1010 (3.17 and the end of section 3), 1121-1135 and 1190-1205 (retention), 1494-1518 (terms section 2), 1616-1672 (terms 9, 11, 14), 1851-1900 (coach terms 5, 6, 9); the same areas in `site/_build/pages_ar.py` (lines 335-340, 783-790, 833-836, 854-858, 1027, 1388-1394, 1504-1508, 1517-1521, 1538-1542, 1707-1722, 1747-1750)

## Why
The published pages say "no payments", "nobody can pay yet" and "the price includes Own Hub's fee". When payments by InstaPay go live these statements are false, and a privacy policy that does not name payment records, bank screenshots and the screenshot reader is a legal and a store problem. The policy, the terms and the coach terms must be changed together, in both languages, before the flag is on. Arabic is Egyptian (owner decision 14 Oct), plain register, feminine address, no em dashes.

## Final result
After `python3 site/_build/build.py` the generated `site/privacy.html`, `site/ar/privacy.html`, `site/terms.html`, `site/ar/terms.html`, `site/coach-terms.html` and `site/ar/coach-terms.html` say, in plain words: Own Hub never holds the money; a member pays her coach directly by InstaPay; what is kept about a payment, for how long and who sees it; the screenshot is read on the phone and again on our server; no check can prove a payment; the coach's duties, the fee, strikes and suspensions; refunds. No page still says "no payments", "free for now", "nobody can pay" or "price includes Own Hub's service fee".

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| site/_build/pages_en.py | edit | privacy 3.15, 3.16, new 3.18, short version, section 4 card, section 6 rows, section 10; terms 2, 9, 11, 14; coach terms 5, 6, 9 |
| site/_build/pages_ar.py | edit | the same, in Arabic |
| docs/release/privacy-policy.md | edit | the plain-text copy gets the same 3.18 (UNVERIFIED if it is generated: `grep -n "3.16" docs/release/privacy-policy.md | head -3`) |

## Steps
Anchors are unique text found with `grep -n`. For each, run the grep first; the line numbers are "about".
1. EN privacy short version. Anchor: the first `(sections 3.16 and 3.17).</li>` (about line 343). Add after it:
```html
            <li><b>If you pay a coach, you pay her directly by InstaPay.</b>
            Own Hub never holds or moves the money. We keep a record of each
            payment, the transaction number you give and the screenshots you
            send, so your coach can confirm it and our team can decide a
            dispute (section 3.18).</li>
```
2. AR short version. Anchor: the `و3.17).</li>` that ends the coach-chat bullet (about line 338). Add after it:
```html
            <li><b>لو دفعتي لمدرّبة، بتدفعي لها على طول بإنستا باي.</b>
            Own Hub مابتمسكش الفلوس ولا بتحرّكها. بنحتفظ بسجل لكل دفعة، ورقم
            العملية اللي بتكتبيه، ولقطات الشاشة اللي بتبعتيها، عشان مدرّبتك
            تأكد الدفع وفريقنا يقدر يفصل في أي خلاف (القسم 3.18).</li>
```
3. EN 3.15. Anchor: `(section 3.16). Payments are not offered yet, so no payment data\n        exists.</p>` (about line 851). Replace those two lines with `(section 3.16). Payments between a member and her coach are described\n        in section 3.18.</p>`. AR 3.15. Anchor: `يقروه، وتقدر العضوات ينضمّوا لمدرّبة مجانًا (القسم 3.16). الدفع مش\n        متاح لسه، فمفيش بيانات دفع.</p>` (about line 787). Replace with `يقروه، وتقدر العضوات ينضمّوا لمدرّبة (القسم 3.16). والدفع بين العضوة\n        ومدرّبتها متشرح في القسم 3.18.</p>`. Also AR line about 835: `الانضمام لمدرّبة مجانًا (القسم 3.16)، ومحدّش يقدر يدفع لسه.</li>` becomes `الانضمام لمدرّبة (القسم 3.16)، والدفع متشرح في القسم 3.18.</li>`.
4. EN 3.16. Anchor: `It is free: Own Hub offers no payments yet, so no payment details are asked\n        for or kept.</p>` (about line 930). Replace with `Asking to join is free. If your coach accepts you and charges for her\n        package, you pay her directly (section 3.18).</p>`. AR 3.16 anchor: `وده مجاني: Own Hub مبيقدّمش دفع لسه، فمفيش بيانات دفع بتتطلب أو\n        بتتحفظ.</p>` (about line 856). Replace with `والطلب نفسه مجاني. ولو مدرّبتك قبلتك وليها سعر للباقة، بتدفعي لها\n        على طول (القسم 3.18).</p>`.
5. EN new section 3.18. Anchor: the line `""" + h2("where", "4. Who handles your data, and where") + """` (about line 1010). Insert BEFORE it (after the closing `</ul>` of 3.17):
```python
""" + h3("c-pay", "3.18 Paying a coach by InstaPay") + """
        <p>This applies only if you pay a coach, or you are a coach and a
        member pays you. <b>Own Hub never holds, receives or moves the money.</b>
        The member sends it by InstaPay, from her bank app, to the coach&rsquo;s
        own InstaPay address. Own Hub shows who to pay and how much, records
        the payment, asks the coach to confirm that it arrived, and decides a
        dispute if there is one.</p>
        <ul>
          <li><b>What we keep about a payment.</b> The member and the coach, by
          account identifier; the package; the amount, which has a few extra
          piasters so that it matches only this payment; a reference code; the
          status and the time of each step; the coach&rsquo;s InstaPay address
          and account name as they were when you paid; the transaction number
          you give; and the notes and reasons either of you writes in a
          dispute.</li>
          <li><b>Screenshots.</b> If you send screenshots of your bank&rsquo;s
          receipt, the app reads the text on your phone to fill in the form.
          You can hide lines (card numbers, balances) and crop before anything
          is sent: only that copy leaves your phone, never the original. Our
          server stores the copy privately, reads it again with Google Cloud
          Vision, keeps the text fields it found, and keeps a fingerprint of
          the picture so that the same picture cannot be used twice.
          <!-- [LAWYER] confirm Cloud Vision as a processor and its region; [OWNER] confirm the region -->
          </li>
          <li><b>Who sees it.</b> The member and her coach. Own Hub&rsquo;s team
          opens a payment only when it is in dispute or flagged, and a woman
          reviews any case that holds a woman&rsquo;s private data. Another coach
          never sees it. A coach does not see your phone number. Your own
          InstaPay address, if you use one, is shown on the receipt your bank
          makes, so we suggest an address with an @ rather than your phone
          number.</li>
          <li><b>Why.</b> So the coach can confirm a payment, our team can
          decide a dispute, we can prevent fraud, and we meet our legal
          duties. <b>No check can prove a payment</b>: only the coach&rsquo;s
          bank knows. We reduce fraud; we cannot remove it. We may report fraud
          to the authorities and keep the evidence for that.</li>
          <li><b>Basis:</b> carrying out the coaching you asked for, and keeping
          members safe and the service working, which the law allows (Law
          151/2020, Article 6, point 4).
          <!-- [LAWYER] confirm the basis for payment records, screenshots and strikes -->
          </li>
          <li><b>Optional.</b> At your first payment you can say yes to
          &ldquo;Help improve receipt reading&rdquo;. If you do, we keep only the
          text fields read from your receipts, never the picture, to improve the
          reading. The answer is off until you give it.</li>
          <li><b>Not in statistics.</b> No amount, reference, transaction number
          or screenshot is ever sent to usage statistics or crash reports.</li>
          <li><b>Strikes.</b> A payment proof that staff find false is recorded
          as a strike on the account, and so is a false claim by a coach that
          she was not paid. Two strikes in 90 days remove the ability to pay or
          to take payments by this method. A decision is made by a person, with a
          written reason.</li>
          <li><b>InstaPay and your bank</b> handle the transfer under their own
          terms. Own Hub cannot undo a transfer. If you sent money to the wrong
          account, contact your bank at once.</li>
        </ul>

"""
```
(the closing `"""` re-opens the string exactly as the neighbouring sections do: copy the join pattern from the end of 3.17 in the file, i.e. the section before ends with `</ul>\n\n""" + h2("where", ...`; your insertion must keep `""" + h3(...) + """` pairs balanced. Run the build to prove it.)
6. AR new section 3.18. Anchor: `""" + h2("where", "4. مين بيتعامل مع بياناتك وفين") + """` (about line 925). Insert before it:
```python
""" + h3("c-pay", "3.18 الدفع لمدرّبة بإنستا باي") + """
        <p>القسم ده بينطبق بس لو دفعتي لمدرّبة، أو لو إنتِ مدرّبة وعضوة دفعتلك.
        <b>Own Hub مابتمسكش الفلوس ولا بتستلمها ولا بتحرّكها.</b> العضوة
        بتحوّلها بإنستا باي من تطبيق البنك على عنوان إنستا باي بتاع المدرّبة
        نفسها. وOwn Hub بتوريكي تدفعي لمين وكام، وبتسجّل الدفع، وبتطلب من
        المدرّبة تأكد إن الفلوس وصلت، وبتفصل في أي خلاف لو حصل.</p>
        <ul>
          <li><b>بنحتفظ بإيه عن الدفع.</b> العضوة والمدرّبة (برقم الحساب)؛
          والباقة؛ والمبلغ وفيه كام قرش زيادة عشان يطابق الدفعة دي بس؛ ورقم
          مرجعي؛ وحالة الدفع ووقت كل خطوة؛ وعنوان إنستا باي واسم حساب المدرّبة
          زي ما كانوا وقت الدفع؛ ورقم العملية اللي بتكتبيه؛ والملاحظات
          والأسباب اللي أي واحدة فيكم بتكتبها في الخلاف.</li>
          <li><b>لقطات الشاشة.</b> لو بعتّي لقطات من إيصال البنك، التطبيق بيقرا
          النص على تليفونك عشان يملا الاستمارة. وتقدري تخفي سطور (أرقام كارت
          أو رصيد) وتقصّي الصورة قبل ما أي حاجة تتبعت: النسخة دي بس هي اللي
          بتسيب تليفونك، مش الأصل. السيرفر بتاعنا بيحفظ النسخة بشكل خاص، وبيقراها
          تاني بـ Google Cloud Vision، وبيحتفظ بالحقول اللي لقاها، وببصمة للصورة
          عشان نفس الصورة ماتتستخدمش مرتين.
          <!-- [LAWYER] confirm Cloud Vision as a processor and its region; [OWNER] confirm the region -->
          </li>
          <li><b>مين بيشوف.</b> العضوة ومدرّبتها. وفريق Own Hub بيفتح الدفع بس
          لو فيه خلاف عليه أو اتعلّم للمراجعة، وواحدة ست بتراجع أي حالة فيها
          بيانات خاصة بست. وأي مدرّبة تانية مبتشوفوش. والمدرّبة مبتشوفش رقم
          تليفونك. وعنوان إنستا باي بتاعك، لو بتستخدمي واحد، بيظهر في الإيصال
          اللي البنك بيعمله، فبننصحك بعنوان فيه @ بدل رقم تليفونك.</li>
          <li><b>ليه.</b> عشان المدرّبة تأكد الدفع، وفريقنا يفصل في الخلاف،
          ونمنع الاحتيال، ونلتزم بالقانون. <b>مفيش فحص يقدر يثبت إن دفعة
          حصلت</b>: بنك المدرّبة بس هو اللي يعرف. إحنا بنقلّل الاحتيال لكن
          مبنقدرش نمنعه خالص. وممكن نبلّغ السلطات عن الاحتيال ونحتفظ بالدليل
          لده.</li>
          <li><b>الأساس:</b> تنفيذ التدريب اللي طلبتيه، وحماية العضوات وتشغيل
          الخدمة، وده القانون بيسمح بيه (قانون 151 لسنة 2020، المادة 6، البند
          4).
          <!-- [LAWYER] confirm the basis for payment records, screenshots and strikes -->
          </li>
          <li><b>اختياري.</b> في أول دفع تقدري تقولي أيوه على «ساعدي نحسّن قراءة
          الإيصالات». لو قلتي أيوه، بنحتفظ بالحقول المقروءة من إيصالاتك بس، مش
          بالصورة، عشان نحسّن القراءة. والإجابة مقفولة لحد ما تدّيها.</li>
          <li><b>مش في الإحصاءات.</b> مفيش مبلغ ولا رقم مرجعي ولا رقم عملية ولا
          لقطة شاشة بتتبعت لإحصاءات الاستخدام أو تقارير الأعطال.</li>
          <li><b>الإنذارات.</b> إثبات دفع فريقنا يلاقيه غير صحيح بيتسجّل إنذار على
          الحساب، وكمان ادّعاء المدرّبة إن الفلوس ماوصلتش لو طلع غير صحيح.
          إنذارين في 90 يوم بيوقفوا القدرة على الدفع أو استلام الدفع بالطريقة
          دي. والقرار بيتاخد من شخص، بسبب مكتوب.</li>
          <li><b>إنستا باي وبنكك</b> بيتعاملوا مع التحويل بشروطهم. وOwn Hub
          مابتقدرش ترجّع تحويل. ولو بعتّي الفلوس لحساب غلط، كلّمي بنكك فورًا.</li>
        </ul>

"""
```
7. EN section 4 (who handles data). Anchor: the `cards([` call of section 4, the tuple starting `("Google Cloud Firestore, Cloud Functions, Cloud Storage and Secret Manager", [` (about line 1025). Add a new tuple after that tuple's closing `]),`:
```python
            ("Google Cloud Vision", [
                ("Handles", "The text of a payment screenshot you send as proof, read by our server"),
                ("Where", "UNVERIFIED-REGION"),
            ]),
```
Replace `UNVERIFIED-REGION` with the region the owner confirms (Vision availability and region are not verified: the server order WO-10l-server decides; run `grep -rn "vision" functions/ --include=requirements.txt` to see if it is in use). AR: the same tuple in `pages_ar.py` (find the matching tuple `("Google Cloud Firestore, Cloud Functions...` or its Arabic title; `grep -n "Cloud Firestore" site/_build/pages_ar.py`): `("Google Cloud Vision", [("بيتعامل مع", "نص لقطة الشاشة اللي بتبعتيها كإثبات دفع، والسيرفر بتاعنا بيقراه"), ("فين", "UNVERIFIED-REGION")])` matching that file's label words for Handles and Where (copy them from the neighbouring tuple).
8. EN retention (section 6). Anchor: the row `("Backups held by Google", "Removed within about 6 months (180 days) of deletion"),` (about line 1199). Add before it:
```python
            ("Payment records (amount, reference, transaction number, status, steps, notes)",
             "For the period the law requires. When you delete your account the record is kept without your name for that period, then deleted (section 3.18)."),
            ("Payment screenshots and the text read from them",
             "Deleted 90 days after the payment is settled or its dispute is closed. A screenshot is deleted with your account at once."),
            ("Strikes", "For 90 days from the decision for the two-strike rule; the decision itself stays with the payment record."),
```
`<!-- [OWNER] decision 12.4: retention numbers (90 days, the legal period) -->` goes on the line above the first row as a Python comment `# [OWNER] ...` (a Python comment is not published). AR: same rows in `pages_ar.py` section 6 (anchor `("Backups held by Google"` Arabic label: `grep -n "180" site/_build/pages_ar.py | head`): `("سجلات الدفع (المبلغ والرقم المرجعي ورقم العملية والحالة والخطوات والملاحظات)", "للمدة اللي القانون بيطلبها. ولما بتمسحي حسابك السجل بيتحفظ من غير اسمك للمدة دي وبعدين بيتمسح (القسم 3.18).")`, `("لقطات شاشة الدفع والنص المقروء منها", "بتتمسح بعد 90 يوم من تسوية الدفع أو قفل الخلاف. ولقطة الشاشة بتتمسح مع حسابك فورًا.")`, `("الإنذارات", "90 يوم من القرار لقاعدة الإنذارين؛ والقرار نفسه بيفضل مع سجل الدفع.")`.
9. EN section 10 (what Own Hub does not do). Anchor: the bullet `<li>No access to your photo library. If you pick your profile photo` (about line 1322). After its closing `</li>` (ends `(section\n          3.15).</li>`) add:
```html
          <li>For a payment proof, the same phone picker hands Own Hub only the
          pictures you choose. They are copied after you hide what you want to
          hide; the originals stay on your phone (section 3.18).</li>
```
AR: the matching bullet about the photo library in section 10 (`grep -n "مكتبة الصور" site/_build/pages_ar.py`), add: `<li>ولإثبات الدفع، نفس أداة اختيار الصور في تليفونك بتدّي Own Hub الصور اللي بتختاريها بس. بتتنسخ بعد ما تخفي اللي عايزة تخفيه، والأصول بتفضل على تليفونك (القسم 3.18).</li>`.
10. EN terms. (a) section 2 bullet: replace `<li><b>It is free.</b> There are no adverts, no in-app purchases, no\n          subscriptions and no payments of any kind.</li>` with `<li><b>The app is free.</b> There are no adverts, no in-app purchases and no\n          subscriptions. If you pay a coach, you pay her directly by InstaPay\n          (section 9).</li>`. (b) In the next bullet replace `no community, no AI\n          assistant and no payments.` with `no community and no AI\n          assistant.` and `but nobody can pay\n          yet.` with `and pay them\n          by InstaPay.`; keep `If any missing feature arrives...`. (c) section 9 bullet: replace the whole `<li><b>Free for now.</b> In this version coaching is free and nobody\n          can pay. Before payments open, you will be asked to accept updated\n          terms that set out prices and how payment works.</li>` with:
```html
          <li><b>Paying a coach.</b> Asking to join is free. If your coach
          accepts you and charges for her package, you pay her directly by
          InstaPay from your bank app. Own Hub never holds the money: it shows
          you who to pay and how much, records the payment, asks the coach to
          confirm it and helps decide a dispute. Check that the name your bank
          shows is your coach&rsquo;s before you send: Own Hub cannot undo an
          InstaPay transfer, and no check can prove a payment. You can ask for
          a refund once in the first 14 days. Sending a false proof is a breach
          of these Terms: it is recorded, and two proven false proofs in 90 days
          end your ability to pay this way. The Privacy Policy, section 3.18,
          says what is kept.
          <!-- [LAWYER] confirm: not a regulated payment service; refund window; strike wording -->
          </li>
```
(d) section 11 (`t9`): replace the paragraph with `<p>The app is free. Coaching is paid for directly to your coach (section 9). If a future version adds anything paid to Own Hub itself, it will come with its own terms, shown before anything is charged, and nothing will renew without your clear agreement.</p>`. (e) section 14 (`t12`): replace `Community, an AI assistant and payments are not part of this\n        version.` with `Community and an AI assistant are not part of this\n        version.` (f) `docs/release/terms.md` and `terms.proposed.md` copies are legal records; do not edit them here (UNVERIFIED if generated: ask in QUESTIONS.md).
11. AR terms. (a) the "It is free / no payments" bullet in section 2 (anchor `grep -n "مفيش مدفوعات" site/_build/pages_ar.py` or the Arabic of "no payments of any kind"): replace with `<li><b>التطبيق مجاني.</b> مفيش إعلانات ولا مشتريات جوه التطبيق ولا اشتراكات. ولو دفعتي لمدرّبة، بتدفعي لها على طول بإنستا باي (القسم 9).</li>`. (b) the bullet starting `<li>... طلبتي تنضمّي لمدرّبة، وده مجاني` (about line 1388-1394): delete `وده مجاني` and replace `لكن محدّش يقدر يدفع\n          لسه` with `وتدفع لها بإنستا باي`; and in the "not in this version" line remove "ومدفوعات". (c) section 9 bullet (anchor `<li><b>مجاني دلوقتي.</b>`, about line 1506): replace the whole `<li>` with:
```html
          <li><b>الدفع لمدرّبة.</b> طلب الانضمام مجاني. ولو مدرّبتك قبلتك وليها
          سعر للباقة، بتدفعي لها على طول بإنستا باي من تطبيق البنك. Own Hub
          مابتمسكش الفلوس أبدًا: بتوريكي تدفعي لمين وكام، وبتسجّل الدفع،
          وبتطلب من المدرّبة تأكده، وبتساعد في الفصل في أي خلاف. اتأكدي إن الاسم
          اللي البنك بيعرضه هو اسم مدرّبتك قبل ما تبعتي: Own Hub مابتقدرش
          ترجّع تحويل إنستا باي، ومفيش فحص يقدر يثبت إن دفعة حصلت. وتقدري
          تطلبي استرداد مرة واحدة في أول 14 يوم. وإرسال إثبات دفع غير صحيح
          مخالفة لشروط الاستخدام دي: بيتسجّل، وإثباتين غير صحيحين في 90 يوم
          بيوقفوا قدرتك على الدفع بالطريقة دي. وسياسة الخصوصية، القسم 3.18،
          بتقول إحنا بنحتفظ بإيه.</li>
```
(d) section 11 (`t9`, about line 1517): replace the paragraph with `<p>التطبيق مجاني. والتدريب بتدفعي ثمنه لمدرّبتك على طول (القسم 9). ولو إصدار جاي ضاف حاجة مدفوعة لـ Own Hub نفسها، هتيجي بشروطها الخاصة اللي هتتعرض عليكي قبل أي خصم، ومفيش حاجة هتتجدد من غير موافقتك الواضحة.</p>`. (e) section 14 (`t12`, about line 1539): replace `المجتمع، ومساعد الذكاء الاصطناعي، والمدفوعات مش جزء من الإصدار\n        ده.` with `المجتمع ومساعد الذكاء الاصطناعي مش جزء من الإصدار\n        ده.`
12. EN coach terms. (a) k5, bullet 1: replace `Do not put payment details or ways to reach you outside Own Hub\n          (a phone number, a messaging account, a social media page) in your\n          portfolio.` with `Do not put ways to reach you outside Own Hub (a phone number, a\n          messaging account, a social media page) in your portfolio. Your\n          InstaPay address is set only in the payments setting of the app.` (b) k6, the bullet `In this version the price members see includes ...`: replace the whole `<li>` with `<li>The price you set is the price members see and pay, with nothing added on top. Members pay you directly by InstaPay. Own Hub keeps a fee of 15 percent of the price for a client who found you in the app, and 8 percent for a client you brought with your own invite code. The fee is fixed when the coaching first starts between you and that client.\n          <!-- [LAWYER] D63; confirm the rates and that the fee is owed from activation -->\n          </li>`. (c) k9: replace the whole section (heading and paragraph) with:
```python
""" + h2("k9", "9. Payments by InstaPay") + """
        <!-- [LAWYER] DRAFT FOR COUNSEL: whole section, see docs/release/launch-pack/instapay-terms-drafts.md -->
        <ul>
          <li><b>You are paid directly.</b> A member pays your own InstaPay
          address. Own Hub never holds or moves the money. Keep your address
          and account name exactly as your bank shows them. A new address takes
          effect after 24 hours, needs a fresh sign-in and a code sent to your
          phone, and the members with a payment waiting are told.</li>
          <li><b>Confirm honestly.</b> When a member sends proof, check your own
          bank for the exact amount and the transaction number, then confirm, or
          say it has not arrived and attach your bank&rsquo;s list for that day.
          No check can prove a payment; you are the check. If you do not answer
          in 3 days, Own Hub reviews it and the member may be given short access
          meanwhile.</li>
          <li><b>Strikes.</b> A claim that you were not paid, when your own
          statement shows the payment, is a strike. Two strikes in 90 days
          suspend your ability to take payments. Staff decide, with a written
          reason, and two staff agree before a suspension. Your current clients
          are not cut off.</li>
          <li><b>The fee.</b> It is owed when a client&rsquo;s package becomes
          active, not when you tap confirm. You get a monthly statement and pay
          Own Hub&rsquo;s fee by InstaPay and record it. More than 30 days late,
          you cannot take new clients; current clients are never cut off.</li>
          <li><b>Refunds.</b> A member may ask for a refund once in the first
          14 days. You have 3 days to answer; you send the money back by
          InstaPay and record it. After that Own Hub decides. Ignoring a staff
          decision on a refund ends your ability to take payments.</li>
          <li><b>Stay on Own Hub.</b> While you coach a client you met through
          Own Hub, and for 12 months after the last coaching on Own Hub ends,
          you may not coach her or take payment from her outside Own Hub. This
          does not apply to clients you brought with your own invite code. A
          confirmed breach is a warning and a charge of 3 months of Own
          Hub&rsquo;s share; a second is a suspension.
          <!-- [LAWYER] D64: enforceability, Civil Code Art. 224 -->
          </li>
          <li><b>Records.</b> Payment records and the evidence in a dispute are
          kept, and fraud may be reported to the authorities. The Privacy
          Policy, section 3.18, says what is kept and for how long.</li>
        </ul>

"""
```
Use the same string-join pattern as the neighbours (the section after `k9` is `h2("k10", ...)`; keep it). AR coach terms: (a) k5 bullet (about line 1707): `<li>متحطيش في البورتفوليو بيانات دفع أو طرق للوصول ليكي برّه Own Hub` becomes `<li>متحطيش في البورتفوليو طرق للوصول ليكي برّه Own Hub` and add at its end `وعنوان إنستا باي بتاعك بيتظبط من إعدادات الدفع في التطبيق بس.` (the exact continuation text of that bullet is on lines 1707-1708: read them first). (b) k6 bullet (about line 1719-1723): replace the `<li>` that starts `في الإصدار ده السعر اللي العضوات بيشوفوه فيه رسوم خدمة` with `<li>السعر اللي بتحطيه هو السعر اللي العضوات بيشوفوه وبيدفعوه، من غير أي زيادة. والعضوات بيدفعولك على طول بإنستا باي. وOwn Hub بتاخد رسوم 15 في المية من السعر لعميلة لقتك من التطبيق، و8 في المية لعميلة جبتيها بكود الدعوة بتاعك. والرسوم بتتثبت أول ما التدريب بيبدأ بينك وبين العميلة دي.</li>`. (c) k9 (about line 1747): replace heading and paragraph by the Arabic of the section above:
```python
""" + h2("k9", "9. الدفع بإنستا باي") + """
        <ul>
          <li><b>بتتدفعيلك على طول.</b> العضوة بتدفع على عنوان إنستا باي بتاعك.
          Own Hub مابتمسكش الفلوس ولا بتحرّكها. خلّي العنوان واسم الحساب زي ما
          البنك بيعرضهم بالظبط. والعنوان الجديد بيشتغل بعد 24 ساعة، وبيحتاج
          تسجيل دخول جديد وكود على تليفونك، والعضوات اللي عندهم دفع مستني
          بيتقالهم.</li>
          <li><b>أكدي بصدق.</b> لما عضوة تبعت إثبات، شوفي بنكك على المبلغ بالظبط
          ورقم العملية، وبعدين أكدي، أو قولي إنه ماوصلش وضيفي كشف البنك لليوم
          ده. مفيش فحص يقدر يثبت إن دفعة حصلت؛ إنتِ الفحص. ولو ماردتيش خلال 3
          أيام، Own Hub بتراجع، وممكن العضوة تاخد وصول مؤقت في الوقت ده.</li>
          <li><b>الإنذارات.</b> ادّعاء إنك ماتدفعيلكيش، وكشفك أنتِ بيوري الدفع،
          إنذار. وإنذارين في 90 يوم بيوقفوا قدرتك على استلام الدفع. والفريق هو
          اللي بيقرر، بسبب مكتوب، واتنين من الفريق بيوافقوا قبل أي إيقاف.
          وعميلاتك الحاليين مبيتقطعوش.</li>
          <li><b>الرسوم.</b> بتتستحق لما باقة العميلة بتبقى شغالة، مش لما بتضغطي
          «وصلتني». هيجيلك كشف شهري، وتدفعي رسوم Own Hub بإنستا باي وتسجّلي.
          ولو اتأخرتي أكتر من 30 يوم مش هتقدري تاخدي عميلات جداد؛ والعميلات
          الحاليين عمرهم ما بيتقطعوا.</li>
          <li><b>الاسترداد.</b> العضوة تقدر تطلب استرداد مرة واحدة في أول 14 يوم.
          عندك 3 أيام تردّي؛ وتبعتي الفلوس بإنستا باي وتسجّلي. وبعدها Own Hub
          بتقرر. وتجاهل قرار الفريق في استرداد بيوقف قدرتك على استلام الدفع.</li>
          <li><b>خليكي على Own Hub.</b> طول ما إنتِ بتدرّبي عميلة قابلتيها من
          خلال Own Hub، ولمدة 12 شهر بعد آخر تدريب ليها على Own Hub، مينفعش
          تدرّبيها أو تاخدي منها فلوس برّه Own Hub. ودي مبتنطبقش على عميلات
          جبتيهم بكود الدعوة بتاعك. والمخالفة المؤكدة تحذير ورسوم 3 شهور من
          نصيب Own Hub؛ والتانية إيقاف.</li>
          <li><b>السجلات.</b> سجلات الدفع والأدلة في الخلاف بتتحفظ، وممكن يتبلّغ
          عن الاحتيال للسلطات. وسياسة الخصوصية، القسم 3.18، بتقول بنحتفظ
          بإيه ولمدة قد إيه.</li>
        </ul>

"""
```
13. Build and check: `cd site/_build && python3 build.py` (UNVERIFIED how the repo runs it for a dry run: `sed -n 1,40p site/_build/deploy.sh` and `python3 site/_build/build.py --help`; do NOT run `deploy.sh`). Then run the site checks the repo has (`ls site/_build` shows no test file; search `grep -rn "pages_en" --include=*.py /Users/mahmoudreda/ownhub/functions/tests /Users/mahmoudreda/ownhub/tools 2>/dev/null | head`).

## Strings to add
None (site text is inline).

## Tests to add or change
| file | test | what |
|---|---|---|
| (command) | `no stale payment sentence remains` | `cd site && grep -rniE "no payments|nobody can pay|free for now|price includes|محدّش يقدر يدفع|مفيش مدفوعات" privacy.html terms.html coach-terms.html ar/privacy.html ar/terms.html ar/coach-terms.html` prints nothing |
| (command) | `3.18 exists in both languages and links resolve` | `grep -c 'id="c-pay"' site/privacy.html site/ar/privacy.html` prints `1` for both; `grep -c "3.18" site/privacy.html` at least 4 |
| (command) | `no drafting comment is published` | `grep -rc "LAWYER\|OWNER" site/*.html site/ar/*.html` prints 0 for every file |
| (command) | `no em dash and no Arabic-Indic digit in the new text` | `grep -n "—" ` on the new blocks prints nothing; `grep -nP "[٠-٩]"` on the new Arabic blocks prints nothing |

## Verify
- `cd site/_build && python3 build.py` exits 0 (or the repo's dry-run option) and the four greps above give the stated output.
- Open `site/privacy.html` and `site/ar/privacy.html` in the browser pane; the contents list shows 3.18; the Arabic page reads right to left.

## Do not
- Do not deploy, and do not run `deploy.sh`. Do not edit `docs/release/terms.md` or `privacy-policy.md` without asking (they may be the counsel-approved record).
- Do not remove `<!-- [LAWYER] -->` questions; do not invent a processor region: leave `UNVERIFIED-REGION` out of the built page by asking the owner (the build must fail the grep if it is left in: add `grep -rn UNVERIFIED-REGION site/_build` to your checks).
- No em dashes, no loss or guilt words, Western digits in Arabic.

## Done checklist
- [ ] EN and AR: short version, 3.15, 3.16, 3.18, section 4 card, retention rows, section 10 bullet
- [ ] EN and AR terms: 2, 9, 11, 14
- [ ] EN and AR coach terms: 5, 6, 9
- [ ] the four greps clean

## If stuck
If an anchor is not found or the build fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10q).

UNVERIFIED in this order: 5 (privacy-policy.md is generated or hand written; build dry-run command; Vision region and processor status; Arabic anchor lines; whether the terms record files are generated).
