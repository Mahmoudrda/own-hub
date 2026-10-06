# -*- coding: utf-8 -*-
"""English content for the Own Hub public site.

The legal text is taken from docs/release/privacy-policy.md, terms.md and
delete-account.md, which were written against the shipping code. The substance
is not rewritten here. Markers only the owner can fill are left as {{tokens}}
and resolved from config.json at build time.
"""

from __future__ import annotations


# ------------------------------------------------------------- helpers -----

def kv(rows) -> str:
    items = "\n".join(
        f"        <div><dt>{dt}</dt><dd>{dd}</dd></div>" for dt, dd in rows if dd
    )
    return '      <dl class="kv">\n' + items + "\n      </dl>"


def cards(items) -> str:
    out = []
    for title, rows in items:
        body = "\n".join(
            f"            <div><dt>{dt}</dt><dd>{dd}</dd></div>" for dt, dd in rows
        )
        out.append(
            "        <li>\n"
            f"          <h4>{title}</h4>\n"
            "          <dl>\n" + body + "\n          </dl>\n"
            "        </li>"
        )
    return '      <ul class="cards">\n' + "\n".join(out) + "\n      </ul>"


def h2(anchor: str, text: str, cls: str = "") -> str:
    klass = f' class="{cls}"' if cls else ""
    return (
        f'      <h2 id="{anchor}"{klass}>{text}'
        f'<a class="anchor" href="#{anchor}" aria-label="Link to this section">#</a></h2>'
    )


def h3(anchor: str, text: str) -> str:
    return (
        f'      <h3 id="{anchor}">{text}'
        f'<a class="anchor" href="#{anchor}" aria-label="Link to this section">#</a></h3>'
    )


def toc(title: str, entries) -> str:
    rows = []
    for kind, a, label in entries:
        if kind == "part":
            rows.append(f'          <li class="part">{label}</li>')
        else:
            rows.append(f'          <li><a href="#{a}">{label}</a></li>')
    return (
        '      <nav class="toc" aria-labelledby="toc-heading">\n'
        f'        <h2 id="toc-heading" class="no-rule">{title}</h2>\n'
        "        <ol>\n" + "\n".join(rows) + "\n        </ol>\n"
        "      </nav>"
    )


DELETE_SUBJECT = "Own Hub: account deletion request"

DELETE_BODY = """Hello,

I am writing about the Own Hub app, bundle id com.ownhub.app.

Please delete my Own Hub account and the data you hold about me.

The phone number on my account:

Please send the one-time code to that number so I can confirm this
request is mine.

Thank you.
"""



FORM = '''
        <form class="waitlist" action="{{waitlistEndpoint}}" method="post"
              accept-charset="utf-8">
          <input type="hidden" name="lang" value="en">
          <p class="field">
            <label for="contact">Mobile number or email</label>
            <input id="contact" name="contact" type="text" dir="ltr" required
                   maxlength="254" autocomplete="on" spellcheck="false"
                   aria-describedby="contact-hint">
            <span class="hint" id="contact-hint">An Egyptian mobile number starting 010, 011, 012 or 015, or an email address.</span>
          </p>
          <p class="hp" aria-hidden="true">
            <label for="website">Leave this empty</label>
            <input id="website" name="website" type="text" tabindex="-1"
                   autocomplete="off">
          </p>
          <p class="check">
            <input id="consent" name="consent" type="checkbox" value="yes" required>
            <label for="consent"><b>I agree.</b> We will message you once when Own Hub opens, then delete your contact.</label>
          </p>
          <div class="btn-row"><button class="btn" type="submit">Join the waitlist</button></div>
        </form>
'''


# ---------------------------------------------------------------- build ----

