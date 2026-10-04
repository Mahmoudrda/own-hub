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

You can phone that number to confirm this request is mine.

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
        <div class="btn-row"><a class="btn" href="/waitlist">Join the waitlist</a></div>
      </div>
      <ul class="facts" aria-label="Own Hub at a glance">
        <li><b>Women only</b><span>Checked once with your national ID and a live selfie, or by a woman reviewer on a short video call. The photos are never stored.</span></li>
        <li><b>Your health stays with you</b><span>Cycle, check-ins, measurements and weight stay on your phone unless you turn on backup yourself.</span></li>
        <li><b>One permission</b><span>The camera, for the women-only check. No photo library, no microphone, no location, no health data.</span></li>
        <li><b>Free</b><span>No adverts, no purchases, no subscriptions. Nothing in it is for sale.</span></li>
        <li><b>Arabic and English</b><span>The whole app in both, right to left included.</span></li>
      </ul>
      </div>
    </section>

    <section class="wrap" aria-labelledby="inside">
      <div class="prose">
""" + h2("inside", "What is inside it") + """
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
          account in Frankfurt, and only you can read them. Your cycle and
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
          no assistant. There is no export of your data yet, and the app says so
          rather than showing a button that would produce nothing.</p>
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
        <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person, when she reads, and answers to the things women write in about.</span></a></li>
        <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to delete your account from inside the app, and how to ask without installing it.</span></a></li>
      </ul>
    </section>
""",
    }

    # ---------------------------------------------------------- privacy ----
    # The account build: phone sign-in, a women-only check with a national ID
    # and a live selfie, and cloud storage of her logs. Based on
    # docs/release/privacy-policy.proposed.md (2 October 2026), corrected to
    # what the code does after the council fixes. PENDING COUNSEL SIGN-OFF:
    # the banner below stays until a licensed Egyptian lawyer has approved it.
    draft_banner = """
        <div class="callout" role="note">
          <p><b>Draft pending review by a licensed Egyptian lawyer.</b> This page
          describes the version of Own Hub with accounts and the women-only
          check. It has not yet been approved by counsel, and it may change
          before it is final.</p>
        </div>
