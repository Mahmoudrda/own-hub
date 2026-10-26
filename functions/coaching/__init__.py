"""The coach side's server logic: applications, portfolios, and (later) the
paid relationship.

Three switches, matching `coachPortfolioLive()`, `coachClientsLive()` and
`coachPaymentsLive()` in firebase/firestore.rules and firebase/storage.rules.
A callable that would put coach data on the server refuses with
`coach_app_closed` while its switch is False, so a verified account calling
the API directly cannot create what the app does not offer.
"""

# Applications, profiles, packages, drafts, the reviewer's decisions, the
# coach claim and the public coach reads.
COACH_PORTFOLIO_LIVE = True

# Requests, accepting or declining, relationships, chat and its trigger,
# shared plans, live sessions, invites and ending a coaching. With payments
# off, accepting makes the coaching active at once, free.
COACH_CLIENTS_LIVE = True

# Payment proofs, refunds, payouts, receipts, receiving accounts and the
# ledger. Stays off until the legal steps for taking money are done.
COACH_PAYMENTS_LIVE = False

# The weekly check-in card, its push and the coach's "Needs attention" list.
# Stays False until the app version that renders `systemKind: "checkIn"` is in
# both stores: older builds show an unknown system line as a hidden message.
CHECK_INS_LIVE = False