def build(cfg, lang, mailto_link):
    delete_button = mailto_link(
        cfg, lang, "contactPrivacy", DELETE_SUBJECT, DELETE_BODY,
        "btn", "Open a ready-made deletion email",
    )

    pages = {}

    # Download buttons, drawn only once a store link is set in config.json.
    store_links = []
    if cfg.store_url("storeUrlIos"):
        store_links.append(
            f'<a class="btn ghost" href="{cfg.store_url("storeUrlIos")}" '
            'rel="noopener">Download on the App Store</a>'
        )
    if cfg.store_url("storeUrlAndroid"):
        store_links.append(
            f'<a class="btn ghost" href="{cfg.store_url("storeUrlAndroid")}" '
            'rel="noopener">Get it on Google Play</a>'
        )
    store_row = (
        '\n        <div class="btn-row store-links" role="group" '
        'aria-label="Download Own Hub">' + "".join(store_links) + "</div>"
        if store_links else ""
    )

    # ------------------------------------------------------------ index ----
    pages["index"] = {
        "title": "Own Hub · a fitness app for women in Egypt",
        "description": (
            "Own Hub is a free fitness app for women in Egypt, and only for "
            "women. Every member is checked once, and her ID and selfie photos "
            "are never stored."
        ),
        "body": """
    <section class="wrap hero">
      <div class="hero-grid">
      <div class="prose">
        <p class="eyebrow">Fitness for women, in Egypt</p>
        <h1>Own Hub</h1>
        <p class="lede">Own Hub is a fitness app built for women in Egypt, and
        only for women. You join with your Egyptian mobile number and a code
        sent by SMS, and you are checked once, with your national ID card and a
        live selfie, so that every member is a woman. The check runs on our own
        server in Frankfurt, Germany, and the photographs of your card and your
        face are never stored. Your training and meals are kept with your
        account, so a new phone does not mean starting again. Your cycle,
        check-ins, measurements and weight stay on your phone unless you choose
        to back them up. Own Hub is free, and there is nothing in it to
        buy.</p>
        <p>Own Hub was founded by {{brandFounder}}, a woman in Egypt building
        for women in Egypt. There is no biography to read here and nothing to
        take on trust: the pages below set out exactly what the app keeps, where
        it keeps it, and for how long.</p>
        <div class="btn-row"><a class="btn" href="/waitlist">Join the waitlist</a></div>""" + store_row + """
      </div>
      <ul class="facts" aria-label="Own Hub at a glance">
        <li><b>Women only</b><span>Checked once with your national ID and a live selfie, or, if the check cannot decide, by a woman from Own Hub who contacts you to arrange it. The photos are never stored.</span></li>
        <li><b>Your health stays with you</b><span>Cycle, check-ins, measurements and weight stay on your phone unless you turn on backup yourself.</span></li>
        <li><b>One permission</b><span>The camera, for the women-only check. No photo library, no microphone, no location, no access to Apple Health or Health Connect.</span></li>
        <li><b>Free</b><span>No adverts, no purchases, no subscriptions. Nothing in it is for sale.</span></li>
        <li><b>Arabic and English</b><span>The whole app in both, right to left included.</span></li>
      </ul>
      </div>
    </section>

    <section class="wrap" aria-labelledby="inside">
      <div class="prose">
""" + h2("inside", "What is inside it") + """
        <p>Before you join, tap &ldquo;Show me around&rdquo; in the app to see
        it with a sample week. No account, and nothing is saved.</p>
      </div>
      <ul class="pillars">
        <li>
          <h3>Today</h3>
          <p>Today&rsquo;s session is waiting when you open the app, with a walk
          or a meal one tap away. What you log saves at once, and you have five
          seconds to undo it. Nothing here stops you to ask whether you are
          sure.</p>
        </li>
        <li>
          <h3>Train</h3>
          <p>A workout player that keeps your place: tap a set to log it, rest
          timers that start themselves, a swap for any move that hurts or needs
          equipment you do not own, and a way to log a whole session from memory
          if you trained without your phone.</p>
        </li>
        <li>
          <h3>Eat</h3>
          <p>Log a meal by tapping one of your usual plates, or by typing a
          sentence like &ldquo;ful and baladi bread&rdquo;. Egyptian food, under
          the names you already use for it.</p>
        </li>
        <li>
          <h3>My cycle</h3>
          <p>Period and symptom tracking, private from the start. On a hard day
          the app offers a gentler session instead of the one it planned. Your
          cycle can be deleted on its own, without touching anything else.</p>
        </li>
        <li>
          <h3>Progress</h3>
          <p>Your week, your personal bests, the milestones you have passed, and
          body measurements nobody else sees.</p>
        </li>
        <li>
          <h3>Kept for you, and only you</h3>
          <p>Once you are verified, your training and meals are kept with your
          account in Frankfurt, and no other member can see them. Your cycle and
          health information stays on your phone unless you back it up.
          Profile, then <b>Your data</b>, deletes your account and everything in
          it.</p>
        </li>
      </ul>
    </section>

    <section class="wrap" aria-labelledby="will-not">
      <div class="prose">
""" + h2("will-not", "What this app will not do") + """
        <ul>
          <li>No daily streaks. We count weeks, not days, because a real life is
          not a straight line.</li>
          <li>No calorie countdown following you around all day.</li>
          <li>Nothing ranks women by body weight or by followers.</li>
          <li>No adverts, no purchases, nothing sold.</li>
        </ul>

        <div class="callout quiet">
          <p><b>What is not in this version.</b> There is no community and no
          coaching: nothing in the app connects you to another member. There is
          no assistant. To get a copy of your data, ask from Profile, then Your
          data, and we send it to you.</p>
        </div>

        <p>The app is in Arabic and English, right to left included. You can
        change the language from Profile, then Language, at any time.</p>
      </div>
    </section>

    <section class="wrap" aria-labelledby="doors">
      <div class="prose">
""" + h2("doors", "The rest of this site") + """
      </div>
      <ul class="doorways">
        <li><a href="/privacy"><span class="t">Privacy Policy</span><span class="d">What the app collects, where it is kept, and why your ID and selfie photos are never stored.</span></a></li>
        <li><a href="/terms"><span class="t">Terms of Use</span><span class="d">What Own Hub is, what it is not, and the medical warning worth reading even if you skip the rest.</span></a></li>
        <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person, the hours messages are read, and answers to the things women write in about.</span></a></li>
        <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to delete your account from inside the app, and how to ask without installing it.</span></a></li>
      </ul>
    </section>
""",
    }

    # ---------------------------------------------------------- privacy ----
    # Privacy Policy v3.0 (compliance plan, 6 October 2026). No drafting note
    # is published, not even as an HTML comment: build.py strips any that
    # slips in. A value only the owner can supply is a {{token}} from
    # config.json. The owner publishes without a draft banner; legal review
    # happens on the published text.
    draft_banner = ""

    privacy_toc = toc("On this page", [
        ("a", "short-version", "The short version"),
        ("a", "who-we-are", "1. Who is responsible for your data"),
        ("a", "who-can-use", "2. Who can use Own Hub, and why it is for women only"),
        ("a", "collect", "3. What we collect, why, and on what basis"),
        ("a", "where", "4. Who handles your data, and where"),
        ("a", "transfers", "5. Transfers outside Egypt"),
        ("a", "retention", "6. How long we keep it"),
        ("a", "deletion", "7. Deleting your account"),
        ("a", "rights", "8. Your rights"),
        ("a", "security", "9. Security"),
        ("a", "does-not", "10. What Own Hub does not do"),
        ("a", "children", "11. Children"),
        ("a", "changes", "12. Changes to this policy"),
        ("a", "language", "13. Language"),
        ("a", "contact", "14. Contact"),
    ])

    who_rows = [
        ("Controller", "{{legalEntity}}, an individual publishing Own Hub in his own "
                       "name. He is personally responsible for complying with the law."),
        ("Address", "{{legalAddress}}"),
        ("Privacy contact", "{{mailto:contactPrivacy}}"),
        ("Personal Data Protection Centre permit", "{{pdpcPermit}}"),
    ]
    if cfg.plain("commercialRegistration", lang):
        who_rows.append(("Commercial registration", "{{commercialRegistration}}"))
    if cfg.plain("dataProtectionOfficer", lang):
        who_rows.append(("Data protection officer", "{{dataProtectionOfficer}}"))

    pages["privacy"] = {
        "title": "Privacy Policy · Own Hub",
        "description": (
            "How Own Hub handles your phone number, the women-only check, and "
            "your training, meals and health information. ID and selfie photos "
            "are never stored, and nothing is used to train AI."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Privacy Policy</h1>
        <p class="meta">
          <b>Version:</b> 3.0<br>
          <b>Effective date:</b> {{policyEffectiveDate}}<br>
          <b>Applies to:</b> Own Hub for iOS and Android, bundle id
          <code>com.ownhub.app</code>, and this website.
        </p>
        <p>If the English and Arabic versions of this policy differ, the Arabic
        version applies.</p>
""" + draft_banner + """
""" + privacy_toc + """

""" + h2("short-version", "The short version", "no-rule") + """
        <div class="callout calm">
          <ul>
            <li>Own Hub is a fitness app for women in Egypt aged 18 and over.
            Membership is for women only, for women&rsquo;s safety and privacy.
            To keep it that way, we check your Egyptian national ID card and a
            live selfie once, when you join.</li>
            <li><b>The photographs of your card and your face are never
            stored.</b> Our server in Frankfurt, Germany reads them in memory
            and discards them when the check ends. We keep the result for 180
            days. We also keep a keyed code made from your ID number, so that
            one card cannot open two accounts.</li>
            <li><b>Your cycle, check-ins, measurements, weight, pregnancy or
            postpartum stage and allergies stay on your phone,</b> unless you
            turn on health backup yourself.</li>
            <li>Once you are verified, your workouts and meals are copied to
            Google Cloud in Frankfurt, so a new phone does not mean starting
            again. No other member can see them.</li>
            <li>To send your sign-in code, your phone number goes to Google
            Firebase in the United States.</li>
            <li>We do not sell your data. There are no adverts, no tracking and
            no analytics. Crash reports are sent only if you allow them.</li>
            <li><b>We never use your data to train AI, ours or anyone&rsquo;s.</b></li>
            <li>You can delete your account in the app at any time, and ask us
            for a copy of your data.</li>
          </ul>
        </div>

""" + h2("who-we-are", "1. Who is responsible for your data") + """
""" + kv(who_rows) + """
        <p>{{brandFounder}} is Own Hub&rsquo;s founder and coach, and the face
        of the brand. She is not the controller of your data and has no access
        to your account data.</p>
        <p>The women who review verification cases act on the
        controller&rsquo;s instructions and are bound by a written
        confidentiality agreement.</p>

""" + h2("who-can-use", "2. Who can use Own Hub, and why it is for women only") + """
        <p>Own Hub is for women aged 18 or over who hold an Egyptian national
        ID card. It is a women-only space for one reason: so that women in
        Egypt can train, follow their bodies and their cycles, and look after
        their health somewhere they feel safe and their privacy is protected.
        This reflects the Constitution&rsquo;s protection of women, of private
        life, of health and of everyone&rsquo;s right to sport (Articles 11, 18,
        57, 59 and 84). It is not a judgement about anyone else.</p>
        <p>Your sex and your age are read from the digits of your national ID
        number. We never guess them from your face.</p>
        <p>We do not knowingly collect data from anyone under 18. If the check
        shows that you are under 18, your application is refused. The refusal
        is kept as section 6 describes.</p>

""" + h2("collect", "3. What we collect, why, and on what basis") + """
        <p>Each basis below is one that Egypt&rsquo;s Personal Data Protection
        Law allows (Law 151/2020, Articles 2, 6 and 12).</p>
""" + h3("c-account", "3.1 Your account") + """
        <ul>
          <li><b>Your mobile number.</b> Used to create your account and sign
          you in with a code sent by SMS, and to phone you if you ask a woman
          reviewer to check you.</li>
          <li><b>An account identifier we generate.</b> Used to link your data
          to your account.</li>
          <li><b>Your language, settings and setup answers.</b> This covers your
          privacy switches, notification preferences and quiet hours, your
          goal, where you train, your equipment, your training days and
          minutes, and your dietary preferences. Used to run the app the way
          you set it.</li>
          <li><b>Basis:</b> performing our agreement with you (the Terms of
          Use).</li>
        </ul>

""" + h3("c-agreements", "3.2 Your agreements") + """
        <p>When you sign up, we record which versions of the Terms of Use and
        this policy you accepted, in which language, from which app version,
        and when. We keep a similar record for each separate consent you give:
        the identity check, health backup and a review by a woman.</p>
        <ul>
          <li><b>Basis:</b> a legal obligation. The Executive Regulations of the
          Personal Data Protection Law require us to keep a record of each
          consent, with its date and form.</li>
        </ul>

""" + h3("c-check", "3.3 Checking that you are a woman aged 18 or over") + """
        <p>This happens once, when you join, and only after you have read a
        separate screen and agreed to it. The camera does not start until our
        server has recorded that agreement. The camera is the only way to take
        the photographs: the app cannot upload a picture that is already on
        your phone.</p>
        <ul>
          <li><b>Photographs of the front and back of your ID card.</b> Sent
          over an encrypted connection to our server in Frankfurt, Germany.
          Google Cloud Vision reads the text on the card through its European
          Union endpoint. The images are not stored anywhere.</li>
          <li><b>A short live selfie,</b> taken while you follow prompts chosen
          by our server. It checks that a live person is present and that the
          face matches the portrait on the card. The comparison runs on our own
          server, with no outside face recognition service. We do not store the
          selfie or any face measurement.</li>
          <li><b>Your national ID number.</b> Used to confirm your sex (from the
          digit the Civil Status authority sets in the number) and your age
          (from the birth date encoded in it). It is then turned into a one-way
          keyed code, with a secret key held separately in Google Secret
          Manager. The number itself is not stored.</li>
          <li><b>Your name and date of birth</b> as printed on the card. Read
          only to cross-check the number, and not stored.</li>
          <li><b>The result:</b> approved, refused, or sent to a woman reviewer.
          It comes with reason codes, coarse score bands (never raw scores),
          the attempt number and the dates. The app shows you whether your
          check is pending, approved, refused or ready to try again.</li>
          <li><b>Fraud signals:</b> a count of failed attempts for each ID
          code; and a scrambled code for the app installation, together with
          the last ID codes tried from it, so that one installation trying many
          cards can be noticed.</li>
          <li><b>Basis:</b> your explicit consent, given in writing on the
          screen before the camera opens. The face match is biometric data,
          which the law treats as sensitive. Because a face match is sensitive
          data, the law also requires a permit from the Personal Data
          Protection Centre. Ours is shown in section 1.</li>
          <li>You can refuse. If you do, you can still ask a woman reviewer to
          check you (section 3.4). Without a check you cannot open a verified
          account, because a women-only membership is the purpose of the
          service.</li>
        </ul>

""" + h3("c-review", "3.4 Review by a woman") + """
        <p>Your case goes to a woman reviewer in four situations: the automatic
        check is unsure; you wear niqab and prefer a woman reviewer; you
        decline the camera; or the check cannot run for a technical
        reason.</p>
        <ul>
          <li><b>Your request.</b> When you ask for this, we record your request
          and the route you chose (section 3.2).</li>
          <li><b>The queue.</b> The review queue holds reason codes and score
          bands. It never holds a photograph or your phone number.</li>
          <li><b>The contact.</b> A woman from Own Hub reviews your case. When
          she is ready to contact you, she looks up your number at that moment.
          Each lookup is recorded with the reviewer and the time. She phones you
          within 72 hours of your request to finish your check with you. There
          is no video call.</li>
          <li><b>Nothing is recorded.</b> The check is not recorded, and the
          reviewer writes down only her decision and the date.</li>
          <li><b>Your ID number.</b> If your case has no ID code yet, the
          reviewer may ask you to read out your ID number. It is turned into
          the keyed code at once, and is never stored or written to a log.</li>
          <li><b>Our team&rsquo;s alert.</b> When a case enters the queue, our
          team gets an alert containing only the case number and the reason
          codes. It is sent through {{chatService}}.</li>
          <li><b>Basis:</b> your consent, given when you ask for the review.</li>
        </ul>

""" + h3("c-training", "3.5 Your training and meals") + """
        <p>Workouts, sets, weights and repetitions, weekly goals, personal
        bests, the meals you log, your usual plates, your protein target and
        your meal plans stay on your phone. Once your account is verified, a
        copy is also kept in Google Cloud Firestore in Frankfurt, Germany, so
        that it survives a lost or replaced phone. Server security rules let
        only your own verified account read it. No other member can see
        it.</p>
        <p>Your Ramadan setting stays on your phone only.</p>
        <p>If you add an Own Hub widget to your Home Screen or Lock Screen, it
        shows how many sessions you have done this week, whether today&rsquo;s
        workout is done and whether you have logged a meal, and nothing else.
        The widget reads this from your phone. It never shows your cycle,
        pregnancy or postpartum stage, weight, measurements or allergies, and
        nothing is sent anywhere. Signing out or deleting your account clears
        it.</p>
        <ul>
          <li><b>Basis:</b> performing our agreement with you.</li>
        </ul>

""" + h3("c-health", "3.6 Your health information stays on your phone") + """
        <p>By default, these are kept on your phone only: your cycle settings
        and period days; your daily check-ins (for example energy, sleep,
        bloating, pain and bleeding); your body measurements and weight; your
        life stage (pregnancy, postpartum or training around an injury); and
        the allergies you tell us about.</p>
        <p>You can choose to back them up. In <b>Profile</b>, then
        <b>Privacy</b>, <b>Back up my health data</b> asks for a separate
        consent. That consent names this information and the countries where
        it would be stored. Nothing is copied until our server has recorded
        the consent, and our server&rsquo;s security rules refuse the copy
        without it. If you turn backup off, we delete the copy on our servers
        straight away. The copy on your phone stays.</p>
        <p><b>Your cycle and health information is never used for advertising
        or marketing, never sold, never sent to any analytics service, and
        never used to train AI.</b></p>
        <ul>
          <li><b>Basis:</b> your explicit consent, given in writing in the
          app, which the law requires for health data, and our permit from the
          Centre (section 1).</li>
        </ul>

""" + h3("c-technical", "3.7 Technical data") + """
        <ul>
          <li><b>Sign-in security.</b> When you sign in, Google Firebase
          Authentication receives your IP address and device details. To stop
          abuse of text messages, Firebase may confirm that the request comes
          from a real device, using Google Play Integrity, an Apple push
          notification, or a reCAPTCHA check page.</li>
          <li><b>Genuine-app check.</b> From the first time you open the app,
          Firebase App Check uses Google Play Integrity (Android) or Apple App
          Attest (iOS) to confirm that requests come from the real Own Hub app.
          Firebase gives the installation a random identifier for this.</li>
          <li><b>Selfie guidance.</b> Google ML Kit detects your face on the
          phone to guide the selfie camera. Your images do not leave the phone
          through ML Kit. ML Kit sends Google the device model, operating
          system, app version, an installation identifier and performance
          events.</li>
          <li><b>Crash reports, only if you allow them.</b> You can allow them
          on the sign-up screen, or later in Profile, then Privacy. They are off
          until you do. What Firebase Crashlytics receives when the app
          crashes: the type of error and where in the code it happened, your
          device model, operating system, app version, free memory and storage,
          and an installation identifier. What is never attached: your account
          identifier, your name or your phone number. If you turn them off,
          reports waiting on your phone are deleted.</li>
          <li><b>Our server logs.</b> These record outcomes and reason codes.
          They never record your phone number or your ID number, and they never
          place your account identifier beside an outcome.</li>
          <li><b>Basis:</b> keeping the service secure and working, which the
          law allows (Law 151/2020, Article 6, point 4), except crash reports,
          which need your consent. ML Kit runs only on the selfie screen, after
          you have agreed to the check.</li>
        </ul>

""" + h3("c-ai", "3.8 Artificial intelligence") + """
        <ul>
          <li><b>We never use your data to train AI models, ours or
          anyone&rsquo;s.</b></li>
          <li>Google Cloud Vision reads the text on your ID card only to run the
          check. It reads the card in memory and does not keep the image. Under
          Google Cloud&rsquo;s terms, Google may not use that data to train its
          own models.</li>
          <li>The face comparison uses open-source models that run on our own
          server. Their authors trained them before Own Hub existed. They are
          not trained or adjusted with your face.</li>
          <li>There is no AI assistant in this version of Own Hub. If we add
          one, we will ask for your separate agreement first, naming the
          provider, before anything is sent to it.</li>
        </ul>

""" + h3("c-messages", "3.9 Messages you send us") + """
        <p>If you write to us, we keep your message and your email address so
        that we can answer you. These are deleted {{supportRetention}} after the
        conversation ends.</p>

""" + h3("c-waitlist", "3.10 The waitlist and this website") + """
        <p><b>If you joined the waitlist on this website,</b> we keep the mobile
        number or email address you gave, the language you chose, your
        agreement and the date you joined.</p>
        <ul>
          <li>We use it for one thing: to message you once when Own Hub opens.
          Then we delete it.</li>
          <li>If that has not happened, it is deleted automatically 180 days
          after you joined.</li>
          <li>So that we can prove you agreed, we keep a keyed code made from
          your contact, the version of the wording you agreed to, and the date,
          for 3 years after the last message we send you.</li>
          <li>To protect the form from abuse, we keep a keyed code made from
          your internet address (never the address itself) and a count of
          attempts from it. Both are deleted after two days.</li>
          <li>It is all stored in Google Cloud Firestore in Frankfurt,
          Germany. To leave the waitlist sooner, write to
          {{mailto:contactPrivacy}}.</li>
        </ul>
        <p><b>This website</b> sets no cookies, runs no scripts and counts no
        visits. The company that hosts it, listed in section 4, receives the
        standard data any website receives, such as your IP address and browser type, in
        order to deliver the pages.</p>

""" + h2("where", "4. Who handles your data, and where") + """
        <p>We do not sell your data, and we do not share it with advertisers,
        data brokers or marketing companies. The service providers below
        process data only on our instructions. Google processes data for us
        under the Google Cloud Data Processing Addendum and the Firebase Data
        Processing and Security Terms.</p>
""" + cards([
            ("Google Firebase Authentication", [
                ("Handles", "Your phone number, IP address and device details"),
                ("Where", "United States"),
            ]),
            ("Your mobile operator and Google&rsquo;s SMS partners", [
                ("Handles", "Your phone number and the sign-in code"),
                ("Where", "Egypt, and the route Google uses"),
            ]),
            ("Google Cloud Firestore, Cloud Functions, Cloud Storage and Secret Manager", [
                ("Handles", "Your account, training and meals, health "
                            "information if you turn on backup, verification "
                            "results and the keyed ID code"),
                ("Where", "Frankfurt, Germany (europe-west3)"),
            ]),
            ("Google Cloud Vision", [
                ("Handles", "The text on your ID card, during the check only"),
                ("Where", "European Union"),
            ]),
            ("Google Play Integrity, Apple App Attest, reCAPTCHA, Firebase App Check", [
                ("Handles", "Confirmation that the app and the device are genuine"),
                ("Where", "Google data centres worldwide, which include the "
                          "United States, and Apple servers for App Attest"),
            ]),
            ("Google ML Kit", [
                ("Handles", "Device and performance data (section 3.7)"),
                ("Where", "Google data centres worldwide, which include the "
                          "United States"),
            ]),
            ("Firebase Crashlytics, only if you allow it", [
                ("Handles", "Crash data (section 3.7)"),
                ("Where", "Google data centres worldwide, which include the "
                          "United States"),
            ]),
            ("{{cap:chatService}}", [
                ("Handles", "A case number and reason codes only"),
                ("Where", "{{chatServiceRegion}}"),
            ]),
            ("{{cap:emailProvider}}", [
                ("Handles", "Messages you send us"),
                ("Where", "{{emailProviderRegion}}"),
            ]),
            ("{{cap:hostingProvider}}", [
                ("Handles", "Standard website request data"),
                ("Where", "{{hostingProviderRegion}}"),
            ]),
        ]) + """
        <p>We may also disclose data where Egyptian law requires it, for
        example in answer to a lawful order from a court or a competent
        authority. If Own Hub is ever transferred to another publisher, we will
        tell you in the app before it happens, ask for your consent where the
        law requires it, and the new publisher will need its own permit from
        the Personal Data Protection Centre.</p>

""" + h2("transfers", "5. Transfers outside Egypt") + """
        <p>Your data is stored and processed outside Egypt:</p>
        <ul>
          <li><b>Germany and the European Union:</b> your account, your training
          and meals, any health backup, and your verification.</li>
          <li><b>The United States:</b> your phone number, for sign-in.</li>
          <li><b>Google data centres worldwide, which include the United
          States:</b> the device checks, ML Kit performance data, and crash
          reports if you allow them. Google does not let us choose one country
          for these.</li>
        </ul>
        <p>Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020 allows
        transfers abroad only under a permit from the Personal Data Protection
        Centre, and with your consent. We ask for that consent on
        the sign-up screen, naming these countries, before your phone number is
        sent. We ask again, separately, before any health information is backed
        up.</p>
        <p>Permit: {{pdpcPermit}}</p>
        <p>Safeguards: {{transferCountries}}</p>

""" + h2("retention", "6. How long we keep it") + """
""" + kv([
            ("ID card photographs, selfie, name and date of birth from the card, your raw ID number",
             "Never stored. Discarded from memory when the check ends, whatever the result."),
            ("The single-use selfie session", "5 minutes, then deleted automatically"),
            ("Verification result and review case",
             "180 days after the case is decided, or earlier if you delete your "
             "account. A case still waiting for review is kept until it is decided."),
            ("The keyed code of your ID number",
             "While your account exists. After you delete your account it is "
             "closed, not deleted: it is no longer linked to any account, it is "
             "kept with no end date, and the same card cannot be used to open a "
             "new account."),
            ("Count of failed attempts per ID code, and the scrambled installation record",
             "180 days after the last attempt. Not linked to your account."),
            ("Reviewer access log (which reviewer opened which case, and when)",
             "1 year. It holds no photograph, phone number or ID number."),
            ("Your account, settings, training, meals, any health backup and your consent records",
             "Until you delete them or delete your account"),
            ("The record that a deletion was carried out (status and dates only)",
             "{{deletionRecordRetention}}, as proof that your request was honoured"),
            ("Daily totals of verifications, with no link to any person", "Kept"),
            ("Our server logs", "{{serverLogRetention}}"),
            ("Crash reports, if you allow them", "{{crashReportRetention}}"),
            ("Messages you send us", "{{supportRetention}}"),
            ("Waitlist contact",
             "180 days at most. The proof that you agreed is kept for 3 years "
             "after the last message we send you (section 3.10)."),
            ("Backups held by Google", "Removed within about 6 months (180 days) of deletion"),
        ]) + """

""" + h2("deletion", "7. Deleting your account") + """
        <p><b>In the app:</b> <b>Profile</b>, then <b>Your data</b>, then
        <b>Delete everything</b>. You do not need to be verified to do
        this.</p>
        <ul>
          <li>Our server locks your sign-in first.</li>
          <li>It then deletes your account and the data in section 3, and
          deletes your sign-in record, including your phone number, last.</li>
          <li>Your phone is cleared at the same time.</li>
          <li>It usually takes under a minute. If anything interrupts it, it
          finishes on its own within the hour.</li>
        </ul>
        <p><b>Without the app:</b> use the
        <a href="/delete-account">deletion page</a> on this website. It
        explains how to ask by email. We confirm that the request comes from
        the owner of the number on the account ({{deletionVerifyMethod}}), then
        delete within {{deletionWindow}} and confirm in writing.</p>
        <p><b>What remains after deletion, on purpose:</b></p>
        <ul>
          <li>the closed keyed code of your ID number (section 6);</li>
          <li>the failed-attempt count and the installation record, until their
          180 days end, linked to no account;</li>
          <li>reviewer access log entries for your case, until their year
          ends;</li>
          <li>the record that the deletion was carried out.</li>
        </ul>
        <p>Crash reports and ML Kit data are never linked to your account.
        Google deletes them on its own schedule.</p>
        <p><b>Deleting only part of your data:</b></p>
        <ul>
          <li>turn off health backup (this deletes the cloud copy);</li>
          <li>delete your cycle data on its own, from cycle settings;</li>
          <li>remove items from a day&rsquo;s log, and delete individual
          measurements.</li>
        </ul>

""" + h2("rights", "8. Your rights") + """
        <p>Under Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020, you
        have the right to:</p>
        <ul>
          <li>know what personal data we hold about you, and get a copy of
          it;</li>
          <li>have it corrected or completed;</li>
          <li>have it erased;</li>
          <li>withdraw your consent at any time, without affecting processing
          that took place before. You can turn off crash reports and health
          backup yourself in Profile, then Privacy;</li>
          <li>object to processing, or ask us to restrict it;</li>
          <li>be told of any breach of your personal data.</li>
        </ul>
        <p><b>A copy of your data:</b></p>
        <ul>
          <li>How to ask: in the app (<b>Profile</b>, then <b>Your data</b>, then
          <b>Ask for a copy</b>), or write to {{mailto:contactPrivacy}}.</li>
          <li>What you get: a file a computer can read, plus a summary in your
          language.</li>
          <li>How you get it: {{exportDelivery}}.</li>
          <li>Health information that is only on your phone is not held by us.
          You can see it in the app.</li>
        </ul>
        <p><b>Response time:</b> we answer every request within
        {{rightsResponseWindow}}. Requests are free.</p>
        <p><b>Complaints:</b> if you are not satisfied with our answer, you can
        complain to Egypt&rsquo;s Personal Data Protection Centre:
        {{pdpcContact}}</p>

""" + h2("security", "9. Security") + """
        <ul>
          <li>Sign-in uses a one-time code sent to your phone. There is no
          password to steal.</li>
          <li>Data travels over encrypted connections, and Google encrypts it
          where it is stored.</li>
          <li>Server rules let your account read only your own data, and the app
          cannot mark itself as verified. Only our server can do that.</li>
          <li>We never write verification images to disk, logs or
          storage.</li>
          <li>The secret key behind the ID code is held in Google Secret
          Manager, separate from the database.</li>
          <li>Access to our systems is limited to the people who run Own Hub,
          and every lookup of a phone number for a review is recorded.</li>
          <li>No system is perfectly secure. If a breach affects your personal
          data, we will notify the Personal Data Protection Centre within 72
          hours of becoming aware of it, and tell you within three working days
          after that, by SMS or email.</li>
          <li>The publisher, who runs Own Hub&rsquo;s systems, can technically
          reach stored data. He opens an individual account&rsquo;s data only
          to answer your request, to fix a fault, to investigate misuse, or when
          the law requires it.</li>
        </ul>

""" + h2("does-not", "10. What Own Hub does not do") + """
        <ul>
          <li>No adverts, no advertising identifiers, and no tracking across
          other apps or websites.</li>
          <li>No analytics software.</li>
          <li>No sale of your data.</li>
          <li>No training of AI on your data.</li>
          <li>No access to your contacts, location, photo library, microphone,
          text messages, or Apple Health or Health Connect. The app itself
          never uses your microphone, and there is no video review.</li>
          <li>Nothing that guesses your sex, age or anything else about you from
          your face.</li>
        </ul>

""" + h2("children", "11. Children") + """
        <p>Own Hub is not for anyone under 18. We do not knowingly keep data
        about children. If you believe a child has an account, write to us and
        we will delete it.</p>

""" + h2("changes", "12. Changes to this policy") + """
        <p>We publish every change here, with its date and version.</p>
        <ul>
          <li><b>Material changes</b> require your agreement in the app before
          they apply to you. A material change is one that collects something
          new, uses your data for a new purpose, adds a new country or a new
          kind of provider, or reduces your rights.</li>
          <li><b>Other changes</b> are announced in the app.</li>
        </ul>
        <p>Version history:</p>
        <ul>
          <li><b>3.0, minor update:</b> section 3.5 now describes the Own Hub
          widgets. They collect nothing new, so you are not asked to accept
          again.</li>
          <li><b>3.0, {{policyEffectiveDate}}:</b> acceptance recorded at
          sign-up, crash reports by consent, AI statement, full retention
          periods, copy of your data on request.</li>
          <li><b>2.0, 24 September 2026:</b> accounts and the women-only
          check.</li>
        </ul>

""" + h2("language", "13. Language") + """
        <p>This policy is published in Arabic and English. If they differ, the
        Arabic version applies.</p>

""" + h2("contact", "14. Contact") + """
        <p>{{mailto:contactPrivacy}} &middot; {{legalEntity}}, {{legalAddress}}</p>
      </div>
    </div>
""",
    }

    # ------------------------------------------------------------ terms ----
    terms_toc = toc("On this page", [
        ("a", "t1", "1. Who you are agreeing with, and how"),
        ("a", "t2", "2. What Own Hub is, in this version"),
        ("a", "t3", "3. Who may use it, and why it is for women only"),
        ("a", "t4", "4. Own Hub is not medical advice"),
        ("a", "t5", "5. Allergies and food"),
        ("a", "t6", "6. Your account and your data"),
        ("a", "t7", "7. What you may not do"),
        ("a", "t8", "8. What you make is yours"),
        ("a", "t9", "9. Free"),
        ("a", "t10", "10. Ending it"),
        ("a", "t11", "11. The app is provided as it is"),
        ("a", "t12", "12. Later features"),
        ("a", "t13", "13. Limits on what we owe you"),
        ("a", "t14", "14. Changes to these Terms"),
        ("a", "t15", "15. Law, disputes and language"),
        ("a", "t16", "16. Apple and Google"),
        ("a", "t17", "17. The rest"),
        ("a", "t18", "18. Contact"),
    ])

    pages["terms"] = {
        "title": "Terms of Use · Own Hub",
        "description": (
            "The terms for using Own Hub: a free fitness app for women in "
            "Egypt, with a women-only account, no community, no coaching and "
            "nothing to buy. Not a medical device."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Terms of Use</h1>
        <p class="meta">
          <b>Version:</b> 3.0<br>
          <b>Effective date:</b> {{policyEffectiveDate}}<br>
          <b>Applies to:</b> Own Hub for iOS and Android, bundle id
          <code>com.ownhub.app</code>.
        </p>
        <p>If the English and Arabic versions of these Terms differ, the Arabic
        version applies.</p>
""" + draft_banner + """
""" + terms_toc + """

""" + h2("t1", "1. Who you are agreeing with, and how", "no-rule") + """
        <ul>
          <li>Own Hub was founded by {{brandFounder}}. It is published and
          developed by {{legalEntity}}, {{legalAddress}}.</li>
          <li>In these Terms, &ldquo;we&rdquo; and &ldquo;us&rdquo; mean that
          publisher, and &ldquo;you&rdquo; means the person using the app.</li>
          <li>Contact: {{mailto:contactSupport}}</li>
          <li><b>How you accept:</b> by tapping &ldquo;Agree and send me a
          code&rdquo; when you sign up. Before you tap, the screen links to
          these Terms and to the Privacy Policy. We record the version you
          accepted, the language, the app version and the time. If you do not
          accept, do not create an account. We keep this record securely, so it
          can show what you accepted and when.</li>
        </ul>

""" + h2("t2", "2. What Own Hub is, in this version") + """
        <ul>
          <li><b>A fitness app for women in Egypt.</b> You can follow workouts,
          log what you train and eat, set a weekly goal, track measurements you
          enter yourself, and record your menstrual cycle.</li>
          <li><b>You need an account, and you are checked once.</b> You sign up
          with your Egyptian mobile number and a code sent by SMS. There is no
          password, and there is no profile that anyone else can see.</li>
          <li><b>It is free.</b> There are no adverts, no in-app purchases, no
          subscriptions and no payments of any kind.</li>
          <li><b>What is not in this version:</b> no community, no coaching and
          no AI assistant. Nothing in the app connects you to another person.
          If any of these arrives, it will come in a later version, with
          updated Terms that you will be asked to accept.</li>
        </ul>

""" + h2("t3", "3. Who may use it, and why it is for women only") + """
        <ul>
          <li>Own Hub is for women aged 18 or over who hold an Egyptian national
          ID card. It is a women-only space for one reason: so that women in
          Egypt can train, follow their bodies and their cycles, and look after
          their health somewhere they feel safe and their privacy is protected.
          This reflects the Constitution&rsquo;s protection of women, of private
          life, of health and of everyone&rsquo;s right to sport (Articles 11,
          18, 57, 59 and 84). It is not a judgement about anyone else.</li>
          <li>You must be a woman aged 18 or over who holds an Egyptian national
          ID card.</li>
          <li>If you are 18, 19 or 20: Egyptian civil law gives full contractual
          capacity at 21. Own Hub is free and asks nothing of you in money, and
          nothing in these Terms takes away any right the law gives you because
          of your age.</li>
          <li><b>How membership is confirmed:</b> once, when you join. Your sex
          and age are read from your national ID number. A live selfie is
          compared with the portrait on your card. If the automatic check
          cannot decide, or you choose the niqab route, a woman from Own Hub
          reviews your case and contacts you by phone within 72 hours to finish
          your check. The photographs of your
          card and your face are never stored. We never guess your sex or your
          age from your face.</li>
          <li>One account per person. You may not use anyone else&rsquo;s
          identity documents, or let anyone else use your account.</li>
        </ul>

""" + h2("t4", "4. Own Hub is not medical advice") + """
        <p><b>Read this section even if you skip the rest.</b></p>
        <ul>
          <li>Own Hub is a fitness and wellbeing app. <b>It is not a medical
          device.</b> It does not diagnose, treat, cure or prevent any
          condition, and it is not a substitute for a doctor.</li>
          <li>Workouts, meal suggestions, calorie and macro figures, and
          anything the app shows about your cycle are general guidance, not
          prescriptions. Cycle dates are estimates.</li>
          <li><b>Talk to a doctor before you start</b>, especially if any of
          these apply to you: you are pregnant or have recently given birth;
          you have a heart, joint, bone or blood-pressure condition, diabetes,
          or an eating disorder; you are recovering from surgery or an injury;
          you take medication that affects exercise.</li>
          <li>Stop exercising if something hurts, and get medical help if you
          need it. The app never penalises you for stopping or resting.</li>
          <li>Where the app shows guidance about severe symptoms, it is telling
          you to seek care, not treating you. In an emergency, contact
          emergency services or go to a hospital.</li>
        </ul>

""" + h2("t5", "5. Allergies and food") + """
        <p>The app refuses to say a dish is safe when it cannot tell. You are
        still responsible for checking what you eat. Nothing in the app
        replaces reading a label or asking whoever cooked it.</p>

""" + h2("t6", "6. Your account and your data") + """
        <ul>
          <li>Your account is tied to your mobile number, so keep your phone and
          SIM card safe. Anyone who can unlock your phone can open the
          app.</li>
          <li>The <a href="/privacy">Privacy Policy</a> explains what we keep,
          where, and for how long.</li>
          <li><b>Deleting:</b> you can delete your account and data at any time,
          from Profile, then Your data. Deletion cannot be undone.</li>
          <li><b>A copy of your data:</b> ask from the same place, or by email.
          We send it as the Privacy Policy describes.</li>
        </ul>

""" + h2("t7", "7. What you may not do") + """
        <p>You may not:</p>
        <ul>
          <li>defeat or try to defeat the women-only check;</li>
          <li>use someone else&rsquo;s ID card or face;</li>
          <li>scrape the app, access it automatically, reverse engineer it, or
          test its security without our written permission;</li>
          <li>reach features that are switched off;</li>
          <li>redistribute the app, its exercise library or its food data as
          your own;</li>
          <li>use Own Hub for anything illegal under Egyptian law.</li>
        </ul>

""" + h2("t8", "8. What you make is yours") + """
        <p>What you log is yours, and we do not claim ownership of it. We keep
        a copy only to provide the service, as the Privacy Policy describes.
        The app&rsquo;s content (exercise instructions, programmes, recipes,
        food data, design) belongs to us or to the people who licensed it to
        us.</p>

""" + h2("t9", "9. Free") + """
        <p>The app is free. If a future version adds anything paid, it will
        come with its own terms, shown before anything is charged, and nothing
        will renew without your clear agreement.</p>

""" + h2("t10", "10. Ending it") + """
        <ul>
          <li><b>You</b> can stop at any time by deleting your account. Deleting
          the app alone does not delete your account.</li>
          <li><b>We</b> may suspend or close an account that breaks section 3 or
          section 7. Before we do, we tell you why and give you a chance to
          reply, unless the law, an order from an authority or someone&rsquo;s
          safety prevents it. You keep your right to a copy of your data.</li>
        </ul>

""" + h2("t11", "11. The app is provided as it is") + """
        <p>We work to keep Own Hub accurate and available, but we do not
        promise that it is free of errors, that it will always be available, or
        that any particular result will follow from using it.</p>

""" + h2("t12", "12. Later features") + """
        <p>Community, coaching, an AI assistant and payments are not part of
        this version. Each will come with its own rules, published with the
        release that switches it on, and you will be asked to accept them
        before you use it.</p>

""" + h2("t13", "13. Limits on what we owe you") + """
        <ul>
          <li>We are not responsible for injury, illness or loss that results
          from exercise you chose to do, food you chose to eat, or following
          general guidance in the app instead of seeing a doctor.</li>
          <li>Because Own Hub is free, we are responsible for harm caused by our
          fraud or gross negligence, and for anything else Egyptian law makes us
          responsible for whatever these Terms say.</li>
          <li>Nothing in these Terms limits our responsibility for fraud, gross
          negligence or harm caused outside this agreement, or reduces any right
          you have under the Consumer Protection Law.</li>
        </ul>

""" + h2("t14", "14. Changes to these Terms") + """
        <ul>
          <li><b>Material changes:</b> we ask you to accept them in the app
          before they apply to you. If you do not accept, you can delete your
          account.</li>
          <li><b>Other changes:</b> we publish them here with the date and tell
          you in the app.</li>
          <li>Continuing to use the app alone never counts as accepting a
          material change.</li>
        </ul>

""" + h2("t15", "15. Law, disputes and language") + """
        <ul>
          <li>These Terms are governed by the laws of the Arab Republic of
          Egypt.</li>
          <li>Disputes go to {{courtVenue}}.</li>
          <li>These Terms are published in Arabic and English, and the Arabic
          version applies if they differ.</li>
          <li>Own Hub is made for, and offered in, Egypt.</li>
        </ul>

""" + h2("t16", "16. Apple and Google") + """
        <ul>
          <li>These Terms are between you and the publisher only, not Apple or
          Google. The publisher alone, not Apple, is responsible for the app and
          its content, its maintenance and support, any product claims, and any
          claim that the app infringes someone else&rsquo;s rights.</li>
          <li>You get a personal, non-transferable licence to use the app on
          Apple devices you own or control, as the App Store&rsquo;s Usage Rules
          allow.</li>
          <li>Apple has no obligation to provide maintenance or support for the
          app.</li>
          <li>If the app fails to meet any warranty that applies, you may tell
          Apple, and Apple will refund any price you paid for it (the app is
          free). To the extent the law allows, Apple has no other warranty
          obligation for the app.</li>
          <li>The publisher, not Apple, is responsible for investigating,
          defending, settling and discharging any claim that the app infringes
          someone&rsquo;s intellectual property, and for any product liability,
          legal or regulatory, consumer protection or privacy claim.</li>
          <li>Questions, complaints or claims about the app go to the publisher:
          {{legalEntity}}, {{legalAddress}}, {{mailto:contactSupport}}.</li>
          <li>You confirm that you are not in a country subject to a United
          States Government embargo, and that you are not on a United States
          Government list of prohibited or restricted parties.</li>
          <li>Apple and its subsidiaries are third-party beneficiaries of these
          Terms and may enforce them against you.</li>
          <li>You must follow any third-party terms that apply when you use the
          app, for example your mobile operator&rsquo;s.</li>
          <li>Your use of the App Store or Google Play is also governed by their
          own terms.</li>
        </ul>

""" + h2("t17", "17. The rest") + """
        <ul>
          <li>If a court finds one clause unenforceable, the rest stays in
          force.</li>
          <li>Not enforcing a clause once does not waive it.</li>
          <li>These Terms and the Privacy Policy are the whole agreement between
          us about Own Hub.</li>
          <li>You may not transfer your rights under these Terms. We may
          transfer ours only together with Own Hub, after telling you in the
          app, and only to a publisher that holds its own permit from the
          Personal Data Protection Centre.</li>
          <li>Own Hub uses the Rubik, La Belle Aurore and Aref Ruqaa typefaces
          under the SIL Open Font Licence 1.1.</li>
        </ul>

""" + h2("t18", "18. Contact") + """
        <p>{{mailto:contactSupport}} &middot; {{legalEntity}}, {{legalAddress}}</p>
""" + kv([
            ("Version", "3.0"),
            ("Date", "{{policyEffectiveDate}}"),
            ("What changed",
             "Acceptance at sign-up, Arabic prevails, store terms, AI assistant "
             "listed as a later feature. Replaces version 2.0."),
        ]) + """
      </div>
    </div>
""",
    }

    # ---------------------------------------------------------- support ----
    pages["support"] = {
        "title": "Support · Own Hub",
        "description": (
            "How to reach Own Hub, what to put in your message, when you will "
            "get a reply, and answers to the things women write in about."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Support</h1>
        <p class="meta"><b>Last updated:</b> {{effectiveDate}}</p>

        <p class="lede">Write to {{mailto:contactSupport}} and you will get an
        answer. There is no ticket system, no chatbot and no form to fill
        in.</p>

""" + h2("who-reads", "Who reads it, and when") + """
        <div class="callout">
          <p>Own Hub was founded by {{brandFounder}}. It is published and
          developed by one person, {{legalEntity}}, and he reads this mailbox
          himself. There is no support team behind it, and we would rather say
          so than imply one.</p>
          <p><b>Sunday to Thursday, 9:00 to 17:00 Cairo time. A reply within one
          working day. Not monitored at night.</b></p>
          <p>If you write on a Friday or a Saturday, or after 17:00, your message
          is read on the next working day. The app keeps working while you wait,
          and your women-only check does not wait on this mailbox: if your
          check needs a person, a woman reviewer phones you.</p>
        </div>
        <p>If something in the app is hurting you or frightening you, do not wait
        for an email. Stop, and if you think it is an emergency contact emergency
        services or go to a hospital.</p>

""" + h2("what-to-include", "What to put in your message") + """
        <p>Four short lines make almost every problem solvable on the first
        reply:</p>
""" + kv([
            ("Your phone", "iPhone or Android, and which model if you know it."),
            ("The app version",
             "Profile, then scroll to the bottom. If you cannot reach it, say "
             "roughly when you installed the app."),
            ("What you were doing",
             "The screen you were on and what you tapped, in the order you "
             "tapped it."),
            ("What happened instead",
             "What you expected, and what the app did. A screenshot is worth "
             "more than a paragraph."),
        ]) + """
        <p><b>Please do not send anything you would not want in an ordinary
        email.</b> We never need your ID, your photograph, your measurements,
        your cycle history or the code we send you by SMS to answer a question,
        and we will never ask you for them. There is no password to reset,
        because the app has none: you sign in with a code sent to your
        phone.</p>

""" + h2("questions", "The questions people actually write in about") + """
        <div class="qa">
""" + h3("q-restore", "I deleted everything. Can you bring it back?") + """
          <p>No, and neither can anyone else. Deleting your account from
          Profile, then Your data, deletes it from our servers and from your
          phone, and there is no restore and no grace period. The
          <a href="/delete-account">deletion page</a> lists the three things
          that are kept on purpose, and none of them is your logs.</p>
          <p>If you lost your phone or uninstalled the app without deleting
          your account, sign in again with the same number: your training and
          meals come back. Your cycle and health information comes back only if
          you had turned on health backup.</p>

""" + h3("q-newphone", "I am changing phone. Does my history come with me?") + """
          <p>Sign in on the new phone with the same mobile number. Your training
          and meals are kept with your verified account, so they come back.
          Your cycle, check-ins, measurements and weight are kept on the phone
          only, unless you turned on <b>Back up my health data</b> in Profile,
          then Privacy; if you did, they come back too. If you did not, they
          stay on the old phone. You can ask for a copy of your data from
          Profile, then Your data, then Ask for a copy, and we send it to
          you.</p>

""" + h3("q-signin", "Where do I sign in? Where is the community?") + """
          <p>You sign in with your Egyptian mobile number and a code sent by
          SMS. There is no password. The first time, you are also checked once
          with your national ID card and a live selfie; if the automatic check
          is unsure, or you choose the niqab route, a woman from Own Hub
          reviews your case and contacts you by phone within 72 hours to finish
          your check. There is no community, no coaching
          and no assistant in this version: nothing in the app connects you to
          another member, and nothing in it can be bought. If you were expecting
          one of those, you were reading about a later version that is not
          out.</p>

""" + h3("q-language", "How do I switch between Arabic and English?") + """
          <p>Profile, then Language. Pick the one you want and the whole app
          changes with it, right to left included. The setting stays after you
          close the app, and you can change it as often as you like.</p>

""" + h3("q-privacy", "What do you know about me?") + """
          <p>Your mobile number, which Google Firebase Authentication holds in
          the United States so that you can sign in. The result of your
          women-only check, and a one-way keyed code made from your ID number so
          that one card cannot open two accounts. We never keep the photographs
          of your card or your face, and we never keep the ID number itself.
          Once you are verified, your training and meals, kept in Frankfurt,
          Germany, where no other member can see them. Your cycle, check-ins,
          measurements, life stage, allergies and weight only if you turn on
          health backup yourself.</p>
          <p>If you allow crash reports, Firebase Crashlytics receives a report
          when the app crashes, with no account identifier, name or phone
          number. They are off until you allow them. There is no
          analytics and no advertising library in the app. The
          <a href="/privacy">Privacy Policy</a> sets out every item, who handles
          it and where.</p>
        </div>

""" + h2("elsewhere", "The other things you might be looking for") + """
        <ul>
          <li><a href="/delete-account">Delete your data</a>: how to delete your
          account from inside the app, and how to ask us without installing
          it.</li>
          <li><a href="/privacy">Privacy Policy</a>: what the app collects,
          where it is kept, and for how long.</li>
          <li><a href="/terms">Terms of Use</a>: including the medical warning,
          which is worth reading before you start training.</li>
        </ul>
      </div>
    </div>
""",
    }

    # --------------------------------------------------- delete-account ----
    # The account build: deletion runs on our server (delete_account) and on
    # the phone. PENDING COUNSEL SIGN-OFF, like the privacy policy.
    pages["delete-account"] = {
        "title": "Delete your Own Hub account · Own Hub",
        "description": (
            "How to delete your Own Hub account and your data, in the app or "
            "by email, and the three things that are kept on purpose."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Delete your Own Hub account</h1>
        <p class="meta"><b>Last updated:</b> {{effectiveDate}}</p>
""" + draft_banner + """
""" + h2("short", "The short version", "no-rule") + """
        <div class="callout calm">
          <p><b>Open Own Hub, go to Profile, then Your data, and choose to
          delete your account.</b> Our server deletes your account and your data,
          and the app wipes your phone at the same time.</p>
          <p>You do not need to be verified to do this. A woman whose check is
          still pending, or was refused, can delete her account in exactly the
          same way.</p>
        </div>
""" + kv([
            ("App", "Own Hub, iOS and Android, bundle id "
                    "<code>com.ownhub.app</code>"),
            ("Publisher and developer", "{{legalEntity}}"),
            ("Country", "{{legalAddress}}"),
            ("Where to write", "{{mailto:contactPrivacy}}"),
        ]) + """

""" + h2("how", "How to delete it") + """
""" + h3("in-the-app", "In the app") + """
        <ol class="steps">
          <li>Open <b>Own Hub</b> and sign in.</li>
          <li>Open <b>Profile</b>.</li>
          <li>Tap <b>Your data</b>.</li>
          <li>Read the sheet. It says what will be removed, what is kept and
          why, and that it cannot be undone.</li>
          <li>Confirm that you want to delete your account.</li>
        </ol>
        <p>This is what happens, in this order:</p>
        <ol>
          <li>Your sign-in is locked, so nothing new can be written to your
          account while it is being deleted.</li>
          <li>Your account and everything stored under it is deleted from our
          servers, together with your verification records and your review
          case if you have one.</li>
          <li>The data on your phone is wiped.</li>
          <li>Your sign-in record, including your phone number, is deleted
          last.</li>
        </ol>
        <p>If your connection drops or something fails part way, the deletion
        is not lost: our server finishes it automatically within the hour, and
        the app tells you so.</p>

""" + h3("without-the-app", "Without the app, by email") + """
        <p>You can ask us to delete your account without installing Own Hub.
        The button below opens a message to {{mailtoplain:contactPrivacy}} with
        the text already written. Include the phone number on the account.</p>
        <div class="btn-row">""" + delete_button + """</div>
        <p>We send a one-time code by SMS to the number on the account. Reply to
        our email with the code, and we delete within {{deletionWindow}} and
        confirm in writing. You never need to send us your ID, a photograph or
        any health information, and we will never ask you for them.</p>

""" + h2("what-goes", "What is deleted") + """
        <ul>
          <li>Your account and your phone number.</li>
          <li>Your settings, your training, your meals, your goals, your
          personal bests and your milestones.</li>
          <li>Any health information you backed up: cycle, periods, check-ins,
          measurements and weight, life stage and allergies.</li>
          <li>Your consent records.</li>
          <li>Your verification results, your review case and your selfie
          session records. (The photographs themselves were never stored.)</li>
          <li>Your safety-report list, blocks, notifications and anything you
          uploaded.</li>
          <li>Everything the app holds on your phone.</li>
        </ul>

""" + h2("what-stays", "What is kept, on purpose") + """
        <ul>
          <li><b>The keyed code of your ID number is closed, not deleted.</b> It
          no longer points to any account, and it stops the same card opening a
          new account. It is kept with no end date, so the same card cannot be
          used to join again.</li>
          <li><b>Safety reports</b> you made, or that were made about you, are
          kept for the safety of other members, with your account identifier
          replaced by a random code.</li>
          <li><b>A record that your deletion was carried out</b>, reduced to its
          status and dates, as proof that your request was honoured.</li>
        </ul>
        <p>Two more things are not linked to your account and expire on their
        own: the count of failed check attempts and the scrambled installation
        record, deleted 180 days after the last attempt, and the log of which
        reviewer opened your case, deleted after one year.</p>
        <p>Google removes its own backups within its own deletion window.</p>

""" + h2("cannot-undo", "It cannot be undone") + """
        <p>There is no restore and no grace period. Once it is done, your logs
        and your history are gone.</p>
        <p><b>Want a copy first?</b> Ask from Profile, then Your data, then Ask
        for a copy, or write to {{mailto:contactPrivacy}} before you delete, and
        we send it to you.</p>

""" + h2("some-of-it", "Delete only some of it") + """
        <ul>
          <li><b>Health backup can be switched off</b> in Profile, then Privacy.
          That deletes the copy of your health information on our servers and
          keeps the one on your phone.</li>
          <li><b>Cycle data can be deleted on its own</b>, from cycle settings.</li>
          <li>You can remove items from a day&rsquo;s log and delete individual
          measurements.</li>
        </ul>

""" + h2("rights", "Your rights") + """
        <p>Under Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020 you
        can ask what we hold about you, correct it, have it deleted, and
        withdraw a consent you gave. The <a href="/privacy">Privacy Policy</a>
        sets out each right and how to use it.</p>
        <p>If you are not satisfied with how we handle a request, you can
        complain to Egypt&rsquo;s Personal Data Protection Centre.
        {{pdpcContact}}</p>

        <p><b>Questions:</b> {{mailto:contactPrivacy}}</p>
      </div>
    </div>
""",
    }

    # -------------------------------------------------------------- 404 ----
    # --------------------------------------------------------- waitlist ----
    # W1. A plain form, no script: the join_waitlist Function answers with a
    # redirect to one of the three pages after this one.
    pages["waitlist"] = {
        "title": "Join the waitlist · Own Hub",
        "description": (
            "Leave your Egyptian mobile number or your email, and we will "
            "message you once when Own Hub opens."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Join the waitlist</h1>
        <p class="lede">Own Hub is not open yet. Leave your Egyptian mobile
        number or your email address, and we will message you once when it
        opens.</p>
""" + FORM + """
        <p>That is all we ask for. The waitlist is not an account, and what we
        keep, and for how long, is set out in the
        <a href="/privacy#c-waitlist">privacy policy</a>.</p>
      </div>
    </div>
""",
    }

    pages["waitlist-joined"] = {
        "title": "You are on the list · Own Hub",
        "description": "You are on the Own Hub waitlist.",
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>You are on the list</h1>
        <p class="lede">Thank you. We will message you once, when Own Hub
        opens, and then delete your contact.</p>
        <p>If you had already joined with the same number or email, you are
        still on the list only once.</p>
        <div class="btn-row"><a class="btn ghost" href="/">Back to the home page</a></div>
      </div>
    </div>
""",
    }

    pages["waitlist-check"] = {
        "title": "That did not go through · Own Hub",
        "description": "The waitlist form could not use what was sent.",
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>That did not go through</h1>
        <p class="lede">We could not use what was sent, so nothing was
        saved.</p>
        <p>Please enter an Egyptian mobile number, eleven digits starting 010,
        011, 012 or 015, or an email address, and tick the box to agree.</p>
        <div class="btn-row"><a class="btn" href="/waitlist">Try again</a></div>
      </div>
    </div>
""",
    }

    pages["waitlist-later"] = {
        "title": "Please try again later · Own Hub",
        "description": "The waitlist could not take this request just now.",
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Please try again later</h1>
        <p class="lede">We could not add you just now, and nothing was
        saved.</p>
        <p>This connection may have already sent many requests today, the
        waitlist may be full for today, or something went wrong on our side.
        Please try again tomorrow.</p>
        <div class="btn-row"><a class="btn ghost" href="/">Back to the home page</a></div>
      </div>
    </div>
""",
    }

    pages["404"] = {
        "title": "Page not found · Own Hub",
        "description": "That address is not on this site. Here is everything that is.",
        "body": """
    <div class="wrap lost">
      <div class="prose">
        <h1>That page is not here</h1>
        <p class="lede">The address you followed does not exist on this site,
        which has only six pages. One of these is almost certainly the one you
        wanted.</p>
      </div>
      <ul class="doorways">
        <li><a href="/"><span class="t">Home</span><span class="d">What Own Hub is.</span></a></li>
        <li><a href="/waitlist"><span class="t">Join the waitlist</span><span class="d">Hear once when Own Hub opens.</span></a></li>
        <li><a href="/privacy"><span class="t">Privacy Policy</span><span class="d">What the app collects, and where it is kept.</span></a></li>
        <li><a href="/terms"><span class="t">Terms of Use</span><span class="d">What Own Hub is, and what it is not.</span></a></li>
        <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person.</span></a></li>
        <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to delete your account.</span></a></li>
      </ul>
    </div>
""",
    }

    return pages
