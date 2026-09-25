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


DELETE_SUBJECT = "Own Hub — data deletion request"

DELETE_BODY = """Hello,

I am writing about the Own Hub app, bundle id com.ownhub.app.

I would like to know whether you hold any data about me, and I am asking for anything you do hold to be deleted.

Please confirm in your reply:
1. Whether you hold anything about me at all.
2. What, if anything, you have deleted.

So that you can look:
- My phone (iPhone or Android):
- Roughly when I installed the app:
- Anything else you need from me:

Thank you.
"""


# ---------------------------------------------------------------- build ----

def build(cfg, lang, mailto_link):
    delete_button = mailto_link(
        cfg, lang, "contactPrivacy", DELETE_SUBJECT, DELETE_BODY,
        "btn", "Open a ready-made deletion email",
    )

    pages = {}

    # ------------------------------------------------------------ index ----
    pages["index"] = {
        "title": "Own Hub — a fitness app for women in Egypt",
        "description": (
            "Own Hub is a free fitness app for women in Egypt. There is no "
            "account and no server: everything you log stays on your own phone."
        ),
        "body": """
    <section class="wrap hero">
      <div class="hero-grid">
      <div class="prose">
        <p class="eyebrow">Fitness for women, in Egypt</p>
        <h1>Own Hub</h1>
        <p class="lede">Own Hub is a fitness app built for women in Egypt, and
        only for women. There is no account here: no sign-up, no password and
        no phone number, so the app was never told who you are. It has no
        server either, which means it collects nothing, sends nothing anywhere,
        and asks for no permission at all &mdash; the released Android build does
        not even ask to use the internet. Everything you log is written to your
        own handset so it is still there tomorrow, and one button in your
        profile erases all of it at once. Own Hub is free, and there is nothing
        in it to buy.</p>
        <p>Own Hub was founded by {{brandFounder}}, a woman in Egypt building
        for women in Egypt. There is no biography to read here and nothing to
        take on trust: the app asks you for nothing, keeps nothing of yours, and
        the pages below set out exactly how.</p>
      </div>
      <ul class="facts" aria-label="Own Hub at a glance">
        <li><b>No account</b><span>No sign-up, no password, no phone number. It opens straight onto your own day.</span></li>
        <li><b>No server</b><span>There is no network library in the app. It cannot send anything anywhere.</span></li>
        <li><b>No permissions</b><span>No camera, no photos, no microphone, no location, no health data, no notifications.</span></li>
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
          <h3>It stays on your phone</h3>
          <p>Own Hub has no server. What you log is written to your own handset,
          no other app can read it, and nothing uploads it. Profile, then
          <b>Your data</b>, erases every bit of it at once.</p>
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
          coaching: nothing in the app connects you to another person. There is
          no sign-in, no identity check and no camera. There is no assistant,
          and nothing you write is sent to any service. There is no export of
          your data yet, and the app says so rather than showing a button that
          would produce nothing.</p>
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
        <li><a href="/privacy"><span class="t">Privacy Policy</span><span class="d">What the app collects, which is nothing, and why you can check that for yourself.</span></a></li>
        <li><a href="/terms"><span class="t">Terms of Use</span><span class="d">What Own Hub is, what it is not, and the medical warning worth reading even if you skip the rest.</span></a></li>
        <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person, when she reads, and answers to the things women write in about.</span></a></li>
        <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to erase everything from inside the app, and how to ask without installing it.</span></a></li>
      </ul>
    </section>
""",
    }

    # ---------------------------------------------------------- privacy ----
    privacy_toc = toc("On this page", [
        ("a", "short-version", "The short version"),
        ("a", "who-we-are", "1. Who we are"),
        ("a", "how-to-read", "2. How to read this policy"),
        ("part", "", "Part A, the version on the store"),
        ("a", "a1", "A1. What it collects: nothing"),
        ("a", "a2", "A2. What it keeps on your phone"),
        ("a", "a3", "A3. Features that look like they need a server"),
        ("a", "a4", "A4. Permissions it asks for"),
        ("a", "a5", "A5. Deleting everything"),
        ("a", "a6", "A6. What Apple and Google collect on their own"),
        ("a", "a7", "A7. What the store forms say"),
        ("a", "a8", "A8. Children"),
        ("a", "a9", "A9. Your rights, in this version"),
        ("part", "", "Part B, when a server is connected"),
        ("a", "b1", "B1. The promises that shape this section"),
        ("a", "b2", "B2. What would be collected"),
        ("a", "b3", "B3. What we would rely on to process it"),
        ("a", "b4", "B4. Who else would handle it"),
        ("a", "b5", "B5. How long things would be kept"),
        ("a", "b6", "B6. Deleting an account"),
        ("a", "b7", "B7. Security, in plain language"),
        ("a", "b8", "B8. Children, once accounts exist"),
        ("a", "b9", "B9. Your rights, once we hold something"),
        ("part", "", "And finally"),
        ("a", "changes", "Changes to this policy"),
    ])

    who_rows = [
        ("App", "Own Hub"),
        ("Founder", "{{brandFounder}}"),
        ("Publisher and developer", "{{legalEntity}}"),
        ("Country", "{{legalAddress}}"),
        ("Privacy contact", "{{mailto:contactPrivacy}}"),
    ]
    if cfg.plain("commercialRegistration", lang):
        who_rows.append(
            ("Commercial registration and tax card number",
             "{{commercialRegistration}}")
        )
    if cfg.plain("dataProtectionOfficer", lang):
        who_rows.append(("Data protection officer", "{{dataProtectionOfficer}}"))

    pages["privacy"] = {
        "title": "Privacy Policy — Own Hub",
        "description": (
            "Own Hub collects nothing about you. There is no account and no "
            "server, and everything you put into the app stays on your phone."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Privacy Policy</h1>
        <p class="meta">
          <b>Effective date:</b> {{effectiveDate}}<br>
          <b>Applies to:</b> Own Hub for iOS and Android, bundle id
          <code>com.ownhub.app</code>.<br>
          <b>Last updated:</b> {{effectiveDate}}
        </p>

""" + privacy_toc + """

""" + h2("short-version", "The short version", "no-rule") + """
        <div class="callout">
          <p><b>Own Hub collects nothing about you. Everything you put into it
          stays on your phone.</b></p>
          <p>There is no account to make, no server to send anything to, and no
          company on the other end receiving your training, your meals or your
          cycle. The app writes what you log onto your own handset so that it is
          still there tomorrow, and one button in your profile erases all of
          it.</p>
          <p>That is not a promise about how carefully we handle your data. It
          is a statement about software that has no way to send it anywhere, and
          the rest of this page explains why you can check that for
          yourself.</p>
        </div>

""" + h2("who-we-are", "1. Who we are") + """
""" + kv(who_rows) + """
        <p>Own Hub is a fitness app for women in Egypt. It is free. There are no
        adverts in it, and nothing in it is sold to anyone.</p>
        <p>Own Hub was founded by {{brandFounder}}. It is published and
        developed by {{legalEntity}}, who holds the App Store and Google Play
        accounts and who is the contact for anything on this page. <b>In this
        version nothing you log leaves your phone, so neither of them can see
        any of it</b>, and that is worth saying plainly on a product made for
        women rather than leaving you to find it out.</p>
        <p>Nobody administers a store of your data today, because there is no
        store: every word of it sits on your own handset, inside this
        app&rsquo;s sandbox. If that ever changes, this policy will name the
        person who administers that store and say what they can reach, in the
        same release that switches it on.</p>

""" + h2("how-to-read", "2. How to read this policy") + """
        <ul>
          <li><b>Part A is this release</b>, the version you can install today.
          It is complete on its own.</li>
          <li><b>Part B describes the release that adds accounts and a
          server.</b> None of it is running. It cannot start without a new
          version of the app, a new version of this policy, and your consent
          where consent is required. It is published early so you can read it
          before you decide to make an account.</li>
        </ul>
        <p>If you are reading this from a store listing, <b>only Part A
        describes software you can install.</b></p>

        <h2 id="part-a">Part A, the version on the store<a class="anchor" href="#part-a" aria-label="Link to this section">#</a></h2>

""" + h3("a1", "A1. What it collects: nothing") + """
        <p><b>Own Hub has no server. It cannot send anything anywhere.</b></p>
        <p>That is a statement about the software, and it is checkable:</p>
        <ul>
          <li>The app&rsquo;s whole dependency list is <code>flutter</code>,
          <code>flutter_localizations</code>, <code>intl</code>,
          <code>meta</code>, <code>crypto</code>,
          <code>shared_preferences</code>, <code>url_launcher</code> and
          <code>cupertino_icons</code>. <b>There is no network library of any
          kind in it.</b> No Firebase, no analytics library, no advertising
          library, no crash-reporting library, no HTTP client.</li>
          <li>On Android, the released app <b>does not even ask for permission
          to use the internet.</b></li>
          <li><b>We receive nothing about you.</b> Not your name, not your phone
          number, not what you log, not which screens you open, not whether you
          opened the app at all. We could not tell you how many people are using
          it beyond what Apple and Google count for their own stores.</li>
          <li><b>There is no advertising and no tracking.</b> The app never
          reads an advertising identifier, never asks permission to track you,
          and shares nothing with ad networks or data brokers.</li>
          <li>There is no account. Nothing in the app identifies you, because
          the app was never told who you are.</li>
        </ul>

""" + h3("a2", "A2. What it keeps on your phone, and where") + """
        <p>Everything you log is written to <b>your own handset</b>, so that
        closing the app does not lose your week.</p>
""" + kv([
            ("Where", "The phone&rsquo;s own private settings store, inside the "
                      "app&rsquo;s sandbox. On iOS that is the app&rsquo;s user "
                      "defaults; on Android it is the app&rsquo;s private "
                      "preferences file. No other app can read it."),
            ("What", "One document, holding your training, your meals, your "
                     "weekly goal, your personal bests, your measurements, your "
                     "cycle days, symptoms and settings, your privacy switches, "
                     "what you told us you avoid eating, your setup answers, and "
                     "your language."),
            ("When", "A few hundred milliseconds after you change something, and "
                     "again when you swipe the app away."),
            ("Who can read it", "This app, on this phone. Nothing uploads it, "
                                "nothing backs it up to us, and there is no "
                                "analytics library in the app that could read it."),
            ("How to erase it", "Profile, then <b>Your data</b>. See "
                                '<a href="#a5">A5</a>.'),
        ]) + """
        <p><b>This is still not collection.</b> Both Apple and Google define
        collecting as data leaving the device. Nothing here leaves it.</p>

""" + h3("a3", "A3. The features that look like they need a server, and what they actually do") + """
""" + kv([
            ("Signing up or signing in",
             "<b>There is none.</b> The app opens straight onto your own Home. "
             "No number is asked for, no code is sent, and there is no password "
             "anywhere in the product."),
            ("Identity checks, ID and selfie",
             "<b>Not in this version.</b> There is no camera in the app, and the "
             "screens that would use one are switched off."),
            ("A community, posts, comments, groups",
             "<b>Not in this version.</b> There is nothing to post to and nobody "
             "to post to. No part of the app connects you to another person."),
            ("Coaching, a coach, payments",
             "<b>Not in this version.</b> Nothing in the app can be bought, and "
             "no price is shown anywhere."),
            ("An assistant",
             "<b>Not in this version.</b> No question can be asked, nothing you "
             "write is sent to any AI service, and the app contains no key that "
             "could reach one."),
            ("Photos, video, voice notes",
             "Cannot be created. There is no camera, no gallery access, no "
             "microphone and no speech recognition."),
            ("Opening our privacy policy, terms or support page",
             "These three rows hand a fixed address, ours, to your phone&rsquo;s "
             "own browser. The app has no browser of its own, it fetches "
             "nothing, and it learns nothing about what you do once the page "
             "opens."),
        ]) + """

""" + h3("a4", "A4. Permissions it asks for") + """
        <p><b>None.</b> No camera, no photos, no microphone, no contacts, no
        location, no calendar, no health data, no notifications, no motion or
        fitness sensors. The iOS build contains no permission text at all,
        because nothing in it requests a permission.</p>
        <p>The app is not connected to Apple Health, Google Fit, Health Connect,
        a step counter, or any sensor. Everything the app knows about your
        training is what you typed into it.</p>

""" + h3("a5", "A5. Deleting everything") + """
        <p><b>Profile, then Your data.</b> A sheet tells you what deleting
        removes, that it happens at once and that none of it can be brought
        back. The button under it does exactly that.</p>
        <p>It erases the document described in <a href="#a2">A2</a>, and empties
        everything the app is holding: your training, your meals, your
        measurements, your cycle, your settings and your answers. The app goes
        back to its first day and says so.</p>
        <p>Two things worth knowing:</p>
        <ol>
          <li><b>There is nothing on our side to delete</b>, because we never had
          anything. You do not have to ask us, write to us or wait for us.</li>
          <li><b>Downloading a copy first is not built yet.</b> The sheet says so
          rather than showing a button that would produce nothing. There is also
          nothing we could send you, for the same reason.</li>
        </ol>
        <p>Deleting the app removes everything too. There is a fuller
        explanation on the <a href="/delete-account">deletion page</a>.</p>

""" + h3("a6", "A6. What Apple and Google collect on their own") + """
        <p>When you download or update any app, Apple and Google process data
        under their own privacy policies, not ours. If you have agreed with them
        to share crash and usage data with developers, they may make aggregate
        reports available through their consoles. We do not control that, we
        cannot switch it on or off for you, and you can change it in your device
        settings. It is not something the app does.</p>

""" + h3("a7", "A7. What the store forms say for this version") + """
        <p>For this version the correct answer on Apple&rsquo;s App Privacy
        questionnaire and Google Play&rsquo;s Data Safety form is <b>&ldquo;Data
        Not Collected&rdquo;</b>, with no data used to track you and no data
        linked to you. The app&rsquo;s iOS privacy manifest says the same thing,
        and the two plugins in the build carry their own manifests declaring
        that they collect nothing either.</p>

""" + h3("a8", "A8. Children") + """
        <p>Own Hub is not directed at children. It is a fitness and health
        tracking tool intended for adults.</p>
        <p>Because this version has no account and collects nothing, there is no
        personal data of anyone, of any age, for us to hold.</p>

""" + h3("a9", "A9. Your rights, in this version") + """
        <p>Under Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020 you
        have the right to know what a company holds about you, to see it, to
        correct it, to have it deleted, to take it with you, and to object to
        particular processing.</p>
        <p><b>In this version we hold nothing about you, so there is nothing to
        see, correct, port or ask us to delete.</b> Everything the app holds is
        on your phone and under your control, and <a href="#a5">A5</a> is how
        you clear it.</p>
        <p>If you want to tell us that, or ask anything else, write to
        {{mailto:contactPrivacy}}.</p>

        <h2 id="part-b">Part B, when a server is connected<a class="anchor" href="#part-b" aria-label="Link to this section">#</a></h2>
        <div class="callout calm">
          <p><b>None of Part B is active.</b> It describes the release in which
          sign-in, identity verification and cloud storage are switched on. Until
          that release exists, nothing below happens.</p>
        </div>

""" + h3("b1", "B1. The promises that shape this section") + """
        <ol>
          <li><b>Your ID photo and your selfie are deleted after the check.</b>
          Only the pass or fail result is kept. The app shows you the date they
          were deleted, read from the record itself, not from a sentence someone
          typed.</li>
          <li><b>There is no AI face or gender classification anywhere in this
          product.</b> We never guess your sex from a photograph. The check reads
          the sex digit that the Egyptian government already put in your national
          ID number.</li>
          <li><b>Your cycle data never goes to analytics, under any
          circumstance.</b> Neither does your phone number, your name, your
          verification result, your weight, or any photo.</li>
        </ol>

""" + h3("b2", "B2. What would be collected, by category") + """
        <p>The category names are the ones Apple&rsquo;s App Privacy and Google
        Play&rsquo;s Data Safety forms use, so this list and those forms can be
        checked line by line. <b>Nothing in Own Hub is ever used for tracking, in
        any category.</b></p>
""" + cards([
            ("Contact info", [
                ("What", "Your mobile number, the first name you type, and the "
                         "account identifier we generate."),
                ("Why", "The number is how you sign in. There is no password and "
                        "no email. Your name is never read off your ID."),
                ("Linked to you", "Yes"),
            ]),
            ("Sensitive info, government ID", [
                ("What", "A photograph of your Egyptian national ID and a selfie."),
                ("Why", "To confirm you are a woman, and old enough. The sex "
                        "digit and the date of birth come from the ID number; the "
                        "selfie only confirms the card is yours. <b>The images are "
                        "deleted after the check</b>, and only the result, the "
                        "date, the provider&rsquo;s reference and a one-way "
                        "scramble of the ID number are kept."),
                ("Linked to you", "Yes"),
            ]),
            ("Health and fitness", [
                ("What", "Workouts, sets, meals, weekly goals, personal bests, "
                         "measurements, daily check-ins, <b>period days and cycle "
                         "settings</b>."),
                ("Why", "To show you your own logs, your progress and your plan. "
                        "Cycle data adjusts what the app suggests to you, and "
                        "nothing else. <b>Never sent to analytics.</b>"),
                ("Linked to you", "Yes"),
            ]),
            ("User content", [
                ("What", "Community posts, comments, messages to a coach. "
                         "Progress photos stay <b>encrypted on your own phone "
                         "only</b>."),
                ("Why", "So the people you chose can see what you shared. We "
                        "cannot see your progress photos, cannot export them and "
                        "cannot delete them from our side, because we never had "
                        "them."),
                ("Linked to you", "Yes"),
            ]),
            ("Safety records", [
                ("What", "Reports you make or that are made about you, and who "
                         "you block."),
                ("Why", "To keep members safe and act on what is reported. Read "
                        "by a woman on the moderation team."),
                ("Linked to you", "Yes"),
            ]),
            ("Identifiers", [
                ("What", "The account identifier, and a device record holding "
                         "your notification token, language and platform."),
                ("Why", "To keep you signed in and send notifications you asked "
                        "for. <b>No advertising ID, ever.</b>"),
                ("Linked to you", "Yes"),
            ]),
            ("Purchases", [
                ("What", "If you pay a coach: that a payment happened, its "
                         "amount, status and reference. <b>Never your card "
                         "number</b>, which is entered on the payment "
                         "provider&rsquo;s own page."),
                ("Why", "To run the coaching you paid for."),
                ("Linked to you", "Yes"),
            ]),
            ("Usage data and diagnostics", [
                ("What", "<b>Not collected, and nothing is planned that is "
                         "already built.</b> There is no analytics SDK and no "
                         "crash reporter in the app."),
            ]),
            ("Location, contacts, messages, calendar, files, browsing history", [
                ("What", "<b>Not collected.</b> The app requests none of these "
                         "permissions."),
            ]),
        ]) + """
        <p>If you wear niqab, or do not want to send a face photo, there is a
        path that needs no face photo at all: a short live check with a woman
        reviewer, or an in-person check at a partner ladies-only gym. Only a
        woman reviews it, and the recording is not kept.</p>

""" + h3("b3", "B3. What we would rely on to process it") + """
        <p>Under the PDPL we must have a lawful basis for every category above,
        and explicit consent for the sensitive ones.</p>
""" + kv([
            ("Phone number and account",
             "Necessary to provide the service you asked for."),
            ("ID and selfie",
             "<b>Your explicit, separate consent</b>, recorded with the version "
             "of the wording you were shown."),
            ("Health, fitness, measurements and cycle data",
             "<b>Your explicit consent</b>, given by entering it. You can delete "
             "any of it, and cycle data can be deleted on its own."),
            ("Community posts and comments",
             "Necessary to provide the part of the service you chose to use."),
            ("Safety records",
             "Keeping members safe, and our legal obligations."),
            ("Payment records",
             "Performing the contract, and Egyptian invoicing and tax rules."),
            ("Analytics and diagnostics",
             "Not applicable. There is no analytics SDK and no crash reporter in "
             "the app, and none is planned for the release Part B describes."),
        ]) + """

""" + h3("b4", "B4. Who else would handle it") + """
""" + cards([
            ("{{providerAuth}}", [
                ("What they get", "Your phone number."),
                ("Where", "{{providerAuthRegion}}"),
            ]),
            ("{{providerDatabase}}", [
                ("What they get", "Everything stored in B2."),
                ("Where", "{{providerDatabaseRegion}}"),
            ]),
            ("Your mobile operator", [
                ("What they get", "The sign-in message."),
                ("Where", "Egypt"),
            ]),
            ("{{providerIdentity}}", [
                ("What they get", "Your ID image and selfie, at the moment of "
                                  "the check."),
                ("Where", "{{providerIdentityRegion}}"),
            ]),
            ("{{providerPayment}}", [
                ("What they get", "Your payment details, on their own page."),
                ("Where", "Egypt"),
            ]),
        ]) + """
        <p><b>Today this list is empty in practice</b>, because none of these is
        connected.</p>
        <p>We do not sell your data, and we do not share it with advertisers,
        data brokers or marketing companies. <b>Transfers outside Egypt</b> are
        restricted by the PDPL. The countries the data would reach, and the
        transfer mechanism relied on: {{transferCountries}}</p>

""" + h3("b5", "B5. How long things would be kept") + """
        <p><b>In this version nothing is kept anywhere but your own phone</b>,
        for as long as you keep it there. The periods below belong to the
        release Part B describes, and several of them still have to be set with
        counsel before any server exists.</p>
""" + kv([
            ("ID image and selfie",
             "Deleted after the check. Only the result survives."),
            ("One-way scramble of the ID number",
             'While the account exists, and in closed form afterwards. See '
             '<a href="#b6">B6</a>.'),
            ("Your logs, meals, measurements, cycle data, plans, posts",
             "Until you delete them, or until you delete your account."),
            ("Messages with a coach", "{{retentionCoachMessages}}"),
            ("In-app notifications", "30 days, then deleted automatically."),
            ("A data export you request", "24 hours, then deleted automatically."),
            ("Safety reports", "{{retentionSafetyReports}}"),
            ("Payment and invoice records", "{{retentionPaymentRecords}}"),
        ]) + """

""" + h3("b6", "B6. Deleting an account, once accounts exist") + """
        <p>You will be able to delete from inside the app, and to ask us to
        delete without installing the app at all. The public page at
        <a href="/delete-account">Delete your data</a> explains both.</p>
        <p><b>Three things would survive on purpose</b>, and we would rather say
        so than let you find out:</p>
        <ol>
          <li>A one-way scramble of your national ID number, kept in
          <b>closed</b> form with the link to you removed, so that someone
          removed from the app cannot rejoin the next day.</li>
          <li>Safety reports made by you or about you, with the account
          identifiers replaced by a meaningless token.</li>
          <li>A record that a deletion happened, reduced to dates and a
          status.</li>
        </ol>

""" + h3("b7", "B7. Security, in plain language") + """
        <ul>
          <li>Your account would be protected by a code sent to your phone.
          There is no password to steal, and we never ask for one.</li>
          <li>Data would travel over an encrypted connection and be encrypted
          where it is stored.</li>
          <li><b>You could only read your own data.</b> The rules enforcing that
          live on the server, not in the app, so a modified copy of the app
          cannot read anyone else&rsquo;s data.</li>
          <li><b>The app cannot mark itself as verified.</b> The verification
          result is written by our server and by nothing else. That is the
          single most important rule in this product: a women-only app whose
          gate can be set by the phone holding it is not a women-only app.</li>
          <li>Progress photos would be encrypted on your device with a key held
          in the iOS Keychain or the Android Keystore.</li>
          <li>Honest limits: no system is perfectly secure, and a device left
          unlocked is outside our control.</li>
        </ul>

""" + h3("b8", "B8. Children, once accounts exist") + """
        <p>The minimum age would be {{minimumAge}}, and the check would not be a
        tick box: your date of birth comes from your national ID.</p>

""" + h3("b9", "B9. Your rights, once we hold something") + """
        <p>You would have the rights listed in <a href="#a9">A9</a>, exercised in
        the app through &ldquo;download everything&rdquo; and &ldquo;delete my
        account&rdquo;, or by writing to {{mailto:contactPrivacy}} from the
        number on the account.</p>
        <p><b>How long we take:</b> {{rightsResponseWindow}}</p>
        <p><b>If you are not satisfied</b>, you can complain to Egypt&rsquo;s
        Personal Data Protection Centre. {{pdpcContact}}</p>

""" + h2("changes", "Changes to this policy") + """
        <p>We will post any change here, with the date and what changed. If a
        change means we start collecting something new, we will tell you in the
        app before it starts, and ask for consent where consent is required.</p>
""" + kv([
            ("Date", "{{effectiveDate}}"),
            ("Version", "1.0"),
            ("What changed",
             "First published. This version of Own Hub has no accounts and "
             "collects no data. Everything you log stays on your own phone. Part "
             "B describes a server that is not connected."),
        ]) + """
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
        "title": "Terms of Use — Own Hub",
        "description": (
            "The terms for using Own Hub: a free fitness app for women in "
            "Egypt, with no account, no community, no coaching and nothing to buy."
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
        <p><b>This version has no account.</b> There is nothing to sign up for,
        no password and no profile that anyone else can see. Everything you put
        into it is written to your own phone and stays there.</p>
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
        <p><b>In this version the app does not check, because there is no
        account to attach a check to.</b> We are saying that plainly rather than
        implying a gate that does not exist. When accounts arrive, membership is
        confirmed through the Egyptian national ID, which carries sex and date of
        birth in the ID number itself. We do not judge appearance and we do not
        classify faces.</p>

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
        <p>There is no account and no server in this version, so there is
        nothing for you to secure with us and nothing for us to lose.</p>
        <ul>
          <li><b>What you log lives on your phone.</b> Anyone who can unlock your
          phone can open the app and read it. If that matters to you, use your
          phone&rsquo;s own lock.</li>
          <li><b>You can erase everything at once</b>, from Profile, then Your
          data. It is immediate and it cannot be undone.</li>
          <li><b>We cannot recover anything.</b> We never had it. If you delete
          it, or lose the phone, or delete the app, it is gone.</li>
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
          engineering, no attempt to defeat the parts of the product that are
          switched off, and no security testing without our written
          permission.</li>
          <li>Redistribute the app, its content, its exercise library or its food
          data as your own.</li>
          <li>Use Own Hub for anything illegal under Egyptian law.</li>
        </ul>
        <p>When the community arrives, <a href="#t12">section 12</a> adds the
        rules that come with it. They are not in force in this version, because
        there is nowhere to post.</p>

""" + h2("t8", "8. Content you make") + """
        <p><b>What you log is yours.</b> We do not claim ownership of it, and in
        this version we do not have a copy of it, because it never leaves your
        phone.</p>

""" + h2("t9", "9. Nothing is for sale here") + """
        <p>The app is free. There are no in-app purchases, no subscriptions, no
        external payments, and no price shown anywhere in this version. If a
        future version adds paid coaching, it will do so with its own terms,
        shown to you before anything is charged, and nothing will renew by
        itself.</p>

""" + h2("t10", "10. Ending it") + """
        <p><b>You can stop at any time.</b> Delete everything from Profile, then
        Your data, or delete the app, or both. You do not owe us a reason, and
        there is no account for us to close.</p>

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
            ("Accounts and verification",
             "One account per person, the membership rule and the minimum age "
             "from section 3, and the rule that you may not use anyone "
             "else&rsquo;s identity documents."),
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
          lost profits or lost opportunity. In this version your data is on your
          phone alone, and keeping your phone is your side of that.</li>
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
            ("Version", "1.0"),
            ("What changed",
             "First published, for a release with no account, no community, no "
             "coaching and no payments."),
        ]) + """
      </div>
    </div>
""",
    }

    # ---------------------------------------------------------- support ----
    pages["support"] = {
        "title": "Support — Own Hub",
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
          is read on the next working day. Nothing about the app depends on that
          reply: it keeps working while you wait, because it never needed us.</p>
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
        email.</b> We never need your ID, your photograph, your measurements or
        your cycle history to answer a question, and we will never ask you for
        them. There is no password to reset, because the app has none.</p>

""" + h2("questions", "The questions people actually write in about") + """
        <div class="qa">
""" + h3("q-restore", "I deleted everything. Can you bring it back?") + """
          <p>No, and neither can anyone else. Deleting from Profile, then Your
          data, is immediate, and there is no restore and no grace period. We
          never had a copy, because the app has no server and sends us nothing,
          so there is nothing on our side to recover from. The same is true if
          you lose the phone or uninstall the app.</p>

""" + h3("q-newphone", "I am changing phone. Does my history come with me?") + """
          <p>Not from us. Your logs live in the app&rsquo;s own private storage
          on the handset, and Own Hub has no account and no cloud backup, so
          there is nothing for us to move. A full device-to-device transfer or a
          full phone backup restored onto the new handset may carry it across,
          but that is your phone&rsquo;s own feature and we cannot promise what
          it does. There is no export in this version, and the app says so rather
          than offering a button that would produce nothing.</p>

""" + h3("q-signin", "Where do I sign in? Where is the community?") + """
          <p>There is nothing to sign in to. This version has no account, no
          password and no phone number, and it opens straight onto your own Home.
          There is no community, no coaching and no assistant in it either:
          nothing in the app connects you to another person, and nothing in it
          can be bought. If you were expecting one of those, you were reading
          about a later version that is not out.</p>

""" + h3("q-language", "How do I switch between Arabic and English?") + """
          <p>Profile, then Language. Pick the one you want and the whole app
          changes with it, right to left included. The setting stays after you
          close the app, and you can change it as often as you like.</p>

""" + h3("q-privacy", "What do you know about me?") + """
          <p>Nothing at all. The app has no network code in it, the released
          Android build does not even ask for permission to use the internet, and
          there is no analytics, crash reporting or advertising library anywhere
          in it. We could not tell you how many women use the app beyond what
          Apple and Google count for their own stores. The
          <a href="/privacy">Privacy Policy</a> explains why you can check that
          for yourself rather than take our word for it.</p>
        </div>

""" + h2("elsewhere", "The other things you might be looking for") + """
        <ul>
          <li><a href="/delete-account">Delete your data</a> &mdash; how to erase
          everything from inside the app, and how to ask us without installing
          it.</li>
          <li><a href="/privacy">Privacy Policy</a> &mdash; what the app
          collects, which is nothing.</li>
          <li><a href="/terms">Terms of Use</a> &mdash; including the medical
          warning, which is worth reading before you start training.</li>
        </ul>
      </div>
    </div>
""",
    }

    # --------------------------------------------------- delete-account ----
    pages["delete-account"] = {
        "title": "Delete your Own Hub data — Own Hub",
        "description": (
            "Own Hub has no accounts and no server. Everything is on your own "
            "phone, and this page explains how to erase it, with or without the app."
        ),
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Delete your Own Hub data</h1>
        <p class="meta"><b>Last updated:</b> {{effectiveDate}}</p>

""" + h2("short", "The short version", "no-rule") + """
        <div class="callout">
          <p><b>Own Hub has no accounts and no server. We hold nothing about
          you, so there is nothing for us to delete.</b></p>
          <p>Everything you put into the app is on your own phone. To erase it,
          open Own Hub, go to <b>Profile</b>, then <b>Your data</b>, then
          <b>Delete everything</b>. It happens at once.</p>
        </div>
""" + kv([
            ("App", "Own Hub, iOS and Android, bundle id "
                    "<code>com.ownhub.app</code>"),
            ("Founder", "{{brandFounder}}"),
            ("Publisher and developer", "{{legalEntity}}"),
            ("Country", "{{legalAddress}}"),
            ("Where to write", "{{mailto:contactPrivacy}}"),
        ]) + """

""" + h2("nothing-our-side", "Why there is nothing on our side") + """
        <p>This version of Own Hub has no server, no account and no network code
        at all.</p>
        <ul>
          <li>There is no sign-up and no sign-in. The app has never been told who
          you are.</li>
          <li>The released Android app does not even ask for permission to use
          the internet.</li>
          <li>There is no analytics, no crash reporting and no advertising
          library in it.</li>
        </ul>
        <p>So we never received your training, your meals, your measurements or
        your cycle, and we cannot delete, correct, export or look at any of it.
        There is no record of you to find.</p>

""" + h2("what-goes", "What is on your phone, and what deleting removes") + """
        <p>The app writes one document into your phone&rsquo;s own private
        settings store, so that closing the app does not lose your week. Deleting
        removes it, along with everything the app is holding:</p>
        <ul>
          <li>Your training: sessions, sets, weights and repetitions, and the
          workouts you swapped.</li>
          <li>Your meals, your usual plates and your eating preferences.</li>
          <li>Your weekly goal, the weeks you completed, your personal bests and
          your milestones.</li>
          <li>Body measurements and weight you entered.</li>
          <li><b>Your cycle: every period day you recorded, your check-ins and
          your cycle settings.</b></li>
          <li>What you told the app you avoid eating, and your setup
          answers.</li>
          <li>Your privacy switches and your language.</li>
        </ul>
        <p>The app then returns to its first day and tells you so.</p>

""" + h2("how", "How to delete it") + """
""" + h3("in-the-app", "In the app, which is the only way it needs") + """
        <ol class="steps">
          <li>Open <b>Own Hub</b>.</li>
          <li>Tap your picture at the top of Home to open <b>Profile</b>.</li>
          <li>Tap <b>Your data</b>.</li>
          <li>Read the sheet. It says what will be removed and that it cannot be
          undone.</li>
          <li>Tap <b>Delete everything</b>.</li>
        </ol>
        <p>It is immediate. There is no waiting on us, no email to send, no code
        to confirm, and no queue, because nothing about it involves us.</p>
        <p><b>Deleting the app removes everything too.</b> The document lives
        with the app, so uninstalling takes it with it.</p>

""" + h3("without-the-app", "Without installing the app, by email") + """
        <p>You can ask us to delete your data without installing Own Hub at all.
        The button below opens a message to {{mailtoplain:contactPrivacy}} with
        the subject and the text already written; send it, change it, or write
        your own.</p>
        <div class="btn-row">""" + delete_button + """</div>
        <div class="callout calm">
          <p><b>Here is the honest answer you will get back.</b> In this version
          of Own Hub nothing of yours exists on any server, ours or anyone
          else&rsquo;s, so there is nothing for us to find, delete, correct or
          send you. We will confirm that in writing, and point you at the steps
          above, which are the only deletion that has anything to delete.</p>
          <p>We are keeping this route open anyway, because you are entitled to
          ask a company what it holds about you without having to install its
          software first, and because the day accounts arrive it becomes a real
          request with a real queue behind it.</p>
        </div>
        <p>If the button does not work on your device, write to
        {{mailto:contactPrivacy}} yourself. Anything you send is an ordinary
        email, held in an ordinary mailbox, and you do not need to include your
        ID, a photograph or any health information &mdash; we will never ask you
        for them.</p>

""" + h2("cannot-undo", "It cannot be undone") + """
        <p>There is no restore and no grace period. Once it is done, your logs,
        your measurements and your cycle history are gone, and we cannot bring
        them back, because we never had a copy.</p>
        <p><b>Downloading a copy first is not built in this version.</b> The
        sheet in the app says so plainly rather than offering a button that would
        produce nothing, and there is nothing we could send you either.</p>

""" + h2("some-of-it", "Delete only some of it") + """
        <p>You do not have to delete everything to delete the part that matters
        to you.</p>
        <ul>
          <li><b>Cycle data can be deleted on its own</b>, from cycle settings,
          without touching anything else.</li>
          <li>You can delete individual logs, meals and measurements as you
          go.</li>
        </ul>

""" + h2("later", "What changes when accounts arrive") + """
        <p>A later version of Own Hub will add accounts, identity verification
        and cloud storage. From that version onwards this page will describe two
        routes, deleting from inside the app and asking us to delete without
        installing it at all, and it will say what survives a deletion and
        why.</p>
        <p>Nothing in that paragraph is running today. The
        <a href="/privacy">Privacy Policy</a> carries the full description, in
        Part B.</p>

""" + h2("rights", "Your rights") + """
        <p>Under Egypt&rsquo;s Personal Data Protection Law No. 151 of 2020 you
        can ask a company what it holds about you, correct it, get a portable
        copy, have it deleted, and withdraw a consent you gave.</p>
        <p><b>In this version we hold nothing about you</b>, so there is nothing
        to see, correct, port or ask us to delete. Everything is on your phone
        and under your control.</p>
        <p>If you are not satisfied with how we handle a request, you can
        complain to Egypt&rsquo;s Personal Data Protection Centre.
        {{pdpcContact}}</p>

        <p><b>Questions:</b> {{mailto:contactPrivacy}}</p>
      </div>
    </div>
""",
    }

    # -------------------------------------------------------------- 404 ----
    pages["404"] = {
        "title": "Page not found — Own Hub",
        "description": "That address is not on this site. Here is everything that is.",
        "body": """
    <div class="wrap lost">
      <div class="prose">
        <h1>That page is not here</h1>
        <p class="lede">The address you followed does not exist on this site,
        which has only five pages. One of these is almost certainly the one you
        wanted.</p>
      </div>
      <ul class="doorways">
        <li><a href="/"><span class="t">Home</span><span class="d">What Own Hub is.</span></a></li>
        <li><a href="/privacy"><span class="t">Privacy Policy</span><span class="d">What the app collects, which is nothing.</span></a></li>
        <li><a href="/terms"><span class="t">Terms of Use</span><span class="d">What Own Hub is, and what it is not.</span></a></li>
        <li><a href="/support"><span class="t">Support</span><span class="d">How to reach a person.</span></a></li>
        <li><a href="/delete-account"><span class="t">Delete your data</span><span class="d">How to erase everything.</span></a></li>
      </ul>
    </div>
""",
    }

    return pages
