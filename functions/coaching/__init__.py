"""The coach side's server logic: her role, her certificates, her invites.

Dormant while the coach app is off. COACH_APP_LIVE moves with the app's
`Feature.coachApp` and with `coachLive()` in firebase/firestore.rules and
firebase/storage.rules: all three are switched on in the same release, never
one without the others. While it is False every callable here that would put
coach data on the server refuses, so a verified account calling the API
directly cannot create what the app does not offer.
"""

COACH_APP_LIVE = False
