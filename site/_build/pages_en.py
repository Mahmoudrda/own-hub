# -*- coding: utf-8 -*-
"""English content for the Own Hub public site.

The legal text is taken from docs/release/privacy-policy.md, terms.md and
delete-account.md, which were written against the shipping code. The substance
is not rewritten here. Markers only the owner can fill are left as {{tokens}}
and resolved from config.json at build time.
"""

from __future__ import annotations

import art


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
            f"          <h3>{title}</h3>\n"
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

I am writing about the Own Hub app (iPhone com.ownhub.fitness, Android com.ownhub.app).

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
            <label for="consent"><b>I agree.</b> We will message you once: an early invite if you are among the first 100, or the day Own Hub opens. Then we delete your contact.</label>
          </p>
          <div class="btn-row"><button class="btn" type="submit">Join the waitlist</button></div>
        </form>
'''


# ---------------------------------------------------------------- build ----

def build(cfg, lang, mailto_link, store_badges, shot):
    delete_button = mailto_link(
        cfg, lang, "contactPrivacy", DELETE_SUBJECT, DELETE_BODY,
        "btn", "Open a ready-made deletion email",
    )

    pages = {}

    # The store badges. Until a store link is set in config.json each badge
    # is drawn as "Coming soon" and is not a link; the waitlist stands in.
    live = bool(cfg.store_url("storeUrlIos")) and bool(cfg.store_url("storeUrlAndroid"))
    hero_badges = store_badges(cfg, lang, where="hero")
    if live:
        eyebrow = "A fitness app for women in Egypt"
        hero_cta = hero_badges
        # Apple allows one App Store badge per layout: the hero carries it,
        # so this section links in words.
        download_section = """
    <section class="download" aria-labelledby="download">
      <div class="wrap">
        <div class="panel">
          <div class="prose">
""" + h2("download", "Get Own Hub", "no-rule") + """
        <p>Free on iPhone and Android. You can look around it before you
        sign up, if you like.</p>
        <p><a href=""" + '"' + cfg.store_url("storeUrlIos") + '" rel="noopener">Own Hub on the App Store</a>' + """ &middot; <a href=""" + '"' + cfg.store_url("storeUrlAndroid") + '" rel="noopener">Own Hub on Google Play</a></p>' + """
          </div>
        </div>
      </div>
    </section>
"""
    else:
        # Not in the stores yet: the page has one job, the waitlist, and it
        # is the first thing on it. The badges below it say "Coming soon".
        eyebrow = "Opening soon, for women in Egypt"
        hero_cta = """
          <div class="offer" id="download">
            <p class="offer-t"><b>Free, all of it.</b>
            The first 100 women on the list try Own Hub before it opens to
            everyone.</p>
            <div class="form-card">""" + FORM + """
            <p class="small">That&rsquo;s all we ask for. The waitlist isn&rsquo;t an
            account. What we keep, and for how long, is in the
            <a href="/privacy#c-waitlist">privacy policy</a>.</p>
            </div>
          </div>
          """ + hero_badges
        download_section = ""

    # ------------------------------------------------------------ index ----
    pages["index"] = {
        "title": "Own Hub · a fitness app for women in Egypt",
        "description": (
            "Own Hub is a free fitness app for women in Egypt, and only for "
            "women. Every member is checked once, and her ID and selfie photos "
            "are never stored."
        ),
        "body": """
    <section class="hero">
      <div class="wrap hero-grid">
        <div class="hero-copy">
          <p class="eyebrow">""" + eyebrow + """</p>
          <h1>Workouts and food that fit your month. <span class="hand">Women only.</span></h1>
          <p class="lede">Home workouts, food you already cook, and a plan that follows how you
          feel from day to day. Only verified women get in. It works in Arabic and English.</p>
          """ + hero_cta + """
        </div>
        <div class="hero-art">
          <figure class="phone">""" + shot(lang, "02-home", "The Own Hub home screen: today's workout, this week's progress, and breakfast.", sizes="(min-width: 62rem) 300px, 240px", eager=True) + """</figure>
          """ + art.kitten_svg() + """
        </div>
      </div>
    </section>

    <section class="band" aria-labelledby="inside">
      <div class="wrap">
        <div class="lead-row">
        <div class="prose">
""" + h2("inside", "What is inside it", "no-rule") + """
          <p class="lede">Want to see it first? Open the app and look around before you
          sign up: Home, workouts and recipes. What you enter before you sign up
          stays on your phone.</p>
        </div>
        """ + art.hairline_svg("phone", "mark") + """
        </div>
        <ul class="shots">
          <li><figure>""" + shot(lang, "03-workout", "The workout player: one move, three sets, and a button for the set you just finished.", sizes="(min-width: 62rem) 280px, 200px") + """<figcaption><b>Train.</b> Every move has a short video. Tap a set when you finish it, and the rest timer starts itself.</figcaption></figure></li>
          <li><figure>""" + shot(lang, "06-progress", "Her progress card: workouts done, meals added and personal bests, ready to share. Her weight is on it only if she adds it.", sizes="(min-width: 62rem) 280px, 200px") + """<figcaption><b>Progress.</b> One card with everything you&rsquo;ve done. Share it if you like.</figcaption></figure></li>
          <li><figure>""" + shot(lang, "07-tour-dinners", "A week of dinners: five sample dinners, planned for you.", sizes="(min-width: 62rem) 280px, 200px") + """<figcaption><b>Eat.</b> A week of dinners planned for you, gentler on harder days.</figcaption></figure></li>
        </ul>
        <p class="small">Coaching with Own Hub-reviewed coaches is available, free for
        now. This version has no community or assistant, and nothing in the app
        connects you to another member except a coach you choose.</p>
      </div>
    </section>

    <section aria-labelledby="women-only">
      <div class="wrap split even">
        <div class="prose">
""" + h2("women-only", "Women only, checked once", "no-rule") + """
          <p class="lede">A women-only space only means something if someone checks.
          So we check every member once, at the door, and then stay out of her
          way.</p>
          <p>Whatever you note about your body, plus your measurements and weight,
          stays on your phone unless you choose to back it up, or to send some
          of your answers to a coach you ask to join. The <a href="/privacy">privacy policy</a>
          says exactly what the app keeps, where, and for how long.</p>
          """ + art.hairline_svg("lockers", "mark") + """
        </div>
          <ol class="steps card">
            <li>You join with your Egyptian mobile number and a code sent by SMS.</li>
            <li>Usually you show your national ID card and take a live selfie.
            If the check can&rsquo;t decide, or you prefer it, a woman from Own Hub
            checks you instead.</li>
            <li>The check runs on our own server in Frankfurt, Germany. The
            photographs of your card and your face are never stored.</li>
          </ol>
      </div>
    </section>
""" + download_section + """
    <section aria-labelledby="doors">
      <div class="wrap">
        <div class="prose">
""" + h2("doors", "The rest of this site", "no-rule") + """
        </div>
        <ul class="doorways">
          <li><a href="/privacy"><span class="t">Privacy Policy</span><span class="d">What the app collects, where it is kept, and why your ID and selfie photos are never stored.</span>""" + art.hairline_svg("vault", "door") + """</a></li>
          <li><a href="/terms"><span class="t">Terms of Use</span><span class="d">What Own Hub is, what it is not, and the medical warning worth reading even if you skip the rest.</span>""" + art.hairline_svg("drawer", "door") + """</a></li>
          <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person, when messages get read, and answers to what women ask most.</span>""" + art.hairline_svg("query", "door") + """</a></li>
          <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to delete your account from inside the app, and how to ask without installing it.</span>""" + art.hairline_svg("basket", "door") + """</a></li>
        </ul>
      </div>
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
          <b>Last updated:</b> {{lastUpdated}}<br>
          <b>Applies to:</b> Own Hub for iPhone, bundle id <code>com.ownhub.fitness</code>,
          and Android, package <code>com.ownhub.app</code>, and this website.
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
            To keep it that way, we check every member once, when she joins:
            usually with her Egyptian national ID card and a live selfie,
            sometimes by a woman on our team instead (sections 3.3 and
            3.4).</li>
            <li><b>The photographs of your card and your face are never
            stored.</b> Our server in Frankfurt, Germany reads them in memory
            and discards them when the check ends. We keep the result for 180
            days. When your ID number is read, we also keep a keyed code made
            from it, so that one card cannot open two accounts.</li>
            <li><b>Your cycle, check-ins, measurements, weight, pregnancy or
            postpartum stage and allergies stay on your phone,</b> unless you
            turn on health backup yourself. The one other exception: if you ask
            to join a coach, the answers you choose to send her, such as your
            allergies, your life stage and your answers to seven health
            questions, are stored on our server in Frankfurt and shown to that
            coach (section 3.16).</li>
            <li>Once you are verified, your workouts and meals are copied to
            Google Cloud in Frankfurt, so a new phone does not mean starting
            again. No other member can see them, unless you choose to share a
            dish (section 3.13), which is shared without your name.</li>
            <li>If you choose to apply to coach, your application, with its
            documents and photos, is kept on our server in Frankfurt. Only
            Own Hub&rsquo;s woman reviewer sees all of it, and members see only
            the public portfolio you build (section 3.15).</li>
            <li>If you join a coach, your chat with her and the plans she shares
            are stored on our server in Frankfurt, readable by the two of you.
            Own Hub&rsquo;s team reads a chat only after one of you reports it
            (sections 3.16 and 3.17).</li>
            <li>To send your sign-in code, your phone number goes to Google
            Firebase in the United States.</li>
            <li>We do not sell your data. There are no adverts and no tracking.
            Usage statistics and crash reports are each sent only if you allow
            them, and never include your health information. Usage statistics
            go to Google Analytics and PostHog, including in the United
            States.</li>
            <li><b>We never use your data to train AI, ours or anyone&rsquo;s.</b></li>
            <li>You can look around parts of the app before you sign up, and
            what you enter then stays on your phone (section 3.1).</li>
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
        <p>When your ID card is checked, your sex and your age are read from
        the digits of your national ID number. We never guess them from your
        face. A woman can also be approved by a woman on our team, as section
        3.4 describes.</p>
        <p>We do not knowingly collect data from anyone under 18. If the check
        shows that you are under 18, your application is refused. The refusal
        is kept as section 6 describes.</p>

""" + h2("collect", "3. What we collect, why, and on what basis") + """
        <p>Each basis below is one that Egypt&rsquo;s Personal Data Protection
        Law allows (Law 151/2020, Articles 2, 6 and 12).</p>
""" + h3("c-account", "3.1 Your account") + """
        <ul>
          <li><b>Before you sign up.</b> You can use parts of Own Hub without an
          account: Home, workouts with their videos, food search and recipes.
          What you enter then, such as your setup answers, stays on your phone
          and is not sent to our servers. If you try something that needs an
          account, such as starting a workout or logging a meal, the app keeps
          it on your phone and finishes it once you are verified.</li>
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
        server has recorded that agreement. For this check the camera is the
        only way to take the photographs: the app cannot upload a picture that is already on
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
          Protection Centre. Own Hub is applying for this permit under Law
          151/2020, and will show its number in section 1 once the Centre
          issues it.</li>
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
          Each lookup is recorded with the reviewer and the time. She usually
          phones you within 72 hours of your request, or at the time you book,
          to finish your check with you. There is no video call for this
          check.</li>
          <li><b>A time you book.</b> You can book a time for the call from the
          free times a reviewer offers. We keep the reviewer, the time and when
          you booked it. The booking is deleted when you are approved, when you
          delete your account, or automatically 30 days after the booked
          time.</li>
          <li><b>A reviewer you know.</b> If you choose a reviewer under
          &ldquo;I know one of the reviewers&rdquo;, we note on your account
          which reviewer you chose, so that your request goes to her.</li>
          <li><b>How a reviewer approves you.</b> A woman reviewer can approve
          you after she has talked to you, or without a call, for example
          when she knows you. An Own Hub administrator can also approve an
          account, for example when no reviewer is available. We record how
          you were approved and when, and who approved you.</li>
          <li><b>A number approved before you join.</b> A reviewer can add a
          phone number to a pre-approved list before that woman signs up. When
          you sign in with a number on the list, you are approved without the
          ID check, unless your check was refused or your approval taken back
          before, and the number is removed from the list. Until it is used or
          a reviewer removes it, it is kept on our server, where only the Own
          Hub team can see it. To have a number removed, write to
          {{mailto:contactPrivacy}}.</li>
          <li><b>Without your ID number.</b> If you are approved by a reviewer
          or from the list and your ID number was never read, no keyed code of
          an ID number is kept for your account.</li>
          <li><b>Nothing is recorded.</b> The check is not recorded, and the
          reviewer writes down only her decision and the date.</li>
          <li><b>Your ID number.</b> If your case has no ID code yet, the
          reviewer may ask you to read out your ID number. It is turned into
          the keyed code at once, and is never stored or written to a log.</li>
          <li><b>Our team&rsquo;s alert.</b> When a case enters the queue, our
          team gets an alert containing only the case number and the reason
          codes. It is sent through {{chatService}}.</li>
          <li><b>Basis:</b> your consent, given when you ask for the review. For
          a number added to the pre-approved list before you join, the basis is
          your request to the reviewer to let you join this way; the number is
          used only for that and removed once it is used.</li>
        </ul>

""" + h3("c-training", "3.5 Your training and meals") + """
        <p>Workouts, sets, weights and repetitions, weekly goals, personal
        bests, the meals you log, your usual plates, your protein target and
        your meal plans stay on your phone. Once your account is verified, a
        copy is also kept in Google Cloud Firestore in Frankfurt, Germany, so
        that it survives a lost or replaced phone. Server security rules let
        only your own verified account read it. No other member can see
        it, unless you choose to share a dish (section 3.13), which is shared
        without your name.</p>
        <p>Your Ramadan setting stays on your phone only.</p>
        <p>If you add an Own Hub widget to your Home Screen or Lock Screen, it
        shows how many sessions you have done this week, whether today&rsquo;s
        workout is done and whether you have logged a meal, and nothing else.
        The widget reads this from your phone. It never shows your cycle,
        pregnancy or postpartum stage, weight, measurements or allergies, and
        nothing is sent anywhere. Signing out or deleting your account clears
        it.</p>
        <p>Your profile photo stays on your phone. Own Hub never uploads it.
        Only you see it. Delete everything removes it from this phone; if you
        back up your whole phone, a copy made earlier stays in that
        backup.</p>
        <p>The workout card you can share is made on your phone from your
        session, its calories are an estimate, and nothing is sent unless you
        tap Share and choose where it goes; there is no account and no
        tracking involved.</p>
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
        <p>How you say you feel after a session and your answers on the
        Friday week review stay on this phone. They are never part of the
        backup, even when health backup is on, they are never sent for
        statistics, and <b>Delete everything</b> erases them.</p>
        <p><b>The exception: a coach you ask to join.</b> If you ask to join a
        coach, the answers you choose to send with your request are stored on
        our server in Frankfurt, Germany, and shown to that coach: your goal,
        level, training days and where you train, your life stage, the
        allergies you keep on the form, your answers to the seven health
        questions, whether you have spoken to your doctor, your note, and your
        first name if you give it (section 3.16). This is separate from health
        backup, and nothing else from your phone is sent with it.</p>
        <p><b>Your cycle and health information is never used for advertising
        or marketing, never sold, never sent to any analytics service, and
        never used to train AI.</b></p>
        <ul>
          <li><b>Basis:</b> your explicit consent, given in writing in the
          app, which the law requires for health data. The law also requires a
          permit from the Centre, which Own Hub is applying for (section
          3.3).</li>
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
          crashes: the type of error and where in the code it happened, the
          screen it happened on (shown as &ldquo;private&rdquo; for screens
          about your body or your cycle), your device model, operating system,
          app version, free memory and storage, and an installation
          identifier. It also receives a report when one of our servers fails
          in a way that is our fault, with only the error&rsquo;s status code.
          If you have also turned on usage statistics, the last screens and
          steps you used are shown with the report. What is never attached:
          your account identifier, your name, your phone number, or the text of
          any error. If you turn them off, reports waiting on your phone are
          deleted.</li>
          <li><b>Usage statistics (&ldquo;Help improve Own Hub&rdquo;), only if
          you allow them.</b> A separate switch on the sign-up screen and in
          Profile, then Privacy. Off until you turn it on. When it is on, Google
          Analytics for Firebase receives which screens you open (by a short
          screen code such as &ldquo;T01&rdquo;) and which steps you reach: the
          tour, each sign-up step, whether the ID check started, went to a
          reviewer, asked for new photos, let you in or was refused (one word,
          never why), your first workout and meal, reaching your weekly target,
          coming back after a week or more away, and your language and kitten
          settings. Google adds a random app instance identifier, your device
          model, operating system and app version, and an approximate location
          it works out from your IP address. <b>It never receives your health
          information, cycle, body measurements, weight, life stage, pregnancy,
          allergies, name, phone number, ID number, anything you type, or the
          names of recipes or programmes.</b> We do not give it your account
          identifier and do not link what it receives to your account. We never
          use it for advertising: there is no advertising identifier, and
          advertising uses are switched off. If you turn it off, collection
          stops at once and the identifier on your phone is reset, so what was
          sent before cannot be joined to anything sent later.</li>
          <li><b>PostHog, with the same switch.</b> When usage statistics are
          on, PostHog, in the United States, also receives a few app
          milestones: starting and finishing the tour, starting and finishing
          sign-up, signing in, starting and finishing a workout, and sending a
          coaching request. With them come a random identifier for this
          installation and technical details the PostHog library adds, such as
          your device model, operating system and app version. Each time the
          app starts, it also sends one fixed technical line that says only
          that statistics are working. We send PostHog no account identifier,
          health information, messages or payment details. For the milestones
          we ask it not to work out your location from your IP address. It
          builds no profile of you, and session recording is off. If you turn usage statistics off,
          collection stops and the identifier is reset. What PostHog already
          received is not linked to your account, and it is kept as section 6
          says.</li>
          <li><b>Our server logs.</b> These record outcomes and reason codes.
          They never record your phone number or your ID number, and they never
          place your account identifier beside an outcome.</li>
          <li><b>Basis:</b> keeping the service secure and working, which the
          law allows (Law 151/2020, Article 6, point 4), except crash reports
          and usage statistics, which each need your consent. ML Kit runs only on the selfie screen, after
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
          <li>If you choose to analyse a photo of a meal, Google Cloud Vertex AI
          (Gemini) reads it to estimate the food on the plate. Section 3.12
          explains how.</li>
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
          <li>We use it for one thing: to message you once. If you are among
          the first 100 to join, the message invites you to try Own Hub before
          it opens to everyone; otherwise it tells you the day it opens. Then
          we delete it.</li>
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

""" + h3("c-notifications", "3.11 Reminders and notifications") + """
        <p>Most notifications Own Hub shows are made on your phone and never
        come from our servers. Two kinds come from our server: word that your
        account check is done, and coaching notifications.</p>
        <ul>
          <li><b>Scheduled on your phone.</b> Training reminders, rest-timer
          alerts, the &ldquo;add a session you did&rdquo; nudge and the gentle
          check-ins after some days away are all scheduled by the app on your
          phone. They are never sent from our servers, and we do not receive
          anything about them.</li>
          <li><b>The words are chosen on your phone.</b> The words of a
          reminder are chosen on your phone from what you did in the app, such
          as your training days, the food you log and which notes you open, and
          nothing about that choice is sent anywhere.</li>
          <li><b>Event reminders.</b> When Own Hub events are open to you, the
          app reads the list of events and, for the next few, whether you
          booked a seat. It then schedules a few notes on your phone: three
          days, one day and three hours before an event you have not booked,
          and the morning of and three hours before an event you have booked.
          The notes do not name the event. They are scheduled on your phone,
          never sent from our servers, and we receive nothing about them. You
          can turn them off with Event reminders in Notifications. Quiet hours
          apply.</li>
          <li><b>What we store for push.</b> If you ask to be told when your
          check is done, we store a device token for this phone. We use it to
          tell you that your check is done and, if you use coaching, to send
          the coaching notifications below to this phone. We use it for
          nothing else. It is deleted when you delete your account.</li>
          <li><b>Coaching notifications.</b> If you apply to coach or use
          coaching, our server sends notifications through Firebase Cloud
          Messaging to a phone registered for them: news about your coach
          application or your portfolio photos, a new coaching request, an
          answer to a request, a coaching that starts, ends soon or has ended,
          a new message, a shared plan and a proposed live session. The text on
          your lock screen is one fixed, general line, such as &ldquo;You have a
          new message.&rdquo;, and never contains a message, a name, a plan or an
          amount. They are sent when the event happens, at any time of
          day.</li>
          <li><b>Quiet hours.</b> Reminders scheduled on your phone are never
          shown between 22:00 and 08:00. Anything due in that time waits until
          08:00. Three things can still reach you then: a rest timer you
          started yourself, word that your account check is done, and coaching
          notifications.</li>
          <li><b>Your choice.</b> You can turn each type of reminder off in
          Notifications in the app. Notifications from our server have no
          switch in the app: to stop them, turn off notifications for Own Hub
          in your phone&rsquo;s settings, which turns off all the others
          too.</li>
          <li><b>What they never show.</b> Notifications never show health,
          cycle or weight details.</li>
        </ul>

""" + h3("c-meal-photos", "3.12 Meal photos") + """
        <p>Once your account is verified, you can photograph a meal and Own Hub
        will estimate what is on the plate. This is optional. You can always
        type your meal instead.</p>
        <ul>
          <li><b>When a photo is sent.</b> Only when you tap &ldquo;Analyse my
          meal&rdquo;, after you have seen the photo. Nothing is sent while the
          camera is open, and nothing is sent on its own.</li>
          <li><b>Where it goes.</b> To Google Cloud Vertex AI (Gemini) in the
          European Union, in Frankfurt, Germany (europe-west3). The photo is
          sent once, without its location or other details from your camera,
          and is used only to estimate the meal.</li>
          <li><b>Not kept.</b> Own Hub does not keep the photo, on your phone
          or on our servers, and never puts it in your photo library. To take
          it, the camera writes a temporary copy on your phone for a moment,
          and the app deletes that copy right away. The photo is then held only
          in the app&rsquo;s memory, and is deleted as soon as the estimate
          comes back. Our server logs record only the outcome and how many
          foods were found, never the photo or the food. Separately from the
          logs, see the next point.</li>
          <li><b>A repeat answer, kept 30 days.</b> To answer the same photo
          again without asking Google again, our server keeps a fingerprint of
          the photo (a one-way code made from the photo, from which the photo
          cannot be rebuilt) and the foods and weights found in it, for 30 days,
          then deletes them automatically. It holds no photo, and nothing that
          identifies you: no account identifier, name or phone number. It is
          used only when the exact same photo is analysed again.</li>
          <li><b>Not used for training.</b> Under Google Cloud&rsquo;s terms,
          Google does not use the photo to train its models, and we never do
          either.</li>
          <li><b>An estimate you check.</b> The foods and their weights are a
          guess. The energy, protein, carbohydrate, fat and fibre figures come
          from public nutrition tables (USDA FoodData Central) and a table of
          Egyptian dishes, never from the AI. You can change every item, its
          weight and its figures, remove it or add another, and nothing is
          logged until you tap &ldquo;Log this meal&rdquo;. What you log is
          kept with your meals (section 3.5).</li>
          <li><b>A limit.</b> Up to 5 meal photos a day for each member.</li>
          <li><b>Your agreement.</b> Before your first meal photo, the app asks
          for your agreement and our server records it, with the date, the
          language and the app version. If you do not agree, the camera does
          not open.</li>
          <li><b>Basis:</b> your consent, given in the app before your first
          meal photo.</li>
        </ul>

""" + h3("c-dish-sharing", "3.13 Sharing a dish with other members (optional)") + """
        <p>Under the meal check, and in Profile, then Privacy, there is a switch
        that lets you help other members find Egyptian dishes. It is <b>off</b>
        until you turn it on, and it is separate from the meal photo
        agreement.</p>
        <ul>
          <li><b>What is sent.</b> Only when the switch is on and you tap
          &ldquo;Log this meal&rdquo;: the name of the dish or dishes, what is in
          it (the names of the foods and their weights) and the energy, protein,
          carbohydrate and fat figures. It goes to a list on our server
          that only the Own Hub team can read. It never includes your photo or
          your name.</li>
          <li><b>How we count you once.</b> To avoid counting your confirmation
          twice, the server keeps a marker made from your account identifier
          with a secret key that only the server holds, so the marker cannot be
          turned back into you by anyone without that key. The marker is deleted
          when you delete your account. A dish waiting for review that only you
          had confirmed is deleted with it.</li>
          <li><b>Review.</b> The Own Hub team reviews each dish before anyone
          sees it.</li>
          <li><b>What other members see.</b> A dish the team approves is shown to
          all verified members, with its name, category, allergens and figures.
          It does not show what is in it, your photo or your name, and it carries
          no link to you.</li>
          <li><b>Turning it off.</b> Turning the switch off stops any future
          sharing. It does not withdraw dishes that have already been approved,
          because they carry no link to you and we cannot tell which are
          yours.</li>
          <li><b>Basis:</b> your consent, given by turning the switch on.</li>
        </ul>

""" + h3("c-events", "3.14 Event seats") + """
        <p>If you reserve a seat at an Own Hub event, our server records your
        place: your account identifier, when you reserved and the status of the
        seat, under that event. Only you and the Own Hub team can read it. The
        team uses it to count seats and run the event. Cancelling your seat
        deletes it, and so does deleting your account.</p>
        <ul>
          <li><b>Basis:</b> performing our agreement with you.</li>
        </ul>

""" + h3("c-coach", "3.15 If you apply to coach (optional)") + """
        <p>This applies only if you choose to apply, from <b>Profile</b>, then
        <b>Become a coach</b>, and only if you are a verified member. If you
        never apply, none of it happens. Coaches are checked before members can
        see them. In this version an approved coach has a public portfolio that
        members can read, and members can join a coach for free
        (section 3.16). Payments are not offered yet, so no payment data
        exists.</p>
        <p><b>What an application holds:</b></p>
        <ul>
          <li>your full name, used only for the review;</li>
          <li>your display name, governorate, languages, a one-line headline
          and your profile photo;</li>
          <li>your education (degree, institution and year) and your
          certificates (title, issuer and year), each with a photo of the
          document if you add one;</li>
          <li>your specialties, years of experience and qualifications;</li>
          <li>at least two pieces of feedback from clients: the words, who it
          is from as you typed it, and a screenshot if you add one;</li>
          <li>at least one before and after transformation, with the photos of
          your client and your confirmation that she agreed in writing;</li>
          <li>optionally, photos of yourself or your work;</li>
          <li>how you coach: your approach, check-ins each week, how quickly
          you reply and where you train;</li>
          <li>the version of the coach terms you accepted, and when. You accept
          them in the last step, and the <a href="/coach-terms">Coach Terms</a>
          are published on this site.</li>
        </ul>
        <p>Until you send it, your draft stays on your phone, and <b>Delete
        everything</b> erases it. You pick each picture with the camera or your
        phone&rsquo;s own picker, and Own Hub receives only the pictures you
        choose. When you send the application they are uploaded to Google Cloud
        Storage in Frankfurt, Germany, in a folder that only your account can
        write to. Feedback screenshots and before and after photos show other
        people, so add them only with the written consent of the woman in
        them. Photos of yourself or your work are yours to choose.</p>
        <p>The reviewer checks every picture before members see it. When she
        approves one, Own Hub keeps a re-encoded copy with no location or other
        metadata and deletes the original. You can remove any item from your
        portfolio yourself, and all of it is deleted with your account.</p>
        <p><b>Who sees what:</b></p>
        <ul>
          <li>Own Hub&rsquo;s woman reviewer sees the whole application,
          including feedback screenshots and transformation photos, to decide
          it.</li>
          <li>The Own Hub administrator can read the written parts of the
          application and open your profile photo, education documents and
          certificates. Before an item is approved, only you and Own Hub&rsquo;s
          woman reviewer can open your feedback screenshots and before and after
          photos. Once approved, an item is shown to verified members on your
          portfolio like the rest of it.</li>
          <li>No member sees your application. Your full name is never shown to
          members.</li>
          <li>Once the reviewer approves you, verified members can see your
          public portfolio, and only this: your display name, a copy of your
          photo, your headline, your approach, your specialties, languages and
          years of experience, how quickly you reply and where you train; the
          title, issuer and year of the certificates the reviewer checked; the
          feedback text, with the name or word you typed beside it, and the
          feedback screenshots, before and after photos and photos of you or
          your work that the reviewer approved; and your packages, with what
          each includes and its price.
          Members can ask to join a coach for free (section 3.16); nobody can
          pay yet.</li>
          <li>A member can report a portfolio. The team reads the report and may
          hide or suspend the portfolio (Coach Terms, section 7).</li>
        </ul>
        <p><b>Why:</b> to check coaches before members see them, and to show
        the portfolio you build. Nothing from an application is used for
        advertising or to train AI.</p>
        <p><b>How long:</b> your application and its files are kept while you
        are a coach, or until you delete your account. If an application is
        not approved, or the reviewer asks for changes, it and its files are
        kept on our server with no automatic deletion date, so that we can tell
        you why and so that you can apply again after 30 days. Deleting your
        account removes all of it (section 7).</p>
        <p><b>To withdraw an application:</b> write to {{mailto:contactPrivacy}}
        and we will delete it, or use <b>Delete everything</b> in the app.</p>
        <ul>
          <li><b>Basis:</b> your consent, given when you accept the coach terms
          and send the application. The photos of your clients rest on the
          written consent you confirm you hold.</li>
        </ul>

""" + h3("c-coaching", "3.16 Joining a coach, and chatting with her") + """
        <p>This applies only if you ask to join a coach, from her portfolio. It
        is free: Own Hub offers no payments yet, so no payment details are asked
        for or kept.</p>
        <ul>
          <li><b>What you share with her.</b> When you ask to join, you fill in
          a short form: your goal, your level, how many days a week, where you
          train, the allergies you choose to keep on it (they come filled in
          from your profile and you can remove them), your life stage, your
          answers to seven health questions, whether you have spoken to your
          doctor, and a note if you write one. Your first name, if you give
          it, goes to the coach you ask, together with your answers. Our server
          stores it with the request, in Frankfurt, Germany.</li>
          <li><b>Who sees it.</b> Only that coach, and only while the coaching
          lasts. When it ends, she loses access to it. Nobody else sees it. You
          can still read it, and it is kept until you or the coach delete your
          account.</li>
          <li><b>Chat.</b> Once the coach accepts, you and she can exchange text
          messages. They are stored on Google Cloud Firestore in Frankfurt,
          readable by both of you. Own Hub staff read a thread only after one
          of you reports it. When the coaching ends the chat closes, and the
          messages stay until either of you deletes her account, which deletes
          the coaching and its messages (a reported message is kept as section
          3.17 describes). Messages that contain a phone number,
          payment details, a link or abusive words are blocked: the app stops
          them before they are sent, and if one reaches our server, the server
          hides it and erases its text.</li>
          <li><b>Plans a coach shares.</b> A workout plan or meal plan she
          shares with you is stored under your account, so you can follow it
          in the app.</li>
          <li><b>Live sessions.</b> If her package includes live sessions, she
          proposes a time and a link to a video call in Google Meet, Zoom or
          Microsoft Teams, and you confirm or decline. Own Hub has no video of
          its own: the session opens in that service, outside the app, under
          that service&rsquo;s own privacy terms, and Own Hub receives nothing
          from the call. With the coaching we store the time, its length, the
          link, its status and which of you marked it done. You can read them,
          and the coach can while the coaching lasts.</li>
          <li><b>Reminders.</b> When she writes, we may send you a push
          notification through Firebase Cloud Messaging, at most once every few
          minutes for a conversation. It does not show the message (section
          3.11).</li>
          <li><b>Report and block.</b> Every coaching chat has Report and Block,
          and a coach&rsquo;s portfolio has Report (section 3.17).</li>
          <li><b>Basis:</b> your consent, given on the form when you ask to
          join, and performing the free coaching you asked for.</li>
        </ul>

""" + h3("c-chat-media", "Voice notes, photos and videos in coaching chat") + """
        <p>If you coach with a coach on Own Hub you can send her, and she can send you, voice notes, photos and short videos (up to 120 seconds of audio and 30 seconds of video). Own Hub asks for your microphone only when you press and hold the mic button, and for your camera or a photo you pick only when you choose to send one. We store these files so that you and your coach, and nobody else, can listen and watch again. They are sent over an encrypted connection and are not used for advertising, for training any model, or for anything other than showing them in the chat. Photos are re-saved without the location and device details your phone adds. Videos can still contain such details, so film in a place you are happy to share. If a message is reported, a woman reviewer at Own Hub may see that file. The files are deleted when the coaching chat is deleted and when you delete your account.</p>

""" + h3("c-reports", "3.17 Reports and blocks") + """
        <p>You can report a coach&rsquo;s portfolio or a message, and you can
        block the coach or the client you are talking to.</p>
        <ul>
          <li><b>What a report holds.</b> Who made it and who it is about, by
          account identifier; what was reported; the reason you chose from a
          list; any note you write, up to 1,000 characters; and the date, your
          language and the app version. It also keeps a copy of what was
          reported as it was at the time: the text of the message, or the
          portfolio name and headline.</li>
          <li><b>Who sees it.</b> Only the Own Hub team. The person you report
          is never told who reported her. You can follow your own reports in
          the app, under Reports you made.</li>
          <li><b>What the team does.</b> The team reads the report and, for a
          chat, the thread it is about. It may hide content or suspend an
          account (Terms of Use, section 8).</li>
          <li><b>How long.</b> No deletion period is set. If you delete your
          account, the reports you made or that are about you are kept for the
          safety of other members, with your account identifier replaced by a
          random code wherever it names you, including in the link to what was
          reported. If you are the woman who reported and you delete your
          account, the copy of what was reported is deleted. If you are the
          woman reported and you delete your account, the copy is kept for the
          safety case with your name, picture and account links removed; the
          words that were reported stay. No period is set for that copy yet.</li>
          <li><b>A block.</b> It is kept on your account: whom you blocked,
          when, and from where. The person you block is never told. It stops
          new messages, requests and sessions between you. It stays until you
          unblock her or delete your account.</li>
          <li><b>Basis:</b> keeping members safe and the service working,
          which the law allows (Law 151/2020, Article 6, point 4).</li>
        </ul>

""" + h2("where", "4. Who handles your data, and where") + """
        <p>We do not sell your data, and we do not share it with advertisers,
        data brokers or marketing companies. The service providers below
        process data only on our instructions. Google processes data for us
        under the Google Cloud Data Processing Addendum and the Firebase Data
        Processing and Security Terms. Google Analytics processes usage
        statistics for us under the Google Ads Data Processing Terms, with data
        sharing with Google, Google signals and advertising links all switched
        off.</p>
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
                            "results and the keyed ID code. If you apply to "
                            "coach: your application and its files "
                            "(section 3.15). If you join a coach: your "
                            "form, chat, live session records and shared "
                            "plans (section 3.16). Reports and blocks "
                            "(section 3.17)"),
                ("Where", "Frankfurt, Germany (europe-west3)"),
            ]),
            ("Google Cloud Vision", [
                ("Handles", "The text on your ID card, during the check only"),
                ("Where", "European Union"),
            ]),
            ("Google Cloud Vertex AI (Gemini), only if you analyse a meal photo", [
                ("Handles", "The meal photo, during the estimate only "
                            "(section 3.12)"),
                ("Where", "Frankfurt, Germany (europe-west3)"),
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
            ("Google Analytics for Firebase, only if you allow it", [
                ("Handles", "Usage statistics (section 3.7)"),
                ("Where", "Google data centres worldwide, which include the "
                          "United States"),
            ]),
            ("PostHog, only if you allow usage statistics", [
                ("Handles", "App milestones, an installation identifier, "
                            "device details and one technical line "
                            "(section 3.7)"),
                ("Where", "United States"),
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
          and meals, any health backup, your verification, any meal photo you
          choose to analyse (and the 30-day repeat answer from it), any dish you
          choose to share, your event seats, and, if you apply to coach, your
          application and portfolio, and, if you join a coach, your form and chat.</li>
          <li><b>The United States:</b> your phone number, for sign-in; and, if
          you allow usage statistics, what PostHog receives (section 3.7).</li>
          <li><b>Google data centres worldwide, which include the United
          States:</b> the device checks, ML Kit performance data, crash reports
          if you allow them, and usage statistics if you allow them. Google
          does not let us choose one country for these.</li>
        </ul>
        <p>Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020 allows
        transfers abroad only under a permit from the Personal Data Protection
        Centre, and with your consent. We ask for that consent on
        the sign-up screen, naming these countries, before your phone number is
        sent. We ask again, separately, before any health information is backed
        up. Usage statistics have their own consent, the &ldquo;Help improve
        Own Hub&rdquo; switch, which names Google Analytics and PostHog and says
        the data goes outside Egypt, including to the United States. Nothing
        is sent before you turn it on.</p>
        <p>Permit: {{pdpcPermit}}</p>
        <p>Safeguards: {{transferCountries}}</p>

""" + h2("retention", "6. How long we keep it") + """
""" + kv([
            ("ID card photographs, selfie, name and date of birth from the card, your raw ID number",
             "Never stored. Discarded from memory when the check ends, whatever the result."),
            ("The single-use selfie session", "5 minutes, then deleted automatically"),
            ("Meal photos",
             "Not kept. The camera&rsquo;s temporary copy on your phone exists "
             "only for the moment the photo is taken, and is deleted right "
             "away. The photo is deleted from memory as soon as the estimate "
             "comes back (section 3.12)."),
            ("The repeat answer for a meal photo (a fingerprint of the photo and the foods and weights found; no photo, nothing that identifies you)",
             "30 days, then deleted automatically (section 3.12)"),
            ("A dish you chose to share, while it waits for review (dish names, what is in it, figures; a keyed marker instead of your identity)",
             "While it waits. When the team decides, the dish is not deleted: see the next two rows. The marker is deleted with your account, and a dish still waiting that only you had confirmed is deleted with it (section 3.13)."),
            ("A dish the team declined (dish names, what is in it with weights, figures; a keyed marker instead of your identity)",
             "Kept on our server, where only the Own Hub team can read it, and no deletion period is set. When you delete your account, the marker is deleted; the dish itself stays, because nothing in it identifies you (section 3.13)."),
            ("The review record of a dish the team approved (dish names, what is in it with weights, figures; a keyed marker instead of your identity)",
             "Kept on our server, where only the Own Hub team can read it, and no deletion period is set. It still holds what is in the dish; the published entry below does not. When you delete your account, the marker is deleted; the record itself stays (section 3.13)."),
            ("A count of the dishes you shared today (kept on your verification record)",
             "Replaced the next time you share or scan on a new UTC day, and deleted with your account (section 3.13)"),
            ("A dish the team approved (names, category, allergens, figures; no link to you)",
             "Kept, and shown to verified members. Not withdrawn when you turn sharing off or delete your account, because it carries no link to you (section 3.13)."),
            ("Your seat at an event (account identifier, time reserved, status)",
             "Until you cancel the seat or delete your account (section 3.14)"),
            ("A coach application and its files (section 3.15)",
             "While you are a coach, or until you delete your account"),
            ("An application that was not approved, or sent back for changes, and its files",
             "Kept with no automatic deletion date, so that we can tell you why and you can apply again after 30 days. Deleted with your account."),
            ("The form you filled in to join a coach, and the coaching record",
             "The coach can read the form only while the coaching lasts; you can still read it after that. No other deletion period is set: it is kept until you or the coach delete your account."),
            ("Chat messages with a coach",
             "Kept after the coaching ends, readable by you and the coach, until either of you deletes her account (a reported message is kept as section 3.17 describes). No other deletion period is set. Staff read a thread only after a report."),
            ("Live session records (time, length, link, status, who marked it done)",
             "Kept with the coaching until you or the coach delete your account. The coach can read them only while the coaching lasts."),
            ("Reports you made or that are about you (section 3.17)",
             "No deletion period is set. Kept after you delete your account, with your account identifier replaced by a random code wherever it names you. The copy of what was reported is deleted if you were the one who reported, and kept with your name, picture and account links removed if you were the one reported."),
            ("Your blocks", "Until you unblock or delete your account"),
            ("Plans a coach shared with you", "Until you delete your account"),
            ("Your public coach portfolio and the copy of your photo",
             "While it is published. Deleted with your account."),
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
            ("How you were approved (the route, the reviewer and the date), and the reviewer you said you know",
             "Until you delete your account"),
            ("A time you booked for a review call (reviewer, time, when booked)",
             "Until you are approved or delete your account, and at most 30 days after the booked time, then deleted automatically"),
            ("A phone number on the pre-approved list (section 3.4)",
             "Until it is used when that number signs in, or a reviewer removes it. It is also removed if the approval is revoked or the account with that number is deleted."),
            ("Your account, settings, training, meals, any health backup and your consent records",
             "Until you delete them or delete your account"),
            ("The record that a deletion was carried out (status and dates only)",
             "{{deletionRecordRetention}}, as proof that your request was honoured"),
            ("Daily totals of verifications, with no link to any person", "Kept"),
            ("Our server logs", "{{serverLogRetention}}"),
            ("Crash reports, if you allow them", "{{crashReportRetention}}"),
            ("Usage statistics sent to Google Analytics, if you allow them",
             "2 months for anything tied to the app instance identifier, the "
             "shortest Google Analytics allows, then deleted automatically. "
             "Counts that are not linked to any person, such as how many people "
             "finished the tour, are kept."),
            ("Usage statistics sent to PostHog, if you allow them",
             "Kept by PostHog under its retention settings, which on its free "
             "plan are one year for milestones and 14 days for the technical "
             "line. Not linked to your account, so turning statistics off or "
             "deleting your account does not remove what PostHog already "
             "received."),
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
          <li>any dish the team approved after you shared it, which carries no
          link to you (section 3.13);</li>
          <li>reports you made or that are about you, as section 3.17
          describes (the copy of what was reported is deleted if you made the
          report, and kept without your name if it is about you);</li>
          <li>the record that the deletion was carried out.</li>
        </ul>
        <p>If you joined a coach, deleting everything also deletes the
        coaching, your form, its chat, its live session records and the plans
        she shared. If she deletes her account,
        the same happens to the coaching and chat you had with her.</p>
        <p>If you applied to coach, deleting everything also removes your
        application, its documents and photos, your public portfolio, your
        packages and the copy of your photo.</p>
        <p>Crash reports, usage statistics and ML Kit data are never linked to
        your account. Deleting everything also turns usage statistics off and
        resets the identifier on your phone. Google and PostHog delete this
        data on the schedule in section 6.</p>
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
          that took place before. You can turn off crash reports, usage
          statistics and health backup yourself in Profile, then Privacy;</li>
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
          <li>No analytics unless you turn on usage statistics, and never of
          your health information.</li>
          <li>No sale of your data.</li>
          <li>No training of AI on your data.</li>
          <li>No access to your contacts, location, text messages, or Apple
          Health or Health Connect. The app uses your microphone only while
          you press and hold the mic button in a coaching chat to record a
          voice note for your coach, which is sent when you let go (see
          <a href="#c-chat-media">Voice notes, photos and videos in coaching
          chat</a>); it never listens in the background. The app has no video
          calls: there is no video review, and a live coaching session opens
          in the coach&rsquo;s video service, outside the app (section
          3.16).</li>
          <li>No access to your photo library. If you pick your profile photo
          from your photos, your phone&rsquo;s own picker hands Own Hub only
          the one picture you choose, and that picture stays on your
          phone. The exception is a picture you choose for a coach
          application: it is uploaded when you send the application (section
          3.15).</li>
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
          <li><b>23 October 2026, clarifications:</b> to describe what the app
          already does. Section 3.1 now describes using parts of the app before
          you sign up. Sections 3.3 and 3.6 now say that Own Hub is applying for
          the permit the law requires, instead of saying it is shown in section
          1. Section 3.4 now describes every way a woman reviewer can approve
          you, the pre-approved list and booked review times, and section 2 and
          the short version no longer say that everyone is checked with an ID
          card. Section 3.6 and the short version now name the one exception to
          health information staying on your phone: the answers you send a
          coach you ask to join. Sections 3.7, 4, 5, 6 and 7 now list PostHog
          with the other providers. Section 3.11 now describes the
          notifications our server sends for coaching. Section 3.16 now
          describes live sessions, which open in the coach&rsquo;s video
          service, and everything the chat filter blocks. Section 3.17 is new
          and describes reports and blocks. Section 6 now gives the current
          periods for the coaching form, live sessions, reports, blocks,
          approvals, booked times and pre-approved numbers. None of this
          collects anything new, so you are not asked to accept again.</li>
          <li><b>23 October 2026, portfolio photos:</b> section 3.15 now says
          that an approved coach&rsquo;s portfolio can show members feedback
          screenshots, before and after photos of her clients (each with that
          client&rsquo;s written consent, which the coach confirms) and photos of
          the coach or her work. Own Hub&rsquo;s woman reviewer checks each one
          first, the approved copy is re-encoded with no location or other
          metadata and the original is deleted, and the coach can remove an
          item. It is all deleted with her account. Earlier text said that only
          her profile photo was shown.</li>
          <li><b>23 October 2026, coach applications:</b> section 3.15 is new:
          an optional application for verified women who want to coach, and the
          public portfolio of an approved coach. Sections 4, 5, 6, 7 and 10 now
          mention it, and section 3.16 is new: joining a coach for free and
          chatting with her. It collects nothing unless you apply or ask to
          join, and you accept the Coach Terms or fill in the form with its own
          consent at that moment, so you are not asked to accept again.</li>
          <li><b>21 October 2026, repeat answers, dish sharing and event
          seats:</b> section 3.12 now says a fingerprint of the photo and the
          foods found are kept for 30 days to answer the same photo again.
          Section 3.13 is new: an optional switch, off until you turn it on,
          that shares a dish without your name. Section 3.14 is new: event
          seats. Statements that your meals are seen by no one now name the
          dish-sharing exception. A correction the same day: section 3.13 no
          longer lists fibre, which is not sent, and section 6 now says that a
          dish the team has decided on is kept on our server, with a keyed
          marker instead of your identity (deleted with your account) and no
          deletion period for the dish, and that a count of the dishes you
          shared is replaced the next time you share or scan on a new UTC day.
          Section 3.6 now also says that how you feel after a session and your
          week review answers stay on your phone only. Also that day, to
          explain what already happens on your phone: section 3.11 now
          describes event reminders, which are scheduled on your phone and
          never sent from our servers; section 3.5 now says that your profile
          photo stays on your phone and is never uploaded, and that the workout
          card you can share is made on your phone and sent nowhere unless you
          tap Share; and section 10 now says how the photo picker works. None
          of this collects anything new, so you are not asked to accept
          again.</li>
          <li><b>17 October 2026, meal photos:</b> section 3.12. An optional
          feature with its own agreement, asked in the app before the first
          meal photo. Nothing changes for you unless you use it.</li>
          <li><b>12 October 2026, pre-release analytics update:</b> optional PostHog US usage milestones and one technical status log, requiring fresh analytics consent.</li>
          <li><b>3.0, update before release:</b> usage statistics with Google
          Analytics for Firebase, only with your separate consent (&ldquo;Help
          improve Own Hub&rdquo;), and more detail on what a crash report
          carries.</li>
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
        ("a", "t-conduct", "8. How you treat other members"),
        ("a", "t-coaching", "9. Coaching"),
        ("a", "t8", "10. What you make is yours"),
        ("a", "t9", "11. Free"),
        ("a", "t10", "12. Ending it"),
        ("a", "t11", "13. The app is provided as it is"),
        ("a", "t12", "14. Later features"),
        ("a", "t13", "15. Limits on what we owe you"),
        ("a", "t14", "16. Changes to these Terms"),
        ("a", "t15", "17. Law, disputes and language"),
        ("a", "t16", "18. Apple and Google"),
        ("a", "t17", "19. The rest"),
        ("a", "t18", "20. Contact"),
    ])

    pages["terms"] = {
        "title": "Terms of Use · Own Hub",
        "description": (
            "The terms for using Own Hub: a free fitness app for women in "
            "Egypt, with a women-only account, no community and "
            "nothing to buy. Not a medical device."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Terms of Use</h1>
        <p class="meta">
          <b>Version:</b> 3.0<br>
          <b>Effective date:</b> {{policyEffectiveDate}}<br>
          <b>Last updated:</b> {{lastUpdated}}<br>
          <b>Applies to:</b> Own Hub for iPhone, bundle id <code>com.ownhub.fitness</code>,
          and Android, package <code>com.ownhub.app</code>.
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
          <li><b>You need an account to save anything, and you are checked
          once.</b> You can look around parts of the app without one. You sign
          up with your Egyptian mobile number and a code sent by SMS. There is
          no password. Members have no public profile; a member who applies to
          coach and is approved has a public portfolio, as described
          below.</li>
          <li><b>It is free.</b> There are no adverts, no in-app purchases, no
          subscriptions and no payments of any kind.</li>
          <li><b>What is not in this version:</b> no community, no AI
          assistant and no payments. Nothing in the app puts you in touch with
          another person unless you ask to join a coach, which is free, and
          then you can chat with her. Two things are shown to other members: a dish you choose to share, without your name, and, if you
          apply to coach and are approved, the public portfolio you build, under
          the <a href="/coach-terms">Coach Terms</a>. Members can read
          portfolios under Find a coach and ask to join, but nobody can pay
          yet. If any missing feature arrives, it will come in a later
          version, with updated Terms that you will be asked to accept.</li>
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
          <li><b>How membership is confirmed:</b> once, when you join. Usually
          your sex and age are read from your national ID number, and a live
          selfie is compared with the portrait on your card. If the automatic
          check cannot decide, you choose the niqab route, or you prefer not to
          use the camera, a woman from Own Hub reviews your case and can
          approve you, usually after a phone call within 72 hours or at a time
          you book. A woman reviewer can also approve a phone number before
          its owner signs up. The <a href="/privacy#c-review">Privacy Policy,
          section 3.4</a>, describes each route. The photographs of your card
          and your face are never stored. We never guess your sex or your age
          from your face.</li>
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

""" + h2("t-conduct", "8. How you treat other members") + """
        <p>Own Hub has zero tolerance for:</p>
        <ul>
          <li>harassment, threats or insults;</li>
          <li>sexual or hateful content;</li>
          <li>sharing anyone else&rsquo;s photos or personal data without her
          consent;</li>
          <li>asking anyone to pay, or offering to pay, outside the app.</li>
        </ul>
        <p>Own Hub can remove such content and suspend or close an account that
        does any of this, as section 12 describes. Every coaching chat has
        Report and Block, and a coach&rsquo;s portfolio can be reported. The
        Own Hub team reads every report, and the person you report is never
        told who reported her (<a href="/privacy#c-reports">Privacy Policy,
        section 3.17</a>).</p>

""" + h2("t-coaching", "9. Coaching") + """
        <ul>
          <li><b>Who the coaches are.</b> Coaches on Own Hub are independent
          professionals, not Own Hub&rsquo;s employees. Own Hub&rsquo;s woman
          reviewer checks each coach&rsquo;s application, certificates and
          portfolio before members can see her, and coaches follow the
          <a href="/coach-terms">Coach Terms</a>.</li>
          <li><b>What coaching is.</b> General fitness and healthy eating. It
          is not medical advice: a coach does not diagnose or treat any
          condition, prescribe a medical diet or recommend supplements, and
          section 4 applies to coaching too.</li>
          <li><b>Own Hub&rsquo;s role.</b> Own Hub reviews coaches, shows their
          portfolios, carries your request, your chat, the plans she shares and
          the times of live sessions, and acts on reports. The coach you choose
          gives the coaching. Own Hub does not sit in on sessions.</li>
          <li><b>Live sessions</b> open in the video service the coach chooses
          (Google Meet, Zoom or Microsoft Teams), outside the app, under that
          service&rsquo;s own terms.</li>
          <li><b>Free for now.</b> In this version coaching is free and nobody
          can pay. Before payments open, you will be asked to accept updated
          terms that set out prices and how payment works.</li>
        </ul>

""" + h2("t8", "10. What you make is yours") + """
        <p>What you log is yours, and we do not claim ownership of it. We keep
        a copy only to provide the service, as the Privacy Policy describes.
        The app&rsquo;s content (exercise instructions, programmes, recipes,
        food data, design) belongs to us or to the people who licensed it to
        us.</p>

""" + h2("t9", "11. Free") + """
        <p>The app is free. If a future version adds anything paid, it will
        come with its own terms, shown before anything is charged, and nothing
        will renew without your clear agreement.</p>

""" + h2("t10", "12. Ending it") + """
        <ul>
          <li><b>You</b> can stop at any time by deleting your account. Deleting
          the app alone does not delete your account.</li>
          <li><b>We</b> may suspend or close an account that breaks section 3,
          section 7 or section 8. Before we do, we tell you why and give you a chance to
          reply, unless the law, an order from an authority or someone&rsquo;s
          safety prevents it. You keep your right to a copy of your data.</li>
        </ul>

""" + h2("t11", "13. The app is provided as it is") + """
        <p>We work to keep Own Hub accurate and available, but we do not
        promise that it is free of errors, that it will always be available, or
        that any particular result will follow from using it.</p>

""" + h2("t12", "14. Later features") + """
        <p>Community, an AI assistant and payments are not part of this
        version. Each will come with its own rules, published with the
        release that switches it on, and you will be asked to accept them
        before you use it.</p>

""" + h2("t13", "15. Limits on what we owe you") + """
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

""" + h2("t14", "16. Changes to these Terms") + """
        <ul>
          <li><b>Material changes:</b> we ask you to accept them in the app
          before they apply to you. If you do not accept, you can delete your
          account.</li>
          <li><b>Other changes:</b> we publish them here with the date and tell
          you in the app.</li>
          <li>Continuing to use the app alone never counts as accepting a
          material change.</li>
        </ul>

""" + h2("t15", "17. Law, disputes and language") + """
        <ul>
          <li>These Terms are governed by the laws of the Arab Republic of
          Egypt.</li>
          <li>Disputes go to {{courtVenue}}.</li>
          <li>These Terms are published in Arabic and English, and the Arabic
          version applies if they differ.</li>
          <li>Own Hub is made for, and offered in, Egypt.</li>
        </ul>

""" + h2("t16", "18. Apple and Google") + """
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

""" + h2("t17", "19. The rest") + """
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

""" + h2("t18", "20. Contact") + """
        <p>{{mailto:contactSupport}} &middot; {{legalEntity}}, {{legalAddress}}</p>
""" + kv([
            ("Version", "3.0"),
            ("Date", "{{policyEffectiveDate}}"),
            ("What changed",
             "Acceptance at sign-up, Arabic prevails, store terms, AI assistant "
             "listed as a later feature. Replaces version 2.0."),
            ("23 October 2026",
             "Clarifications to match the app: you can look around parts of the "
             "app before you sign up; members have no public profile, and an "
             "approved coach has a public portfolio; section 3 now says how "
             "membership is confirmed, including review by a woman and "
             "pre-approved numbers; new section 8 on how you treat other "
             "members and new section 9 on coaching. Later sections are "
             "renumbered."),
        ]) + """
      </div>
    </div>
""",
    }

    # ------------------------------------------------------ coach terms ----
    pages["coach-terms"] = {
        "title": "Coach Terms · Own Hub",
        "description": (
            "The rules for women who apply to coach on Own Hub: reviewed "
            "coaches only, accurate information, client consent, what you may "
            "coach, and what happens if a portfolio is reported."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Coach Terms</h1>
        <p class="meta">
          <b>Version:</b> 1 (coach-terms-v1)<br>
          <b>Effective date:</b> {{policyEffectiveDate}}<br>
          <b>Last updated:</b> {{lastUpdated}}<br>
          <b>Applies to:</b> women who apply to coach on Own Hub, in the app.
        </p>
        <p>If the English and Arabic versions of these Terms differ, the Arabic
        version applies.</p>
        <p class="lede">You accept these terms in the last step of the coach
        application. They sit beside the <a href="/terms">Terms of Use</a> and
        the <a href="/privacy#c-coach">Privacy Policy</a>, which still apply to
        you as a member.</p>

""" + h2("k1", "1. Reviewed coaches only", "no-rule") + """
        <ul>
          <li>Only a verified member can apply, and only a coach whom Own
          Hub&rsquo;s woman reviewer has approved is shown to members.</li>
          <li>The reviewer may approve, ask you for changes, or refuse, and
          tells you why. After a refusal you can apply again after 30
          days.</li>
          <li>Approval means your portfolio can be shown to members. Nothing is
          shown before it.</li>
        </ul>

""" + h2("k2", "2. Accurate information") + """
        <ul>
          <li>Everything in your application and portfolio must be true:
          your name, your education, your certificates, your years of
          experience and your feedback.</li>
          <li>Certificates and documents must be your own and unaltered.</li>
          <li>Keep your portfolio up to date. We may remove a portfolio that
          is not accurate.</li>
        </ul>

""" + h2("k3", "3. Your clients&rsquo; photos and words") + """
        <ul>
          <li>Add a before and after photo, or a screenshot of a
          client&rsquo;s message, only with that woman&rsquo;s written consent.
          You confirm in the app that you have it.
          A clear message from her is enough. Keep it, and show it to us if we
          ask.</li>
          <li>Own Hub&rsquo;s woman reviewer checks every photo and screenshot
          before members see it. When she approves one, we keep a re-encoded
          copy with no location or other metadata and delete the original.
          Verified members then see the approved items on your portfolio. You
          can remove an item yourself, and everything is deleted with your
          account.</li>
          <li>You may also add photos of yourself or your work, which are
          checked the same way.</li>
          <li>If a client withdraws her consent, tell us and we delete the
          photos.</li>
        </ul>

""" + h2("k4", "4. What you may coach") + """
        <ul>
          <li>You coach as an independent professional. You are not Own
          Hub&rsquo;s employee.</li>
          <li>General fitness and healthy eating only.</li>
          <li>Do not diagnose or treat any condition, prescribe a medical diet
          or recommend supplements.</li>
          <li>If a woman is pregnant or has recently given birth, or you think
          she may have an eating disorder, refer her to a doctor.</li>
        </ul>

""" + h2("k5", "5. Keep it inside Own Hub") + """
        <ul>
          <li>Do not put payment details or ways to reach you outside Own Hub
          (a phone number, a messaging account, a social media page) in your
          portfolio.</li>
          <li>Do not ask a member to pay you or to talk to you outside Own
          Hub.</li>
        </ul>

""" + h2("k6", "6. What members see, and prices") + """
        <ul>
          <li>Members see the public portfolio described in the Privacy Policy,
          section 3.15, including the photos the reviewer approved, and nothing
          else from your application.</li>
          <li>While you are a coach, you let Own Hub show your approved
          portfolio content to members in the app.</li>
          <li>In this version the price members see includes Own Hub&rsquo;s
          service fee, and coaching is free for now: nobody can pay. Before
          payments open you will be asked to accept updated coach terms that
          set out prices, Own Hub&rsquo;s share and payouts.</li>
          <li>When a member joins you, you can read the form she filled in only
          while the coaching lasts, and you may use it only to coach her.
          Keep her answers, including her health answers, confidential, and
          use them only to coach her. When her coaching ends, delete any notes
          of your own about her. Messages with her stay inside Own Hub.</li>
        </ul>

""" + h2("k7", "7. Reports, hiding and suspension") + """
        <ul>
          <li>Any member can report a portfolio.</li>
          <li>Own Hub may hide or suspend a portfolio after a report, or if it
          breaks these terms. We tell you why and let you reply, unless the
          law, an order from an authority or someone&rsquo;s safety prevents
          it.</li>
        </ul>

""" + h2("k8", "8. Stopping") + """
        <ul>
          <li>You can withdraw an application, or stop being a coach, at any
          time. Write to {{mailto:contactSupport}}, or delete your account in
          the app, from Profile, then Your data.</li>
          <li>Deleting your account removes your application, its documents and
          your portfolio, as the Privacy Policy describes.</li>
        </ul>

""" + h2("k9", "9. Payments, later") + """
        <p>Payments are not part of this version. If they are offered later,
        they will come with their own terms,
        shown to you before anything is charged, and you will be asked to accept
        them first.</p>

""" + h2("k10", "10. Changes, law and contact") + """
        <ul>
          <li>If we change these terms in a way that matters, we ask you to
          accept them in the app. Other changes are published here.</li>
          <li>These terms are governed by the laws of the Arab Republic of
          Egypt, and disputes go to {{courtVenue}}.</li>
          <li>Contact: {{mailto:contactSupport}} &middot; {{legalEntity}},
          {{legalAddress}}</li>
        </ul>
""" + kv([
            ("23 October 2026",
             "Clarifications: section 4 now says you coach as an independent "
             "professional; section 6 now says that the price members see "
             "includes Own Hub&rsquo;s service fee and that coaching is free "
             "for now, that you keep clients&rsquo; answers confidential and "
             "delete your own notes when a coaching ends, and that Own Hub "
             "shows your approved portfolio content to members while you are a "
             "coach."),
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
        <p class="meta"><b>Last updated:</b> {{lastUpdated}}</p>

        <p class="lede">Write to {{mailto:contactSupport}} and a person will
        answer. There&rsquo;s no ticket system or chatbot in the way.</p>

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
          SMS. There is no password. The first time, you are also checked once,
          usually with your national ID card and a live selfie; if the
          automatic check is unsure, or you choose the niqab route, a woman
          from Own Hub reviews your case and phones you, usually within 72
          hours or at a time you book, to finish your check. There is no community and no assistant
          in this version, and nothing in it can be bought. Coaching with
          Own Hub-reviewed coaches is available, free for now. If you were expecting
          the community or the assistant, you were reading about a later
          version that is not out. You can choose to share a dish, without your
          name, and you can ask a coach to take you on.</p>

""" + h3("q-language", "How do I switch between Arabic and English?") + """
          <p>Profile, then Language. Pick the one you want and the whole app
          changes with it, right to left included. The setting stays after you
          close the app, and you can change it as often as you like.</p>

""" + h3("q-privacy", "What do you know about me?") + """
          <p>Your mobile number, which Google Firebase Authentication holds in
          the United States so that you can sign in. The result of your
          women-only check, and, if your ID number was read, a one-way keyed
          code made from it so that one card cannot open two accounts. We never keep the photographs
          of your card or your face, and we never keep the ID number itself.
          Once you are verified, your training and meals, kept in Frankfurt,
          Germany, where no other member can see them (unless you choose to
          share a dish, which is shared without your name). Your cycle, check-ins,
          measurements, life stage, allergies and weight only if you turn on
          health backup yourself, and the answers you choose to send a coach if
          you ask to join one.</p>
          <p>If you allow crash reports, Firebase Crashlytics receives a report
          when the app crashes, with no account identifier, name or phone
          number. They are off until you allow them. If you turn on
          <b>Help improve Own Hub</b>, Google Analytics for Firebase and PostHog
          receive usage statistics, such as which screens you open or that you
          finished a workout, never your health information and never linked
          to your account. That is off until you
          turn it on. There is no advertising library in the app. The
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
        <p class="small">Line drawings: <a href="https://github.com/lucasmarkes/hairline">Hairline
        by Lucas Marques</a>, under the MIT licence.</p>
      </div>
    </div>
""",
    }

    pages["join"] = {
        "title": "Open this in Own Hub",
        "description": "How to open a coach's invitation or profile link in Own Hub.",
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Open this in Own Hub</h1>
        <p class="lede">Own Hub is a training app for women only. If your coach
        sent you this link, install the app and sign up.</p>
        <p>If her message has a code, tap <b>I have a code from my coach</b> and
        type it in. If it is a link to her page, open the link again once the
        app is installed. Her page opens in the app, and you can ask to join
        her from there.</p>
        <p><a href="/ar/join">العربية</a></p>
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
        <p class="meta"><b>Last updated:</b> {{lastUpdated}}</p>
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
            ("App", "Own Hub for iPhone, bundle id <code>com.ownhub.fitness</code>, "
                    "and Android, package <code>com.ownhub.app</code>"),
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
          replaced by a random code wherever it names you. The copy of what was
          reported is deleted if you made the report. If the report is about
          you, the copy is kept with your name, picture and account links
          removed, and the words that were reported stay.</li>
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
            "Leave your Egyptian mobile number or your email. The first 100 "
            "women try Own Hub before it opens to everyone."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Join the waitlist</h1>
        <p class="lede">Own Hub isn&rsquo;t open yet, and all of it is free.
        Leave your Egyptian mobile number or your email address. The first
        100 women on the list try it before it opens to everyone. Everyone
        else hears from us once, the day it opens.</p>
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
        <p class="lede">Thank you. We will message you once: an early invite
        if you are among the first 100, or the day Own Hub opens. Then we
        delete your contact.</p>
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
      <div class="lead-row">
      <div class="prose">
        <h1>That page is not here</h1>
        <p class="lede">The address you followed does not exist on this site,
        which has only six pages. One of these is almost certainly the one you
        wanted.</p>
      </div>
      """ + art.hairline_svg("loupe", "mark") + """
      </div>
      <ul class="doorways">
        <li><a href="/"><span class="t">Home</span><span class="d">What Own Hub is.</span></a></li>
        <li><a href="/waitlist"><span class="t">Join the waitlist</span><span class="d">The first 100 women try Own Hub before it opens.</span></a></li>
        <li><a href="/privacy"><span class="t">Privacy Policy</span><span class="d">What the app collects, and where it is kept.</span></a></li>
        <li><a href="/terms"><span class="t">Terms of Use</span><span class="d">What Own Hub is, and what it is not.</span></a></li>
        <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person.</span></a></li>
        <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to delete your account.</span></a></li>
      </ul>
    </div>
""",
    }

    return pages