"""

    privacy_toc = toc("On this page", [
        ("a", "short-version", "The short version"),
        ("a", "who-we-are", "1. Who is responsible for your data"),
        ("a", "who-can-use", "2. Who can use Own Hub"),
        ("a", "collect", "3. What we collect, and why"),
        ("a", "where", "4. Who handles it, and where"),
        ("a", "transfers", "5. Transfers outside Egypt"),
        ("a", "retention", "6. How long we keep it"),
        ("a", "deletion", "7. Deleting your account"),
        ("a", "rights", "8. Your rights"),
        ("a", "security", "9. Security"),
        ("a", "does-not", "10. What Own Hub does not do"),
        ("a", "changes", "11. Changes to this policy"),
    ])

    who_rows = [
        ("App", "Own Hub, iOS and Android, bundle id <code>com.ownhub.app</code>"),
        ("Controller", "{{legalEntity}}, an individual publishing Own Hub in his own name"),
        ("Country", "{{legalAddress}}"),
        ("Privacy contact", "{{mailto:contactPrivacy}}"),
        ("Personal Data Protection Centre permit", "{{pdpcPermit}}"),
    ]
    if cfg.plain("commercialRegistration", lang):
        who_rows.append(
            ("Commercial registration and tax card number",
             "{{commercialRegistration}}")
        )
    if cfg.plain("dataProtectionOfficer", lang):
        who_rows.append(("Data protection officer", "{{dataProtectionOfficer}}"))

    pages["privacy"] = {
        "title": "Privacy Policy · Own Hub",
        "description": (
            "How Own Hub handles your phone number, the women-only check, and "
            "your training, meals and health information. ID and selfie photos "
            "are never stored."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Privacy Policy</h1>
        <p class="meta">
          <b>Effective date:</b> {{effectiveDate}}<br>
          <b>Version:</b> 2.0<br>
          <b>Applies to:</b> Own Hub for iOS and Android, bundle id
          <code>com.ownhub.app</code>, and this website.
        </p>
""" + draft_banner + """
""" + privacy_toc + """

""" + h2("short-version", "The short version", "no-rule") + """
        <div class="callout calm">
          <ul>
            <li>Own Hub is a fitness app for women in Egypt aged 18 and over. To
            keep it women only, we check your Egyptian national ID card and a
            live selfie once, when you join.</li>
            <li><b>The photographs of your card and your selfie are never
            stored.</b> They are read in memory on our server in Frankfurt,
            Germany, and discarded when the check ends. We keep the result, and
            a one-way keyed code made from your ID number so that one card
            cannot open two accounts.</li>
            <li><b>Your cycle, periods, daily check-ins, measurements and
            weight, pregnancy or postpartum status, injuries and allergies stay
            on your phone.</b> They are copied to our servers only if you turn
            on health backup yourself, after a separate consent. Turning it off
            deletes the copy.</li>
            <li>Your workouts and meals are copied to Google Cloud servers in
            Frankfurt once your account is verified, so you do not lose them if
            you lose your phone. Only you can read them.</li>
            <li>Your phone number is handled by Google Firebase Authentication,
            which runs in the United States.</li>
            <li>We do not sell your data, show no adverts, use no advertising or
            analytics tools, and never use your health information for
            marketing.</li>
            <li>You can delete your account and your data from inside the app at
            any time.</li>
          </ul>
        </div>

""" + h2("who-we-are", "1. Who is responsible for your data") + """
        <p>The controller of your personal data, meaning the person who
        decides how and why it is used, is:</p>
""" + kv(who_rows) + """
        <p>{{brandFounder}} is Own Hub&rsquo;s founder and the author of its
        recipes. She is not the controller of your data.</p>
        <p>The people who review verification cases by video call are women
        acting on the controller&rsquo;s instructions and bound by
        confidentiality.</p>

""" + h2("who-can-use", "2. Who can use Own Hub") + """
        <p>Own Hub is for women aged <b>18 or over</b> who hold an Egyptian
        national ID card. We do not knowingly collect data from anyone under
        18. Your age and sex are read from your national ID number during the
        check. If the check shows that you are under 18, your application is
        refused.</p>

""" + h2("collect", "3. What we collect, and why") + """
""" + h3("c-account", "3.1 Your account") + """
        <ul>
          <li><b>Your mobile number</b>, to create your account and sign you in
          with a one-time code sent by SMS.</li>
          <li><b>An account identifier</b> we generate, to link your data to
          your account.</li>
          <li><b>Your language and settings</b> (privacy switches, notification
          preferences and quiet hours), to run the app the way you set it.</li>
        </ul>

""" + h3("c-check", "3.2 Checking that you are a woman aged 18 or over") + """
        <p>This happens once, when you join, and only after you have read a
        separate screen and agreed to it. Nothing about the camera starts
        before that agreement is recorded on our server. The camera is the only
        way to take the photographs: the app cannot upload a picture that is
        already on your phone.</p>
        <ul>
          <li><b>Photographs of the front and back of your ID card.</b> Sent over
          an encrypted connection to our server in Frankfurt, Germany. The text
          on the card is read by Google Cloud Vision through its European Union
          endpoint. <b>We do not store the images anywhere.</b></li>
          <li><b>A short live selfie</b>, taken while you follow prompts chosen
          by our server. It is used to check that a live person is present and
          that the face matches the portrait on the card. The comparison runs on
          our own server and does not use any outside face recognition service.
          <b>We do not store the selfie or any face measurement.</b></li>
          <li><b>Your national ID number.</b> Used to confirm your sex (from the
          digit the Civil Status authority set in the number) and your age (from
          the date of birth encoded in it), then turned into a one-way keyed
          code with a secret key held separately in Google Secret Manager.
          <b>The number itself is not stored.</b></li>
          <li><b>Your name and date of birth as printed on the card</b> are read
          only to cross-check the number. <b>Not stored.</b></li>
          <li><b>The result</b>: approved, refused, or sent to a woman reviewer,
          with reason codes, coarse score bands, the attempt number and the
          dates. Your account shows you only whether your check is pending,
          approved, refused or ready to try again, never the reason codes.</li>
          <li><b>Fraud signals</b>: a count of failed attempts per ID code, and a
          scrambled identifier for the app installation, so that one
          installation trying many different cards can be noticed.</li>
          <li><b>Your consent</b>: the version of the wording you accepted, and
          when.</li>
        </ul>
        <p>We never guess your sex from your face. The decision about sex comes
        from your national ID.</p>
        <p>Legal basis: your explicit consent, given on the screen before the
        camera opens. You can refuse. If you refuse, you cannot join Own Hub,
        because a women-only membership is the purpose of the service.</p>

""" + h3("c-review", "3.3 Review by a woman") + """
        <p>If the automatic check is unsure, if you wear niqab and prefer a
        woman reviewer, if you decline the camera, or if the check cannot run
        for a technical reason, your case is reviewed by a woman in a short
        live video call over {{videoCallService}}.</p>
        <ul>
          <li>The review queue holds reason codes and scores. It never holds a
          photograph, and it never holds your phone number.</li>
          <li>When a reviewer is ready to call you, she looks up your number
          from your account at that moment. Every lookup is recorded with the
          reviewer and the time, so that access leaves a trace.</li>
          <li><b>The call is not recorded.</b> The reviewer records only her
          decision and the date.</li>
          <li>If your case has no ID code yet (for example because you chose
          the niqab route), the reviewer may ask you to read your ID number
          during the call. It is turned into the keyed code at once and is never
          stored or written to any log.</li>
          <li>We do not send text messages about your review. A woman reviewer
          phones you.</li>
        </ul>

""" + h3("c-training", "3.4 Your training and meals") + """
        <p>Workouts, sets, weights and repetitions, weekly goals, personal
        bests, meals you log and your eating preferences stay on your phone,
        and once your account is verified a copy is also stored in Google Cloud
        Firestore in Frankfurt, Germany, under your account, so it survives a
        lost or replaced phone. Security rules on the server mean only your own
        signed-in, verified account can read it.</p>

""" + h3("c-health", "3.5 Your health information stays on your phone") + """
        <p>Your cycle settings, period days, daily check-ins (for example
        energy, sleep, bloating, pain and bleeding), body measurements and
        weight, your life stage (pregnancy, postpartum or training around an
        injury) and the allergies you tell us about are <b>kept on your phone
        only</b>, by default.</p>
        <p>You can choose to back them up. In <b>Profile</b>, then
        <b>Privacy</b>, <b>Back up my health data</b> asks for a separate
        consent that names this health information and the countries it would
        be stored in. Only after our server has recorded that consent is any of
        it copied, and our server&rsquo;s security rules refuse it without
        that consent. If you turn backup off, we delete the copy on our servers
        straight away; the copy on your phone stays.</p>
        <p><b>Your cycle and health information is never used for advertising
        or marketing, never sold, and never sent to any analytics
        service.</b></p>

""" + h3("c-technical", "3.6 Technical data") + """
        <ul>
          <li><b>Sign-in</b>: Google Firebase Authentication receives your IP
          address and device details when you sign in, for security.</li>
          <li><b>Genuine app check</b>: Google Play Integrity (Android) or Apple
          App Attest (iOS), through Firebase App Check, confirms that requests
          come from the real app, to stop automated abuse of the check.</li>
          <li><b>Selfie guidance</b>: Google ML Kit, the on-device face
          detection that guides the selfie camera, sends Google device model,
          operating system, app version, an installation identifier and
          performance events. Your images do not leave the phone through ML
          Kit.</li>
          <li><b>Crash reports</b>: if the app crashes, Firebase Crashlytics
          receives the error, device model, operating system and app version.
          No account identifier, name or phone number is attached.</li>
        </ul>

""" + h3("c-waitlist", "3.7 The waitlist on this website") + """
        <p>If you join the waitlist on this website, we keep the mobile number
        or email address you give, the language you chose, your agreement and
        when you joined. We use it for one thing: to message you once when Own
        Hub opens, and then we delete it. If that has not happened, it is
        deleted automatically 180 days after you joined, a period pending
        counsel&rsquo;s confirmation. To protect the form from abuse we also
        keep a keyed code made from your internet address, never the address
        itself, and a count of attempts from it that is deleted after two days.
        It is stored in Google Cloud Firestore in Frankfurt, Germany, and no app
        or browser can read it. To leave the waitlist sooner, write to
        {{mailto:contactPrivacy}}.</p>

""" + h2("where", "4. Who handles it, and where") + """
        <p>We do not sell your data and do not share it with advertisers, data
        brokers or marketing companies. These service providers process data
        only on our instructions:</p>
""" + cards([
            ("Google Firebase Authentication", [
                ("Handles", "Your phone number, IP address and device details"),
                ("Where", "United States"),
            ]),
            ("Your mobile operator and Google&rsquo;s SMS partners", [
                ("Handles", "Your phone number and the sign-in code"),
                ("Where", "Egypt, and the route Google uses"),
            ]),
            ("Google Cloud Firestore, Cloud Functions and Secret Manager", [
                ("Handles", "Your account, your training and meals, health "
                            "information if you turn on backup, verification "
                            "results and the keyed ID code"),
                ("Where", "Frankfurt, Germany (europe-west3)"),
            ]),
            ("Google Cloud Vision", [
                ("Handles", "The text on your ID card, during the check only"),
                ("Where", "European Union"),
            ]),
            ("Google Play Integrity and Apple App Attest", [
                ("Handles", "Confirmation that the app is genuine"),
                ("Where", "Google and Apple systems"),
            ]),
            ("Google ML Kit and Firebase Crashlytics", [
                ("Handles", "Device, performance and crash data listed in 3.6"),
                ("Where", "Google systems"),
            ]),
            ("{{videoCallService}}", [
                ("Handles", "Your image and voice during a review call, if you "
                            "have one"),
                ("Where", "{{videoCallServiceRegion}}"),
            ]),
        ]) + """
        <p>We may also disclose data where Egyptian law requires it, for
        example in answer to a lawful order of a court or a competent
        authority.</p>

""" + h2("transfers", "5. Transfers outside Egypt") + """
        <p>Your data is stored and processed outside Egypt: in Germany and the
        European Union for your account, your logs and your verification, and
        in the United States for your phone number. Egypt&rsquo;s Personal Data
        Protection Law No. 151 of 2020 allows transfers abroad only with a
        licence or permit from the Personal Data Protection Centre and, under
        its Executive Regulations, with your consent. We ask for that consent,
        naming these countries, before your data leaves your phone, and again
        separately before any health information does.
        {{transferCountries}}</p>

""" + h2("retention", "6. How long we keep it") + """
        <ul>
          <li><b>ID card photographs and selfie</b>: not stored. Discarded in
          memory when the check ends, whatever the result.</li>
          <li><b>The single-use selfie session</b>: valid for five minutes, then
          deleted automatically.</li>
          <li><b>Your account, settings, training, meals, any health backup and
          your consent records</b>: until you delete them or delete your
          account.</li>
          <li><b>Verification results and review records</b>: deleted
          automatically 180 days after the case is decided, or earlier if you
          delete your account. A case still waiting for review is kept until it
          is decided. The 180 days are pending counsel&rsquo;s confirmation.</li>
          <li><b>The keyed code of your ID number</b>: see section 7.</li>
          <li><b>The reviewer access log</b>: which reviewer opened which case,
          and when. It holds no photograph, no phone number and no ID number,
          and it is kept as an audit trail.</li>
          <li><b>Daily totals of verifications</b>, with no link to any person:
          kept.</li>
          <li><b>A record that a deletion was carried out</b>, reduced to its
          status and dates: kept as proof that your request was honoured.</li>
          <li><b>Backups held by Google</b>: removed within Google&rsquo;s own
          deletion window.</li>
        </ul>

""" + h2("deletion", "7. Deleting your account") + """
        <p>In the app: <b>Profile</b>, then <b>Your data</b>, then the delete
        option. Our server locks your sign-in first, deletes your account and
        the data in section 3, and deletes your sign-in record last; your phone
        is wiped at the same time. If anything interrupts it, it finishes
        automatically within the hour. The
        <a href="/delete-account">deletion page</a> explains every step, and how
        to ask without the app.</p>
        <p><b>Three things survive on purpose:</b></p>
        <ul>
          <li><b>The keyed code of your ID number is closed, not deleted.</b> The
          link to your account is removed, and the same card cannot open a new
          account. Whether a woman who deleted her account may rejoin is a
          question we have put to counsel.</li>
          <li><b>Safety reports</b> you made, or that were made about you, keep
          the report but replace your account identifier with a random
          code.</li>
          <li><b>The record that your deletion was carried out</b>, reduced to
          its status and dates.</li>
        </ul>

""" + h2("rights", "8. Your rights") + """
        <p>Under Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020 you
        have the right to:</p>
        <ul>
          <li>know what personal data we hold about you and obtain a copy of
          it;</li>
          <li>have it corrected or completed;</li>
          <li>have it erased;</li>
          <li>withdraw your consent at any time, without affecting processing
          that took place before;</li>
          <li>object to processing, or ask us to restrict it;</li>
          <li>be told of any breach of your personal data.</li>
        </ul>
        <p>To use any of these rights, write to {{mailto:contactPrivacy}}. We
        will answer within {{rightsResponseWindow}}. A copy of your data is not
        yet available as a button in the app, so we will send it to you by
        email on request.</p>
        <p>If you are not satisfied with our answer, you can complain to
        Egypt&rsquo;s Personal Data Protection Centre. {{pdpcContact}}</p>

""" + h2("security", "9. Security") + """
        <ul>
          <li>Sign-in uses a one-time code sent to your phone. There is no
          password to steal.</li>
          <li>Data travels over encrypted connections, and Google encrypts it
          where it is stored.</li>
          <li>Server rules mean your account can read only your own data, and
          the app cannot mark itself as verified. Only our server can do
          that.</li>
          <li>Verification images are never written to disk, logs or storage by
          us. Our logs record outcomes and reason codes, never your phone
          number, your ID number or your account identifier beside an
          outcome.</li>
          <li>The secret key behind the ID code is held in Google Secret
          Manager, separate from the database.</li>
          <li>No system is perfectly secure. If a breach affects your personal
          data, we will notify the Personal Data Protection Centre within 72
          hours of becoming aware of it, and tell you within three working days
          after that.</li>
        </ul>

""" + h2("does-not", "10. What Own Hub does not do") + """
        <ul>
          <li>No adverts, no advertising identifiers, no tracking across other
          apps or websites.</li>
          <li>No analytics software.</li>
          <li>No access to your contacts, location, photo library, microphone,
          or Apple Health or Health Connect.</li>
          <li>Nothing that guesses your sex, age or anything else about you from
          your face.</li>
        </ul>

""" + h2("changes", "11. Changes to this policy") + """
        <p>We will publish any change here with its date. If a change means
        collecting something new or using your data in a new way, we will tell
        you in the app before it takes effect and ask for your consent where
        the law requires it.</p>
        <p><b>Version 2.0, {{effectiveDate}}</b>: accounts, the women-only
        check, cloud storage of your training and meals, and optional health
        backup. Replaces the version written for a build with no server.</p>

        <p><b>Questions:</b> {{mailto:contactPrivacy}}</p>
      </div>
    </div>
""",
    }

    # ------------------------------------------------------------ terms ----
    terms_toc = toc("On this page", [
        ("a", "t1", "1. Who you are agreeing with"),
        ("a", "t2", "2. What Own Hub is, in this version"),
        ("a", "t3", "3. Who may use it"),
        ("a", "t4", "4. Own Hub is not medical advice"),
        ("a", "t5", "5. Allergies and food"),
        ("a", "t6", "6. Your data, and your phone"),
        ("a", "t7", "7. What you may not do"),
        ("a", "t8", "8. Content you make"),
        ("a", "t9", "9. Nothing is for sale here"),
        ("a", "t10", "10. Ending it"),
        ("a", "t11", "11. The app is provided as it is"),
        ("a", "t12", "12. What changes when the rest of the product arrives"),
        ("a", "t13", "13. Limits on what we owe you"),
        ("a", "t14", "14. Changes to these Terms"),
        ("a", "t15", "15. Law and disputes"),
        ("a", "t16", "16. The rest"),
        ("a", "t17", "17. Contact"),
    ])

    pages["terms"] = {
        "title": "Terms of Use · Own Hub",
        "description": (
            "The terms for using Own Hub: a free fitness app for women in "
            "Egypt, with a women-only account, no community, no coaching and "
            "nothing to buy."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Terms of Use</h1>
        <p class="meta">
          <b>Effective date:</b> {{effectiveDate}}<br>
          <b>Applies to:</b> Own Hub for iOS and Android, bundle id
          <code>com.ownhub.app</code>.<br>
          <b>Last updated:</b> {{effectiveDate}}
        </p>
""" + draft_banner + """
""" + terms_toc + """

""" + h2("t1", "1. Who you are agreeing with", "no-rule") + """
        <p>Own Hub was founded by {{brandFounder}} and is published and
        developed by {{legalEntity}}, {{legalAddress}}. In these Terms,
        &ldquo;we&rdquo; and &ldquo;us&rdquo; mean the publisher named here, and
        &ldquo;you&rdquo; means the person using the app.</p>
        <p>Contact: {{mailto:contactSupport}}</p>
        <p>By downloading or using Own Hub you accept these Terms. If you do not
        accept them, do not use the app.</p>

""" + h2("t2", "2. What Own Hub is, in this version") + """
        <p>A fitness app for women in Egypt. It lets you follow workouts, log
        what you train and eat, set a weekly goal, track measurements you enter
        yourself, and record your menstrual cycle.</p>
        <p><b>You need an account, and you are checked once.</b> You sign up
        with your Egyptian mobile number and a code sent by SMS. There is no
        password and no profile that anyone else can see. Your training and
        meals are kept on your phone and, once you are verified, with your
        account. Your cycle and health information stays on your phone unless
        you turn on backup yourself. The <a href="/privacy">Privacy Policy</a>
        sets out exactly what is kept and where.</p>
        <p><b>It is free, and there is nothing in it to buy.</b> No adverts, no
        in-app purchases, no subscriptions, and no payment of any kind inside or
        outside the app.</p>
        <p><b>It has no community and no coaching in this version.</b> Nothing
        connects you to another person. <a href="#t12">Section 12</a> describes
        what changes if those arrive, and they will arrive only in a later
        version, with a later version of these Terms.</p>

""" + h2("t3", "3. Who may use it") + """
        <p>Own Hub is made for women in Egypt, and that is the product&rsquo;s
        purpose.</p>
        <p><b>You must be a woman aged 18 or over who holds an Egyptian national
        ID card.</b> Membership is confirmed once, when you join, through the
        Egyptian national ID, which carries sex and date of birth in the ID
        number itself, and a live selfie that is compared with the portrait on
        the card. If the automatic check is unsure, or you choose the niqab
        route, a woman reviewer phones you to arrange a short video check. The
        photographs of your card and your face are never stored. We never guess
        your sex or your age from your face.</p>
        <ul>
          <li>One account per person.</li>
          <li>You may not use anyone else&rsquo;s identity documents, or let
          anyone else use your account.</li>
        </ul>

""" + h2("t4", "4. Own Hub is not medical advice") + """
        <div class="callout">
          <p><b>Read this section even if you skip the rest.</b></p>
          <ul>
            <li>Own Hub is a fitness and wellbeing app. It is <b>not a medical
            device, not a diagnosis, and not a substitute for a doctor.</b>
            Nothing in it is a clinical opinion about you.</li>
            <li>Workouts, meal suggestions, calorie and macro figures, and
            anything the app shows about your cycle are general guidance. They
            are not prescriptions.</li>
            <li><b>Talk to a doctor before you start</b>, especially if you are
            pregnant or recently gave birth, have a heart, joint, bone or
            blood-pressure condition, diabetes, an eating disorder, are
            recovering from surgery or injury, or take medication that affects
            exercise.</li>
            <li><b>Stop exercising if something hurts, and get medical help if
            you need it.</b> Nothing in the app can require you to continue. The
            app never penalises you for stopping or for resting.</li>
            <li>Where the app shows guidance about severe symptoms, such as heavy
            bleeding or severe pain, <b>it is telling you to seek care, not
            treating you.</b> If you think it is an emergency, contact emergency
            services or go to a hospital. Do not wait for an app.</li>
            <li>The app does not know your medical history. It only knows what
            you typed into it.</li>
          </ul>
        </div>

""" + h2("t5", "5. Allergies and food") + """
        <p>The app carries an allergy guard that refuses to say a dish is safe
        when it cannot tell. <b>It fails towards refusing rather than towards
        reassuring</b>, which is the right way round.</p>
        <p>You are responsible for checking what you eat. Nothing in the app
        replaces reading a label or asking whoever cooked it.</p>

""" + h2("t6", "6. Your data, and your phone") + """
        <p>Your account is tied to your mobile number. Signing in needs a code
        sent by SMS to that number, so keep your phone and your SIM card
        safe.</p>
        <ul>
          <li><b>What you log is on your phone.</b> Anyone who can unlock your
          phone can open the app and read it. If that matters to you, use your
          phone&rsquo;s own lock.</li>
          <li><b>Your training and meals are also kept with your account</b>
          once you are verified, so they come back when you sign in on a new
          phone. Your cycle and health information comes back only if you
          turned on health backup; otherwise it stays on the old phone.</li>
          <li><b>You can delete your account and your data</b>, from Profile,
          then Your data. Deletion completes on our server, and it cannot be
          undone.</li>
          <li><b>We cannot recover anything after deletion.</b> Once your
          account is deleted, your logs and your history are gone.</li>
          <li>Downloading a copy of your data is not built in this version, and
          the app says so rather than offering a button that produces
          nothing.</li>
        </ul>
        <p>The <a href="/privacy">Privacy Policy</a> explains all of this in more
        detail.</p>

""" + h2("t7", "7. What you may not do") + """
        <p>You may not:</p>
        <ul>
          <li>Break the app: no scraping, no automated access, no reverse
          engineering, no attempt to defeat the women-only check or the parts
          of the product that are switched off, and no security testing without
          our written
          permission.</li>
          <li>Redistribute the app, its content, its exercise library or its food
          data as your own.</li>
          <li>Use Own Hub for anything illegal under Egyptian law.</li>
        </ul>
        <p>When the community arrives, <a href="#t12">section 12</a> adds the
        rules that come with it. They are not in force in this version, because
        there is nowhere to post.</p>

""" + h2("t8", "8. Content you make") + """
        <p><b>What you log is yours.</b> We do not claim ownership of it. We
        keep a copy of your training and meals, and of your health information
        only if you turn on backup, for one purpose: so that you do not lose
        them.</p>

""" + h2("t9", "9. Nothing is for sale here") + """
        <p>The app is free. There are no in-app purchases, no subscriptions, no
        external payments, and no price shown anywhere in this version. If a
        future version adds paid coaching, it will do so with its own terms,
        shown to you before anything is charged, and nothing will renew by
        itself.</p>

""" + h2("t10", "10. Ending it") + """
        <p><b>You can stop at any time.</b> Delete your account from Profile,
        then Your data. You do not owe us a reason. Deleting the app alone does
        not delete your account; the <a href="/delete-account">deletion
        page</a> explains both ways to do it, with the app and without it.</p>

""" + h2("t11", "11. The app is provided as it is") + """
        <p>We work to keep Own Hub accurate and available, but we do not promise
        that it is free of errors, that it will always be available, or that any
        particular result will follow from using it. Exercise and diet outcomes
        depend on you, and on things neither of us controls.</p>
        <p>Content in the app, including exercise instructions, food data and
        cycle information, is general information.</p>

""" + h2("t12", "12. What changes when the rest of the product arrives") + """
        <p>These clauses are <b>not in force in this version</b>. They are
        written down now so that the version that switches each feature on does
        not invent them under time pressure, and each will be published with the
        release that needs it.</p>
""" + kv([
            ("The community",
             "No harassment, threats, abuse, hateful or sexual content about "
             "another member. No screenshotting or reposting another "
             "member&rsquo;s content anywhere. No medical advice to other "
             "members. No selling, advertising, spam or recruiting. We may remove "
             "content and act before reviewing where a woman&rsquo;s safety is at "
             "stake. Reporting and blocking must both actually work before this "
             "clause is published."),
            ("Coaching",
             "Coaches are independent professionals, not our employees. Enquiry "
             "first, then acceptance, then payment. One month at a time, nothing "
             "renews automatically, the price is shown before you pay, and the "
             "card is entered on the payment provider&rsquo;s own page, never in "
             "the app. Refunds, cancellation, the coach agreement and complaints "
             "are separate documents counsel must draft, shown before the first "
             "payment."),
            ("Any payment",
             "The invoicing and tax-record retention Egyptian law requires, which "
             "is an exception to deletion and which the Privacy Policy must then "
             "say plainly."),
        ]) + """

""" + h2("t13", "13. Limits on what we owe you") + """
        <p>To the fullest extent Egyptian law allows:</p>
        <ul>
          <li>We are not liable for injury, illness or loss that results from
          exercise you chose to do, from food you chose to eat, or from following
          general guidance in the app instead of seeing a doctor.</li>
          <li>We are not liable for indirect or consequential loss, lost data,
          lost profits or lost opportunity. Your cycle and health information is
          on your phone alone unless you turn on backup, and keeping your phone
          is your side of that.</li>
          <li>Where liability cannot be excluded, it is limited to
          {{liabilityCap}}</li>
        </ul>
        <p><b>Nothing here excludes liability that Egyptian law does not allow us
        to exclude</b>, including for death or personal injury caused by our own
        negligence, or for fraud.</p>

""" + h2("t14", "14. Changes to these Terms") + """
        <p>We may update these Terms. We will post the new version here with the
        date, and where a change matters we will tell you in the app before it
        takes effect. Continuing to use Own Hub after that means you accept the
        new version.</p>

""" + h2("t15", "15. Law and disputes") + """
        <p>These Terms are governed by the laws of the Arab Republic of Egypt.
        Disputes go to the courts of {{courtVenue}}</p>
        <p>Own Hub is offered in Egypt.</p>

""" + h2("t16", "16. The rest") + """
        <ul>
          <li>If a court finds one clause unenforceable, the rest stays in
          force.</li>
          <li>Not enforcing a clause once does not waive it.</li>
          <li>These Terms, plus the <a href="/privacy">Privacy Policy</a>, are
          the whole agreement between us about Own Hub.</li>
          <li>You may not transfer your rights under these Terms. We may transfer
          ours if the business is sold.</li>
          <li>Apple and Google are not parties to these Terms and are not
          responsible for Own Hub. Your use of their stores is governed by their
          own terms.</li>
          <li>Own Hub uses the Rubik, La Belle Aurore and Aref Ruqaa typefaces
          under the SIL Open Font Licence 1.1.</li>
        </ul>

""" + h2("t17", "17. Contact") + """
        <p>{{mailto:contactSupport}}<br>
        {{legalEntity}}, {{legalAddress}}</p>
""" + kv([
            ("Date", "{{effectiveDate}}"),
            ("Version", "2.0"),
            ("What changed",
             "Accounts and the women-only check. Replaces version 1.0, which was "
             "written for a release with no account. Still no community, no "
             "coaching and no payments."),
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
          stay on the old phone. There is no export in this version, and the app
          says so rather than offering a button that would produce
          nothing.</p>

""" + h3("q-signin", "Where do I sign in? Where is the community?") + """
          <p>You sign in with your Egyptian mobile number and a code sent by
          SMS. There is no password. The first time, you are also checked once
          with your national ID card and a live selfie; if the automatic check
          is unsure, or you choose the niqab route, a woman reviewer phones you
          to arrange a short video check. There is no community, no coaching
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
          Germany, where only your account can read them. Your cycle, check-ins,
          measurements, life stage, allergies and weight only if you turn on
          health backup yourself.</p>
          <p>If the app crashes, Firebase Crashlytics receives a crash report
          with no account identifier, name or phone number. There is no
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
        <p>Before deleting, we will phone that number to confirm the request is
        yours, then complete the deletion within {{rightsResponseWindow}} and
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
          new account. Whether a woman who deleted her account may rejoin is a
          question we have put to counsel.</li>
          <li><b>Safety reports</b> you made, or that were made about you, are
          kept for the safety of other members, with your account identifier
          replaced by a random code.</li>
          <li><b>A record that your deletion was carried out</b>, reduced to its
          status and dates, as proof that your request was honoured.</li>
        </ul>
        <p>Google removes its own backups within its own deletion window.</p>

""" + h2("cannot-undo", "It cannot be undone") + """
        <p>There is no restore and no grace period. Once it is done, your logs
        and your history are gone.</p>
        <p><b>Downloading a copy first is not built into the app yet.</b> If you
        want a copy, write to {{mailto:contactPrivacy}} before you delete and we
        will send it to you by email.</p>

""" + h2("some-of-it", "Delete only some of it") + """
        <ul>
          <li><b>Health backup can be switched off</b> in Profile, then Privacy.
          That deletes the copy of your health information on our servers and
          keeps the one on your phone.</li>
          <li><b>Cycle data can be deleted on its own</b>, from cycle settings.</li>
          <li>You can delete individual logs, meals and measurements as you
          go.</li>
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
