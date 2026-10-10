# Delete your Own Hub data

> **SUPERSEDED on 6 October 2026. Do not send this file to counsel and do not publish it.**
> This 23 September draft is replaced by the deletion page, written in English and Arabic in the repository at
> `site/_build/pages_en.py` and `site/_build/pages_ar.py` and built to `site/delete-account/index.html` and `site/ar/delete-account/index.html`.
> This file describes an earlier build with no accounts and nothing on a server to delete. It is kept only as a record.

> **Draft for legal review. This is not legal advice.** This is the content for the public web page
> at `[OWNER: https://yourdomain/delete-account]`. Every `[OWNER: ...]` marker is a fact only the
> owner can supply.
>
> **Why this page exists for a release with no accounts.** Google Play requires a deletion page from
> apps that let people create an account, and this version does not, so the requirement is not
> triggered. Publish it anyway: it is one of the four addresses
> `app/lib/config/legal_links.dart` needs before the in-app rows are drawn, it is the honest place to
> explain what deletion means when there is no server, and the requirement returns the moment
> accounts do.

**Last updated:** `[OWNER: publication date]`

---

## The short version

**Own Hub has no accounts and no server. We hold nothing about you, so there is nothing for us to
delete.**

Everything you put into the app is on your own phone. To erase it, open Own Hub, go to **Profile**,
then **Your data**, then **Delete everything**. It happens at once.

| | |
|---|---|
| App | Own Hub, iOS and Android, bundle id `com.ownhub.app` |
| Developer | `[OWNER: registered legal entity name]` |
| Address | `[OWNER: registered address, city, Egypt]` |
| Where to write | `[OWNER: privacy contact email address]` |

---

## Why there is nothing on our side

This version of Own Hub has no server, no account and no network code at all.

- There is no sign-up and no sign-in. The app has never been told who you are.
- The released Android app does not even ask for permission to use the internet.
- There is no analytics, no crash reporting and no advertising library in it.

So we never received your training, your meals, your measurements or your cycle, and we cannot
delete, correct, export or look at any of it. There is no record of you to find.

## What is on your phone, and what deleting removes

The app writes one document into your phone's own private settings store, so that closing the app
does not lose your week. Deleting removes it, along with everything the app is holding:

- Your training: sessions, sets, weights and repetitions, and the workouts you swapped.
- Your meals, your usual plates and your eating preferences.
- Your weekly goal, the weeks you completed, your personal bests and your milestones.
- Body measurements and weight you entered.
- **Your cycle: every period day you recorded, your check-ins and your cycle settings.**
- What you told the app you avoid eating, and your setup answers.
- Your privacy switches and your language.
- What the Home Screen and Lock Screen widgets show. They go back to "Open Own Hub to start", and the
  same happens when you sign out.

The app then returns to its first day and tells you so.

## How to delete it

### In the app, which is the only way it needs

1. Open **Own Hub**.
2. Tap your picture at the top of Home to open **Profile**.
3. Tap **Your data**.
4. Read the sheet. It says what will be removed and that it cannot be undone.
5. Tap **Delete everything**.

It is immediate. There is no waiting on us, no email to send, no code to confirm, and no queue,
because nothing about it involves us.

**Deleting the app removes everything too.** The document lives with the app, so uninstalling takes
it with it.

### By email

You can write to `[OWNER: privacy contact email address]` at any time, and someone will answer.
**There is nothing we can delete for you**, because we hold nothing, and the honest answer we will
give you is the instructions above. `[OWNER: this needs a monitored mailbox, not a procedure.]`

---

## It cannot be undone

There is no restore and no grace period. Once it is done, your logs, your measurements and your cycle
history are gone, and we cannot bring them back, because we never had a copy.

**Downloading a copy first is not built in this version.** The sheet in the app says so plainly
rather than offering a button that would produce nothing, and there is nothing we could send you
either.

`[OWNER: when an export is built, add it here and to the sheet in the same release. A page that
offers an export that does not exist is worse than a page that does not offer one.]`

---

## Delete only some of it

You do not have to delete everything to delete the part that matters to you.

- **Cycle data can be deleted on its own**, from cycle settings, without touching anything else.
- You can delete individual logs, meals and measurements as you go.

---

## What changes when accounts arrive

A later version of Own Hub will add accounts, identity verification and cloud storage. From that
version onwards this page will describe two routes, deleting from inside the app and asking us to
delete without installing it at all, and it will say what survives a deletion and why.

Nothing in that paragraph is running today. The Privacy Policy at
`[OWNER: https://yourdomain/privacy]` carries the full description, in Part B.

---

## Your rights

Under Egypt's Personal Data Protection Law No. 151 of 2020 you can ask a company what it holds about
you, correct it, get a portable copy, have it deleted, and withdraw a consent you gave.

**In this version we hold nothing about you**, so there is nothing to see, correct, port or ask us to
delete. Everything is on your phone and under your control.

If you are not satisfied with how we handle a request, you can complain to Egypt's Personal Data
Protection Centre. `[OWNER: add the PDPC's contact details once counsel confirms the current
channel.]`

---

**Questions:** `[OWNER: privacy contact email address]`

---

## Publishing checklist for the owner

- [ ] The URL is live, reachable with no login, no geo-block and no cookie wall hiding the text.
- [ ] The page exists in **English and Arabic**.
- [ ] The in-app path described here actually works on the build being submitted: Profile, then Your
      data, then Delete everything, and the app comes back empty after a restart.
- [ ] The address is in `app/lib/config/legal_links.dart`, so the in-app rows are drawn.
- [ ] `[OWNER: ...]` markers replaced with real values.
- [ ] This page, `privacy-policy.md`, the Play Data safety answers and the App Privacy answers all
      say the same thing: nothing is collected.
