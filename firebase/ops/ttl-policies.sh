#!/usr/bin/env bash
# Firestore TTL policies for every collection that expires on its own.
#
# `firebase deploy --only firestore:indexes` applies the same policies from
# firebase/firestore.indexes.json (fieldOverrides with "ttl": true). This is
# the equivalent by hand, for a project where the indexes file was not
# deployed, or to check what is on. Each command is idempotent.
#
#   bash firebase/ops/ttl-policies.sh            # enable
#   bash firebase/ops/ttl-policies.sh --list     # show what is on
#
# The retention periods behind them (functions/identity/config.py and
# functions/waitlist/join.py) are PENDING COUNSEL.

set -euo pipefail

PROJECT="${PROJECT:-own-hub}"

if [ "${1:-}" = "--list" ]; then
  gcloud firestore fields ttls list --project="$PROJECT"
  exit 0
fi

enable() {
  gcloud firestore fields ttls update "$2" \
    --collection-group="$1" --enable-ttl --project="$PROJECT" --async
}

enable verificationSessions     expiresAt
enable verificationJobs         expireAt
enable verification_flags       expireAt
enable verificationBehaviour    expireAt   # M9, 180 days after the last signal
enable verificationInstalls     expireAt   # M9, 180 days after the last signal
enable verificationReviewAccess expireAt   # M9, one year after the access
enable waitlist                 expireAt
enable waitlistRate             expireAt
enable waitlistConsentProof     expireAt   # M11, three years after the last possible message
enable adminAccessLog           expireAt   # console reads, one year after the read
enable opsErrors                expireAt   # daily error-code counts, 90 days
enable scanCache                expiresAt  # meal-photo answers, 30 days
enable verificationBookings     expireAt   # booked review slots, once the time has passed
